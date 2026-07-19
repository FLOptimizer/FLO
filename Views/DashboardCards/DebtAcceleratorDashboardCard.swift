//  DebtAcceleratorDashboardCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Debt Accelerator Phase 1
//  Dashboard summary card showing active debt payoff plan status.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct DebtAcceleratorDashboardCard: View {
    @Query(sort: \DebtAcceleratorPlan.createdDate, order: .reverse) private var plans: [DebtAcceleratorPlan]
    @Query private var accounts: [Account]

    private var activePlan: DebtAcceleratorPlan? {
        plans.first { $0.isActive }
    }

    private var debtAccounts: [Account] {
        accounts.filter { $0.isDebtAccount }
    }

    private var totalDebt: Double {
        debtAccounts.reduce(0) { $0 + abs($1.currentBalance) }
    }

    var body: some View {
        // Only show if user has debt accounts
        if !debtAccounts.isEmpty {
            cardContent
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Debt Accelerator")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    NavigationService.shared.navigateTo(.debtAccelerator)
                } label: {
                    Text("View")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            if let plan = activePlan {
                activePlanContent(plan)
            } else {
                noPlanContent
            }
        }
        #if os(macOS)
        .background(Color(.controlBackgroundColor))
        #else
        .background(Color(.secondarySystemGroupedBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Active Plan Content

    @ViewBuilder
    private func activePlanContent(_ plan: DebtAcceleratorPlan) -> some View {
        VStack(spacing: 12) {
            // Debt-free countdown
            if let months = plan.monthsUntilPayoff, months > 0 {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Debt-Free In")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(months)")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.green)
                            Text(months == 1 ? "month" : "months")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total Debt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(totalDebt.formatted(.currency(code: "USD")))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }

            // Savings vs minimum
            if plan.projectedInterestSaved > 0 || plan.projectedMonthsSaved > 0 {
                HStack(spacing: 16) {
                    if plan.projectedInterestSaved > 0 {
                        miniStat(
                            label: "Interest Saved",
                            value: plan.projectedInterestSaved.formatted(.currency(code: "USD")),
                            color: .green
                        )
                    }
                    if plan.projectedMonthsSaved > 0 {
                        miniStat(
                            label: "Months Saved",
                            value: "\(plan.projectedMonthsSaved)",
                            color: .blue
                        )
                    }
                    Spacer()
                }
            }

            // Strategy badge
            HStack(spacing: 6) {
                Image(systemName: plan.strategy.icon)
                    .font(.caption2)
                Text(plan.strategy.displayName)
                    .font(.caption2.weight(.medium))
                Text("+\(plan.extraMonthlyPayment.formatted(.currency(code: "USD")))/mo extra")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - No Plan Content

    private var noPlanContent: some View {
        VStack(spacing: 8) {
            Text("\(debtAccounts.count) debt account\(debtAccounts.count == 1 ? "" : "s") totaling \(totalDebt.formatted(.currency(code: "USD")))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                NavigationService.shared.selectedDetail = .createDebtPlan
                NavigationService.shared.navigateTo(.debtAccelerator)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Payoff Plan")
                }
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func miniStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

#if DEBUG
#Preview {
    VStack {
        DebtAcceleratorDashboardCard()
            .padding(.horizontal)
    }
    .modelContainer(for: [DebtAcceleratorPlan.self, Account.self])
}
#endif
