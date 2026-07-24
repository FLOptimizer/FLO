//  FLOMACRSDepreciationTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - MACRS depreciation engine tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - MACRS percentage tables sum to 100% (IRS Pub 946 Appendix A)
//  - 200% DB half-year schedules (3/5/7-year property)
//  - Straight-line half-year schedules
//  - Section 179 full and partial expensing
//  - Bonus depreciation (partial and 100%)
//  - Real property mid-month convention (27.5-year and 39-year)
//  - Accumulated depreciation / remaining basis columns
//  - Multi-asset yearly totals

import XCTest
@testable import FLO

final class FLOMACRSDepreciationTests: XCTestCase {

    let service = MACRSCalculationService.shared
    let precision: Double = 0.01

    // MARK: - Helpers

    /// A date in the given month/year, so placed-in-service month is deterministic.
    private func date(year: Int, month: Int, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    private func makeAsset(
        cost: Double,
        year: Int = 2025,
        month: Int = 6,
        propertyClass: PropertyClass = .fiveYear,
        method: DepreciationMethod = .macrs200DB,
        section179: Double? = nil,
        bonusPercent: Double? = nil
    ) -> DepreciableAsset {
        DepreciableAsset(
            name: "Test Asset",
            cost: cost,
            placedInServiceDate: date(year: year, month: month),
            propertyClass: propertyClass,
            depreciationMethod: method,
            section179Amount: section179,
            bonusDepreciationPercent: bonusPercent
        )
    }

    // MARK: - Table Integrity (IRS Pub 946)

    func testMACRSTables_EachSumsToOneHundredPercent() {
        let tables: [(String, [Double])] = [
            ("3-year 200DB", MACRSCalculationService.macrs3Year200DB),
            ("5-year 200DB", MACRSCalculationService.macrs5Year200DB),
            ("7-year 200DB", MACRSCalculationService.macrs7Year200DB),
            ("10-year 200DB", MACRSCalculationService.macrs10Year200DB),
            ("15-year 150DB", MACRSCalculationService.macrs15Year150DB),
            ("20-year 150DB", MACRSCalculationService.macrs20Year150DB)
        ]
        for (name, table) in tables {
            let sum = table.reduce(0, +)
            XCTAssertEqual(sum, 1.0, accuracy: 0.0005, "\(name) table should sum to 100%, got \(sum)")
        }
    }

    func testMACRSTables_HalfYearConventionRowCounts() {
        // Half-year convention spreads an N-year recovery over N+1 tax years
        XCTAssertEqual(MACRSCalculationService.macrs3Year200DB.count, 4)
        XCTAssertEqual(MACRSCalculationService.macrs5Year200DB.count, 6)
        XCTAssertEqual(MACRSCalculationService.macrs7Year200DB.count, 8)
        XCTAssertEqual(MACRSCalculationService.macrs10Year200DB.count, 11)
        XCTAssertEqual(MACRSCalculationService.macrs15Year150DB.count, 16)
        XCTAssertEqual(MACRSCalculationService.macrs20Year150DB.count, 21)
    }

    // MARK: - 5-Year 200% DB (IRS Table A-1)

    func testFiveYear200DB_TenThousandDollarAsset() {
        let asset = makeAsset(cost: 10_000, year: 2025)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 6)
        let expected: [Double] = [2_000, 3_200, 1_920, 1_152, 1_152, 576]
        for (index, expectedAmount) in expected.enumerated() {
            XCTAssertEqual(schedule[index].year, 2025 + index)
            XCTAssertEqual(schedule[index].amount, expectedAmount, accuracy: precision,
                           "Year \(2025 + index) depreciation")
        }
    }

    func testFiveYear200DB_FullyDepreciatesToZero() {
        let asset = makeAsset(cost: 10_000, year: 2025)
        let schedule = service.generateFullSchedule(for: asset)

        let total = schedule.reduce(0) { $0 + $1.amount }
        XCTAssertEqual(total, 10_000, accuracy: precision, "Total depreciation should equal cost")
        XCTAssertEqual(schedule.last!.remainingBasis, 0, accuracy: precision)
        XCTAssertEqual(schedule.last!.accumulatedDepreciation, 10_000, accuracy: precision)
    }

    func testThreeYear200DB_Schedule() {
        let asset = makeAsset(cost: 30_000, year: 2025, propertyClass: .threeYear)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 4)
        XCTAssertEqual(schedule[0].amount, 9_999, accuracy: precision)   // 33.33%
        XCTAssertEqual(schedule[1].amount, 13_335, accuracy: precision)  // 44.45%
        XCTAssertEqual(schedule[2].amount, 4_443, accuracy: precision)   // 14.81%
        XCTAssertEqual(schedule[3].amount, 2_223, accuracy: precision)   // 7.41%
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 30_000, accuracy: precision)
    }

    func testSevenYear200DB_FirstAndLastYear() {
        let asset = makeAsset(cost: 14_000, year: 2025, propertyClass: .sevenYear)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 8)
        XCTAssertEqual(schedule[0].amount, 2_000.60, accuracy: precision) // 14.29%
        XCTAssertEqual(schedule[7].amount, 624.40, accuracy: precision)   // 4.46%
    }

    // MARK: - Straight-Line

    func testStraightLine_FiveYear_HalfYearConvention() {
        let asset = makeAsset(cost: 10_000, year: 2025, method: .straightLine)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 6)
        XCTAssertEqual(schedule[0].amount, 1_000, accuracy: precision, "First year is half-year")
        XCTAssertEqual(schedule[1].amount, 2_000, accuracy: precision)
        XCTAssertEqual(schedule[5].amount, 1_000, accuracy: precision, "Last year is half-year")
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 10_000, accuracy: precision)
    }

    // MARK: - Section 179

    func testSection179_FullExpensing_SingleYearDeduction() {
        let asset = makeAsset(cost: 20_000, year: 2025, section179: 20_000)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 1, "Fully expensed asset has a single year-1 entry")
        XCTAssertEqual(schedule[0].year, 2025)
        XCTAssertEqual(schedule[0].amount, 20_000, accuracy: precision,
                       "Year-1 deduction must equal cost, not double it")
        XCTAssertEqual(schedule[0].remainingBasis, 0, accuracy: precision)
        XCTAssertEqual(schedule[0].accumulatedDepreciation, 20_000, accuracy: precision)
    }

    func testSection179_Partial_RemainderDepreciatesOnMACRS() {
        // $10,000 asset, $4,000 §179 → $6,000 MACRS base
        let asset = makeAsset(cost: 10_000, year: 2025, section179: 4_000)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 6)
        // Year 1: 6,000 × 20% + 4,000 §179 = 5,200
        XCTAssertEqual(schedule[0].amount, 5_200, accuracy: precision)
        // Year 2: 6,000 × 32% = 1,920
        XCTAssertEqual(schedule[1].amount, 1_920, accuracy: precision)
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 10_000, accuracy: precision)
        XCTAssertEqual(schedule.last!.remainingBasis, 0, accuracy: precision)
    }

    // MARK: - Bonus Depreciation

    func testBonusDepreciation_FortyPercent() {
        // $10,000 asset, 40% bonus → $4,000 bonus + $6,000 MACRS base
        let asset = makeAsset(cost: 10_000, year: 2025, bonusPercent: 0.40)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 6)
        // Year 1: 6,000 × 20% + 4,000 bonus = 5,200
        XCTAssertEqual(schedule[0].amount, 5_200, accuracy: precision)
        XCTAssertEqual(schedule[0].accumulatedDepreciation, 5_200, accuracy: precision,
                       "Accumulated must not double-count the bonus")
        XCTAssertEqual(schedule[0].remainingBasis, 4_800, accuracy: precision,
                       "Remaining basis must not double-subtract the bonus")
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 10_000, accuracy: precision)
        XCTAssertEqual(schedule.last!.remainingBasis, 0, accuracy: precision)
    }

    func testBonusDepreciation_HundredPercent_FullyExpensesYearOne() {
        let asset = makeAsset(cost: 5_000, year: 2025, bonusPercent: 1.0)
        let schedule = service.generateFullSchedule(for: asset)

        XCTAssertEqual(schedule.count, 1, "100% bonus should produce a single year-1 entry")
        XCTAssertEqual(schedule.first?.amount ?? 0, 5_000, accuracy: precision)
        XCTAssertEqual(service.calculateDepreciation(for: asset, year: 2025), 5_000, accuracy: precision)
    }

    func testSection179PlusBonus_Combined() {
        // $10,000 cost, $4,000 §179, 50% bonus on remaining $6,000 → $3,000 bonus, $3,000 base
        let asset = makeAsset(cost: 10_000, year: 2025, section179: 4_000, bonusPercent: 0.50)

        XCTAssertEqual(asset.firstYearBonus, 7_000, accuracy: precision)
        XCTAssertEqual(asset.depreciableBase, 3_000, accuracy: precision)

        let schedule = service.generateFullSchedule(for: asset)
        // Year 1: 3,000 × 20% + 7,000 = 7,600
        XCTAssertEqual(schedule[0].amount, 7_600, accuracy: precision)
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 10_000, accuracy: precision)
    }

    // MARK: - Real Property (Mid-Month Convention)

    func testNonresidential39Year_PlacedInJuly() {
        // $390,000 building placed in service July → 5.5 months of year-1 depreciation
        let asset = makeAsset(cost: 390_000, year: 2025, month: 7, propertyClass: .nonResidential)
        let schedule = service.generateFullSchedule(for: asset)

        let fullYearAmount = 390_000.0 / 39.0 // 10,000
        XCTAssertEqual(schedule[0].amount, fullYearAmount * 5.5 / 12.0, accuracy: precision,
                       "Year 1: mid-month July = 5.5 months")
        XCTAssertEqual(schedule[1].amount, fullYearAmount, accuracy: precision)
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 390_000, accuracy: 1.0,
                       "39-year schedule should depreciate the full cost")
    }

    func testResidential27HalfYear_DepreciatesFullBasis() {
        // $275,000 rental placed in service January
        let asset = makeAsset(cost: 275_000, year: 2025, month: 1, propertyClass: .residential)
        let schedule = service.generateFullSchedule(for: asset)

        let fullYearAmount = 275_000.0 / 27.5 // 10,000
        XCTAssertEqual(schedule[0].amount, fullYearAmount * 11.5 / 12.0, accuracy: precision,
                       "Year 1: mid-month January = 11.5 months")
        XCTAssertEqual(schedule[1].amount, fullYearAmount, accuracy: precision)
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 275_000, accuracy: 1.0,
                       "27.5-year schedule should depreciate the full cost, including the half year")
    }

    func testResidential_PlacedInDecember_SmallFirstYear() {
        let asset = makeAsset(cost: 275_000, year: 2025, month: 12, propertyClass: .residential)
        let schedule = service.generateFullSchedule(for: asset)

        // December: 0.5 months of depreciation in year 1
        XCTAssertEqual(schedule[0].amount, (275_000.0 / 27.5) * 0.5 / 12.0, accuracy: precision)
        XCTAssertEqual(schedule.reduce(0) { $0 + $1.amount }, 275_000, accuracy: 1.0)
    }

    // MARK: - Year Lookups & Multi-Asset Totals

    func testCalculateDepreciation_YearOutsideSchedule_ReturnsZero() {
        let asset = makeAsset(cost: 10_000, year: 2025)
        XCTAssertEqual(service.calculateDepreciation(for: asset, year: 2024), 0)
        XCTAssertEqual(service.calculateDepreciation(for: asset, year: 2031), 0)
        XCTAssertEqual(service.calculateDepreciation(for: asset, year: 2026), 3_200, accuracy: precision)
    }

    func testTotalDepreciationForYear_SumsAcrossAssets() {
        let tractor = makeAsset(cost: 10_000, year: 2025)                          // yr1: 2,000
        let mower = makeAsset(cost: 5_000, year: 2025, propertyClass: .sevenYear)  // yr1: 714.50
        let total = service.totalDepreciationForYear(2025, assets: [tractor, mower])
        XCTAssertEqual(total, 2_000 + 714.50, accuracy: precision)
    }

    func testAsset_AccumulatedDepreciationAndNetBookValue() {
        let asset = makeAsset(cost: 10_000, year: 2025)
        XCTAssertEqual(asset.accumulatedDepreciation(throughYear: 2026), 5_200, accuracy: precision)
        XCTAssertEqual(asset.netBookValue(atEndOfYear: 2026), 4_800, accuracy: precision)
        XCTAssertEqual(asset.netBookValue(atEndOfYear: 2030), 0, accuracy: precision)
    }

    func testDepreciableBase_ZeroCostAsset_EmptySchedule() {
        let asset = makeAsset(cost: 0, year: 2025)
        XCTAssertTrue(service.generateFullSchedule(for: asset).isEmpty)
        XCTAssertEqual(service.calculateDepreciation(for: asset, year: 2025), 0)
    }
}
