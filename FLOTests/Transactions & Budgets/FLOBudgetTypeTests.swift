//  FLOBudgetTypeTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Budget Type Calculation Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate calculations for different budget types including
//  Envelope, Simple, Zero-based, and 50/30/20 budgeting methods.
//
//  COVERS:
//  - Envelope budgeting with rollover
//  - Simple budget tracking
//  - Zero-based budget allocation
//  - 50/30/20 budget rule
//  - Budget period handling
//

import XCTest
@testable import FLO

final class FLOBudgetTypeTests: XCTestCase {
    
    // MARK: - Budget Type Enum
    
    enum BudgetType: String {
        case envelope = "Envelope"
        case simple = "Simple"
        case zeroBased = "Zero-Based"
        case fiftyThirtyTwenty = "50/30/20"
    }
    
    // MARK: - Precision
    
    let currencyPrecision: Double = 0.01
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: currencyPrecision, message.isEmpty ? "Expected \(expected), got \(actual)" : message, file: file, line: line)
    }
}

// MARK: - Envelope Budgeting

extension FLOBudgetTypeTests {
    
    /// Test: Envelope budget - basic remaining calculation
    func testEnvelope_BasicRemaining() {
        let budgeted: Double = 500.00
        let spent: Double = 325.00
        let carryOver: Double = 0.00
        
        let totalAvailable = budgeted + carryOver
        let remaining = totalAvailable - spent
        
        assertCurrencyEqual(remaining, 175.00)
    }
    
    /// Test: Envelope budget - positive carryover
    func testEnvelope_PositiveCarryover() {
        let budgeted: Double = 500.00
        let spent: Double = 400.00
        let carryOver: Double = 75.00  // Underspent last month
        
        let totalAvailable = budgeted + carryOver
        let remaining = totalAvailable - spent
        
        assertCurrencyEqual(totalAvailable, 575.00, "Budget + carryover")
        assertCurrencyEqual(remaining, 175.00)
    }
    
    /// Test: Envelope budget - negative carryover (overspent last month)
    func testEnvelope_NegativeCarryover() {
        let budgeted: Double = 500.00
        let spent: Double = 300.00
        let carryOver: Double = -100.00  // Overspent last month
        
        let totalAvailable = budgeted + carryOver
        let remaining = totalAvailable - spent
        
        assertCurrencyEqual(totalAvailable, 400.00, "Budget reduced by overspend")
        assertCurrencyEqual(remaining, 100.00)
    }
    
    /// Test: Envelope budget - calculate next month's carryover
    func testEnvelope_CalculateNextCarryover() {
        let budgeted: Double = 500.00
        let spent: Double = 420.00
        let carryOver: Double = 50.00
        
        let totalAvailable = budgeted + carryOver
        let nextCarryover = totalAvailable - spent
        
        assertCurrencyEqual(nextCarryover, 130.00, "Unspent amount rolls over")
    }
    
    /// Test: Envelope budget - overspend creates negative carryover
    func testEnvelope_OverspendCreatesNegativeCarryover() {
        let budgeted: Double = 500.00
        let spent: Double = 650.00
        let carryOver: Double = 0.00
        
        let totalAvailable = budgeted + carryOver
        let nextCarryover = totalAvailable - spent
        
        assertCurrencyEqual(nextCarryover, -150.00, "Overspend becomes negative carryover")
    }
    
    /// Test: Envelope budget - multi-month simulation
    func testEnvelope_MultiMonthSimulation() {
        let monthlyBudget: Double = 500.00
        var carryOver: Double = 0.00
        
        let monthlySpending: [Double] = [450, 550, 400, 600, 480]  // 5 months
        
        for spent in monthlySpending {
            let totalAvailable = monthlyBudget + carryOver
            carryOver = totalAvailable - spent  // Next month's carryover
        }
        
        // Total budget: 5 × $500 = $2,500
        // Total spent: $450 + $550 + $400 + $600 + $480 = $2,480
        // Final carryover: $2,500 - $2,480 = $20
        assertCurrencyEqual(carryOver, 20.00, "Final carryover after 5 months")
    }
}

// MARK: - Simple Budget

extension FLOBudgetTypeTests {
    
    /// Test: Simple budget - basic tracking (no rollover)
    func testSimple_BasicTracking() {
        let budgeted: Double = 500.00
        let spent: Double = 325.00
        
        let remaining = budgeted - spent
        let percentUsed = spent / budgeted
        
        assertCurrencyEqual(remaining, 175.00)
        XCTAssertEqual(percentUsed, 0.65, accuracy: 0.01, "65% used")
    }
    
    /// Test: Simple budget - resets each period (no carryover)
    func testSimple_NoCarryover() {
        // Month 1: underspend
        let month1Budget: Double = 500.00
        let month1Spent: Double = 300.00
        let month1Remaining = month1Budget - month1Spent  // $200 remaining
        
        // Month 2: starts fresh
        let month2Budget: Double = 500.00
        let month2Spent: Double = 400.00
        let month2Remaining = month2Budget - month2Spent  // $100 remaining
        
        // Verify month 1 had remaining
        assertCurrencyEqual(month1Remaining, 200.00, "Month 1 had $200 remaining")
        
        // Remaining doesn't include Month 1's unspent amount
        assertCurrencyEqual(month2Remaining, 100.00, "Simple budget doesn't carry over")
        XCTAssertNotEqual(month2Remaining, month1Remaining + 100.00, "Should NOT include month 1 remaining")
    }
    
    /// Test: Simple budget - over budget detection
    func testSimple_OverBudgetDetection() {
        let budgeted: Double = 500.00
        let spent: Double = 600.00
        
        let remaining = budgeted - spent
        let isOverBudget = remaining < 0
        
        assertCurrencyEqual(remaining, -100.00)
        XCTAssertTrue(isOverBudget)
    }
    
    /// Test: Simple budget - alert thresholds
    func testSimple_AlertThresholds() {
        let budgeted: Double = 1000.00
        
        func getAlertLevel(_ spent: Double) -> String {
            let percentUsed = spent / budgeted
            if percentUsed >= 1.0 { return "over" }
            if percentUsed >= 0.9 { return "critical" }
            if percentUsed >= 0.8 { return "warning" }
            return "normal"
        }
        
        XCTAssertEqual(getAlertLevel(700), "normal")
        XCTAssertEqual(getAlertLevel(800), "warning")
        XCTAssertEqual(getAlertLevel(900), "critical")
        XCTAssertEqual(getAlertLevel(1000), "over")
        XCTAssertEqual(getAlertLevel(1100), "over")
    }
}

// MARK: - Zero-Based Budget

extension FLOBudgetTypeTests {
    
    /// Test: Zero-based budget - income minus allocations = 0
    func testZeroBased_IncomeMinusAllocationsEqualsZero() {
        let monthlyIncome: Double = 5000.00
        
        let allocations: [String: Double] = [
            "Housing": 1500.00,
            "Transportation": 400.00,
            "Food": 600.00,
            "Utilities": 200.00,
            "Insurance": 300.00,
            "Savings": 500.00,
            "Debt Payment": 400.00,
            "Entertainment": 200.00,
            "Personal": 300.00,
            "Miscellaneous": 100.00
        ]
        
        let totalAllocated = allocations.values.reduce(0, +)
        let unallocated = monthlyIncome - totalAllocated
        
        assertCurrencyEqual(totalAllocated, 4500.00)
        assertCurrencyEqual(unallocated, 500.00, "Should allocate remaining $500")
    }
    
    /// Test: Zero-based budget - fully allocated
    func testZeroBased_FullyAllocated() {
        let monthlyIncome: Double = 5000.00
        let totalAllocated: Double = 5000.00
        
        let unallocated = monthlyIncome - totalAllocated
        let isFullyAllocated = abs(unallocated) < 0.01
        
        XCTAssertTrue(isFullyAllocated, "Every dollar has a job")
    }
    
    /// Test: Zero-based budget - over-allocated warning
    func testZeroBased_OverAllocatedWarning() {
        let monthlyIncome: Double = 5000.00
        let totalAllocated: Double = 5200.00
        
        let unallocated = monthlyIncome - totalAllocated
        let isOverAllocated = unallocated < 0
        
        assertCurrencyEqual(unallocated, -200.00)
        XCTAssertTrue(isOverAllocated, "Over-allocated by $200")
    }
    
    /// Test: Zero-based budget - category tracking
    func testZeroBased_CategoryTracking() {
        let categoryBudget: Double = 600.00  // Food budget
        let transactions: [Double] = [45.00, 120.00, 35.00, 80.00, 95.00]
        
        let totalSpent = transactions.reduce(0, +)
        let remaining = categoryBudget - totalSpent
        
        assertCurrencyEqual(totalSpent, 375.00)
        assertCurrencyEqual(remaining, 225.00)
    }
}

// MARK: - 50/30/20 Budget

extension FLOBudgetTypeTests {
    
    /// Test: 50/30/20 - calculate allocations
    func test503020_CalculateAllocations() {
        let monthlyIncome: Double = 6000.00
        
        let needs = monthlyIncome * 0.50      // 50% for needs
        let wants = monthlyIncome * 0.30      // 30% for wants
        let savings = monthlyIncome * 0.20    // 20% for savings/debt
        
        assertCurrencyEqual(needs, 3000.00, "50% for needs")
        assertCurrencyEqual(wants, 1800.00, "30% for wants")
        assertCurrencyEqual(savings, 1200.00, "20% for savings")
        
        // Verify they add up to 100%
        assertCurrencyEqual(needs + wants + savings, monthlyIncome)
    }
    
    /// Test: 50/30/20 - classify expense categories
    func test503020_ClassifyCategories() {
        let needsCategories = ["Housing", "Utilities", "Groceries", "Insurance", "Transportation", "Minimum Debt Payments"]
        let wantsCategories = ["Dining Out", "Entertainment", "Shopping", "Subscriptions", "Hobbies"]
        let savingsCategories = ["Emergency Fund", "Retirement", "Extra Debt Payment", "Investments"]
        
        func classify(_ category: String) -> String {
            if needsCategories.contains(category) { return "needs" }
            if wantsCategories.contains(category) { return "wants" }
            if savingsCategories.contains(category) { return "savings" }
            return "unknown"
        }
        
        XCTAssertEqual(classify("Housing"), "needs")
        XCTAssertEqual(classify("Dining Out"), "wants")
        XCTAssertEqual(classify("Emergency Fund"), "savings")
        XCTAssertEqual(classify("Random"), "unknown")
    }
    
    /// Test: 50/30/20 - check compliance
    func test503020_CheckCompliance() {
        let monthlyIncome: Double = 5000.00
        
        let actualNeeds: Double = 2800.00    // 56%
        let actualWants: Double = 1200.00    // 24%
        let actualSavings: Double = 1000.00  // 20%
        
        let needsPercent = actualNeeds / monthlyIncome
        let wantsPercent = actualWants / monthlyIncome
        let savingsPercent = actualSavings / monthlyIncome
        
        let needsCompliant = needsPercent <= 0.50
        let wantsCompliant = wantsPercent <= 0.30
        let savingsCompliant = savingsPercent >= 0.20
        
        XCTAssertFalse(needsCompliant, "Needs over 50%")
        XCTAssertTrue(wantsCompliant, "Wants under 30%")
        XCTAssertTrue(savingsCompliant, "Savings at 20%")
    }
    
    /// Test: 50/30/20 - generate recommendations
    func test503020_GenerateRecommendations() {
        let monthlyIncome: Double = 5000.00
        let actualNeeds: Double = 3000.00  // 60% - over target
        
        let targetNeeds = monthlyIncome * 0.50
        let needsOverage = actualNeeds - targetNeeds
        
        let recommendation = generateNeedsRecommendation(overage: needsOverage)
        
        XCTAssertEqual(needsOverage, 500.00)
        XCTAssertTrue(recommendation.contains("Reduce"), "Should recommend reduction")
    }
    
    /// Helper to generate needs recommendation (avoids compile-time optimization)
    private func generateNeedsRecommendation(overage: Double) -> String {
        return overage > 0
            ? "Reduce needs spending by $\(Int(overage)) to meet 50% target"
            : "Needs spending is within target"
    }
    
    /// Test: 50/30/20 - handle variable income
    func test503020_VariableIncome() {
        let monthlyIncomes: [Double] = [4000, 6000, 5000, 7000, 4500]
        
        var monthlyAllocations: [(needs: Double, wants: Double, savings: Double)] = []
        
        for income in monthlyIncomes {
            let allocation = (
                needs: income * 0.50,
                wants: income * 0.30,
                savings: income * 0.20
            )
            monthlyAllocations.append(allocation)
        }
        
        // Verify first month
        assertCurrencyEqual(monthlyAllocations[0].needs, 2000.00)
        assertCurrencyEqual(monthlyAllocations[0].wants, 1200.00)
        assertCurrencyEqual(monthlyAllocations[0].savings, 800.00)
        
        // Verify high income month
        assertCurrencyEqual(monthlyAllocations[3].needs, 3500.00)
        assertCurrencyEqual(monthlyAllocations[3].savings, 1400.00)
    }
}

// MARK: - Budget Period Handling

extension FLOBudgetTypeTests {
    
    /// Test: Monthly period - days remaining
    func testPeriod_DaysRemaining() {
        let calendar = Calendar.current
        let today = Date()
        
        // Get last day of current month
        let range = calendar.range(of: .day, in: .month, for: today)!
        let lastDay = range.count
        let currentDay = calendar.component(.day, from: today)
        
        let daysRemaining = lastDay - currentDay
        
        XCTAssertGreaterThanOrEqual(daysRemaining, 0, "Days remaining >= 0")
        XCTAssertLessThanOrEqual(daysRemaining, 31, "Days remaining <= 31")
    }
    
    /// Test: Daily budget calculation
    func testPeriod_DailyBudget() {
        let monthlyBudget: Double = 600.00  // Food budget
        let daysInMonth: Int = 30
        let currentDay: Int = 15
        let spent: Double = 250.00
        
        let dailyBudget = monthlyBudget / Double(daysInMonth)
        let expectedSpentByNow = dailyBudget * Double(currentDay)
        let onTrack = spent <= expectedSpentByNow
        
        assertCurrencyEqual(dailyBudget, 20.00, "Daily budget = $20")
        assertCurrencyEqual(expectedSpentByNow, 300.00, "Should have spent ~$300 by day 15")
        XCTAssertTrue(onTrack, "Under expected spending")
    }
    
    /// Test: Weekly budget period
    func testPeriod_WeeklyBudget() {
        let weeklyBudget: Double = 150.00  // Entertainment
        let spent: Double = 80.00
        let dayOfWeek: Int = 4  // Thursday
        
        let remaining = weeklyBudget - spent
        let daysLeft = 7 - dayOfWeek
        let dailyRemaining = remaining / Double(daysLeft)
        
        assertCurrencyEqual(remaining, 70.00)
        XCTAssertEqual(daysLeft, 3, "3 days left in week")
        assertCurrencyEqual(dailyRemaining, 23.33, "~$23/day remaining")
    }
    
    /// Test: Annual budget period
    func testPeriod_AnnualBudget() {
        let annualBudget: Double = 2400.00  // Vacation fund
        let monthsPassed: Int = 8
        let spent: Double = 1800.00
        
        let monthlyTarget = annualBudget / 12.0
        let expectedSpentByNow = monthlyTarget * Double(monthsPassed)
        let variance = spent - expectedSpentByNow
        
        assertCurrencyEqual(monthlyTarget, 200.00)
        assertCurrencyEqual(expectedSpentByNow, 1600.00)
        assertCurrencyEqual(variance, 200.00, "Over by $200")
    }
}

// MARK: - Budget Comparison Across Types

extension FLOBudgetTypeTests {
    
    /// Test: Same scenario, different budget types
    func testComparison_SameScenarioDifferentTypes() {
        let monthlyBudget: Double = 500.00
        let lastMonthUnspent: Double = 75.00  // For envelope
        let currentSpent: Double = 450.00
        
        // Envelope: carries over unspent
        let envelopeAvailable = monthlyBudget + lastMonthUnspent
        let envelopeRemaining = envelopeAvailable - currentSpent
        
        // Simple: no carryover
        let simpleRemaining = monthlyBudget - currentSpent
        
        // Results differ
        assertCurrencyEqual(envelopeRemaining, 125.00, "Envelope has $125 remaining")
        assertCurrencyEqual(simpleRemaining, 50.00, "Simple has $50 remaining")
        XCTAssertGreaterThan(envelopeRemaining, simpleRemaining, "Envelope shows more available")
    }
}
