//  Vendor.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill vendor tracking
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Vendor model for tracking companies that bill the user.
//  Mirrors the Client model (clients invoice the user; vendors bill the user).
//
//  CHANGES v1.0:
//  ✅ Initial vendor model for Bill feature
//  ✅ CloudKit-compatible: all properties have inline defaults, no @Attribute(.unique)
//  ✅ Cascade-deletes bills when vendor is deleted

import Foundation
import SwiftData

@Model
final class Vendor {

    // MARK: - Properties

    var id: UUID = UUID()
    var name: String = ""
    var contactName: String?
    var email: String?
    var phone: String?
    var website: String?
    var accountNumber: String?
    var notes: String?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()

    // Defaults to apply when creating a new bill from this vendor
    var defaultCategory: Category?
    var defaultAccount: Account?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \Bill.vendor)
    var bills: [Bill]?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        name: String,
        contactName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        accountNumber: String? = nil,
        notes: String? = nil,
        defaultCategory: Category? = nil,
        defaultAccount: Account? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.contactName = contactName
        self.email = email
        self.phone = phone
        self.website = website
        self.accountNumber = accountNumber
        self.notes = notes
        self.defaultCategory = defaultCategory
        self.defaultAccount = defaultAccount
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }

    // MARK: - Computed Properties

    var initials: String {
        let components = name.components(separatedBy: .whitespacesAndNewlines)
        let result = components
            .compactMap { $0.first?.uppercased() }
            .prefix(2)
            .joined()
        return result.isEmpty ? "V" : result
    }

    /// Total amount across all non-cancelled bills (paid + unpaid).
    var totalBilled: Double {
        (bills ?? [])
            .filter { $0.status != .cancelled }
            .reduce(0) { $0 + $1.amount }
    }

    /// Sum of remaining balance across pending and partially-paid bills.
    var outstandingBalance: Double {
        (bills ?? [])
            .filter { $0.status == .pending || $0.status == .partiallyPaid }
            .reduce(0) { $0 + $1.remainingBalance }
    }

    var hasOverdueBills: Bool {
        (bills ?? []).contains { $0.isOverdue }
    }

    var pendingBills: [Bill] {
        (bills ?? []).filter { $0.status == .pending || $0.status == .partiallyPaid }
    }

    func touch() {
        modifiedDate = Date()
    }
}

// MARK: - Protocol Conformances

extension Vendor: Identifiable {}

extension Vendor: Equatable {
    static func == (lhs: Vendor, rhs: Vendor) -> Bool {
        lhs.id == rhs.id
    }
}

extension Vendor: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension Vendor {
    @MainActor static var previewPGE: Vendor {
        Vendor(
            name: "PG&E",
            email: "billing@pge.com",
            website: "pge.com",
            accountNumber: "1234567890"
        )
    }

    @MainActor static var previewComcast: Vendor {
        Vendor(
            name: "Comcast",
            phone: "1-800-COMCAST"
        )
    }
}
#endif
