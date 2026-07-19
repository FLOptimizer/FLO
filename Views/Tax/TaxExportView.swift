//  TaxExportView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — CPA-facing tax data export UI
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Allows users to export tax line data in Lacerte CSV or generic CSV format
//  for their CPA/enrolled agent.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct TaxExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var allTransactions: [Transaction] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var selectedFormat: TaxExportFormat = .lacerteCSV
    @State private var selectedBusiness: BusinessProfile?
    @State private var exportAll = true
    @State private var exportResult: TaxExportResult?
    @State private var showingShareSheet = false
    @State private var exportFileURL: URL?
    @State private var viewAppeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                configurationSection
                previewSection

                if exportResult != nil {
                    exportButton
                }
            }
            .padding(16)
        }
        .navigationTitle("CPA Export")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            loadTransactions()
            withAnimation(.easeOut(duration: 0.3)) {
                viewAppeared = true
            }
        }
        .onChange(of: selectedYear) { _, _ in
            loadTransactions()
        }
        .onChange(of: selectedFormat) { _, _ in generateExport() }
        .onChange(of: exportAll) { _, _ in generateExport() }
        .onChange(of: selectedBusiness) { _, _ in generateExport() }
        .shareSheet(isPresented: $showingShareSheet, items: exportFileURL as Any)
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "doc.badge.arrow.up",
            title: "Export for CPA",
            subtitle: "Generate tax data in your preparer's format",
            color: .blue
        )
    }

    // MARK: - Configuration

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            yearPickerSection
            formatPickerSection
            entityPickerSection
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var yearPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tax Year")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let currentYear = Calendar.current.component(.year, from: Date())
            let years = Array((currentYear - 2)...(currentYear))

            Picker("Tax Year", selection: $selectedYear) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var formatPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Export Format")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(TaxExportFormat.allCases, id: \.self) { format in
                formatRow(format)
            }
        }
    }

    private func formatRow(_ format: TaxExportFormat) -> some View {
        let isSelected = selectedFormat == format
        return Button {
            selectedFormat = format
            HapticService.play(.light)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: format.icon)
                    .font(.subheadline)
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.brandPrimary : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(format.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(format.description)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.brandPrimary : Color.gray.opacity(0.3))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .background(isSelected ? Color.brandPrimary.opacity(0.06) : Color.floSecondarySystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var entityPickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Entities")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Toggle("Export all entities", isOn: $exportAll)
                .font(.subheadline)

            if !exportAll {
                Picker("Business", selection: $selectedBusiness) {
                    Text("Select...").tag(nil as BusinessProfile?)
                    ForEach(businesses) { business in
                        Text(business.businessName).tag(business as BusinessProfile?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Group {
            if let result = exportResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Export Preview")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(result.lineCount) lines")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Summary stats
                    HStack(spacing: 16) {
                        statPill(label: "Income", value: result.totalIncome, color: .green)
                        statPill(label: "Deductions", value: result.totalDeductions, color: .red)
                    }

                    // CSV preview (first 10 lines)
                    let previewLines = result.csvContent
                        .components(separatedBy: "\n")
                        .filter { !$0.hasPrefix("#") && !$0.isEmpty }
                        .prefix(8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(previewLines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            if result.lineCount > 8 {
                                Text("... \(result.lineCount - 8) more lines")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.floSecondarySystemBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if businesses.isEmpty {
                emptyState
            }
        }
    }

    private func statPill(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatCurrency(value))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button {
            HapticService.play(.medium)
            performExport()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share \(selectedFormat.displayName)")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.brandPrimary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
            Text("No businesses configured")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(30)
    }

    // MARK: - Data

    private func loadTransactions() {
        allTransactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        generateExport()
    }

    private func generateExport() {
        guard !businesses.isEmpty else {
            exportResult = nil
            return
        }

        if exportAll {
            exportResult = TaxExportService.shared.exportAll(
                businesses: businesses,
                transactions: allTransactions,
                taxYear: selectedYear,
                format: selectedFormat
            )
        } else if let business = selectedBusiness {
            exportResult = TaxExportService.shared.exportBusiness(
                business: business,
                transactions: allTransactions,
                taxYear: selectedYear,
                format: selectedFormat
            )
        } else {
            exportResult = nil
        }
    }

    private func performExport() {
        guard let result = exportResult else { return }
        exportFileURL = TaxExportService.shared.saveToFile(result)
        if exportFileURL != nil {
            showingShareSheet = true
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#if DEBUG
#Preview("Tax Export") {
    NavigationStack {
        TaxExportView()
            .modelContainer(for: [BusinessProfile.self, Transaction.self])
    }
}
#endif
