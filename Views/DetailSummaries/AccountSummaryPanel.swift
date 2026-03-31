//  AccountSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 contextual summary for the Accounts tab.
//  Complements Zone 2 (which already shows net worth, assets, liabilities).
//  Shows account balances bar chart with brand colors and type breakdown.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import Charts

struct AccountSummaryPanel: View {
    @Query private var accounts: [Account]

    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }

    /// Sorted by absolute balance descending, top 8
    private var accountBars: [AccountBar] {
        activeAccounts
            .sorted { abs($0.currentBalance) > abs($1.currentBalance) }
            .prefix(8)
            .map { account in
                AccountBar(
                    name: account.name,
                    balance: account.currentBalance,
                    color: barColor(for: account),
                    type: account.accountType.rawValue.capitalized
                )
            }
    }

    private var accountsByType: [(type: String, count: Int, total: Double)] {
        var map: [String: (count: Int, total: Double)] = [:]
        for account in activeAccounts {
            let typeName = account.accountType.rawValue.capitalized
            var entry = map[typeName] ?? (0, 0)
            entry.count += 1
            entry.total += account.currentBalance
            map[typeName] = entry
        }
        return map.sorted { $0.value.total > $1.value.total }
            .map { ($0.key, $0.value.count, $0.value.total) }
    }

    /// Accounts with notable status (high debt, large balance, zero balance)
    private var insights: [AccountInsight] {
        var results: [AccountInsight] = []

        let highDebt = activeAccounts
            .filter { ($0.accountType == .creditCard || $0.accountType == .loan) && abs($0.currentBalance) > 5000 }
        for account in highDebt.prefix(2) {
            results.append(AccountInsight(
                icon: "exclamationmark.triangle.fill",
                text: "\(account.name): \(formatCompact(account.currentBalance)) balance",
                style: .urgent
            ))
        }

        let zeroBalance = activeAccounts
            .filter { $0.currentBalance == 0 && $0.accountType != .creditCard }
        if zeroBalance.count > 0 {
            results.append(AccountInsight(
                icon: "info.circle",
                text: "\(zeroBalance.count) account\(zeroBalance.count == 1 ? "" : "s") at $0",
                style: .neutral
            ))
        }

        return results
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "building.columns.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandPrimary)
                    Text("Account Balances")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }

                // Account Balances Bar Chart
                if !accountBars.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Chart(accountBars) { bar in
                            BarMark(
                                x: .value("Balance", abs(bar.balance)),
                                y: .value("Account", bar.name)
                            )
                            .foregroundStyle(bar.color)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text(formatCompact(bar.balance))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .chartXAxis(.hidden)
                        .frame(height: CGFloat(accountBars.count) * 40)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Account balances chart")
                    }
                    .padding()
                    .background(Color.floSecondarySystemBackground)
                    .cornerRadius(12)
                }

                // Insights / Alerts
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(insights) { insight in
                            SummaryChip(
                                icon: insight.icon,
                                text: insight.text,
                                style: insight.style
                            )
                        }
                    }
                }

                // Account type breakdown
                if !accountsByType.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Account Type")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(accountsByType, id: \.type) { item in
                            HStack {
                                Text(item.type)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.count) acct\(item.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(item.total, format: .currency(code: "USD").precision(.fractionLength(0)))
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                                    .foregroundStyle(item.total >= 0 ? Color.incomeGreen : Color.expenseRed)
                            }
                        }
                    }
                    .padding()
                    .background(Color.floSecondarySystemBackground)
                    .cornerRadius(12)
                }

                // Active accounts count
                SummaryChip(
                    icon: "building.columns",
                    text: "\(activeAccounts.count) active account\(activeAccounts.count == 1 ? "" : "s")",
                    style: .info
                )
            }
            .padding()
        }
    }

    // MARK: - Bar Color Logic
    //
    // Three brand colors based on balance sentiment:
    //   #14B8A6 (teal/brandPrimary) — healthy positive balances
    //   #FBBF24 (warning/amber)     — small balances or moderate debt
    //   #F87171 (expenseRed)        — large liabilities

    private func barColor(for account: Account) -> Color {
        let balance = account.currentBalance
        let isDebt = account.accountType == .creditCard || account.accountType == .loan

        if isDebt {
            // Large liability (> $5k) = red, smaller = amber
            return abs(balance) > 5000 ? Color.expenseRed : Color.brandWarning
        } else {
            // Positive asset = teal, zero/negative checking = amber
            return balance > 0 ? Color.brandPrimary : Color.brandWarning
        }
    }

    private func formatCompact(_ value: Double) -> String {
        let absValue = abs(value)
        let prefix = value < 0 ? "-" : ""
        if absValue >= 1000 {
            return "\(prefix)$\(String(format: "%.1f", absValue / 1000))k"
        }
        return "\(prefix)$\(Int(absValue))"
    }
}

private struct AccountBar: Identifiable {
    let id = UUID()
    let name: String
    let balance: Double
    let color: Color
    let type: String
}

private struct AccountInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let style: SummaryChip.ChipStyle
}
