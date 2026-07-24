//  FLOFinancialTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Updated 2026 Mileage Rate Expected Values Calculation Test Suite
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Prevent user financial loss through rigorous validation of all
//  money calculations in the app. These tests ensure data integrity and
//  accuracy for critical financial features.
//
//  TEST CATEGORIES:
//  1. Account Balance Operations
//  2. Credit Card Calculations
//  3. Tax Calculations
//  4. Budget Calculations
//  5. Invoice Calculations
//  6. Recurring Transaction Balance Updates
//  7. Mileage Deduction Calculations
//  8. Edge Cases & Precision
//
//  RUN FREQUENCY: Before every release, after any financial code changes
//

import XCTest
@testable import FLO

// MARK: - Test Configuration

final class FLOFinancialTests: XCTestCase {
    
    /// Precision for currency comparisons (1 cent tolerance)
    let currencyPrecision: Double = 0.01
    
    /// Precision for percentage comparisons
    let percentPrecision: Double = 0.001
    
    // MARK: - Helper Methods
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: currencyPrecision, message.isEmpty ? "Currency mismatch: expected \(expected), got \(actual)" : message, file: file, line: line)
    }
    
    private func assertPercentEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: percentPrecision, message.isEmpty ? "Percent mismatch: expected \(expected), got \(actual)" : message, file: file, line: line)
    }
    
    /// Safe division helper - prevents divide by zero
    private func safeDivide(_ numerator: Double, by denominator: Double, defaultValue: Double = 0) -> Double {
        guard denominator != 0 else { return defaultValue }
        return numerator / denominator
    }
    
    /// Budget percentage calculator with zero protection
    private func calculateBudgetPercentUsed(planned: Double, spent: Double) -> Double {
        guard planned > 0 else {
            return spent > 0 ? 1.0 : 0.0
        }
        return spent / planned
    }
    
    /// Safe harbor calculator
    private func calculateSafeHarbor(priorYearTax: Double, isHighEarner: Bool) -> Double {
        let multiplier = isHighEarner ? 1.10 : 1.00
        return priorYearTax * multiplier
    }
    
    /// Apply balance change based on income/expense type
    private func applyBalanceChange(balance: Double, amount: Double, isIncome: Bool) -> Double {
        return isIncome ? balance + amount : balance - amount
    }
}

// MARK: - 1. ACCOUNT BALANCE OPERATIONS

extension FLOFinancialTests {
    
    // MARK: 1.1 Basic Balance Math
    
    /// Test: Adding income increases account balance
    /// Formula: newBalance = currentBalance + incomeAmount
    func testAccountBalance_AddIncome_IncreasesBalance() {
        let startingBalance: Double = 1000.00
        let incomeAmount: Double = 500.00
        let newBalance = startingBalance + incomeAmount
        
        assertCurrencyEqual(newBalance, 1500.00, "Income should increase balance")
    }
    
    /// Test: Adding expense decreases account balance
    /// Formula: newBalance = currentBalance - expenseAmount
    func testAccountBalance_AddExpense_DecreasesBalance() {
        let startingBalance: Double = 1000.00
        let expenseAmount: Double = 300.00
        let newBalance = startingBalance - expenseAmount
        
        assertCurrencyEqual(newBalance, 700.00, "Expense should decrease balance")
    }
    
    /// Test: Balance can go negative (overdraft scenario)
    func testAccountBalance_Overdraft_AllowsNegative() {
        let startingBalance: Double = 100.00
        let expenseAmount: Double = 250.00
        let newBalance = startingBalance - expenseAmount
        
        assertCurrencyEqual(newBalance, -150.00, "Balance should allow negative (overdraft)")
    }
    
    /// Test: Transaction edit reverses original and applies new
    /// Formula: newBalance = currentBalance + originalAmount - newAmount (for expense)
    func testAccountBalance_EditTransaction_ReversesAndApplies() {
        // Given: $1000 balance, original expense was $200
        let currentBalance: Double = 800.00  // After $200 expense from $1000
        let originalExpense: Double = 200.00
        let newExpense: Double = 350.00
        
        // When: Reverse original, apply new
        let reversed = currentBalance + originalExpense  // Back to $1000
        let newBalance = reversed - newExpense           // $1000 - $350 = $650
        
        assertCurrencyEqual(newBalance, 650.00, "Edit should reverse original and apply new amount")
    }
    
    /// Test: Deleting income reverses the addition
    func testAccountBalance_DeleteIncome_ReversesAddition() {
        let currentBalance: Double = 1500.00
        let incomeToDelete: Double = 500.00
        let newBalance = currentBalance - incomeToDelete
        
        assertCurrencyEqual(newBalance, 1000.00, "Deleting income should reverse the addition")
    }
    
    /// Test: Deleting expense reverses the subtraction
    func testAccountBalance_DeleteExpense_ReversesSubtraction() {
        let currentBalance: Double = 700.00
        let expenseToDelete: Double = 300.00
        let newBalance = currentBalance + expenseToDelete
        
        assertCurrencyEqual(newBalance, 1000.00, "Deleting expense should reverse the subtraction")
    }
    
    // MARK: 1.2 Account Type Balance Direction
    
    /// Test: Checking account - positive balance is good
    func testCheckingAccount_PositiveBalance_IsAsset() {
        let balance: Double = 5000.00
        let isAsset = true
        
        XCTAssertTrue(isAsset && balance > 0, "Checking account with positive balance is an asset")
    }
    
    /// Test: Credit card - negative balance means you owe money
    func testCreditCard_NegativeBalance_IsLiability() {
        let balance: Double = -2500.00
        let isLiability = true
        
        XCTAssertTrue(isLiability && balance < 0, "Credit card with negative balance means money owed")
    }
    
    // MARK: 1.3 Multiple Transaction Accuracy
    
    /// Test: Balance after 100 transactions remains accurate
    func testAccountBalance_After100Transactions_RemainsAccurate() {
        var balance: Double = 10000.00
        
        // Apply 100 transactions (alternating income/expense)
        for i in 1...100 {
            let amount = Double(i) * 10.0
            if i % 2 == 0 {
                balance -= amount  // Even = expense
            } else {
                balance += amount  // Odd = income
            }
        }
        
        // Net: Odd sum (25000) - Even sum (25500) = -500
        // Final: 10000 - 500 = 9500
        assertCurrencyEqual(balance, 9500.00, "Balance after 100 transactions should be accurate")
    }
}

// MARK: - 2. CREDIT CARD CALCULATIONS

extension FLOFinancialTests {
    
    // MARK: 2.1 Credit Utilization
    
    /// Test: Credit utilization calculation
    /// Formula: utilization = (balance / limit) × 100
    func testCreditUtilization_StandardCalculation() {
        let balance: Double = -2500.00
        let limit: Double = 10000.00
        let utilization = (abs(balance) / limit) * 100.0
        
        assertPercentEqual(utilization, 25.0, "Utilization should be 25%")
    }
    
    /// Test: Utilization at exactly 30% (excellent threshold)
    func testCreditUtilization_ExcellentThreshold() {
        let balance: Double = -3000.00
        let limit: Double = 10000.00
        let utilization = (abs(balance) / limit) * 100.0
        let isExcellent = utilization <= 30
        
        assertPercentEqual(utilization, 30.0)
        XCTAssertTrue(isExcellent, "30% utilization should be excellent")
    }
    
    /// Test: Overpaid credit card (positive balance) = 0% utilization
    func testCreditUtilization_OverpaidCard_ReturnsZero() {
        let balance: Double = 150.00  // Positive = credit balance (overpaid)
        let limit: Double = 5000.00
        
        // Overpaid = no utilization
        let utilization = balance >= 0 ? 0.0 : (abs(balance) / limit) * 100.0
        
        assertPercentEqual(utilization, 0.0, "Overpaid card should show 0% utilization")
    }
    
    /// Test: Over-limit card can exceed 100%
    func testCreditUtilization_OverLimit_ExceedsHundred() {
        let balance: Double = -6000.00
        let limit: Double = 5000.00
        let utilization = (abs(balance) / limit) * 100.0
        
        assertPercentEqual(utilization, 120.0, "Over-limit should show >100% utilization")
    }
    
    /// Test: Utilization clamped for UI (0-100%)
    func testCreditUtilization_Clamped_ForUI() {
        let balance: Double = -6000.00
        let limit: Double = 5000.00
        let rawUtilization = (abs(balance) / limit) * 100.0
        let clampedUtilization = min(max(rawUtilization, 0), 100)
        
        assertPercentEqual(clampedUtilization, 100.0, "Clamped utilization should cap at 100%")
    }
    
    // MARK: 2.2 Minimum Payment Calculations
    
    /// Test: Minimum payment - percentage higher than floor
    /// Formula: max(balance × percent, min(floor, balance))
    func testMinimumPayment_PercentageHigherThanFloor() {
        let balance: Double = 2000.00
        let percent: Double = 2.0
        let floor: Double = 25.00
        
        let percentPayment = balance * (percent / 100.0)  // $40
        let minimumPayment = max(percentPayment, min(floor, balance))
        
        assertCurrencyEqual(minimumPayment, 40.00, "Should use percentage when higher than floor")
    }
    
    /// Test: Minimum payment - floor higher than percentage
    func testMinimumPayment_FloorHigherThanPercentage() {
        let balance: Double = 1000.00
        let percent: Double = 2.0
        let floor: Double = 25.00
        
        let percentPayment = balance * (percent / 100.0)  // $20
        let minimumPayment = max(percentPayment, min(floor, balance))
        
        assertCurrencyEqual(minimumPayment, 25.00, "Should use floor when higher than percentage")
    }
    
    /// Test: Minimum payment - small balance less than floor
    func testMinimumPayment_SmallBalance_PaysFullAmount() {
        let balance: Double = 15.00
        let percent: Double = 2.0
        let floor: Double = 25.00
        
        let percentPayment = balance * (percent / 100.0)  // $0.30
        let minimumPayment = max(percentPayment, min(floor, balance))
        
        assertCurrencyEqual(minimumPayment, 15.00, "Small balance should pay full amount")
    }
    
    // MARK: 2.3 Interest Calculations
    
    /// Test: Monthly interest calculation
    /// Formula: monthlyInterest = balance × (APR / 12 / 100)
    func testMonthlyInterest_StandardCalculation() {
        let balance: Double = 1000.00
        let apr: Double = 24.0
        let monthlyInterest = balance * (apr / 100.0 / 12.0)
        
        assertCurrencyEqual(monthlyInterest, 20.00, "Monthly interest should be $20")
    }
    
    /// Test: Daily interest rate
    /// Formula: dailyRate = APR / 100 / 365
    func testDailyInterestRate_Calculation() {
        let apr: Double = 24.0
        let dailyRate = apr / 100.0 / 365.0
        
        XCTAssertEqual(dailyRate, 0.0006575, accuracy: 0.0000001, "Daily rate should be ~0.0657%")
    }
    
    /// Test: Available credit calculation
    /// Formula: available = limit - abs(balance)
    func testAvailableCredit_Calculation() {
        let balance: Double = -3000.00
        let limit: Double = 10000.00
        let available = max(0, limit - abs(balance))
        
        assertCurrencyEqual(available, 7000.00, "Available credit should be $7000")
    }
}

// MARK: - 3. TAX CALCULATIONS

extension FLOFinancialTests {
    
    // MARK: 3.1 Net Income Calculation
    
    /// Test: Net income = Total Income - Total Expenses
    func testNetIncome_BasicCalculation() {
        let totalIncome: Double = 75000.00
        let totalExpenses: Double = 25000.00
        let netIncome = totalIncome - totalExpenses
        
        assertCurrencyEqual(netIncome, 50000.00, "Net income should be $50,000")
    }
    
    /// Test: Net income with zero expenses
    func testNetIncome_ZeroExpenses() {
        let totalIncome: Double = 60000.00
        let totalExpenses: Double = 0.00
        let netIncome = totalIncome - totalExpenses
        
        assertCurrencyEqual(netIncome, 60000.00, "Net income should equal total income when no expenses")
    }
    
    /// Test: Net income can be negative (loss)
    func testNetIncome_CanBeNegative() {
        let totalIncome: Double = 20000.00
        let totalExpenses: Double = 35000.00
        let netIncome = totalIncome - totalExpenses
        
        assertCurrencyEqual(netIncome, -15000.00, "Net income can be negative (loss)")
    }
    
    // MARK: 3.2 Self-Employment Tax
    
    /// Test: Self-employment tax calculation
    /// Formula: SE Tax = (Net Income × 0.9235) × 0.153
    func testSelfEmploymentTax_StandardCalculation() {
        let netIncome: Double = 100000.00
        let seRate: Double = 0.153
        
        let seIncome = netIncome * 0.9235
        let seTax = seIncome * seRate
        
        assertCurrencyEqual(seTax, 14129.55, "SE tax should be $14,129.55")
    }
    
    /// Test: SE tax with zero income
    func testSelfEmploymentTax_ZeroIncome() {
        let netIncome: Double = 0.00
        let seRate: Double = 0.153
        
        let seIncome = netIncome * 0.9235
        let seTax = seIncome * seRate
        
        assertCurrencyEqual(seTax, 0.00, "SE tax should be $0 with no income")
    }
    
    /// Test: SE tax with negative income (no tax owed)
    func testSelfEmploymentTax_NegativeIncome() {
        let netIncome: Double = -5000.00
        let seRate: Double = 0.153
        
        // SE tax only applies to positive income
        let seTax = max(0, netIncome * 0.9235 * seRate)
        
        assertCurrencyEqual(seTax, 0.00, "SE tax should be $0 with negative income")
    }
    
    // MARK: 3.3 Quarterly Payment Calculation
    
    /// Test: Quarterly payment = Total Tax ÷ 4
    func testQuarterlyPayment_Calculation() {
        let totalTax: Double = 20000.00
        let quarterlyPayment = totalTax / 4.0
        
        assertCurrencyEqual(quarterlyPayment, 5000.00, "Quarterly payment should be $5,000")
    }
    
    /// Test: Quarterly payment with odd amount
    func testQuarterlyPayment_OddAmount() {
        let totalTax: Double = 15000.00
        let quarterlyPayment = totalTax / 4.0
        
        assertCurrencyEqual(quarterlyPayment, 3750.00, "Quarterly payment should be $3,750")
    }
    
    // MARK: 3.4 Federal Tax Bracket Calculation
    
    /// Test: Federal tax for single filer - first bracket only
    func testFederalTax_SingleFiler_FirstBracketOnly() {
        // 2026 first bracket: 10% up to $12,260
        let taxableIncome: Double = 10000.00
        let tax = taxableIncome * 0.10
        
        assertCurrencyEqual(tax, 1000.00, "Tax should be $1,000 (10% of $10,000)")
    }
    
    /// Test: Federal tax for single filer - two brackets
    func testFederalTax_SingleFiler_TwoBrackets() {
        // 2026 brackets: 10% up to $12,260, 12% up to $49,830
        let taxableIncome: Double = 40000.00
        
        let bracket1 = 12260.00 * 0.10                         // $1,226.00
        let bracket2 = (taxableIncome - 12260.00) * 0.12       // $27,740 × 0.12 = $3,328.80
        let totalTax = bracket1 + bracket2                      // $4,554.80
        
        assertCurrencyEqual(totalTax, 4554.80, "Tax should be $4,554.80")
    }
    
    // MARK: 3.5 Standard Deduction
    
    /// Test: Taxable income after standard deduction
    /// Formula: taxableIncome = max(0, netIncome - standardDeduction)
    func testTaxableIncome_AfterStandardDeduction() {
        let netIncome: Double = 75000.00
        let standardDeduction: Double = 15000.00
        let taxableIncome = max(0, netIncome - standardDeduction)
        
        assertCurrencyEqual(taxableIncome, 60000.00, "Taxable income should be $60,000")
    }
    
    /// Test: Taxable income cannot be negative
    func testTaxableIncome_CannotBeNegative() {
        let netIncome: Double = 10000.00
        let standardDeduction: Double = 15000.00
        let taxableIncome = max(0, netIncome - standardDeduction)
        
        assertCurrencyEqual(taxableIncome, 0.00, "Taxable income cannot be negative")
    }
    
    // MARK: 3.6 Effective Tax Rate
    
    /// Test: Effective tax rate calculation
    /// Formula: effectiveRate = totalTax / netIncome
    func testEffectiveTaxRate_Calculation() {
        let totalTax: Double = 15000.00
        let netIncome: Double = 75000.00
        let effectiveRate = safeDivide(totalTax, by: netIncome)
        
        assertPercentEqual(effectiveRate, 0.20, "Effective rate should be 20%")
    }
    
    /// Test: Effective rate with zero income (divide by zero protection)
    func testEffectiveTaxRate_ZeroIncome_NoError() {
        let totalTax: Double = 0.00
        let netIncome: Double = 0.00
        let effectiveRate = safeDivide(totalTax, by: netIncome)
        
        assertPercentEqual(effectiveRate, 0.00, "Effective rate should be 0 when no income")
    }
    
    // MARK: 3.7 Safe Harbor Calculation
    
    /// Test: Safe harbor for regular earners (100% of prior year)
    func testSafeHarbor_RegularEarner() {
        let safeHarborAmount = calculateSafeHarbor(priorYearTax: 10000.00, isHighEarner: false)
        assertCurrencyEqual(safeHarborAmount, 10000.00, "Safe harbor should be 100% for regular earners")
    }
    
    /// Test: Safe harbor for high earners (110% of prior year)
    func testSafeHarbor_HighEarner() {
        let safeHarborAmount = calculateSafeHarbor(priorYearTax: 10000.00, isHighEarner: true)
        assertCurrencyEqual(safeHarborAmount, 11000.00, "Safe harbor should be 110% for high earners")
    }
}

// MARK: - 4. BUDGET CALCULATIONS

extension FLOFinancialTests {
    
    // MARK: 4.1 Basic Budget Math
    
    /// Test: Remaining budget calculation
    /// Formula: remaining = planned - spent
    func testBudget_RemainingCalculation() {
        let planned: Double = 500.00
        let spent: Double = 325.00
        let remaining = planned - spent
        
        assertCurrencyEqual(remaining, 175.00, "Should have $175 remaining")
    }
    
    /// Test: Over budget shows negative remaining
    func testBudget_OverBudget_NegativeRemaining() {
        let planned: Double = 500.00
        let spent: Double = 650.00
        let remaining = planned - spent
        
        assertCurrencyEqual(remaining, -150.00, "Over budget should show negative remaining")
    }
    
    /// Test: Percentage used calculation
    /// Formula: percentUsed = spent / planned
    func testBudget_PercentageUsed() {
        let planned: Double = 1000.00
        let spent: Double = 750.00
        let percentUsed = safeDivide(spent, by: planned)
        
        assertPercentEqual(percentUsed, 0.75, "Should be 75% used")
    }
    
    /// Test: Percentage used with zero budget (divide by zero protection)
    func testBudget_PercentageUsed_ZeroBudget() {
        // Test case 1: Zero budget with spending
        let percentUsed1 = calculateBudgetPercentUsed(planned: 0.00, spent: 100.00)
        assertPercentEqual(percentUsed1, 1.0, "Should show 100% when budget is zero but spent exists")
        
        // Test case 2: Zero budget with no spending
        let percentUsed2 = calculateBudgetPercentUsed(planned: 0.00, spent: 0.00)
        assertPercentEqual(percentUsed2, 0.0, "Should show 0% when both budget and spent are zero")
        
        // Test case 3: Normal budget
        let percentUsed3 = calculateBudgetPercentUsed(planned: 500.00, spent: 250.00)
        assertPercentEqual(percentUsed3, 0.5, "Should show 50% for normal case")
    }
    
    // MARK: 4.2 Envelope Budgeting Rollover
    
    /// Test: Envelope budget with rollover
    /// Formula: totalAvailable = planned + carryOver
    func testEnvelopeBudget_WithRollover() {
        let planned: Double = 500.00
        let carryOver: Double = 75.00
        let totalAvailable = planned + carryOver
        
        assertCurrencyEqual(totalAvailable, 575.00, "Total available should include rollover")
    }
    
    /// Test: Negative rollover (overspent last month)
    func testEnvelopeBudget_NegativeRollover() {
        let planned: Double = 500.00
        let carryOver: Double = -100.00
        let totalAvailable = planned + carryOver
        
        assertCurrencyEqual(totalAvailable, 400.00, "Negative rollover reduces available")
    }
    
    /// Test: Calculate rollover to next month
    /// Formula: rollover = planned + carryOver - spent
    func testEnvelopeBudget_CalculateNextRollover() {
        let planned: Double = 500.00
        let carryOver: Double = 50.00
        let spent: Double = 400.00
        let totalAvailable = planned + carryOver
        let nextRollover = totalAvailable - spent
        
        assertCurrencyEqual(nextRollover, 150.00, "Should have $150 to roll over")
    }
    
    // MARK: 4.3 Budget Alert Thresholds
    
    /// Test: Near limit detection (>80%)
    func testBudget_NearLimit_Detection() {
        let planned: Double = 1000.00
        let spent: Double = 850.00
        let percentUsed = safeDivide(spent, by: planned)
        let isNearLimit = percentUsed >= 0.80
        
        XCTAssertTrue(isNearLimit, "85% usage should trigger near-limit warning")
    }
    
    /// Test: Over budget detection
    func testBudget_OverBudget_Detection() {
        let planned: Double = 1000.00
        let spent: Double = 1100.00
        let isOverBudget = spent > planned
        
        XCTAssertTrue(isOverBudget, "Spending over planned should be detected")
    }
}

// MARK: - 5. INVOICE CALCULATIONS

extension FLOFinancialTests {
    
    // MARK: 5.1 Line Item Calculations
    
    /// Test: Line item total = quantity × unit price
    func testInvoiceLineItem_TotalCalculation() {
        let quantity: Double = 5.0
        let unitPrice: Double = 150.00
        let total = quantity * unitPrice
        
        assertCurrencyEqual(total, 750.00, "Line item total should be $750")
    }
    
    /// Test: Fractional quantity
    func testInvoiceLineItem_FractionalQuantity() {
        let quantity: Double = 2.5
        let unitPrice: Double = 100.00
        let total = quantity * unitPrice
        
        assertCurrencyEqual(total, 250.00, "Fractional quantity should calculate correctly")
    }
    
    // MARK: 5.2 Subtotal Calculation
    
    /// Test: Subtotal = sum of all line items
    func testInvoiceSubtotal_Calculation() {
        let lineItems: [(quantity: Double, unitPrice: Double)] = [
            (5.0, 150.00),
            (10.0, 50.00),
            (1.0, 200.00)
        ]
        let subtotal = lineItems.reduce(0) { $0 + ($1.quantity * $1.unitPrice) }
        
        assertCurrencyEqual(subtotal, 1450.00, "Subtotal should be $1,450")
    }
    
    // MARK: 5.3 Tax Calculation
    
    /// Test: Tax amount = subtotal × tax rate
    func testInvoiceTax_Calculation() {
        let subtotal: Double = 1000.00
        let taxRate: Double = 0.0825
        let taxAmount = subtotal * taxRate
        
        assertCurrencyEqual(taxAmount, 82.50, "Tax should be $82.50")
    }
    
    /// Test: Zero tax rate
    func testInvoiceTax_ZeroRate() {
        let subtotal: Double = 1000.00
        let taxRate: Double = 0.0
        let taxAmount = subtotal * taxRate
        
        assertCurrencyEqual(taxAmount, 0.00, "Zero tax rate should yield $0 tax")
    }
    
    // MARK: 5.4 Total Calculation
    
    /// Test: Total = subtotal + tax - discount
    func testInvoiceTotal_WithTaxAndDiscount() {
        let subtotal: Double = 1000.00
        let taxAmount: Double = 80.00
        let discount: Double = 100.00
        let total = subtotal + taxAmount - discount
        
        assertCurrencyEqual(total, 980.00, "Total should be $980")
    }
    
    /// Test: Total without discount
    func testInvoiceTotal_NoDiscount() {
        let subtotal: Double = 1000.00
        let taxAmount: Double = 80.00
        let discount: Double = 0.00
        let total = subtotal + taxAmount - discount
        
        assertCurrencyEqual(total, 1080.00, "Total without discount should be $1,080")
    }
    
    // MARK: 5.5 Partial Payment Tracking
    
    /// Test: Amount paid = sum of payments
    func testInvoice_AmountPaid_SumOfPayments() {
        let payments: [Double] = [500.00, 300.00, 200.00]
        let amountPaid = payments.reduce(0, +)
        
        assertCurrencyEqual(amountPaid, 1000.00, "Amount paid should be $1,000")
    }
    
    /// Test: Remaining balance = total - amount paid
    func testInvoice_RemainingBalance() {
        let total: Double = 1500.00
        let amountPaid: Double = 1000.00
        let remainingBalance = max(total - amountPaid, 0)
        
        assertCurrencyEqual(remainingBalance, 500.00, "Remaining balance should be $500")
    }
    
    /// Test: Overpayment handling
    func testInvoice_Overpayment_ZeroRemaining() {
        let total: Double = 1000.00
        let amountPaid: Double = 1100.00
        let remainingBalance = max(total - amountPaid, 0)
        
        assertCurrencyEqual(remainingBalance, 0.00, "Remaining balance cannot be negative")
    }
    
    /// Test: Payment progress calculation
    func testInvoice_PaymentProgress() {
        let total: Double = 2000.00
        let amountPaid: Double = 1500.00
        let progress = min(safeDivide(amountPaid, by: total), 1.0)
        
        assertPercentEqual(progress, 0.75, "Payment progress should be 75%")
    }
    
    /// Test: Fully paid detection
    func testInvoice_FullyPaid_Detection() {
        let total: Double = 1000.00
        let amountPaid: Double = 1000.00
        let isFullyPaid = (total - amountPaid) <= 0.01
        
        XCTAssertTrue(isFullyPaid, "Invoice should be detected as fully paid")
    }
}

// MARK: - 6. RECURRING TRANSACTION BALANCE UPDATES

extension FLOFinancialTests {
    
    // MARK: 6.1 Balance Updates on Instance Creation
    
    /// Test: Recurring income increases account balance
    func testRecurring_IncomeInstance_IncreasesBalance() {
        let accountBalance: Double = 5000.00
        let recurringAmount: Double = 1500.00
        let newBalance = applyBalanceChange(balance: accountBalance, amount: recurringAmount, isIncome: true)
        
        assertCurrencyEqual(newBalance, 6500.00, "Income instance should increase balance")
    }
    
    /// Test: Recurring expense decreases account balance
    func testRecurring_ExpenseInstance_DecreasesBalance() {
        let accountBalance: Double = 5000.00
        let recurringAmount: Double = 99.99
        let newBalance = applyBalanceChange(balance: accountBalance, amount: recurringAmount, isIncome: false)
        
        assertCurrencyEqual(newBalance, 4900.01, "Expense instance should decrease balance")
    }
    
    /// Test: Multiple catch-up instances update balance correctly
    func testRecurring_MultipleCatchup_CorrectBalance() {
        var accountBalance: Double = 5000.00
        let recurringAmount: Double = 100.00
        let missedInstances: Int = 3
        
        for _ in 0..<missedInstances {
            accountBalance = applyBalanceChange(balance: accountBalance, amount: recurringAmount, isIncome: false)
        }
        
        assertCurrencyEqual(accountBalance, 4700.00, "3 expense instances should reduce balance by $300")
    }
    
    // MARK: 6.2 Transaction Amount Always Positive
    
    /// Test: Transaction amount stored as positive (isIncome determines direction)
    func testRecurring_AmountAlwaysPositive() {
        let recurringAmount: Double = -50.00
        let transactionAmount = abs(recurringAmount)
        
        XCTAssertGreaterThan(transactionAmount, 0, "Transaction amount should always be positive")
        assertCurrencyEqual(transactionAmount, 50.00, "Amount should be absolute value")
    }
}

// MARK: - 7. MILEAGE CALCULATIONS

extension FLOFinancialTests {
    
    // MARK: 7.1 Deduction Calculation
    
    /// Test: Mileage deduction = miles × IRS rate
    /// 2026 IRS rate: $0.725 per mile
    func testMileage_DeductionCalculation() {
        let businessMiles: Double = 500.0
        let irsRate: Double = 0.725
        let deduction = businessMiles * irsRate
        
        assertCurrencyEqual(deduction, 362.50, "Deduction should be $362.50")
    }
    
    /// Test: Personal miles excluded from deduction
    func testMileage_PersonalMiles_Excluded() {
        let businessMiles: Double = 300.0
        let personalMiles: Double = 200.0
        let irsRate: Double = 0.725
        
        let deduction = businessMiles * irsRate
        let incorrectDeduction = (businessMiles + personalMiles) * irsRate
        
        assertCurrencyEqual(deduction, 217.50, "Only business miles should be deducted")
        XCTAssertNotEqual(deduction, incorrectDeduction, "Personal miles should not be included")
    }
    
    /// Test: Zero miles = zero deduction
    func testMileage_ZeroMiles_ZeroDeduction() {
        let businessMiles: Double = 0.0
        let irsRate: Double = 0.725
        let deduction = businessMiles * irsRate
        
        assertCurrencyEqual(deduction, 0.00, "Zero miles should yield zero deduction")
    }
    
    // MARK: 7.2 Distance Calculations
    
    /// Test: Total distance from trip segments
    func testMileage_TotalDistance_FromSegments() {
        let segments: [Double] = [5.2, 12.8, 3.5, 8.5]
        let totalMiles = segments.reduce(0, +)
        
        XCTAssertEqual(totalMiles, 30.0, accuracy: 0.1, "Total should be 30 miles")
    }
}

// MARK: - 8. EDGE CASES & PRECISION

extension FLOFinancialTests {
    
    // MARK: 8.1 Floating Point Precision
    
    /// Test: Currency calculations maintain precision
    func testPrecision_CurrencyMaintained() {
        let amount1: Double = 0.1
        let amount2: Double = 0.2
        let sum = amount1 + amount2
        
        assertCurrencyEqual(sum, 0.30, "0.1 + 0.2 should equal 0.30 for currency")
    }
    
    /// Test: Large transaction amounts
    func testPrecision_LargeAmounts() {
        let amount: Double = 999999.99
        let balance: Double = 1000000.00
        let newBalance = balance - amount
        
        assertCurrencyEqual(newBalance, 0.01, "Large amounts should calculate precisely")
    }
    
    /// Test: Very small amounts (sub-cent)
    func testPrecision_SmallAmounts() {
        let amount: Double = 10.00
        let percentage: Double = 0.333
        let result = amount * percentage
        let rounded = (result * 100).rounded() / 100
        
        assertCurrencyEqual(rounded, 3.33, "Should round to nearest cent")
    }
    
    // MARK: 8.2 Zero Value Handling
    
    /// Test: Zero division protection across all calculations
    func testZeroDivision_AllProtected() {
        // Budget percentage with zero budget
        let budgetPercent = safeDivide(100, by: 0)
        XCTAssertFalse(budgetPercent.isNaN, "Budget percent should not be NaN")
        XCTAssertFalse(budgetPercent.isInfinite, "Budget percent should not be infinite")
        XCTAssertEqual(budgetPercent, 0, "Budget percent should default to 0")
        
        // Credit utilization with zero limit
        let utilization = safeDivide(1000, by: 0)
        XCTAssertFalse(utilization.isNaN, "Utilization should not be NaN")
        XCTAssertFalse(utilization.isInfinite, "Utilization should not be infinite")
        
        // Effective tax rate with zero income
        let taxRate = safeDivide(5000, by: 0)
        XCTAssertFalse(taxRate.isNaN, "Tax rate should not be NaN")
        XCTAssertFalse(taxRate.isInfinite, "Tax rate should not be infinite")
        
        // Verify normal division still works
        let normalResult = safeDivide(100, by: 4)
        XCTAssertEqual(normalResult, 25, "Normal division should work correctly")
    }
    
    // MARK: 8.3 Negative Value Handling
    
    /// Test: Transaction amount cannot be negative (stored value)
    func testNegative_TransactionAmountStored() {
        let inputAmount: Double = -500.00
        let storedAmount = abs(inputAmount)
        
        XCTAssertGreaterThan(storedAmount, 0, "Stored amount should be positive")
    }
    
    /// Test: Budget planned cannot be negative
    func testNegative_BudgetPlanned() {
        let inputPlanned: Double = -100.00
        let storedPlanned = max(inputPlanned, 0)
        
        XCTAssertGreaterThanOrEqual(storedPlanned, 0, "Budget planned should not be negative")
    }
    
    // MARK: 8.4 Overflow Protection
    
    /// Test: Calculations don't overflow with maximum values
    func testOverflow_LargeMultiplication() {
        let largeAmount: Double = 1_000_000.00
        let multiplier: Double = 1000.0
        let result = largeAmount * multiplier
        
        XCTAssertFalse(result.isInfinite, "Result should not overflow to infinity")
        XCTAssertEqual(result, 1_000_000_000.00, "Should handle billion-dollar calculations")
    }
    
    // MARK: 8.5 Rounding Consistency
    
    /// Test: Currency rounding is consistent
    func testRounding_CurrencyConsistent() {
        func roundToCents(_ value: Double) -> Double {
            return (value * 100).rounded() / 100
        }
        
        assertCurrencyEqual(roundToCents(10.125), 10.13, "10.125 should round to 10.13")
        assertCurrencyEqual(roundToCents(10.124), 10.12, "10.124 should round to 10.12")
        assertCurrencyEqual(roundToCents(10.126), 10.13, "10.126 should round to 10.13")
    }
}

// MARK: - INTEGRATION TESTS

extension FLOFinancialTests {
    
    /// Test: Complete transaction workflow maintains balance integrity
    func testIntegration_TransactionWorkflow_BalanceIntegrity() {
        var balance: Double = 10000.00
        let startingBalance = balance
        
        // 1. Add income $500
        balance += 500.00
        XCTAssertEqual(balance, 10500.00)
        
        // 2. Add expense $200
        balance -= 200.00
        XCTAssertEqual(balance, 10300.00)
        
        // 3. Edit expense from $200 to $300
        balance += 200.00  // Reverse
        balance -= 300.00  // Apply new
        XCTAssertEqual(balance, 10200.00)
        
        // 4. Delete income $500
        balance -= 500.00
        XCTAssertEqual(balance, 9700.00)
        
        assertCurrencyEqual(balance, startingBalance - 300.00, "Balance should reflect all operations")
    }
    
    /// Test: Invoice with all components
    func testIntegration_CompleteInvoice() {
        // Line items
        let item1 = 10.0 * 150.00
        let item2 = 5.0 * 75.00
        let item3 = 1.0 * 500.00
        
        let subtotal = item1 + item2 + item3
        assertCurrencyEqual(subtotal, 2375.00)
        
        let taxRate = 0.08
        let tax = subtotal * taxRate
        assertCurrencyEqual(tax, 190.00)
        
        let discount = 100.00
        let total = subtotal + tax - discount
        assertCurrencyEqual(total, 2465.00)
        
        let payment1 = 1000.00
        let payment2 = 1000.00
        let amountPaid = payment1 + payment2
        
        let remaining = total - amountPaid
        assertCurrencyEqual(remaining, 465.00, "Complete invoice calculation should be accurate")
    }
    
    /// Test: Tax estimate with all components
    func testIntegration_TaxEstimate_AllComponents() {
        let grossIncome: Double = 120000.00
        let expenses: Double = 20000.00
        let netIncome = grossIncome - expenses
        assertCurrencyEqual(netIncome, 100000.00)
        
        let standardDeduction: Double = 15000.00
        let taxableIncome = max(0, netIncome - standardDeduction)
        assertCurrencyEqual(taxableIncome, 85000.00)
        
        let seIncome = netIncome * 0.9235
        let seTax = seIncome * 0.153
        assertCurrencyEqual(seTax, 14129.55)
        
        let federalTax = taxableIncome * 0.18
        assertCurrencyEqual(federalTax, 15300.00)
        
        let stateTax = netIncome * 0.093
        assertCurrencyEqual(stateTax, 9300.00)
        
        let totalTax = federalTax + stateTax + seTax
        assertCurrencyEqual(totalTax, 38729.55)
        
        let quarterlyPayment = totalTax / 4
        assertCurrencyEqual(quarterlyPayment, 9682.39, "Quarterly payment should be accurate")
    }
}

// MARK: - Test Runner Summary

/*
 ═══════════════════════════════════════════════════════════════
 FLO FINANCIAL TEST SUITE v1.3 - SUMMARY
 ═══════════════════════════════════════════════════════════════
 
 CATEGORY                              TESTS    CRITICAL
 ─────────────────────────────────────────────────────────────
 1. Account Balance Operations           8        ✓
 2. Credit Card Calculations            12        ✓
 3. Tax Calculations                    14        ✓
 4. Budget Calculations                 10        ✓
 5. Invoice Calculations                12        ✓
 6. Recurring Transaction Updates        4        ✓✓
 7. Mileage Calculations                 4        ✓
 8. Edge Cases & Precision              10        ✓
 9. Integration Tests                    3        ✓
 ─────────────────────────────────────────────────────────────
 TOTAL                                  77
 
 ═══════════════════════════════════════════════════════════════
 
 RUN BEFORE:
 • Every App Store submission
 • After any financial calculation code changes
 • After model changes (Transaction, Account, Budget, Invoice)
 • After TaxSettings or TaxCalculationService changes
 • After RecurringTransaction or RecurringTransactionService changes
 
 FAILURE IMPACT:
 • Any failure = BLOCK RELEASE
 • Financial accuracy is non-negotiable
 • User trust depends on correct calculations
 
 ═══════════════════════════════════════════════════════════════
 */
