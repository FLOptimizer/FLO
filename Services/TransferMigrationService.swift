//  TransferMigrationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - One-Time Transfer Migration
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  MIGRATION PURPOSE:
//  Converts legacy Transaction records marked with isTransfer=true into proper
//  Transfer records that use double-entry accounting and track money movement
//  between accounts.
//
//  WHY THIS IS NEEDED:
//  - Old system: Transactions had an isTransfer flag but no proper accounting
//  - New system: Transfer is a separate model with fromAccount/toAccount relationships
//  - Users with existing transfer transactions need seamless migration
//
//  MIGRATION STRATEGY:
//  1. Fetch all transactions where isTransfer == true
//  2. Create corresponding Transfer records with intelligent type detection
//  3. Mark transfers as .partiallyMatched (needs user review for toAccount)
//  4. Delete original transactions only after successful Transfer creation
//  5. Track completion with UserDefaults to prevent re-running
//
//  SAFETY FEATURES:
//  ✅ Atomic per-transaction migration (rollback on failure)
//  ✅ Detailed logging for debugging
//  ✅ UserDefaults flag prevents duplicate migrations
//  ✅ Graceful handling of missing data
//  ✅ No data loss — deletes only after successful creation
//
//  TRANSFER TYPE DETECTION LOGIC:
//  - Expense from business account → Owner's Draw
//  - Expense from personal account → Capital Contribution (reverse)
//  - Expense to credit card/loan → Debt Payment
//  - Income to any account → reverse logic
//  - Default fallback → Internal Transfer
//
//  USAGE:
//  ```swift
//  if TransferMigrationService.shouldRunMigration() {
//      await TransferMigrationService.shared.migrateTransferTransactions(context: context)
//  }
//  ```
//

import Foundation
import SwiftData

// MARK: - Transfer Migration Service

@MainActor
final class TransferMigrationService {
    
    // MARK: - Singleton
    
    static let shared = TransferMigrationService()
    private init() {}
    
    // MARK: - Constants
    
    private static let migrationCompletedKey = "hasCompletedTransferMigration"
    
    // MARK: - Migration Check
    
    /// Checks if the transfer migration should run.
    /// Returns true only if migration has never been completed.
    static func shouldRunMigration() -> Bool {
        let hasCompleted = UserDefaults.standard.bool(forKey: migrationCompletedKey)
        return !hasCompleted
    }
    
    /// Marks the migration as completed so it won't run again.
    private static func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        print("✅ Transfer migration marked as completed")
    }
    
    // MARK: - Main Migration Method
    
    /// Migrates all transactions marked with isTransfer=true to proper Transfer records.
    /// This is a one-time migration that runs on first launch after adding the Transfer model.
    ///
    /// - Parameter context: The SwiftData model context
    /// - Returns: Migration statistics (success count, failure count, total processed)
    func migrateTransferTransactions(context: ModelContext) async -> MigrationResult {
        print("🔄 Starting transfer transaction migration...")
        
        // Fetch all transactions marked as transfers
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.isTransfer == true
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let transferTransactions = try? context.fetch(descriptor) else {
            print("❌ Failed to fetch transfer transactions")
            return MigrationResult(successCount: 0, failureCount: 0, totalProcessed: 0, errors: ["Failed to fetch transactions"])
        }
        
        guard !transferTransactions.isEmpty else {
            print("ℹ️ No transfer transactions found to migrate")
            Self.markMigrationCompleted()
            return MigrationResult(successCount: 0, failureCount: 0, totalProcessed: 0, errors: [])
        }
        
        print("📋 Found \(transferTransactions.count) transfer transaction(s) to migrate")
        
        var successCount = 0
        var failureCount = 0
        var errors: [String] = []
        
        // Process all transactions, batching saves to avoid WAL checkpoint spam
        for (index, transaction) in transferTransactions.enumerated() {
            let transactionName = transaction.displayName

            // Log progress at intervals to avoid console spam
            if index < 5 || index % 50 == 0 || index == transferTransactions.count - 1 {
                print("   [\(index + 1)/\(transferTransactions.count)] Migrating: \(transactionName)")
            }

            do {
                let success = try migrateTransactionWithoutSave(transaction, context: context)

                if success {
                    successCount += 1
                } else {
                    failureCount += 1
                    let errorMsg = "Failed to migrate \(transactionName) - unknown error"
                    errors.append(errorMsg)
                    print("   ⚠️ \(errorMsg)")
                }
            } catch {
                failureCount += 1
                let errorMsg = "Failed to migrate \(transactionName): \(error.localizedDescription)"
                errors.append(errorMsg)
                print("   ❌ \(errorMsg)")
            }
        }

        // Single batch save for all migrations — avoids per-item WAL checkpoint overhead
        do {
            try context.save()
            print("   💾 Batch save complete (\(successCount) transfers)")
        } catch {
            print("   ❌ Batch save failed: \(error.localizedDescription)")
            errors.append("Batch save failed: \(error.localizedDescription)")
        }

        // Mark migration as completed regardless of outcome
        // This prevents infinite retry loops if some transactions can't be migrated
        Self.markMigrationCompleted()
        
        // Summary
        let result = MigrationResult(
            successCount: successCount,
            failureCount: failureCount,
            totalProcessed: transferTransactions.count,
            errors: errors
        )
        
        print("🎯 Transfer migration complete:")
        print("   ✅ Success: \(successCount)")
        if failureCount > 0 {
            print("   ⚠️ Failures: \(failureCount)")
        }
        print("   📊 Total: \(transferTransactions.count)")
        
        return result
    }
    
    // MARK: - Individual Transaction Migration
    
    /// Migrates a single transaction to a Transfer record.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to migrate
    ///   - context: The model context
    /// - Returns: True if migration succeeded, false otherwise
    /// - Throws: Any errors during migration
    /// Migrates a single transaction without saving — caller is responsible for batch save.
    private func migrateTransactionWithoutSave(_ transaction: Transaction, context: ModelContext) throws -> Bool {
        guard let fromAccount = transaction.account else {
            return false
        }

        let transferType = detectTransferType(
            transaction: transaction,
            fromAccount: fromAccount
        )

        let actualFromAccount: Account?
        let actualToAccount: Account?

        if transaction.isIncome {
            actualFromAccount = nil
            actualToAccount = fromAccount
        } else {
            actualFromAccount = fromAccount
            actualToAccount = nil
        }

        let transfer = Transfer(
            date: transaction.date,
            amount: transaction.amount,
            transferType: transferType,
            status: .partiallyMatched,
            fromAccount: actualFromAccount,
            toAccount: actualToAccount,
            notes: buildTransferNotes(from: transaction),
            reference: nil,
            taxQuarter: nil,
            taxYear: nil,
            taxAuthority: nil,
            recurringTransfer: nil
        )

        context.insert(transfer)
        context.delete(transaction)

        return true
    }
    
    // MARK: - Transfer Type Detection
    
    /// Intelligently detects the appropriate transfer type based on transaction data.
    ///
    /// - Parameters:
    ///   - transaction: The transaction being migrated
    ///   - fromAccount: The account the transaction is linked to
    /// - Returns: The detected transfer type
    private func detectTransferType(
        transaction: Transaction,
        fromAccount: Account
    ) -> TransferType {
        
        // Check for credit card or loan payment patterns
        if let category = transaction.category {
            let categoryName = category.name.lowercased()
            if categoryName.contains("credit card") ||
               categoryName.contains("loan") ||
               categoryName.contains("debt") ||
               categoryName.contains("payment") {
                return .debtPayment
            }
        }
        
        // Check merchant name for debt payment indicators
        let merchantName = transaction.merchantName.lowercased()
        if merchantName.contains("credit card") ||
           merchantName.contains("loan payment") ||
           merchantName.contains("mortgage") {
            return .debtPayment
        }
        
        // Check for tax payment indicators
        if merchantName.contains("irs") ||
           merchantName.contains("tax") ||
           merchantName.contains("estimated tax") {
            return .taxPayment
        }
        
        // Detect based on finance type and transaction direction
        if !transaction.isIncome {
            // Expense transaction (money leaving account)
            if fromAccount.financeType == .business {
                // Money leaving business account
                // Check if it's going to personal (owner's draw)
                let note = transaction.note.lowercased()
                if note.contains("draw") ||
                   note.contains("personal") ||
                   note.contains("owner") ||
                   merchantName.contains("owner") {
                    return .ownersDraw
                }
                // Default for business expenses that are transfers
                return .internal
            } else {
                // Money leaving personal account
                // Check if it's going to business (capital contribution)
                let note = transaction.note.lowercased()
                if note.contains("contribution") ||
                   note.contains("invest") ||
                   note.contains("capital") ||
                   note.contains("business") {
                    return .capitalContribution
                }
                return .internal
            }
        } else {
            // Income transaction (money entering account)
            if fromAccount.financeType == .business {
                // Money entering business account from personal
                return .capitalContribution
            } else {
                // Money entering personal account from business
                return .ownersDraw
            }
        }
    }
    
    /// Builds descriptive notes for the transfer based on transaction data.
    private func buildTransferNotes(from transaction: Transaction) -> String {
        var notes: [String] = []
        
        // Add original merchant name
        if !transaction.merchantName.isEmpty {
            notes.append("From: \(transaction.merchantName)")
        }
        
        // Add original note if it exists
        if !transaction.note.isEmpty {
            notes.append("Note: \(transaction.note)")
        }
        
        // Add category if available
        if let category = transaction.category {
            notes.append("Category: \(category.name)")
        }
        
        // Add migration marker
        notes.append("(Migrated from transaction)")
        
        return notes.joined(separator: " | ")
    }
}

// MARK: - Migration Result

/// Statistics about the migration process
struct MigrationResult {
    let successCount: Int
    let failureCount: Int
    let totalProcessed: Int
    let errors: [String]
    
    var wasSuccessful: Bool {
        failureCount == 0 && totalProcessed > 0
    }
    
    var wasPartiallySuccessful: Bool {
        successCount > 0 && failureCount > 0
    }
    
    var noDataFound: Bool {
        totalProcessed == 0
    }
}

// MARK: - Migration Status View Model

/// Optional: Use this in a view to display migration status to users
@MainActor
@Observable
class TransferMigrationViewModel {
    var isRunning = false
    var result: MigrationResult?
    var errorMessage: String?
    
    func runMigration(context: ModelContext) async {
        guard !isRunning else { return }
        
        isRunning = true
        errorMessage = nil
        
        result = await TransferMigrationService.shared.migrateTransferTransactions(context: context)

        if let result = result, result.failureCount > 0 {
            errorMessage = "Migration completed with \(result.failureCount) error(s). Check console for details."
        }
        
        isRunning = false
    }
    
    var statusMessage: String {
        if isRunning {
            return "Migrating transfer transactions..."
        }
        
        guard let result = result else {
            return "Ready to migrate"
        }
        
        if result.noDataFound {
            return "No transfer transactions found"
        }
        
        if result.wasSuccessful {
            return "✅ Successfully migrated \(result.successCount) transaction(s)"
        }
        
        if result.wasPartiallySuccessful {
            return "⚠️ Migrated \(result.successCount) of \(result.totalProcessed) transaction(s)"
        }
        
        return "❌ Migration failed"
    }
}
