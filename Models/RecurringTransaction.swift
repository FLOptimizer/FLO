//  RecurringTransaction.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.11 - Not Paid Yet Override
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.11:
//  ✅ ADDED: notSentMonth property — override to mark auto-created transaction as "not paid yet"
//  ✅ ADDED: markAsNotSent(for:in:) — deletes premature auto-transaction + adjusts balance
//  ✅ UPDATED: isSentForMonth respects notSentMonth override
//
//  CHANGES v2.10:
//  ✅ ADDED: isSentForMonth(_:) — checks BOTH payment logs AND auto-created transactions
//  ✅ ADDED: transactionForMonth(_:) — retrieves auto-created transaction for a month
//  ✅ FIX: Auto-engine transactions now auto-detect as "sent" so user won't duplicate
//
//  CHANGES v2.9:
//  ✅ ADDED: paymentLogs relationship for tracking actual payment dates/amounts
//  ✅ ADDED: suggestedDayOfMonth computed property based on payment history
//  ✅ ADDED: hasPaymentForMonth(_:) helper to check if already marked sent
//  ✅ ADDED: markAsSent(for:amount:date:context:) method to create log + transaction
//
//  CHANGES v2.8:
//  - CRITICAL FIX: Account balance now updates when recurring instances are created
//  - Income instances increase account balance
//  - Expense instances decrease account balance
//  - account.lastBalanceUpdate and account.touch() called properly
//  - This fixes the discrepancy between summaries and account balances
//
//  CHANGES v2.7:
//  - FIXED: Recurring expenses were stored with negative amounts
//  - Transaction amounts are now always positive (per Transaction model spec)
//  - The isIncome flag determines direction, not the amount sign
//  - This fixes Net Income showing green for expenses on dashboard
//
//  CHANGES v2.6:
//  - Added Account relationship - recurring transactions tied to specific accounts
//  - Account passed to generated transaction instances
//  - Added accountName computed property
//
//  CHANGES v2.5:
//  - Fixed month skipping bug (Feb, Apr, Jun when starting on day 31)
//  - Correctly uses last day of month when intended day doesn't exist

import Foundation
import SwiftData

/// A recurring transaction template that automatically generates transaction instances on schedule.
@Model
final class RecurringTransaction {
    
    // MARK: - Identifiers
    private(set) var id: UUID = UUID()

    // MARK: - Core Transaction Data

    /// Amount for each generated transaction instance.
    var amount: Double = 0.0

    /// Merchant or payee name (optional for migration compatibility)
    var merchantName: String = ""

    /// Description/note for the recurring transaction.
    var note: String = ""

    /// Whether this generates income or expense transactions.
    var isIncome: Bool = false

    /// Business or Personal classification
    var financeType: Transaction.FinanceType = Transaction.FinanceType.personal

    /// How frequently instances should be created.
    var frequency: RecurrenceFrequency = RecurrenceFrequency.monthly

    // MARK: - Schedule

    /// First date this recurrence becomes active.
    var startDate: Date = Date()

    /// Optional end date - if set, no instances created after this date.
    var endDate: Date?

    /// Date when the last instance was created - used to calculate next due date.
    var lastCreated: Date?

    /// Whether this recurrence is currently active.
    var isActive: Bool = true

    /// When set, overrides auto-detection for this month — treats it as "not paid yet"
    /// even if the auto-engine created a transaction. Cleared when manually marked as sent.
    var notSentMonth: Date?
    
    // MARK: - Relationships
    
    /// Optional category for generated transactions.
    @Relationship(deleteRule: .nullify)
    var category: Category?
    
    /// Optional account for generated transactions (Premium feature)
    @Relationship(deleteRule: .nullify)
    var account: Account?

    /// Optional business profile for per-business recurring tracking (v4.1)
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?
    
    /// All transaction instances created from this recurring template.
    @Relationship(deleteRule: .cascade, inverse: \Transaction.recurringParent)
    var transactions: [Transaction]?

    /// Payment logs tracking actual payment dates and amounts (v2.9)
    @Relationship(deleteRule: .cascade, inverse: \RecurringPaymentLog.recurringTransaction)
    var paymentLogs: [RecurringPaymentLog]?
    
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
        account: Account? = nil,
        businessProfile: BusinessProfile? = nil,
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
        self.businessProfile = businessProfile
    }
    
    // MARK: - Computed Properties
    
    /// Display name combines merchantName and note intelligently
    var displayName: String {
        if merchantName.isEmpty {
            return note.isEmpty ? "Recurring Transaction" : note
        }
        return merchantName
    }
    
    /// Account name for display
    var accountName: String {
        account?.name ?? "No Account"
    }
    
    /// Whether this recurring transaction has an assigned account
    var hasAccount: Bool {
        account != nil
    }
    
    /// The next date when an instance should be created.
    /// Properly handles all months including those without the intended day
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
        let start = DateFormatter.mediumDate.string(from: startDate)
        if let end = endDate {
            return "\(frequency.displayName) from \(start) to \(DateFormatter.mediumDate.string(from: end))"
        } else {
            return "\(frequency.displayName) starting \(start)"
        }
    }
    
    /// Number of instances created so far.
    var instanceCount: Int {
        (transactions ?? []).count
    }

    /// Total amount generated by all instances.
    var totalGenerated: Double {
        (transactions ?? []).reduce(0) { $0 + $1.amount }
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
    /// v2.8: Now updates account balance when instance is created
    /// v2.7: Fixed - amounts are always positive, isIncome determines direction
    @discardableResult
    func createNextInstance(in context: ModelContext, on date: Date = .now) -> Transaction? {
        guard shouldCreateInstance(today: date) else { return nil }

        // Prevent duplicates on same day
        let calendar = Calendar.current
        if let last = lastCreated, calendar.isDate(last, inSameDayAs: date) {
            return nil
        }

        // v2.10 FIX: Belt-and-suspenders dedup against the actual transactions relationship.
        // The lastCreated flag alone is not sufficient under CloudKit sync — two devices can
        // each materialize an instance before syncing, and lastCreated merges last-write-wins
        // while both Transaction rows survive. Querying the relationship catches post-sync
        // duplicates and in-session retries.
        let existingForDay = (transactions ?? []).filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        if !existingForDay.isEmpty {
            // Sync the flag so future runs short-circuit on the cheap check above.
            lastCreated = date
            #if DEBUG
            print("[Recurring] Skipped duplicate for \(merchantName) on \(date.formatted(date: .abbreviated, time: .omitted)) — \(existingForDay.count) already exist")
            #endif
            return nil
        }

        // v2.7 FIX: Amount is ALWAYS positive - isIncome determines direction
        // This matches Transaction model spec: "Transaction amount (always positive, use isIncome to determine direction)"
        let transactionAmount = abs(amount)  // Ensure positive
        
        let transaction = Transaction(
            amount: transactionAmount,
            date: date,
            note: note.isEmpty ? merchantName : note,
            isIncome: isIncome,
            merchantName: merchantName,
            category: category,
            financeType: financeType,
            account: account
        )
        
        transaction.recurringParent = self
        if transactions != nil {
            transactions?.append(transaction)
        } else {
            transactions = [transaction]
        }
        context.insert(transaction)
        
        // v2.8 FIX: Update account balance when recurring instance is created
        // This ensures account balances stay in sync with transaction summaries
        if let account = account {
            if isIncome {
                account.currentBalance += transactionAmount
            } else {
                account.currentBalance -= transactionAmount
            }
            account.lastBalanceUpdate = Date()
            account.touch()
            
            #if DEBUG
            print("[Recurring] Updated \(account.name) balance: \(account.formattedBalance)")
            #endif
        }
        
        lastCreated = date
        
        #if DEBUG
        print("[Recurring] Created instance: \(merchantName) - $\(transactionAmount) (\(isIncome ? "income" : "expense")) on \(date.formatted(date: .abbreviated, time: .omitted))")
        #endif
        
        return transaction
    }
    
    // MARK: - Payment Log Helpers (v2.9)

    /// Suggested day of month based on actual payment history (weighted toward recent payments).
    /// Returns nil if fewer than 2 payment logs exist.
    var suggestedDayOfMonth: Int? {
        let logs = (paymentLogs ?? []).sorted { $0.dateSent < $1.dateSent }
        guard logs.count >= 2 else { return nil }

        // Use last 6 payments max, weighted toward recent
        let recentLogs = Array(logs.suffix(6))
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for (index, log) in recentLogs.enumerated() {
            let weight = Double(index + 1) // More recent = higher weight
            weightedSum += Double(log.dayOfMonthSent) * weight
            totalWeight += weight
        }

        guard totalWeight > 0 else { return nil }
        return Int(round(weightedSum / totalWeight))
    }

    /// Check if a payment has already been logged for a given month.
    func hasPaymentForMonth(_ month: Date) -> Bool {
        let calendar = Calendar.current
        return (paymentLogs ?? []).contains { log in
            calendar.isDate(log.billingMonth, equalTo: month, toGranularity: .month)
        }
    }

    /// Get the payment log for a specific month (if exists).
    func paymentLog(for month: Date) -> RecurringPaymentLog? {
        let calendar = Calendar.current
        return (paymentLogs ?? []).first { log in
            calendar.isDate(log.billingMonth, equalTo: month, toGranularity: .month)
        }
    }

    /// Find an auto-engine-created transaction for a given month (even without a payment log).
    func transactionForMonth(_ month: Date) -> Transaction? {
        let calendar = Calendar.current
        return (transactions ?? []).first { txn in
            !txn.isDeleted &&
            calendar.isDate(txn.date, equalTo: month, toGranularity: .month)
        }
    }

    /// Check if this recurring is effectively "sent" for a month — either via a payment log
    /// OR because the auto-engine already created a transaction for this month.
    /// Respects `notSentMonth` override — if user explicitly marked "not paid yet", returns false.
    func isSentForMonth(_ month: Date) -> Bool {
        let calendar = Calendar.current
        // Check for explicit "not paid yet" override
        if let notSent = notSentMonth,
           calendar.isDate(notSent, equalTo: month, toGranularity: .month) {
            return false
        }
        if hasPaymentForMonth(month) { return true }
        return transactionForMonth(month) != nil
    }

    /// Mark a recurring as "not paid yet" for a given month.
    /// Deletes the auto-created transaction (if any), adjusts account balance, and sets the override.
    /// When the user later marks as sent, the override is cleared automatically.
    func markAsNotSent(for month: Date, in context: ModelContext) {
        let calendar = Calendar.current

        // Remove any payment log for this month
        if let log = paymentLog(for: month) {
            context.delete(log)
            paymentLogs?.removeAll { $0.id == log.id }
        }

        // Delete the auto-created transaction and reverse account balance
        if let txn = transactionForMonth(month) {
            // Reverse the balance impact
            if let account = txn.account ?? self.account {
                if txn.isIncome {
                    account.currentBalance -= abs(txn.amount)
                } else {
                    account.currentBalance += abs(txn.amount)
                }
                account.lastBalanceUpdate = Date()
                account.touch()
            }

            // Remove from our transactions list and delete
            transactions?.removeAll { $0.id == txn.id }
            context.delete(txn)
        }

        // Set the override so isSentForMonth returns false even if auto-engine recreates
        let components = calendar.dateComponents([.year, .month], from: month)
        notSentMonth = calendar.date(from: components)

        #if DEBUG
        print("[Recurring] Marked \(merchantName) as not sent for \(month)")
        #endif
    }

    /// Mark this recurring as sent for a given month.
    /// If the auto-engine already created a transaction for this month, links to it instead of duplicating.
    /// Otherwise creates a new transaction.
    /// - Parameters:
    ///   - month: The billing month this payment covers
    ///   - sentAmount: Actual amount sent (defaults to template amount)
    ///   - sentDate: Date payment was made (defaults to now)
    ///   - context: ModelContext for persistence
    /// - Returns: The created RecurringPaymentLog, or nil if already fully logged for this month
    @discardableResult
    func markAsSent(
        for month: Date,
        amount sentAmount: Double? = nil,
        on sentDate: Date = .now,
        in context: ModelContext
    ) -> RecurringPaymentLog? {
        // Don't double-log if a payment log already exists
        guard !hasPaymentForMonth(month) else { return nil }

        let calendar = Calendar.current
        let paymentAmount = sentAmount ?? amount

        // Check if the auto-engine already created a transaction for this month
        let existingTransaction = (transactions ?? []).first { txn in
            calendar.isDate(txn.date, equalTo: month, toGranularity: .month) &&
            txn.merchantName == merchantName
        }

        // Create the payment log
        let log = RecurringPaymentLog(
            recurringTransaction: self,
            billingMonth: month,
            amountSent: paymentAmount,
            dateSent: sentDate,
            isManual: true
        )

        let transaction: Transaction
        if let existing = existingTransaction {
            // Link to existing auto-generated transaction — no duplicate
            transaction = existing
            #if DEBUG
            print("[Recurring] Linking to existing transaction for \(merchantName)")
            #endif
        } else {
            // No auto-generated transaction yet — create one
            let transactionAmount = abs(paymentAmount)
            transaction = Transaction(
                amount: transactionAmount,
                date: sentDate,
                note: note.isEmpty ? merchantName : note,
                isIncome: isIncome,
                merchantName: merchantName,
                category: category,
                financeType: financeType,
                account: account
            )
            transaction.recurringParent = self

            if transactions != nil {
                transactions?.append(transaction)
            } else {
                transactions = [transaction]
            }

            context.insert(transaction)

            // Update account balance only for new transactions
            if let account = account {
                if isIncome {
                    account.currentBalance += transactionAmount
                } else {
                    account.currentBalance -= transactionAmount
                }
                account.lastBalanceUpdate = Date()
                account.touch()
            }
        }

        // Link log to transaction
        log.transaction = transaction

        if paymentLogs != nil {
            paymentLogs?.append(log)
        } else {
            paymentLogs = [log]
        }

        context.insert(log)

        // Clear "not paid yet" override if it was set for this month
        if let notSent = notSentMonth,
           calendar.isDate(notSent, equalTo: month, toGranularity: .month) {
            notSentMonth = nil
        }

        // Update lastCreated so the auto-engine doesn't create another instance
        lastCreated = sentDate

        #if DEBUG
        print("[Recurring] Marked sent: \(merchantName) - $\(abs(paymentAmount)) for \(DateFormatter.monthYear.string(from: month))")
        #endif

        return log
    }

    /// Deactivate this recurring transaction.
    func deactivate() {
        isActive = false
    }
    
    /// Reactivate this recurring transaction.
    func activate() {
        isActive = true
    }
    
    /// Update the account for this recurring transaction
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
    
    /// DEPRECATED: Use nextDate(from:) instead for accurate calendar calculations
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
