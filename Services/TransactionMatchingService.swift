//  TransactionMatchingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Enhanced with receipt matching support
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Elite service for matching both bank imports AND receipts
//
//  CHANGES FROM v2.0:
//  - Added receipt matching support (findPotentialMatches)
//  - Added receipt linking (linkReceiptToTransaction)
//  - Added cash purchase marking (markAsCashPurchase)
//  - Added TransactionMatch struct
//  - Added MatchType enum
//  - Fixed ReceiptData property compatibility
//  - Enhanced documentation
//
//  PURPOSE:
//  1. Match imported bank transactions with manual entries (avoid duplicates)
//  2. Match scanned receipts with existing transactions (link receipts)
//  3. Handle cash purchases that won't have bank matches

import Foundation
import SwiftData

// MARK: - TransactionMatch Model

/// Represents a potential match between a receipt and an existing transaction
struct TransactionMatch {
    let transaction: Transaction
    let score: Double  // 0.0 to 1.0
    let matchType: MatchType
    
    var displayConfidence: String {
        switch matchType {
        case .perfect:
            return "Perfect Match (100%)"
        case .veryStrong:
            return "Very Strong Match (\(Int(score * 100))%)"
        case .strong:
            return "Strong Match (\(Int(score * 100))%)"
        case .moderate:
            return "Moderate Match (\(Int(score * 100))%)"
        case .weak:
            return "Weak Match (\(Int(score * 100))%)"
        }
    }
}

// MARK: - MatchType Enum

/// Classification of match confidence levels
enum MatchType {
    case perfect      // 95%+  - Exact match
    case veryStrong   // 85-94% - Nearly certain
    case strong       // 75-84% - Highly likely
    case moderate     // 60-74% - Possible match
    case weak         // <60%  - Uncertain
    
    init(score: Double) {
        switch score {
        case 0.95...:
            self = .perfect
        case 0.85..<0.95:
            self = .veryStrong
        case 0.75..<0.85:
            self = .strong
        case 0.60..<0.75:
            self = .moderate
        default:
            self = .weak
        }
    }
}

// MARK: - TransactionMatchingService

@MainActor
class TransactionMatchingService {
    
    // Singleton instance
    static let shared = TransactionMatchingService()
    
    private init() {}
    
    // MARK: - Bank Import Matching (from v2.0)
    
    /// Finds a potential match for an imported bank transaction
    /// - Parameters:
    ///   - importedAmount: Amount from bank import
    ///   - importedDate: Date from bank import
    ///   - importedMerchant: Merchant name from bank import
    ///   - existingTransactions: Array of existing transactions to search
    /// - Returns: Matched transaction if found, nil otherwise
    func findMatch(
        importedAmount: Double,
        importedDate: Date,
        importedMerchant: String,
        in existingTransactions: [Transaction]
    ) -> Transaction? {
        
        let calendar = Calendar.current
        
        // Match criteria:
        // 1. Amount must match exactly
        // 2. Date within ±3 days (accounts for processing delays)
        // 3. Merchant name similarity > 70%
        
        for transaction in existingTransactions {
            // Check amount match
            guard abs(transaction.amount - importedAmount) < 0.01 else { continue }
            
            // Check date match (within 3 days)
            let daysDiff = calendar.dateComponents([.day], from: transaction.date, to: importedDate).day ?? 999
            guard abs(daysDiff) <= 3 else { continue }
            
            // Check merchant similarity
            let similarity = stringSimilarity(
                transactionMerchant: transaction.merchantName,
                importedMerchant: importedMerchant
            )
            
            if similarity > 0.7 {
                print("✅ Bank match found: \(transaction.merchantName) ≈ \(importedMerchant) (similarity: \(String(format: "%.1f%%", similarity * 100)))")
                return transaction
            }
        }
        
        print("ℹ️ No bank match found for: $\(importedAmount) at \(importedMerchant) on \(importedDate.formatted(date: .abbreviated, time: .omitted))")
        return nil
    }
    
    /// Creates a new transaction from imported bank data
    /// - Parameters:
    ///   - amount: Transaction amount (positive for income, negative for expense)
    ///   - date: Transaction date
    ///   - merchantName: Merchant name from bank
    ///   - context: ModelContext to insert transaction into
    /// - Returns: Newly created Transaction
    func createTransaction(
        from amount: Double,
        date: Date,
        merchantName: String,
        context: ModelContext
    ) -> Transaction {
        
        let isIncome = amount > 0
        let absoluteAmount = abs(amount)
        
        let transaction = Transaction(
            amount: absoluteAmount,
            date: date,
            note: "Imported from bank",
            isIncome: isIncome,
            merchantName: merchantName,
            category: nil,
            financeType: .business,  // Default to business for imported transactions
            hasReceipt: false
        )
        
        context.insert(transaction)
        
        print("✅ Created transaction from bank import: \(merchantName) - $\(absoluteAmount)")
        
        return transaction
    }
    
    /// Batch match imported transactions
    /// - Parameters:
    ///   - importedTransactions: Array of tuples containing imported transaction data
    ///   - existingTransactions: Array of existing transactions to match against
    /// - Returns: Tuple of (matched transactions, unmatched transaction data)
    func batchMatch(
        importedTransactions: [(amount: Double, date: Date, merchant: String)],
        existingTransactions: [Transaction]
    ) -> (matched: [Transaction], unmatched: [(amount: Double, date: Date, merchant: String)]) {
        
        var matched: [Transaction] = []
        var unmatched: [(amount: Double, date: Date, merchant: String)] = []
        
        for imported in importedTransactions {
            if let match = findMatch(
                importedAmount: imported.amount,
                importedDate: imported.date,
                importedMerchant: imported.merchant,
                in: existingTransactions
            ) {
                matched.append(match)
            } else {
                unmatched.append(imported)
            }
        }
        
        print("📊 Bank batch match complete: \(matched.count) matched, \(unmatched.count) unmatched out of \(importedTransactions.count) total")
        
        return (matched, unmatched)
    }
    
    // MARK: - Receipt Matching (NEW in v2.1)
    
    /// Finds potential matches for a scanned receipt
    /// - Parameters:
    ///   - receipt: Parsed receipt data
    ///   - existingTransactions: Array of existing transactions to search
    /// - Returns: Array of potential matches sorted by confidence
    func findPotentialMatches(
        for receipt: ReceiptData,
        in existingTransactions: [Transaction]
    ) -> [TransactionMatch] {
        
        // FIXED: Use totalAmount and date directly (not optional)
        let receiptAmount = receipt.totalAmount
        let receiptDate = receipt.date
        
        let calendar = Calendar.current
        var matches: [TransactionMatch] = []
        
        // Search for potential matches
        for transaction in existingTransactions {
            // Skip if transaction already has a receipt
            if transaction.hasReceipt {
                continue
            }
            
            var score: Double = 0.0
            
            // 1. Amount match (50% weight)
            let amountDiff = abs(transaction.amount - receiptAmount)
            let amountMatch = max(0, 1.0 - (amountDiff / receiptAmount))
            score += amountMatch * 0.5
            
            // 2. Date match (30% weight)
            // FIXED: Properly get day difference as Int
            let daysDiff = abs(calendar.dateComponents([.day], from: transaction.date, to: receiptDate).day ?? 999)
            let dateMatch: Double
            switch daysDiff {
            case 0:
                dateMatch = 1.0  // Same day
            case 1:
                dateMatch = 0.8  // 1 day off
            case 2:
                dateMatch = 0.6  // 2 days off
            case 3:
                dateMatch = 0.4  // 3 days off
            default:
                dateMatch = 0.0  // Too far apart
            }
            score += dateMatch * 0.3
            
            // 3. Merchant match (20% weight)
            // FIXED: Use merchantName directly (not optional)
            let merchantSimilarity = stringSimilarity(
                transactionMerchant: transaction.merchantName,
                importedMerchant: receipt.merchantName
            )
            score += merchantSimilarity * 0.2
            
            // Only include matches with reasonable confidence (>40%)
            if score > 0.4 {
                let matchType = MatchType(score: score)
                let match = TransactionMatch(
                    transaction: transaction,
                    score: score,
                    matchType: matchType
                )
                matches.append(match)
            }
        }
        
        // Sort by score (highest first)
        matches.sort { $0.score > $1.score }
        
        print("📊 Receipt matching found \(matches.count) potential matches")
        if let best = matches.first {
            print("   Best match: \(best.transaction.merchantName) with \(Int(best.score * 100))% confidence")
        }
        
        return matches
    }
    
    /// Links a receipt to an existing transaction
    /// - Parameters:
    ///   - transaction: Transaction to link receipt to
    ///   - receipt: Receipt data to link
    ///   - imagePath: Path to saved receipt image
    func linkReceiptToTransaction(
        _ transaction: Transaction,
        receipt: ReceiptData,
        imagePath: String
    ) {
        transaction.receiptImagePath = imagePath
        transaction.hasReceipt = true
        transaction.receiptID = receipt.id.uuidString
        transaction.updatedAt = Date()
        
        print("✅ Linked receipt to transaction: \(transaction.merchantName)")
    }
    
    /// Marks a receipt as a cash purchase (creates new transaction)
    /// - Parameters:
    ///   - receipt: Receipt data
    ///   - imagePath: Path to saved receipt image
    ///   - context: ModelContext to insert into
    /// - Returns: Newly created transaction
    @discardableResult
    func markAsCashPurchase(
        receipt: ReceiptData,
        imagePath: String,
        context: ModelContext
    ) -> Transaction {
        
        // FIXED: Use totalAmount directly (not optional)
        let transaction = Transaction(
            amount: receipt.totalAmount,
            date: receipt.date,
            note: receipt.merchantName,
            isIncome: false,
            merchantName: receipt.merchantName,
            category: nil,
            financeType: .business,  // Default to business
            receiptImagePath: imagePath,
            receiptID: receipt.id.uuidString,
            hasReceipt: true
        )
        
        context.insert(transaction)
        
        print("✅ Created cash purchase transaction: \(transaction.merchantName)")
        
        return transaction
    }
    
    // MARK: - Private Helper Methods
    
    /// Calculates similarity between two strings using Levenshtein distance
    /// - Parameters:
    ///   - transactionMerchant: Merchant name from existing transaction
    ///   - importedMerchant: Merchant name from import/receipt
    /// - Returns: Similarity score between 0.0 and 1.0
    private func stringSimilarity(transactionMerchant: String, importedMerchant: String) -> Double {
        let s1 = transactionMerchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2 = importedMerchant.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Quick exact match
        if s1 == s2 { return 1.0 }
        
        // Check if one contains the other (common with bank merchant names)
        if s1.contains(s2) || s2.contains(s1) {
            let shorterLength = Double(min(s1.count, s2.count))
            let longerLength = Double(max(s1.count, s2.count))
            return shorterLength / longerLength
        }
        
        // Calculate Levenshtein distance
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculates Levenshtein distance between two strings
    /// - Parameters:
    ///   - s1: First string
    ///   - s2: Second string
    /// - Returns: Edit distance between the strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)
        
        for (i, char1) in s1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                current[j + 1] = char1 == char2
                    ? last[j]
                    : Swift.min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        
        return last.last ?? 0
    }
}

// MARK: - Usage Examples (Documentation)

/*
 // === BANK IMPORT MATCHING ===
 
 // Match a single imported transaction
 let match = TransactionMatchingService.shared.findMatch(
     importedAmount: 125.50,
     importedDate: Date(),
     importedMerchant: "STARBUCKS #1234",
     in: existingTransactions
 )
 
 if let matched = match {
     print("Found existing transaction: \(matched.merchantName)")
 } else {
     // Create new transaction
     let newTransaction = TransactionMatchingService.shared.createTransaction(
         from: -125.50,
         date: Date(),
         merchantName: "Starbucks",
         context: context
     )
 }
 
 // === RECEIPT MATCHING ===
 
 // Find potential matches for a scanned receipt
 let matches = TransactionMatchingService.shared.findPotentialMatches(
     for: receiptData,
     in: existingTransactions
 )
 
 if let bestMatch = matches.first, bestMatch.score > 0.8 {
     // High confidence match - link receipt
     TransactionMatchingService.shared.linkReceiptToTransaction(
         bestMatch.transaction,
         receipt: receiptData,
         imagePath: "/path/to/receipt.jpg"
     )
 } else if matches.isEmpty {
     // No match - mark as cash purchase
     TransactionMatchingService.shared.markAsCashPurchase(
         receipt: receiptData,
         imagePath: "/path/to/receipt.jpg",
         context: context
     )
 }
 */
// MARK: - String Extension for Fuzzy Matching

extension String {
    /// Calculates fuzzy match confidence between two strings
    /// - Parameter other: String to compare against
    /// - Returns: Confidence score between 0.0 and 1.0
    func fuzzyMatchConfidence(with other: String) -> Double {
        let s1 = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2 = other.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Quick exact match
        if s1 == s2 { return 1.0 }
        
        // Check if one contains the other
        if s1.contains(s2) || s2.contains(s1) {
            let shorterLength = Double(min(s1.count, s2.count))
            let longerLength = Double(max(s1.count, s2.count))
            return shorterLength / longerLength
        }
        
        // Calculate Levenshtein distance
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)
        
        for (i, char1) in s1.enumerated() {
            var current = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                current[j + 1] = char1 == char2
                    ? last[j]
                    : Swift.min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        
        return last.last ?? 0
    }
}
