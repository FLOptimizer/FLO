//  CSVImportCommitService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 — Reconciliation-Aware Balance Adjustment
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 — Reconciliation-Aware Balance Adjustment:
//  ✅ ADDED: reconciliationChoice parameter to commitImport()
//  ✅ REPLACED: Blind `currentBalance += balanceChange` with ReconciliationService.applyReconciliation()
//  ✅ NOTE: Backward-compatible — callers can use default .adjustBalance for legacy behavior
//
//  CHANGES v1.1 — Transfer Exclusion Fix:
//  ✅ FIXED: Now passes parsed.isTransfer to Transaction init
//  ✅ ROOT CAUSE: CSV-imported transfers were created with isTransfer=false (default)
//  ✅ This caused $87K+ in bank transfers to appear as "Uncategorized" expenses
//
//  Commits approved CSV-parsed transactions into SwiftData as
//  real Transaction objects. Updates account balances and learns
//  merchant-to-category mappings for future imports.
//

import Foundation
import SwiftData
import os.log

@MainActor
final class CSVImportCommitService {
    static let shared = CSVImportCommitService()
    private init() {}
    
    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CSVImportCommit"
    )
    
    // MARK: - Primary Commit Method
    
    /// Commits selected parsed transactions to SwiftData.
    ///
    /// - Parameters:
    ///   - transactions: All parsed transactions (selected + unselected)
    ///   - targetAccount: Optional account to assign all transactions to
    ///   - defaultFinanceType: Fallback finance type if transaction has none
    ///   - reconciliationChoice: How imported transactions should affect account balance
    ///   - context: The SwiftData ModelContext to insert into
    /// - Returns: .success(count) or .failure(error)
    ///
    func commitImport(
        transactions: [CSVParsedTransaction],
        targetAccount: Account?,
        defaultFinanceType: Transaction.FinanceType,
        reconciliationChoice: ReconciliationService.ReconciliationChoice = .adjustBalance,
        context: ModelContext
    ) -> Result<Int, Error> {
        // Step 1: Filter to selected transactions only
        let selected = transactions.filter { $0.isSelected }
        
        guard !selected.isEmpty else {
            Self.logger.warning("commitImport called with no selected transactions")
            return .success(0)
        }
        
        Self.logger.info("Committing \(selected.count) of \(transactions.count) transactions")
        
        // Step 2: Track balance changes
        var balanceChange: Double = 0.0  // Net change for account
        var createdCount = 0
        
        // Step 3: Create Transaction objects (loop, no save)
        for parsed in selected {
            let transaction = Transaction(
                amount: parsed.amount,
                date: parsed.date,
                note: parsed.description,
                isIncome: parsed.isIncome,
                merchantName: parsed.merchantName,
                category: parsed.suggestedCategory,
                financeType: parsed.suggestedFinanceType,
                account: targetAccount,
                importSource: .csvImport,
                isTransfer: parsed.isTransfer
            )
            
            context.insert(transaction)
            createdCount += 1
            
            // Track balance impact
            if parsed.isIncome {
                balanceChange += parsed.amount
            } else {
                balanceChange -= parsed.amount
            }
        }
        
        Self.logger.info("Created \(createdCount) Transaction objects in context")
        
        // Step 4: Apply reconciliation choice (replaces blind balance adjustment)
        if let account = targetAccount {
            ReconciliationService.shared.applyReconciliation(
                choice: reconciliationChoice,
                account: account,
                balanceChange: balanceChange,
                importedTransactions: selected,
                context: context
            )
        }
        
        // Step 5: Learn merchant mappings
        CSVCategorizationService.shared.learnFromImport(
            committed: selected,
            context: context
        )
        
        Self.logger.info("Merchant categorization learning complete")
        
        // Step 6: Save context (once)
        do {
            try context.save()
            
            Self.logger.info(
                "Successfully committed \(createdCount) CSV transactions"
            )
            
            return .success(createdCount)
        } catch {
            Self.logger.error(
                "Failed to save CSV import: \(error.localizedDescription)"
            )
            return .failure(error)
        }
    }
}
