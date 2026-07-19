//  DepreciableAsset.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Asset depreciation tracking with MACRS support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks depreciable business assets (equipment, vehicles, buildings) with
//  IRS-compliant MACRS depreciation schedules. Integrates with tax summary
//  views and the Tax Handoff PDF for CPA preparation.
//

import Foundation
import SwiftData

// MARK: - Supporting Enums

/// IRS depreciation method.
enum DepreciationMethod: String, Codable, CaseIterable, Identifiable {
    case macrs200DB   = "macrs200DB"    // 200% Declining Balance (GDS default)
    case macrs150DB   = "macrs150DB"    // 150% Declining Balance (farm equipment, ADS)
    case straightLine = "straightLine"  // Straight-line (ADS, real property)
    case section179   = "section179"    // Full immediate expensing under §179

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .macrs200DB:   return "MACRS 200% DB"
        case .macrs150DB:   return "MACRS 150% DB"
        case .straightLine: return "Straight-Line"
        case .section179:   return "Section 179"
        }
    }

    var shortName: String {
        switch self {
        case .macrs200DB:   return "200DB"
        case .macrs150DB:   return "150DB"
        case .straightLine: return "SL"
        case .section179:   return "§179"
        }
    }
}

/// IRS depreciation convention (determines first/last year treatment).
enum DepreciationConvention: String, Codable, CaseIterable, Identifiable {
    case halfYear   = "halfYear"    // Most personal property
    case midQuarter = "midQuarter"  // When >40% placed in service in Q4
    case midMonth   = "midMonth"    // Real property (buildings)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .halfYear:   return "Half-Year"
        case .midQuarter: return "Mid-Quarter"
        case .midMonth:   return "Mid-Month"
        }
    }
}

/// MACRS property class (recovery period).
enum PropertyClass: String, Codable, CaseIterable, Identifiable {
    case threeYear    = "3"
    case fiveYear     = "5"
    case sevenYear    = "7"
    case tenYear      = "10"
    case fifteenYear  = "15"
    case twentyYear   = "20"
    case residential  = "27.5"   // Residential rental property
    case nonResidential = "39"   // Commercial buildings

    var id: String { rawValue }

    var years: Double {
        switch self {
        case .threeYear:      return 3
        case .fiveYear:       return 5
        case .sevenYear:      return 7
        case .tenYear:        return 10
        case .fifteenYear:    return 15
        case .twentyYear:     return 20
        case .residential:    return 27.5
        case .nonResidential: return 39
        }
    }

    /// Number of depreciation periods (years with non-zero depreciation).
    /// MACRS half-year convention adds 1 year to recovery period.
    var depreciationYears: Int {
        switch self {
        case .threeYear:      return 4
        case .fiveYear:       return 6
        case .sevenYear:      return 8
        case .tenYear:        return 11
        case .fifteenYear:    return 16
        case .twentyYear:     return 21
        case .residential:    return 28
        case .nonResidential: return 40
        }
    }

    var displayName: String {
        switch self {
        case .threeYear:      return "3-Year Property"
        case .fiveYear:       return "5-Year Property"
        case .sevenYear:      return "7-Year Property"
        case .tenYear:        return "10-Year Property"
        case .fifteenYear:    return "15-Year Property"
        case .twentyYear:     return "20-Year Property"
        case .residential:    return "Residential Rental (27.5 yr)"
        case .nonResidential: return "Nonresidential Real Property (39 yr)"
        }
    }

    /// Common assets in this class.
    var examples: String {
        switch self {
        case .threeYear:      return "Tractor units, racehorses, qualified rent-to-own property"
        case .fiveYear:       return "Cars, trucks, computers, office equipment, farm equipment (post-2017)"
        case .sevenYear:      return "Office furniture, fixtures, most machinery"
        case .tenYear:        return "Vessels, barges, single-purpose agricultural structures"
        case .fifteenYear:    return "Land improvements, fencing, roads, bridges"
        case .twentyYear:     return "Farm buildings, municipal sewers"
        case .residential:    return "Rental houses, apartments"
        case .nonResidential: return "Commercial buildings, warehouses, offices"
        }
    }
}

// MARK: - Yearly Depreciation Result

/// A single year's depreciation calculation result.
struct YearlyDepreciation: Identifiable {
    let id = UUID()
    let year: Int
    let amount: Double
    let accumulatedDepreciation: Double
    let remainingBasis: Double
}

// MARK: - Depreciable Asset Model

@Model
final class DepreciableAsset {

    // MARK: - Properties

    /// Unique identifier
    var id: UUID = UUID()

    /// Asset name (e.g., "Bad Boy 3026HILB Tractor")
    var name: String = ""

    /// Detailed description or notes
    var assetDescription: String?

    /// Original cost basis
    var cost: Double = 0.0

    /// Estimated salvage/residual value (usually 0 for MACRS)
    var salvageValue: Double = 0.0

    /// Date the asset was placed in service
    var placedInServiceDate: Date = Date()

    /// Date the asset was disposed of or sold (nil if still active)
    var disposedDate: Date?

    /// Raw backing for depreciation method enum
    var depreciationMethodRaw: String = DepreciationMethod.macrs200DB.rawValue

    /// Raw backing for convention enum
    var conventionRaw: String = DepreciationConvention.halfYear.rawValue

    /// Raw backing for property class enum
    var propertyClassRaw: String = PropertyClass.fiveYear.rawValue

    /// Section 179 immediate expensing amount (if elected)
    var section179Amount: Double?

    /// Bonus depreciation percentage (e.g., 0.40 for 40% in 2026)
    var bonusDepreciationPercent: Double?

    /// Serial number or identification number
    var serialNumber: String?

    /// Whether this asset is currently active (not disposed)
    var isActive: Bool = true

    /// Date this record was created
    var createdAt: Date = Date()

    // MARK: - Relationships

    /// The business this asset belongs to
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    // MARK: - Typed Accessors

    var depreciationMethod: DepreciationMethod {
        get { DepreciationMethod(rawValue: depreciationMethodRaw) ?? .macrs200DB }
        set { depreciationMethodRaw = newValue.rawValue }
    }

    var convention: DepreciationConvention {
        get { DepreciationConvention(rawValue: conventionRaw) ?? .halfYear }
        set { conventionRaw = newValue.rawValue }
    }

    var propertyClass: PropertyClass {
        get { PropertyClass(rawValue: propertyClassRaw) ?? .fiveYear }
        set { propertyClassRaw = newValue.rawValue }
    }

    // MARK: - Computed Properties

    /// Cost minus Section 179 and bonus depreciation = MACRS depreciable base
    var depreciableBase: Double {
        let s179 = section179Amount ?? 0
        let bonus = (bonusDepreciationPercent ?? 0) * (cost - s179)
        return cost - s179 - bonus
    }

    /// Total first-year deduction (Section 179 + bonus)
    var firstYearBonus: Double {
        let s179 = section179Amount ?? 0
        let bonus = (bonusDepreciationPercent ?? 0) * (cost - s179)
        return s179 + bonus
    }

    /// The tax year the asset was placed in service
    var placedInServiceYear: Int {
        Calendar.current.component(.year, from: placedInServiceDate)
    }

    /// Recovery period in years based on property class
    var recoveryPeriodYears: Double {
        propertyClass.years
    }

    /// Depreciation for a specific tax year
    func depreciationForYear(_ taxYear: Int) -> Double {
        MACRSCalculationService.shared.calculateDepreciation(for: self, year: taxYear)
    }

    /// Full depreciation schedule
    func fullSchedule() -> [YearlyDepreciation] {
        MACRSCalculationService.shared.generateFullSchedule(for: self)
    }

    /// Accumulated depreciation through end of given year
    func accumulatedDepreciation(throughYear year: Int) -> Double {
        let schedule = fullSchedule()
        return schedule
            .filter { $0.year <= year }
            .reduce(0) { $0 + $1.amount }
    }

    /// Net book value at end of given year
    func netBookValue(atEndOfYear year: Int) -> Double {
        cost - accumulatedDepreciation(throughYear: year)
    }

    // MARK: - Initialization

    init(
        name: String,
        cost: Double,
        placedInServiceDate: Date,
        propertyClass: PropertyClass = .fiveYear,
        depreciationMethod: DepreciationMethod = .macrs200DB,
        convention: DepreciationConvention = .halfYear,
        section179Amount: Double? = nil,
        bonusDepreciationPercent: Double? = nil,
        serialNumber: String? = nil,
        assetDescription: String? = nil,
        businessProfile: BusinessProfile? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.cost = cost
        self.placedInServiceDate = placedInServiceDate
        self.propertyClassRaw = propertyClass.rawValue
        self.depreciationMethodRaw = depreciationMethod.rawValue
        self.conventionRaw = convention.rawValue
        self.section179Amount = section179Amount
        self.bonusDepreciationPercent = bonusDepreciationPercent
        self.serialNumber = serialNumber
        self.assetDescription = assetDescription
        self.businessProfile = businessProfile
        self.createdAt = Date()
    }
}

// MARK: - Protocol Conformances

extension DepreciableAsset: Identifiable { }

extension DepreciableAsset: Equatable {
    static func == (lhs: DepreciableAsset, rhs: DepreciableAsset) -> Bool {
        lhs.id == rhs.id
    }
}

extension DepreciableAsset: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
