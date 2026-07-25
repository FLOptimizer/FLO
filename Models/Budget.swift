//  Budget.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5 - Wrap-Up Controls: Mark as Paid + Carryover Override
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Budget model with envelope, simple, zero-based, and percentage-based budgeting
//
//  CHANGES FROM v2.4:
//  ✅ Added isPaidOverride / paidOverrideDate for manual paid status control
//  ✅ Added allowCarryOverOverride for persistent per-budget carryover preference
//  ✅ Added monthlyCarryOverSkip for one-time wrap-up carryover override
//  ✅ Added effectiveShouldCarryOver computed property (respects overrides)
//  ✅ Added isPaid(spent:) method (auto-detect + manual override)
//
//  CHANGES FROM v2.3:
//  ✅ Added suggestedAmount property for ML-predicted budget amounts
//  ✅ Added isUserOverridden flag to track manual overrides of predictions
//
//  CHANGES FROM v2.2:
//  ✅ Added optional account relationship for account-specific budgets
//  ✅ Added accountName computed property
//  ✅ Added isAccountSpecific flag
//  ✅ Enhanced accessibility labels
//  ✅ Maintained all v2.2 functionality
//
//  CHANGES FROM v2.1:
//  - Fixed garbled UTF-8 characters
//


import Foundation
import SwiftData

/// A monthly budget that can belong to a specific category and support multiple budgeting methodologies
/// while distinguishing between personal and business finances.
@Model
final class Budget {
    
    // MARK: - Identifiers
    private(set) var id: UUID = UUID()
    
    // MARK: - Core Budget Data
    /// First day of the month this budget applies to – always normalized to midnight on the 1st.
    var month: Date = Date()
    
    /// Amount intentionally planned/allocated for this month.
    var planned: Double = 0.0
    
    /// Rollover amount from previous month (only meaningful for envelope budgeting).
    var carryOver: Double = 0.0
    
    /// The budgeting methodology used.
    var budgetType: BudgetType = BudgetType.envelope
    
    /// Personal vs Business classification – affects UI, reporting, and tax logic.
    var financeType: Transaction.FinanceType = Transaction.FinanceType.personal
    
    // MARK: - Relationships (All inverses required for CloudKit)
    // NOTE: Category defines the inverse for category relationship

    /// Optional category this budget belongs to. Nil = overall/unallocated budget.
    @Relationship(deleteRule: .nullify)
    var category: Category?

    /// Optional account this budget is specific to (NEW in v2.3 - Premium feature)
    /// Nil = budget applies across all accounts of matching financeType
    @Relationship(deleteRule: .nullify)
    var account: Account?

    /// Optional business profile for per-business budget tracking (NEW in v4.1)
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    /// Transactions assigned to this budget (inverse of Transaction.budget)
    @Relationship(deleteRule: .nullify, inverse: \Transaction.budget)
    var transactions: [Transaction]?
    
    // MARK: - Prediction Properties (NEW in v2.4)

    /// ML-predicted suggested amount for this budget (nil if no prediction available)
    var suggestedAmount: Double?

    /// Whether the user manually overrode the ML-suggested amount
    var isUserOverridden: Bool = false

    // MARK: - Paid Status (NEW in v2.5)

    /// Manual override for paid status (nil = auto-detect from transactions, true/false = manual)
    var isPaidOverride: Bool?

    /// When the user manually marked this budget as paid
    var paidOverrideDate: Date?

    // MARK: - Carryover Control (NEW in v2.5)

    /// Persistent per-budget carryover preference (nil = use budgetType default)
    var allowCarryOverOverride: Bool?

    /// One-time wrap-up override for this specific month (nil = use persistent setting)
    var monthlyCarryOverSkip: Bool?

    // MARK: - Need/Want/Savings Classification (NEW in v2.6)

    /// Raw backing for the 50/30/20 purpose classification. Nil = unclassified,
    /// which keeps existing synced budgets valid (additive CloudKit change).
    var purposeRaw: String?

    /// For savings-classified budgets: the Category ID of the envelope this
    /// budget contributes to. Category-based (not Budget-based) so the link
    /// stays stable across monthly budget instances.
    var savingsEnvelopeCategoryID: UUID?

    // MARK: - Metadata

    /// When budget was created
    var createdAt: Date = Date()

    /// When budget was last modified
    var updatedAt: Date = Date()
    
    // MARK: - Initialization
    
    init(
        month: Date,
        planned: Double,
        carryOver: Double = 0.0,
        category: Category? = nil,
        account: Account? = nil,
        businessProfile: BusinessProfile? = nil,
        budgetType: BudgetType = .envelope,
        financeType: Transaction.FinanceType = .personal,
        purpose: BudgetPurpose? = nil,
        savingsEnvelopeCategoryID: UUID? = nil
    ) {
        self.id = UUID()
        self.month = {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: month)
            return calendar.date(from: components) ?? month
        }()
        self.planned = max(planned, 0)           // Defensive: never allow negative planned amount
        self.carryOver = carryOver
        self.category = category
        self.account = account
        self.businessProfile = businessProfile
        self.budgetType = budgetType
        self.financeType = financeType
        self.purposeRaw = purpose?.rawValue
        self.savingsEnvelopeCategoryID = savingsEnvelopeCategoryID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Total amount currently available to spend/allocation based on budget type.
    var totalAvailable: Double {
        switch budgetType {
        case .envelope:
            return planned + carryOver
        default:
            return planned
        }
    }
    
    /// Whether remaining funds should roll over to the next month (respects persistent override).
    var shouldCarryOver: Bool {
        allowCarryOverOverride ?? (budgetType == .envelope)
    }

    /// Final carryover decision factoring in one-time wrap-up skip.
    /// Use this when deciding whether to actually carry over at month boundary.
    var effectiveShouldCarryOver: Bool {
        if let skip = monthlyCarryOverSkip {
            return !skip
        }
        return shouldCarryOver
    }
    
    /// Primary display name shown throughout the app.
    var displayName: String {
        category?.name ?? budgetType.displayName
    }
    
    /// Convenience flag – very common in SwiftUI views.
    var isEnvelope: Bool {
        budgetType == .envelope
    }

    /// Typed accessor for the 50/30/20 purpose classification (v2.6).
    var purpose: BudgetPurpose? {
        get {
            guard let raw = purposeRaw else { return nil }
            return BudgetPurpose(rawValue: raw)
        }
        set { purposeRaw = newValue?.rawValue }
    }
    
    // MARK: - Account Properties (NEW in v2.3)
    
    /// Whether this budget is specific to an account
    var isAccountSpecific: Bool {
        account != nil
    }
    
    /// Account name for display (or "All Accounts" if not account-specific)
    var accountName: String {
        account?.name ?? "All Accounts"
    }
    
    /// Account display with identifier
    var accountDisplayName: String {
        account?.displayNameWithDigits ?? "All Accounts"
    }
    
    /// Account icon (or default)
    var accountIcon: String {
        account?.icon ?? "building.columns"
    }
    
    /// Full display name including account if specific
    var fullDisplayName: String {
        if let accountName = account?.name {
            return "\(displayName) (\(accountName))"
        }
        return displayName
    }
    
    // MARK: - Month Helpers
    
    /// Month and year formatted for display
    var monthYearDisplay: String {
        DateFormatter.monthYear.string(from: month)
    }

    /// Short month display
    var shortMonthDisplay: String {
        DateFormatter.shortMonthYear.string(from: month)
    }

    /// Month key for grouping (YYYY-MM format)
    var monthKey: String {
        DateFormatter.yearMonth.string(from: month)
    }
    
    /// Year of this budget
    var year: Int {
        Calendar.current.component(.year, from: month)
    }
    
    /// Month number (1-12)
    var monthNumber: Int {
        Calendar.current.component(.month, from: month)
    }
    
    // MARK: - Accessibility
    
    /// Full accessibility label for VoiceOver and Dynamic Type.
    var accessibilityLabel: String {
        let monthYear = DateFormatter.monthYear.string(from: month)
        
        let currency = planned.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        
        var label = "\(financeType.rawValue.capitalized) \(budgetType.displayName) for \(displayName) in \(monthYear): \(currency) planned"
        
        if isAccountSpecific {
            label += ", for \(accountName)"
        }
        
        return label
    }
    
    // MARK: - Legacy Compatibility
    
    @available(*, deprecated, message: "Use totalAvailable instead")
    func availableAmount() -> Double { totalAvailable }
    
    // MARK: - Helper Methods
    
    /// Normalize date to first day of month at midnight.
    private func normalizeToStartOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Update the budget
    func update(planned: Double? = nil, carryOver: Double? = nil) {
        if let planned = planned {
            self.planned = max(planned, 0)
        }
        if let carryOver = carryOver {
            self.carryOver = carryOver
        }
        self.updatedAt = Date()
    }
    
    /// Touch to update timestamp
    func touch() {
        updatedAt = Date()
    }
    
    /// Assign to an account
    func assignToAccount(_ newAccount: Account?) {
        account = newAccount
        touch()
    }
    
    /// Whether this budget is considered "paid" for the month.
    /// Checks manual override first, then auto-detects from spent amount.
    func isPaid(spent: Double) -> Bool {
        if let override = isPaidOverride {
            return override
        }
        return spent >= planned && planned > 0
    }

    /// Manually mark this budget as paid or unpaid. Pass nil to reset to auto-detect.
    func setPaidOverride(_ paid: Bool?) {
        isPaidOverride = paid
        paidOverrideDate = paid != nil ? Date() : nil
        touch()
    }

    /// Calculate remaining amount based on spent
    func remaining(spent: Double) -> Double {
        totalAvailable - spent
    }
    
    /// Calculate percentage used
    func percentageUsed(spent: Double) -> Double {
        guard totalAvailable > 0 else { return 0 }
        return min((spent / totalAvailable) * 100, 100)
    }
    
    /// Whether budget is over limit
    func isOverBudget(spent: Double) -> Bool {
        spent > totalAvailable
    }
    
    /// Whether budget is near limit (>80%)
    func isNearLimit(spent: Double) -> Bool {
        percentageUsed(spent: spent) >= 80
    }
}

// MARK: - Protocol Conformances

extension Budget: Identifiable { }

extension Budget: Equatable {
    static func == (lhs: Budget, rhs: Budget) -> Bool {
        lhs.id == rhs.id
    }
}

extension Budget: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Budget Type Definition

enum BudgetType: String, Codable, CaseIterable {
    case envelope   = "envelope"
    case simple     = "simple"
    case zeroBase   = "zeroBase"
    case percentage = "percentage"
    
    var displayName: String {
        switch self {
        case .envelope:     return "Envelope Budgeting"
        case .simple:       return "Simple Budget"
        case .zeroBase:     return "Zero-Based Budget"
        case .percentage:   return "50/30/20 Rule"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .envelope:     return "Rollover unused funds"
        case .simple:       return "Track vs. limit"
        case .zeroBase:     return "Every dollar assigned"
        case .percentage:   return "Percentage split"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .envelope:     return "envelope.fill"
        case .simple:       return "chart.bar.fill"
        case .zeroBase:     return "dollarsign.circle.fill"
        case .percentage:   return "chart.pie.fill"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .envelope:
            return "Allocate money to categories like physical envelopes. Unused funds roll over to the next month."
        case .simple:
            return "Set a spending limit and track against it. Clean slate each month."
        case .zeroBase:
            return "Assign every dollar a job. Income minus all allocations should equal zero."
        case .percentage:
            return "50% needs, 30% wants, 20% savings. Classic budgeting rule."
        }
    }
}

// MARK: - Budget Purpose (v2.6)

/// 50/30/20 classification for a budget: is this spending a need, a want,
/// or savings? Powers the color-coded 50/30/20 bar on the budget list.
enum BudgetPurpose: String, Codable, CaseIterable, Identifiable {
    case need    = "need"
    case want    = "want"
    case savings = "savings"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .need:    return "Need"
        case .want:    return "Want"
        case .savings: return "Savings"
        }
    }

    var systemImageName: String {
        switch self {
        case .need:    return "house.fill"
        case .want:    return "sparkles"
        case .savings: return "banknote.fill"
        }
    }

    /// Target share of monthly income under the 50/30/20 rule.
    var targetShare: Double {
        switch self {
        case .need:    return 0.50
        case .want:    return 0.30
        case .savings: return 0.20
        }
    }

    /// Whether exceeding the target is desirable (true only for savings —
    /// saving more than 20% is good; spending more than 50/30 is not).
    var higherIsBetter: Bool {
        self == .savings
    }

    var footerDescription: String {
        switch self {
        case .need:    return "Essentials: housing, groceries, utilities, insurance, minimum debt payments."
        case .want:    return "Nice-to-haves: dining out, entertainment, hobbies, subscriptions."
        case .savings: return "Money set aside: emergency fund, investments, extra debt payments."
        }
    }
}

// MARK: - Filtering Extensions

extension Budget {
    /// Filter predicate for account-based queries
    static func accountPredicate(accountId: UUID) -> Predicate<Budget> {
        #Predicate<Budget> { budget in
            budget.account?.id == accountId
        }
    }
    
    /// Filter predicate for finance type
    static func financeTypePredicate(_ type: Transaction.FinanceType) -> Predicate<Budget> {
        #Predicate<Budget> { budget in
            budget.financeType == type
        }
    }
    
    /// Filter predicate for month
    static func monthPredicate(_ month: Date) -> Predicate<Budget> {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: month)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return #Predicate<Budget> { _ in false }
        }
        
        return #Predicate<Budget> { budget in
            budget.month >= startOfMonth && budget.month < endOfMonth
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension Budget {
    @MainActor static var previewEnvelopePersonal: Budget {
        Budget(
            month: .now,
            planned: 1_250.0,
            carryOver: 187.43,
            budgetType: .envelope,
            financeType: .personal
        )
    }
    
    @MainActor static var previewSimpleBusiness: Budget {
        Budget(
            month: .now,
            planned: 8_500.0,
            budgetType: .simple,
            financeType: .business
        )
    }
    
    @MainActor static var previewZeroBased: Budget {
        Budget(
            month: Date.now.addingTimeInterval(-2_592_000), // ~1 month ago
            planned: 4_200.0,
            budgetType: .zeroBase,
            financeType: .personal
        )
    }
    
    @MainActor static var previewPercentage: Budget {
        Budget(
            month: .now,
            planned: 6_000.0,
            budgetType: .percentage,
            financeType: .personal
        )
    }
    
    @MainActor static var previewAccountSpecific: Budget {
        let budget = Budget(
            month: .now,
            planned: 3_000.0,
            budgetType: .envelope,
            financeType: .business
        )
        // Note: Would assign account in actual usage
        return budget
    }
}
#endif
