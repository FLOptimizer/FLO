//  BillPayment.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill payment tracking with partial payment support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks individual payments against bills for complete payment history.
//  Mirrors InvoicePayment but for the inverse direction (vendors billing the user).
//
//  CHANGES v1.0:
//  ✅ Initial bill payment model
//  ✅ CloudKit-compatible: all properties have inline defaults, no @Attribute(.unique)
//  ✅ Optional reference to the Transaction this payment created (one-directional —
//     no inverse declared on Transaction to keep Phase 1 purely additive)
//  ✅ Reuses PaymentMethod enum from InvoicePayment

import Foundation
import SwiftData

@Model
final class BillPayment {

    // MARK: - Properties

    private(set) var id: UUID = UUID()
    var amount: Double = 0.0
    var date: Date = Date()
    var paymentMethod: PaymentMethod = PaymentMethod.bankTransfer
    var notes: String = ""
    var createdAt: Date = Date()

    // MARK: - Relationships

    @Relationship(deleteRule: .nullify)
    var account: Account?

    /// The Transaction this payment posted to the ledger.
    /// One-directional: Transaction does not declare an inverse back to BillPayment
    /// in Phase 1, to keep this migration purely additive. Lookup from a Transaction
    /// to its BillPayment must be done via FetchDescriptor when needed.
    @Relationship(deleteRule: .nullify)
    var linkedTransaction: Transaction?

    /// Owning bill — set automatically when added to a Bill via `recordPayment`.
    /// Inverse declared on Bill.payments.
    var bill: Bill?

    // MARK: - Initialization

    init(
        amount: Double,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .bankTransfer,
        notes: String = "",
        account: Account? = nil,
        linkedTransaction: Transaction? = nil,
        bill: Bill? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.account = account
        self.linkedTransaction = linkedTransaction
        self.bill = bill
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    var formattedAmount: String {
        amount.formatted(.currency(code: "USD"))
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var displayDescription: String {
        var desc = "\(formattedAmount) via \(paymentMethod.displayName)"
        if let accountName = account?.name {
            desc += " ← \(accountName)"
        }
        return desc
    }
}

// MARK: - Protocol Conformances

extension BillPayment: Identifiable {}

extension BillPayment: Equatable {
    static func == (lhs: BillPayment, rhs: BillPayment) -> Bool {
        lhs.id == rhs.id
    }
}

extension BillPayment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension BillPayment {
    @MainActor static var previewFull: BillPayment {
        BillPayment(
            amount: 142.58,
            date: Date(),
            paymentMethod: .bankTransfer,
            notes: "Auto-pay"
        )
    }

    @MainActor static var previewPartial: BillPayment {
        BillPayment(
            amount: 50.00,
            date: Date().addingTimeInterval(-86400 * 3),
            paymentMethod: .creditCard,
            notes: "Partial payment — rest next paycheck"
        )
    }
}
#endif
