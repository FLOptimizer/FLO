//  FLOFiftyThirtyTwentyTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Need/Want/Savings classification + 50/30/20 rule tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  COVERS:
//  - BudgetPurpose targets and savings-inversion semantics
//  - Monthly income: personal-only, transfer/business/other-month filtering
//  - Actuals-with-fallback income basis (previous month before first paycheck)
//  - Bucket status thresholds (under / on track ±2pts / over)
//  - Bucket aggregation and share math
//  - Budget model purpose accessor + savings envelope link persistence

import XCTest
@testable import FLO

final class FLOFiftyThirtyTwentyTests: XCTestCase {

    let precision: Double = 0.0001

    // MARK: - Helpers

    private func date(year: Int = 2026, month: Int, day: Int = 15) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    private func monthStart(year: Int = 2026, month: Int) -> Date {
        date(year: year, month: month, day: 1)
    }

    private func income(
        _ amount: Double,
        month: Int,
        financeType: Transaction.FinanceType = .personal,
        isTransfer: Bool = false
    ) -> Transaction {
        Transaction(
            amount: amount,
            date: date(month: month),
            isIncome: true,
            financeType: financeType,
            isTransfer: isTransfer
        )
    }

    // MARK: - BudgetPurpose

    func testPurpose_TargetSharesMatchRule() {
        XCTAssertEqual(BudgetPurpose.need.targetShare, 0.50)
        XCTAssertEqual(BudgetPurpose.want.targetShare, 0.30)
        XCTAssertEqual(BudgetPurpose.savings.targetShare, 0.20)
        XCTAssertEqual(BudgetPurpose.allCases.map(\.targetShare).reduce(0, +), 1.0, accuracy: precision)
    }

    func testPurpose_OnlySavingsIsHigherIsBetter() {
        XCTAssertFalse(BudgetPurpose.need.higherIsBetter)
        XCTAssertFalse(BudgetPurpose.want.higherIsBetter)
        XCTAssertTrue(BudgetPurpose.savings.higherIsBetter)
    }

    // MARK: - Monthly Income

    func testMonthlyIncome_SumsPersonalIncomeForMonth() {
        let transactions = [
            income(3_000, month: 6),
            income(2_000, month: 6),
            income(9_999, month: 5)                        // other month
        ]
        let total = FiftyThirtyTwentyService.monthlyIncome(for: monthStart(month: 6), transactions: transactions)
        XCTAssertEqual(total, 5_000, accuracy: precision)
    }

    func testMonthlyIncome_ExcludesBusinessTransfersAndExpenses() {
        let expense = Transaction(amount: 400, date: date(month: 6), isIncome: false, financeType: .personal)
        let transactions = [
            income(3_000, month: 6),
            income(1_000, month: 6, financeType: .business),   // business income excluded
            income(500, month: 6, isTransfer: true),           // transfer excluded
            expense                                            // not income
        ]
        let total = FiftyThirtyTwentyService.monthlyIncome(for: monthStart(month: 6), transactions: transactions)
        XCTAssertEqual(total, 3_000, accuracy: precision)
    }

    // MARK: - Income Basis (Actuals with Fallback)

    func testIncomeBasis_UsesCurrentMonthWhenIncomeExists() {
        let transactions = [income(4_000, month: 6), income(3_500, month: 5)]
        let basis = FiftyThirtyTwentyService.incomeBasis(for: monthStart(month: 6), transactions: transactions)
        XCTAssertEqual(basis.amount, 4_000, accuracy: precision)
        XCTAssertFalse(basis.usedPreviousMonth)
    }

    func testIncomeBasis_FallsBackToPreviousMonth() {
        let transactions = [income(3_500, month: 5)]
        let basis = FiftyThirtyTwentyService.incomeBasis(for: monthStart(month: 6), transactions: transactions)
        XCTAssertEqual(basis.amount, 3_500, accuracy: precision)
        XCTAssertTrue(basis.usedPreviousMonth)
    }

    func testIncomeBasis_NoIncomeAnywhere_ZeroWithoutFallbackFlag() {
        let basis = FiftyThirtyTwentyService.incomeBasis(for: monthStart(month: 6), transactions: [])
        XCTAssertEqual(basis.amount, 0, accuracy: precision)
        XCTAssertFalse(basis.usedPreviousMonth, "Fallback flag only set when previous month actually had income")
    }

    // MARK: - Status Thresholds

    func testStatus_OnTrackWithinTwoPoints() {
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.50, target: 0.50), .onTrack)
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.52, target: 0.50), .onTrack)
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.48, target: 0.50), .onTrack)
    }

    func testStatus_UnderAndOverOutsideTolerance() {
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.45, target: 0.50), .under)
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.56, target: 0.50), .over)
        XCTAssertEqual(FiftyThirtyTwentyService.status(share: 0.0, target: 0.20), .under)
    }

    func testStatus_HealthSemantics_SavingsInverted() {
        XCTAssertTrue(PurposeStatus.under.isHealthy(for: .need), "Spending under 50% on needs is good")
        XCTAssertFalse(PurposeStatus.over.isHealthy(for: .need))
        XCTAssertFalse(PurposeStatus.under.isHealthy(for: .savings), "Saving under 20% is bad")
        XCTAssertTrue(PurposeStatus.over.isHealthy(for: .savings), "Saving over 20% is good")
        XCTAssertTrue(PurposeStatus.onTrack.isHealthy(for: .want))
    }

    // MARK: - Bucket Summaries

    func testSummaries_AggregatesByPurposeInFixedOrder() {
        let spending: [(purpose: BudgetPurpose, spent: Double)] = [
            (.want, 600),
            (.need, 1_500),
            (.need, 1_000),
            (.savings, 800)
        ]
        let summaries = FiftyThirtyTwentyService.summaries(classifiedSpending: spending, income: 5_000)

        XCTAssertEqual(summaries.map(\.purpose), [.need, .want, .savings], "Fixed need → want → savings order")
        XCTAssertEqual(summaries[0].spent, 2_500, accuracy: precision)
        XCTAssertEqual(summaries[0].share, 0.50, accuracy: precision)
        XCTAssertEqual(summaries[0].status, .onTrack)
        XCTAssertEqual(summaries[1].share, 0.12, accuracy: precision)
        XCTAssertEqual(summaries[1].status, .under)
        XCTAssertEqual(summaries[2].share, 0.16, accuracy: precision)
        XCTAssertEqual(summaries[2].status, .under)
        XCTAssertFalse(summaries[2].isHealthy, "Saving 16% against a 20% target is under-saving")
    }

    func testSummaries_OmitsPurposesWithNoBudgets() {
        let summaries = FiftyThirtyTwentyService.summaries(
            classifiedSpending: [(.need, 1_000)],
            income: 4_000
        )
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].purpose, .need)
    }

    func testSummaries_ZeroIncome_SharesAreZero() {
        let summaries = FiftyThirtyTwentyService.summaries(
            classifiedSpending: [(.need, 1_000)],
            income: 0
        )
        XCTAssertEqual(summaries[0].share, 0, accuracy: precision)
        XCTAssertEqual(summaries[0].status, .under)
    }

    // MARK: - Budget Model

    func testBudget_PurposeAccessorRoundtrip() {
        let budget = Budget(month: date(month: 6), planned: 500)
        XCTAssertNil(budget.purpose, "Unclassified by default")

        budget.purpose = .savings
        XCTAssertEqual(budget.purposeRaw, "savings")
        XCTAssertEqual(budget.purpose, .savings)

        budget.purpose = nil
        XCTAssertNil(budget.purposeRaw)
    }

    func testBudget_InitStoresPurposeAndEnvelopeLink() {
        let envelopeCategoryID = UUID()
        let budget = Budget(
            month: date(month: 6),
            planned: 500,
            purpose: .savings,
            savingsEnvelopeCategoryID: envelopeCategoryID
        )
        XCTAssertEqual(budget.purpose, .savings)
        XCTAssertEqual(budget.savingsEnvelopeCategoryID, envelopeCategoryID)
    }

    func testBudget_UnknownPurposeRawDecodesAsNil() {
        let budget = Budget(month: date(month: 6), planned: 500)
        budget.purposeRaw = "yacht"
        XCTAssertNil(budget.purpose, "Unknown raw values must not crash — decode as unclassified")
    }
}
