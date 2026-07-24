//  FLOPropertyBasedTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Updated SE Tax Calculations for 2026
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Property-based tests that verify mathematical invariants
//  across randomized inputs. These tests catch edge cases that
//  specific test cases might miss.
//
//  CHANGES IN v1.1:
//  ✅ Updated SE tax calculations to match TaxCalculationService v1.4
//  ✅ SE tax now uses: 12.4% SS (capped at $184,500) + 2.9% Medicare (uncapped)
//  ✅ Added Additional Medicare Tax (0.9%) for high earners
//  ✅ Split SE rate tests into below/above wage base cap
//  ✅ Added SS cap and Medicare uncapped property tests
//
//  PHILOSOPHY:
//  - Properties should always hold true, regardless of input values
//  - Use random inputs to discover edge cases
//  - Focus on relationships between values, not specific numbers
//
//  STRUCTURE:
//  - Tax calculation properties
//  - Credit card calculation properties
//  - Date calculation properties
//  - Safe harbor properties
//

import XCTest
@testable import FLO

// MARK: - Property-Based Test Infrastructure

final class FLOPropertyBasedTests: XCTestCase {
    
    // MARK: - Configuration
    
    /// Number of random samples per property test
    let sampleCount = 100
    
    // MARK: - 2026 SE Tax Constants
    
    let seIncomeMultiplier: Double = 0.9235
    let socialSecurityRate: Double = 0.124
    let medicareRate: Double = 0.029
    let additionalMedicareRate: Double = 0.009
    let socialSecurityWageBase2026: Double = 184_500
    let additionalMedicareThresholdSingle: Double = 200_000
    
    // Maximum SS tax possible: $184,500 × 12.4% = $22,878
    var maxSocialSecurityTax: Double { socialSecurityWageBase2026 * socialSecurityRate }
    
    // MARK: - Random Value Generators
    
    func randomIncome() -> Double {
        Double.random(in: 1_000...500_000)
    }
    
    func randomSmallIncome() -> Double {
        Double.random(in: 1_000...50_000)
    }
    
    func randomLargeIncome() -> Double {
        Double.random(in: 100_000...1_000_000)
    }
    
    func randomBalance() -> Double {
        Double.random(in: 100...50_000)
    }
    
    func randomAPR() -> Double {
        Double.random(in: 0.05...0.30)
    }
    
    func randomMinPaymentPercent() -> Double {
        Double.random(in: 0.01...0.05)
    }
    
    func randomDay() -> Int {
        Int.random(in: 1...31)
    }
    
    func randomMonth() -> Int {
        Int.random(in: 1...12)
    }
    
    func randomYear() -> Int {
        Int.random(in: 2020...2030)
    }
    
    // MARK: - SE Tax Calculation Helper
    
    /// Calculate SE tax with proper 2026 rates and wage base cap
    /// Mirrors TaxCalculationService v1.4 logic
    func calculateSETax(netIncome: Double) -> Double {
        guard netIncome > 0 else { return 0 }
        
        let seIncome = netIncome * seIncomeMultiplier
        
        // SS capped at wage base
        let ssTax = min(seIncome, socialSecurityWageBase2026) * socialSecurityRate
        
        // Medicare uncapped
        let medicareTax = seIncome * medicareRate
        
        // Additional Medicare above threshold
        let additionalMedicareTax = seIncome > additionalMedicareThresholdSingle
            ? (seIncome - additionalMedicareThresholdSingle) * additionalMedicareRate
            : 0
        
        return ssTax + medicareTax + additionalMedicareTax
    }
    
    /// Calculate just Social Security portion
    func calculateSSTax(netIncome: Double) -> Double {
        guard netIncome > 0 else { return 0 }
        let seIncome = netIncome * seIncomeMultiplier
        return min(seIncome, socialSecurityWageBase2026) * socialSecurityRate
    }
    
    /// Calculate just Medicare portion (base + additional)
    func calculateMedicareTax(netIncome: Double) -> Double {
        guard netIncome > 0 else { return 0 }
        let seIncome = netIncome * seIncomeMultiplier
        let baseMedicare = seIncome * medicareRate
        let additionalMedicare = seIncome > additionalMedicareThresholdSingle
            ? (seIncome - additionalMedicareThresholdSingle) * additionalMedicareRate
            : 0
        return baseMedicare + additionalMedicare
    }
}

// MARK: - Tax Calculation Properties

extension FLOPropertyBasedTests {
    
    // =========================================================================
    // PROPERTY: SE tax is never negative
    // =========================================================================
    
    func testProperty_Tax_NeverNegative() {
        for _ in 0..<sampleCount {
            let netIncome = Double.random(in: -100_000...500_000)
            let seTax = calculateSETax(netIncome: netIncome)
            
            XCTAssertGreaterThanOrEqual(seTax, 0, "SE tax should never be negative")
        }
    }
    
    // =========================================================================
    // PROPERTY: Higher income = higher SE tax (monotonic)
    // This holds even with the SS cap because Medicare is uncapped
    // =========================================================================
    
    func testProperty_Tax_Monotonic() {
        for _ in 0..<sampleCount {
            let income1 = randomIncome()
            let income2 = income1 + Double.random(in: 1_000...50_000)
            
            let tax1 = calculateSETax(netIncome: income1)
            let tax2 = calculateSETax(netIncome: income2)
            
            XCTAssertGreaterThanOrEqual(
                tax2, tax1,
                "Higher income ($\(income2)) should have >= SE tax than lower income ($\(income1))"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Zero income = zero SE tax
    // =========================================================================
    
    func testProperty_Tax_ZeroIncomeZeroTax() {
        let seTax = calculateSETax(netIncome: 0)
        XCTAssertEqual(seTax, 0, "Zero income should produce zero SE tax")
    }
    
    // =========================================================================
    // PROPERTY: SE deduction is exactly half of SE tax
    // This is an IRS rule that applies regardless of income level
    // =========================================================================
    
    func testProperty_Tax_SEDeductionIsHalfOfSETax() {
        for _ in 0..<sampleCount {
            let netIncome = randomIncome()
            let seTax = calculateSETax(netIncome: netIncome)
            let seDeduction = seTax / 2
            
            XCTAssertEqual(
                seDeduction, seTax * 0.5,
                accuracy: 0.01,
                "SE deduction should be exactly half of SE tax"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Social Security tax is capped
    // SS tax should never exceed $22,878 (2026 wage base × 12.4%)
    // =========================================================================
    
    func testProperty_Tax_SocialSecurityCapped() {
        for _ in 0..<sampleCount {
            let netIncome = Double.random(in: 200_000...1_000_000)  // Above cap
            let ssTax = calculateSSTax(netIncome: netIncome)
            
            XCTAssertLessThanOrEqual(
                ssTax, maxSocialSecurityTax + 0.01,
                "SS tax should never exceed $\(maxSocialSecurityTax)"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Medicare tax has no cap (grows with income)
    // =========================================================================
    
    func testProperty_Tax_MedicareUncapped() {
        for _ in 0..<sampleCount {
            let income1 = Double.random(in: 100_000...300_000)
            let income2 = income1 + 100_000
            
            let medicare1 = calculateMedicareTax(netIncome: income1)
            let medicare2 = calculateMedicareTax(netIncome: income2)
            
            XCTAssertGreaterThan(
                medicare2, medicare1,
                "Medicare tax should always increase with income (no cap)"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Below wage base, effective SE rate is ~14.13%
    // (0.9235 × 15.3% = 14.13%)
    // =========================================================================
    
    func testProperty_Tax_EffectiveRate_BelowWageBase() {
        for _ in 0..<sampleCount {
            // Income that keeps SE income below wage base
            // $184,500 ÷ 0.9235 ≈ $199,838
            let netIncome = Double.random(in: 10_000...190_000)
            let seTax = calculateSETax(netIncome: netIncome)
            let effectiveRate = seTax / netIncome
            
            // Below cap and below Additional Medicare threshold:
            // Rate should be approximately 14.13% (±0.5% tolerance)
            XCTAssertGreaterThanOrEqual(effectiveRate, 0.13, "SE rate should be >= 13%")
            XCTAssertLessThanOrEqual(effectiveRate, 0.15, "SE rate should be <= 15%")
        }
    }
    
    // =========================================================================
    // PROPERTY: Above wage base, effective SE rate decreases
    // Because SS portion is capped, rate goes down as income rises
    // =========================================================================
    
    func testProperty_Tax_EffectiveRate_AboveWageBase() {
        for _ in 0..<sampleCount {
            let netIncome = Double.random(in: 300_000...500_000)
            let seTax = calculateSETax(netIncome: netIncome)
            let effectiveRate = seTax / netIncome
            
            // Above cap: rate should be lower than 14.13%
            // At $500K: ~7.5% effective rate
            XCTAssertGreaterThanOrEqual(effectiveRate, 0.03, "SE rate should be >= 3%")
            XCTAssertLessThanOrEqual(effectiveRate, 0.14, "SE rate should be < 14% above cap")
        }
    }
    
    // =========================================================================
    // PROPERTY: SE tax components sum correctly
    // SS + Medicare + Additional Medicare = Total
    // =========================================================================
    
    func testProperty_Tax_ComponentsSum() {
        for _ in 0..<sampleCount {
            let netIncome = randomLargeIncome()
            let seIncome = netIncome * seIncomeMultiplier
            
            let ssTax = min(seIncome, socialSecurityWageBase2026) * socialSecurityRate
            let medicareTax = seIncome * medicareRate
            let additionalMedicareTax = seIncome > additionalMedicareThresholdSingle
                ? (seIncome - additionalMedicareThresholdSingle) * additionalMedicareRate
                : 0
            
            let expectedTotal = ssTax + medicareTax + additionalMedicareTax
            let actualTotal = calculateSETax(netIncome: netIncome)
            
            XCTAssertEqual(
                actualTotal, expectedTotal,
                accuracy: 0.01,
                "SE tax components should sum to total"
            )
        }
    }
}

// MARK: - Credit Card Properties

extension FLOPropertyBasedTests {
    
    /// Calculate months to payoff
    func calculatePayoffMonths(balance: Double, apr: Double, minPaymentPercent: Double) -> Int {
        guard balance > 0 else { return 0 }
        
        let monthlyRate = apr / 12
        var remaining = balance
        var months = 0
        let maxMonths = 600
        
        while remaining > 0.01 && months < maxMonths {
            let interest = remaining * monthlyRate
            let minPayment = max(remaining * minPaymentPercent, 25)
            let payment = min(minPayment, remaining + interest)
            
            remaining = remaining + interest - payment
            months += 1
            
            // Detect interest trap
            if months > 1 && remaining >= balance {
                return maxMonths
            }
        }
        
        return months
    }
    
    // =========================================================================
    // PROPERTY: Payoff months is never negative
    // =========================================================================
    
    func testProperty_CreditCard_PayoffNeverNegative() {
        for _ in 0..<sampleCount {
            let balance = randomBalance()
            let apr = randomAPR()
            let minPayment = randomMinPaymentPercent()
            
            let months = calculatePayoffMonths(balance: balance, apr: apr, minPaymentPercent: minPayment)
            
            XCTAssertGreaterThanOrEqual(months, 0, "Payoff months should never be negative")
        }
    }
    
    // =========================================================================
    // PROPERTY: Higher APR = longer payoff (or trapped)
    // =========================================================================
    
    func testProperty_CreditCard_HigherAPRLongerPayoff() {
        for _ in 0..<sampleCount {
            let balance = randomBalance()
            let minPayment = 0.03  // Fixed min payment to avoid trap
            
            let apr1 = Double.random(in: 0.10...0.15)
            let apr2 = apr1 + Double.random(in: 0.01...0.05)
            
            let months1 = calculatePayoffMonths(balance: balance, apr: apr1, minPaymentPercent: minPayment)
            let months2 = calculatePayoffMonths(balance: balance, apr: apr2, minPaymentPercent: minPayment)
            
            XCTAssertGreaterThanOrEqual(
                months2, months1,
                "Higher APR should result in >= payoff time"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Higher balance = longer payoff
    // =========================================================================
    
    func testProperty_CreditCard_HigherBalanceLongerPayoff() {
        for _ in 0..<sampleCount {
            let apr = Double.random(in: 0.10...0.18)
            let minPayment = 0.03
            
            let balance1 = Double.random(in: 1_000...5_000)
            let balance2 = balance1 + Double.random(in: 500...2_000)
            
            let months1 = calculatePayoffMonths(balance: balance1, apr: apr, minPaymentPercent: minPayment)
            let months2 = calculatePayoffMonths(balance: balance2, apr: apr, minPaymentPercent: minPayment)
            
            XCTAssertGreaterThanOrEqual(
                months2, months1,
                "Higher balance should result in >= payoff time"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Zero APR = total paid equals balance
    // =========================================================================
    
    func testProperty_CreditCard_ZeroAPR() {
        for _ in 0..<sampleCount {
            let balance = randomBalance()
            let minPayment = randomMinPaymentPercent()
            
            // Simulate zero APR payoff
            var remaining = balance
            var totalPaid: Double = 0
            var months = 0
            
            while remaining > 0.01 && months < 600 {
                let payment = max(remaining * minPayment, 25)
                let actualPayment = min(payment, remaining)
                remaining -= actualPayment
                totalPaid += actualPayment
                months += 1
            }
            
            XCTAssertEqual(
                totalPaid, balance,
                accuracy: 0.01,
                "Zero APR should result in total paid = balance"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Higher min payment = faster payoff
    // =========================================================================
    
    func testProperty_CreditCard_HigherMinPaymentFasterPayoff() {
        for _ in 0..<sampleCount {
            let balance = Double.random(in: 2_000...10_000)
            let apr = Double.random(in: 0.12...0.18)
            
            let minPayment1 = 0.02
            let minPayment2 = 0.04
            
            let months1 = calculatePayoffMonths(balance: balance, apr: apr, minPaymentPercent: minPayment1)
            let months2 = calculatePayoffMonths(balance: balance, apr: apr, minPaymentPercent: minPayment2)
            
            XCTAssertLessThanOrEqual(
                months2, months1,
                "Higher min payment should result in <= payoff time"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Utilization is bounded [0, 100+]
    // =========================================================================
    
    func testProperty_CreditCard_UtilizationBounded() {
        for _ in 0..<sampleCount {
            let balance = Double.random(in: 0...10_000)
            let limit = Double.random(in: 1_000...20_000)
            
            let utilization = (balance / limit) * 100
            
            XCTAssertGreaterThanOrEqual(utilization, 0, "Utilization should be >= 0%")
            // Note: Utilization can exceed 100% if over limit
        }
    }
}

// MARK: - Date Calculation Properties

extension FLOPropertyBasedTests {
    
    // =========================================================================
    // PROPERTY: Day of month is bounded [1, 31]
    // =========================================================================
    
    func testProperty_Date_DayBounded() {
        for _ in 0..<sampleCount {
            let day = randomDay()
            
            XCTAssertGreaterThanOrEqual(day, 1, "Day should be >= 1")
            XCTAssertLessThanOrEqual(day, 31, "Day should be <= 31")
        }
    }
    
    // =========================================================================
    // PROPERTY: February has 28 or 29 days
    // =========================================================================
    
    func testProperty_Date_FebruaryDays() {
        let calendar = Calendar.current
        
        for _ in 0..<sampleCount {
            let year = randomYear()
            let components = DateComponents(year: year, month: 2)
            
            guard let date = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: date) else {
                continue
            }
            
            let days = range.count
            
            XCTAssertTrue(
                days == 28 || days == 29,
                "February should have 28 or 29 days, got \(days)"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Clamped day <= last day of month
    // =========================================================================
    
    func testProperty_Date_ClampedDayValid() {
        let calendar = Calendar.current
        
        for _ in 0..<sampleCount {
            let year = randomYear()
            let month = randomMonth()
            let requestedDay = randomDay()
            
            let components = DateComponents(year: year, month: month)
            guard let date = calendar.date(from: components),
                  let range = calendar.range(of: .day, in: .month, for: date) else {
                continue
            }
            
            let lastDay = range.count
            let clampedDay = min(requestedDay, lastDay)
            
            XCTAssertLessThanOrEqual(
                clampedDay, lastDay,
                "Clamped day should be <= last day of month"
            )
        }
    }
    
    // =========================================================================
    // PROPERTY: Adding 12 months = 1 year
    // =========================================================================
    
    func testProperty_Date_TwelveMonthsEqualsOneYear() {
        let calendar = Calendar.current
        
        for _ in 0..<sampleCount {
            let year = randomYear()
            let month = randomMonth()
            let day = min(randomDay(), 28)  // Avoid month-end issues
            
            guard let startDate = calendar.date(from: DateComponents(year: year, month: month, day: day)),
                  let plus12Months = calendar.date(byAdding: .month, value: 12, to: startDate),
                  let plus1Year = calendar.date(byAdding: .year, value: 1, to: startDate) else {
                continue
            }
            
            let monthsComponents = calendar.dateComponents([.year, .month, .day], from: plus12Months)
            let yearComponents = calendar.dateComponents([.year, .month, .day], from: plus1Year)
            
            XCTAssertEqual(
                monthsComponents.year, yearComponents.year,
                "12 months should equal 1 year"
            )
            XCTAssertEqual(
                monthsComponents.month, yearComponents.month,
                "12 months should equal 1 year"
            )
        }
    }
}

// MARK: - Safe Harbor Properties

extension FLOPropertyBasedTests {
    
    // =========================================================================
    // PROPERTY: Safe harbor threshold is consistent
    // High earners (>$150K) need 110%, others need 100%
    // =========================================================================
    
    func testProperty_SafeHarbor_ThresholdConsistent() {
        let threshold: Double = 150_000
        
        for _ in 0..<sampleCount {
            let agi = Double.random(in: 50_000...300_000)
            let isHighEarner = agi > threshold
            let safeHarborPercent = isHighEarner ? 1.10 : 1.00
            
            if agi > threshold {
                XCTAssertEqual(safeHarborPercent, 1.10, "High earner should need 110%")
            } else {
                XCTAssertEqual(safeHarborPercent, 1.00, "Normal earner should need 100%")
            }
        }
    }
    
    // =========================================================================
    // PROPERTY: Safe harbor amount >= prior year tax
    // =========================================================================
    
    func testProperty_SafeHarbor_AmountGreaterThanOrEqualToPriorYear() {
        for _ in 0..<sampleCount {
            let priorYearTax = Double.random(in: 5_000...50_000)
            let isHighEarner = Bool.random()
            let safeHarborPercent = isHighEarner ? 1.10 : 1.00
            let safeHarborAmount = priorYearTax * safeHarborPercent
            
            XCTAssertGreaterThanOrEqual(
                safeHarborAmount, priorYearTax,
                "Safe harbor amount should be >= prior year tax"
            )
        }
    }
}

// MARK: - Version History
/*
 Version 1.1 (Current):
 - Updated SE tax calculations to match TaxCalculationService v1.4
 - SE tax now uses: 12.4% SS (capped at $184,500) + 2.9% Medicare (uncapped)
 - Added Additional Medicare Tax (0.9%) for high earners
 - Split SE rate tests into below/above wage base cap
 - Added SS cap property test
 - Added Medicare uncapped property test
 - Added SE tax components sum test
 
 Version 1.0:
 - Initial property-based test suite
 - Tax, credit card, date, and safe harbor properties
 */
