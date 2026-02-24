//  CSVCategorizationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - CSV Import auto-categorization engine
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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
        for transaction in committed {
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
