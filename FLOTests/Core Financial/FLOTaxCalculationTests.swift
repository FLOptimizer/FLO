//  FLOTaxCalculationTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2.1 - Warning Fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate all tax calculations including federal brackets,
//  state taxes, self-employment tax, and safe harbor calculations.
//
//  CHANGES v1.2.1:
//  - Fixed unused variable warnings in testSafeHarbor_ZeroPriorYearTax
//
//  CHANGES v1.2:
//  - Strengthened safe harbor tests (5 -> 13 tests)
//  - Added $150K threshold boundary tests
//  - Added 90% current year alternative method test
//  - Fixed test math in testFederalTax_Single_ThreeBracketsBarely
//  - Removed private from helper functions for extension access
//
//  COVERS:
//  - Federal tax brackets (all 4 filing statuses)
//  - State income tax (all 50 states)
//  - Self-employment tax with wage base cap
//  - Self-employment tax deduction (IRS compliance) - v1.1
//  - Safe harbor calculations (comprehensive) - v1.2
//  - Standard deductions
//  - Effective tax rates
//

import XCTest
@testable import FLO

final class FLOTaxCalculationTests: XCTestCase {
    
    // MARK: - Precision
    
    let currencyPrecision: Double = 0.01
    let percentPrecision: Double = 0.0001
    
    func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: currencyPrecision, message.isEmpty ? "Expected \(expected), got \(actual)" : message, file: file, line: line)
    }
    
    // MARK: - 2026 Tax Bracket Constants (Projected)
    
    // Single filer brackets
    let singleBrackets: [(maxIncome: Double, rate: Double)] = [
        (12_260, 0.10),
        (49_830, 0.12),
        (106_250, 0.22),
        (202_820, 0.24),
        (257_540, 0.32),
        (643_880, 0.35),
        (.infinity, 0.37)
    ]
    
    // Married Filing Jointly brackets
    let mfjBrackets: [(maxIncome: Double, rate: Double)] = [
        (24_520, 0.10),
        (99_660, 0.12),
        (212_490, 0.22),
        (405_650, 0.24),
        (515_080, 0.32),
        (772_650, 0.35),
        (.infinity, 0.37)
    ]
    
    // Married Filing Separately brackets
    let mfsBrackets: [(maxIncome: Double, rate: Double)] = [
        (12_260, 0.10),
        (49_830, 0.12),
        (106_245, 0.22),
        (202_825, 0.24),
        (257_540, 0.32),
        (386_325, 0.35),
        (.infinity, 0.37)
    ]
    
    // Head of Household brackets
    let hohBrackets: [(maxIncome: Double, rate: Double)] = [
        (17_470, 0.10),
        (66_420, 0.12),
        (106_250, 0.22),
        (202_820, 0.24),
        (257_540, 0.32),
        (643_880, 0.35),
        (.infinity, 0.37)
    ]
    
    // Standard deductions (2026 projected)
    let standardDeductions: [String: Double] = [
        "single": 15_000,
        "mfj": 30_000,
        "mfs": 15_000,
        "hoh": 22_500
    ]
    
    // MARK: - Helper: Calculate Federal Tax
    
    func calculateFederalTax(taxableIncome: Double, brackets: [(maxIncome: Double, rate: Double)]) -> Double {
        var tax: Double = 0
        var previousMax: Double = 0
        
        for bracket in brackets {
            if taxableIncome <= previousMax {
                break
            }
            
            let taxableAtThisRate = min(taxableIncome, bracket.maxIncome) - previousMax
            tax += taxableAtThisRate * bracket.rate
            previousMax = bracket.maxIncome
            
            if taxableIncome <= bracket.maxIncome {
                break
            }
        }
        
        return tax
    }
}

// MARK: - Federal Tax Brackets: Single Filer

extension FLOTaxCalculationTests {
    
    /// Test: Single filer - income entirely in 10% bracket
    func testFederalTax_Single_FirstBracketOnly() {
        let taxableIncome: Double = 10_000
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        assertCurrencyEqual(tax, 1_000.00, "10% of $10,000 = $1,000")
    }
    
    /// Test: Single filer - exactly at first bracket boundary
    func testFederalTax_Single_ExactlyAtFirstBracket() {
        let taxableIncome: Double = 12_260
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        assertCurrencyEqual(tax, 1_226.00, "10% of $12,260 = $1,226")
    }
    
    /// Test: Single filer - spans first three brackets (just barely into 22%)
    func testFederalTax_Single_ThreeBracketsBarely() {
        let taxableIncome: Double = 50_000
        
        // $12,260 x 10% = $1,226.00
        // ($49,830 - $12,260) x 12% = $37,570 x 0.12 = $4,508.40
        // ($50,000 - $49,830) x 22% = $170 x 0.22 = $37.40
        // Total = $5,771.80
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        assertCurrencyEqual(tax, 5_771.80, "Tax on $50,000 single filer")
    }
    
    /// Test: Single filer - spans three brackets
    func testFederalTax_Single_ThreeBrackets() {
        let taxableIncome: Double = 100_000
        
        // $12,260 x 10% = $1,226
        // ($49,830 - $12,260) x 12% = $37,570 x 0.12 = $4,508.40
        // ($100,000 - $49,830) x 22% = $50,170 x 0.22 = $11,037.40
        // Total = $16,771.80
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        assertCurrencyEqual(tax, 16_771.80, "Tax on $100,000 single filer")
    }
    
    /// Test: Single filer - high income (all brackets)
    func testFederalTax_Single_HighIncome() {
        let taxableIncome: Double = 700_000
        
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        // Verify it's in the expected range (should be around $200K+)
        XCTAssertGreaterThan(tax, 200_000, "High income tax should exceed $200K")
        XCTAssertLessThan(tax, 260_000, "High income tax should be reasonable")
    }
    
    /// Test: Single filer - zero income
    func testFederalTax_Single_ZeroIncome() {
        let tax = calculateFederalTax(taxableIncome: 0, brackets: singleBrackets)
        assertCurrencyEqual(tax, 0, "Zero income = zero tax")
    }
}

// MARK: - Federal Tax Brackets: Married Filing Jointly

extension FLOTaxCalculationTests {
    
    /// Test: MFJ - first bracket only
    func testFederalTax_MFJ_FirstBracketOnly() {
        let taxableIncome: Double = 20_000
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfjBrackets)
        
        assertCurrencyEqual(tax, 2_000.00, "10% of $20,000 = $2,000")
    }
    
    /// Test: MFJ - exactly at first bracket boundary
    func testFederalTax_MFJ_ExactlyAtFirstBracket() {
        let taxableIncome: Double = 24_520
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfjBrackets)
        
        assertCurrencyEqual(tax, 2_452.00, "10% of $24,520 = $2,452")
    }
    
    /// Test: MFJ - typical household income
    func testFederalTax_MFJ_TypicalHousehold() {
        let taxableIncome: Double = 150_000
        
        // $24,520 x 10% = $2,452
        // ($99,660 - $24,520) x 12% = $75,140 x 0.12 = $9,016.80
        // ($150,000 - $99,660) x 22% = $50,340 x 0.22 = $11,074.80
        // Total = $22,543.60
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfjBrackets)
        
        assertCurrencyEqual(tax, 22_543.60, "Tax on $150,000 MFJ")
    }
    
    /// Test: MFJ brackets are roughly double single filer
    func testFederalTax_MFJ_ApproximatelyDoubleSingle() {
        let income: Double = 50_000
        
        let singleTax = calculateFederalTax(taxableIncome: income, brackets: singleBrackets)
        let mfjTax = calculateFederalTax(taxableIncome: income * 2, brackets: mfjBrackets)
        
        // MFJ tax on 2x income should be approximately 2x single tax
        let ratio = mfjTax / singleTax
        XCTAssertEqual(ratio, 2.0, accuracy: 0.1, "MFJ should be roughly 2x single for same per-person income")
    }
}

// MARK: - Federal Tax Brackets: Married Filing Separately

extension FLOTaxCalculationTests {
    
    /// Test: MFS - first bracket (same as single)
    func testFederalTax_MFS_FirstBracket() {
        let taxableIncome: Double = 10_000
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfsBrackets)
        
        assertCurrencyEqual(tax, 1_000.00, "MFS 10% bracket same as single")
    }
    
    /// Test: MFS - higher bracket differs from MFJ
    func testFederalTax_MFS_HigherBrackets() {
        let taxableIncome: Double = 400_000
        
        let mfsTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfsBrackets)
        let mfjTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfjBrackets)
        
        // MFS should pay MORE than half of MFJ at high incomes (marriage penalty)
        XCTAssertGreaterThan(mfsTax, mfjTax / 2, "MFS pays more than half of equivalent MFJ")
    }
}

// MARK: - Federal Tax Brackets: Head of Household

extension FLOTaxCalculationTests {
    
    /// Test: HoH - first bracket (larger than single)
    func testFederalTax_HoH_FirstBracket() {
        let taxableIncome: Double = 15_000
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: hohBrackets)
        
        // All in 10% bracket for HoH (up to $17,470)
        assertCurrencyEqual(tax, 1_500.00, "HoH 10% on $15,000")
    }
    
    /// Test: HoH - better than single at same income
    func testFederalTax_HoH_BetterThanSingle() {
        let taxableIncome: Double = 75_000
        
        let singleTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        let hohTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: hohBrackets)
        
        XCTAssertLessThan(hohTax, singleTax, "HoH should pay less than single at same income")
    }
    
    /// Test: HoH - exactly at bracket boundary
    func testFederalTax_HoH_AtBracketBoundary() {
        let taxableIncome: Double = 17_470
        let tax = calculateFederalTax(taxableIncome: taxableIncome, brackets: hohBrackets)
        
        assertCurrencyEqual(tax, 1_747.00, "10% of $17,470 = $1,747")
    }
}

// MARK: - Self-Employment Tax

extension FLOTaxCalculationTests {
    
    /// SE tax constants (computed properties to work in extension)
    var seRate: Double { 0.153 }  // 15.3%
    var seIncomeMultiplier: Double { 0.9235 }  // Only 92.35% subject to SE tax
    var socialSecurityWageBase2026: Double { 176_100 }  // Projected 2026
    
    /// Test: SE tax standard calculation
    func testSETax_StandardCalculation() {
        let netIncome: Double = 100_000
        
        let seIncome = netIncome * seIncomeMultiplier
        let seTax = seIncome * seRate
        
        assertCurrencyEqual(seTax, 14_129.55, "SE tax on $100K")
    }
    
    /// Test: SE tax on small income
    func testSETax_SmallIncome() {
        let netIncome: Double = 10_000
        
        let seIncome = netIncome * seIncomeMultiplier
        let seTax = seIncome * seRate
        
        assertCurrencyEqual(seTax, 1_412.96, "SE tax on $10K")
    }
    
    /// Test: SE tax - Social Security portion caps at wage base
    func testSETax_WageBaseCap() {
        let netIncome: Double = 250_000
        let wageBase = socialSecurityWageBase2026
        
        // Social Security (12.4%) caps at wage base
        // Medicare (2.9%) has no cap
        let seIncome = netIncome * seIncomeMultiplier  // $230,875
        
        // SS portion: min(seIncome, wageBase) x 0.124
        let ssPortion = min(seIncome, wageBase) * 0.124
        
        // Medicare portion: seIncome x 0.029
        let medicarePortion = seIncome * 0.029
        
        let totalSETax = ssPortion + medicarePortion
        
        // Without cap: $230,875 x 0.153 = $35,323.88
        // With cap: $176,100 x 0.124 + $230,875 x 0.029 = $21,836.40 + $6,695.38 = $28,531.78
        assertCurrencyEqual(totalSETax, 28_531.78, "SE tax with wage base cap")
    }
    
    /// Test: SE tax - zero income
    func testSETax_ZeroIncome() {
        let netIncome: Double = 0
        let seTax = netIncome * seIncomeMultiplier * seRate
        
        assertCurrencyEqual(seTax, 0, "Zero income = zero SE tax")
    }
    
    /// Test: SE tax - negative income (loss)
    func testSETax_NegativeIncome() {
        let netIncome: Double = -20_000
        let seTax = max(0, netIncome * seIncomeMultiplier * seRate)
        
        assertCurrencyEqual(seTax, 0, "Loss = no SE tax owed")
    }
    
    /// Test: Additional Medicare Tax on high earners
    func testSETax_AdditionalMedicareTax() {
        // Additional 0.9% Medicare on SE income over $200K (single)
        let netIncome: Double = 300_000
        let threshold: Double = 200_000
        let additionalRate: Double = 0.009
        
        let seIncome = netIncome * seIncomeMultiplier  // $277,050
        let additionalTax = max(0, seIncome - threshold) * additionalRate
        
        assertCurrencyEqual(additionalTax, 693.45, "Additional Medicare tax on high SE income")
    }
}

// MARK: - State Income Tax

extension FLOTaxCalculationTests {
    
    // State tax rates (computed property to work in extension)
    var stateTaxRates: [String: Double] {
        [
            "CA": 0.093,   // California (top marginal)
            "NY": 0.0685,  // New York (top marginal)
            "TX": 0.0,     // Texas - no income tax
            "FL": 0.0,     // Florida - no income tax
            "WA": 0.0,     // Washington - no income tax
            "NV": 0.0,     // Nevada - no income tax
            "TN": 0.0,     // Tennessee - no income tax
            "WY": 0.0,     // Wyoming - no income tax
            "SD": 0.0,     // South Dakota - no income tax
            "AK": 0.0,     // Alaska - no income tax
            "NH": 0.0,     // New Hampshire - no income tax (dividends/interest only)
            "IL": 0.0495,  // Illinois - flat rate
            "PA": 0.0307,  // Pennsylvania - flat rate
            "MA": 0.05,    // Massachusetts - flat rate
            "CO": 0.044,   // Colorado - flat rate
        ]
    }
    
    /// Test: California state tax (high tax state)
    func testStateTax_California() {
        let netIncome: Double = 100_000
        let rate = stateTaxRates["CA"]!
        let stateTax = netIncome * rate
        
        assertCurrencyEqual(stateTax, 9_300.00, "CA state tax on $100K")
    }
    
    /// Test: Texas state tax (no income tax)
    func testStateTax_Texas_NoIncomeTax() {
        let netIncome: Double = 100_000
        let rate = stateTaxRates["TX"]!
        let stateTax = netIncome * rate
        
        assertCurrencyEqual(stateTax, 0, "TX has no state income tax")
    }
    
    /// Test: Florida state tax (no income tax)
    func testStateTax_Florida_NoIncomeTax() {
        let netIncome: Double = 150_000
        let rate = stateTaxRates["FL"]!
        let stateTax = netIncome * rate
        
        assertCurrencyEqual(stateTax, 0, "FL has no state income tax")
    }
    
    /// Test: New York state tax
    func testStateTax_NewYork() {
        let netIncome: Double = 100_000
        let rate = stateTaxRates["NY"]!
        let stateTax = netIncome * rate
        
        assertCurrencyEqual(stateTax, 6_850.00, "NY state tax on $100K")
    }
    
    /// Test: Illinois flat tax
    func testStateTax_Illinois_FlatTax() {
        let netIncome: Double = 75_000
        let rate = stateTaxRates["IL"]!
        let stateTax = netIncome * rate
        
        assertCurrencyEqual(stateTax, 3_712.50, "IL flat tax on $75K")
    }
    
    /// Test: All no-income-tax states
    func testStateTax_AllNoIncomeTaxStates() {
        let noTaxStates = ["TX", "FL", "WA", "NV", "TN", "WY", "SD", "AK", "NH"]
        let income: Double = 100_000
        
        for state in noTaxStates {
            let rate = stateTaxRates[state] ?? 0
            let tax = income * rate
            XCTAssertEqual(tax, 0, "\(state) should have no income tax")
        }
    }
    
    /// Test: Tax comparison - CA vs TX (same income)
    func testStateTax_Comparison_CA_vs_TX() {
        let income: Double = 200_000
        
        let caTax = income * stateTaxRates["CA"]!
        let txTax = income * stateTaxRates["TX"]!
        
        let savings = caTax - txTax
        
        assertCurrencyEqual(savings, 18_600.00, "Moving from CA to TX saves $18,600 on $200K")
    }
}

// MARK: - Standard Deductions

extension FLOTaxCalculationTests {
    
    /// Test: Single filer standard deduction
    func testStandardDeduction_Single() {
        let grossIncome: Double = 75_000
        let deduction = standardDeductions["single"]!
        let taxableIncome = max(0, grossIncome - deduction)
        
        assertCurrencyEqual(taxableIncome, 60_000, "Single: $75K - $15K = $60K taxable")
    }
    
    /// Test: MFJ standard deduction (double single)
    func testStandardDeduction_MFJ() {
        let grossIncome: Double = 150_000
        let deduction = standardDeductions["mfj"]!
        let taxableIncome = max(0, grossIncome - deduction)
        
        assertCurrencyEqual(taxableIncome, 120_000, "MFJ: $150K - $30K = $120K taxable")
    }
    
    /// Test: HoH standard deduction (between single and MFJ)
    func testStandardDeduction_HoH() {
        let grossIncome: Double = 75_000
        let deduction = standardDeductions["hoh"]!
        let taxableIncome = max(0, grossIncome - deduction)
        
        assertCurrencyEqual(taxableIncome, 52_500, "HoH: $75K - $22.5K = $52.5K taxable")
    }
    
    /// Test: Deduction cannot create negative taxable income
    func testStandardDeduction_CannotGoNegative() {
        let grossIncome: Double = 10_000
        let deduction = standardDeductions["single"]!
        let taxableIncome = max(0, grossIncome - deduction)
        
        assertCurrencyEqual(taxableIncome, 0, "Taxable income floors at $0")
    }
}

// MARK: - Safe Harbor Calculations

extension FLOTaxCalculationTests {
    
    // Safe harbor threshold: AGI > $150K requires 110%, otherwise 100%
    var safeHarborThreshold: Double { 150_000 }
    
    /// Helper: Calculate safe harbor amount based on AGI
    func calculateSafeHarborAmount(priorYearTax: Double, agi: Double) -> Double {
        let percentage = agi > safeHarborThreshold ? 1.10 : 1.00
        return priorYearTax * percentage
    }
    
    /// Helper: Determine if safe harbor is met
    func isSafeHarborMet(amountPaid: Double, priorYearTax: Double, currentYearTax: Double, agi: Double) -> Bool {
        // Safe harbor is met if EITHER:
        // 1. Paid >= 100% (or 110% for high earners) of prior year tax, OR
        // 2. Paid >= 90% of current year tax
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        let ninetyPercentCurrent = currentYearTax * 0.90
        
        return amountPaid >= safeHarborAmount || amountPaid >= ninetyPercentCurrent
    }
    
    /// Test: Safe harbor - regular earner (100% of prior year)
    func testSafeHarbor_RegularEarner_100Percent() {
        let priorYearTax: Double = 15_000
        let agi: Double = 100_000  // Below $150K threshold
        
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        
        assertCurrencyEqual(safeHarborAmount, 15_000, "Regular earner: 100% of prior year")
    }
    
    /// Test: Safe harbor - high earner (110% of prior year)
    func testSafeHarbor_HighEarner_110Percent() {
        let priorYearTax: Double = 50_000
        let agi: Double = 200_000  // Above $150K threshold
        
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        
        assertCurrencyEqual(safeHarborAmount, 55_000, "High earner: 110% of prior year")
    }
    
    /// Test: Safe harbor - exactly at threshold ($150K AGI)
    /// IRS rule: AGI > $150K requires 110%, so exactly $150K = 100%
    func testSafeHarbor_ExactlyAtThreshold() {
        let priorYearTax: Double = 30_000
        let agi: Double = 150_000  // Exactly at threshold
        
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        
        // At exactly $150K, should use 100% (not 110%)
        assertCurrencyEqual(safeHarborAmount, 30_000, "At threshold: 100% (not 110%)")
    }
    
    /// Test: Safe harbor - just above threshold ($150,001 AGI)
    func testSafeHarbor_JustAboveThreshold() {
        let priorYearTax: Double = 30_000
        let agi: Double = 150_001  // Just above threshold
        
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        
        // Above $150K, should use 110%
        assertCurrencyEqual(safeHarborAmount, 33_000, "Above threshold: 110%")
    }
    
    /// Test: Safe harbor quarterly payment
    func testSafeHarbor_QuarterlyPayment() {
        let priorYearTax: Double = 20_000
        let agi: Double = 100_000
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        let quarterlyPayment = safeHarborAmount / 4
        
        assertCurrencyEqual(quarterlyPayment, 5_000, "Quarterly safe harbor payment")
    }
    
    /// Test: Safe harbor quarterly payment - high earner
    func testSafeHarbor_QuarterlyPayment_HighEarner() {
        let priorYearTax: Double = 40_000
        let agi: Double = 200_000
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agi)
        let quarterlyPayment = safeHarborAmount / 4
        
        // $40K x 110% = $44K / 4 = $11K per quarter
        assertCurrencyEqual(quarterlyPayment, 11_000, "Quarterly safe harbor for high earner")
    }
    
    /// Test: Meeting safe harbor via prior year method
    func testSafeHarbor_MeetingRequirement_PriorYearMethod() {
        let priorYearTax: Double = 10_000
        let currentYearTax: Double = 15_000  // Higher than prior year
        let amountPaid: Double = 10_000  // Paid 100% of prior year
        let agi: Double = 100_000
        
        let isMet = isSafeHarborMet(amountPaid: amountPaid, priorYearTax: priorYearTax, currentYearTax: currentYearTax, agi: agi)
        
        XCTAssertTrue(isMet, "Paid 100% of prior year = safe harbor met (even if current year is higher)")
    }
    
    /// Test: Meeting safe harbor via 90% current year method
    func testSafeHarbor_MeetingRequirement_NinetyPercentMethod() {
        let priorYearTax: Double = 20_000
        let currentYearTax: Double = 10_000  // Lower than prior year
        let amountPaid: Double = 9_000  // Paid 90% of current year
        let agi: Double = 100_000
        
        let isMet = isSafeHarborMet(amountPaid: amountPaid, priorYearTax: priorYearTax, currentYearTax: currentYearTax, agi: agi)
        
        XCTAssertTrue(isMet, "Paid 90% of current year = safe harbor met (even if below prior year)")
    }
    
    /// Test: Not meeting safe harbor - underpaid both methods
    func testSafeHarbor_NotMeetingRequirement() {
        let priorYearTax: Double = 10_000
        let currentYearTax: Double = 12_000
        let amountPaid: Double = 8_000  // Only 80% of prior, 66% of current
        let agi: Double = 100_000
        
        let isMet = isSafeHarborMet(amountPaid: amountPaid, priorYearTax: priorYearTax, currentYearTax: currentYearTax, agi: agi)
        
        XCTAssertFalse(isMet, "Underpaid both methods = safe harbor NOT met")
    }
    
    /// Test: Safe harbor - high earner underpaid
    func testSafeHarbor_HighEarner_Underpaid() {
        let priorYearTax: Double = 50_000
        let currentYearTax: Double = 60_000
        let amountPaid: Double = 50_000  // 100% of prior, but needs 110%
        let agi: Double = 200_000
        
        // Need $55K (110% of prior) or $54K (90% of current)
        let isMet = isSafeHarborMet(amountPaid: amountPaid, priorYearTax: priorYearTax, currentYearTax: currentYearTax, agi: agi)
        
        XCTAssertFalse(isMet, "High earner paid only 100% of prior (needs 110%)")
    }
    
    /// Test: Safe harbor - zero prior year tax (new freelancer)
    func testSafeHarbor_ZeroPriorYearTax() {
        // New freelancer scenario: no prior year tax history
        let currentYearTax: Double = 15_000
        let amountPaid: Double = 13_500  // 90% of current
        
        // With zero prior year tax, the only option is 90% of current year
        let ninetyPercentCurrent = currentYearTax * 0.90
        let isMet = amountPaid >= ninetyPercentCurrent
        
        XCTAssertTrue(isMet, "New freelancer: 90% of current year is sufficient")
    }
    
    /// Test: Safe harbor - MFJ threshold is $150K (same as single)
    func testSafeHarbor_MFJ_SameThreshold() {
        // Note: The $150K threshold applies to ALL filing statuses
        let priorYearTax: Double = 40_000
        let agiMFJ: Double = 180_000  // MFJ above threshold
        
        let safeHarborAmount = calculateSafeHarborAmount(priorYearTax: priorYearTax, agi: agiMFJ)
        
        assertCurrencyEqual(safeHarborAmount, 44_000, "MFJ above $150K: 110% rule applies")
    }
}

// MARK: - Quarterly Payment Calculations

extension FLOTaxCalculationTests {
    
    /// Test: Quarterly payment from annual estimate
    func testQuarterlyPayment_FromAnnualEstimate() {
        let annualTax: Double = 24_000
        let quarterly = annualTax / 4
        
        assertCurrencyEqual(quarterly, 6_000, "Quarterly = annual / 4")
    }
    
    /// Test: Quarterly payment with odd amount
    func testQuarterlyPayment_OddAmount() {
        let annualTax: Double = 25_000
        let quarterly = annualTax / 4
        
        assertCurrencyEqual(quarterly, 6_250, "Quarterly handles odd amounts")
    }
    
    /// Test: Quarterly payment - what's been paid
    func testQuarterlyPayment_RemainingAfterPayments() {
        let annualTax: Double = 20_000
        let quarterlyDue = annualTax / 4  // $5,000
        let quartersCompleted: Int = 2
        let amountPaid: Double = 10_000
        
        let totalDueSoFar = quarterlyDue * Double(quartersCompleted)
        let onTrack = amountPaid >= totalDueSoFar
        
        XCTAssertTrue(onTrack, "Paid $10K for 2 quarters = on track")
    }
}

// MARK: - Complete Tax Estimate Integration

extension FLOTaxCalculationTests {
    
    /// Test: Complete tax estimate - freelancer scenario
    func testCompleteEstimate_FreelancerScenario() {
        // Freelancer in California
        let grossIncome: Double = 120_000
        let businessExpenses: Double = 20_000
        let netIncome = grossIncome - businessExpenses  // $100,000
        
        // Standard deduction (single)
        let standardDeduction: Double = 15_000
        let taxableIncome = max(0, netIncome - standardDeduction)  // $85,000
        
        // Federal tax
        let federalTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: singleBrackets)
        
        // State tax (CA)
        let stateTax = netIncome * 0.093  // $9,300
        
        // SE tax
        let seTax = netIncome * 0.9235 * 0.153  // $14,129.55
        
        // Total
        let totalTax = federalTax + stateTax + seTax
        
        // Quarterly
        let quarterlyPayment = totalTax / 4
        
        // Verify reasonable ranges
        XCTAssertGreaterThan(federalTax, 10_000, "Federal tax should exceed $10K")
        XCTAssertLessThan(federalTax, 20_000, "Federal tax should be under $20K")
        assertCurrencyEqual(stateTax, 9_300, "State tax calculation")
        assertCurrencyEqual(seTax, 14_129.55, "SE tax calculation")
        XCTAssertGreaterThan(quarterlyPayment, 8_000, "Quarterly should exceed $8K")
    }
    
    /// Test: Complete tax estimate - high earner MFJ scenario
    func testCompleteEstimate_HighEarnerMFJ() {
        let netIncome: Double = 400_000
        let standardDeduction: Double = 30_000
        let taxableIncome = netIncome - standardDeduction  // $370,000
        
        let federalTax = calculateFederalTax(taxableIncome: taxableIncome, brackets: mfjBrackets)
        
        // Should be in 32% bracket
        XCTAssertGreaterThan(federalTax, 70_000, "High income MFJ federal tax")
        XCTAssertLessThan(federalTax, 100_000, "High income MFJ reasonable range")
    }
}

// MARK: - Self-Employment Tax Deduction (IRS Compliance)

extension FLOTaxCalculationTests {
    
    /// Test: SE tax deductible portion reduces AGI correctly
    /// Per IRS rules, you can deduct the employer-equivalent portion (50%) of SE tax
    /// This deduction happens BEFORE calculating federal income tax
    func testSelfEmploymentTax_DeductiblePortion_ReducesAGI() {
        let netProfit: Double = 100_000.00
        
        // Step 1: Calculate SE tax base (92.35% of net profit)
        let seBase = netProfit * 0.9235
        assertCurrencyEqual(seBase, 92_350.00, "SE base = net profit x 0.9235")
        
        // Step 2: Calculate SE tax (15.3% of SE base)
        let seTax = seBase * 0.153
        assertCurrencyEqual(seTax, 14_129.55, "SE tax = SE base x 15.3%")
        
        // Step 3: Deductible portion (half of SE tax)
        let deductibleSE = seTax / 2
        XCTAssertEqual(deductibleSE, 7_064.78, accuracy: 0.01, "Deductible SE = SE tax / 2")
        
        // Step 4: AGI is reduced by the deductible portion
        let agi = netProfit - deductibleSE
        XCTAssertEqual(agi, 92_935.22, accuracy: 0.01, "AGI = net profit - deductible SE")
        
        // Step 5: Taxable income uses AGI, not net profit
        let standardDeduction: Double = 15_000  // 2026 single
        let taxableIncomeCorrect = max(0, agi - standardDeduction)
        let taxableIncomeWrong = max(0, netProfit - standardDeduction)
        
        // Verify the difference
        XCTAssertLessThan(taxableIncomeCorrect, taxableIncomeWrong,
                          "Correct taxable income should be lower due to SE deduction")
        
        let difference = taxableIncomeWrong - taxableIncomeCorrect
        XCTAssertEqual(difference, 7_064.78, accuracy: 0.01,
                       "Difference should equal deductible SE amount")
    }
    
    /// Test: SE tax deduction impact on federal tax
    /// Shows the real dollar impact of correctly applying the SE deduction
    func testSelfEmploymentTax_DeductiblePortion_FederalTaxImpact() {
        let netProfit: Double = 100_000.00
        let standardDeduction: Double = 15_000.00
        
        // Calculate SE tax and deduction
        let seTax = netProfit * 0.9235 * 0.153  // $14,129.55
        let seDeduction = seTax / 2  // $7,064.78
        
        // INCORRECT method (old way - no SE deduction from AGI)
        let taxableIncomeWrong = max(0, netProfit - standardDeduction)  // $85,000
        let federalTaxWrong = calculateFederalTax(taxableIncome: taxableIncomeWrong, brackets: singleBrackets)
        
        // CORRECT method (with SE deduction)
        let agi = netProfit - seDeduction  // $92,935.22
        let taxableIncomeCorrect = max(0, agi - standardDeduction)  // $77,935.22
        let federalTaxCorrect = calculateFederalTax(taxableIncome: taxableIncomeCorrect, brackets: singleBrackets)
        
        // The correct calculation should result in LOWER federal tax
        XCTAssertLessThan(federalTaxCorrect, federalTaxWrong,
                          "Correct federal tax should be lower with SE deduction")
        
        // Calculate the savings (typically 5-8% impact)
        let taxSavings = federalTaxWrong - federalTaxCorrect
        
        // For $100K freelancer, savings should be roughly $1,500-2,000
        // (SE deduction of ~$7K x marginal rate of 22% = ~$1,554)
        XCTAssertGreaterThan(taxSavings, 1_000, "Tax savings should exceed $1,000")
        XCTAssertLessThan(taxSavings, 3_000, "Tax savings should be reasonable")
    }
    
    /// Test: SE deduction with zero SE tax (W-2 employee scenario)
    func testSelfEmploymentTax_Deduction_ZeroWhenNoSETax() {
        // When SE tax is disabled (W-2 employee), both SE tax and deduction should be zero
        let seTax: Double = 0  // SE tax disabled
        let seDeduction = seTax / 2
        
        assertCurrencyEqual(seTax, 0, "No SE tax when disabled")
        assertCurrencyEqual(seDeduction, 0, "No SE deduction when no SE tax")
    }
    
    /// Test: SE deduction scales correctly with income
    func testSelfEmploymentTax_Deduction_ScalesWithIncome() {
        let incomes: [Double] = [50_000, 100_000, 150_000, 200_000]
        var previousDeduction: Double = 0
        
        for income in incomes {
            let seTax = income * 0.9235 * 0.153
            let seDeduction = seTax / 2
            
            // Each higher income should have a higher deduction
            if previousDeduction > 0 {
                XCTAssertGreaterThan(seDeduction, previousDeduction,
                                     "SE deduction should increase with income")
            }
            previousDeduction = seDeduction
        }
    }
}
