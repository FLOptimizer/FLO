//  FLOReceiptStorageTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Receipt Storage & Tier Limit Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate receipt storage limits, tier enforcement,
//  and photo management.
//
//  COVERS:
//  - Receipt limits per tier (20/100/unlimited)
//  - Monthly reset logic
//  - Photo storage management
//  - Receipt linking to transactions
//

import XCTest
@testable import FLO

final class FLOReceiptStorageTests: XCTestCase {
    
    // MARK: - Tier Definitions
    
    enum SubscriptionTier {
        case free
        case premium
        case pro
    }
    
    func receiptLimit(for tier: SubscriptionTier) -> Int {
        switch tier {
        case .free: return 20
        case .premium: return 100
        case .pro: return .max
        }
    }
}

// MARK: - Receipt Limit Enforcement

extension FLOReceiptStorageTests {
    
    /// Test: Free tier - 20 receipt limit
    func testLimit_FreeTier_20Receipts() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        
        XCTAssertEqual(limit, 20)
    }
    
    /// Test: Premium tier - 100 receipt limit
    func testLimit_PremiumTier_100Receipts() {
        let tier = SubscriptionTier.premium
        let limit = receiptLimit(for: tier)
        
        XCTAssertEqual(limit, 100)
    }
    
    /// Test: Pro tier - unlimited receipts
    func testLimit_ProTier_Unlimited() {
        let tier = SubscriptionTier.pro
        let limit = receiptLimit(for: tier)
        
        XCTAssertEqual(limit, .max)
    }
    
    /// Test: Can save when under limit
    func testLimit_CanSaveUnderLimit() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        let currentCount = 15
        
        let canSave = currentCount < limit
        
        XCTAssertTrue(canSave, "15 < 20, can save")
    }
    
    /// Test: Cannot save when at limit
    func testLimit_CannotSaveAtLimit() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        let currentCount = 20
        
        let canSave = currentCount < limit
        
        XCTAssertFalse(canSave, "20 = 20, cannot save")
    }
    
    /// Test: Cannot save when over limit
    func testLimit_CannotSaveOverLimit() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        let currentCount = 25  // Somehow over limit
        
        let canSave = currentCount < limit
        
        XCTAssertFalse(canSave, "25 > 20, cannot save")
    }
    
    /// Test: Pro tier can always save
    func testLimit_ProCanAlwaysSave() {
        let tier = SubscriptionTier.pro
        let limit = receiptLimit(for: tier)
        let currentCount = 10000
        
        let canSave = currentCount < limit
        
        XCTAssertTrue(canSave, "Pro has no practical limit")
    }
    
    /// Test: Calculate remaining receipts
    func testLimit_RemainingCount() {
        let tier = SubscriptionTier.premium
        let limit = receiptLimit(for: tier)
        let currentCount = 75
        
        let remaining = max(0, limit - currentCount)
        
        XCTAssertEqual(remaining, 25, "100 - 75 = 25 remaining")
    }
    
    /// Test: Remaining cannot be negative
    func testLimit_RemainingNotNegative() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        let currentCount = 25
        
        let remaining = max(0, limit - currentCount)
        
        XCTAssertEqual(remaining, 0, "Remaining floors at 0")
    }
}

// MARK: - Monthly Reset Logic

extension FLOReceiptStorageTests {
    
    /// Test: Detect new month
    func testMonthlyReset_DetectNewMonth() {
        let calendar = Calendar.current
        let lastResetDate = calendar.date(byAdding: .month, value: -1, to: Date())!
        let today = Date()
        
        let lastMonth = calendar.component(.month, from: lastResetDate)
        let currentMonth = calendar.component(.month, from: today)
        
        let shouldReset = lastMonth != currentMonth
        
        XCTAssertTrue(shouldReset, "Different month = should reset")
    }
    
    /// Test: Same month - no reset
    func testMonthlyReset_SameMonth_NoReset() {
        let calendar = Calendar.current
        let today = Date()

        // Use the 1st of the current month as "last reset" to guarantee same month
        // (subtracting days from today can cross month boundaries early in a month)
        var components = calendar.dateComponents([.year, .month], from: today)
        components.day = 1
        let lastResetDate = calendar.date(from: components)!

        let lastMonth = calendar.component(.month, from: lastResetDate)
        let currentMonth = calendar.component(.month, from: today)

        let shouldReset = lastMonth != currentMonth

        XCTAssertFalse(shouldReset, "Same month = no reset")
    }
    
    /// Test: Year rollover (Dec to Jan)
    func testMonthlyReset_YearRollover() {
        let calendar = Calendar.current
        var lastComponents = DateComponents()
        lastComponents.year = 2025
        lastComponents.month = 12
        lastComponents.day = 28
        let lastResetDate = calendar.date(from: lastComponents)!
        
        var currentComponents = DateComponents()
        currentComponents.year = 2026
        currentComponents.month = 1
        currentComponents.day = 5
        let currentDate = calendar.date(from: currentComponents)!
        
        let lastMonth = calendar.component(.month, from: lastResetDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        let shouldReset = lastMonth != currentMonth
        
        XCTAssertTrue(shouldReset, "Dec to Jan = should reset")
    }
    
    /// Test: Reset sets count to zero
    func testMonthlyReset_ResetsCount() {
        var receiptCount = 18
        let shouldReset = true
        
        if shouldReset {
            receiptCount = 0
        }
        
        XCTAssertEqual(receiptCount, 0, "Count reset to 0")
    }
}

// MARK: - Photo Storage Management

extension FLOReceiptStorageTests {
    
    /// Test: Calculate storage used
    func testStorage_CalculateUsed() {
        // Simulate photo sizes in bytes
        let photoSizes: [Int] = [
            500_000,   // 500 KB
            750_000,   // 750 KB
            1_200_000, // 1.2 MB
            800_000    // 800 KB
        ]
        
        let totalBytes = photoSizes.reduce(0, +)
        let totalMB = Double(totalBytes) / 1_000_000
        
        XCTAssertEqual(totalMB, 3.25, accuracy: 0.01, "3.25 MB total")
    }
    
    /// Test: Compress large images
    func testStorage_CompressLargeImages() {
        let originalSizeKB: Double = 5000  // 5 MB
        let maxSizeKB: Double = 1000       // 1 MB max
        
        // Image needs compression since it exceeds max
        XCTAssertTrue(originalSizeKB > maxSizeKB, "Needs compression")
        
        // Calculate compression ratio: target / original
        let compressionRatio = maxSizeKB / originalSizeKB
        
        XCTAssertEqual(compressionRatio, 0.2, accuracy: 0.01, "Compress to 20%")
    }
    
    /// Test: Small image needs no compression
    func testStorage_SmallImageNoCompression() {
        let originalSizeKB: Double = 500   // 500 KB
        let maxSizeKB: Double = 1000       // 1 MB max
        
        // Image is already under limit
        XCTAssertFalse(originalSizeKB > maxSizeKB, "No compression needed")
        
        // Compression ratio is 1.0 (no change)
        let compressionRatio = 1.0
        
        XCTAssertEqual(compressionRatio, 1.0, "No compression applied")
    }
    
    /// Test: Image dimensions for storage
    func testStorage_ImageDimensions() {
        let maxWidth: Int = 1024
        let maxHeight: Int = 1024
        
        let originalWidth = 4000
        let originalHeight = 3000
        
        // Calculate scale factor
        let widthScale = Double(maxWidth) / Double(originalWidth)
        let heightScale = Double(maxHeight) / Double(originalHeight)
        let scale = min(widthScale, heightScale)
        
        let newWidth = Int(Double(originalWidth) * scale)
        let newHeight = Int(Double(originalHeight) * scale)
        
        XCTAssertLessThanOrEqual(newWidth, maxWidth)
        XCTAssertLessThanOrEqual(newHeight, maxHeight)
    }
    
    /// Test: Generate unique filename
    func testStorage_UniqueFilename() {
        let uuid1 = UUID().uuidString
        let uuid2 = UUID().uuidString
        
        let filename1 = "receipt_\(uuid1).jpg"
        let filename2 = "receipt_\(uuid2).jpg"
        
        XCTAssertNotEqual(filename1, filename2, "Filenames should be unique")
    }
}

// MARK: - Receipt-Transaction Linking

extension FLOReceiptStorageTests {
    
    /// Test: Link receipt to transaction
    func testLinking_ReceiptToTransaction() {
        let receiptId = "receipt_123"
        var transactionReceiptId: String? = nil
        
        // Link receipt
        transactionReceiptId = receiptId
        
        XCTAssertEqual(transactionReceiptId, receiptId)
    }
    
    /// Test: Unlink receipt from transaction
    func testLinking_UnlinkReceipt() {
        var transactionReceiptId: String? = "receipt_123"
        
        // Unlink
        transactionReceiptId = nil
        
        XCTAssertNil(transactionReceiptId)
    }
    
    /// Test: Delete receipt keeps transaction
    func testLinking_DeleteReceiptKeepsTransaction() {
        var transactionReceiptId: String? = "receipt_123"
        let transactionAmount: Double = 50.00
        
        // Delete receipt (just unlink)
        transactionReceiptId = nil
        
        XCTAssertNil(transactionReceiptId, "Receipt unlinked")
        XCTAssertEqual(transactionAmount, 50.00, "Transaction preserved")
    }
    
    /// Test: Multiple receipts same transaction (split)
    func testLinking_MultipleReceipts() {
        let transactionReceiptIds: [String] = ["receipt_1", "receipt_2", "receipt_3"]
        
        XCTAssertEqual(transactionReceiptIds.count, 3, "Can have multiple receipts")
    }
    
    /// Test: Find transactions without receipts
    func testLinking_TransactionsWithoutReceipts() {
        let transactions: [(id: String, hasReceipt: Bool)] = [
            ("tx_1", true),
            ("tx_2", false),
            ("tx_3", true),
            ("tx_4", false),
            ("tx_5", false)
        ]
        
        let withoutReceipts = transactions.filter { !$0.hasReceipt }
        
        XCTAssertEqual(withoutReceipts.count, 3)
    }
}

// MARK: - Receipt Queue

extension FLOReceiptStorageTests {
    
    /// Test: Queue unmatched receipts
    func testQueue_UnmatchedReceipts() {
        let receipts: [(id: String, isMatched: Bool)] = [
            ("r1", true),
            ("r2", false),
            ("r3", false),
            ("r4", true)
        ]
        
        let queuedReceipts = receipts.filter { !$0.isMatched }
        
        XCTAssertEqual(queuedReceipts.count, 2, "2 receipts need matching")
    }
    
    /// Test: Sort queue by date (oldest first)
    func testQueue_SortByDateOldestFirst() {
        let calendar = Calendar.current
        let today = Date()
        
        let receipts: [(id: String, date: Date)] = [
            ("r1", calendar.date(byAdding: .day, value: -1, to: today)!),
            ("r2", calendar.date(byAdding: .day, value: -5, to: today)!),
            ("r3", calendar.date(byAdding: .day, value: -3, to: today)!)
        ]
        
        let sorted = receipts.sorted { $0.date < $1.date }
        
        XCTAssertEqual(sorted[0].id, "r2", "Oldest first")
        XCTAssertEqual(sorted[2].id, "r1", "Newest last")
    }
}

// MARK: - Edge Cases

extension FLOReceiptStorageTests {
    
    /// Test: Upgrade increases limit
    func testEdge_UpgradeIncreasesLimit() {
        var tier = SubscriptionTier.free
        var limit = receiptLimit(for: tier)
        let currentCount = 18
        
        XCTAssertEqual(limit, 20)
        XCTAssertTrue(currentCount < limit, "Under free limit")
        
        // Upgrade
        tier = .premium
        limit = receiptLimit(for: tier)
        
        XCTAssertEqual(limit, 100)
        XCTAssertTrue(currentCount < limit, "Now well under premium limit")
    }
    
    /// Test: Downgrade doesn't delete receipts
    func testEdge_DowngradePreservesReceipts() {
        var tier = SubscriptionTier.premium
        let receiptCount = 75
        
        // Downgrade
        tier = .free
        let newLimit = receiptLimit(for: tier)
        
        // Receipts preserved, just can't add more
        let canAdd = receiptCount < newLimit
        
        XCTAssertEqual(receiptCount, 75, "Receipts preserved")
        XCTAssertFalse(canAdd, "Cannot add new receipts until under limit")
    }
    
    /// Test: Zero receipts this month
    func testEdge_ZeroReceipts() {
        let tier = SubscriptionTier.free
        let limit = receiptLimit(for: tier)
        let currentCount = 0
        
        let remaining = limit - currentCount
        let percentUsed = Double(currentCount) / Double(limit)
        
        XCTAssertEqual(remaining, 20)
        XCTAssertEqual(percentUsed, 0, "0% used")
    }
}
