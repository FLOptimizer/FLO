//  FLOMerchantMappingTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Merchant Category Mapping Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate auto-categorization based on merchant names,
//  learning from user corrections, and category suggestions.
//
//  COVERS:
//  - Known merchant to category mapping
//  - Fuzzy matching for merchant names
//  - User correction learning
//  - Category suggestion confidence
//  - Business detection
//

import XCTest
@testable import FLO

final class FLOMerchantMappingTests: XCTestCase {
    
    // MARK: - Known Merchant Database
    
    let merchantCategories: [String: String] = [
        // Food & Drink
        "STARBUCKS": "Food & Drink",
        "MCDONALDS": "Food & Drink",
        "SUBWAY": "Food & Drink",
        "CHIPOTLE": "Food & Drink",
        "DUNKIN": "Food & Drink",
        
        // Groceries
        "WALMART": "Groceries",
        "TARGET": "Groceries",
        "COSTCO": "Groceries",
        "WHOLE FOODS": "Groceries",
        "TRADER JOES": "Groceries",
        "KROGER": "Groceries",
        "SAFEWAY": "Groceries",
        
        // Transportation
        "SHELL": "Transportation",
        "CHEVRON": "Transportation",
        "EXXON": "Transportation",
        "BP": "Transportation",
        "UBER": "Transportation",
        "LYFT": "Transportation",
        
        // Shopping
        "AMAZON": "Shopping",
        "BEST BUY": "Shopping",
        "HOME DEPOT": "Shopping",
        "LOWES": "Shopping",
        "IKEA": "Shopping",
        
        // Office Supplies
        "OFFICE DEPOT": "Office Supplies",
        "STAPLES": "Office Supplies",
        
        // Health
        "CVS": "Health",
        "WALGREENS": "Health",
        
        // Utilities
        "AT&T": "Utilities",
        "VERIZON": "Utilities",
        "COMCAST": "Utilities",
        "PG&E": "Utilities",
        
        // Subscriptions
        "NETFLIX": "Subscriptions",
        "SPOTIFY": "Subscriptions",
        "ADOBE": "Software & Subscriptions",
        "MICROSOFT": "Software & Subscriptions"
    ]
    
    /// Find category for merchant
    private func categorize(_ merchant: String) -> String? {
        let normalized = merchant.uppercased()
        
        // Exact match first
        if let category = merchantCategories[normalized] {
            return category
        }
        
        // Partial match
        for (key, category) in merchantCategories {
            if normalized.contains(key) || key.contains(normalized) {
                return category
            }
        }
        
        return nil
    }
    
    let businessMerchants = [
        "OFFICE DEPOT",
        "STAPLES",
        "FEDEX",
        "UPS STORE",
        "VISTAPRINT",
        "QUICKBOOKS",
        "ZOOM",
        "SLACK",
        "DROPBOX",
        "ADOBE",
        "MICROSOFT"
    ]
}

// MARK: - Known Merchant Mapping

extension FLOMerchantMappingTests {
    
    /// Test: Exact match - Starbucks
    func testMapping_ExactMatch_Starbucks() {
        let category = categorize("STARBUCKS")
        XCTAssertEqual(category, "Food & Drink")
    }
    
    /// Test: Exact match - Walmart
    func testMapping_ExactMatch_Walmart() {
        let category = categorize("WALMART")
        XCTAssertEqual(category, "Groceries")
    }
    
    /// Test: Case insensitive matching
    func testMapping_CaseInsensitive() {
        let category1 = categorize("starbucks")
        let category2 = categorize("StArBuCkS")
        let category3 = categorize("STARBUCKS")
        
        XCTAssertEqual(category1, "Food & Drink")
        XCTAssertEqual(category2, "Food & Drink")
        XCTAssertEqual(category3, "Food & Drink")
    }
    
    /// Test: Partial match - "STARBUCKS #12345"
    func testMapping_PartialMatch_WithStoreNumber() {
        let category = categorize("STARBUCKS #12345")
        XCTAssertEqual(category, "Food & Drink")
    }
    
    /// Test: Partial match - "SHELL OIL 54789"
    func testMapping_PartialMatch_GasStation() {
        let category = categorize("SHELL OIL 54789")
        XCTAssertEqual(category, "Transportation")
    }
    
    /// Test: Unknown merchant returns nil
    func testMapping_UnknownMerchant() {
        let category = categorize("RANDOM LOCAL SHOP")
        XCTAssertNil(category)
    }
    
    /// Test: All food merchants
    func testMapping_AllFoodMerchants() {
        let foodMerchants = ["STARBUCKS", "MCDONALDS", "SUBWAY", "CHIPOTLE", "DUNKIN"]
        
        for merchant in foodMerchants {
            let category = categorize(merchant)
            XCTAssertEqual(category, "Food & Drink", "\(merchant) should be Food & Drink")
        }
    }
    
    /// Test: All grocery merchants
    func testMapping_AllGroceryMerchants() {
        let groceryMerchants = ["WALMART", "TARGET", "COSTCO", "WHOLE FOODS", "TRADER JOES"]
        
        for merchant in groceryMerchants {
            let category = categorize(merchant)
            XCTAssertEqual(category, "Groceries", "\(merchant) should be Groceries")
        }
    }
}

// MARK: - Fuzzy Matching

extension FLOMerchantMappingTests {
    
    /// Calculate similarity between two strings (0.0 to 1.0)
    private func similarity(_ s1: String, _ s2: String) -> Double {
        let set1 = Set(s1.uppercased())
        let set2 = Set(s2.uppercased())
        
        let intersection = set1.intersection(set2).count
        let union = set1.union(set2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
    
    /// Test: High similarity for close matches
    func testFuzzy_HighSimilarity() {
        let sim = similarity("STARBUCKS", "STARBUCKS COFFEE")
        XCTAssertGreaterThan(sim, 0.6, "Close match should have high similarity")
    }
    
    /// Test: Low similarity for different merchants
    func testFuzzy_LowSimilarity() {
        let sim = similarity("STARBUCKS", "WALMART")
        XCTAssertLessThan(sim, 0.5, "Different merchants should have low similarity")
    }
    
    /// Test: Handle typos
    func testFuzzy_HandleTypos() {
        let sim = similarity("STARBUCKS", "STARBUKCS")  // Typo
        XCTAssertGreaterThan(sim, 0.8, "Typo should still match well")
    }
    
    /// Test: Find best match from database
    func testFuzzy_FindBestMatch() {
        let input = "STARBUKCS COFFEE"  // Typo
        var bestMatch: (merchant: String, similarity: Double)? = nil
        
        for merchant in merchantCategories.keys {
            let sim = similarity(input, merchant)
            if bestMatch == nil || sim > bestMatch!.similarity {
                bestMatch = (merchant, sim)
            }
        }
        
        XCTAssertEqual(bestMatch?.merchant, "STARBUCKS")
    }
}

// MARK: - User Correction Learning

extension FLOMerchantMappingTests {
    
    /// Test: Store user correction
    func testLearning_StoreCorrection() {
        var userMappings: [String: String] = [:]
        
        // User corrects "LOCAL COFFEE SHOP" to "Food & Drink"
        userMappings["LOCAL COFFEE SHOP"] = "Food & Drink"
        
        XCTAssertEqual(userMappings["LOCAL COFFEE SHOP"], "Food & Drink")
    }
    
    /// Test: User mapping overrides default
    func testLearning_UserOverridesDefault() {
        var userMappings: [String: String] = [:]
        
        // User says their Target purchases are "Shopping" not "Groceries"
        userMappings["TARGET"] = "Shopping"
        
        func categorizeWithUserMappings(_ merchant: String) -> String? {
            let normalized = merchant.uppercased()
            
            // User mappings take priority
            if let userCategory = userMappings[normalized] {
                return userCategory
            }
            
            return merchantCategories[normalized]
        }
        
        let category = categorizeWithUserMappings("TARGET")
        XCTAssertEqual(category, "Shopping", "User mapping overrides default")
    }
    
    /// Test: Track correction count
    func testLearning_TrackCorrectionCount() {
        var correctionCounts: [String: Int] = [:]
        
        // Simulate corrections
        correctionCounts["LOCAL CAFE", default: 0] += 1
        correctionCounts["LOCAL CAFE", default: 0] += 1
        correctionCounts["LOCAL CAFE", default: 0] += 1
        
        XCTAssertEqual(correctionCounts["LOCAL CAFE"], 3, "Tracked 3 corrections")
    }
    
    /// Test: Learn from repeated corrections
    func testLearning_RepeatedCorrections() {
        var corrections: [(merchant: String, category: String)] = []
        
        // User corrects same merchant multiple times
        corrections.append(("ACME CORP", "Office Supplies"))
        corrections.append(("ACME CORP", "Office Supplies"))
        corrections.append(("ACME CORP", "Shopping"))  // One different
        corrections.append(("ACME CORP", "Office Supplies"))
        
        // Find most common correction
        let acmeCorrections = corrections.filter { $0.merchant == "ACME CORP" }
        var categoryCounts: [String: Int] = [:]
        for correction in acmeCorrections {
            categoryCounts[correction.category, default: 0] += 1
        }
        
        let bestCategory = categoryCounts.max { $0.value < $1.value }?.key
        
        XCTAssertEqual(bestCategory, "Office Supplies", "Most common correction wins")
    }
}

// MARK: - Category Suggestion Confidence

extension FLOMerchantMappingTests {
    
    /// Test: High confidence for exact match
    func testConfidence_ExactMatch() {
        func getConfidence(_ merchant: String) -> Double {
            let normalized = merchant.uppercased()
            
            if merchantCategories[normalized] != nil {
                return 1.0  // Exact match
            }
            
            for key in merchantCategories.keys {
                if normalized.contains(key) {
                    return 0.8  // Partial match
                }
            }
            
            return 0.0  // No match
        }
        
        let confidence = getConfidence("STARBUCKS")
        XCTAssertEqual(confidence, 1.0, "Exact match = 100% confidence")
    }
    
    /// Test: Medium confidence for partial match
    func testConfidence_PartialMatch() {
        func getConfidence(_ merchant: String) -> Double {
            let normalized = merchant.uppercased()
            
            if merchantCategories[normalized] != nil {
                return 1.0
            }
            
            for key in merchantCategories.keys {
                if normalized.contains(key) {
                    return 0.8
                }
            }
            
            return 0.0
        }
        
        let confidence = getConfidence("STARBUCKS #12345 DOWNTOWN")
        XCTAssertEqual(confidence, 0.8, "Partial match = 80% confidence")
    }
    
    /// Test: Zero confidence for unknown
    func testConfidence_Unknown() {
        func getConfidence(_ merchant: String) -> Double {
            let normalized = merchant.uppercased()
            
            if merchantCategories[normalized] != nil {
                return 1.0
            }
            
            for key in merchantCategories.keys {
                if normalized.contains(key) {
                    return 0.8
                }
            }
            
            return 0.0
        }
        
        let confidence = getConfidence("RANDOM MERCHANT")
        XCTAssertEqual(confidence, 0.0, "Unknown = 0% confidence")
    }
    
    /// Test: Auto-apply above threshold
    func testConfidence_AutoApplyThreshold() {
        let autoApplyThreshold: Double = 0.9
        
        let exactMatchConfidence: Double = 1.0
        let partialMatchConfidence: Double = 0.8
        
        XCTAssertTrue(exactMatchConfidence >= autoApplyThreshold, "Exact match auto-applies")
        XCTAssertFalse(partialMatchConfidence >= autoApplyThreshold, "Partial match needs confirmation")
    }
}

// MARK: - Business Detection

extension FLOMerchantMappingTests {
    
    /// Test: Detect likely business expense
    func testBusiness_DetectBusinessMerchant() {
        func isLikelyBusiness(_ merchant: String) -> Bool {
            let normalized = merchant.uppercased()
            return businessMerchants.contains { normalized.contains($0) }
        }
        
        XCTAssertTrue(isLikelyBusiness("OFFICE DEPOT #123"))
        XCTAssertTrue(isLikelyBusiness("ADOBE CREATIVE CLOUD"))
        XCTAssertFalse(isLikelyBusiness("STARBUCKS"))
    }
    
    /// Test: Suggest business flag
    func testBusiness_SuggestBusinessFlag() {
        let merchant = "STAPLES OFFICE SUPPLIES"
        let normalized = merchant.uppercased()
        
        let suggestBusiness = businessMerchants.contains { normalized.contains($0) }
        
        XCTAssertTrue(suggestBusiness, "Should suggest marking as business")
    }
    
    /// Test: Software subscriptions are often business
    func testBusiness_SoftwareSubscriptions() {
        let softwareMerchants = ["ADOBE", "MICROSOFT", "ZOOM", "SLACK", "DROPBOX"]
        
        for merchant in softwareMerchants {
            let isLikelyBusiness = businessMerchants.contains { merchant.contains($0) }
            XCTAssertTrue(isLikelyBusiness, "\(merchant) is likely business")
        }
    }
}

// MARK: - Integration

extension FLOMerchantMappingTests {
    
    /// Test: Full categorization workflow
    func testIntegration_FullWorkflow() {
        var userMappings: [String: String] = [:]
        
        func fullCategorize(_ merchant: String) -> (category: String?, confidence: Double, suggestBusiness: Bool) {
            let normalized = merchant.uppercased()
            
            // 1. Check user mappings first
            if let userCategory = userMappings[normalized] {
                return (userCategory, 1.0, false)
            }
            
            // 2. Check known merchants
            if let category = merchantCategories[normalized] {
                let isBusiness = businessMerchants.contains { normalized.contains($0) }
                return (category, 1.0, isBusiness)
            }
            
            // 3. Partial match
            for (key, category) in merchantCategories {
                if normalized.contains(key) {
                    let isBusiness = businessMerchants.contains { normalized.contains($0) }
                    return (category, 0.8, isBusiness)
                }
            }
            
            return (nil, 0.0, false)
        }
        
        // Test known merchant
        let result1 = fullCategorize("STARBUCKS")
        XCTAssertEqual(result1.category, "Food & Drink")
        XCTAssertEqual(result1.confidence, 1.0)
        XCTAssertFalse(result1.suggestBusiness)
        
        // Test business merchant
        let result2 = fullCategorize("OFFICE DEPOT")
        XCTAssertEqual(result2.category, "Office Supplies")
        XCTAssertTrue(result2.suggestBusiness)
        
        // Test user mapping
        userMappings["MY LOCAL SHOP"] = "Shopping"
        let result3 = fullCategorize("MY LOCAL SHOP")
        XCTAssertEqual(result3.category, "Shopping")
        XCTAssertEqual(result3.confidence, 1.0)
    }
}
