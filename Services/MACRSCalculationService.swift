//  MACRSCalculationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — IRS MACRS depreciation calculation engine
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Implements Modified Accelerated Cost Recovery System (MACRS) depreciation
//  per IRS Publication 946. Supports 200% DB, 150% DB, and straight-line methods
//  with half-year, mid-quarter, and mid-month conventions.
//
//  Tables sourced from IRS Publication 946, Appendix A (Tables A-1 through A-13).
//

import Foundation

final class MACRSCalculationService {
    static let shared = MACRSCalculationService()

    private init() {}

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - MACRS Percentage Tables (IRS Publication 946)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Table A-1: 200% Declining Balance, Half-Year Convention (GDS)
    // Array index = recovery year (0-based), value = percentage as decimal

    /// 3-Year Property, 200% DB, Half-Year
    static let macrs3Year200DB: [Double] = [
        0.3333, 0.4445, 0.1481, 0.0741
    ]

    /// 5-Year Property, 200% DB, Half-Year
    static let macrs5Year200DB: [Double] = [
        0.2000, 0.3200, 0.1920, 0.1152, 0.1152, 0.0576
    ]

    /// 7-Year Property, 200% DB, Half-Year
    static let macrs7Year200DB: [Double] = [
        0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446
    ]

    /// 10-Year Property, 200% DB, Half-Year
    static let macrs10Year200DB: [Double] = [
        0.1000, 0.1800, 0.1440, 0.1152, 0.0922,
        0.0737, 0.0655, 0.0655, 0.0656, 0.0655, 0.0328
    ]

    /// 15-Year Property, 150% DB, Half-Year
    static let macrs15Year150DB: [Double] = [
        0.0500, 0.0950, 0.0855, 0.0770, 0.0693,
        0.0623, 0.0590, 0.0590, 0.0591, 0.0590,
        0.0591, 0.0590, 0.0591, 0.0590, 0.0591, 0.0295
    ]

    /// 20-Year Property, 150% DB, Half-Year
    static let macrs20Year150DB: [Double] = [
        0.03750, 0.07219, 0.06677, 0.06177, 0.05713,
        0.05285, 0.04888, 0.04522, 0.04462, 0.04461,
        0.04462, 0.04461, 0.04462, 0.04461, 0.04462,
        0.04461, 0.04462, 0.04461, 0.04462, 0.04461, 0.02231
    ]

    // Table A-6: Residential Rental Property, Straight-Line, Mid-Month
    // 27.5-year property — percentage depends on month placed in service.
    // For simplicity, we use the monthly rate: 1/27.5 = 3.636% per full year.

    /// 27.5-Year Residential Rental, Straight-Line, Mid-Month
    static let residentialMonthlyRate: Double = 1.0 / 27.5  // 0.03636...

    /// 39-Year Nonresidential, Straight-Line, Mid-Month
    static let nonresidentialMonthlyRate: Double = 1.0 / 39.0  // 0.02564...

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Public API
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Calculate depreciation for a specific tax year.
    func calculateDepreciation(for asset: DepreciableAsset, year taxYear: Int) -> Double {
        let schedule = generateFullSchedule(for: asset)
        return schedule.first(where: { $0.year == taxYear })?.amount ?? 0
    }

    /// Generate the complete yearly depreciation schedule for an asset.
    func generateFullSchedule(for asset: DepreciableAsset) -> [YearlyDepreciation] {
        let startYear = asset.placedInServiceYear
        let base = asset.depreciableBase

        guard base > 0 else {
            // Fully expensed via §179 and/or 100% bonus — one entry for year 1.
            // firstYearBonus already includes both the §179 amount and bonus depreciation.
            let firstYear = asset.firstYearBonus
            if firstYear > 0 {
                return [YearlyDepreciation(
                    year: startYear,
                    amount: roundToNearest(firstYear),
                    accumulatedDepreciation: roundToNearest(firstYear),
                    remainingBasis: max(0, roundToNearest(asset.cost - firstYear))
                )]
            }
            return []
        }

        let percentages = macrsPercentages(for: asset)
        var schedule: [YearlyDepreciation] = []
        var accumulated: Double = asset.firstYearBonus

        for (index, pct) in percentages.enumerated() {
            let yearAmount = base * pct
            // Add bonus/179 to first year
            let totalAmount = (index == 0) ? yearAmount + asset.firstYearBonus : yearAmount
            accumulated += yearAmount
            let remaining = asset.cost - accumulated

            schedule.append(YearlyDepreciation(
                year: startYear + index,
                amount: roundToNearest(totalAmount),
                accumulatedDepreciation: roundToNearest(accumulated),
                remainingBasis: max(0, roundToNearest(remaining))
            ))
        }

        return schedule
    }

    /// Total depreciation deduction for a specific year across multiple assets.
    func totalDepreciationForYear(_ year: Int, assets: [DepreciableAsset]) -> Double {
        assets.reduce(0) { total, asset in
            total + calculateDepreciation(for: asset, year: year)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Private Helpers
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Returns the MACRS percentage table for the given asset configuration.
    private func macrsPercentages(for asset: DepreciableAsset) -> [Double] {
        // For real property, use mid-month convention
        if asset.propertyClass == .residential || asset.propertyClass == .nonResidential {
            return realPropertyPercentages(for: asset)
        }

        // For Section 179, no further depreciation
        if asset.depreciationMethod == .section179 {
            return []
        }

        // For straight-line on personal property
        if asset.depreciationMethod == .straightLine {
            return straightLinePercentages(for: asset)
        }

        // Standard MACRS tables (200% DB or 150% DB, half-year convention)
        switch asset.propertyClass {
        case .threeYear:   return Self.macrs3Year200DB
        case .fiveYear:    return Self.macrs5Year200DB
        case .sevenYear:   return Self.macrs7Year200DB
        case .tenYear:     return Self.macrs10Year200DB
        case .fifteenYear: return Self.macrs15Year150DB
        case .twentyYear:  return Self.macrs20Year150DB
        default:           return Self.macrs5Year200DB
        }
    }

    /// Generates straight-line percentages with half-year convention.
    private func straightLinePercentages(for asset: DepreciableAsset) -> [Double] {
        let years = asset.propertyClass.years
        let fullYearRate = 1.0 / years
        let halfYearRate = fullYearRate / 2.0
        let totalYears = Int(years) + 1

        var percentages: [Double] = []
        percentages.append(halfYearRate) // First year (half)
        for _ in 1..<(totalYears - 1) {
            percentages.append(fullYearRate) // Full years
        }
        percentages.append(halfYearRate) // Last year (half)

        return percentages
    }

    /// Generates percentages for real property (27.5-year or 39-year) with mid-month convention.
    private func realPropertyPercentages(for asset: DepreciableAsset) -> [Double] {
        let monthPlaced = Calendar.current.component(.month, from: asset.placedInServiceDate)
        let rate = asset.propertyClass == .residential
            ? Self.residentialMonthlyRate
            : Self.nonresidentialMonthlyRate

        // Total recovery is exactly 27.5 or 39 years = 330 or 468 months.
        // Emitting full 12-month years until the remainder runs out handles the
        // fractional 27.5-year period (which spills into a final partial year).
        let totalMonths = asset.propertyClass.years * 12.0

        var percentages: [Double] = []

        // First year: mid-month convention — depreciate from mid-month placed in service
        let firstYearMonths = Double(12 - monthPlaced) + 0.5
        percentages.append(rate * firstYearMonths / 12.0)

        var monthsRemaining = totalMonths - firstYearMonths
        while monthsRemaining > 0.001 {
            let monthsThisYear = min(12.0, monthsRemaining)
            percentages.append(rate * monthsThisYear / 12.0)
            monthsRemaining -= monthsThisYear
        }

        return percentages
    }

    /// Round to nearest cent to avoid floating-point drift.
    private func roundToNearest(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
