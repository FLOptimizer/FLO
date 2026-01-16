//  RecurringTransaction.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.6 - Added Account relationship for recurring transactions
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.5:
//  ✅ ADDED: Account relationship - recurring transactions tied to specific accounts
//  ✅ ADDED: Account passed to generated transaction instances
//  ✅ ADDED: accountName computed property
//  ✅ Maintained all v2.5 functionality
//
//  Previous (v2.5):
//  - Fixed month skipping bug (Feb, Apr, Jun when starting on day 31)
//  - Correctly uses last day of month when intended day doesn't exist

import Foundation
import SwiftData

/// A recurring transaction template that automatically generates transaction instances on schedule.
@Model
final class RecurringTransaction {
    
    // MARK: - Identifiers
    @Attribute(.unique) private(set) var id: UUID
    
    // MARK: - Core Transaction Data
    
    /// Amount for each generated transaction instance.
    var amount: Double
    
    /// Merchant or payee name (optional for migration compatibility)
    var merchantName: String
    
    /// Description/note for the recurring transaction.
    var note: String
    
    /// Whether this generates income or expense transactions.
    var isIncome: Bool
    
    /// Business or Personal classification
    var financeType: Transaction.FinanceType
    
    /// How frequently instances should be created.
    var frequency: RecurrenceFrequency
    
    // MARK: - Schedule
    
    /// First date this recurrence becomes active.
    var startDate: Date
    
    /// Optional end date - if set, no instances created after this date.
    var endDate: Date?
    
    /// Date when the last instance was created - used to calculate next due date.
    var lastCreated: Date?
    
    /// Whether this recurrence is currently active.
    var isActive: Bool
    
    // MARK: - Relationships
    
    /// Optional category for generated transactions.
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    /// Optional account for generated transactions (NEW in v2.6 - Premium feature)
    @Relationship(deleteRule: .nullify)
    var account: Account?
    
    /// All transaction instances created from this recurring template.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.recurringParent)
    var transactions: [Transaction] = []
    
    // MARK: - Initialization
    
    init(
        amount: Double,
        merchantName: String = "",
        note: String = "",
        isIncome: Bool = false,
        financeType: Transaction.FinanceType = .personal,
        frequency: RecurrenceFrequency,
        startDate: Date = .now,
        endDate: Date? = nil,
        category: Category? = nil,
        account: Account? = nil,  // NEW in v2.6
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.amount = amount
        self.merchantName = merchantName
        self.note = note.isEmpty ? merchantName : note
        self.isIncome = isIncome
        self.financeType = financeType
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.lastCreated = nil
        self.isActive = isActive
        self.category = category
        self.account = account
    }
    
    // MARK: - Computed Properties
    
    /// Display name combines merchantName and note intelligently
    var displayName: String {
        if merchantName.isEmpty {
            return note.isEmpty ? "Recurring Transaction" : note
        }
        return merchantName
    }
    
    /// Account name for display (NEW in v2.6)
    var accountName: String {
        account?.name ?? "No Account"
    }
    
    /// Whether this recurring transaction has an assigned account (NEW in v2.6)
    var hasAccount: Bool {
        account != nil
    }
    
    /// The next date when an instance should be created.
    /// ✅ FIXED in v2.5: Properly handles all months including those without the intended day
    var nextOccurrence: Date? {
        guard isActive else { return nil }
        
        // If never created, use start date
        guard let last = lastCreated else { return startDate }
        
        let calendar = Calendar.current
        
        // Get the intended day from start date
        let intendedDay = calendar.component(.day, from: startDate)
        
        // Calculate base next occurrence using frequency
        guard let baseNext = frequency.nextDate(from: last, calendar: calendar) else {
            return nil
        }
        
        // For non-monthly frequencies, use the base calculation
        if frequency != .monthly && frequency != .quarterly && frequency != .yearly {
            if let end = endDate, baseNext > end {
                return nil
            }
            return baseNext
        }
        
        // For monthly/quarterly/yearly: try to preserve the intended day
        var components = calendar.dateComponents([.year, .month], from: baseNext)
        components.day = intendedDay
        
        // Try to create date with intended day
        if let targetDate = calendar.date(from: components) {
            // Verify the day is correct (handles invalid dates like Feb 31)
            let actualDay = calendar.component(.day, from: targetDate)
            
            if actualDay == intendedDay {
                // Perfect! Got our intended day
                if let end = endDate, targetDate > end {
                    return nil
                }
                return targetDate
            }
        }
        
        // Intended day doesn't exist in this month (e.g., Feb 31, Apr 31, Jun 31)
        // Use the LAST day of the target month
        components.day = 1 // Start with first day of month
        if let firstOfMonth = calendar.date(from: components),
           let range = calendar.range(of: .day, in: .month, for: firstOfMonth) {
            
            // Set to last day of month
            components.day = range.count
            if let lastDayOfMonth = calendar.date(from: components) {
                if let end = endDate, lastDayOfMonth > end {
                    return nil
                }
                return lastDayOfMonth
            }
        }
        
        // Fallback to base calculation if something went wrong
        if let end = endDate, baseNext > end {
            return nil
        }
        return baseNext
    }
    
    /// User-friendly display of recurrence schedule.
    var displaySchedule: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let start = formatter.string(from: startDate)
        if let end = endDate {
            let endStr = formatter.string(from: end)
            return "\(frequency.displayName) from \(start) to \(endStr)"
        } else {
            return "\(frequency.displayName) starting \(start)"
        }
    }
    
    /// Number of instances created so far.
    var instanceCount: Int {
        transactions.count
    }
    
    /// Total amount generated by all instances.
    var totalGenerated: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    /// Whether this recurrence is overdue (active, past due date, and not ended).
    var isOverdue: Bool {
        guard isActive else { return false }
        guard let next = nextOccurrence else { return false }
        return next < .now
    }
    
    // MARK: - Instance Creation Logic
    
    /// Check if a new transaction instance should be created today.
    func shouldCreateInstance(today: Date = .now) -> Bool {
        guard isActive else { return false }
        if let end = endDate, today > end { return false }
        guard today >= startDate else { return false }
        
        guard let next = nextOccurrence else { return false }
        return today >= next
    }
    
    /// Create the next transaction instance if due.
    /// v2.6: Now includes account in generated transaction
    @discardableResult
    func createNextInstance(in context: ModelContext, on date: Date = .now) -> Transaction? {
        guard shouldCreateInstance(today: date) else { return nil }
        
        // Prevent duplicates on same day
        let calendar = Calendar.current
        if let last = lastCreated, calendar.isDate(last, inSameDayAs: date) {
            return nil
        }
        
        // Use correct signed amount (negative for expenses)
        let transactionAmount = isIncome ? amount : -amount
        
        let transaction = Transaction(
            amount: transactionAmount,
            date: date,
            note: note.isEmpty ? merchantName : note,
            isIncome: isIncome,
            merchantName: merchantName,
            category: category,
            financeType: financeType,
            account: account  // NEW in v2.6: Pass account to generated transaction
        )
        
        transaction.recurringParent = self
        transactions.append(transaction)
        context.insert(transaction)
        lastCreated = date
        
        return transaction
    }
    
    /// Deactivate this recurring transaction.
    func deactivate() {
        isActive = false
    }
    
    /// Reactivate this recurring transaction.
    func activate() {
        isActive = true
    }
    
    /// Update the account for this recurring transaction (NEW in v2.6)
    func assignToAccount(_ newAccount: Account?) {
        account = newAccount
    }
}

// MARK: - Protocol Conformances

extension RecurringTransaction: Identifiable {}

extension RecurringTransaction: Equatable {
    static func == (lhs: RecurringTransaction, rhs: RecurringTransaction) -> Bool {
        lhs.id == rhs.id
    }
}

extension RecurringTransaction: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Recurrence Frequency

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .weekly:     return "Weekly"
        case .biweekly:   return "Bi-weekly"
        case .monthly:    return "Monthly"
        case .quarterly:  return "Quarterly"
        case .yearly:     return "Yearly"
        }
    }
    
    /// Calculate the next occurrence date using proper calendar math
    /// - Parameters:
    ///   - date: The date to calculate from
    ///   - calendar: Calendar to use (defaults to current)
    /// - Returns: Next occurrence date, or nil if calculation fails
    func nextDate(from date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }
    
    /// ⚠️ DEPRECATED: Use nextDate(from:) instead for accurate calendar calculations
    @available(*, deprecated, message: "Use nextDate(from:) for accurate calendar-based calculations")
    var daysInterval: Int {
        switch self {
        case .weekly:     return 7
        case .biweekly:   return 14
        case .monthly:    return 30    // Inaccurate
        case .quarterly:  return 90    // Inaccurate
        case .yearly:     return 365   // Inaccurate
        }
    }
    
    var systemImageName: String {
        switch self {
        case .weekly:     return "calendar"
        case .biweekly:   return "calendar.badge.clock"
        case .monthly:    return "calendar.circle"
        case .quarterly:  return "calendar.badge.plus"
        case .yearly:     return "calendar.badge.exclamationmark"
        }
    }
    
    var icon: String { systemImageName }
}

// MARK: - Preview Support

#if DEBUG
extension RecurringTransaction {
    @MainActor static var previewNetflix: RecurringTransaction {
        RecurringTransaction(
            amount: 15.99,
            merchantName: "Netflix",
            note: "Streaming Subscription",
            isIncome: false,
            financeType: .personal,
            frequency: .monthly,
            startDate: Date.now.addingTimeInterval(-86400 * 30),
            isActive: true
        )
    }
    
    @MainActor static var previewSalary: RecurringTransaction {
        RecurringTransaction(
            amount: 5000.00,
            merchantName: "Employer",
            note: "Bi-weekly Salary",
            isIncome: true,
            financeType: .business,
            frequency: .biweekly,
            startDate: Date.now.addingTimeInterval(-86400 * 14),
            isActive: true
        )
    }
    
    @MainActor static var previewRent: RecurringTransaction {
        RecurringTransaction(
            amount: 1500.00,
            merchantName: "Landlord",
            note: "Rent Payment",
            isIncome: false,
            financeType: .personal,
            frequency: .monthly,
            startDate: Date.now,
            isActive: true
        )
    }
}
#endif
