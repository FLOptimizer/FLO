//  ReceiptMatchingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Initial Implementation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Service for automatic receipt-to-transaction matching
//  Designed to work with both manual transactions AND Plaid imports
//
//  FEATURES:
//  ✅ Find unmatched receipts with potential transaction matches
//  ✅ Background matching when new receipts/transactions added
//  ✅ Pending match count for UI badges
//  ✅ Batch matching for efficiency
//  ✅ Plaid-ready: works with any Transaction source
//

import Foundation
import SwiftData
import Combine

// MARK: - Pending Match Model

/// Represents a receipt that has potential transaction matches waiting for user review
struct PendingReceiptMatch: Identifiable {
    let id: UUID
    let receipt: ReceiptData
    let potentialMatches: [TransactionMatch]
    let bestMatchScore: Double
    
    init(receipt: ReceiptData, matches: [TransactionMatch]) {
        self.id = receipt.id
        self.receipt = receipt
        self.potentialMatches = matches
        self.bestMatchScore = matches.first?.score ?? 0
    }
    
    var matchQuality: MatchQuality {
        switch bestMatchScore {
        case 0.85...: return .excellent
        case 0.70..<0.85: return .good
        case 0.50..<0.70: return .fair
        default: return .poor
        }
    }
    
    enum MatchQuality {
        case excellent  // 85%+ - Very likely the right match
        case good       // 70-84% - Probably correct
        case fair       // 50-69% - Needs review
        case poor       // <50% - Low confidence
        
        var displayText: String {
            switch self {
            case .excellent: return "Excellent Match"
            case .good: return "Good Match"
            case .fair: return "Review Needed"
            case .poor: return "Low Confidence"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

// MARK: - Receipt Matching Service

@MainActor
class ReceiptMatchingService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ReceiptMatchingService()
    
    // MARK: - Published Properties
    
    @Published private(set) var pendingMatchCount: Int = 0
    @Published private(set) var pendingMatches: [PendingReceiptMatch] = []
    @Published private(set) var isProcessing: Bool = false
    
    // MARK: - Private Properties
    
    private var lastScanDate: Date?
    private let minimumMatchScore: Double = 0.50  // Minimum score to show as potential match
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Scans all unmatched receipts for potential transaction matches
    /// Call this when:
    /// - App launches
    /// - New receipt is scanned
    /// - New transaction is added (manual or Plaid import)
    func scanForMatches(
        receipts: [ReceiptData],
        transactions: [Transaction]
    ) {
        isProcessing = true
        
        // Filter to unmatched receipts only
        let unmatchedReceipts = receipts.filter { $0.matchStatus == .unmatched }
        
        // Filter to transactions without receipts
        let availableTransactions = transactions.filter { !$0.hasReceipt && !$0.isIncome }
        
        var newPendingMatches: [PendingReceiptMatch] = []
        
        for receipt in unmatchedReceipts {
            let matches = TransactionMatchingService.shared.findPotentialMatches(
                for: receipt,
                in: availableTransactions
            )
            
            // Only include if there's at least one match above minimum score
            let validMatches = matches.filter { $0.score >= minimumMatchScore }
            
            if !validMatches.isEmpty {
                let pending = PendingReceiptMatch(receipt: receipt, matches: validMatches)
                newPendingMatches.append(pending)
            }
        }
        
        // Sort by best match score (highest first)
        newPendingMatches.sort { $0.bestMatchScore > $1.bestMatchScore }
        
        pendingMatches = newPendingMatches
        pendingMatchCount = newPendingMatches.count
        lastScanDate = Date()
        isProcessing = false
        
        #if DEBUG
        print("📋 Receipt matching scan complete:")
        print("   - Unmatched receipts: \(unmatchedReceipts.count)")
        print("   - Available transactions: \(availableTransactions.count)")
        print("   - Pending matches found: \(pendingMatchCount)")
        #endif
    }
    
    /// Quick check if a newly scanned receipt has matches
    /// Returns matches immediately for display in scanning UI
    func findImmediateMatches(
        for receipt: ReceiptData,
        in transactions: [Transaction]
    ) -> [TransactionMatch] {
        let availableTransactions = transactions.filter { !$0.hasReceipt && !$0.isIncome }
        
        let matches = TransactionMatchingService.shared.findPotentialMatches(
            for: receipt,
            in: availableTransactions
        )
        
        return matches.filter { $0.score >= minimumMatchScore }
    }
    
    /// Links a receipt to a transaction and updates state
    func linkReceipt(
        _ receipt: ReceiptData,
        to transaction: Transaction,
        imagePath: String,
        context: ModelContext
    ) throws {
        // Link the receipt
        TransactionMatchingService.shared.linkReceiptToTransaction(
            transaction,
            receipt: receipt,
            imagePath: imagePath
        )
        
        // Update receipt status
        receipt.matchStatus = .manualMatch
        receipt.matchedDate = Date()
        receipt.transactionID = transaction.id
        receipt.modifiedDate = Date()
        
        // Save changes
        try context.save()
        
        // Remove from pending matches
        pendingMatches.removeAll { $0.receipt.id == receipt.id }
        pendingMatchCount = pendingMatches.count
        
        HapticService.play(.success)
        
        #if DEBUG
        print("✅ Receipt linked: \(receipt.merchantName) → \(transaction.merchantName)")
        #endif
    }
    
    /// Marks a receipt as having no transaction match (cash purchase)
    func markAsNoMatch(
        _ receipt: ReceiptData,
        context: ModelContext
    ) throws {
        receipt.matchStatus = .noBankTransaction
        receipt.modifiedDate = Date()
        
        try context.save()
        
        // Remove from pending matches
        pendingMatches.removeAll { $0.receipt.id == receipt.id }
        pendingMatchCount = pendingMatches.count
        
        HapticService.play(.light)
        
        #if DEBUG
        print("💵 Receipt marked as cash purchase: \(receipt.merchantName)")
        #endif
    }
    
    /// Skips a receipt match for now (keeps in pending)
    func skipForNow(_ receipt: ReceiptData) {
        // Just provide feedback - receipt stays in pending
        HapticService.play(.light)
        
        #if DEBUG
        print("⏭️ Skipped matching for: \(receipt.merchantName)")
        #endif
    }
    
    /// Clears all pending matches (useful for refresh)
    func clearPendingMatches() {
        pendingMatches.removeAll()
        pendingMatchCount = 0
    }
    
    // MARK: - Plaid Integration Support
    
    /// Call this after Plaid sync to re-scan for matches
    /// New Plaid transactions may match existing unmatched receipts
    func onPlaidSyncComplete(
        receipts: [ReceiptData],
        transactions: [Transaction]
    ) {
        #if DEBUG
        print("🔄 Plaid sync complete - rescanning for receipt matches...")
        #endif
        
        scanForMatches(receipts: receipts, transactions: transactions)
    }
    
    /// Call this after new receipt is scanned
    /// Triggers a rescan to find potential matches
    func onNewReceiptScanned(
        receipts: [ReceiptData],
        transactions: [Transaction]
    ) {
        scanForMatches(receipts: receipts, transactions: transactions)
    }
    
    // MARK: - Statistics
    
    /// Get matching statistics for display
    func getStatistics(receipts: [ReceiptData]) -> MatchingStatistics {
        let total = receipts.count
        let matched = receipts.filter {
            $0.matchStatus == .automaticMatch || $0.matchStatus == .manualMatch
        }.count
        let unmatched = receipts.filter { $0.matchStatus == .unmatched }.count
        let cashPurchases = receipts.filter { $0.matchStatus == .noBankTransaction }.count
        
        return MatchingStatistics(
            totalReceipts: total,
            matchedReceipts: matched,
            unmatchedReceipts: unmatched,
            cashPurchases: cashPurchases,
            pendingMatches: pendingMatchCount,
            matchRate: total > 0 ? Double(matched) / Double(total) : 0
        )
    }
}

// MARK: - Matching Statistics

struct MatchingStatistics {
    let totalReceipts: Int
    let matchedReceipts: Int
    let unmatchedReceipts: Int
    let cashPurchases: Int
    let pendingMatches: Int
    let matchRate: Double
    
    var matchRatePercentage: String {
        String(format: "%.0f%%", matchRate * 100)
    }
}

// MARK: - Usage Examples

/*
 // === BASIC USAGE ===
 
 // Scan for matches on app launch or data change
 ReceiptMatchingService.shared.scanForMatches(
     receipts: allReceipts,
     transactions: allTransactions
 )
 
 // Check pending count for badge
 let pendingCount = ReceiptMatchingService.shared.pendingMatchCount
 
 // Get pending matches for queue view
 let pending = ReceiptMatchingService.shared.pendingMatches
 
 // Link a receipt to transaction
 try ReceiptMatchingService.shared.linkReceipt(
     receipt,
     to: selectedTransaction,
     imagePath: imagePath,
     context: modelContext
 )
 
 // === PLAID INTEGRATION ===
 
 // After Plaid sync completes:
 ReceiptMatchingService.shared.onPlaidSyncComplete(
     receipts: allReceipts,
     transactions: allTransactions  // Now includes Plaid transactions
 )
 
 // Plaid transactions have cleaner merchant names and exact amounts,
 // which improves match accuracy significantly!
 */
