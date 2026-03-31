//  BatchCategorizationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Batch Merchant Categorization
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Groups transactions by merchant name and allows bulk categorization.
//  When a user categorizes all transactions for a merchant, the service
//  also creates/reinforces a MerchantCategoryMapping so future transactions
//  from that merchant auto-categorize.
//
//  FEATURES v1.0:
//  ✅ Groups transactions by normalized merchant name
//  ✅ Bulk-updates all transactions for a merchant to a chosen category
//  ✅ Creates or reinforces MerchantCategoryMapping for learning
//  ✅ Singleton pattern matching CSVCategorizationService
//  ✅ Progress tracking via published properties
//

import Foundation
import SwiftData
import os.log

// MARK: - Merchant Group Model

/// Represents a group of transactions sharing the same merchant name
struct MerchantGroup: Identifiable, Hashable {
    let id: String  // Normalized merchant name
    let merchantName: String  // Display name (original casing)
    let normalizedName: String
    var transactionCount: Int
    var totalAmount: Double
    var currentCategory: Category?
    var currentCategoryName: String?
    var hasMultipleCategories: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MerchantGroup, rhs: MerchantGroup) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Batch Categorization Service

@MainActor
final class BatchCategorizationService: ObservableObject {
    static let shared = BatchCategorizationService()
    private init() {}

    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "BatchCategorization"
    )

    // MARK: - Published State

    @Published var isProcessing = false
    @Published var processedCount = 0
    @Published var totalToProcess = 0

    // MARK: - Group Transactions by Merchant

    /// Groups all provided transactions by their normalized merchant name.
    ///
    /// - Parameters:
    ///   - transactions: All transactions to group
    ///   - uncategorizedOnly: If true, only includes transactions without a category
    /// - Returns: Array of MerchantGroup sorted by transaction count (descending)
    func groupTransactionsByMerchant(
        _ transactions: [Transaction],
        uncategorizedOnly: Bool = false
    ) -> [MerchantGroup] {
        // Filter out transfers and optionally filter for uncategorized
        let eligible = transactions.filter { t in
            !t.isTransfer &&
            !t.merchantName.trimmingCharacters(in: .whitespaces).isEmpty &&
            (!uncategorizedOnly || t.category == nil)
        }

        // Group by normalized merchant name
        var groupDict: [String: (
            displayName: String,
            count: Int,
            total: Double,
            categories: Set<String>,
            lastCategory: Category?
        )] = [:]

        for t in eligible {
            let normalized = t.merchantName.lowercased().trimmingCharacters(in: .whitespaces)

            if var existing = groupDict[normalized] {
                existing.count += 1
                existing.total += abs(t.amount)
                if let catName = t.category?.name {
                    existing.categories.insert(catName)
                    existing.lastCategory = t.category
                }
                groupDict[normalized] = existing
            } else {
                var cats = Set<String>()
                if let catName = t.category?.name {
                    cats.insert(catName)
                }
                groupDict[normalized] = (
                    displayName: t.merchantName,
                    count: 1,
                    total: abs(t.amount),
                    categories: cats,
                    lastCategory: t.category
                )
            }
        }

        // Convert to MerchantGroup array
        let groups = groupDict.map { normalized, info in
            MerchantGroup(
                id: normalized,
                merchantName: info.displayName,
                normalizedName: normalized,
                transactionCount: info.count,
                totalAmount: info.total,
                currentCategory: info.categories.count == 1 ? info.lastCategory : nil,
                currentCategoryName: info.categories.count == 1 ? info.categories.first : nil,
                hasMultipleCategories: info.categories.count > 1
            )
        }

        // Sort by count descending (most common merchants first)
        return groups.sorted { $0.transactionCount > $1.transactionCount }
    }

    // MARK: - Batch Categorize

    /// Updates all transactions for a given merchant to the specified category,
    /// and creates or reinforces the MerchantCategoryMapping for auto-categorization.
    ///
    /// - Parameters:
    ///   - merchantName: The normalized merchant name to match
    ///   - category: The target category to assign
    ///   - transactions: All transactions to search through
    ///   - context: The SwiftData model context for persistence
    /// - Returns: Number of transactions updated
    @discardableResult
    func categorizeAll(
        merchantName: String,
        category: Category,
        transactions: [Transaction],
        context: ModelContext
    ) -> Int {
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespaces)

        isProcessing = true
        processedCount = 0

        // Find matching transactions
        let matching = transactions.filter {
            $0.merchantName.lowercased().trimmingCharacters(in: .whitespaces) == normalized &&
            !$0.isTransfer
        }

        totalToProcess = matching.count
        Self.logger.info("🏷️ Batch categorizing \(matching.count) transactions for '\(merchantName)' → \(category.name)")

        // Update each transaction
        for transaction in matching {
            transaction.category = category
            processedCount += 1
        }

        // Create or reinforce MerchantCategoryMapping
        updateMerchantMapping(
            merchantName: merchantName,
            normalizedName: normalized,
            category: category,
            transactionCount: matching.count,
            context: context
        )

        // Save changes
        do {
            try context.save()
            Self.logger.info("✅ Batch categorization saved: \(matching.count) transactions")
        } catch {
            Self.logger.error("❌ Failed to save batch categorization: \(error.localizedDescription)")
        }

        isProcessing = false
        return matching.count
    }

    // MARK: - Merchant Mapping

    /// Creates or reinforces a MerchantCategoryMapping for auto-categorization.
    private func updateMerchantMapping(
        merchantName: String,
        normalizedName: String,
        category: Category,
        transactionCount: Int,
        context: ModelContext
    ) {
        // Check for existing mapping
        let descriptor = FetchDescriptor<MerchantCategoryMapping>(
            predicate: #Predicate<MerchantCategoryMapping> { mapping in
                mapping.normalizedMerchantName == normalizedName
            }
        )

        if let existingMapping = try? context.fetch(descriptor).first {
            // Reinforce existing mapping with new category
            existingMapping.categoryID = category.id
            existingMapping.categoryName = category.name
            // Reinforce multiple times based on batch size for stronger learning
            for _ in 0..<min(transactionCount, 10) {
                existingMapping.reinforceMapping()
            }
            existingMapping.isManualOverride = true
            Self.logger.info("🔄 Reinforced mapping: '\(merchantName)' → \(category.name) (confidence: \(existingMapping.confidence))")
        } else {
            // Create new mapping
            let mapping = MerchantCategoryMapping(
                merchantName: merchantName,
                categoryID: category.id,
                categoryName: category.name,
                confidence: 0.95,  // High confidence for manual batch assignment
                isManualOverride: true
            )
            // Reinforce based on batch size
            for _ in 0..<min(transactionCount - 1, 9) {
                mapping.reinforceMapping()
            }
            context.insert(mapping)
            Self.logger.info("➕ Created mapping: '\(merchantName)' → \(category.name) (confidence: \(mapping.confidence))")
        }
    }
}
