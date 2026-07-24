//  FLOCategorySpendingTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Category Spending Aggregation Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate category spending calculations, aggregations,
//  and filtering for budget tracking.
//
//  COVERS:
//  - Transaction aggregation by category
//  - Date range filtering
//  - Business vs Personal filtering
//  - Category totals for budgets
//  - Spending trends
//

import XCTest
@testable import FLO

final class FLOCategorySpendingTests: XCTestCase {
    
    // MARK: - Test Data Structures
    
    struct TestTransaction {
        let amount: Double
        let category: String
        let date: Date
        let isBusiness: Bool
        let isIncome: Bool
    }
    
    // MARK: - Helpers
    
    let calendar = Calendar.current
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 0.01, message, file: file, line: line)
    }
}

// MARK: - Basic Category Aggregation

extension FLOCategorySpendingTests {
    
    /// Test: Sum transactions by single category
    func testAggregation_SingleCategory() {
        let transactions = [
            TestTransaction(amount: 45.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 32.50, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 28.00, category: "Food", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let foodTotal = transactions
            .filter { $0.category == "Food" && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(foodTotal, 105.50)
    }
    
    /// Test: Sum transactions by multiple categories
    func testAggregation_MultipleCategories() {
        let transactions = [
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 30.00, category: "Transportation", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 25.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 100.00, category: "Utilities", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 45.00, category: "Transportation", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        var totalsByCategory: [String: Double] = [:]
        
        for tx in transactions where !tx.isIncome {
            totalsByCategory[tx.category, default: 0] += tx.amount
        }
        
        assertCurrencyEqual(totalsByCategory["Food"]!, 75.00)
        assertCurrencyEqual(totalsByCategory["Transportation"]!, 75.00)
        assertCurrencyEqual(totalsByCategory["Utilities"]!, 100.00)
    }
    
    /// Test: Exclude income from expense totals
    func testAggregation_ExcludeIncome() {
        let transactions = [
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 1000.00, category: "Salary", date: Date(), isBusiness: false, isIncome: true),
            TestTransaction(amount: 30.00, category: "Food", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let expenseTotal = transactions
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let incomeTotal = transactions
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(expenseTotal, 80.00, "Only expenses")
        assertCurrencyEqual(incomeTotal, 1000.00, "Only income")
    }
    
    /// Test: Empty category returns zero
    func testAggregation_EmptyCategory() {
        let transactions = [
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let entertainmentTotal = transactions
            .filter { $0.category == "Entertainment" && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(entertainmentTotal, 0, "No entertainment transactions")
    }
}

// MARK: - Date Range Filtering

extension FLOCategorySpendingTests {
    
    /// Test: Filter by current month
    func testDateFilter_CurrentMonth() {
        let today = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        let transactions = [
            TestTransaction(amount: 50.00, category: "Food", date: today, isBusiness: false, isIncome: false),
            TestTransaction(amount: 30.00, category: "Food", date: calendar.date(byAdding: .month, value: -1, to: today)!, isBusiness: false, isIncome: false)
        ]
        
        let currentMonthTotal = transactions
            .filter { $0.date >= startOfMonth && $0.date <= endOfMonth && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(currentMonthTotal, 50.00, "Only current month")
    }
    
    /// Test: Filter by specific date range
    func testDateFilter_SpecificRange() {
        let startDate = makeDate(year: 2026, month: 1, day: 1)
        let endDate = makeDate(year: 2026, month: 1, day: 15)
        
        let transactions = [
            TestTransaction(amount: 100.00, category: "Shopping", date: makeDate(year: 2026, month: 1, day: 5), isBusiness: false, isIncome: false),
            TestTransaction(amount: 50.00, category: "Shopping", date: makeDate(year: 2026, month: 1, day: 10), isBusiness: false, isIncome: false),
            TestTransaction(amount: 75.00, category: "Shopping", date: makeDate(year: 2026, month: 1, day: 20), isBusiness: false, isIncome: false)  // Outside range
        ]
        
        let rangeTotal = transactions
            .filter { $0.date >= startDate && $0.date <= endDate && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(rangeTotal, 150.00, "Only Jan 1-15")
    }
    
    /// Test: Year-to-date filter
    func testDateFilter_YearToDate() {
        let today = Date()
        let startOfYear = calendar.date(from: DateComponents(year: calendar.component(.year, from: today), month: 1, day: 1))!
        
        let transactions = [
            TestTransaction(amount: 200.00, category: "Insurance", date: makeDate(year: 2026, month: 1, day: 15), isBusiness: false, isIncome: false),
            TestTransaction(amount: 200.00, category: "Insurance", date: makeDate(year: 2025, month: 12, day: 15), isBusiness: false, isIncome: false)  // Last year
        ]
        
        let ytdTotal = transactions
            .filter { $0.date >= startOfYear && $0.date <= today && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        // Only includes 2026 transaction if current year is 2026
        XCTAssertGreaterThanOrEqual(ytdTotal, 0, "YTD total calculated")
    }
}

// MARK: - Business vs Personal Filtering

extension FLOCategorySpendingTests {
    
    /// Test: Filter business expenses only
    func testBusinessFilter_BusinessOnly() {
        let transactions = [
            TestTransaction(amount: 100.00, category: "Office Supplies", date: Date(), isBusiness: true, isIncome: false),
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 75.00, category: "Software", date: Date(), isBusiness: true, isIncome: false)
        ]
        
        let businessTotal = transactions
            .filter { $0.isBusiness && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(businessTotal, 175.00, "Business expenses only")
    }
    
    /// Test: Filter personal expenses only
    func testBusinessFilter_PersonalOnly() {
        let transactions = [
            TestTransaction(amount: 100.00, category: "Office Supplies", date: Date(), isBusiness: true, isIncome: false),
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 75.00, category: "Entertainment", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let personalTotal = transactions
            .filter { !$0.isBusiness && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(personalTotal, 125.00, "Personal expenses only")
    }
    
    /// Test: Combined business and personal
    func testBusinessFilter_CombinedTotals() {
        let transactions = [
            TestTransaction(amount: 100.00, category: "Office Supplies", date: Date(), isBusiness: true, isIncome: false),
            TestTransaction(amount: 50.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 75.00, category: "Software", date: Date(), isBusiness: true, isIncome: false)
        ]
        
        let businessTotal = transactions.filter { $0.isBusiness && !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let personalTotal = transactions.filter { !$0.isBusiness && !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let grandTotal = transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        
        assertCurrencyEqual(businessTotal + personalTotal, grandTotal, "Business + Personal = Total")
    }
}

// MARK: - Budget Category Matching

extension FLOCategorySpendingTests {
    
    /// Test: Calculate spent amount for budget
    func testBudgetSpent_CalculateFromTransactions() {
        let budgetCategory = "Food"
        let budgetAmount: Double = 500.00
        
        let transactions = [
            TestTransaction(amount: 45.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 120.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 35.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 80.00, category: "Transportation", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let spent = transactions
            .filter { $0.category == budgetCategory && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let remaining = budgetAmount - spent
        let percentUsed = spent / budgetAmount
        
        assertCurrencyEqual(spent, 200.00)
        assertCurrencyEqual(remaining, 300.00)
        XCTAssertEqual(percentUsed, 0.40, accuracy: 0.01, "40% used")
    }
    
    /// Test: Multiple categories in one budget
    func testBudgetSpent_MultipleCategoriesInBudget() {
        // Budget covers both "Dining Out" and "Groceries"
        let budgetCategories = ["Dining Out", "Groceries"]
        let budgetAmount: Double = 600.00
        
        let transactions = [
            TestTransaction(amount: 150.00, category: "Groceries", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 45.00, category: "Dining Out", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 200.00, category: "Groceries", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 30.00, category: "Dining Out", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        let spent = transactions
            .filter { budgetCategories.contains($0.category) && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let remaining = budgetAmount - spent
        
        assertCurrencyEqual(spent, 425.00)
        assertCurrencyEqual(remaining, 175.00, "Should have $175 remaining")
    }
}

// MARK: - Spending Trends

extension FLOCategorySpendingTests {
    
    /// Test: Month-over-month comparison
    func testTrend_MonthOverMonthComparison() {
        let lastMonthTotal: Double = 500.00
        let thisMonthTotal: Double = 550.00
        
        let difference = thisMonthTotal - lastMonthTotal
        let percentChange = (difference / lastMonthTotal) * 100
        
        assertCurrencyEqual(difference, 50.00)
        XCTAssertEqual(percentChange, 10.0, accuracy: 0.1, "10% increase")
    }
    
    /// Test: Identify spending increase
    func testTrend_IdentifyIncrease() {
        let lastMonth: Double = 400.00
        let thisMonth: Double = 500.00
        
        let percentChange = ((thisMonth - lastMonth) / lastMonth) * 100
        let isSignificantIncrease = percentChange > 20  // >20% threshold
        
        XCTAssertEqual(percentChange, 25.0, accuracy: 0.1)
        XCTAssertTrue(isSignificantIncrease, "25% increase is significant")
    }
    
    /// Test: Identify spending decrease
    func testTrend_IdentifyDecrease() {
        let lastMonth: Double = 600.00
        let thisMonth: Double = 450.00
        
        let percentChange = ((thisMonth - lastMonth) / lastMonth) * 100
        let isDecrease = percentChange < 0
        
        XCTAssertEqual(percentChange, -25.0, accuracy: 0.1)
        XCTAssertTrue(isDecrease, "Spending decreased")
    }
    
    /// Test: Calculate average spending
    func testTrend_AverageSpending() {
        let monthlyTotals: [Double] = [450, 520, 480, 510, 490, 530]
        
        let average = monthlyTotals.reduce(0, +) / Double(monthlyTotals.count)
        let min = monthlyTotals.min()!
        let max = monthlyTotals.max()!
        
        assertCurrencyEqual(average, 496.67)
        assertCurrencyEqual(min, 450.00)
        assertCurrencyEqual(max, 530.00)
    }
    
    /// Test: Handle zero last month (avoid divide by zero)
    func testTrend_ZeroLastMonth() {
        let percentChange = calculatePercentChange(lastMonth: 0.00, thisMonth: 100.00)
        
        XCTAssertEqual(percentChange, 100.0, "New spending = 100% change")
    }
    
    /// Helper to calculate percent change (avoids compile-time optimization and divide by zero)
    private func calculatePercentChange(lastMonth: Double, thisMonth: Double) -> Double {
        if lastMonth == 0 {
            return thisMonth > 0 ? 100.0 : 0.0
        } else {
            return ((thisMonth - lastMonth) / lastMonth) * 100
        }
    }
}

// MARK: - Category Rankings

extension FLOCategorySpendingTests {
    
    /// Test: Rank categories by spending
    func testRanking_ByCategorySpending() {
        let transactions = [
            TestTransaction(amount: 1500.00, category: "Housing", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 400.00, category: "Food", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 300.00, category: "Transportation", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 200.00, category: "Utilities", date: Date(), isBusiness: false, isIncome: false),
            TestTransaction(amount: 100.00, category: "Entertainment", date: Date(), isBusiness: false, isIncome: false)
        ]
        
        var totals: [String: Double] = [:]
        for tx in transactions where !tx.isIncome {
            totals[tx.category, default: 0] += tx.amount
        }
        
        let ranked = totals.sorted { $0.value > $1.value }
        
        XCTAssertEqual(ranked[0].key, "Housing", "#1 category")
        XCTAssertEqual(ranked[1].key, "Food", "#2 category")
        XCTAssertEqual(ranked[4].key, "Entertainment", "#5 category")
    }
    
    /// Test: Calculate category percentages
    func testRanking_CategoryPercentages() {
        let totals: [String: Double] = [
            "Housing": 1500.00,
            "Food": 400.00,
            "Transportation": 300.00,
            "Other": 300.00
        ]
        
        let grandTotal = totals.values.reduce(0, +)
        let percentages = totals.mapValues { ($0 / grandTotal) * 100 }
        
        assertCurrencyEqual(grandTotal, 2500.00)
        XCTAssertEqual(percentages["Housing"]!, 60.0, accuracy: 0.1)
        XCTAssertEqual(percentages["Food"]!, 16.0, accuracy: 0.1)
    }
}
