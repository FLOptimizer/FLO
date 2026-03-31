//  AccountBalanceService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 — Anchor-Based Balance Reconciliation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 — Anchor-Based Balance Reconciliation:
//  ✅ UPDATED: calculateBalance(for:) accepts optional anchors parameter
//  ✅ UPDATED: calculateBalance(for:asOf:) uses anchor as starting point when available
//  ✅ UPDATED: generateSummary() passes anchors through to calculateBalance()
//  ✅ NOTE: anchors parameter defaults to empty array — preserves backward compatibility
//  ✅ NOTE: No anchors = legacy behavior (startingBalance + all transactions)
//
//  CHANGES v1.1 — Transfer Exclusion:
//  ✅ FIXED: generateSummary() excludes transfers from totalIncome/totalExpenses
//  ✅ FIXED: generateCashFlow() excludes transfers from inflows/outflows
//  ✅ KEPT: calculateBalance() methods INCLUDE transfers (real money movement)
//  ✅ NOTE: Balance calculations must include transfers because account balances
//    genuinely change when money moves between accounts.
//    Only P&L/income/expense summaries should exclude transfers.
//
//  FEATURES:
//  ✅ Real-time balance calculation based on transactions
//  ✅ Balance at specific point in time
//  ✅ Balance change tracking (period over period)
//  ✅ Reconciliation helpers
//  ✅ Net worth calculation across all accounts
//  ✅ Cash flow analysis
//

import Foundation
import SwiftData

// MARK: - Balance Snapshot

/// Represents account balance at a specific point in time
struct BalanceSnapshot: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let balance: Double
    let accountId: UUID
    let accountName: String
}

// MARK: - Account Balance Summary

/// Summary of an account's financial activity
struct AccountBalanceSummary: Identifiable {
    let id: UUID
    let accountName: String
    let accountType: AccountType
    let financeType: Transaction.FinanceType
    
    let startingBalance: Double
    let currentBalance: Double
    let calculatedBalance: Double
    
    let totalIncome: Double
    let totalExpenses: Double
    let netChange: Double
    
    let transactionCount: Int
    let lastActivity: Date?
    
    var discrepancy: Double {
        currentBalance - calculatedBalance
    }
    
    var isReconciled: Bool {
        abs(discrepancy) < 0.01
    }
    
    var changePercentage: Double {
        guard startingBalance != 0 else { return 0 }
        return ((calculatedBalance - startingBalance) / abs(startingBalance)) * 100
    }
}

// MARK: - Net Worth Summary

/// Summary of overall financial position
struct NetWorthSummary {
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    
    let liquidAssets: Double      // Checking, Savings, Cash
    let investmentAssets: Double  // Investment accounts
    let creditDebt: Double        // Credit cards
    let loanDebt: Double          // Loans, mortgages
    
    let businessAssets: Double
    let businessLiabilities: Double
    let personalAssets: Double
    let personalLiabilities: Double
    
    var businessNetWorth: Double {
        businessAssets - businessLiabilities
    }
    
    var personalNetWorth: Double {
        personalAssets - personalLiabilities
    }
    
    var debtToAssetRatio: Double {
        guard totalAssets > 0 else { return 0 }
        return totalLiabilities / totalAssets
    }
}

// MARK: - Cash Flow Summary

/// Cash flow analysis for a period
struct CashFlowSummary: Identifiable {
    let id = UUID()
    let period: String
    let startDate: Date
    let endDate: Date
    
    let openingBalance: Double
    let closingBalance: Double
    
    let totalInflows: Double
    let totalOutflows: Double
    let netCashFlow: Double
    
    let businessInflows: Double
    let businessOutflows: Double
    let personalInflows: Double
    let personalOutflows: Double
    
    var cashFlowIsPositive: Bool {
        netCashFlow >= 0
    }
}

// MARK: - Account Balance Service

@MainActor
final class AccountBalanceService {
    
    static let shared = AccountBalanceService()
    
    private init() {}
    
    // MARK: - Balance Calculations
    
    /// Calculate the current balance for an account using anchor-based reconciliation.
    /// If no anchors are provided, falls back to startingBalance + all transactions (legacy).
    ///
    /// - Parameters:
    ///   - account: The account to calculate balance for
    ///   - anchors: BalanceAnchors to use for reconciliation. Defaults to empty (legacy behavior).
    /// - Returns: The calculated balance
    func calculateBalance(for account: Account, anchors: [BalanceAnchor] = []) -> Double {
        let (anchorDate, anchorBalance) = account.effectiveAnchor(from: anchors)
        let transactions = account.transactions ?? []

        // Only count transactions AFTER the anchor date
        let postAnchorTransactions = anchors.isEmpty
            ? transactions  // No anchors = legacy behavior (all transactions from startingBalance)
            : transactions.filter { $0.date > anchorDate }

        let income = postAnchorTransactions
            .filter { $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }

        let expenses = postAnchorTransactions
            .filter { !$0.isIncome }
            .reduce(0.0) { $0 + $1.amount }

        return anchorBalance + income - expenses
    }
    
    /// Calculate balance at a specific date, using anchors when available.
    ///
    /// When `asOf` is after the anchor: anchor balance + post-anchor transactions up to `asOf`.
    /// When `asOf` is before the anchor (or no anchors): legacy startingBalance + all transactions up to `asOf`.
    func calculateBalance(for account: Account, asOf date: Date, anchors: [BalanceAnchor] = []) -> Double {
        let (anchorDate, anchorBalance) = account.effectiveAnchor(from: anchors)
        let transactions = account.transactions ?? []

        if !anchors.isEmpty && date >= anchorDate {
            // Post-anchor: count only transactions between anchor and asOf
            let relevantTransactions = transactions.filter {
                $0.date > anchorDate && $0.date <= date
            }

            let income = relevantTransactions
                .filter { $0.isIncome }
                .reduce(0.0) { $0 + $1.amount }

            let expenses = relevantTransactions
                .filter { !$0.isIncome }
                .reduce(0.0) { $0 + $1.amount }

            return anchorBalance + income - expenses
        } else {
            // Pre-anchor or no anchors: legacy behavior
            let relevantTransactions = transactions.filter { $0.date <= date }

            let income = relevantTransactions
                .filter { $0.isIncome }
                .reduce(0.0) { $0 + $1.amount }

            let expenses = relevantTransactions
                .filter { !$0.isIncome }
                .reduce(0.0) { $0 + $1.amount }

            return account.startingBalance + income - expenses
        }
    }
    
    /// Get balance change for a period
    func balanceChange(for account: Account, from startDate: Date, to endDate: Date) -> Double {
        let transactions = account.transactions ?? []
        
        let periodTransactions = transactions.filter {
            $0.date >= startDate && $0.date <= endDate
        }
        
        let income = periodTransactions
            .filter { $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let expenses = periodTransactions
            .filter { !$0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        return income - expenses
    }
    
    // MARK: - Account Summary
    
    /// Generate comprehensive balance summary for an account
    func generateSummary(for account: Account, anchors: [BalanceAnchor] = []) -> AccountBalanceSummary {
        let transactions = account.transactions ?? []
        
        // v1.1: Exclude transfers from income/expense display totals
        // Transfers are real money movement but are NOT income or expenses
        let nonTransferTransactions = transactions.filter { !$0.isTransfer }
        
        let totalIncome = nonTransferTransactions
            .filter { $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let totalExpenses = nonTransferTransactions
            .filter { !$0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let netChange = totalIncome - totalExpenses
        
        // Balance uses ALL transactions (including transfers) because
        // account balances genuinely change when money moves
        let calculatedBalance = calculateBalance(for: account, anchors: anchors)
        
        let lastActivity = transactions.max(by: { $0.date < $1.date })?.date
        
        return AccountBalanceSummary(
            id: account.id,
            accountName: account.name,
            accountType: account.accountType,
            financeType: account.financeType,
            startingBalance: account.startingBalance,
            currentBalance: account.currentBalance,
            calculatedBalance: calculatedBalance,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netChange: netChange,
            transactionCount: transactions.count,
            lastActivity: lastActivity
        )
    }
    
    // MARK: - Net Worth Calculations
    
    /// Calculate net worth across all accounts
    func calculateNetWorth(accounts: [Account]) -> NetWorthSummary {
        let activeAccounts = accounts.filter { $0.isActive }
        
        // Total assets and liabilities
        let assets = activeAccounts.filter { $0.isAsset }
        let liabilities = activeAccounts.filter { $0.isLiability }
        
        let totalAssets = assets.reduce(0.0) { $0 + $1.currentBalance }
        let totalLiabilities = liabilities.reduce(0.0) { $0 + abs($1.currentBalance) }
        
        // Liquid vs Investment
        let liquidTypes: [AccountType] = [.checking, .savings, .cash]
        let liquidAssets = assets
            .filter { liquidTypes.contains($0.accountType) }
            .reduce(0.0) { $0 + $1.currentBalance }
        
        let investmentAssets = assets
            .filter { $0.accountType == .investment }
            .reduce(0.0) { $0 + $1.currentBalance }
        
        // Debt breakdown
        let creditDebt = liabilities
            .filter { $0.accountType == .creditCard }
            .reduce(0.0) { $0 + abs($1.currentBalance) }
        
        let loanDebt = liabilities
            .filter { $0.accountType == .loan }
            .reduce(0.0) { $0 + abs($1.currentBalance) }
        
        // Business vs Personal
        let businessAssets = assets
            .filter { $0.financeType == .business }
            .reduce(0.0) { $0 + $1.currentBalance }
        
        let businessLiabilities = liabilities
            .filter { $0.financeType == .business }
            .reduce(0.0) { $0 + abs($1.currentBalance) }
        
        let personalAssets = assets
            .filter { $0.financeType == .personal }
            .reduce(0.0) { $0 + $1.currentBalance }
        
        let personalLiabilities = liabilities
            .filter { $0.financeType == .personal }
            .reduce(0.0) { $0 + abs($1.currentBalance) }
        
        return NetWorthSummary(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities,
            liquidAssets: liquidAssets,
            investmentAssets: investmentAssets,
            creditDebt: creditDebt,
            loanDebt: loanDebt,
            businessAssets: businessAssets,
            businessLiabilities: businessLiabilities,
            personalAssets: personalAssets,
            personalLiabilities: personalLiabilities
        )
    }
    
    // MARK: - Cash Flow Analysis
    
    /// Generate cash flow summary for a period
    func generateCashFlow(
        accounts: [Account],
        transactions: [Transaction],
        from startDate: Date,
        to endDate: Date,
        periodLabel: String
    ) -> CashFlowSummary {
        
        // Filter transactions for the period
        // v1.1: Exclude transfers — moving between your own accounts isn't cash flow
        let periodTransactions = transactions.filter {
            $0.date >= startDate && $0.date <= endDate && !$0.isTransfer
        }
        
        // Calculate opening balance (sum of all account balances as of start date)
        var openingBalance: Double = 0
        for account in accounts.filter({ $0.isActive }) {
            openingBalance += calculateBalance(for: account, asOf: startDate)
        }
        
        // Calculate inflows and outflows
        let inflows = periodTransactions
            .filter { $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let outflows = periodTransactions
            .filter { !$0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        // Business vs Personal breakdown
        let businessInflows = periodTransactions
            .filter { $0.isIncome && $0.financeType == .business }
            .reduce(0.0) { $0 + $1.amount }
        
        let businessOutflows = periodTransactions
            .filter { !$0.isIncome && $0.financeType == .business }
            .reduce(0.0) { $0 + $1.amount }
        
        let personalInflows = periodTransactions
            .filter { $0.isIncome && $0.financeType == .personal }
            .reduce(0.0) { $0 + $1.amount }
        
        let personalOutflows = periodTransactions
            .filter { !$0.isIncome && $0.financeType == .personal }
            .reduce(0.0) { $0 + $1.amount }
        
        let netCashFlow = inflows - outflows
        let closingBalance = openingBalance + netCashFlow
        
        return CashFlowSummary(
            period: periodLabel,
            startDate: startDate,
            endDate: endDate,
            openingBalance: openingBalance,
            closingBalance: closingBalance,
            totalInflows: inflows,
            totalOutflows: outflows,
            netCashFlow: netCashFlow,
            businessInflows: businessInflows,
            businessOutflows: businessOutflows,
            personalInflows: personalInflows,
            personalOutflows: personalOutflows
        )
    }
    
    // MARK: - Balance History
    
    /// Generate daily balance snapshots for an account over a period
    func generateBalanceHistory(
        for account: Account,
        from startDate: Date,
        to endDate: Date
    ) -> [BalanceSnapshot] {
        var snapshots: [BalanceSnapshot] = []
        var currentDate = startDate
        let calendar = Calendar.current
        
        while currentDate <= endDate {
            let balance = calculateBalance(for: account, asOf: currentDate)
            let snapshot = BalanceSnapshot(
                date: currentDate,
                balance: balance,
                accountId: account.id,
                accountName: account.name
            )
            snapshots.append(snapshot)
            
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
        
        return snapshots
    }
    
    // MARK: - Reconciliation
    
    /// Check if account balance matches calculated balance
    func checkReconciliation(for account: Account) -> (isReconciled: Bool, discrepancy: Double) {
        let calculated = calculateBalance(for: account)
        let discrepancy = account.currentBalance - calculated
        let isReconciled = abs(discrepancy) < 0.01
        return (isReconciled, discrepancy)
    }
    
    /// Update account balance to match calculated value
    func reconcileAccount(_ account: Account) {
        let calculated = calculateBalance(for: account)
        account.updateBalance(calculated)
    }
    
    /// Get accounts that need reconciliation
    func accountsNeedingReconciliation(accounts: [Account]) -> [Account] {
        accounts.filter { account in
            let (isReconciled, _) = checkReconciliation(for: account)
            return !isReconciled
        }
    }
}

// MARK: - Formatting Helpers

extension AccountBalanceService {
    
    /// Format currency value
    func formatCurrency(_ value: Double) -> String {
        return NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    /// Format percentage
    func formatPercentage(_ value: Double) -> String {
        return NumberFormatter.appPercent.string(from: NSNumber(value: value / 100)) ?? "0%"
    }
}
