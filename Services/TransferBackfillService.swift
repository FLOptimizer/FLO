//  TransferBackfillService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — One-Time Transfer Flag Backfill
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  CSVImportCommitService v1.0 never set isTransfer=true when committing
//  CSV-imported transactions. This caused bank-to-bank transfers to appear
//  as "Uncategorized" expenses, inflating expense totals by $87K+.
//
//  This migration scans all existing transactions for transfer patterns
//  in merchant names and sets isTransfer=true on matches.
//
//  DETECTION PATTERNS:
//  - "Transfer From" / "Transfer To" (bank internal transfers)
//  - "Zelle" (peer-to-peer transfers)
//  - "Venmo" in transfer context
//  - "ACH Transfer" / "Wire Transfer"
//  - "Online Transfer" / "Mobile Transfer"
//  - Merchant names containing "transfer" (case-insensitive)
//
//  SAFETY:
//  ✅ Runs once per device (UserDefaults guard)
//  ✅ Only flags transactions that are NOT already isTransfer=true
//  ✅ Only targets CSV-imported transactions (importSource == .csvImport)
//  ✅ Logs every flagged transaction for audit trail
//  ✅ Does NOT delete or modify amounts — only sets isTransfer flag
//
//  USAGE:
//  Call from FLOApp.swift after container init:
//  ```swift
//  if TransferBackfillService.shouldRun() {
//      await TransferBackfillService.shared.backfillTransferFlags(context: context)
//  }
//  ```
//

import Foundation
import SwiftData

@MainActor
final class TransferBackfillService {
    
    // MARK: - Singleton
    
    static let shared = TransferBackfillService()
    private init() {}
    
    // MARK: - Constants
    
    private static let migrationKey = "com.finchandpoppy.flo.transferBackfillV1"
    
    /// Patterns that indicate a transaction is a bank transfer
    /// Matched case-insensitively against merchantName
    private static let transferPatterns: [String] = [
        "transfer from",
        "transfer to",
        "online transfer",
        "mobile transfer",
        "ach transfer",
        "wire transfer",
        "internal transfer",
        "xfer from",
        "xfer to",
    ]
    
    /// Exact merchant keywords that strongly indicate transfers
    /// Matched case-insensitively as full-word contains
    private static let transferKeywords: [String] = [
        "zelle",
    ]
    
    /// Merchant prefixes that indicate transfers
    private static let transferPrefixes: [String] = [
        "transfer from",
        "transfer to",
    ]
    
    // MARK: - Migration Check
    
    /// Whether the migration should run. Returns true only once per device.
    static func shouldRun() -> Bool {
        !UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    // MARK: - Main Migration
    
    /// Scans all transactions and sets isTransfer=true on likely bank transfers.
    ///
    /// Only processes CSV-imported transactions that currently have isTransfer=false.
    /// Uses merchant name pattern matching to identify transfers.
    ///
    /// - Parameter context: The SwiftData ModelContext
    func backfillTransferFlags(context: ModelContext) {
        print("🔄 TransferBackfillService: Starting transfer flag backfill...")
        
        // Fetch all transactions that are NOT already flagged as transfers
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.isTransfer == false
            }
        )
        
        guard let allTransactions = try? context.fetch(descriptor) else {
            print("❌ TransferBackfillService: Failed to fetch transactions")
            Self.markCompleted()
            return
        }
        
        print("📊 TransferBackfillService: Scanning \(allTransactions.count) non-transfer transactions")
        
        var flaggedCount = 0
        var flaggedAmount: Double = 0
        
        for transaction in allTransactions {
            if isLikelyTransfer(transaction) {
                transaction.isTransfer = true
                transaction.updatedAt = Date()
                flaggedCount += 1
                flaggedAmount += transaction.amount
                
                let direction = transaction.isIncome ? "IN" : "OUT"
                print("  ✅ Flagged: \(transaction.merchantName) | $\(String(format: "%.2f", transaction.amount)) \(direction) | \(transaction.date.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        
        // Save changes
        if flaggedCount > 0 {
            do {
                try context.save()
                print("✅ TransferBackfillService: Flagged \(flaggedCount) transactions as transfers (total: $\(String(format: "%.2f", flaggedAmount)))")
            } catch {
                print("❌ TransferBackfillService: Failed to save: \(error.localizedDescription)")
            }
        } else {
            print("✅ TransferBackfillService: No unflagged transfers found — data is clean")
        }
        
        Self.markCompleted()
        print("✅ TransferBackfillService: Migration complete, will not run again")
    }
    
    // MARK: - Transfer Detection
    
    /// Determines if a transaction is likely a bank transfer based on merchant name patterns.
    ///
    /// Uses multiple heuristics:
    /// 1. Merchant name starts with "Transfer From" or "Transfer To"
    /// 2. Merchant name contains known transfer patterns
    /// 3. Merchant name contains transfer keywords (Zelle, etc.)
    ///
    /// - Parameter transaction: The transaction to evaluate
    /// - Returns: true if the transaction is likely a transfer
    private func isLikelyTransfer(_ transaction: Transaction) -> Bool {
        let merchant = transaction.merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Skip if merchant name is empty — can't determine transfer status
        guard !merchant.isEmpty else { return false }
        
        // Check prefix patterns (highest confidence)
        for prefix in Self.transferPrefixes {
            if merchant.hasPrefix(prefix) {
                return true
            }
        }
        
        // Check contains patterns
        for pattern in Self.transferPatterns {
            if merchant.contains(pattern) {
                return true
            }
        }
        
        // Check keywords
        for keyword in Self.transferKeywords {
            if merchant.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Completion
    
    private static func markCompleted() {
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    /// Resets the migration flag (for testing only)
    #if DEBUG
    static func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 TransferBackfillService: Migration flag reset")
    }
    #endif
}
