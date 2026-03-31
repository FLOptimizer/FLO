//  WatchModels.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Added Comparable conformance to WatchSubscriptionTier
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLO (main app) — WatchConnectivityService builds these
//  ✅ FLOWatch (watchOS app) — views display these
//  ✅ FLOWatchComplications (watchOS widget) — complications read these
//
//  DESIGN NOTES:
//  These are lightweight Codable DTOs, NOT SwiftData @Model classes.
//  The iPhone app converts SwiftData models → WatchDTO and sends via
//  WatchConnectivity. The Watch never touches SwiftData directly.
//
//  DATA FLOW:
//  iPhone SwiftData → WatchSnapshot → WatchConnectivity → Watch Views
//  Watch QuickExpense → WatchCommand → WatchConnectivity → iPhone SwiftData
//

import Foundation

// MARK: - Watch Snapshot (iPhone → Watch)

/// Complete data package the iPhone pushes to the Watch.
/// Sent via updateApplicationContext() on every meaningful data change.
/// The Watch reads this to populate all views and complications.
struct WatchSnapshot: Codable {
    
    /// When this snapshot was generated
    let generatedAt: Date
    
    /// User's current subscription tier (raw value of SubscriptionTier enum)
    let subscriptionTierRaw: Int
    
    /// Today's spending summary
    let todaySummary: WatchDaySummary
    
    /// Recent transactions (last 10, newest first)
    let recentTransactions: [WatchTransaction]
    
    /// Current tax estimate (nil if free tier)
    let taxEstimate: WatchTaxEstimate?
    
    /// Active mileage trip status (nil if no active trip)
    let activeMileageTrip: WatchMileageStatus?
    
    /// User's top categories for quick expense entry (max 6)
    let quickCategories: [WatchCategory]
    
    /// Complication-specific data (pre-formatted for efficiency)
    let complicationData: WatchComplicationData
    
    // MARK: - Subscription Helpers
    
    /// Decoded subscription tier
    var subscriptionTier: WatchSubscriptionTier {
        WatchSubscriptionTier(rawValue: subscriptionTierRaw) ?? .free
    }
}

// MARK: - Day Summary

/// Today's financial summary for the Watch home screen
struct WatchDaySummary: Codable {
    /// Total spent today
    let todaySpending: Double
    
    /// Total income today
    let todayIncome: Double
    
    /// Net for today (income - spending)
    var todayNet: Double { todayIncome - todaySpending }
    
    /// This week's total spending
    let weekSpending: Double
    
    /// This month's total spending
    let monthSpending: Double
    
    /// This month's total income
    let monthIncome: Double
    
    /// Number of transactions today
    let todayTransactionCount: Int
}

// MARK: - Watch Transaction DTO

/// Lightweight transaction for Watch display (read-only list)
struct WatchTransaction: Codable, Identifiable {
    let id: UUID
    let amount: Double
    let merchantName: String
    let categoryName: String
    let categoryIcon: String
    let isIncome: Bool
    let isBusiness: Bool
    let date: Date
    
    /// Formatted amount string (pre-formatted on iPhone for Watch efficiency)
    let formattedAmount: String
}

// MARK: - Watch Category DTO

/// Category for the quick expense picker on Watch
struct WatchCategory: Codable, Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let isBusiness: Bool
    
    /// How many times this category was used recently (for sorting)
    let usageCount: Int
}

// MARK: - Tax Estimate DTO

/// Quarterly tax estimate for Watch display
struct WatchTaxEstimate: Codable {
    /// Estimated quarterly payment amount
    let quarterlyPayment: Double
    
    /// Adjusted payment after W-2 withholding credits
    let adjustedQuarterlyPayment: Double
    
    /// Next quarterly deadline date
    let nextDeadline: Date?
    
    /// Days until next deadline (pre-calculated)
    let daysUntilDeadline: Int?
    
    /// Year-to-date self-employment income
    let ytdIncome: Double
    
    /// Year-to-date deductions
    let ytdDeductions: Double
    
    /// Effective tax rate as decimal (e.g., 0.285 = 28.5%)
    let effectiveTaxRate: Double
    
    /// Formatted quarterly payment (pre-formatted)
    let formattedQuarterlyPayment: String
}

// MARK: - Mileage Status DTO

/// Active mileage trip status for Watch control
struct WatchMileageStatus: Codable {
    /// Trip identifier
    let tripId: UUID
    
    /// Current distance in miles
    let distanceMiles: Double
    
    /// Elapsed time in seconds
    let elapsedSeconds: TimeInterval
    
    /// Estimated tax deduction at IRS rate
    let estimatedDeduction: Double
    
    /// Whether tracking is currently paused
    let isPaused: Bool
    
    /// GPS signal quality: "strong", "weak", "searching"
    let gpsSignal: String
    
    /// Trip start time
    let startTime: Date
    
    /// Starting address (geocoded)
    let startAddress: String
}

// MARK: - Complication Data

/// Pre-formatted data optimized for Watch face complications
struct WatchComplicationData: Codable {
    /// Today's total spending formatted (e.g., "$142.50")
    let todaySpendingFormatted: String
    
    /// Today's spending raw value
    let todaySpendingRaw: Double
    
    /// Tax deadline short text (e.g., "14d" or "Q1 Due")
    let taxDeadlineShort: String
    
    /// Tax payment formatted (e.g., "$2,340")
    let taxPaymentFormatted: String
    
    /// Tax payment raw value
    let taxPaymentRaw: Double
    
    /// Days until tax deadline (nil if no deadline)
    let daysUntilTaxDeadline: Int?
    
    /// Whether mileage is actively tracking
    let isMileageActive: Bool
    
    /// Current trip miles formatted (e.g., "12.4 mi")
    let currentTripMilesFormatted: String
    
    /// Today's total miles
    let todayTotalMiles: Double
    
    /// Monthly spending trend: "up", "down", "flat"
    let spendingTrend: String
    
    /// Percentage change from last period
    let spendingTrendPercent: Double
}

// MARK: - Watch Commands (Watch → iPhone)

/// Commands the Watch sends to the iPhone for execution.
/// Sent via sendMessage() for immediate actions or transferUserInfo() for queued actions.
enum WatchCommand: Codable {
    
    /// Add a new expense transaction
    case addExpense(AddExpensePayload)
    
    /// Add a new income transaction
    case addIncome(AddIncomePayload)
    
    /// Start mileage tracking
    case startMileage
    
    /// Pause mileage tracking
    case pauseMileage
    
    /// Resume mileage tracking
    case resumeMileage
    
    /// End mileage tracking
    case endMileage
    
    /// Request a fresh snapshot
    case requestSnapshot
    
    // MARK: - Payloads
    
    struct AddExpensePayload: Codable {
        let amount: Double
        let categoryId: UUID
        let isBusiness: Bool
        let note: String?
        let date: Date
    }
    
    struct AddIncomePayload: Codable {
        let amount: Double
        let categoryId: UUID
        let isBusiness: Bool
        let note: String?
        let date: Date
    }
}

// MARK: - Watch Subscription Tier

/// Lightweight mirror of SubscriptionTier for Watch-side feature gating.
/// Raw values match SubscriptionTier.rawValue on iPhone.
enum WatchSubscriptionTier: Int, Codable, Comparable {
    case free = 0
    case premium = 1
    case pro = 2
    
    static func < (lhs: WatchSubscriptionTier, rhs: WatchSubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Watch app available to all tiers
    var hasWatchApp: Bool { true }
    
    /// Quick expense entry — all tiers
    var hasQuickExpense: Bool { true }
    
    /// View recent transactions — all tiers
    var hasRecentTransactions: Bool { true }
    
    /// Today's summary — all tiers
    var hasTodaySummary: Bool { true }
    
    /// Tax estimate view — Premium+
    var hasTaxEstimate: Bool { self >= .premium }
    
    /// Mileage control (start/stop/pause) — Premium+
    var hasMileageControl: Bool { self >= .premium }
    
    /// Watch face complications — all tiers (spending only for free)
    var hasComplications: Bool { true }
    
    /// Tax deadline complication — Premium+
    var hasTaxComplication: Bool { self >= .premium }
    
    /// Mileage complication — Premium+
    var hasMileageComplication: Bool { self >= .premium }
    
    /// Display name for upgrade prompts
    var upgradeTargetName: String {
        switch self {
        case .free:    return "Premium"
        case .premium: return "Pro"
        case .pro:     return ""
        }
    }
}

// MARK: - WatchConnectivity Message Keys

/// String keys used in WatchConnectivity dictionaries.
/// Both iPhone and Watch reference these to encode/decode messages.
enum WatchMessageKey {
    /// Key for the snapshot data (Data, JSON-encoded WatchSnapshot)
    static let snapshot = "com.flo.watch.snapshot"
    
    /// Key for command data (Data, JSON-encoded WatchCommand)
    static let command = "com.flo.watch.command"
    
    /// Key for command acknowledgment (Bool)
    static let commandAck = "com.flo.watch.ack"
    
    /// Key for error message (String)
    static let errorMessage = "com.flo.watch.error"
    
    /// Key for complication update data (Data, JSON-encoded WatchComplicationData)
    static let complicationUpdate = "com.flo.watch.complication"
}

// MARK: - Codable Helpers

extension WatchSnapshot {
    
    /// Encode snapshot to JSON Data for WatchConnectivity transfer
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    /// Decode snapshot from JSON Data received via WatchConnectivity
    static func decoded(from data: Data) throws -> WatchSnapshot {
        try JSONDecoder().decode(WatchSnapshot.self, from: data)
    }
}

extension WatchCommand {
    
    /// Encode command to JSON Data for WatchConnectivity transfer
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
    
    /// Decode command from JSON Data received via WatchConnectivity
    static func decoded(from data: Data) throws -> WatchCommand {
        try JSONDecoder().decode(WatchCommand.self, from: data)
    }
}
