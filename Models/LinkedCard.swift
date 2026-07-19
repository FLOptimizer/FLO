//  LinkedCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Card-to-Account Linking
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Links physical/virtual cards to an Account for receipt auto-matching.
//  Supports multiple cards per account (joint accounts, authorized users).
//
//  FEATURES:
//  ✅ Last 4 digits matching for receipt OCR auto-assignment
//  ✅ Cardholder name tracking (whose card is it?)
//  ✅ Expiration date tracking with near-expiry warnings
//  ✅ Optional card label/nickname for easy identification
//

import Foundation
import SwiftData

@Model
final class LinkedCard {
    var id: UUID = UUID()

    /// Last 4 digits of the card number (for receipt matching)
    var lastFourDigits: String = ""

    /// Name on the card (e.g., "Travis Anderson", "Jane Anderson")
    var cardholderName: String = ""

    /// Optional nickname (e.g., "Chase Sapphire", "Business Amex")
    var nickname: String?

    /// Card network (Visa, Mastercard, Amex, Discover, etc.)
    var networkRaw: String?

    /// Expiration month (1-12)
    var expirationMonth: Int?

    /// Expiration year (e.g., 2028)
    var expirationYear: Int?

    /// The account this card is linked to
    @Relationship(deleteRule: .nullify)
    var account: Account?

    var createdDate: Date = Date()

    init(
        lastFourDigits: String,
        cardholderName: String,
        nickname: String? = nil,
        network: CardNetwork? = nil,
        expirationMonth: Int? = nil,
        expirationYear: Int? = nil
    ) {
        self.id = UUID()
        self.lastFourDigits = lastFourDigits
        self.cardholderName = cardholderName
        self.nickname = nickname
        self.networkRaw = network?.rawValue
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.createdDate = Date()
    }

    // MARK: - Computed Properties

    var network: CardNetwork? {
        get { networkRaw.flatMap { CardNetwork(rawValue: $0) } }
        set { networkRaw = newValue?.rawValue }
    }

    /// Human-readable display name: "Travis (****1234)" or "Chase Sapphire (****1234)"
    var displayName: String {
        let label = nickname ?? cardholderName
        return "\(label) (****\(lastFourDigits))"
    }

    /// Short label for compact UI: "****1234"
    var shortLabel: String {
        "****\(lastFourDigits)"
    }

    /// Expiration date as "MM/YY" string
    var expirationDisplay: String? {
        guard let month = expirationMonth, let year = expirationYear else { return nil }
        return String(format: "%02d/%02d", month, year % 100)
    }

    /// Whether the card is expired
    var isExpired: Bool {
        guard let month = expirationMonth, let year = expirationYear else { return false }
        let now = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        return year < currentYear || (year == currentYear && month < currentMonth)
    }

    /// Whether the card expires within the given number of days
    var isExpiringSoon: Bool {
        guard let month = expirationMonth, let year = expirationYear else { return false }
        let calendar = Calendar.current
        // End of expiration month
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let expStart = calendar.date(from: components),
              let expEnd = calendar.date(byAdding: .month, value: 1, to: expStart) else { return false }
        let daysUntil = calendar.dateComponents([.day], from: Date(), to: expEnd).day ?? 0
        return daysUntil > 0 && daysUntil <= 60
    }

    /// Days until expiration (nil if no expiration set, negative if expired)
    var daysUntilExpiration: Int? {
        guard let month = expirationMonth, let year = expirationYear else { return nil }
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let expStart = calendar.date(from: components),
              let expEnd = calendar.date(byAdding: .month, value: 1, to: expStart) else { return nil }
        return calendar.dateComponents([.day], from: Date(), to: expEnd).day
    }
}

// MARK: - Card Network

enum CardNetwork: String, Codable, CaseIterable, Identifiable {
    case visa = "visa"
    case mastercard = "mastercard"
    case amex = "amex"
    case discover = "discover"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "American Express"
        case .discover: return "Discover"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .visa: return "creditcard"
        case .mastercard: return "creditcard.fill"
        case .amex: return "creditcard.trianglebadge.exclamationmark"
        case .discover: return "creditcard.and.123"
        case .other: return "creditcard"
        }
    }
}

// MARK: - Protocol Conformances

extension LinkedCard: Identifiable {}
