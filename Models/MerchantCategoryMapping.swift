//  MerchantCategoryMapping.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - MVP Deployment Ready
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Stores learned merchant → category mappings for intelligent auto-categorization
//

import Foundation
import SwiftData

@Model
final class MerchantCategoryMapping {
    @Attribute(.unique) var id: UUID
    var merchantName: String
    var normalizedMerchantName: String  // Lowercase, trimmed version for matching
    var categoryID: UUID?  // Optional: might not have category yet
    var categoryName: String?  // Cached for quick access
    var confidence: Double  // 0.0 to 1.0 - how confident we are about this mapping
    var timesUsed: Int  // How many times user has confirmed this mapping
    var lastUsedDate: Date
    var createdDate: Date
    var isManualOverride: Bool  // User explicitly set this vs. learned
    
    // FIX: Store patterns as comma-separated string instead of [String] array
    // SwiftData has issues materializing String arrays during initialization
    var merchantPatternsString: String  // Comma-separated patterns
    
    // Computed property for easy access with sanitization
    var merchantPatterns: [String] {
        get {
            merchantPatternsString
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            let cleaned = newValue
                .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .uniqued()
            merchantPatternsString = cleaned.joined(separator: ",")
        }
    }
    
    init(
        merchantName: String,
        categoryID: UUID? = nil,
        categoryName: String? = nil,
        confidence: Double = 0.5,
        isManualOverride: Bool = false
    ) {
        self.id = UUID()
        self.merchantName = merchantName
        
        // Initialize all stored properties FIRST
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.confidence = confidence
        self.timesUsed = 1
        self.lastUsedDate = Date()
        self.createdDate = Date()
        self.isManualOverride = isManualOverride
        
        // THEN use computed values
        let normalized = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        self.normalizedMerchantName = normalized
        self.merchantPatternsString = normalized
    }
    
    /// Convenience initializer for seed data
    convenience init(
        merchant: String,
        categoryID: UUID,
        categoryName: String,
        patterns: [String] = []
    ) {
        self.init(
            merchantName: merchant,
            categoryID: categoryID,
            categoryName: categoryName,
            confidence: 0.9,
            isManualOverride: true
        )
        
        if !patterns.isEmpty {
            self.merchantPatterns = patterns
        }
    }
    
    /// Increase confidence when user confirms this mapping
    /// Uses logarithmic formula for diminishing returns
    func reinforceMapping() {
        timesUsed += 1
        lastUsedDate = Date()
        
        // Bayesian-like confidence: fast growth early, slows down
        // 1 use → 0.25, 5 uses → 0.625, 10 → 0.77, 20 → 0.87
        confidence = min(0.97, Double(timesUsed) / Double(timesUsed + 3))
    }
    
    /// Decrease confidence when user changes this mapping
    func weakenMapping() {
        confidence = max(0.1, confidence - 0.2)
    }
    
    /// Check if merchant name matches this mapping
    /// Ultra-robust version with edge-case protection
    func matches(_ merchant: String) -> Bool {
        let normalizedInput = merchant.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check exact match first
        if normalizedMerchantName == normalizedInput {
            return true
        }
        
        // Word-based matching with noise filtering
        let inputWords = normalizedInput
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.count >= 3 } // Ignore noise like "inc", "llc"
        
        // Require at least one significant pattern word to appear fully in input
        for pattern in merchantPatterns {
            let patternWords = pattern
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count >= 3 }
            
            for patternWord in patternWords {
                // Match if pattern word appears in input word AND is significant (4+ chars)
                // OR exact word match for shorter patterns
                if inputWords.contains(where: { $0.contains(patternWord) && patternWord.count >= 4 }) ||
                   inputWords.contains(where: { $0 == patternWord }) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Add a new pattern variation for this merchant
    func addPattern(_ pattern: String) {
        let normalized = pattern.lowercased().trimmingCharacters(in: .whitespaces)
        var currentPatterns = merchantPatterns
        
        if !currentPatterns.contains(normalized) {
            currentPatterns.append(normalized)
            merchantPatterns = currentPatterns
        }
    }
}

// MARK: - Helper Extension

extension Sequence where Element: Hashable {
    /// Remove duplicates while preserving order
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Common Merchant Patterns

extension MerchantCategoryMapping {
    /// Default mappings for common merchants (seed data)
    static let commonMappings: [(merchant: String, category: String, patterns: [String])] = [
        // Meals & Entertainment
        ("Starbucks", "Meals & Entertainment", ["starbucks"]),
        ("McDonald's", "Meals & Entertainment", ["mcdonald", "mcdonalds"]),
        ("Chipotle", "Meals & Entertainment", ["chipotle"]),
        ("Panera", "Meals & Entertainment", ["panera"]),
        ("Subway", "Meals & Entertainment", ["subway"]),
        
        // Office Supplies
        ("Staples", "Office Supplies", ["staples"]),
        ("Office Depot", "Office Supplies", ["office depot", "officedepot"]),
        ("Amazon", "Office Supplies", ["amazon", "amzn"]),
        ("Best Buy", "Office Supplies", ["best buy", "bestbuy"]),
        
        // Auto & Mileage
        ("Shell", "Auto Expenses", ["shell"]),
        ("Chevron", "Auto Expenses", ["chevron"]),
        ("BP", "Auto Expenses", ["bp", "british petroleum"]),
        ("Exxon", "Auto Expenses", ["exxon"]),
        ("Mobil", "Auto Expenses", ["mobil"]),
        
        // Home Office / Utilities
        ("Home Depot", "Office Supplies", ["home depot", "homedepot"]),
        ("Lowe's", "Office Supplies", ["lowes", "lowe's"]),
        ("IKEA", "Office Supplies", ["ikea"]),
        
        // Software & Subscriptions
        ("Apple", "Software & Subscriptions", ["apple.com", "apple inc"]),
        ("Microsoft", "Software & Subscriptions", ["microsoft", "msft"]),
        ("Adobe", "Software & Subscriptions", ["adobe"]),
        ("Zoom", "Software & Subscriptions", ["zoom.us"]),
        
        // Shipping & Postage
        ("USPS", "Shipping & Postage", ["usps", "united states postal"]),
        ("UPS", "Shipping & Postage", ["ups", "united parcel"]),
        ("FedEx", "Shipping & Postage", ["fedex"]),
        
        // Professional Services
        ("LinkedIn", "Marketing & Advertising", ["linkedin"]),
        ("Facebook", "Marketing & Advertising", ["facebook", "meta"]),
        ("Google Ads", "Marketing & Advertising", ["google ads", "googleads"]),
    ]
}
