//  AccountSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — Zone 3 account analysis panel.
//  Shows net worth breakdown (assets vs liabilities), each account with
//  expandable recent transactions, reconciliation status, and tappable
//  navigation to account detail.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct AccountSummaryPanel: View {
    @Query private var accounts: [Account]

    @State private var expandedAccounts: Set<UUID> = []

    private let fmt = NumberFormatter.appCurrency
    private let balanceService = AccountBalanceService.shared

    // MARK: - Computed Data

    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }

    private var assetAccounts: [Account] {
        activeAccounts
            .filter { !isLiability($0) }
            .sorted { $0.currentBalance > $1.currentBalance }
    }

    private var liabilityAccounts: [Account] {
        activeAccounts
            .filter { isLiability($0) }
            .sorted { abs($0.currentBalance) > abs($1.currentBalance) }
    }

    private var totalAssets: Double {
        assetAccounts.filter { $0.currentBalance > 0 }.reduce(0) { $0 + $1.currentBalance }
    }

    private var totalLiabilities: Double {
        liabilityAccounts.reduce(0) { $0 + abs($1.currentBalance) }
    }

    private var netWorth: Double {
        totalAssets - totalLiabilities
    }

    private var needsReconciliation: [Account] {
        balanceService.accountsNeedingReconciliation(accounts: activeAccounts)
    }

    private func isLiability(_ account: Account) -> Bool {
        account.accountType == .creditCard || account.accountType == .loan
    }

    private func reconciliationStatus(for account: Account) -> (isReconciled: Bool, discrepancy: Double) {
        balanceService.checkReconciliation(for: account)
    }

    private func recentTransactions(for account: Account) -> [Transaction] {
        (account.transactions ?? [])
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Net worth hero
                netWorthSection

                // Reconciliation alert
                if !needsReconciliation.isEmpty {
                    SummaryChip(
                        icon: "exclamationmark.triangle.fill",
                        text: "\(needsReconciliation.count) account\(needsReconciliation.count == 1 ? "" : "s") need reconciliation",
                        style: .warning
                    )
                }

                // Assets
                if !assetAccounts.isEmpty {
                    accountGroup(title: "Assets", accounts: assetAccounts)
                }

                // Liabilities
                if !liabilityAccounts.isEmpty {
                    accountGroup(title: "Liabilities", accounts: liabilityAccounts)
                }

                if activeAccounts.isEmpty {
                    emptyState
                }
            }
            .padding()
        }
        .navigationTitle("Account Overview")
        .onAppear {
            // Auto-expand accounts needing reconciliation
            for account in needsReconciliation {
                expandedAccounts.insert(account.id)
            }
        }
    }

    // MARK: - Net Worth Section

    private var netWorthSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                metricBox(label: "Assets", amount: totalAssets, color: .incomeGreen)
                metricBox(label: "Liabilities", amount: totalLiabilities, color: .expenseRed)
            }
            // Net worth row
            HStack {
                Text("Net Worth")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(from: NSNumber(value: netWorth)) ?? "$0")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(netWorth >= 0 ? Color.incomeGreen : Color.expenseRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.floSystemGroupedSectionBackground)
            .cornerRadius(10)
        }
    }

    private func metricBox(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(fmt.string(from: NSNumber(value: amount)) ?? "$0")
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

    // MARK: - Account Group

    private func accountGroup(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ForEach(accounts) { account in
                accountSection(account)
            }
        }
    }

    // MARK: - Account Section

    private func accountSection(_ account: Account) -> some View {
        let (isReconciled, discrepancy) = reconciliationStatus(for: account)
        let txns = recentTransactions(for: account)
        let isExpanded = expandedAccounts.contains(account.id)

        return VStack(alignment: .leading, spacing: 0) {
            // Account header row — tappable to navigate
            HStack(spacing: 10) {
                // Expand/collapse recent transactions
                Button {
                    withAnimation(FLOAnimation.quick) {
                        if expandedAccounts.contains(account.id) {
                            expandedAccounts.remove(account.id)
                        } else {
                            expandedAccounts.insert(account.id)
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        // Reconciliation indicator
                        Circle()
                            .fill(isReconciled ? Color.incomeGreen : Color.brandWarning)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(account.name)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if account.isPrimary {
                                    Text("Primary")
                                        .font(.caption2)
                                        .foregroundStyle(Color.brandPrimary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.brandPrimary.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                            HStack(spacing: 4) {
                                Text(account.accountType.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                if !isReconciled {
                                    Text("· off \(fmt.string(from: NSNumber(value: abs(discrepancy))) ?? "$0")")
                                        .font(.caption)
                                        .foregroundStyle(Color.brandWarning)
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Balance + navigate to detail
                Button {
                    NavigationService.shared.selectedDetail = .accountDetail(id: account.id)
                } label: {
                    HStack(spacing: 4) {
                        Text(fmt.string(from: NSNumber(value: account.currentBalance)) ?? "$0")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isLiability(account) ? Color.expenseRed : Color.incomeGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "arrow.right.circle")
                            .font(.caption)
                            .foregroundStyle(Color.brandPrimary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Recent transactions (expanded)
            if isExpanded {
                Divider().padding(.leading, 22)

                if txns.isEmpty {
                    Text("No recent transactions")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 8)
                } else {
                    ForEach(txns) { txn in
                        Button {
                            NavigationService.shared.selectedDetail = .transactionDetail(id: txn.id)
                        } label: {
                            HStack(spacing: 10) {
                                Text(DateFormatter.shortMonthDay.string(from: txn.date))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 42, alignment: .leading)

                                Text(txn.merchantName.isEmpty ? txn.note : txn.merchantName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                Text(txn.isIncome ? "+" : "-")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(txn.isIncome ? Color.incomeGreen : Color.expenseRed)
                                Text(fmt.string(from: NSNumber(value: abs(txn.amount))) ?? "$0")
                                    .font(.caption.monospacedDigit().weight(.medium))
                                    .foregroundStyle(txn.isIncome ? Color.incomeGreen : Color.expenseRed)

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.leading, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if txn.id != txns.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }

                // Amortization schedule shortcut for loan accounts
                if account.accountType.hasLoanFields,
                   (account.apr ?? 0) > 0,
                   (account.monthlyPaymentAmount ?? 0) > 0 {
                    Divider().padding(.leading, 22)
                    Button {
                        NavigationService.shared.selectedDetail = .accountDetail(id: account.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .font(.caption)
                                .foregroundStyle(Color.brandPrimary)
                            Text("Amortization Schedule")
                                .font(.caption)
                                .foregroundStyle(Color.brandPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.leading, 8)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isReconciled ? Color.floCardBorder : Color.brandWarning.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No active accounts")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
