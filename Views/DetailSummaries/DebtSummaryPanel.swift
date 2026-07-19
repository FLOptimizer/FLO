//  DebtSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v1.0 — Zone 3 default summary for the Debt Accelerator tab.
//  Shows a debt-at-a-glance overview (total owed, weighted APR, monthly
//  minimums), the active payoff plan's cached projection, and each debt
//  account as a tappable row that navigates to its detail.
//  Mirrors AccountSummaryPanel so the iPad/macOS right pane is populated by
//  default instead of falling through to GenericSummaryPanel.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct DebtSummaryPanel: View {
    @Query private var accounts: [Account]
    @Query(sort: \DebtAcceleratorPlan.createdDate, order: .reverse) private var plans: [DebtAcceleratorPlan]

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed Data

    private var debtAccounts: [Account] {
        accounts
            .filter { $0.isDebtAccount }
            .sorted { $0.effectiveAPR > $1.effectiveAPR }
    }

    private var totalDebt: Double {
        debtAccounts.reduce(0) { $0 + abs($1.currentBalance) }
    }

    private var totalMinimumPayments: Double {
        debtAccounts.reduce(0) { total, account in
            total + (account.minimumPaymentDue ?? account.monthlyPaymentAmount ?? 0)
        }
    }

    private var weightedAPR: Double {
        guard totalDebt > 0 else { return 0 }
        let weightedSum = debtAccounts.reduce(0.0) { $0 + abs($1.currentBalance) * $1.effectiveAPR }
        return weightedSum / totalDebt
    }

    private var activePlan: DebtAcceleratorPlan? {
        plans.first { $0.isActive }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if debtAccounts.isEmpty {
                    emptyState
                } else {
                    overviewSection

                    if let plan = activePlan, let payoffDate = plan.projectedPayoffDate {
                        planProjectionSection(plan, payoffDate: payoffDate)
                    }

                    debtListSection
                }
            }
            .padding()
        }
        .navigationTitle("Debt Overview")
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricBox(label: "Total Debt", value: fmt.string(from: NSNumber(value: totalDebt)) ?? "$0", color: .expenseRed)
                metricBox(label: "Weighted APR", value: String(format: "%.1f%%", weightedAPR), color: .brandWarning)
            }
            HStack {
                Text("Monthly Minimums")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(from: NSNumber(value: totalMinimumPayments)) ?? "$0")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.floSystemGroupedSectionBackground)
            .cornerRadius(10)
        }
    }

    private func metricBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Active Plan Projection

    private func planProjectionSection(_ plan: DebtAcceleratorPlan, payoffDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                NavigationService.shared.selectedDetail = .debtAcceleratorDetail(id: plan.id)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(Color.incomeGreen)
                        Text("Debt-free by \(payoffDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 12) {
                        if plan.projectedInterestSaved > 0 {
                            SummaryChip(
                                icon: "banknote",
                                text: "Saves \(fmt.string(from: NSNumber(value: plan.projectedInterestSaved)) ?? "$0")",
                                style: .success
                            )
                        }
                        if plan.projectedMonthsSaved > 0 {
                            SummaryChip(
                                icon: "clock.arrow.circlepath",
                                text: "\(plan.projectedMonthsSaved) mo faster",
                                style: .info
                            )
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.floSystemGroupedSectionBackground)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Debt List

    private var debtListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your Debts")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ForEach(debtAccounts) { account in
                Button {
                    NavigationService.shared.selectedDetail = .accountDetail(id: account.id)
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(account.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if account.hasActivePromo {
                                    Text("PROMO")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.brandWarning.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(account.accountType.displayName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(fmt.string(from: NSNumber(value: abs(account.currentBalance))) ?? "$0")
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(Color.expenseRed)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(String(format: "%.1f%% APR", account.effectiveAPR))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.floSystemGroupedSectionBackground)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(Color.incomeGreen)
            Text("No debt accounts")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text("Add a credit card or loan account to use the Debt Accelerator.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
