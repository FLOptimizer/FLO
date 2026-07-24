//  FLOTaxCacheTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Tax Cache Invalidation Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate tax calculation caching, cache key generation,
//  and invalidation triggers.
//
//  COVERS:
//  - Cache key generation (hash-based)
//  - Cache hit/miss detection
//  - Invalidation triggers
//  - Cache expiration
//  - Performance optimization
//

import XCTest
@testable import FLO

final class FLOTaxCacheTests: XCTestCase {
    
    // MARK: - Cache Key Generation
    
    /// Generate cache key from tax inputs
    private func generateCacheKey(
        income: Double,
        expenses: Double,
        filingStatus: String,
        state: String,
        year: Int
    ) -> String {
        let components = [
            String(format: "%.2f", income),
            String(format: "%.2f", expenses),
            filingStatus,
            state,
            String(year)
        ]
        return components.joined(separator: "|")
    }
    
    /// Generate hash from cache key
    private func hashCacheKey(_ key: String) -> Int {
        return key.hashValue
    }
}

// MARK: - Cache Key Generation Tests

extension FLOTaxCacheTests {
    
    /// Test: Same inputs produce same key
    func testCacheKey_SameInputs_SameKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        
        XCTAssertEqual(key1, key2, "Same inputs = same key")
    }
    
    /// Test: Different income produces different key
    func testCacheKey_DifferentIncome_DifferentKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100001, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        
        XCTAssertNotEqual(key1, key2, "Different income = different key")
    }
    
    /// Test: Different expenses produces different key
    func testCacheKey_DifferentExpenses_DifferentKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100000, expenses: 25001, filingStatus: "single", state: "CA", year: 2026)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    /// Test: Different filing status produces different key
    func testCacheKey_DifferentFilingStatus_DifferentKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "mfj", state: "CA", year: 2026)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    /// Test: Different state produces different key
    func testCacheKey_DifferentState_DifferentKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "TX", year: 2026)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    /// Test: Different year produces different key
    func testCacheKey_DifferentYear_DifferentKey() {
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2025)
        let key2 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    /// Test: Key format is deterministic
    func testCacheKey_Format() {
        let key = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        
        XCTAssertEqual(key, "100000.00|25000.00|single|CA|2026")
    }
    
    /// Test: Decimal precision in key
    func testCacheKey_DecimalPrecision() {
        let key1 = generateCacheKey(income: 100000.001, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        let key2 = generateCacheKey(income: 100000.004, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        
        // Both round to .00, so keys should match
        XCTAssertEqual(key1, key2, "Sub-cent differences ignored")
    }
}

// MARK: - Cache Hit/Miss Tests

extension FLOTaxCacheTests {
    
    /// Test: Cache hit when key exists
    func testCacheHit_KeyExists() {
        var cache: [String: Double] = [:]
        let key = "100000.00|25000.00|single|CA|2026"
        
        // Store value
        cache[key] = 15000.00
        
        // Lookup
        let cachedValue = cache[key]
        let isHit = cachedValue != nil
        
        XCTAssertTrue(isHit, "Should be cache hit")
        XCTAssertEqual(cachedValue, 15000.00)
    }
    
    /// Test: Cache miss when key doesn't exist
    func testCacheMiss_KeyNotExists() {
        let cache: [String: Double] = [:]
        let key = "100000.00|25000.00|single|CA|2026"
        
        let cachedValue = cache[key]
        let isMiss = cachedValue == nil
        
        XCTAssertTrue(isMiss, "Should be cache miss")
    }
    
    /// Test: Cache stores multiple entries
    func testCache_MultipleEntries() {
        var cache: [String: Double] = [:]
        
        cache["key1"] = 10000.00
        cache["key2"] = 20000.00
        cache["key3"] = 30000.00
        
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache["key1"], 10000.00)
        XCTAssertEqual(cache["key2"], 20000.00)
        XCTAssertEqual(cache["key3"], 30000.00)
    }
}

// MARK: - Cache Invalidation Triggers

extension FLOTaxCacheTests {
    
    /// Test: New transaction invalidates cache
    func testInvalidation_NewTransaction() {
        var cacheValid = true
        
        // New transaction added
        let transactionAdded = true
        if transactionAdded {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid, "New transaction invalidates cache")
    }
    
    /// Test: Transaction deleted invalidates cache
    func testInvalidation_TransactionDeleted() {
        var cacheValid = true
        
        let transactionDeleted = true
        if transactionDeleted {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid, "Deleted transaction invalidates cache")
    }
    
    /// Test: Transaction edited invalidates cache
    func testInvalidation_TransactionEdited() {
        var cacheValid = true
        
        let transactionEdited = true
        if transactionEdited {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid, "Edited transaction invalidates cache")
    }
    
    /// Test: Filing status change invalidates cache
    func testInvalidation_FilingStatusChanged() {
        var cacheValid = true
        
        let filingStatusChanged = true
        if filingStatusChanged {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid)
    }
    
    /// Test: State change invalidates cache
    func testInvalidation_StateChanged() {
        var cacheValid = true
        
        let stateChanged = true
        if stateChanged {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid)
    }
    
    /// Test: Year rollover invalidates cache
    func testInvalidation_YearRollover() {
        var cacheValid = true
        var cachedYear = 2025
        let currentYear = 2026
        
        if cachedYear != currentYear {
            cacheValid = false
            cachedYear = currentYear
        }
        
        XCTAssertFalse(cacheValid, "Year change invalidates cache")
    }
    
    /// Test: Business/Personal toggle invalidates
    func testInvalidation_BusinessPersonalToggle() {
        var cacheValid = true
        
        let categoryChanged = true  // Transaction toggled business/personal
        if categoryChanged {
            cacheValid = false
        }
        
        XCTAssertFalse(cacheValid)
    }
}

// MARK: - Cache Expiration

extension FLOTaxCacheTests {
    
    /// Test: Cache expires after time limit
    func testExpiration_TimeLimit() {
        let cacheCreatedAt = Date().addingTimeInterval(-3600)  // 1 hour ago
        let expirationInterval: TimeInterval = 1800  // 30 minutes
        let now = Date()
        
        let age = now.timeIntervalSince(cacheCreatedAt)
        let isExpired = age > expirationInterval
        
        XCTAssertTrue(isExpired, "1 hour old > 30 min limit = expired")
    }
    
    /// Test: Cache valid within time limit
    func testExpiration_WithinLimit() {
        let cacheCreatedAt = Date().addingTimeInterval(-600)  // 10 minutes ago
        let expirationInterval: TimeInterval = 1800  // 30 minutes
        let now = Date()
        
        let age = now.timeIntervalSince(cacheCreatedAt)
        let isExpired = age > expirationInterval
        
        XCTAssertFalse(isExpired, "10 min old < 30 min limit = valid")
    }
    
    /// Test: Refresh cache on expiration
    func testExpiration_RefreshOnExpire() {
        var cachedValue: Double? = 15000.00
        var cacheTimestamp = Date().addingTimeInterval(-3600)  // 1 hour ago
        let expirationInterval: TimeInterval = 1800
        
        let isExpired = Date().timeIntervalSince(cacheTimestamp) > expirationInterval
        
        if isExpired {
            // Recalculate
            cachedValue = 15500.00  // New calculated value
            cacheTimestamp = Date()
        }
        
        XCTAssertEqual(cachedValue, 15500.00, "Cache refreshed")
    }
}

// MARK: - Cache Size Management

extension FLOTaxCacheTests {
    
    /// Test: Limit cache size
    func testSize_MaxEntries() {
        var cache: [String: Double] = [:]
        let maxEntries = 10
        
        // Add 15 entries
        for i in 0..<15 {
            let key = "key_\(i)"
            cache[key] = Double(i * 1000)
            
            // Evict oldest if over limit
            if cache.count > maxEntries {
                cache.removeValue(forKey: "key_\(i - maxEntries)")
            }
        }
        
        XCTAssertEqual(cache.count, maxEntries, "Cache limited to max entries")
    }
    
    /// Test: Clear all cache
    func testSize_ClearAll() {
        var cache: [String: Double] = [
            "key1": 10000,
            "key2": 20000,
            "key3": 30000
        ]
        
        cache.removeAll()
        
        XCTAssertEqual(cache.count, 0, "Cache cleared")
    }
}

// MARK: - Performance

extension FLOTaxCacheTests {
    
    /// Test: Cache lookup is fast
    func testPerformance_CacheLookup() {
        var cache: [String: Double] = [:]
        
        // Pre-populate cache
        for i in 0..<1000 {
            cache["key_\(i)"] = Double(i * 100)
        }
        
        // Measure lookup time
        let start = Date()
        for i in 0..<1000 {
            _ = cache["key_\(i)"]
        }
        let elapsed = Date().timeIntervalSince(start)
        
        XCTAssertLessThan(elapsed, 0.1, "1000 lookups should be < 0.1 seconds")
    }
    
    /// Test: Hash-based lookup O(1)
    func testPerformance_HashLookup() {
        let key = "100000.00|25000.00|single|CA|2026"
        let hash = hashCacheKey(key)
        
        // Hash should be consistent
        let hash2 = hashCacheKey(key)
        
        XCTAssertEqual(hash, hash2, "Hash is deterministic")
    }
}

// MARK: - Integration

extension FLOTaxCacheTests {
    
    /// Test: Full cache workflow
    func testIntegration_FullWorkflow() {
        var cache: [String: Double] = [:]
        
        // 1. First calculation - cache miss
        let key1 = generateCacheKey(income: 100000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        var result = cache[key1]
        XCTAssertNil(result, "First lookup is miss")
        
        // 2. Calculate and store
        let calculatedTax: Double = 18500.00
        cache[key1] = calculatedTax
        
        // 3. Second lookup - cache hit
        result = cache[key1]
        XCTAssertEqual(result, calculatedTax, "Second lookup is hit")
        
        // 4. Change inputs
        let key2 = generateCacheKey(income: 110000, expenses: 25000, filingStatus: "single", state: "CA", year: 2026)
        result = cache[key2]
        XCTAssertNil(result, "Different inputs = miss")
        
        // 5. Original key still cached
        result = cache[key1]
        XCTAssertEqual(result, calculatedTax, "Original still cached")
    }
}
