//  FLODebtServiceTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - DebtCalculationService Direct Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate DebtCalculationService.shared directly — credit card
//  schedule generation, interest trap detection, strategy comparisons,
//  and fixed-loan amortization.
//
//  CRITICAL: These tests exercise the ACTUAL service code, not helpers.
//  Run before every release to catch regressions in debt math.
//
//  COVERS:
//  - generateCreditCardSchedule() math and tuple return
//  - Interest trap detection (payment ≤ interest)
//  - Pre-interest balance minimum payment calculation
//  - calculateCreditCardPayoff() multi-strategy results
//  - 1/6 Trick for credit cards
//  - Extra payment impact
//  - Fixed-rate loan amortization
//  - calculateMonthlyPayment() formula
//  - Edge cases: zero balance, zero APR, tiny balance
//

import XCTest
@testable import FLO

@MainActor
final class FLODebtServiceTests: XCTestCase {

    // MARK: - Service Under Test

    private var service: DebtCalculationService { DebtCalculationService.shared }

    // MARK: - Precision Helper

    func assertCurrencyEqual(
        _ actual: Double,
        _ expected: Double,
        accuracy: Double = 0.01,
        _ message: String = "",
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            actual, expected, accuracy: accuracy,
            message.isEmpty ? "Expected \(expected), got \(actual)" : message,
            file: file, line: line
        )
    }
}

// MARK: - Credit Card Schedule: Basic Scenarios

extension FLODebtServiceTests {

    /// Test: Basic schedule generation returns non-empty schedule and no interest trap
    func testCCSchedule_BasicScenario() {
        let result = service.generateCreditCardSchedule(
            balance: 5_000, apr: 18.0
        )

        XCTAssertFalse(result.interestTrap, "18% APR with 2% min should NOT be an interest trap")
        XCTAssertFalse(result.schedule.isEmpty, "Should produce a payment schedule")
        XCTAssertGreaterThan(result.schedule.count, 100, "Should take many months at minimum payments")
    }

    /// Test: Schedule balance decreases monotonically to zero
    func testCCSchedule_BalanceDecreasesToZero() {
        let result = service.generateCreditCardSchedule(
            balance: 1_000, apr: 15.0
        )

        XCTAssertFalse(result.interestTrap)
        guard let last = result.schedule.last else {
            XCTFail("Schedule should not be empty")
            return
        }

        assertCurrencyEqual(last.remainingBalance, 0.0, accuracy: 0.02, "Final balance should be ~$0")

        // Verify balance generally decreases (allow for interest spikes in early months)
        for i in stride(from: 10, to: result.schedule.count, by: 10) {
            XCTAssertLessThan(
                result.schedule[i].remainingBalance,
                result.schedule[max(0, i - 10)].remainingBalance,
                "Balance at month \(result.schedule[i].month) should be less than 10 months prior"
            )
        }
    }

    /// Test: Zero APR card pays off with no interest
    func testCCSchedule_ZeroAPR() {
        let result = service.generateCreditCardSchedule(
            balance: 1_000, apr: 0.0
        )

        XCTAssertFalse(result.interestTrap)
        guard let last = result.schedule.last else {
            XCTFail("Schedule should not be empty")
            return
        }

        assertCurrencyEqual(last.cumulativeInterest, 0.0, "Zero APR = zero interest paid")
        assertCurrencyEqual(last.remainingBalance, 0.0, accuracy: 0.02)
    }

    /// Test: Small balance pays off quickly
    func testCCSchedule_SmallBalance() {
        let result = service.generateCreditCardSchedule(
            balance: 50, apr: 20.0
        )

        XCTAssertFalse(result.interestTrap)
        XCTAssertLessThanOrEqual(result.schedule.count, 4, "$50 balance should pay off in a few months")
    }

    /// Test: Zero balance returns empty schedule, no trap
    func testCCSchedule_ZeroBalance() {
        let result = service.generateCreditCardSchedule(
            balance: 0, apr: 20.0
        )

        XCTAssertFalse(result.interestTrap)
        XCTAssertTrue(result.schedule.isEmpty, "Zero balance = nothing to pay")
    }
}

// MARK: - Credit Card Schedule: Interest Trap Detection

extension FLODebtServiceTests {

    /// Test: High APR where min payment can't cover interest → interest trap
    func testCCSchedule_InterestTrap_HighAPR() {
        // 30% APR → monthly rate 2.5%, min payment 2% → payment < interest
        let result = service.generateCreditCardSchedule(
            balance: 10_000, apr: 30.0,
            minimumPercent: 2.0, minimumFloor: 25.0
        )

        XCTAssertTrue(result.interestTrap, "30% APR with 2% min = interest trap")
        XCTAssertTrue(result.schedule.isEmpty, "Interest trap should return empty schedule")
    }

    /// Test: Borderline trap — payment exactly equals interest
    func testCCSchedule_InterestTrap_Borderline() {
        // 24% APR → monthly rate 2.0%, min payment 2.0% → payment == interest
        let result = service.generateCreditCardSchedule(
            balance: 5_000, apr: 24.0,
            minimumPercent: 2.0, minimumFloor: 25.0
        )

        XCTAssertTrue(result.interestTrap, "24% APR with 2% min = borderline trap (payment <= interest)")
    }

    /// Test: Extra payment rescues from interest trap
    func testCCSchedule_InterestTrap_ExtraPaymentRescues() {
        // 30% APR is a trap at min only, but $100 extra should rescue it
        let result = service.generateCreditCardSchedule(
            balance: 5_000, apr: 30.0,
            minimumPercent: 2.0, minimumFloor: 25.0,
            extraPayment: 100
        )

        XCTAssertFalse(result.interestTrap, "Extra payment should rescue from trap")
        XCTAssertFalse(result.schedule.isEmpty, "Should produce schedule with extra payment")
    }

    /// Test: Low APR is NOT a trap
    func testCCSchedule_NotTrap_LowAPR() {
        let result = service.generateCreditCardSchedule(
            balance: 5_000, apr: 15.0
        )

        XCTAssertFalse(result.interestTrap, "15% APR with 2% min should not be a trap")
        XCTAssertFalse(result.schedule.isEmpty)
    }
}

// MARK: - Credit Card Schedule: Payment Math Validation

extension FLODebtServiceTests {

    /// Test: First month payment components add up correctly
    func testCCSchedule_FirstMonthMath() {
        let balance = 5_000.0
        let apr = 18.0
        let result = service.generateCreditCardSchedule(
            balance: balance, apr: apr
        )

        guard let first = result.schedule.first else {
            XCTFail("Schedule should not be empty")
            return
        }

        let expectedInterest = balance * (apr / 100.0 / 12.0)  // $75.00
        assertCurrencyEqual(first.interest, expectedInterest, "Interest should be on pre-interest balance")

        // Payment = principal + interest (approximately, modulo rounding)
        let paymentCheck = first.principal + first.extraPrincipal + first.interest
        assertCurrencyEqual(first.payment, paymentCheck, accuracy: 0.02, "Payment = principal + interest")
    }

    /// Test: Cumulative interest increases monotonically
    func testCCSchedule_CumulativeInterestIncreases() {
        let result = service.generateCreditCardSchedule(
            balance: 3_000, apr: 20.0
        )

        for i in 1..<result.schedule.count {
            XCTAssertGreaterThanOrEqual(
                result.schedule[i].cumulativeInterest,
                result.schedule[i - 1].cumulativeInterest,
                "Cumulative interest must never decrease"
            )
        }
    }

    /// Test: Extra payment reduces total months and interest
    func testCCSchedule_ExtraPaymentImpact() {
        let standardResult = service.generateCreditCardSchedule(
            balance: 5_000, apr: 18.0, extraPayment: 0
        )
        let extraResult = service.generateCreditCardSchedule(
            balance: 5_000, apr: 18.0, extraPayment: 50
        )

        XCTAssertFalse(standardResult.interestTrap)
        XCTAssertFalse(extraResult.interestTrap)

        XCTAssertLessThan(
            extraResult.schedule.count,
            standardResult.schedule.count,
            "Extra payment should reduce months"
        )

        let standardInterest = standardResult.schedule.last?.cumulativeInterest ?? 0
        let extraInterest = extraResult.schedule.last?.cumulativeInterest ?? 0
        XCTAssertLessThan(extraInterest, standardInterest, "Extra payment should reduce total interest")
    }
}

// MARK: - calculateCreditCardPayoff() Strategy Comparisons

extension FLODebtServiceTests {

    /// Test: Returns results for minimumOnly and oneSixthTrick at minimum
    func testCCPayoff_ReturnsMultipleStrategies() {
        let debt = DebtInput(
            name: "Test Card",
            debtType: .creditCard,
            currentBalance: 5_000,
            interestRate: 18.0,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        let results = service.calculateCreditCardPayoff(debt: debt)

        XCTAssertNotNil(results[.minimumOnly], "Should have minimum-only result")
        XCTAssertNotNil(results[.oneSixthTrick], "Should have 1/6 trick result")
    }

    /// Test: 1/6 Trick saves interest vs minimum
    func testCCPayoff_OneSixthTrickSavesInterest() {
        let debt = DebtInput(
            name: "Test Card",
            debtType: .creditCard,
            currentBalance: 5_000,
            interestRate: 18.0,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        let results = service.calculateCreditCardPayoff(debt: debt)

        guard let minimum = results[.minimumOnly],
              let oneSixth = results[.oneSixthTrick] else {
            XCTFail("Both strategies should be present")
            return
        }

        XCTAssertLessThan(oneSixth.totalInterest, minimum.totalInterest, "1/6 trick should save interest")
        XCTAssertLessThan(oneSixth.totalMonths, minimum.totalMonths, "1/6 trick should save months")
        XCTAssertGreaterThan(oneSixth.interestSaved, 0, "Interest saved should be positive")
        XCTAssertGreaterThan(oneSixth.monthsSaved, 0, "Months saved should be positive")
    }

    /// Test: Interest trap returns trap flag on minimumOnly
    func testCCPayoff_InterestTrapResult() {
        let debt = DebtInput(
            name: "Trapped Card",
            debtType: .creditCard,
            currentBalance: 10_000,
            interestRate: 30.0,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        let results = service.calculateCreditCardPayoff(debt: debt)

        guard let minimum = results[.minimumOnly] else {
            XCTFail("Should have minimum result even for trap")
            return
        }

        XCTAssertTrue(minimum.interestTrap, "Should flag interest trap")
        XCTAssertEqual(minimum.totalMonths, 0, "Trap = zero months")
        XCTAssertTrue(minimum.schedule.isEmpty, "Trap = empty schedule")
        // Should only have minimumOnly — no other strategies computed
        XCTAssertEqual(results.count, 1, "Interest trap should only return 1 result")
    }

    /// Test: Fixed extra payment strategy
    func testCCPayoff_FixedExtraPayment() {
        let debt = DebtInput(
            name: "Test Card",
            debtType: .creditCard,
            currentBalance: 5_000,
            interestRate: 18.0,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        let results = service.calculateCreditCardPayoff(debt: debt, extraPayment: 100)

        XCTAssertNotNil(results[.fixed], "Should have fixed extra payment result")

        guard let minimum = results[.minimumOnly],
              let fixed = results[.fixed] else { return }

        XCTAssertLessThan(fixed.totalMonths, minimum.totalMonths, "Extra payment should reduce months")
        XCTAssertLessThan(fixed.totalInterest, minimum.totalInterest, "Extra payment should reduce interest")
    }
}

// MARK: - Fixed-Rate Loan Calculations

extension FLODebtServiceTests {

    /// Test: Monthly payment formula for standard mortgage
    func testFixedLoan_MonthlyPaymentFormula() {
        // $250,000 mortgage at 6.5% for 30 years
        let payment = service.calculateMonthlyPayment(
            principal: 250_000, annualRate: 6.5, termMonths: 360
        )

        // Expected: ~$1,580.17 per industry-standard amortization formula
        assertCurrencyEqual(payment, 1_580.17, accuracy: 1.0, "Standard mortgage payment")
    }

    /// Test: Zero interest rate loan
    func testFixedLoan_ZeroInterest() {
        let payment = service.calculateMonthlyPayment(
            principal: 12_000, annualRate: 0.0, termMonths: 12
        )

        assertCurrencyEqual(payment, 1_000.00, accuracy: 0.01, "$12k / 12 months = $1k/month")
    }

    /// Test: Amortization schedule sums to total
    func testFixedLoan_AmortizationScheduleTotals() {
        // $20,000 at 5% for 60 months → ~$377.42/month
        let monthlyPmt = service.calculateMonthlyPayment(
            principal: 20_000, annualRate: 5.0, termMonths: 60
        )
        let schedule = service.generateAmortizationSchedule(
            principal: 20_000, annualRate: 5.0, monthlyPayment: monthlyPmt, extraMonthlyPayment: 0
        )

        XCTAssertEqual(schedule.count, 60, "60-month term = 60 entries")

        guard let last = schedule.last else {
            XCTFail("Schedule should not be empty")
            return
        }

        assertCurrencyEqual(last.remainingBalance, 0.0, accuracy: 0.05, "Final balance ≈ $0")

        let totalPrincipal = schedule.reduce(0.0) { $0 + $1.principal + $1.extraPrincipal }
        assertCurrencyEqual(totalPrincipal, 20_000, accuracy: 1.0, "Total principal ≈ loan amount")
    }

    /// Test: Extra payment shortens loan
    func testFixedLoan_ExtraPaymentShortensLoan() {
        let monthlyPmt = service.calculateMonthlyPayment(
            principal: 20_000, annualRate: 5.0, termMonths: 60
        )
        let standard = service.generateAmortizationSchedule(
            principal: 20_000, annualRate: 5.0, monthlyPayment: monthlyPmt, extraMonthlyPayment: 0
        )
        let extra = service.generateAmortizationSchedule(
            principal: 20_000, annualRate: 5.0, monthlyPayment: monthlyPmt, extraMonthlyPayment: 100
        )

        XCTAssertLessThan(extra.count, standard.count, "Extra $100/month should shorten loan")

        let standardInterest = standard.reduce(0.0) { $0 + $1.interest }
        let extraInterest = extra.reduce(0.0) { $0 + $1.interest }
        XCTAssertLessThan(extraInterest, standardInterest, "Extra payment should reduce total interest")
    }
}

// MARK: - calculateFixedLoanPayoff() Multi-Strategy

extension FLODebtServiceTests {

    /// Test: Fixed loan payoff returns multiple strategies
    func testFixedLoanPayoff_MultipleStrategies() {
        let debt = DebtInput(
            name: "Auto Loan",
            debtType: .autoLoan,
            currentBalance: 20_000,
            interestRate: 5.0,
            monthlyPayment: 377.42,
            remainingTermMonths: 60
        )

        let results = service.calculateFixedLoanPayoff(debt: debt)

        XCTAssertNotNil(results[.minimumOnly], "Should have minimum strategy")
        XCTAssertNotNil(results[.oneSixthTrick], "Should have 1/6 trick strategy")
    }

    /// Test: 1/6 trick saves on fixed loan
    func testFixedLoanPayoff_OneSixthSaves() {
        let debt = DebtInput(
            name: "Auto Loan",
            debtType: .autoLoan,
            currentBalance: 20_000,
            interestRate: 5.0,
            monthlyPayment: 377.42,
            remainingTermMonths: 60
        )

        let results = service.calculateFixedLoanPayoff(debt: debt)

        guard let minimum = results[.minimumOnly],
              let oneSixth = results[.oneSixthTrick] else {
            XCTFail("Both strategies should be present")
            return
        }

        XCTAssertLessThanOrEqual(oneSixth.totalMonths, minimum.totalMonths)
        XCTAssertLessThanOrEqual(oneSixth.totalInterest, minimum.totalInterest)
    }
}

// MARK: - Edge Cases

extension FLODebtServiceTests {

    /// Test: Negative balance is treated as positive
    func testEdge_NegativeBalance() {
        let debt = DebtInput(
            name: "Negative",
            debtType: .creditCard,
            currentBalance: -3_000,
            interestRate: 18.0,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        // DebtInput.init converts to abs()
        XCTAssertEqual(debt.currentBalance, 3_000, "Negative balance should be converted to positive")
    }

    /// Test: Very high extra payment pays off in 1 month
    func testEdge_VeryHighExtraPayment() {
        let result = service.generateCreditCardSchedule(
            balance: 1_000, apr: 18.0, extraPayment: 10_000
        )

        XCTAssertFalse(result.interestTrap)
        XCTAssertEqual(result.schedule.count, 1, "Huge extra payment = 1-month payoff")
    }

    /// Test: Negative APR treated as valid (promotional rebate scenario)
    func testEdge_NegativeAPR() {
        let result = service.generateCreditCardSchedule(
            balance: 1_000, apr: -1.0
        )

        // Negative APR shouldn't crash — behavior may vary
        XCTAssertFalse(result.interestTrap, "Negative APR should not trap")
    }
}
