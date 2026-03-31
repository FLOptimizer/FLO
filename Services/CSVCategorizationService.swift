//  CSVCategorizationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Transfer Detection Engine
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.0:
//  ✅ ADDED: detectTransfers() method — scans merchant names for transfer keywords
//  ✅ ADDED: TransferKeyword struct — pattern matching with confidence scores
//  ✅ ADDED: transferKeywords static array — comprehensive list of transfer indicators
//  ✅ ADDED: Bank-provided category "Transfer" detection
//  ✅ ADDED: Account number pattern detection (e.g., "TO CHK 4521")
//  ✅ Sets detectedAsTransfer = true and isTransfer = true for auto-detected transfers
//  ✅ User can override in review UI before commit
//
//  Version 1.0:
//  - CSV Import auto-categorization engine
//

import Foundation
import SwiftData
import os.log

@MainActor
final class CSVCategorizationService {
    static let shared = CSVCategorizationService()
    private init() {}
    
    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CSVCategorizationService"
    )
    
    // MARK: - Transfer Keyword Patterns
    
    /// Transfer keyword with associated confidence score
    private struct TransferKeyword {
        let pattern: String
        let confidence: Double
        let requiresWordBoundary: Bool
        
        init(_ pattern: String, confidence: Double, wordBoundary: Bool = false) {
            self.pattern = pattern
            self.confidence = confidence
            self.requiresWordBoundary = wordBoundary
        }
    }
    
    /// Keywords that indicate a transaction is likely a transfer between accounts.
    /// Higher confidence = more certain it's a transfer.
    /// These patterns cover common bank descriptions for internal transfers.
    private static let transferKeywords: [TransferKeyword] = [
        // === HIGH CONFIDENCE (0.95-1.0) — Almost certainly transfers ===
        TransferKeyword("TRANSFER TO", confidence: 1.0),
        TransferKeyword("TRANSFER FROM", confidence: 1.0),
        TransferKeyword("XFER TO", confidence: 1.0),
        TransferKeyword("XFER FROM", confidence: 1.0),
        TransferKeyword("ONLINE TRANSFER TO", confidence: 1.0),
        TransferKeyword("ONLINE TRANSFER FROM", confidence: 1.0),
        TransferKeyword("MOBILE TRANSFER TO", confidence: 1.0),
        TransferKeyword("MOBILE TRANSFER FROM", confidence: 1.0),
        TransferKeyword("INTERNAL TRANSFER", confidence: 1.0),
        TransferKeyword("ACCOUNT TRANSFER", confidence: 1.0),
        TransferKeyword("FUNDS TRANSFER", confidence: 1.0),
        TransferKeyword("MOVE MONEY", confidence: 1.0),
        TransferKeyword("OWNER'S DRAW", confidence: 1.0),
        TransferKeyword("OWNERS DRAW", confidence: 1.0),
        TransferKeyword("OWNER DRAW", confidence: 1.0),
        TransferKeyword("OWNER CONTRIBUTION", confidence: 1.0),
        TransferKeyword("CAPITAL CONTRIBUTION", confidence: 1.0),
        
        // === STRONG INDICATORS (0.85-0.94) — Very likely transfers ===
        TransferKeyword("ZELLE TO", confidence: 0.90),
        TransferKeyword("ZELLE FROM", confidence: 0.90),
        TransferKeyword("ZELLE PAYMENT TO", confidence: 0.90),
        TransferKeyword("ZELLE PAYMENT FROM", confidence: 0.90),
        TransferKeyword("VENMO TO", confidence: 0.90),
        TransferKeyword("VENMO FROM", confidence: 0.90),
        TransferKeyword("VENMO CASHOUT", confidence: 0.95),
        TransferKeyword("PAYPAL TRANSFER", confidence: 0.90),
        TransferKeyword("PAYPAL INSTANT TRANSFER", confidence: 0.95),
        TransferKeyword("CASH APP TO", confidence: 0.90),
        TransferKeyword("CASH APP FROM", confidence: 0.90),
        TransferKeyword("CASHAPP", confidence: 0.85),
        TransferKeyword("WIRE TRANSFER", confidence: 0.90),
        TransferKeyword("WIRE IN", confidence: 0.90),
        TransferKeyword("WIRE OUT", confidence: 0.90),
        TransferKeyword("INCOMING WIRE", confidence: 0.90),
        TransferKeyword("OUTGOING WIRE", confidence: 0.90),
        
        // === MODERATE INDICATORS (0.70-0.84) — Likely transfers, verify ===
        TransferKeyword("ACH TRANSFER", confidence: 0.80),
        TransferKeyword("ACH CREDIT", confidence: 0.75),
        TransferKeyword("ACH DEBIT", confidence: 0.70),
        TransferKeyword("DIRECT DEPOSIT", confidence: 0.65),  // Could be payroll
        TransferKeyword("ONLINE BANKING TRANSFER", confidence: 0.85),
        TransferKeyword("TO SAVINGS", confidence: 0.90),
        TransferKeyword("FROM SAVINGS", confidence: 0.90),
        TransferKeyword("TO CHECKING", confidence: 0.90),
        TransferKeyword("FROM CHECKING", confidence: 0.90),
        TransferKeyword("TO CHK", confidence: 0.90),
        TransferKeyword("FROM CHK", confidence: 0.90),
        TransferKeyword("TO SAV", confidence: 0.90),
        TransferKeyword("FROM SAV", confidence: 0.90),
        TransferKeyword("SAVINGS TRANSFER", confidence: 0.90),
        TransferKeyword("CHECKING TRANSFER", confidence: 0.90),
        
        // === BANK-SPECIFIC PATTERNS (0.80-0.95) ===
        // Chase
        TransferKeyword("CHASE QUICKPAY", confidence: 0.85),
        TransferKeyword("CHASE TRANSFER", confidence: 0.90),
        // Bank of America
        TransferKeyword("BANK OF AMER MOBILE", confidence: 0.75),
        TransferKeyword("BOFA TRANSFER", confidence: 0.90),
        // Wells Fargo
        TransferKeyword("WELLS FARGO TRANSFER", confidence: 0.90),
        TransferKeyword("WF TRANSFER", confidence: 0.90),
        // Capital One
        TransferKeyword("CAPITAL ONE TRANSFER", confidence: 0.90),
        // Generic bank transfers
        TransferKeyword("MOBILE BANKING", confidence: 0.70),
        TransferKeyword("INTERNET BANKING", confidence: 0.70),
        
        // === ACCOUNT NUMBER PATTERNS (handled separately) ===
        // Pattern like "TO 1234" or "FROM ACCT 5678" detected via regex
        
        // === LOWER CONFIDENCE (0.50-0.69) — Possible transfers, review carefully ===
        TransferKeyword("TRANSFER", confidence: 0.60, wordBoundary: true),
        TransferKeyword("XFER", confidence: 0.60, wordBoundary: true),
        TransferKeyword("ZELLE", confidence: 0.70, wordBoundary: true),
        TransferKeyword("VENMO", confidence: 0.70, wordBoundary: true),
    ]
    
    /// Bank-provided category values that indicate transfers
    private static let transferBankCategories: Set<String> = [
        "transfer",
        "transfers",
        "bank transfer",
        "internal transfer",
        "account transfer",
        "wire transfer",
        "money transfer",
        "funds transfer",
        "payment transfer",
    ]
    
    // MARK: - Transfer Detection
    
    /// Detects likely transfers in parsed transactions based on keyword matching.
    /// Sets `detectedAsTransfer` and `isTransfer` flags, plus `transferConfidence` score.
    ///
    /// - Parameter parsed: Array of parsed transactions to analyze
    /// - Returns: Updated transactions with transfer detection applied
    func detectTransfers(
        parsed: [CSVParsedTransaction]
    ) -> [CSVParsedTransaction] {
        var transfersDetected = 0
        
        let updatedTransactions = parsed.map { transaction -> CSVParsedTransaction in
            var updated = transaction
            
            // Check 1: Bank-provided category indicates transfer
            if let bankCategory = transaction.bankCategory?.lowercased(),
               Self.transferBankCategories.contains(bankCategory) {
                updated.detectedAsTransfer = true
                updated.isTransfer = true
                updated.transferConfidence = 0.95  // High confidence from bank category
                transfersDetected += 1
                Self.logger.debug("Transfer detected via bank category: '\(transaction.merchantName)' (category: '\(bankCategory)')")
                return updated
            }
            
            // Check 2: Keyword matching in merchant name and description
            let textToSearch = "\(transaction.merchantName) \(transaction.description)".uppercased()
            var bestMatch: (pattern: String, confidence: Double)?
            
            for keyword in Self.transferKeywords {
                let pattern = keyword.pattern.uppercased()
                
                if keyword.requiresWordBoundary {
                    // Use word boundary matching for generic terms
                    let wordPattern = "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b"
                    if let regex = try? NSRegularExpression(pattern: wordPattern, options: .caseInsensitive) {
                        let range = NSRange(textToSearch.startIndex..., in: textToSearch)
                        if regex.firstMatch(in: textToSearch, options: [], range: range) != nil {
                            if bestMatch == nil || keyword.confidence > bestMatch!.confidence {
                                bestMatch = (keyword.pattern, keyword.confidence)
                            }
                        }
                    }
                } else {
                    // Direct substring match for specific phrases
                    if textToSearch.contains(pattern) {
                        if bestMatch == nil || keyword.confidence > bestMatch!.confidence {
                            bestMatch = (keyword.pattern, keyword.confidence)
                        }
                    }
                }
            }
            
            // Check 3: Account number pattern detection
            // Matches patterns like "TO 1234", "FROM ACCT 5678", "CHK 9012", etc.
            let accountPatterns = [
                "(?:TO|FROM)\\s+(?:ACCT?|ACCOUNT)?\\s*#?\\d{4,}",  // TO ACCT 1234, FROM 5678
                "(?:TO|FROM)\\s+(?:CHK|CHECKING|SAV|SAVINGS)\\s*#?\\d{4}",  // TO CHK 1234
                "(?:ACCT?|ACCOUNT)\\s*#?\\d{4,}\\s*(?:TO|FROM)",  // ACCT 1234 TO
            ]
            
            for pattern in accountPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(textToSearch.startIndex..., in: textToSearch)
                    if regex.firstMatch(in: textToSearch, options: [], range: range) != nil {
                        let accountConfidence = 0.85
                        if bestMatch == nil || accountConfidence > bestMatch!.confidence {
                            bestMatch = ("Account Number Pattern", accountConfidence)
                        }
                    }
                }
            }
            
            // Apply best match if found
            if let match = bestMatch {
                updated.detectedAsTransfer = true
                updated.isTransfer = true  // Auto-select, user can override
                updated.transferConfidence = match.confidence
                transfersDetected += 1
                Self.logger.debug("Transfer detected: '\(transaction.merchantName)' matched '\(match.pattern)' (confidence: \(String(format: "%.2f", match.confidence)))")
            }
            
            return updated
        }
        
        Self.logger.info("Transfer detection complete: \(transfersDetected) transfers detected out of \(parsed.count) transactions")
        
        return updatedTransactions
    }
    
    // MARK: - Auto-Categorization
    
    /// Automatically categorize parsed CSV transactions using learned merchant mappings
    /// - Parameters:
    ///   - parsed: Array of parsed transactions to categorize
    ///   - merchantMappings: Existing merchant-to-category mappings from database
    ///   - categories: All available categories
    /// - Returns: Updated transactions with suggestedCategory applied where possible
    func categorizeTransactions(
        parsed: [CSVParsedTransaction],
        merchantMappings: [MerchantCategoryMapping],
        categories: [Category]
    ) -> [CSVParsedTransaction] {
        var categorizedCount = 0
        var uncategorizedCount = 0
        
        let updatedTransactions = parsed.map { transaction -> CSVParsedTransaction in
            var updated = transaction
            
            // Try to find a matching merchant mapping
            if let mapping = merchantMappings.first(where: { $0.matches(transaction.merchantName) }) {
                // First try to match by categoryID (most reliable)
                if let categoryID = mapping.categoryID,
                   let category = categories.first(where: { $0.id == categoryID }) {
                    updated.suggestedCategory = category
                    categorizedCount += 1
                    Self.logger.debug("Matched '\(transaction.merchantName)' to category '\(category.name)' via learned mapping (ID match)")
                    return updated
                }
                
                // Fall back to matching by categoryName
                if let categoryName = mapping.categoryName,
                   let category = categories.first(where: { $0.name == categoryName }) {
                    updated.suggestedCategory = category
                    categorizedCount += 1
                    Self.logger.debug("Matched '\(transaction.merchantName)' to category '\(categoryName)' via learned mapping (name match)")
                    return updated
                }
            }
            
            // No learned mapping found — try common mappings as fallback
            for commonMapping in MerchantCategoryMapping.commonMappings {
                let patterns = commonMapping.patterns
                let merchantLower = transaction.merchantName.lowercased()
                
                // Check if any pattern matches the merchant name
                let matches = patterns.contains { pattern in
                    let patternLower = pattern.lowercased()
                    return merchantLower.contains(patternLower) || patternLower.contains(merchantLower)
                }
                
                if matches {
                    // Find the category by name
                    if let category = categories.first(where: { $0.name == commonMapping.category }) {
                        updated.suggestedCategory = category
                        categorizedCount += 1
                        Self.logger.debug("Matched '\(transaction.merchantName)' to category '\(commonMapping.category)' via common mapping")
                        return updated
                    }
                }
            }
            
            // No match found
            uncategorizedCount += 1
            return updated
        }
        
        Self.logger.info("Auto-categorization complete: \(categorizedCount) categorized, \(uncategorizedCount) uncategorized out of \(parsed.count) transactions")
        
        return updatedTransactions
    }
    
    // MARK: - Bulk Operations
    
    /// Apply a single category to all uncategorized transactions
    /// - Parameters:
    ///   - transactions: Array of parsed transactions
    ///   - category: Category to apply
    /// - Returns: Updated transactions with category applied to uncategorized items
    func applyBulkCategory(
        to transactions: [CSVParsedTransaction],
        category: Category
    ) -> [CSVParsedTransaction] {
        var appliedCount = 0
        
        let updated = transactions.map { transaction -> CSVParsedTransaction in
            var updated = transaction
            if updated.suggestedCategory == nil {
                updated.suggestedCategory = category
                appliedCount += 1
            }
            return updated
        }
        
        Self.logger.info("Applied bulk category '\(category.name)' to \(appliedCount) uncategorized transactions")
        
        return updated
    }
    
    /// Apply a finance type to all transactions
    /// - Parameters:
    ///   - transactions: Array of parsed transactions
    ///   - financeType: Finance type to apply (.business or .personal)
    /// - Returns: Updated transactions with finance type applied
    func applyFinanceType(
        to transactions: [CSVParsedTransaction],
        financeType: Transaction.FinanceType
    ) -> [CSVParsedTransaction] {
        let updated = transactions.map { transaction -> CSVParsedTransaction in
            var updated = transaction
            updated.suggestedFinanceType = financeType
            return updated
        }
        
        Self.logger.info("Applied finance type '\(financeType.rawValue)' to \(transactions.count) transactions")
        
        return updated
    }
    
    /// Toggle transfer status for all detected transfers
    /// - Parameters:
    ///   - transactions: Array of parsed transactions
    ///   - markAsTransfer: Whether to mark detected transfers as transfers
    /// - Returns: Updated transactions with transfer status applied
    func applyTransferStatus(
        to transactions: [CSVParsedTransaction],
        markAsTransfer: Bool
    ) -> [CSVParsedTransaction] {
        var appliedCount = 0
        
        let updated = transactions.map { transaction -> CSVParsedTransaction in
            var updated = transaction
            if updated.detectedAsTransfer {
                updated.isTransfer = markAsTransfer
                appliedCount += 1
            }
            return updated
        }
        
        Self.logger.info("Applied transfer status (\(markAsTransfer)) to \(appliedCount) detected transfers")
        
        return updated
    }
    
    // MARK: - Learning from Import
    
    /// Learn from committed transactions to improve future categorization
    /// Updates or creates MerchantCategoryMapping entries based on user's final category choices
    /// - Parameters:
    ///   - committed: Transactions that were committed to the database
    ///   - context: ModelContext for database operations
    func learnFromImport(
        committed: [CSVParsedTransaction],
        context: ModelContext
    ) {
        var mappingsCreated = 0
        var mappingsReinforced = 0
        var mappingsUpdated = 0
        
        // Fetch all existing merchant mappings
        let descriptor = FetchDescriptor<MerchantCategoryMapping>()
        guard let existingMappings = try? context.fetch(descriptor) else {
            Self.logger.error("Failed to fetch existing merchant mappings for learning")
            return
        }
        
        // Process each committed transaction that has a category
        // Skip transfers — they don't need category learning
        for transaction in committed where !transaction.isTransfer {
            guard let category = transaction.suggestedCategory else {
                continue
            }
            
            // Check if an existing mapping matches this merchant
            if let existingMapping = existingMappings.first(where: { $0.matches(transaction.merchantName) }) {
                // Check if the category changed (user override)
                if existingMapping.categoryID != category.id {
                    Self.logger.debug("User changed category for '\(transaction.merchantName)' from '\(existingMapping.categoryName ?? "nil")' to '\(category.name)' — updating mapping")
                    
                    existingMapping.weakenMapping()
                    existingMapping.categoryID = category.id
                    existingMapping.categoryName = category.name
                    existingMapping.confidence = 0.5 // Reset to medium confidence after user override
                    mappingsUpdated += 1
                } else {
                    // Category matches — reinforce the mapping
                    existingMapping.reinforceMapping()
                    mappingsReinforced += 1
                    Self.logger.debug("Reinforced mapping for '\(transaction.merchantName)' → '\(category.name)' (confidence: \(String(format: "%.2f", existingMapping.confidence)))")
                }
            } else {
                // No existing mapping — create a new one
                let newMapping = MerchantCategoryMapping(
                    merchantName: transaction.merchantName,
                    categoryID: category.id,
                    categoryName: category.name,
                    confidence: 0.5
                )
                context.insert(newMapping)
                mappingsCreated += 1
                Self.logger.debug("Created new mapping: '\(transaction.merchantName)' → '\(category.name)'")
            }
        }
        
        Self.logger.info("Learning complete: \(mappingsCreated) created, \(mappingsReinforced) reinforced, \(mappingsUpdated) updated")
    }
}
