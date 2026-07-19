//  MerchantLearningService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Centralized merchant→category learning
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Provides category suggestions based on learned merchant mappings
//  and reinforces/creates mappings when users save transactions.
//

import Foundation
import SwiftData

final class MerchantLearningService {
    static let shared = MerchantLearningService()
    private init() {}

    // MARK: - Suggest Category

    /// Returns a category suggestion for a merchant name based on learned mappings and common patterns.
    func suggestCategory(for merchant: String, context: ModelContext) -> (category: Category, confidence: Double)? {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        // Priority 1: Learned mappings from user behavior
        if let allMappings = try? context.fetch(FetchDescriptor<MerchantCategoryMapping>()) {
            for mapping in allMappings where mapping.confidence > 0.3 {
                if mapping.matches(trimmed), let catID = mapping.categoryID {
                    if let category = findCategory(id: catID, context: context) {
                        return (category, mapping.confidence)
                    }
                }
            }
        }

        // Priority 2: Common merchant patterns (hardcoded)
        let normalized = trimmed.lowercased()
        for common in MerchantCategoryMapping.commonMappings {
            for pattern in common.patterns {
                if normalized.contains(pattern) {
                    if let category = findCategoryByName(common.category, context: context) {
                        return (category, 0.75)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Learn Mapping

    /// Creates or reinforces a merchant→category mapping after user saves a transaction.
    func learnMapping(merchant: String, category: Category, context: ModelContext) {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Find existing mapping
        if let allMappings = try? context.fetch(FetchDescriptor<MerchantCategoryMapping>()) {
            for mapping in allMappings {
                if mapping.matches(trimmed) {
                    if mapping.categoryID == category.id {
                        // Same category — reinforce
                        mapping.reinforceMapping()
                    } else {
                        // Different category — update
                        mapping.categoryID = category.id
                        mapping.categoryName = category.name
                        mapping.weakenMapping()
                        mapping.timesUsed += 1
                        mapping.lastUsedDate = Date()
                    }
                    try? context.save()
                    return
                }
            }
        }

        // No existing mapping — create new one
        let newMapping = MerchantCategoryMapping(
            merchantName: trimmed,
            categoryID: category.id,
            categoryName: category.name,
            confidence: 0.5,
            isManualOverride: false
        )
        context.insert(newMapping)
        try? context.save()
    }

    // MARK: - Helpers

    private func findCategory(id: UUID, context: ModelContext) -> Category? {
        let descriptor = FetchDescriptor<Category>()
        guard let categories = try? context.fetch(descriptor) else { return nil }
        return categories.first { $0.id == id }
    }

    private func findCategoryByName(_ name: String, context: ModelContext) -> Category? {
        let descriptor = FetchDescriptor<Category>()
        guard let categories = try? context.fetch(descriptor) else { return nil }
        return categories.first { $0.name == name }
    }
}
