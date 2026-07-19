//  EntityJurisdiction.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Manual jurisdiction tagging for business entities
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks filing jurisdictions (state, county, city) for each business.
//  Phase 2 v1: manual tagging; Phase 3 will add auto-detection from address.
//

import Foundation
import SwiftData

@Model
final class EntityJurisdiction {
    // MARK: - Properties

    var id: UUID = UUID()

    /// Jurisdiction level (state, county, city, local)
    var levelRaw: String = JurisdictionLevel.state.rawValue

    /// Jurisdiction name (e.g., "Kentucky", "Fayette County", "Lexington")
    var name: String = ""

    /// State abbreviation (e.g., "KY") — always present even for sub-state jurisdictions
    var stateCode: String = ""

    /// Whether a separate filing is required for this jurisdiction
    var requiresFiling: Bool = true

    /// Filing deadline description (e.g., "April 15", "April 30")
    var deadlineDescription: String?

    /// Tax type (income, franchise, gross receipts, occupational, etc.)
    var taxTypeRaw: String = JurisdictionTaxType.income.rawValue

    /// Estimated tax rate for this jurisdiction (for reference)
    var estimatedRate: Double?

    /// Filing form name/number (e.g., "KY 765", "LMFT Net Profit")
    var formName: String?

    /// User notes
    var notes: String?

    /// Whether this jurisdiction is active (soft delete)
    var isActive: Bool = true

    var createdAt: Date = Date()

    // MARK: - Relationship

    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    // MARK: - Computed Properties

    var level: JurisdictionLevel {
        get { JurisdictionLevel(rawValue: levelRaw) ?? .state }
        set { levelRaw = newValue.rawValue }
    }

    var taxType: JurisdictionTaxType {
        get { JurisdictionTaxType(rawValue: taxTypeRaw) ?? .income }
        set { taxTypeRaw = newValue.rawValue }
    }

    var displayName: String {
        switch level {
        case .state:  return name
        case .county: return "\(name) (\(stateCode))"
        case .city:   return "\(name), \(stateCode)"
        case .local:  return "\(name) (\(stateCode))"
        }
    }

    var filingDescription: String {
        var parts: [String] = [taxType.displayName]
        if let form = formName {
            parts.append(form)
        }
        if let deadline = deadlineDescription {
            parts.append("due \(deadline)")
        }
        return parts.joined(separator: " — ")
    }

    // MARK: - Init

    init(
        level: JurisdictionLevel = .state,
        name: String,
        stateCode: String,
        requiresFiling: Bool = true,
        taxType: JurisdictionTaxType = .income,
        deadlineDescription: String? = nil,
        estimatedRate: Double? = nil,
        formName: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.levelRaw = level.rawValue
        self.name = name
        self.stateCode = stateCode
        self.requiresFiling = requiresFiling
        self.taxTypeRaw = taxType.rawValue
        self.deadlineDescription = deadlineDescription
        self.estimatedRate = estimatedRate
        self.formName = formName
        self.notes = notes
        self.createdAt = Date()
    }
}

// MARK: - Enums

enum JurisdictionLevel: String, CaseIterable, Codable {
    case state  = "state"
    case county = "county"
    case city   = "city"
    case local  = "local"

    var displayName: String {
        switch self {
        case .state:  return "State"
        case .county: return "County"
        case .city:   return "City"
        case .local:  return "Local/District"
        }
    }

    var icon: String {
        switch self {
        case .state:  return "flag.fill"
        case .county: return "map.fill"
        case .city:   return "building.2.fill"
        case .local:  return "mappin.circle.fill"
        }
    }
}

enum JurisdictionTaxType: String, CaseIterable, Codable {
    case income         = "income"
    case franchise      = "franchise"
    case grossReceipts  = "grossReceipts"
    case occupational   = "occupational"
    case propertyTax    = "propertyTax"
    case salesTax       = "salesTax"
    case other          = "other"

    var displayName: String {
        switch self {
        case .income:        return "Income Tax"
        case .franchise:     return "Franchise Tax"
        case .grossReceipts: return "Gross Receipts Tax"
        case .occupational:  return "Occupational/Net Profit Tax"
        case .propertyTax:   return "Property Tax"
        case .salesTax:      return "Sales Tax"
        case .other:         return "Other"
        }
    }
}

// MARK: - Protocol Conformances

extension EntityJurisdiction: Identifiable { }
