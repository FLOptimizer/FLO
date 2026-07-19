//  RecurringPaymentLog.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Recurring Payment Tracking
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks actual payment dates and amounts for recurring transactions.
//  Used for:
//  - "Mark as Sent" early payments before the scheduled date
//  - Suggested date learning (adapts next occurrence based on actual payment patterns)
//  - Budget paid status integration

import Foundation
import SwiftData

/// Logs each actual payment for a recurring transaction, tracking when and how much was sent.
@Model
final class RecurringPaymentLog {

    // MARK: - Identifiers
    private(set) var id: UUID = UUID()

    // MARK: - Payment Data

    /// The billing period this payment covers (first day of the month, normalized)
    var billingMonth: Date = Date()

    /// Actual amount sent (may differ from the recurring template amount)
    var amountSent: Double = 0.0

    /// Date the payment was actually sent/made
    var dateSent: Date = Date()

    /// Whether this was manually marked by the user (vs auto-generated)
    var isManual: Bool = true

    /// Optional note about this specific payment
    var paymentNote: String = ""

    // MARK: - Relationships

    /// The recurring transaction this payment belongs to
    @Relationship(deleteRule: .nullify)
    var recurringTransaction: RecurringTransaction?

    /// The transaction record that was created for this payment (if any)
    @Relationship(deleteRule: .nullify, inverse: \Transaction.paymentLog)
    var transaction: Transaction?

    // MARK: - Metadata

    var createdAt: Date = Date()

    // MARK: - Initialization

    init(
        recurringTransaction: RecurringTransaction,
        billingMonth: Date,
        amountSent: Double,
        dateSent: Date = .now,
        isManual: Bool = true,
        paymentNote: String = ""
    ) {
        self.id = UUID()
        self.recurringTransaction = recurringTransaction
        self.billingMonth = {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: billingMonth)
            return calendar.date(from: components) ?? billingMonth
        }()
        self.amountSent = abs(amountSent)
        self.dateSent = dateSent
        self.isManual = isManual
        self.paymentNote = paymentNote
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    /// Day of month when payment was sent
    var dayOfMonthSent: Int {
        Calendar.current.component(.day, from: dateSent)
    }

    /// Month/Year display for the billing period
    var billingMonthDisplay: String {
        DateFormatter.monthYear.string(from: billingMonth)
    }

    /// Date sent formatted for display
    var dateSentDisplay: String {
        DateFormatter.mediumDate.string(from: dateSent)
    }

    /// Whether the amount differs from the recurring template
    var amountDiffers: Bool {
        guard let recurring = recurringTransaction else { return false }
        return abs(amountSent - recurring.amount) > 0.01
    }
}

// MARK: - Protocol Conformances

extension RecurringPaymentLog: Identifiable {}

extension RecurringPaymentLog: Equatable {
    static func == (lhs: RecurringPaymentLog, rhs: RecurringPaymentLog) -> Bool {
        lhs.id == rhs.id
    }
}

extension RecurringPaymentLog: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension RecurringPaymentLog {
    @MainActor static var previewNetflixPayment: RecurringPaymentLog {
        RecurringPaymentLog(
            recurringTransaction: RecurringTransaction.previewNetflix,
            billingMonth: Date(),
            amountSent: 15.99,
            dateSent: Date(),
            isManual: true
        )
    }
}
#endif
