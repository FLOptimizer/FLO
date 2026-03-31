//  ReconciliationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Balance Reconciliation Service
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ CREATED: Centralized service for anchor management and import reconciliation
//  ✅ ADDED: ImportType detection — analyzes transaction dates to classify imports
//  ✅ ADDED: ReconciliationChoice — three-option model (keep/adjust/set manually)
//  ✅ ADDED: applyReconciliation() — replaces blind balance adjustment in CSV commit
//  ✅ ADDED: createAccountCreationAnchor() — initial anchor for new accounts
//  ✅ ADDED: extractStatementEndBalance() — pulls running balance from CSV data
//  ✅ ADDED: fetchAnchors() — queries anchors by account ID, sorted newest first
//

import Foundation
import SwiftData
import os.log

@MainActor
final class ReconciliationService {
    static let shared = ReconciliationService()
    private init() {}

    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "Reconciliation"
    )

    // MARK: - Import Type Detection

    /// Classification of imported transactions based on their dates
    enum ImportType {
        case historical      // Transactions are old — almost certainly already in balance
        case possiblyLive    // Recent transactions — might not be reflected yet
        case ambiguous       // Can't tell — ask the user
    }

    /// Analyze imported transactions to guess whether they're historical.
    ///
    /// - Historical: newest >7 days old AND span >30 days (bank statement export)
    /// - Possibly live: newest within 3 days
    /// - Ambiguous: everything else
    func detectImportType(transactions: [CSVParsedTransaction]) -> ImportType {
        let today = Date()
        let calendar = Calendar.current

        guard let newest = transactions.max(by: { $0.date < $1.date })?.date,
              let oldest = transactions.min(by: { $0.date < $1.date })?.date else {
            return .ambiguous
        }

        let daysSinceNewest = calendar.dateComponents([.day], from: newest, to: today).day ?? 0
        let spanDays = calendar.dateComponents([.day], from: oldest, to: newest).day ?? 0

        // Newest transaction is >7 days old AND span is >30 days
        // → Almost certainly a historical bank statement export
        if daysSinceNewest > 7 && spanDays > 30 {
            return .historical
        }

        // Newest transaction is within last 3 days
        // → Might include recent unrecorded activity
        if daysSinceNewest <= 3 {
            return .possiblyLive
        }

        return .ambiguous
    }

    // MARK: - Reconciliation Options

    /// How the user wants imported transactions to affect their balance
    enum ReconciliationChoice {
        case keepBalance           // Import for tracking only, don't move balance
        case adjustBalance         // Add net impact to current balance (current behavior)
        case setBalance(Double)    // User specifies the real balance manually
    }

    // MARK: - CSV Running Balance Extraction

    /// If the CSV has a running balance column, extract the final row's balance
    /// as a suggested anchor value.
    func extractStatementEndBalance(
        from transactions: [CSVParsedTransaction]
    ) -> (date: Date, balance: Double)? {
        // Find the last transaction with a running balance
        guard let last = transactions.last(where: { $0.runningBalance != nil }),
              let balance = last.runningBalance else {
            return nil
        }
        return (last.date, balance)
    }

    // MARK: - Apply Reconciliation Choice

    /// Apply the user's reconciliation choice after CSV import commit.
    ///
    /// Called AFTER transactions are created but BEFORE context.save().
    /// Replaces the blind `account.currentBalance += balanceChange` in CSVImportCommitService.
    func applyReconciliation(
        choice: ReconciliationChoice,
        account: Account,
        balanceChange: Double,
        importedTransactions: [CSVParsedTransaction],
        context: ModelContext
    ) {
        switch choice {
        case .keepBalance:
            // Don't touch currentBalance at all
            // Create an anchor at today's date with the current balance
            let anchor = BalanceAnchor(
                account: account,
                anchorDate: Date(),
                anchorBalance: account.currentBalance,
                source: .csvImportKeepBalance,
                notes: "Balance preserved during CSV import of \(importedTransactions.count) historical transactions"
            )
            context.insert(anchor)
            account.lastBalanceUpdate = Date()
            account.touch()

            Self.logger.info(
                "Reconciliation: Kept balance at \(String(format: "%.2f", account.currentBalance)), created anchor"
            )

        case .adjustBalance:
            // Current behavior — add net impact
            account.currentBalance += balanceChange
            account.lastBalanceUpdate = Date()
            account.touch()

            Self.logger.info(
                "Reconciliation: Adjusted balance by \(String(format: "%.2f", balanceChange))"
            )

        case .setBalance(let userBalance):
            // User typed their real balance
            let anchor = BalanceAnchor(
                account: account,
                anchorDate: Date(),
                anchorBalance: userBalance,
                source: .manualReconciliation,
                notes: "User set balance to \(String(format: "%.2f", userBalance)) during CSV import"
            )
            context.insert(anchor)
            account.currentBalance = userBalance
            account.lastBalanceUpdate = Date()
            account.touch()

            Self.logger.info(
                "Reconciliation: User set balance to \(String(format: "%.2f", userBalance)), created anchor"
            )
        }
    }

    // MARK: - Account Creation Anchor

    /// Create an implicit anchor when a new account is created.
    /// This establishes the starting balance as the first anchor point.
    func createAccountCreationAnchor(
        for account: Account,
        context: ModelContext
    ) {
        let anchor = BalanceAnchor(
            account: account,
            anchorDate: account.createdDate,
            anchorBalance: account.startingBalance,
            source: .accountCreation,
            notes: "Initial balance at account creation"
        )
        context.insert(anchor)

        Self.logger.info(
            "Created account creation anchor for '\(account.name)' at \(String(format: "%.2f", account.startingBalance))"
        )
    }

    // MARK: - Fetch Anchors

    /// Fetch all anchors for a specific account, sorted newest first.
    func fetchAnchors(for account: Account, context: ModelContext) -> [BalanceAnchor] {
        let accountID = account.id
        let descriptor = FetchDescriptor<BalanceAnchor>(
            predicate: #Predicate { $0.account?.id == accountID },
            sortBy: [SortDescriptor(\.anchorDate, order: .reverse)]
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Failed to fetch anchors: \(error.localizedDescription)")
            return []
        }
    }
}
