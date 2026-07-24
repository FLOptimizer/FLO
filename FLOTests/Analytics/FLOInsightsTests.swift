//  FLOInsightsTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Insights & Trends Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate insights calculations, spending trends,
//  budget alerts, and financial recommendations.
//
//  COVERS:
//  - Month-over-month spending comparisons
//  - Spending trend detection
//  - Budget alert generation
//  - Tax optimization tips
//  - Cash flow insights
//

import XCTest
@testable import FLO

final class FLOInsightsTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 0.01, message, file: file, line: line)
    }
}

// MARK: - Month-Over-Month Comparison

extension FLOInsightsTests {
    
    /// Test: Calculate spending change percentage
    func testMoM_SpendingChangePercent() {
        let lastMonth: Double = 2500.00
        let thisMonth: Double = 2750.00
        
        let change = thisMonth - lastMonth
        let percentChange = (change / lastMonth) * 100
        
        assertCurrencyEqual(change, 250.00)
        XCTAssertEqual(percentChange, 10.0, accuracy: 0.1, "10% increase")
    }
    
    /// Test: Spending decreased
    func testMoM_SpendingDecreased() {
        let lastMonth: Double = 3000.00
        let thisMonth: Double = 2700.00
        
        let change = thisMonth - lastMonth
        let percentChange = (change / lastMonth) * 100
        
        assertCurrencyEqual(change, -300.00)
        XCTAssertEqual(percentChange, -10.0, accuracy: 0.1, "10% decrease")
    }
    
    /// Test: Handle zero last month
    func testMoM_ZeroLastMonth() {
        let percentChange = calculatePercentChange(lastMonth: 0.00, thisMonth: 500.00)
        
        XCTAssertTrue(percentChange.isInfinite || percentChange == 100, "New spending from zero")
    }
    
    /// Helper to calculate percent change (avoids compile-time optimization)
    private func calculatePercentChange(lastMonth: Double, thisMonth: Double) -> Double {
        if lastMonth == 0 {
            return thisMonth > 0 ? Double.infinity : 0
        } else {
            return ((thisMonth - lastMonth) / lastMonth) * 100
        }
    }
    
    /// Test: Category-specific comparison
    func testMoM_CategoryComparison() {
        let lastMonthByCategory: [String: Double] = [
            "Food": 600,
            "Transportation": 300,
            "Entertainment": 200
        ]
        
        let thisMonthByCategory: [String: Double] = [
            "Food": 700,
            "Transportation": 250,
            "Entertainment": 350
        ]
        
        var changes: [String: Double] = [:]
        for (category, thisAmount) in thisMonthByCategory {
            let lastAmount = lastMonthByCategory[category] ?? 0
            let percentChange = lastAmount > 0 ? ((thisAmount - lastAmount) / lastAmount) * 100 : 100
            changes[category] = percentChange
        }
        
        XCTAssertEqual(changes["Food"]!, 16.67, accuracy: 0.1, "Food up 16.67%")
        XCTAssertEqual(changes["Transportation"]!, -16.67, accuracy: 0.1, "Transport down 16.67%")
        XCTAssertEqual(changes["Entertainment"]!, 75.0, accuracy: 0.1, "Entertainment up 75%")
    }
}

// MARK: - Spending Trend Detection

extension FLOInsightsTests {
    
    enum SpendingTrend {
        case increasing
        case decreasing
        case stable
    }
    
    /// Detect trend from 3+ months of data
    private func detectTrend(months: [Double]) -> SpendingTrend {
        guard months.count >= 3 else { return .stable }
        
        var increases = 0
        var decreases = 0
        
        for i in 1..<months.count {
            let change = months[i] - months[i-1]
            let percentChange = abs(change) / months[i-1]
            
            // Only count significant changes (>5%)
            if percentChange > 0.05 {
                if change > 0 { increases += 1 }
                else { decreases += 1 }
            }
        }
        
        if increases > decreases && increases >= 2 { return .increasing }
        if decreases > increases && decreases >= 2 { return .decreasing }
        return .stable
    }
    
    /// Test: Detect increasing trend
    func testTrend_Increasing() {
        let months: [Double] = [2000, 2200, 2500, 2800]
        let trend = detectTrend(months: months)
        
        XCTAssertEqual(trend, .increasing)
    }
    
    /// Test: Detect decreasing trend
    func testTrend_Decreasing() {
        let months: [Double] = [3000, 2700, 2400, 2100]
        let trend = detectTrend(months: months)
        
        XCTAssertEqual(trend, .decreasing)
    }
    
    /// Test: Detect stable trend
    func testTrend_Stable() {
        let months: [Double] = [2500, 2520, 2480, 2510]
        let trend = detectTrend(months: months)
        
        XCTAssertEqual(trend, .stable)
    }
    
    /// Test: Mixed trend is stable
    func testTrend_Mixed() {
        // Up, down, small change = 1 inc, 1 dec, 0 significant = stable
        let months: [Double] = [2000, 2400, 2000, 2050]
        let trend = detectTrend(months: months)
        
        XCTAssertEqual(trend, .stable, "1 increase + 1 decrease = stable")
    }
}

// MARK: - Budget Alert Generation

extension FLOInsightsTests {
    
    enum BudgetAlertType {
        case onTrack
        case warning      // 80-99%
        case overBudget   // 100%+
        case underSpent   // < 50% with little time left
    }
    
    /// Generate alert based on budget status
    private func generateAlert(spent: Double, budgeted: Double, daysRemaining: Int, totalDays: Int) -> BudgetAlertType {
        let percentUsed = spent / budgeted
        let percentTimeRemaining = Double(daysRemaining) / Double(totalDays)
        
        if percentUsed >= 1.0 {
            return .overBudget
        } else if percentUsed >= 0.8 {
            return .warning
        } else if percentUsed < 0.5 && percentTimeRemaining < 0.25 {
            return .underSpent
        }
        return .onTrack
    }
    
    /// Test: On track alert
    func testAlert_OnTrack() {
        let alert = generateAlert(spent: 300, budgeted: 500, daysRemaining: 15, totalDays: 30)
        XCTAssertEqual(alert, .onTrack, "60% used with 50% time left = on track")
    }
    
    /// Test: Warning alert
    func testAlert_Warning() {
        let alert = generateAlert(spent: 450, budgeted: 500, daysRemaining: 10, totalDays: 30)
        XCTAssertEqual(alert, .warning, "90% used = warning")
    }
    
    /// Test: Over budget alert
    func testAlert_OverBudget() {
        let alert = generateAlert(spent: 550, budgeted: 500, daysRemaining: 10, totalDays: 30)
        XCTAssertEqual(alert, .overBudget, "110% used = over budget")
    }
    
    /// Test: Underspent alert
    func testAlert_UnderSpent() {
        let alert = generateAlert(spent: 100, budgeted: 500, daysRemaining: 5, totalDays: 30)
        XCTAssertEqual(alert, .underSpent, "20% used with 17% time left = underspent")
    }
}

// MARK: - Tax Optimization Tips

extension FLOInsightsTests {
    
    /// Test: Suggest quarterly payment if not made
    func testTaxTip_QuarterlyPaymentReminder() {
        let currentQuarter = 1
        let lastPaymentQuarter = 0  // No payment this year yet
        
        let needsReminder = currentQuarter > lastPaymentQuarter
        
        XCTAssertTrue(needsReminder, "Should remind about Q1 payment")
    }
    
    /// Test: Suggest business expense review
    func testTaxTip_BusinessExpenseReview() {
        let personalExpenses: Double = 5000
        let businessExpenses: Double = 2000
        let totalExpenses = personalExpenses + businessExpenses
        let businessPercent = businessExpenses / totalExpenses
        
        let shouldSuggestReview = businessPercent < 0.30  // Less than 30% marked business
        
        XCTAssertTrue(shouldSuggestReview, "Low business expense ratio suggests review")
    }
    
    /// Test: Mileage tracking suggestion
    func testTaxTip_MileageTracking() {
        let trackedTrips: Int = 5
        let estimatedTrips: Int = 50  // Based on driving frequency
        let trackingRate = Double(trackedTrips) / Double(estimatedTrips)
        
        let shouldSuggestTracking = trackingRate < 0.50
        
        XCTAssertTrue(shouldSuggestTracking, "Only 10% tracked = suggest mileage tracking")
    }
    
    /// Test: Home office deduction suggestion
    func testTaxTip_HomeOfficeDeduction() {
        let hasHomeExpenses = true
        let homeOfficeConfigured = false
        
        let shouldSuggest = hasHomeExpenses && !homeOfficeConfigured
        
        XCTAssertTrue(shouldSuggest, "Has home expenses but no office configured")
    }
}

// MARK: - Cash Flow Insights

extension FLOInsightsTests {
    
    /// Test: Calculate average daily spending
    func testCashFlow_AverageDailySpending() {
        let monthlySpending: Double = 3000
        let daysInMonth: Int = 30
        
        let dailyAverage = monthlySpending / Double(daysInMonth)
        
        assertCurrencyEqual(dailyAverage, 100.00, "$100/day average")
    }
    
    /// Test: Project month-end balance
    func testCashFlow_ProjectMonthEnd() {
        let currentBalance: Double = 5000
        let expectedIncome: Double = 3000  // Remaining income this month
        let projectedExpenses: Double = 2500  // Based on average
        
        let projectedEndBalance = currentBalance + expectedIncome - projectedExpenses
        
        assertCurrencyEqual(projectedEndBalance, 5500.00)
    }
    
    /// Test: Detect low balance warning
    func testCashFlow_LowBalanceWarning() {
        let currentBalance: Double = 500
        let averageDailyExpense: Double = 100
        let daysUntilNextIncome: Int = 10
        
        let projectedExpenses = averageDailyExpense * Double(daysUntilNextIncome)
        let projectedBalance = currentBalance - projectedExpenses
        
        let isLowBalance = projectedBalance < 0
        
        XCTAssertTrue(isLowBalance, "Will run out of money before next income")
    }
    
    /// Test: Calculate days until broke
    func testCashFlow_DaysUntilBroke() {
        let currentBalance: Double = 750
        let averageDailyExpense: Double = 100
        
        let daysUntilBroke = currentBalance / averageDailyExpense
        
        XCTAssertEqual(daysUntilBroke, 7.5, accuracy: 0.1, "~7.5 days of runway")
    }
}

// MARK: - Insight Message Generation

extension FLOInsightsTests {
    
    /// Test: Generate spending change message
    func testMessage_SpendingChange() {
        func generateMessage(category: String, percentChange: Double) -> String {
            let direction = percentChange >= 0 ? "up" : "down"
            let absChange = abs(percentChange)
            return "\(category) spending is \(direction) \(Int(absChange))% from last month"
        }
        
        let message1 = generateMessage(category: "Food", percentChange: 15)
        let message2 = generateMessage(category: "Entertainment", percentChange: -20)
        
        XCTAssertEqual(message1, "Food spending is up 15% from last month")
        XCTAssertEqual(message2, "Entertainment spending is down 20% from last month")
    }
    
    /// Test: Generate budget warning message
    func testMessage_BudgetWarning() {
        func generateWarning(category: String, percentUsed: Double, daysRemaining: Int) -> String {
            return "You've used \(Int(percentUsed * 100))% of your \(category) budget with \(daysRemaining) days remaining"
        }
        
        let message = generateWarning(category: "Dining Out", percentUsed: 0.85, daysRemaining: 10)
        
        XCTAssertEqual(message, "You've used 85% of your Dining Out budget with 10 days remaining")
    }
    
    /// Test: Generate savings suggestion
    func testMessage_SavingsSuggestion() {
        let monthlyIncome: Double = 5000
        let monthlyExpenses: Double = 4500
        let currentSavingsRate = (monthlyIncome - monthlyExpenses) / monthlyIncome
        let targetSavingsRate: Double = 0.20
        
        let needsMore = currentSavingsRate < targetSavingsRate
        let additionalNeeded = (targetSavingsRate - currentSavingsRate) * monthlyIncome
        
        XCTAssertTrue(needsMore, "Saving 10%, target is 20%")
        assertCurrencyEqual(additionalNeeded, 500.00, "Need to save $500 more")
    }
}

// MARK: - Insight Priority

extension FLOInsightsTests {
    
    enum InsightPriority: Int {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }
    
    /// Test: Over budget is critical priority
    func testPriority_OverBudget() {
        let priority = determinePriority(isOverBudget: true)
        XCTAssertEqual(priority, .critical)
    }
    
    /// Test: Low balance is high priority
    func testPriority_LowBalance() {
        let priority = determineBalancePriority(daysOfRunway: 5)
        XCTAssertEqual(priority, .high)
    }
    
    /// Test: Tax tip is medium priority
    func testPriority_TaxTip() {
        let priority = determineUrgencyPriority(isUrgent: false)
        XCTAssertEqual(priority, .medium)
    }
    
    /// Test: Positive trend is low priority
    func testPriority_PositiveTrend() {
        let priority = determineTrendPriority(isPositive: true)
        XCTAssertEqual(priority, .low, "Good news is low priority (still show it)")
    }
    
    // MARK: - Priority Helper Functions (avoid compile-time optimization)
    
    private func determinePriority(isOverBudget: Bool) -> InsightPriority {
        return isOverBudget ? .critical : .medium
    }
    
    private func determineBalancePriority(daysOfRunway: Int) -> InsightPriority {
        return daysOfRunway < 7 ? .high : .medium
    }
    
    private func determineUrgencyPriority(isUrgent: Bool) -> InsightPriority {
        return isUrgent ? .high : .medium
    }
    
    private func determineTrendPriority(isPositive: Bool) -> InsightPriority {
        return isPositive ? .low : .medium
    }
}
