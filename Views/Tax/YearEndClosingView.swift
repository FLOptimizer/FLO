//  YearEndClosingView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Guided year-end closing workflow
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Three-step workflow: Preview → Confirm → Results
//  Rolls carryforwards, resets partner capital, reviews depreciation.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct YearEndClosingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @State private var allTransactions: [Transaction] = []
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date()) - 1
    @State private var previews: [ClosingPreview] = []
    @State private var result: YearEndClosingResult?
    @State private var phase: ClosingPhase = .preview
    @State private var showingConfirmation = false
    @State private var viewAppeared = false

    private enum ClosingPhase {
        case preview
        case executing
        case complete
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                switch phase {
                case .preview:
                    previewContent
                case .executing:
                    executingContent
                case .complete:
                    if let result {
                        completedContent(result)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Year-End Close")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.3)) {
                viewAppeared = true
            }
        }
        .alert("Confirm Year-End Close", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Close \(selectedYear)", role: .destructive) {
                executeClose()
            }
        } message: {
            Text("This will roll carryforwards, reset partner capital balances, and create suspended loss entries for \(selectedYear). This action cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "checkmark.seal.fill",
            title: "Year-End Closing",
            subtitle: phase == .complete
                ? "\(selectedYear) closed successfully"
                : "Review and close \(selectedYear) tax year",
            color: phase == .complete ? .green : .indigo
        )
    }

    // MARK: - Preview Phase

    private var previewContent: some View {
        VStack(spacing: 16) {
            // Year picker
            yearPicker

            if businesses.isEmpty {
                emptyBusinessState
            } else {
                ForEach(previews) { preview in
                    businessPreviewCard(preview)
                }

                // Execute button
                Button {
                    HapticService.play(.medium)
                    showingConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Close \(selectedYear) Tax Year")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)

                disclaimerCard
            }
        }
    }

    private var yearPicker: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = Array((currentYear - 2)...(currentYear - 1))

        return Picker("Tax Year", selection: $selectedYear) {
            ForEach(years, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedYear) { _, _ in
            loadData()
        }
    }

    private func businessPreviewCard(_ preview: ClosingPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Business header
            HStack {
                Image(systemName: preview.business.displayIcon)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text(preview.business.businessName)
                    .font(.headline)
                Spacer()
                Text(preview.business.businessType.taxFormName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.brandPrimary.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.brandPrimary)
            }

            Divider()

            // Carryforwards
            if !preview.carryforwardsToRoll.isEmpty {
                previewSection(
                    title: "Carryforwards",
                    icon: "arrow.uturn.forward.circle.fill",
                    color: .orange
                ) {
                    ForEach(preview.carryforwardsToRoll) { item in
                        HStack {
                            Text(item.carryforward.type.displayName)
                                .font(.caption)
                            Spacer()
                            Text(item.action)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Partner capital resets
            if !preview.partnersToReset.isEmpty {
                previewSection(
                    title: "Partner Capital Reset",
                    icon: "person.2.fill",
                    color: .blue
                ) {
                    ForEach(preview.partnersToReset) { item in
                        HStack {
                            Text(item.partner.partnerName)
                                .font(.caption)
                            Spacer()
                            Text("\(formatCurrency(item.currentEndingCapital)) → Beginning")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Asset depreciation
            if !preview.assetsToAdvance.isEmpty {
                previewSection(
                    title: "Depreciation",
                    icon: "chart.bar.fill",
                    color: .teal
                ) {
                    ForEach(preview.assetsToAdvance) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.asset.name)
                                .font(.caption)
                            HStack(spacing: 12) {
                                Text("\(selectedYear): \(formatCurrency(item.currentYearDepreciation))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(selectedYear + 1): \(formatCurrency(item.nextYearDepreciation))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Remaining: \(formatCurrency(item.remainingBasis))")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }

            // Suspended loss alerts
            if !preview.suspendedLossAlerts.isEmpty {
                previewSection(
                    title: "Suspended Loss Alerts",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    ForEach(preview.suspendedLossAlerts) { alert in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.partnerName)
                                    .font(.caption.weight(.medium))
                                Text(alert.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatCurrency(alert.amount))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            // Nothing to close
            if preview.carryforwardsToRoll.isEmpty &&
               preview.partnersToReset.isEmpty &&
               preview.assetsToAdvance.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Nothing to close for this entity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func previewSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            content()
        }
    }

    // MARK: - Executing Phase

    private var executingContent: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Closing \(selectedYear) tax year...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    // MARK: - Completed Phase

    private func completedContent(_ result: YearEndClosingResult) -> some View {
        VStack(spacing: 16) {
            // Success banner
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
                Text("\(result.taxYear) Year-End Close Complete")
                    .font(.headline)
                Text("\(result.totalItemsProcessed) items processed across \(result.businessSummaries.count) \(result.businessSummaries.count == 1 ? "entity" : "entities")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)

            // Per-business results
            ForEach(result.businessSummaries) { summary in
                businessResultCard(summary)
            }
        }
    }

    private func businessResultCard(_ summary: BusinessClosingSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(summary.business.businessName)
                    .font(.headline)
                Spacer()
                if summary.hasWarnings {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }
            }

            ForEach(summary.steps) { step in
                HStack(spacing: 8) {
                    stepStatusIcon(step.status)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(step.stepName)
                            .font(.caption.weight(.medium))
                        Text(step.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if step.itemsProcessed > 0 {
                        Text("\(step.itemsProcessed)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func stepStatusIcon(_ status: ClosingStepResult.StepStatus) -> some View {
        switch status {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
                .accessibilityHidden(true)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
                .accessibilityHidden(true)
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Empty State

    private var emptyBusinessState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.quaternary)
                .accessibilityHidden(true)
            Text("No businesses configured")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Add a business profile in Settings to use year-end closing.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    // MARK: - Disclaimer

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("Important")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.orange)
            }
            Text("Year-end closing modifies carryforward and partner capital data. This cannot be undone. Review all items carefully before proceeding. Consult your tax professional for guidance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data

    private func loadData() {
        allTransactions = (try? modelContext.fetch(FetchDescriptor<Transaction>())) ?? []
        generatePreviews()
    }

    private func generatePreviews() {
        previews = businesses.map { business in
            YearEndClosingService.shared.generatePreview(
                business: business,
                transactions: allTransactions,
                taxYear: selectedYear
            )
        }
    }

    private func executeClose() {
        phase = .executing

        // Small delay for UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let closingResult = YearEndClosingService.shared.executeCloseAll(
                businesses: businesses,
                transactions: allTransactions,
                taxYear: selectedYear,
                context: modelContext
            )

            withAnimation(FLOAnimation.standard) {
                result = closingResult
                phase = .complete
            }
            HapticService.play(.success)
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Double) -> String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0"
    }
}

#if DEBUG
#Preview("Year-End Closing") {
    NavigationStack {
        YearEndClosingView()
            .modelContainer(for: [
                BusinessProfile.self, Transaction.self,
                PartnerAllocation.self, DepreciableAsset.self,
                TaxCarryforward.self
            ])
    }
}
#endif
