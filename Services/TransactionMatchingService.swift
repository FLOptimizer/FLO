//  TransactionMatchingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Added duplicate receipt detection
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.2:
//  ✅ Added duplicate receipt detection (finds transactions that already have receipts)
//  ✅ Rebalanced scoring: Amount 40%, Date 25%, Merchant 35% (merchant now weighted higher)
//  ✅ Added merchant name normalization (handles variations like "Murphy", "Murphy USA", etc.)
//  ✅ findPotentialMatches now returns both linkable matches AND potential duplicates
//  ✅ Added MatchCategory enum to distinguish duplicates from linkable matches
//
//  CHANGES FROM v2.1:
//  - Added receipt matching support (findPotentialMatches)
//  - Added receipt linking (linkReceiptToTransaction)
//  - Added cash purchase marking (markAsCashPurchase)
//
//  PURPOSE:
//  1. Match imported bank transactions with manual entries (avoid duplicates)
//  2. Match scanned receipts with existing transactions (link receipts)
//  3. Detect duplicate receipt scans (prevent creating duplicates)
//  4. Handle cash purchases that won't have bank matches

import Foundation
import SwiftData

// MARK: - MatchCategory Enum

/// Distinguishes between linkable matches and potential duplicates
enum MatchCategory {
    case linkable       // Transaction has no receipt - can be linked
    case duplicate      // Transaction already has receipt - potential duplicate scan
}

// MARK: - TransactionMatch Model

/// Represents a potential match between a receipt and an existing transaction
struct TransactionMatch {
    let transaction: Transaction
    let score: Double  // 0.0 to 1.0
    let matchType: MatchType
    let category: MatchCategory
    
    var displayConfidence: String {
        let prefix = category == .duplicate ? "⚠️ Duplicate? " : ""
        switch matchType {
        case .perfect:
            return "\(prefix)Perfect Match (100%)"
        case .veryStrong:
            return "\(prefix)Very Strong Match (\(Int(score * 100))%)"
        case .strong:
            return "\(prefix)Strong Match (\(Int(score * 100))%)"
        case .moderate:
            return "\(prefix)Moderate Match (\(Int(score * 100))%)"
        case .weak:
            return "\(prefix)Weak Match (\(Int(score * 100))%)"
        }
    }
    
    var isDuplicate: Bool {
        category == .duplicate
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
    
    // MARK: - Merchant Name Normalization
    
    /// Common merchant name variations to normalize
    private let merchantNormalizations: [String: [String]] = [
        "murphy": ["murphy usa", "murphy oil", "murphyusa"],
        "walmart": ["walmart+", "wal-mart", "wal mart"],
        "starbucks": ["starbucks coffee", "sbux"],
        "amazon": ["amzn", "amazon.com", "amazon prime"],
        "target": ["target.com"],
        "costco": ["costco wholesale"],
        "shell": ["shell oil"],
        "chevron": ["chevron usa"],
        "exxon": ["exxonmobil", "exxon mobil"],
        "mcdonalds": ["mcdonald's", "mcd's"],
        "verizon": ["verizon wireless", "vzw"],
        "att": ["at&t", "at & t"],
    ]
    
    /// Normalizes a merchant name for better matching
    private func normalizeMerchant(_ name: String) -> String {
        var normalized = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common suffixes
        let suffixesToRemove = ["#\\d+", "\\d{4,}", "store", "inc", "llc", "corp"]
        for pattern in suffixesToRemove {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                normalized = regex.stringByReplacingMatches(
                    in: normalized,
                    options: [],
                    range: NSRange(normalized.startIndex..., in: normalized),
                    withTemplate: ""
                )
            }
        }
        
        // Trim again after removals
        normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return normalized
    }
    
    /// Extracts the core brand name from a merchant string
    private func extractCoreBrand(_ name: String) -> String {
        let normalized = normalizeMerchant(name)
        
        // Check if any known brand is contained in the name
        for (brand, variations) in merchantNormalizations {
            if normalized.contains(brand) {
                return brand
            }
            for variation in variations {
                if normalized.contains(variation) {
                    return brand
                }
            }
        }
        
        // Return first word as fallback (often the brand)
        return normalized.components(separatedBy: .whitespaces).first ?? normalized
    }
    
    // MARK: - Bank Import Matching
    
    /// Finds a potential match for an imported bank transaction
    func findMatch(
        importedAmount: Double,
        importedDate: Date,
        importedMerchant: String,
        in existingTransactions: [Transaction]
    ) -> Transaction? {
        
        let calendar = Calendar.current
        
        for transaction in existingTransactions {
            guard abs(transaction.amount - importedAmount) < 0.01 else { continue }
            
            let daysDiff = calendar.dateComponents([.day], from: transaction.date, to: importedDate).day ?? 999
            guard abs(daysDiff) <= 3 else { continue }
            
            let similarity = merchantSimilarity(
                merchant1: transaction.merchantName,
                merchant2: importedMerchant
            )
            
            if similarity > 0.7 {
                print("✅ Bank match found: \(transaction.merchantName) ≈ \(importedMerchant) (similarity: \(String(format: "%.1f%%", similarity * 100)))")
                return transaction
            }
        }
        
        print("ℹ️ No bank match found for: $\(importedAmount) at \(importedMerchant)")
        return nil
    }
    
    /// Creates a new transaction from imported bank data
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
            financeType: .business,
            hasReceipt: false
        )
        
        context.insert(transaction)
        
        print("✅ Created transaction from bank import: \(merchantName) - $\(absoluteAmount)")
        
        return transaction
    }
    
    /// Batch match imported transactions
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
        
        print("📊 Bank batch match complete: \(matched.count) matched, \(unmatched.count) unmatched")
        
        return (matched, unmatched)
    }
    
    // MARK: - Receipt Matching (v2.2 Enhanced)
    
    /// Finds potential matches for a scanned receipt
    /// Returns BOTH linkable transactions (no receipt) AND potential duplicates (has receipt)
    /// Duplicates are sorted first to alert user of potential duplicate scans
    func findPotentialMatches(
        for receipt: ReceiptData,
        in existingTransactions: [Transaction]
    ) -> [TransactionMatch] {
        
        let receiptAmount = receipt.totalAmount
        let receiptDate = receipt.date
        let receiptMerchant = receipt.merchantName
        
        let calendar = Calendar.current
        var matches: [TransactionMatch] = []
        
        // Search ALL transactions (including those with receipts for duplicate detection)
        for transaction in existingTransactions {
            var score: Double = 0.0
            
            // 1. Amount match (40% weight) - reduced from 50%
            let amountDiff = abs(transaction.amount - receiptAmount)
            let amountMatch: Double
            if amountDiff < 0.01 {
                amountMatch = 1.0  // Exact match
            } else if receiptAmount > 0 {
                amountMatch = max(0, 1.0 - (amountDiff / receiptAmount))
            } else {
                amountMatch = 0.0
            }
            score += amountMatch * 0.40
            
            // 2. Date match (25% weight) - reduced from 30%
            let daysDiff = abs(calendar.dateComponents([.day], from: transaction.date, to: receiptDate).day ?? 999)
            let dateMatch: Double
            switch daysDiff {
            case 0:
                dateMatch = 1.0  // Same day
            case 1:
                dateMatch = 0.85 // 1 day off
            case 2:
                dateMatch = 0.65 // 2 days off
            case 3:
                dateMatch = 0.45 // 3 days off
            case 4...7:
                dateMatch = 0.2  // Within a week
            default:
                dateMatch = 0.0  // Too far apart
            }
            score += dateMatch * 0.25
            
            // 3. Merchant match (35% weight) - INCREASED from 20%
            let merchantScore = merchantSimilarity(
                merchant1: transaction.merchantName,
                merchant2: receiptMerchant
            )
            score += merchantScore * 0.35
            
            // Only include matches with reasonable confidence (>40%)
            if score > 0.4 {
                let matchType = MatchType(score: score)
                let category: MatchCategory = transaction.hasReceipt ? .duplicate : .linkable
                
                let match = TransactionMatch(
                    transaction: transaction,
                    score: score,
                    matchType: matchType,
                    category: category
                )
                matches.append(match)
            }
        }
        
        // Sort: duplicates first (highest score), then linkable (highest score)
        matches.sort { match1, match2 in
            // Duplicates always come first
            if match1.isDuplicate && !match2.isDuplicate {
                return true
            }
            if !match1.isDuplicate && match2.isDuplicate {
                return false
            }
            // Within same category, sort by score
            return match1.score > match2.score
        }
        
        // Log results
        let duplicates = matches.filter { $0.isDuplicate }
        let linkable = matches.filter { !$0.isDuplicate }
        
        print("📊 Receipt matching found \(matches.count) potential matches")
        print("   - \(duplicates.count) potential duplicate(s)")
        print("   - \(linkable.count) linkable transaction(s)")
        
        if let best = matches.first {
            let typeStr = best.isDuplicate ? "DUPLICATE" : "linkable"
            print("   Best match: \(best.transaction.merchantName) (\(typeStr)) with \(Int(best.score * 100))% confidence")
        }
        
        return matches
    }
    
    /// Links a receipt to an existing transaction
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
    @discardableResult
    func markAsCashPurchase(
        receipt: ReceiptData,
        imagePath: String,
        context: ModelContext
    ) -> Transaction {
        
        let transaction = Transaction(
            amount: receipt.totalAmount,
            date: receipt.date,
            note: receipt.merchantName,
            isIncome: false,
            merchantName: receipt.merchantName,
            category: nil,
            financeType: .business,
            receiptImagePath: imagePath,
            receiptID: receipt.id.uuidString,
            hasReceipt: true
        )
        
        context.insert(transaction)
        
        print("✅ Created cash purchase transaction: \(transaction.merchantName)")
        
        return transaction
    }
    
    // MARK: - Enhanced Merchant Similarity
    
    /// Calculates similarity between two merchant names with brand awareness
    private func merchantSimilarity(merchant1: String, merchant2: String) -> Double {
        let s1 = normalizeMerchant(merchant1)
        let s2 = normalizeMerchant(merchant2)
        
        // Quick exact match
        if s1 == s2 { return 1.0 }
        
        // Check if same core brand
        let brand1 = extractCoreBrand(merchant1)
        let brand2 = extractCoreBrand(merchant2)
        
        if brand1 == brand2 && !brand1.isEmpty {
            // Same brand - high similarity even if full names differ
            // e.g., "Murphy USA 7578" vs "Murphy Walmart +"
            return 0.85
        }
        
        // Check for brand match in known variations
        for (brand, variations) in merchantNormalizations {
            let allVariations = [brand] + variations
            let s1Matches = allVariations.contains { s1.contains($0) }
            let s2Matches = allVariations.contains { s2.contains($0) }
            
            if s1Matches && s2Matches {
                return 0.9  // Both match same brand family
            }
        }
        
        // Check if one contains the other
        if s1.contains(s2) || s2.contains(s1) {
            let shorterLength = Double(min(s1.count, s2.count))
            let longerLength = Double(max(s1.count, s2.count))
            return max(0.7, shorterLength / longerLength)
        }
        
        // Calculate Levenshtein distance
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        
        guard maxLength > 0 else { return 0.0 }
        
        return 1.0 - (Double(distance) / Double(maxLength))
    }
    
    /// Calculates Levenshtein distance between two strings
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

// MARK: - String Extension for Fuzzy Matching

extension String {
    /// Calculates fuzzy match confidence between two strings
    func fuzzyMatchConfidence(with other: String) -> Double {
        let s1 = self.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let s2 = other.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if s1 == s2 { return 1.0 }
        
        if s1.contains(s2) || s2.contains(s1) {
            let shorterLength = Double(min(s1.count, s2.count))
            let longerLength = Double(max(s1.count, s2.count))
            return shorterLength / longerLength
        }
        
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
