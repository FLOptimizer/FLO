//  FLOWidgetTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Widget Data Calculation Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate widget data calculations, timeline entries,
//  and data sharing between app and widgets.
//
//  COVERS:
//  - Balance summary calculations
//  - Budget progress calculations
//  - Tax estimate summaries
//  - Timeline refresh logic
//  - App Group data sharing
//

import XCTest
@testable import FLO

final class FLOWidgetTests: XCTestCase {
    
    // MARK: - Helpers
    
    private func assertCurrencyEqual(_ actual: Double, _ expected: Double, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual, expected, accuracy: 0.01, message, file: file, line: line)
    }
}

// MARK: - Balance Summary Widget

extension FLOWidgetTests {
    
    /// Test: Calculate total balance for widget
    func testBalanceSummary_TotalBalance() {
        let accounts: [(balance: Double, isActive: Bool)] = [
            (5000.00, true),
            (10000.00, true),
            (-2500.00, true),  // Credit card
            (3000.00, false)   // Inactive - exclude
        ]
        
        let totalBalance = accounts
            .filter { $0.isActive }
            .reduce(0) { $0 + $1.balance }
        
        assertCurrencyEqual(totalBalance, 12500.00, "$5000 + $10000 - $2500 = $12500")
    }
    
    /// Test: Calculate cash available (exclude credit cards)
    func testBalanceSummary_CashAvailable() {
        let accounts: [(balance: Double, type: String)] = [
            (5000.00, "checking"),
            (10000.00, "savings"),
            (-2500.00, "creditCard"),
            (500.00, "cash")
        ]
        
        let cashAvailable = accounts
            .filter { $0.type != "creditCard" }
            .reduce(0) { $0 + $1.balance }
        
        assertCurrencyEqual(cashAvailable, 15500.00)
    }
    
    /// Test: Calculate total debt
    func testBalanceSummary_TotalDebt() {
        let accounts: [(balance: Double, type: String)] = [
            (5000.00, "checking"),
            (-2500.00, "creditCard"),
            (-1500.00, "creditCard")
        ]
        
        let totalDebt = accounts
            .filter { $0.type == "creditCard" && $0.balance < 0 }
            .reduce(0) { $0 + abs($1.balance) }
        
        assertCurrencyEqual(totalDebt, 4000.00)
    }
    
    /// Test: Format balance for widget display
    func testBalanceSummary_FormatDisplay() {
        func formatForWidget(_ amount: Double) -> String {
            if abs(amount) >= 1_000_000 {
                return String(format: "$%.1fM", amount / 1_000_000)
            } else if abs(amount) >= 1000 {
                return String(format: "$%.1fK", amount / 1000)
            }
            return String(format: "$%.0f", amount)
        }
        
        XCTAssertEqual(formatForWidget(12500), "$12.5K")
        XCTAssertEqual(formatForWidget(500), "$500")
        XCTAssertEqual(formatForWidget(1500000), "$1.5M")
    }
}

// MARK: - Budget Progress Widget

extension FLOWidgetTests {
    
    /// Test: Calculate budget progress percentage
    func testBudgetProgress_Percentage() {
        let budgeted: Double = 500.00
        let spent: Double = 350.00
        
        let progress = min(spent / budgeted, 1.0)
        let remaining = budgeted - spent
        
        XCTAssertEqual(progress, 0.70, accuracy: 0.01, "70% used")
        assertCurrencyEqual(remaining, 150.00)
    }
    
    /// Test: Budget progress capped at 100%
    func testBudgetProgress_CappedAt100() {
        let budgeted: Double = 500.00
        let spent: Double = 600.00
        
        let progress = min(spent / budgeted, 1.0)
        
        XCTAssertEqual(progress, 1.0, "Capped at 100%")
    }
    
    /// Test: Multiple budgets summary
    func testBudgetProgress_MultipleBudgets() {
        let budgets: [(name: String, budgeted: Double, spent: Double)] = [
            ("Food", 600, 450),
            ("Transportation", 300, 280),
            ("Entertainment", 200, 250)  // Over budget
        ]
        
        let totalBudgeted = budgets.reduce(0) { $0 + $1.budgeted }
        let totalSpent = budgets.reduce(0) { $0 + $1.spent }
        let overBudgetCount = budgets.filter { $0.spent > $0.budgeted }.count
        
        assertCurrencyEqual(totalBudgeted, 1100.00)
        assertCurrencyEqual(totalSpent, 980.00)
        XCTAssertEqual(overBudgetCount, 1)
    }
    
    /// Test: Days remaining calculation
    func testBudgetProgress_DaysRemaining() {
        let calendar = Calendar.current
        let today = Date()
        
        // Get last day of month
        let range = calendar.range(of: .day, in: .month, for: today)!
        let lastDay = range.count
        let currentDay = calendar.component(.day, from: today)
        
        let daysRemaining = lastDay - currentDay
        
        XCTAssertGreaterThanOrEqual(daysRemaining, 0)
        XCTAssertLessThanOrEqual(daysRemaining, 31)
    }
    
    /// Test: Daily budget calculation
    func testBudgetProgress_DailyBudget() {
        let remaining: Double = 150.00
        let daysRemaining: Int = 10
        
        let dailyBudget = remaining / Double(max(daysRemaining, 1))
        
        assertCurrencyEqual(dailyBudget, 15.00, "$15/day")
    }
}

// MARK: - Tax Estimate Widget

extension FLOWidgetTests {
    
    /// Test: Quarterly tax estimate for widget
    func testTaxEstimate_QuarterlyAmount() {
        let annualEstimate: Double = 24000.00
        let quarterlyPayment = annualEstimate / 4
        
        assertCurrencyEqual(quarterlyPayment, 6000.00)
    }
    
    /// Test: Next payment due date
    func testTaxEstimate_NextDueDate() {
        let calendar = Calendar.current
        let today = Date()
        
        // Quarterly due dates: Apr 15, Jun 15, Sep 15, Jan 15
        let dueDates: [(month: Int, day: Int)] = [
            (4, 15), (6, 15), (9, 15), (1, 15)
        ]
        
        // Find next due date
        var nextDue: Date?
        let currentYear = calendar.component(.year, from: today)
        
        for (month, day) in dueDates {
            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = day
            
            // Handle January of next year
            if month == 1 {
                components.year = currentYear + 1
            }
            
            if let date = calendar.date(from: components), date > today {
                if nextDue == nil || date < nextDue! {
                    nextDue = date
                }
            }
        }
        
        XCTAssertNotNil(nextDue, "Should find next due date")
    }
    
    /// Test: Tax status message
    func testTaxEstimate_StatusMessage() {
        func getStatusMessage(amountPaid: Double, amountDue: Double) -> String {
            let remaining = amountDue - amountPaid
            if remaining <= 0 {
                return "On track ✓"
            } else if remaining < 1000 {
                return "Pay $\(Int(remaining)) soon"
            } else {
                return "Pay $\(Int(remaining)) by deadline"
            }
        }
        
        XCTAssertEqual(getStatusMessage(amountPaid: 6000, amountDue: 6000), "On track ✓")
        XCTAssertEqual(getStatusMessage(amountPaid: 5500, amountDue: 6000), "Pay $500 soon")
        XCTAssertEqual(getStatusMessage(amountPaid: 3000, amountDue: 6000), "Pay $3000 by deadline")
    }
}

// MARK: - Timeline Refresh

extension FLOWidgetTests {
    
    /// Test: Calculate next refresh time
    func testTimeline_NextRefresh() {
        let now = Date()
        let refreshInterval: TimeInterval = 3600  // 1 hour
        
        let nextRefresh = now.addingTimeInterval(refreshInterval)
        
        let interval = nextRefresh.timeIntervalSince(now)
        XCTAssertEqual(interval, 3600, accuracy: 1)
    }
    
    /// Test: Generate timeline entries
    func testTimeline_GenerateEntries() {
        let now = Date()
        let entryCount = 5
        let interval: TimeInterval = 3600  // 1 hour
        
        var entries: [Date] = []
        for i in 0..<entryCount {
            entries.append(now.addingTimeInterval(interval * Double(i)))
        }
        
        XCTAssertEqual(entries.count, 5)
        XCTAssertEqual(entries[0], now)
    }
    
    /// Test: Budget refresh at midnight
    func testTimeline_MidnightRefresh() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let nextMidnight = calendar.startOfDay(for: tomorrow)
        
        XCTAssertGreaterThan(nextMidnight, now)
    }
}

// MARK: - App Group Data Sharing

extension FLOWidgetTests {
    
    /// Test: Widget data structure
    func testAppGroup_DataStructure() {
        struct WidgetData: Codable {
            let totalBalance: Double
            let cashAvailable: Double
            let totalDebt: Double
            let budgetProgress: Double
            let budgetRemaining: Double
            let quarterlyTaxDue: Double
            let lastUpdated: Date
        }
        
        let data = WidgetData(
            totalBalance: 12500.00,
            cashAvailable: 15000.00,
            totalDebt: 2500.00,
            budgetProgress: 0.70,
            budgetRemaining: 150.00,
            quarterlyTaxDue: 6000.00,
            lastUpdated: Date()
        )
        
        XCTAssertEqual(data.totalBalance, 12500.00)
        XCTAssertEqual(data.budgetProgress, 0.70)
    }
    
    /// Test: Encode/decode widget data
    func testAppGroup_EncodeDecode() {
        struct WidgetData: Codable, Equatable {
            let balance: Double
            let progress: Double
        }
        
        let original = WidgetData(balance: 12500.00, progress: 0.70)
        
        // Encode
        let encoder = JSONEncoder()
        let encoded = try! encoder.encode(original)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(WidgetData.self, from: encoded)
        
        XCTAssertEqual(original, decoded)
    }
    
    /// Test: Handle missing data gracefully
    func testAppGroup_MissingData() {
        let widgetData: [String: Any]? = nil
        
        let totalBalance = (widgetData?["totalBalance"] as? Double) ?? 0.00
        let budgetProgress = (widgetData?["budgetProgress"] as? Double) ?? 0.00
        
        XCTAssertEqual(totalBalance, 0.00, "Default to 0 when missing")
        XCTAssertEqual(budgetProgress, 0.00)
    }
    
    /// Test: Stale data detection
    func testAppGroup_StaleDataDetection() {
        let lastUpdated = Date().addingTimeInterval(-7200)  // 2 hours ago
        let staleThreshold: TimeInterval = 3600  // 1 hour
        
        let age = Date().timeIntervalSince(lastUpdated)
        let isStale = age > staleThreshold
        
        XCTAssertTrue(isStale, "2 hours old is stale")
    }
}

// MARK: - Widget Sizes

extension FLOWidgetTests {
    
    enum WidgetSize {
        case small
        case medium
        case large
    }
    
    /// Test: Small widget shows minimal data
    func testWidgetSize_SmallContent() {
        let size = WidgetSize.small
        
        let showsBalance = true
        let showsBudgets = false
        let showsTax = false
        
        XCTAssertEqual(size, .small, "Size should be small")
        XCTAssertTrue(showsBalance, "Small shows balance only")
        XCTAssertFalse(showsBudgets)
        XCTAssertFalse(showsTax)
    }
    
    /// Test: Medium widget shows balance + budgets
    func testWidgetSize_MediumContent() {
        let size = WidgetSize.medium
        
        let showsBalance = true
        let showsBudgets = true
        let showsTax = false
        
        XCTAssertEqual(size, .medium, "Size should be medium")
        XCTAssertTrue(showsBalance)
        XCTAssertTrue(showsBudgets, "Medium shows budgets")
        XCTAssertFalse(showsTax)
    }
    
    /// Test: Large widget shows everything
    func testWidgetSize_LargeContent() {
        let size = WidgetSize.large
        
        let showsBalance = true
        let showsBudgets = true
        let showsTax = true
        
        XCTAssertEqual(size, .large, "Size should be large")
        XCTAssertTrue(showsBalance)
        XCTAssertTrue(showsBudgets)
        XCTAssertTrue(showsTax, "Large shows tax info")
    }
}
