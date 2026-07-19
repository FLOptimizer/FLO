//  TaxSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 summary for Tax tab.
//  Shows quarterly estimate, deadline countdown, and tax breakdown.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import Charts

struct TaxSummaryPanel: View {
    @Query private var transactions: [Transaction]
    @Query private var taxSettings: [TaxSettings]

    @State private var estimate: TaxCalculationService.TaxEstimate?

    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                if let estimate {
                    // Quarterly payment hero
                    quarterlyPaymentSection(estimate)

                    // Tax breakdown chart
                    taxBreakdownChart(estimate)

                    // Deadline countdown
                    if let deadline = estimate.nextDeadline,
                       let days = estimate.daysUntilDeadline {
                        deadlineSection(deadline: deadline, days: days)
                    }

                    // Per-business breakdown (v2.0)
                    NavigationLink(value: NavigationDestination.taxBusinessSummary) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal.fill")
                                .foregroundStyle(.orange)
                            Text("Per-Business Tax Summary")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.floSystemGroupedSectionBackground)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    // Effective rates
                    ratesSection(estimate)

                    // Safe harbor status
                    if let safeHarbor = estimate.safeHarborAmount {
                        safeHarborSection(amount: safeHarbor, isMeeting: estimate.isMeetingSafeHarbor)
                    }
                } else {
                    emptyState
                }
            }
            .padding()
        }
        .task {
            calculateEstimate()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundStyle(Color.brandPrimary)
            Text("Tax Overview")
                .font(.title3.weight(.semibold))
            Spacer()
        }
    }

    // MARK: - Quarterly Payment

    private func quarterlyPaymentSection(_ est: TaxCalculationService.TaxEstimate) -> some View {
        VStack(spacing: 8) {
            SummaryHeroMetric(
                amount: est.adjustedQuarterlyPayment,
                subtitle: "Quarterly Payment Due",
                style: .branded
            )

            if est.w2WithholdingCredit > 0 {
                Text("After \(formatted(est.w2WithholdingCredit)) W-2 withholding credit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Tax Breakdown Chart

    private func taxBreakdownChart(_ est: TaxCalculationService.TaxEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tax Breakdown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let slices = taxSlices(est)

            Chart(slices, id: \.label) { slice in
                SectorMark(
                    angle: .value("Amount", slice.amount),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(slice.color)
                .cornerRadius(3)
            }
            .frame(height: 160)

            // Legend
            VStack(alignment: .leading, spacing: 6) {
                ForEach(slices, id: \.label) { slice in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(slice.color)
                            .frame(width: 8, height: 8)
                        Text(slice.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatted(slice.amount))
                            .font(.caption.monospacedDigit().weight(.medium))
                    }
                }
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Deadline

    private func deadlineSection(deadline: Date, days: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(days <= 14 ? Color.expenseRed.opacity(0.15) : Color.brandPrimary.opacity(0.15))
                    .frame(width: 48, height: 48)
                Text("\(days)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(days <= 14 ? Color.expenseRed : Color.brandPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Days Until Deadline")
                    .font(.subheadline.weight(.medium))
                Text(deadline.formatted(.dateTime.month(.wide).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if days <= 14 {
                SummaryChip(
                    icon: "exclamationmark.triangle.fill",
                    text: "Due Soon",
                    style: .urgent
                )
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Effective Rates

    private func ratesSection(_ est: TaxCalculationService.TaxEstimate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Effective Rates")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                rateItem(label: "Federal", rate: est.effectiveFederalRate, color: .blue)
                Divider().frame(height: 40)
                rateItem(label: "State", rate: est.effectiveStateRate, color: Color.brandPrimary)
                Divider().frame(height: 40)
                rateItem(label: "Total", rate: est.effectiveTotalRate, color: Color.expenseRed)
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    private func rateItem(label: String, rate: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f%%", rate * 100))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Safe Harbor

    private func safeHarborSection(amount: Double, isMeeting: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isMeeting ? "checkmark.shield.fill" : "shield.slash")
                .font(.title3)
                .foregroundStyle(isMeeting ? Color.incomeGreen : Color.brandWarning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Safe Harbor")
                    .font(.subheadline.weight(.medium))
                Text(isMeeting
                     ? "On track — paying \(formatted(amount))/year"
                     : "Need \(formatted(amount))/year to avoid penalties")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            SummaryChip(
                icon: isMeeting ? "checkmark" : "exclamationmark.triangle",
                text: isMeeting ? "Met" : "At Risk",
                style: isMeeting ? .success : .warning
            )
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.tertiary)

            Text("No tax estimate available")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Configure your tax settings and add income transactions to see estimates here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private func calculateEstimate() {
        guard !transactions.isEmpty else { return }
        estimate = TaxCalculationService.shared.calculateYearToDateEstimate(
            transactions: transactions,
            settings: settings
        )
    }

    private struct TaxSlice {
        let label: String
        let amount: Double
        let color: Color
    }

    private func taxSlices(_ est: TaxCalculationService.TaxEstimate) -> [TaxSlice] {
        var slices: [TaxSlice] = []
        if est.federalIncomeTax > 0 {
            slices.append(TaxSlice(label: "Federal Income", amount: est.federalIncomeTax, color: .blue))
        }
        if est.stateIncomeTax > 0 {
            slices.append(TaxSlice(label: "State Income", amount: est.stateIncomeTax, color: Color.brandPrimary))
        }
        if est.selfEmploymentTax > 0 {
            slices.append(TaxSlice(label: "Self-Employment", amount: est.selfEmploymentTax, color: Color.brandWarning))
        }
        if slices.isEmpty {
            slices.append(TaxSlice(label: "No Tax", amount: 1, color: Color.gray.opacity(0.3)))
        }
        return slices
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

#if DEBUG
#Preview("Tax Summary") {
    TaxSummaryPanel()
        .modelContainer(for: [Transaction.self, TaxSettings.self])
        .frame(width: 360, height: 700)
}
#endif
