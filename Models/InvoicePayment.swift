//  InvoicePayment.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Invoice payment tracking with partial payment support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks individual payments against invoices for complete payment history

import Foundation
import SwiftData

@Model
final class InvoicePayment {
    
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
    
    @Relationship(deleteRule: .nullify)
    var linkedTransaction: Transaction?
    
    @Relationship(deleteRule: .nullify)
    var invoice: Invoice?
    
    // MARK: - Initialization
    
    init(
        amount: Double,
        date: Date = Date(),
        paymentMethod: PaymentMethod = .bankTransfer,
        notes: String = "",
        account: Account? = nil,
        linkedTransaction: Transaction? = nil,
        invoice: Invoice? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.account = account
        self.linkedTransaction = linkedTransaction
        self.invoice = invoice
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
            desc += " → \(accountName)"
        }
        return desc
    }
}

// MARK: - Payment Method

enum PaymentMethod: String, Codable, CaseIterable {
    case bankTransfer = "bankTransfer"
    case check = "check"
    case creditCard = "creditCard"
    case paypal = "paypal"
    case venmo = "venmo"
    case zelle = "zelle"
    case cash = "cash"
    case wire = "wire"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .bankTransfer: return "Bank Transfer (ACH)"
        case .check: return "Check"
        case .creditCard: return "Credit Card"
        case .paypal: return "PayPal"
        case .venmo: return "Venmo"
        case .zelle: return "Zelle"
        case .cash: return "Cash"
        case .wire: return "Wire Transfer"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .bankTransfer: return "building.columns.fill"
        case .check: return "doc.text.fill"
        case .creditCard: return "creditcard.fill"
        case .paypal: return "p.circle.fill"
        case .venmo: return "v.circle.fill"
        case .zelle: return "z.circle.fill"
        case .cash: return "dollarsign.circle.fill"
        case .wire: return "arrow.left.arrow.right.circle.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Protocol Conformances

extension InvoicePayment: Identifiable {}

extension InvoicePayment: Equatable {
    static func == (lhs: InvoicePayment, rhs: InvoicePayment) -> Bool {
        lhs.id == rhs.id
    }
}

extension InvoicePayment: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension InvoicePayment {
    @MainActor static var previewFull: InvoicePayment {
        InvoicePayment(
            amount: 5000.00,
            date: Date(),
            paymentMethod: .bankTransfer,
            notes: "Final payment received"
        )
    }
    
    @MainActor static var previewPartial: InvoicePayment {
        InvoicePayment(
            amount: 2500.00,
            date: Date().addingTimeInterval(-86400 * 7),
            paymentMethod: .check,
            notes: "Check #1042 - First installment"
        )
    }
}
#endif
