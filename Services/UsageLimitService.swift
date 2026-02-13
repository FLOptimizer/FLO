//  UsageLimitService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Debug Count Overrides for Limit Testing
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Central service for tracking and enforcing subscription tier limits.
//  Provides real-time usage counts and limit checks for:
//  - Transactions (50/month Free, unlimited Premium/Pro)
//  - Receipts (20 Free, 100 Premium, unlimited Pro)
//  - Invoices (0 Free, 25/month Premium, unlimited Pro)
//  - Accounts (1 Free, 5 Premium, unlimited Pro) - handled in AccountsView
//
//  CHANGES v2.0:
//  - ADDED: Debug count overrides for testing limit enforcement
//  - ADDED: debugSetCount(for:count:) to fake usage counts
//  - ADDED: debugClearAllOverrides() to reset to real counts
//  - ADDED: debugHasOverride(for:) to check if override is active
//  - ADDED: debugGetOverride(for:) to read current override value
//  - ADDED: Static convenience methods for DebugMenuView access
//  - Overrides stored in UserDefaults, persist across app launches
//  - All override code behind #if DEBUG - never ships to production
//  - When override is active, published count uses override instead of SwiftData
//
//  CHANGES v1.1:
//  - FIXED: Removed #Predicate macros that caused SwiftData compilation errors
//  - Uses simple FetchDescriptor + in-memory filtering instead
//
//  RESET LOGIC:
//  - Monthly limits (transactions, invoices) reset on the 1st of each month
//  - Total limits (receipts, accounts) do not reset
//

import Foundation
import SwiftData

// MARK: - Usage Limit Service

@MainActor
class UsageLimitService: ObservableObject {
    
    private let modelContext: ModelContext
    
    // MARK: - Published State
    
    @Published private(set) var currentMonthTransactionCount: Int = 0
    @Published private(set) var totalReceiptCount: Int = 0
    @Published private(set) var currentMonthInvoiceCount: Int = 0
    
    // MARK: - Debug Override Keys (DEBUG only)
    
    #if DEBUG
    private static let overrideKeyPrefix = "debug_usage_override_"
    private static let transactionOverrideKey = "\(overrideKeyPrefix)transactions"
    private static let receiptOverrideKey = "\(overrideKeyPrefix)receipts"
    private static let invoiceOverrideKey = "\(overrideKeyPrefix)invoices"
    #endif
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshCounts()
    }
    
    // MARK: - Refresh Counts
    
    /// Refresh all usage counts from the database (or debug overrides)
    func refreshCounts() {
        #if DEBUG
        // Use debug overrides if they exist, otherwise fetch real counts
        if let override = UserDefaults.standard.object(forKey: Self.transactionOverrideKey) as? Int {
            currentMonthTransactionCount = override
            print("[UsageLimitService] DEBUG: Using transaction override: \(override)")
        } else {
            currentMonthTransactionCount = fetchCurrentMonthTransactionCount()
        }
        
        if let override = UserDefaults.standard.object(forKey: Self.receiptOverrideKey) as? Int {
            totalReceiptCount = override
            print("[UsageLimitService] DEBUG: Using receipt override: \(override)")
        } else {
            totalReceiptCount = fetchTotalReceiptCount()
        }
        
        if let override = UserDefaults.standard.object(forKey: Self.invoiceOverrideKey) as? Int {
            currentMonthInvoiceCount = override
            print("[UsageLimitService] DEBUG: Using invoice override: \(override)")
        } else {
            currentMonthInvoiceCount = fetchCurrentMonthInvoiceCount()
        }
        #else
        // Production: always use real counts
        currentMonthTransactionCount = fetchCurrentMonthTransactionCount()
        totalReceiptCount = fetchTotalReceiptCount()
        currentMonthInvoiceCount = fetchCurrentMonthInvoiceCount()
        #endif
    }
    
    // MARK: - Debug Override Methods (DEBUG only)
    
    #if DEBUG
    /// Set a debug count override for a specific limit type
    /// When set, this count is used instead of the real SwiftData count
    func debugSetCount(for limitType: LimitType, count: Int) {
        let clampedCount = max(0, count)
        
        switch limitType {
        case .transactions:
            UserDefaults.standard.set(clampedCount, forKey: Self.transactionOverrideKey)
            currentMonthTransactionCount = clampedCount
            print("[UsageLimitService] DEBUG: Transaction override set to \(clampedCount)")
        case .receipts:
            UserDefaults.standard.set(clampedCount, forKey: Self.receiptOverrideKey)
            totalReceiptCount = clampedCount
            print("[UsageLimitService] DEBUG: Receipt override set to \(clampedCount)")
        case .invoices:
            UserDefaults.standard.set(clampedCount, forKey: Self.invoiceOverrideKey)
            currentMonthInvoiceCount = clampedCount
            print("[UsageLimitService] DEBUG: Invoice override set to \(clampedCount)")
        case .accounts, .clients, .linkedAccounts:
            // Accounts handled separately in AccountsView
            print("[UsageLimitService] DEBUG: \(limitType.displayName) overrides not supported here")
        }
    }
    
    /// Clear all debug count overrides and revert to real SwiftData counts
    func debugClearAllOverrides() {
        UserDefaults.standard.removeObject(forKey: Self.transactionOverrideKey)
        UserDefaults.standard.removeObject(forKey: Self.receiptOverrideKey)
        UserDefaults.standard.removeObject(forKey: Self.invoiceOverrideKey)
        
        // Refresh to get real counts
        currentMonthTransactionCount = fetchCurrentMonthTransactionCount()
        totalReceiptCount = fetchTotalReceiptCount()
        currentMonthInvoiceCount = fetchCurrentMonthInvoiceCount()
        
        print("[UsageLimitService] DEBUG: All overrides cleared, using real counts")
    }
    
    /// Clear a single override for a specific limit type
    func debugClearOverride(for limitType: LimitType) {
        switch limitType {
        case .transactions:
            UserDefaults.standard.removeObject(forKey: Self.transactionOverrideKey)
            currentMonthTransactionCount = fetchCurrentMonthTransactionCount()
        case .receipts:
            UserDefaults.standard.removeObject(forKey: Self.receiptOverrideKey)
            totalReceiptCount = fetchTotalReceiptCount()
        case .invoices:
            UserDefaults.standard.removeObject(forKey: Self.invoiceOverrideKey)
            currentMonthInvoiceCount = fetchCurrentMonthInvoiceCount()
        case .accounts, .clients, .linkedAccounts:
            break
        }
        print("[UsageLimitService] DEBUG: Override cleared for \(limitType.displayName)")
    }
    
    /// Check if a debug override is active for a limit type
    func debugHasOverride(for limitType: LimitType) -> Bool {
        switch limitType {
        case .transactions:
            return UserDefaults.standard.object(forKey: Self.transactionOverrideKey) != nil
        case .receipts:
            return UserDefaults.standard.object(forKey: Self.receiptOverrideKey) != nil
        case .invoices:
            return UserDefaults.standard.object(forKey: Self.invoiceOverrideKey) != nil
        default:
            return false
        }
    }
    
    /// Get the current override value (nil if no override)
    func debugGetOverride(for limitType: LimitType) -> Int? {
        switch limitType {
        case .transactions:
            return UserDefaults.standard.object(forKey: Self.transactionOverrideKey) as? Int
        case .receipts:
            return UserDefaults.standard.object(forKey: Self.receiptOverrideKey) as? Int
        case .invoices:
            return UserDefaults.standard.object(forKey: Self.invoiceOverrideKey) as? Int
        default:
            return nil
        }
    }
    
    /// Check if any override is active
    var debugHasAnyOverride: Bool {
        debugHasOverride(for: .transactions) ||
        debugHasOverride(for: .receipts) ||
        debugHasOverride(for: .invoices)
    }
    
    // MARK: - Static Debug Methods (for DebugMenuView without instance)
    
    /// Set override without needing a UsageLimitService instance
    static func debugSetOverrideStatic(for limitType: LimitType, count: Int) {
        let clampedCount = max(0, count)
        switch limitType {
        case .transactions:
            UserDefaults.standard.set(clampedCount, forKey: transactionOverrideKey)
        case .receipts:
            UserDefaults.standard.set(clampedCount, forKey: receiptOverrideKey)
        case .invoices:
            UserDefaults.standard.set(clampedCount, forKey: invoiceOverrideKey)
        default:
            break
        }
    }
    
    /// Get override without needing an instance
    static func debugGetOverrideStatic(for limitType: LimitType) -> Int? {
        switch limitType {
        case .transactions:
            return UserDefaults.standard.object(forKey: transactionOverrideKey) as? Int
        case .receipts:
            return UserDefaults.standard.object(forKey: receiptOverrideKey) as? Int
        case .invoices:
            return UserDefaults.standard.object(forKey: invoiceOverrideKey) as? Int
        default:
            return nil
        }
    }
    
    /// Clear all overrides without needing an instance
    static func debugClearAllOverridesStatic() {
        UserDefaults.standard.removeObject(forKey: transactionOverrideKey)
        UserDefaults.standard.removeObject(forKey: receiptOverrideKey)
        UserDefaults.standard.removeObject(forKey: invoiceOverrideKey)
    }
    
    /// Check if any override is active (static)
    static var debugHasAnyOverrideStatic: Bool {
        UserDefaults.standard.object(forKey: transactionOverrideKey) != nil ||
        UserDefaults.standard.object(forKey: receiptOverrideKey) != nil ||
        UserDefaults.standard.object(forKey: invoiceOverrideKey) != nil
    }
    #endif
    
    // MARK: - Current Month Date Range
    
    /// Get the start of the current month
    private var currentMonthStartDate: Date {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        return calendar.date(from: components) ?? now
    }
    
    /// Get the end of the current month (start of next month)
    private var currentMonthEndDate: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: 1, to: currentMonthStartDate) ?? Date()
    }
    
    // MARK: - Fetch Counts (No Predicates - In-Memory Filtering)
    
    /// Count transactions created this month
    private func fetchCurrentMonthTransactionCount() -> Int {
        let start = currentMonthStartDate
        let end = currentMonthEndDate
        
        let descriptor = FetchDescriptor<Transaction>()
        
        do {
            let all = try modelContext.fetch(descriptor)
            return all.filter { $0.createdAt >= start && $0.createdAt < end }.count
        } catch {
            print("[UsageLimitService] Error fetching transactions: \(error)")
            return 0
        }
    }
    
    /// Count total receipts (cumulative, not monthly)
    private func fetchTotalReceiptCount() -> Int {
        let descriptor = FetchDescriptor<ReceiptData>()
        
        do {
            return try modelContext.fetch(descriptor).count
        } catch {
            print("[UsageLimitService] Error fetching receipts: \(error)")
            return 0
        }
    }
    
    /// Count invoices created this month
    private func fetchCurrentMonthInvoiceCount() -> Int {
        let start = currentMonthStartDate
        let end = currentMonthEndDate
        
        let descriptor = FetchDescriptor<Invoice>()
        
        do {
            let all = try modelContext.fetch(descriptor)
            return all.filter { $0.issueDate >= start && $0.issueDate < end }.count
        } catch {
            print("[UsageLimitService] Error fetching invoices: \(error)")
            return 0
        }
    }
    
    // MARK: - Can Add Checks
    
    /// Check if user can add another transaction
    func canAddTransaction(tier: SubscriptionTier) -> (allowed: Bool, remaining: Int?) {
        guard let limit = tier.transactionLimit else {
            return (true, nil) // Unlimited
        }
        
        let remaining = max(0, limit - currentMonthTransactionCount)
        return (remaining > 0, remaining)
    }
    
    /// Check if user can add another receipt
    func canAddReceipt(tier: SubscriptionTier) -> (allowed: Bool, remaining: Int?) {
        guard let limit = tier.receiptStorageLimit else {
            return (true, nil) // Unlimited
        }
        
        let remaining = max(0, limit - totalReceiptCount)
        return (remaining > 0, remaining)
    }
    
    /// Check if user can add another invoice
    func canAddInvoice(tier: SubscriptionTier) -> (allowed: Bool, remaining: Int?) {
        guard let limit = tier.invoiceLimit else {
            return (true, nil) // Unlimited
        }
        
        // Free tier has 0 limit - no invoices allowed
        if limit == 0 {
            return (false, 0)
        }
        
        let remaining = max(0, limit - currentMonthInvoiceCount)
        return (remaining > 0, remaining)
    }
    
    // MARK: - Usage Warnings
    
    /// Get warning level for a specific limit type
    func getUsageWarning(for limitType: LimitType, tier: SubscriptionTier) -> UsageWarning? {
        let current: Int
        let limit: Int?
        
        switch limitType {
        case .transactions:
            current = currentMonthTransactionCount
            limit = tier.transactionLimit
        case .receipts:
            current = totalReceiptCount
            limit = tier.receiptStorageLimit
        case .invoices:
            current = currentMonthInvoiceCount
            limit = tier.invoiceLimit
        case .accounts, .clients, .linkedAccounts:
            return nil
        }
        
        guard let maxLimit = limit, maxLimit > 0 else {
            return nil
        }
        
        let percentage = Double(current) / Double(maxLimit)
        let remaining = max(0, maxLimit - current)
        
        if percentage >= 1.0 {
            return UsageWarning(
                level: .blocked,
                current: current,
                limit: maxLimit,
                remaining: 0,
                limitType: limitType
            )
        } else if percentage >= 0.9 {
            return UsageWarning(
                level: .critical,
                current: current,
                limit: maxLimit,
                remaining: remaining,
                limitType: limitType
            )
        } else if percentage >= 0.8 {
            return UsageWarning(
                level: .warning,
                current: current,
                limit: maxLimit,
                remaining: remaining,
                limitType: limitType
            )
        }
        
        return nil
    }
    
    // MARK: - Usage Stats
    
    func getUsageStats(tier: SubscriptionTier) -> UsageStats {
        UsageStats(
            transactionCount: currentMonthTransactionCount,
            transactionLimit: tier.transactionLimit,
            receiptCount: totalReceiptCount,
            receiptLimit: tier.receiptStorageLimit,
            invoiceCount: currentMonthInvoiceCount,
            invoiceLimit: tier.invoiceLimit
        )
    }
}

// MARK: - Usage Warning Model

struct UsageWarning {
    enum Level {
        case warning   // 80-89% used
        case critical  // 90-99% used
        case blocked   // 100% - cannot add more
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle"
            case .critical: return "exclamationmark.triangle.fill"
            case .blocked: return "xmark.circle.fill"
            }
        }
    }
    
    let level: Level
    let current: Int
    let limit: Int
    let remaining: Int
    let limitType: LimitType
    
    var message: String {
        let resourceName = limitType.displayName
        
        switch level {
        case .warning:
            return "You've used \(current) of \(limit) \(resourceName) this month"
        case .critical:
            return "Only \(remaining) \(resourceName) left this month!"
        case .blocked:
            return "\(resourceName.capitalized) limit reached"
        }
    }
    
    var upgradeMessage: String {
        "Upgrade for unlimited \(limitType.displayName)"
    }
}

// MARK: - Usage Stats Model

struct UsageStats {
    let transactionCount: Int
    let transactionLimit: Int?
    let receiptCount: Int
    let receiptLimit: Int?
    let invoiceCount: Int
    let invoiceLimit: Int?
    
    var transactionPercentage: Double? {
        guard let limit = transactionLimit, limit > 0 else { return nil }
        return Double(transactionCount) / Double(limit)
    }
    
    var receiptPercentage: Double? {
        guard let limit = receiptLimit, limit > 0 else { return nil }
        return Double(receiptCount) / Double(limit)
    }
    
    var invoicePercentage: Double? {
        guard let limit = invoiceLimit, limit > 0 else { return nil }
        return Double(invoiceCount) / Double(limit)
    }
}
