//  Bill.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill tracking with partial payment + Mark Paid flow
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  A Bill is an obligation the user owes to a vendor. It's the inverse of Invoice
//  (which is money owed *to* the user). Bills sit in Upcoming Transactions until
//  marked paid; on payment they create a real Transaction posted to the ledger.
//
//  Key design decisions:
//  - Phase 1 is purely additive: no modifications to Transaction.swift. The
//    BillPayment → Transaction link is one-directional.
//  - dueDate is optional; isUponReceipt = true means "no fixed date, pay ASAP".
//  - Overdue is COMPUTED, not stored, so it never goes stale.
//  - Partial payments are first-class via BillPayment[] (mirrors InvoicePayment).
//
//  CHANGES v1.0:
//  ✅ Initial bill model
//  ✅ CloudKit-compatible: all properties have inline defaults, no @Attribute(.unique)
//  ✅ Cascade-deletes BillPayments when bill is deleted

import Foundation
import SwiftData

@Model
final class Bill {

    // MARK: - Properties

    var id: UUID = UUID()

    /// Display name for the vendor. Always set, even when `vendor` relationship is nil
    /// (e.g., scanned bill with no matching Vendor record yet).
    var vendorName: String = ""

    /// Total amount owed on this bill.
    var amount: Double = 0.0

    var note: String = ""

    /// When the bill was created/added to FLO (not when it's due).
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()

    /// Due date for the bill. Nil when `isUponReceipt` is true.
    var dueDate: Date?

    /// "Upon Receipt" — bill should be paid ASAP, no fixed date.
    /// When true, `dueDate` should be nil. Mutually exclusive in UI.
    var isUponReceipt: Bool = false

    /// Stored status. `.overdue` is NOT a stored case — overdue is computed.
    var status: BillStatus = BillStatus.pending

    /// Personal vs Business — drives reporting and tax categorization.
    var financeType: Transaction.FinanceType = Transaction.FinanceType.personal

    /// Scanned bill image (set in Phase 2 by the Scanner).
    @Attribute(.externalStorage)
    var scannedImageData: Data?

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    var vendor: Vendor?

    @Relationship(deleteRule: .nullify)
    var category: Category?

    @Relationship(deleteRule: .nullify)
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \BillPayment.bill)
    var payments: [BillPayment]?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        vendorName: String,
        amount: Double,
        note: String = "",
        dueDate: Date? = nil,
        isUponReceipt: Bool = false,
        status: BillStatus = .pending,
        financeType: Transaction.FinanceType = .personal,
        vendor: Vendor? = nil,
        category: Category? = nil,
        account: Account? = nil,
        scannedImageData: Data? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.vendorName = vendorName
        self.amount = amount
        self.note = note
        self.dueDate = isUponReceipt ? nil : dueDate
        self.isUponReceipt = isUponReceipt
        self.status = status
        self.financeType = financeType
        self.vendor = vendor
        self.category = category
        self.account = account
        self.scannedImageData = scannedImageData
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    // MARK: - Computed Properties — Payment Math

    var amountPaid: Double {
        (payments ?? []).reduce(0) { $0 + $1.amount }
    }

    var remainingBalance: Double {
        max(amount - amountPaid, 0)
    }

    var hasPayments: Bool {
        !(payments ?? []).isEmpty
    }

    /// Considered fully paid when remaining balance is within 1¢ (rounding tolerance).
    var isFullyPaid: Bool {
        remainingBalance <= 0.01
    }

    var isPartiallyPaid: Bool {
        hasPayments && !isFullyPaid
    }

    /// Progress 0.0–1.0. Useful for progress bars.
    var paymentProgress: Double {
        guard amount > 0 else { return 0 }
        return min(amountPaid / amount, 1.0)
    }

    // MARK: - Computed Properties — Status

    /// Computed (not stored). True when the bill is unpaid/partially paid AND past due.
    /// "Upon Receipt" bills are considered overdue 1 day after creation.
    var isOverdue: Bool {
        guard status == .pending || status == .partiallyPaid else { return false }
        let now = Date()
        if isUponReceipt {
            // Upon Receipt → overdue if more than 1 day has passed since creation
            return now.timeIntervalSince(createdDate) > 86400
        }
        guard let dueDate else { return false }
        return now > dueDate
    }

    /// Effective sort date for Upcoming list. Upon-Receipt bills sort to the very top.
    var effectiveSortDate: Date {
        if isUponReceipt {
            return Date.distantPast
        }
        return dueDate ?? Date.distantFuture
    }

    /// Days until due. Negative when overdue. Nil for Upon Receipt.
    var daysUntilDue: Int? {
        guard let dueDate else { return nil }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day
    }

    // MARK: - Computed Properties — Display

    var formattedAmount: String {
        amount.formatted(.currency(code: "USD"))
    }

    var formattedAmountPaid: String {
        amountPaid.formatted(.currency(code: "USD"))
    }

    var formattedRemainingBalance: String {
        remainingBalance.formatted(.currency(code: "USD"))
    }

    var formattedDueDate: String {
        if isUponReceipt { return "Upon Receipt" }
        guard let dueDate else { return "No Due Date" }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    /// Display label for Upcoming row badge: "Due", "Overdue", "Partial", or "Upon Receipt".
    var badgeLabel: String {
        if isOverdue { return "Overdue" }
        if isPartiallyPaid { return "Partial" }
        if isUponReceipt { return "Upon Receipt" }
        return "Due"
    }

    // MARK: - Methods — Payment

    /// Record a payment against this bill. Creates a `BillPayment`, a posted
    /// `Transaction`, debits the account, and updates bill status.
    ///
    /// - Parameters:
    ///   - paymentAmount: How much was paid. Defaults to remaining balance (full payment).
    ///   - date: When the payment was made. Defaults to today.
    ///   - paymentMethod: How it was paid.
    ///   - account: Account the money came from. Bill's account if not specified.
    ///   - paymentNotes: Optional notes on the payment.
    ///   - context: ModelContext to insert the new Transaction into.
    /// - Returns: The created `BillPayment` and the posted `Transaction`.
    @discardableResult
    func recordPayment(
        amount paymentAmount: Double? = nil,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .bankTransfer,
        account paymentAccount: Account? = nil,
        notes paymentNotes: String = "",
        in context: ModelContext
    ) -> (payment: BillPayment, transaction: Transaction) {
        let resolvedAmount = paymentAmount ?? remainingBalance
        let resolvedAccount = paymentAccount ?? self.account

        // 1. Create the posted Transaction
        let transaction = Transaction(
            amount: resolvedAmount,
            date: date,
            note: paymentNotes.isEmpty ? "Bill payment: \(vendorName)" : paymentNotes,
            isIncome: false,
            merchantName: vendorName,
            category: category,
            financeType: financeType,
            account: resolvedAccount
        )
        context.insert(transaction)

        // 2. Update account balance
        resolvedAccount?.recordTransaction(amount: resolvedAmount, isIncome: false)

        // 3. Create the BillPayment record and link to the transaction
        let payment = BillPayment(
            amount: resolvedAmount,
            date: date,
            paymentMethod: paymentMethod,
            notes: paymentNotes,
            account: resolvedAccount,
            linkedTransaction: transaction,
            bill: self
        )

        if payments != nil {
            payments?.append(payment)
        } else {
            payments = [payment]
        }

        // 4. Update bill status
        updatePaymentStatus(asOf: date)

        return (payment, transaction)
    }

    /// Recompute status from current payments. Called automatically by `recordPayment`,
    /// but can be invoked directly after editing or removing payments.
    func updatePaymentStatus(asOf paidDate: Date = Date()) {
        if isFullyPaid {
            status = .paid
        } else if hasPayments {
            status = .partiallyPaid
        } else {
            status = .pending
        }
        modifiedDate = Date()
    }

    func cancel() {
        status = .cancelled
        modifiedDate = Date()
    }

    func reactivate() {
        // Recompute from payments
        updatePaymentStatus()
    }

    func touch() {
        modifiedDate = Date()
    }
}

// MARK: - Bill Status

enum BillStatus: String, Codable, CaseIterable {
    case pending
    case partiallyPaid
    case paid
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .partiallyPaid: return "Partially Paid"
        case .paid: return "Paid"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .partiallyPaid: return "circle.lefthalf.filled"
        case .paid: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

// MARK: - Protocol Conformances

extension Bill: Identifiable {}

extension Bill: Equatable {
    static func == (lhs: Bill, rhs: Bill) -> Bool {
        lhs.id == rhs.id
    }
}

extension Bill: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Filter Predicates

extension Bill {
    /// Bills that should appear in Upcoming Transactions:
    /// pending or partially-paid (not cancelled, not fully paid).
    static func upcomingPredicate() -> Predicate<Bill> {
        let pending = BillStatus.pending
        let partial = BillStatus.partiallyPaid
        return #Predicate<Bill> { bill in
            bill.status == pending || bill.status == partial
        }
    }
}

// MARK: - Preview Support

#if DEBUG
extension Bill {
    @MainActor static var previewPending: Bill {
        Bill(
            vendorName: "PG&E",
            amount: 142.58,
            note: "Electric — March",
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            financeType: .personal
        )
    }

    @MainActor static var previewUponReceipt: Bill {
        Bill(
            vendorName: "Smith Plumbing",
            amount: 450.00,
            note: "Emergency repair",
            isUponReceipt: true,
            financeType: .personal
        )
    }

    @MainActor static var previewOverdue: Bill {
        Bill(
            vendorName: "Comcast",
            amount: 89.99,
            dueDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            financeType: .personal
        )
    }

    @MainActor static var previewPartiallyPaid: Bill {
        let bill = Bill(
            vendorName: "AmEx",
            amount: 1200.00,
            dueDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()),
            financeType: .business
        )
        bill.status = .partiallyPaid
        let payment = BillPayment(
            amount: 400.00,
            date: Date().addingTimeInterval(-86400 * 2),
            paymentMethod: .bankTransfer,
            bill: bill
        )
        bill.payments = [payment]
        return bill
    }
}
#endif
