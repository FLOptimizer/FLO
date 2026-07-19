//  TaxCarryforward.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Carryforward register for multi-year tax items
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks tax items that carry forward across years: suspended losses,
//  NOL carryforwards, remaining depreciation, amortization schedules,
//  inventory carry, and more. Used in the Tax Handoff PDF and Tax Summary views.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Carryforward Type

/// Types of tax items that carry forward between years.
enum CarryforwardType: String, Codable, CaseIterable, Identifiable {
    case suspendedLoss704d     = "suspendedLoss704d"
    case netOperatingLoss      = "netOperatingLoss"
    case depreciationRemaining = "depreciationRemaining"
    case amortization          = "amortization"
    case capitalLoss           = "capitalLoss"
    case section179Carryover   = "section179Carryover"
    case passiveActivityLoss   = "passiveActivityLoss"
    case inventoryCarry        = "inventoryCarry"
    case charitableContribution = "charitableContribution"
    case other                 = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .suspendedLoss704d:      return "Suspended Loss (§704(d))"
        case .netOperatingLoss:       return "Net Operating Loss"
        case .depreciationRemaining:  return "Remaining Depreciation"
        case .amortization:           return "Amortization"
        case .capitalLoss:            return "Capital Loss Carryforward"
        case .section179Carryover:    return "Section 179 Carryover"
        case .passiveActivityLoss:    return "Passive Activity Loss"
        case .inventoryCarry:         return "Inventory Carry"
        case .charitableContribution: return "Charitable Contribution"
        case .other:                  return "Other Carryforward"
        }
    }

    var icon: String {
        switch self {
        case .suspendedLoss704d:      return "pause.circle.fill"
        case .netOperatingLoss:       return "arrow.uturn.forward.circle.fill"
        case .depreciationRemaining:  return "chart.bar.fill"
        case .amortization:           return "calendar.badge.clock"
        case .capitalLoss:            return "chart.line.downtrend.xyaxis"
        case .section179Carryover:    return "dollarsign.arrow.circlepath"
        case .passiveActivityLoss:    return "house.lodge.fill"
        case .inventoryCarry:         return "shippingbox.fill"
        case .charitableContribution: return "heart.fill"
        case .other:                  return "doc.text.fill"
        }
    }

    var color: Color {
        switch self {
        case .suspendedLoss704d:      return Color(flowHex: "#EF4444") // Red
        case .netOperatingLoss:       return Color(flowHex: "#F97316") // Orange
        case .depreciationRemaining:  return Color(flowHex: "#14B8A6") // Teal
        case .amortization:           return Color(flowHex: "#8B5CF6") // Purple
        case .capitalLoss:            return Color(flowHex: "#EF4444") // Red
        case .section179Carryover:    return Color(flowHex: "#3B82F6") // Blue
        case .passiveActivityLoss:    return Color(flowHex: "#F59E0B") // Amber
        case .inventoryCarry:         return Color(flowHex: "#22C55E") // Green
        case .charitableContribution: return Color(flowHex: "#EC4899") // Pink
        case .other:                  return Color(flowHex: "#64748B") // Slate
        }
    }

    /// IRC section reference for the carryforward rule
    var ircReference: String {
        switch self {
        case .suspendedLoss704d:      return "IRC §704(d)"
        case .netOperatingLoss:       return "IRC §172"
        case .depreciationRemaining:  return "IRC §168"
        case .amortization:           return "IRC §197"
        case .capitalLoss:            return "IRC §1212"
        case .section179Carryover:    return "IRC §179"
        case .passiveActivityLoss:    return "IRC §469"
        case .inventoryCarry:         return "IRC §471"
        case .charitableContribution: return "IRC §170"
        case .other:                  return ""
        }
    }

    /// Brief explanation of the carryforward rule
    var explanation: String {
        switch self {
        case .suspendedLoss704d:
            return "Partner's share of loss exceeds outside basis. Carries forward indefinitely until basis is restored through capital contributions or debt allocation."
        case .netOperatingLoss:
            return "Business losses exceeding income. Post-2017 NOLs carry forward indefinitely but limited to 80% of taxable income."
        case .depreciationRemaining:
            return "Remaining cost basis to be depreciated over the asset's recovery period."
        case .amortization:
            return "Intangible asset costs (startup costs, loan origination fees) spread over the applicable period."
        case .capitalLoss:
            return "Capital losses exceeding gains. Individuals may deduct up to $3,000/year; remainder carries forward."
        case .section179Carryover:
            return "Section 179 deduction exceeding the business income limitation. Carries forward indefinitely."
        case .passiveActivityLoss:
            return "Losses from passive activities exceeding passive income. Carries forward until offset by passive income or complete disposition."
        case .inventoryCarry:
            return "Ending inventory becomes beginning inventory for the next tax year."
        case .charitableContribution:
            return "Charitable contributions exceeding the AGI percentage limitation. Carries forward up to 5 years."
        case .other:
            return "Other tax item carrying forward to future years."
        }
    }
}

// MARK: - Carryforward Status

enum CarryforwardStatus: String, Codable, CaseIterable {
    case active             = "active"
    case partiallyUtilized  = "partiallyUtilized"
    case fullyUtilized      = "fullyUtilized"
    case expired            = "expired"

    var displayName: String {
        switch self {
        case .active:            return "Active"
        case .partiallyUtilized: return "Partially Used"
        case .fullyUtilized:     return "Fully Used"
        case .expired:           return "Expired"
        }
    }

    var color: Color {
        switch self {
        case .active:            return Color(flowHex: "#22C55E") // Green
        case .partiallyUtilized: return Color(flowHex: "#F59E0B") // Amber
        case .fullyUtilized:     return Color(flowHex: "#64748B") // Slate
        case .expired:           return Color(flowHex: "#EF4444") // Red
        }
    }
}

// MARK: - Tax Carryforward Model

@Model
final class TaxCarryforward {

    // MARK: - Properties

    /// Unique identifier
    var id: UUID = UUID()

    /// Raw backing for carryforward type enum
    var typeRaw: String = CarryforwardType.other.rawValue

    /// The tax year this carryforward originated
    var originYear: Int = 2025

    /// Original amount of the carryforward
    var originalAmount: Double = 0.0

    /// Amount remaining to be utilized
    var remainingAmount: Double = 0.0

    /// Raw backing for status enum
    var statusRaw: String = CarryforwardStatus.active.rawValue

    /// Year the carryforward expires (nil = no expiration)
    var expirationYear: Int?

    /// User-entered notes or action items
    var notes: String?

    /// Last time this record was updated
    var lastUpdated: Date = Date()

    /// Date this record was created
    var createdAt: Date = Date()

    /// For partner-specific items: which partner this applies to
    var partnerName: String?

    // MARK: - Relationships

    /// The business this carryforward belongs to
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    // MARK: - Typed Accessors

    var type: CarryforwardType {
        get { CarryforwardType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var status: CarryforwardStatus {
        get { CarryforwardStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    // MARK: - Computed Properties

    /// Whether this carryforward still has remaining value
    var isActive: Bool {
        status == .active || status == .partiallyUtilized
    }

    /// Amount that has been utilized
    var amountUtilized: Double {
        originalAmount - remainingAmount
    }

    /// Utilization percentage (0.0–1.0)
    var utilizationPercentage: Double {
        guard originalAmount > 0 else { return 0 }
        return amountUtilized / originalAmount
    }

    /// Whether this item has an expiration date
    var canExpire: Bool {
        expirationYear != nil
    }

    /// Whether this item has expired based on the current year
    var isExpired: Bool {
        guard let expYear = expirationYear else { return false }
        return Calendar.current.component(.year, from: Date()) > expYear
    }

    /// Formatted display: "($3,115) — Suspended Loss (§704(d))"
    var displaySummary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let amountStr = formatter.string(from: NSNumber(value: remainingAmount)) ?? "$0"
        return "\(amountStr) — \(type.displayName)"
    }

    // MARK: - Methods

    /// Record utilization of part or all of this carryforward
    func utilize(amount: Double) {
        let utilized = min(amount, remainingAmount)
        remainingAmount -= utilized
        lastUpdated = Date()

        if remainingAmount <= 0 {
            remainingAmount = 0
            status = .fullyUtilized
        } else {
            status = .partiallyUtilized
        }
    }

    /// Mark as expired
    func markExpired() {
        status = .expired
        lastUpdated = Date()
    }

    // MARK: - Initialization

    init(
        type: CarryforwardType,
        originYear: Int,
        originalAmount: Double,
        remainingAmount: Double? = nil,
        expirationYear: Int? = nil,
        notes: String? = nil,
        partnerName: String? = nil,
        businessProfile: BusinessProfile? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.originYear = originYear
        self.originalAmount = originalAmount
        self.remainingAmount = remainingAmount ?? originalAmount
        self.statusRaw = CarryforwardStatus.active.rawValue
        self.expirationYear = expirationYear
        self.notes = notes
        self.partnerName = partnerName
        self.businessProfile = businessProfile
        self.lastUpdated = Date()
        self.createdAt = Date()
    }
}

// MARK: - Protocol Conformances

extension TaxCarryforward: Identifiable { }

extension TaxCarryforward: Equatable {
    static func == (lhs: TaxCarryforward, rhs: TaxCarryforward) -> Bool {
        lhs.id == rhs.id
    }
}

extension TaxCarryforward: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
