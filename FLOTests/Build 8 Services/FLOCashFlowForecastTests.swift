//  FLOCashFlowForecastTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - CashFlowForecastService Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate cash flow forecasting data structures, forecast result
//  computed properties, danger zone detection, and horizon configuration.
//
//  COVERS:
//  - ForecastHorizon enum (display names, raw values, CaseIterable)
//  - ForecastResult computed properties (trending, net change, formatting)
//  - DangerZone duration calculation
//  - UpcomingBill formatting
//  - DailyBalancePoint properties
//  - Edge cases (empty forecasts, negative balances)

import XCTest
@testable import FLO

final class FLOCashFlowForecastTests: XCTestCase {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeDate(year: Int = 2026, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func makeForecast(
        startingBalance: Double = 5000,
        endBalance: Double = 4000,
        lowestBalance: Double = 2000,
        lowestDate: Date? = nil,
        dangerZones: [DangerZone] = [],
        upcomingBills: [UpcomingBill] = [],
        horizon: ForecastHorizon = .threeMonths
    ) -> ForecastResult {
        let today = calendar.startOfDay(for: Date.now)
        return ForecastResult(
            dailyBalances: [
                DailyBalancePoint(
                    date: today,
                    projectedBalance: startingBalance,
                    isHistorical: false,
                    recurringIncome: 0,
                    recurringExpenses: 0,
                    variableSpending: 0
                ),
                DailyBalancePoint(
                    date: calendar.date(byAdding: .day, value: 1, to: today)!,
                    projectedBalance: endBalance,
                    isHistorical: false,
                    recurringIncome: 0,
                    recurringExpenses: 0,
                    variableSpending: 0
                )
            ],
            upcomingBills: upcomingBills,
            dangerZones: dangerZones,
            projectedEndBalance: endBalance,
            lowestProjectedBalance: lowestBalance,
            lowestBalanceDate: lowestDate,
            startingBalance: startingBalance,
            horizon: horizon
        )
    }
}

// MARK: - ForecastHorizon Enum

extension FLOCashFlowForecastTests {

    func testHorizon_RawValues() {
        XCTAssertEqual(ForecastHorizon.oneMonth.rawValue, 1)
        XCTAssertEqual(ForecastHorizon.threeMonths.rawValue, 3)
        XCTAssertEqual(ForecastHorizon.sixMonths.rawValue, 6)
        XCTAssertEqual(ForecastHorizon.twelveMonths.rawValue, 12)
    }

    func testHorizon_DisplayNames() {
        XCTAssertEqual(ForecastHorizon.oneMonth.displayName, "1M")
        XCTAssertEqual(ForecastHorizon.threeMonths.displayName, "3M")
        XCTAssertEqual(ForecastHorizon.sixMonths.displayName, "6M")
        XCTAssertEqual(ForecastHorizon.twelveMonths.displayName, "1Y")
    }

    func testHorizon_FullDisplayNames() {
        XCTAssertEqual(ForecastHorizon.oneMonth.fullDisplayName, "1 Month")
        XCTAssertEqual(ForecastHorizon.threeMonths.fullDisplayName, "3 Months")
        XCTAssertEqual(ForecastHorizon.sixMonths.fullDisplayName, "6 Months")
        XCTAssertEqual(ForecastHorizon.twelveMonths.fullDisplayName, "12 Months")
    }

    func testHorizon_AllCases() {
        XCTAssertEqual(ForecastHorizon.allCases.count, 4)
    }

    func testHorizon_Identifiable() {
        // Each horizon should have unique ID
        let ids = ForecastHorizon.allCases.map { $0.id }
        XCTAssertEqual(Set(ids).count, ids.count, "All horizon IDs should be unique")
    }
}

// MARK: - ForecastResult Properties

extension FLOCashFlowForecastTests {

    func testForecast_TrendingUp_WhenEndHigher() {
        let forecast = makeForecast(startingBalance: 1000, endBalance: 2000)
        XCTAssertTrue(forecast.isTrendingUp)
    }

    func testForecast_TrendingDown_WhenEndLower() {
        let forecast = makeForecast(startingBalance: 5000, endBalance: 3000)
        XCTAssertFalse(forecast.isTrendingUp)
    }

    func testForecast_NetChange_Positive() {
        let forecast = makeForecast(startingBalance: 1000, endBalance: 1500)
        XCTAssertEqual(forecast.netChange, 500, accuracy: 0.01)
    }

    func testForecast_NetChange_Negative() {
        let forecast = makeForecast(startingBalance: 5000, endBalance: 3000)
        XCTAssertEqual(forecast.netChange, -2000, accuracy: 0.01)
    }

    func testForecast_NetChange_Zero() {
        let forecast = makeForecast(startingBalance: 3000, endBalance: 3000)
        XCTAssertEqual(forecast.netChange, 0, accuracy: 0.01)
        XCTAssertFalse(forecast.isTrendingUp, "Zero change should not be trending up")
    }

    func testForecast_FormattedStartingBalance() {
        let forecast = makeForecast(startingBalance: 1234.56)
        XCTAssertTrue(forecast.formattedStartingBalance.contains("1,234.56") ||
                       forecast.formattedStartingBalance.contains("1234.56"),
                       "Got: \(forecast.formattedStartingBalance)")
    }

    func testForecast_FormattedEndBalance() {
        let forecast = makeForecast(endBalance: 987.65)
        XCTAssertTrue(forecast.formattedEndBalance.contains("987.65"),
                       "Got: \(forecast.formattedEndBalance)")
    }

    func testForecast_FormattedLowestBalance() {
        let forecast = makeForecast(lowestBalance: -500.00)
        XCTAssertTrue(forecast.formattedLowestBalance.contains("500.00"),
                       "Got: \(forecast.formattedLowestBalance)")
    }
}

// MARK: - Danger Zones

extension FLOCashFlowForecastTests {

    func testForecast_HasDangerZones_WhenPresent() {
        let zone = DangerZone(
            startDate: makeDate(month: 3, day: 1),
            endDate: makeDate(month: 3, day: 15),
            lowestBalance: -200
        )
        let forecast = makeForecast(dangerZones: [zone])
        XCTAssertTrue(forecast.hasDangerZones)
    }

    func testForecast_NoDangerZones_WhenEmpty() {
        let forecast = makeForecast(dangerZones: [])
        XCTAssertFalse(forecast.hasDangerZones)
    }

    func testDangerZone_DurationDays() {
        let zone = DangerZone(
            startDate: makeDate(month: 3, day: 1),
            endDate: makeDate(month: 3, day: 10),
            lowestBalance: -500
        )
        XCTAssertEqual(zone.durationDays, 9)
    }

    func testDangerZone_SingleDayDuration() {
        let date = makeDate(month: 5, day: 15)
        let zone = DangerZone(
            startDate: date,
            endDate: date,
            lowestBalance: -100
        )
        XCTAssertEqual(zone.durationDays, 0)
    }

    func testDangerZone_MultipleDangerZones() {
        let zone1 = DangerZone(
            startDate: makeDate(month: 3, day: 1),
            endDate: makeDate(month: 3, day: 5),
            lowestBalance: -200
        )
        let zone2 = DangerZone(
            startDate: makeDate(month: 4, day: 10),
            endDate: makeDate(month: 4, day: 20),
            lowestBalance: -800
        )
        let forecast = makeForecast(dangerZones: [zone1, zone2])
        XCTAssertEqual(forecast.dangerZones.count, 2)
    }
}

// MARK: - UpcomingBill

extension FLOCashFlowForecastTests {

    func testUpcomingBill_FormattedAmount() {
        let bill = UpcomingBill(
            name: "Netflix",
            amount: 15.99,
            dueDate: makeDate(month: 4, day: 1),
            isIncome: false,
            frequency: .monthly
        )
        XCTAssertTrue(bill.formattedAmount.contains("15.99"),
                       "Got: \(bill.formattedAmount)")
    }

    func testUpcomingBill_FormattedDate() {
        let bill = UpcomingBill(
            name: "Rent",
            amount: 1500,
            dueDate: makeDate(month: 4, day: 1),
            isIncome: false,
            frequency: .monthly
        )
        // formattedDate uses .abbreviated, should contain "Apr"
        XCTAssertFalse(bill.formattedDate.isEmpty, "Date should not be empty")
    }

    func testUpcomingBill_Identifiable() {
        let bill1 = UpcomingBill(
            name: "A", amount: 10, dueDate: Date(),
            isIncome: false, frequency: .monthly
        )
        let bill2 = UpcomingBill(
            name: "B", amount: 20, dueDate: Date(),
            isIncome: false, frequency: .monthly
        )
        XCTAssertNotEqual(bill1.id, bill2.id)
    }
}

// MARK: - DailyBalancePoint

extension FLOCashFlowForecastTests {

    func testDailyBalancePoint_Properties() {
        let point = DailyBalancePoint(
            date: Date(),
            projectedBalance: 5000,
            isHistorical: false,
            recurringIncome: 3000,
            recurringExpenses: 1500,
            variableSpending: 500
        )
        XCTAssertEqual(point.projectedBalance, 5000, accuracy: 0.01)
        XCTAssertEqual(point.recurringIncome, 3000, accuracy: 0.01)
        XCTAssertEqual(point.recurringExpenses, 1500, accuracy: 0.01)
        XCTAssertEqual(point.variableSpending, 500, accuracy: 0.01)
        XCTAssertFalse(point.isHistorical)
    }

    func testDailyBalancePoint_UniqueIDs() {
        let p1 = DailyBalancePoint(
            date: Date(), projectedBalance: 100, isHistorical: false,
            recurringIncome: 0, recurringExpenses: 0, variableSpending: 0
        )
        let p2 = DailyBalancePoint(
            date: Date(), projectedBalance: 100, isHistorical: false,
            recurringIncome: 0, recurringExpenses: 0, variableSpending: 0
        )
        XCTAssertNotEqual(p1.id, p2.id)
    }
}

// MARK: - Edge Cases

extension FLOCashFlowForecastTests {

    func testForecast_NegativeBalances() {
        let forecast = makeForecast(
            startingBalance: -1000,
            endBalance: -2000,
            lowestBalance: -3000
        )
        XCTAssertFalse(forecast.isTrendingUp)
        XCTAssertEqual(forecast.netChange, -1000, accuracy: 0.01)
    }

    func testForecast_ZeroBalance() {
        let forecast = makeForecast(
            startingBalance: 0,
            endBalance: 0,
            lowestBalance: 0
        )
        XCTAssertEqual(forecast.netChange, 0, accuracy: 0.01)
    }

    func testForecast_VeryLargeBalance() {
        let forecast = makeForecast(
            startingBalance: 1_000_000,
            endBalance: 1_500_000,
            lowestBalance: 800_000
        )
        XCTAssertTrue(forecast.isTrendingUp)
        XCTAssertEqual(forecast.netChange, 500_000, accuracy: 0.01)
    }
}
