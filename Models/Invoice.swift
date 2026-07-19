//  Invoice.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Multi-Business Invoice Support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Invoice tracking and management model
//
//  CHANGES v2.4:
//  ✅ ADDED: businessProfile relationship — which business issued this invoice
//
//  CHANGES v2.3:
//  ✅ ReminderRecord is now a Codable struct (not @Model)
//  ✅ remindersSent array is automatically JSON-serialized by SwiftData
//  ✅ No relationship management needed for embedded reminder data
//
import Foundation
import SwiftData


@Model
final class Invoice {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID = UUID()

    /// Invoice number (user-visible, e.g., "INV-2024-001")
    var invoiceNumber: String = ""
    
    /// Client this invoice is for
    var client: Client?

    /// Which business issued this invoice (v2.4)
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    /// Invoice issue date
    var issueDate: Date = Date() {
        didSet { updateModifiedDate() }
    }

    /// Invoice due date
    var dueDate: Date = Date() {
        didSet { updateModifiedDate() }
    }
    
    /// Date invoice was actually paid in full (nil if unpaid or partially paid)
    var paidDate: Date? {
        didSet { updateModifiedDate() }
    }
    
    /// Invoice status
    var status: InvoiceStatus = InvoiceStatus.draft {
        didSet { updateModifiedDate() }
    }

    /// Payment terms (e.g., "Net 30", "Due on Receipt")
    var paymentTerms: String = "Net 30" {
        didSet { updateModifiedDate() }
    }
    
    /// Line items on this invoice
    @Relationship(deleteRule: .cascade, inverse: \InvoiceItem.invoice)
    var items: [InvoiceItem]?

    /// Payment records (supports partial payments)
    @Relationship(deleteRule: .cascade, inverse: \InvoicePayment.invoice)
    var payments: [InvoicePayment]?
    
    /// Subtotal before tax
    var subtotal: Double {
        (items ?? []).reduce(0) { $0 + $1.total }
    }
    
    // WARNING: Using Double for money. Acceptable for MVP. Migrate to Decimal in v3 for production accounting.
    
    /// Tax rate (as decimal, e.g., 0.0825 for 8.25%)
    var taxRate: Double = 0.0 {
        didSet { updateModifiedDate() }
    }
    
    /// Tax amount
    var taxAmount: Double {
        subtotal * taxRate
    }
    
    /// Discount amount (flat dollar amount)
    var discountAmount: Double = 0.0 {
        didSet { updateModifiedDate() }
    }
    
    /// Total amount due
    var totalAmount: Double {
        subtotal + taxAmount - discountAmount
    }
    
    /// Invoice notes/description
    var notes: String? {
        didSet { updateModifiedDate() }
    }
    
    /// Payment instructions for client
    var paymentInstructions: String? {
        didSet { updateModifiedDate() }
    }
    
    /// Payment links (copied from client or invoice-specific)
    var stripePaymentLink: String? {
        didSet { updateModifiedDate() }
    }
    var paypalLink: String? {
        didSet { updateModifiedDate() }
    }
    var venmoUsername: String? {
        didSet { updateModifiedDate() }
    }
    var zelleEmail: String? {
        didSet { updateModifiedDate() }
    }
    
    /// Date invoice was sent to client
    var sentDate: Date? {
        didSet { updateModifiedDate() }
    }
    
    /// Reminder history (embedded Codable data, auto-serialized as JSON)
    var remindersSent: [ReminderRecord] = []
    
    /// Date when invoice was created
    var createdDate: Date = Date()

    /// Date when invoice was last modified
    var modifiedDate: Date = Date()
    
    // MARK: - Payment Computed Properties
    
    /// Total amount paid so far
    var amountPaid: Double {
        (payments ?? []).reduce(0) { $0 + $1.amount }
    }

    /// Remaining balance to be paid
    var remainingBalance: Double {
        max(totalAmount - amountPaid, 0)
    }

    /// Whether invoice has any payments
    var hasPayments: Bool {
        !(payments ?? []).isEmpty
    }
    
    /// Whether invoice is fully paid
    var isFullyPaid: Bool {
        remainingBalance <= 0.01 // Allow for small floating point differences
    }
    
    /// Whether invoice is partially paid
    var isPartiallyPaid: Bool {
        hasPayments && !isFullyPaid
    }
    
    /// Payment progress (0.0 to 1.0)
    var paymentProgress: Double {
        guard totalAmount > 0 else { return 0 }
        return min(amountPaid / totalAmount, 1.0)
    }
    
    /// Formatted amount paid
    var formattedAmountPaid: String {
        amountPaid.formatted(.currency(code: "USD"))
    }
    
    /// Formatted remaining balance
    var formattedRemainingBalance: String {
        remainingBalance.formatted(.currency(code: "USD"))
    }
    
    // MARK: - Existing Computed Properties
    
    /// Number of days since invoice was issued
    var daysOutstanding: Int {
        Calendar.current.dateComponents([.day], from: issueDate, to: Date()).day ?? 0
    }
    
    /// Number of days until due date (negative if overdue)
    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
    
    /// Number of days overdue (0 if not overdue)
    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return abs(daysUntilDue)
    }
    
    /// Whether invoice is overdue
    var isOverdue: Bool {
        status != .paid && status != .cancelled && Date() > dueDate
    }
    
    /// Convenience properties for status checks
    var isPaid: Bool { status == .paid }
    var isDraft: Bool { status == .draft }
    var isSent: Bool { status == .sent || status == .viewed }
    var isFinal: Bool { status == .paid || status == .cancelled }
    var hasBeenSent: Bool { sentDate != nil }
    var canSendReminder: Bool {
        [.sent, .viewed, .partiallyPaid, .overdue].contains(status)
    }
    
    /// Aging bucket for reports (Current, 1-30, 31-60, 61-90, 90+)
    var agingBucket: AgingBucket {
        AgingBucket.bucket(for: self)
    }
    
    /// Urgency level for UI (green/yellow/red)
    var urgencyLevel: UrgencyLevel {
        if status == .paid || status == .cancelled {
            return .none
        }
        
        let daysUntil = daysUntilDue
        
        if daysUntil < 0 {
            // Overdue
            let daysLate = abs(daysUntil)
            if daysLate > 30 {
                return .critical
            } else if daysLate > 7 {
                return .high
            } else {
                return .medium
            }
        } else if daysUntil <= 3 {
            return .medium
        } else if daysUntil <= 7 {
            return .low
        } else {
            return .none
        }
    }
    
    /// Formatted due date status (e.g., "Due in 5 days", "Overdue by 3 days")
    var dueDateStatus: String {
        if status == .paid {
            return "Paid"
        } else if status == .cancelled {
            return "Cancelled"
        }
        
        let days = daysUntilDue
        
        if days == 0 {
            return "Due today"
        } else if days > 0 {
            return "Due in \(days) \(days == 1 ? "day" : "days")"
        } else {
            let overdue = abs(days)
            return "Overdue by \(overdue) \(overdue == 1 ? "day" : "days")"
        }
    }
    
    /// Should send reminder? (based on overdue days)
    func shouldSendReminder(atDays days: Int) -> Bool {
        guard canSendReminder else { return false }
        guard daysOverdue == days else { return false }
        
        // Check if we already sent a reminder at this interval
        return !remindersSent.contains { $0.daysOverdue == days }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        invoiceNumber: String,
        client: Client? = nil,
        issueDate: Date = Date(),
        dueDate: Date,
        paidDate: Date? = nil,
        status: InvoiceStatus = .draft,
        paymentTerms: String = "Net 30",
        taxRate: Double = 0.0,
        discountAmount: Double = 0.0,
        notes: String? = nil,
        paymentInstructions: String? = nil,
        stripePaymentLink: String? = nil,
        paypalLink: String? = nil,
        venmoUsername: String? = nil,
        zelleEmail: String? = nil,
        sentDate: Date? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.client = client
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.status = status
        self.paymentTerms = paymentTerms
        self.taxRate = taxRate
        self.discountAmount = discountAmount
        self.notes = notes
        self.paymentInstructions = paymentInstructions
        self.stripePaymentLink = stripePaymentLink
        self.paypalLink = paypalLink
        self.venmoUsername = venmoUsername
        self.zelleEmail = zelleEmail
        self.sentDate = sentDate
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
    
    // MARK: - Helper Methods
    
    /// Update the modified date (called automatically by didSet observers)
    func updateModifiedDate() {
        modifiedDate = Date()
    }
    
    /// Record that a reminder was sent
    func recordReminderSent() {
        let record = ReminderRecord(
            date: Date(),
            daysOverdue: daysOverdue,
            reminderType: determineReminderType()
        )
        
        remindersSent.append(record)
        modifiedDate = Date()
    }
    
    /// Determine which type of reminder to send based on days overdue
    private func determineReminderType() -> ReminderType {
        let days = daysOverdue
        
        if days <= 3 {
            return .gentle
        } else if days <= 7 {
            return .standard
        } else if days <= 14 {
            return .firm
        } else {
            return .final
        }
    }
    
    /// Mark invoice as sent
    func markAsSent(date: Date = Date()) {
        self.status = .sent
        self.sentDate = date
        self.modifiedDate = Date()
    }
    
    /// Mark invoice as paid (legacy - use addPayment for new code)
    func markAsPaid(date: Date = Date()) {
        self.status = .paid
        self.paidDate = date
        self.modifiedDate = Date()
    }
    
    /// Add a payment to the invoice
    /// - Returns: The created payment record
    @discardableResult
    func addPayment(
        amount: Double,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .bankTransfer,
        account: Account? = nil,
        notes: String = "",
        linkedTransaction: Transaction? = nil
    ) -> InvoicePayment {
        let payment = InvoicePayment(
            amount: amount,
            date: date,
            paymentMethod: paymentMethod,
            notes: notes,
            account: account,
            linkedTransaction: linkedTransaction,
            invoice: self
        )
        
        if payments != nil {
            payments?.append(payment)
        } else {
            payments = [payment]
        }
        
        // Update status based on payment
        if isFullyPaid {
            self.status = .paid
            self.paidDate = date
        } else if hasPayments {
            self.status = .partiallyPaid
        }
        
        self.modifiedDate = Date()
        
        return payment
    }
    
    /// Update status based on current payment state
    func updatePaymentStatus() {
        if isFullyPaid {
            self.status = .paid
            if paidDate == nil {
                self.paidDate = payments?.last?.date ?? Date()
            }
        } else if hasPayments {
            self.status = .partiallyPaid
            self.paidDate = nil
        }
        self.modifiedDate = Date()
    }
}

// MARK: - Supporting Models

@Model
final class InvoiceItem {
    var id: UUID = UUID()

    var invoice: Invoice?

    var itemDescription: String = "" {
        didSet {
            invoice?.updateModifiedDate()
        }
    }

    var quantity: Double = 0.0 {
        didSet {
            invoice?.updateModifiedDate()
        }
    }

    var unitPrice: Double = 0.0 {
        didSet {
            invoice?.updateModifiedDate()
        }
    }

    var total: Double {
        quantity * unitPrice
    }

    var createdDate: Date = Date()
    
    init(
        id: UUID = UUID(),
        invoice: Invoice? = nil,
        itemDescription: String,
        quantity: Double,
        unitPrice: Double,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.invoice = invoice
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.createdDate = createdDate
    }
}

// MARK: - Extensions

extension Invoice {
    /// Generate next invoice number based on existing invoices
    static func generateNextInvoiceNumber(existingInvoices: [Invoice]) -> String {
        let year = Calendar.current.component(.year, from: Date())
        let prefix = "INV-\(year)-"
        
        let currentYearNumbers = existingInvoices
            .lazy
            .compactMap { invoice -> Int? in
                guard invoice.invoiceNumber.hasPrefix(prefix),
                      let lastPart = invoice.invoiceNumber.dropFirst(prefix.count).split(separator: "-").last,
                      let number = Int(lastPart)
                else { return nil }
                return number
            }
        
        let nextNumber = (currentYearNumbers.max() ?? 0) + 1
        return String(format: "%@%03d", prefix, nextNumber)
    }
}

extension Invoice: Equatable {
    static func == (lhs: Invoice, rhs: Invoice) -> Bool {
        lhs.id == rhs.id
    }
}
