//  Client.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Added initials computed property, made email optional
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//

import Foundation
import SwiftData

@Model
final class Client {
    // MARK: - Properties
    
    /// Unique identifier
    var id: UUID
    
    /// Client/Company name
    var name: String
    
    /// Contact person name (if different from company)
    var contactName: String?
    
    /// Primary email address
    var email: String?
    
    /// Phone number
    var phone: String?
    
    /// Mailing address
    var address: String?
    var city: String?
    var state: String?
    var zipCode: String?
    var country: String?
    
    /// Business tax ID (EIN or similar)
    var taxId: String?
    
    /// Payment terms in days (e.g., Net 30)
    var defaultPaymentTerms: Int
    
    /// Preferred payment method
    var preferredPaymentMethod: String?
    
    /// Payment links for easy client payment
    var stripePaymentLink: String?
    var paypalLink: String?
    var venmoUsername: String?
    var zelleEmail: String?
    
    /// Client notes
    var notes: String?
    
    /// Whether client wants to receive automatic reminders
    var allowReminders: Bool
    
    /// Client status (active, inactive, blocked)
    var status: ClientStatus
    
    /// Relationship to invoices
    @Relationship(deleteRule: .cascade, inverse: \Invoice.client)
    var invoices: [Invoice]?
    
    /// Date client was added
    var createdDate: Date
    
    /// Date client info was last updated
    var modifiedDate: Date
    
    // MARK: - Computed Properties
    
    /// Client initials for avatar display
    var initials: String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        let initials = components
            .compactMap { $0.first?.uppercased() }
            .prefix(2)
            .joined()
        return initials.isEmpty ? "C" : initials
    }
    
    /// Total amount invoiced to this client
    var totalInvoiced: Double {
        invoices?.reduce(0) { $0 + $1.totalAmount } ?? 0
    }
    
    /// Total amount paid by this client
    var totalPaid: Double {
        invoices?.filter { $0.status == .paid }.reduce(0) { $0 + $1.totalAmount } ?? 0
    }
    
    /// Total outstanding balance
    var outstandingBalance: Double {
        invoices?.filter { $0.status != .paid && $0.status != .cancelled }.reduce(0) { $0 + $1.totalAmount } ?? 0
    }
    
    /// Average days to payment
    var averageDaysToPayment: Double? {
        guard let invoices = invoices else { return nil }
        
        let paidInvoices = invoices.filter { $0.status == .paid && $0.paidDate != nil }
        guard !paidInvoices.isEmpty else { return nil }
        
        let totalDays = paidInvoices.reduce(0.0) { total, invoice in
            guard let paidDate = invoice.paidDate else { return total }
            let days = Calendar.current.dateComponents([.day], from: invoice.dueDate, to: paidDate).day ?? 0
            return total + Double(days)
        }
        
        return totalDays / Double(paidInvoices.count)
    }
    
    /// Payment reliability score (0-100)
    /// Based on: on-time payment %, response to reminders, average days late
    var reliabilityScore: Int {
        guard let invoices = invoices, !invoices.isEmpty else { return 100 }
        
        let paidInvoices = invoices.filter { $0.status == .paid && $0.paidDate != nil }
        guard !paidInvoices.isEmpty else { return 50 }
        
        // Calculate on-time payment percentage
        let onTimePayments = paidInvoices.filter { invoice in
            guard let paidDate = invoice.paidDate else { return false }
            return paidDate <= invoice.dueDate
        }.count
        
        let onTimePercentage = Double(onTimePayments) / Double(paidInvoices.count)
        
        // Calculate average days late (only for late payments)
        let latePayments = paidInvoices.filter { invoice in
            guard let paidDate = invoice.paidDate else { return false }
            return paidDate > invoice.dueDate
        }
        
        var latePenalty = 0.0
        if !latePayments.isEmpty {
            let totalDaysLate = latePayments.reduce(0.0) { total, invoice in
                guard let paidDate = invoice.paidDate else { return total }
                let days = max(0, Calendar.current.dateComponents([.day], from: invoice.dueDate, to: paidDate).day ?? 0)
                return total + Double(days)
            }
            let averageDaysLate = totalDaysLate / Double(latePayments.count)
            latePenalty = min(30, averageDaysLate) / 30.0 * 0.3 // Up to 30% penalty
        }
        
        // Calculate final score
        let baseScore = onTimePercentage * 100
        let penalizedScore = baseScore - (latePenalty * 100)
        
        return max(0, min(100, Int(penalizedScore)))
    }
    
    /// Full address formatted
    var formattedAddress: String? {
        var components: [String] = []
        
        if let address = address { components.append(address) }
        
        var cityStateZip: [String] = []
        if let city = city { cityStateZip.append(city) }
        if let state = state { cityStateZip.append(state) }
        if let zipCode = zipCode { cityStateZip.append(zipCode) }
        if !cityStateZip.isEmpty {
            components.append(cityStateZip.joined(separator: ", "))
        }
        
        if let country = country { components.append(country) }
        
        return components.isEmpty ? nil : components.joined(separator: "\n")
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String,
        contactName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zipCode: String? = nil,
        country: String? = nil,
        taxId: String? = nil,
        defaultPaymentTerms: Int = 30,
        preferredPaymentMethod: String? = nil,
        stripePaymentLink: String? = nil,
        paypalLink: String? = nil,
        venmoUsername: String? = nil,
        zelleEmail: String? = nil,
        notes: String? = nil,
        allowReminders: Bool = true,
        status: ClientStatus = .active,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.contactName = contactName
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.zipCode = zipCode
        self.country = country
        self.taxId = taxId
        self.defaultPaymentTerms = defaultPaymentTerms
        self.preferredPaymentMethod = preferredPaymentMethod
        self.stripePaymentLink = stripePaymentLink
        self.paypalLink = paypalLink
        self.venmoUsername = venmoUsername
        self.zelleEmail = zelleEmail
        self.notes = notes
        self.allowReminders = allowReminders
        self.status = status
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
}

// MARK: - Enums

enum ClientStatus: String, Codable, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case blocked = "Blocked"
    
    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .inactive: return "pause.circle.fill"
        case .blocked: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .active: return "green"
        case .inactive: return "gray"
        case .blocked: return "red"
        }
    }
}

// MARK: - Extensions

extension Client {
    /// Check if client has overdue invoices
    var hasOverdueInvoices: Bool {
        guard let invoices = invoices else { return false }
        return invoices.contains { $0.isOverdue }
    }
    
    /// Get all overdue invoices
    var overdueInvoices: [Invoice] {
        invoices?.filter { $0.isOverdue } ?? []
    }
    
    /// Check if client is a good payer (reliability score > 80)
    var isGoodPayer: Bool {
        reliabilityScore >= 80
    }
    
    /// Check if client is a problem payer (reliability score < 50)
    var isProblemPayer: Bool {
        reliabilityScore < 50
    }
}
