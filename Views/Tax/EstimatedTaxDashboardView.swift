//  EstimatedTaxDashboardView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Estimated tax payment tracking and safe harbor dashboard
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shows quarterly payment status, safe harbor compliance,
//  and actionable alerts for estimated tax obligations.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct EstimatedTaxDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTransactions: [Transaction]
    @Query private var taxSettingsAll: [TaxSettings]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var status: EstimatedTaxStatus?
    @State private var viewAppeared = false
    @State private var voucherPDFData: Data?
    @State private var showingShareSheet = false

    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }

    private var taxSettings: TaxSettings? {
        taxSettingsAll.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                yearPicker

                if let status {
                    alertsSection(status)
                    safeHarborCard(status)
                    quarterlyBreakdown(status)
                    projectionCard(status)
                } else {
                    ProgressView("Calculating estimated taxes...")
                        .padding(40)
                }
            }
            .padding()
        }
        .navigationTitle("Estimated Taxes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            if hasProAccess {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        generateAndShareVouchers()
                    } label: {
                        Label("Export 1040-ES Vouchers", systemImage: "doc.text")
                    }
                    .disabled(status == nil)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let data = voucherPDFData {
                ShareSheet(items: [data])
            }
        }
        .onAppear {
            refreshStatus()
            withAnimation(.easeOut(duration: 0.3)) { viewAppeared = true }
        }
        .onChange(of: selectedYear) { _, _ in refreshStatus() }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "calendar.badge.clock",
            title: "Estimated Tax Tracker",
            subtitle: "Quarterly payments & safe harbor compliance",
            color: Color.brandPrimary
        )
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Picker("Tax Year", selection: $selectedYear) {
            ForEach((currentYear - 1)...(currentYear + 1), id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Alerts

    private func alertsSection(_ status: EstimatedTaxStatus) -> some View {
        ForEach(status.alerts) { alert in
            alertCard(alert)
        }
    }

    private func alertCard(_ alert: EstimatedTaxAlert) -> some View {
        GroupBox {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: alertIcon(alert.alertType))
                    .foregroundStyle(severityColor(alert.severity))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.message)
                        .font(.subheadline.bold())
                    Text(alert.recommendation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Safe Harbor

    private func safeHarborCard(_ status: EstimatedTaxStatus) -> some View {
        let harbor = status.safeHarborStatus

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: harbor.isSafe ? "shield.checkered" : "shield.slash")
                        .foregroundStyle(harbor.isSafe ? .green : .red)
                        .font(.title2)

                    VStack(alignment: .leading) {
                        Text(harbor.isSafe ? "Safe Harbor Met" : "Safe Harbor Not Met")
                            .font(.headline)
                        Text("via \(harbor.method)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                harborMethodRow(
                    label: "Current Year (90%)",
                    met: harbor.meetsCurrentYearHarbor,
                    threshold: harbor.currentYearThreshold,
                    paid: status.totalPaidYTD
                )

                harborMethodRow(
                    label: "Prior Year",
                    met: harbor.meetsPriorYearHarbor,
                    threshold: harbor.priorYearThreshold,
                    paid: status.totalPaidYTD
                )
            }
        } label: {
            Label("Safe Harbor Status", systemImage: "shield.fill")
                .font(.headline)
        }
    }

    private func harborMethodRow(label: String, met: Bool, threshold: Double, paid: Double) -> some View {
        HStack {
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(met ? .green : .secondary)

            Text(label)
                .font(.subheadline)

            Spacer()

            let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: threshold)) ?? "$0"
            Text(formatted)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Quarterly Breakdown

    private func quarterlyBreakdown(_ status: EstimatedTaxStatus) -> some View {
        GroupBox {
            VStack(spacing: 8) {
                ForEach(status.quarterlyStatuses) { qs in
                    quarterRow(qs)
                }

                Divider()

                totalRow(status)
            }
        } label: {
            Label("Quarterly Payments", systemImage: "calendar")
                .font(.headline)
        }
    }

    private func quarterRow(_ qs: QuarterlyStatus) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(qs.quarterLabel)
                        .font(.subheadline.bold())
                    if qs.isPaid {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else if qs.isPastDue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                HStack(spacing: 4) {
                    Text("Due: \(DateFormatter.mediumDate.string(from: qs.dueDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let days = qs.daysUntilDue, days > 0 {
                        Text("(\(days)d)")
                            .font(.caption)
                            .foregroundStyle(days <= 7 ? .red : .orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let dueFormatted = NumberFormatter.appCurrency.string(from: NSNumber(value: qs.amountDue)) ?? "$0"
                Text(dueFormatted)
                    .font(.subheadline.monospacedDigit())
                let paidFormatted = NumberFormatter.appCurrency.string(from: NSNumber(value: qs.amountPaid)) ?? "$0"
                Text("Paid: \(paidFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func totalRow(_ status: EstimatedTaxStatus) -> some View {
        HStack {
            Text("Total")
                .font(.subheadline.bold())
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                let projFormatted = NumberFormatter.appCurrency.string(from: NSNumber(value: status.projectedAnnualTax)) ?? "$0"
                Text("Projected: \(projFormatted)")
                    .font(.subheadline.monospacedDigit())
                let paidFormatted = NumberFormatter.appCurrency.string(from: NSNumber(value: status.totalPaidYTD)) ?? "$0"
                Text("Paid YTD: \(paidFormatted)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if status.remainingDue > 0 {
                    let remFormatted = NumberFormatter.appCurrency.string(from: NSNumber(value: status.remainingDue)) ?? "$0"
                    Text("Remaining: \(remFormatted)")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Projection

    private func projectionCard(_ status: EstimatedTaxStatus) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Based on year-to-date income annualized to a full year. Includes federal income tax, self-employment tax, and estimated state tax.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Projections update automatically as you record transactions. Actual tax liability may differ based on deductions, credits, and other factors.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } label: {
            Label("About This Projection", systemImage: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func alertIcon(_ type: EstimatedTaxAlert.AlertType) -> String {
        switch type {
        case .underpayment: return "exclamationmark.triangle.fill"
        case .pastDue: return "clock.badge.exclamationmark.fill"
        case .upcomingDeadline: return "calendar.badge.exclamationmark"
        case .safeHarborRisk: return "shield.slash"
        case .onTrack: return "checkmark.seal.fill"
        case .overpayment: return "arrow.up.circle.fill"
        }
    }

    private func severityColor(_ severity: BasisAlert.AlertSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func refreshStatus() {
        status = EstimatedTaxAlertService.shared.computeStatus(
            taxYear: selectedYear,
            transactions: allTransactions,
            taxSettings: taxSettings,
            modelContext: modelContext
        )
    }

    private func generateAndShareVouchers() {
        guard let status else { return }
        voucherPDFData = EstimatedTaxVoucherService.shared.generateVoucherPDF(
            taxYear: selectedYear,
            quarterlyStatuses: status.quarterlyStatuses,
            taxpayerName: "Taxpayer",
            address: nil
        )
        if voucherPDFData != nil {
            showingShareSheet = true
        }
    }
}
