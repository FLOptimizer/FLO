//  InsightsService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Exclude transfers from insights
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  AI-like spending insights engine that provides proactive
//  financial guidance based on transaction patterns.
//
//  FEATURES:
//  ✅ Month-over-month spending comparisons
//  ✅ Budget status alerts (under/over budget)
//  ✅ Tax deduction opportunities
//  ✅ Milestone celebrations
//  ✅ Unusual transaction detection
//  ✅ Cash flow insights
//  ✅ Income trend analysis
//  ✅ Smart caching with TTL
//  ✅ Priority-based sorting
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Insight Model

/// Represents a single financial insight or recommendation
struct SpendingInsight: Identifiable, Equatable {
    let id: UUID
    let type: InsightType
    let priority: InsightPriority
    let title: String
    let message: String
    let icon: String
    let color: Color
    let actionable: Bool
    let actionLabel: String?
    let relatedEntityId: UUID?
    let metadata: [String: String]
    let createdAt: Date
    
    init(
        type: InsightType,
        priority: InsightPriority = .normal,
        title: String,
        message: String,
        icon: String? = nil,
        color: Color? = nil,
        actionable: Bool = false,
        actionLabel: String? = nil,
        relatedEntityId: UUID? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.type = type
        self.priority = priority
        self.title = title
        self.message = message
        self.icon = icon ?? type.defaultIcon
        self.color = color ?? type.defaultColor
        self.actionable = actionable
        self.actionLabel = actionLabel
        self.relatedEntityId = relatedEntityId
        self.metadata = metadata
        self.createdAt = Date()
    }
    
    static func == (lhs: SpendingInsight, rhs: SpendingInsight) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Insight Type

enum InsightType: String, CaseIterable {
    case warning        // Spending increase, budget exceeded
    case success        // Under budget, savings milestone
    case tip            // Tax deduction, optimization suggestion
    case milestone      // Achievement, streak
    case alert          // Unusual activity, large transaction
    case trend          // Income/expense trend
    case cashFlow       // Cash flow insight
    
    var defaultIcon: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .tip: return "lightbulb.fill"
        case .milestone: return "star.fill"
        case .alert: return "bell.fill"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .cashFlow: return "arrow.left.arrow.right"
        }
    }
    
    var defaultColor: Color {
        switch self {
        case .warning: return .orange
        case .success: return .green
        case .tip: return .blue
        case .milestone: return .yellow
        case .alert: return .red
        case .trend: return .purple
        case .cashFlow: return .teal
        }
    }
}

// MARK: - Insight Priority

enum InsightPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
    
    static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Insights Service

@MainActor
final class InsightsService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = InsightsService()
    
    // MARK: - Published State
    
    @Published private(set) var insights: [SpendingInsight] = []
    @Published private(set) var isGenerating: Bool = false
    
    // MARK: - Cache Configuration
    
    var cacheTTL: TimeInterval = 600 // 10 minutes default
    
    private var cacheTimestamp: Date?
    private var cachedDataHash: Int?
    
    // MARK: - Configuration
    
    /// Minimum spending increase percentage to trigger a warning (default: 30%)
    var spendingIncreaseThreshold: Double = 0.30
    
    /// Minimum amount for "large transaction" alert
    var largeTransactionThreshold: Double = 500.0
    
    /// Maximum number of insights to display
    var maxInsights: Int = 10
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        print("💡 InsightsService initialized")
        #endif
    }
    
    // MARK: - Generate Insights
        
        /// Generate insights from transactions, budgets, and mileage data
        /// Uses caching to avoid redundant calculations
        func generateInsights(
            transactions: [Transaction],
            budgets: [Budget],
            mileageTrips: [MileageTrip] = [],
            categories: [Category] = [],
            accounts: [Account] = [],  // v1.2: Added for debt insights
            forceRefresh: Bool = false
        ) {
            let dataHash = generateDataHash(
                transactions: transactions,
                budgets: budgets,
                mileageTrips: mileageTrips,
                accounts: accounts  // v1.2: Include in hash
            )
            
            // Check cache validity
            if !forceRefresh,
               let timestamp = cacheTimestamp,
               cachedDataHash == dataHash,
               Date().timeIntervalSince(timestamp) < cacheTTL {
                #if DEBUG
                print("💡 Insights cache HIT")
                #endif
                return
            }
            
            #if DEBUG
            print("💡 Generating fresh insights...")
            #endif
            
            isGenerating = true
            
            // v1.2: Exclude transfers from all insight calculations
            // Transfers (owner's draws, contributions, etc.) should not affect spending analysis
            let filteredTransactions = transactions.filter { !$0.isTransfer }
            
            var newInsights: [SpendingInsight] = []
            
            // Generate various insight types
            newInsights.append(contentsOf: generateSpendingComparisons(transactions: filteredTransactions, categories: categories))
            newInsights.append(contentsOf: generateBudgetInsights(transactions: filteredTransactions, budgets: budgets))
            newInsights.append(contentsOf: generateTaxInsights(transactions: filteredTransactions))
            newInsights.append(contentsOf: generateMilestoneInsights(transactions: filteredTransactions, mileageTrips: mileageTrips))
            newInsights.append(contentsOf: generateAlertInsights(transactions: filteredTransactions))
            newInsights.append(contentsOf: generateCashFlowInsights(transactions: filteredTransactions))
            newInsights.append(contentsOf: generateTrendInsights(transactions: filteredTransactions))
            
            // v1.2: Generate debt optimization insights (Premium+ only)
            if SubscriptionManager.shared.currentTier.hasDebtInsights {
                newInsights.append(contentsOf: generateDebtInsights(accounts: accounts))
            }
            
            // Sort by priority (highest first) then by date
            newInsights.sort { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority > rhs.priority
                }
                return lhs.createdAt > rhs.createdAt
            }
            
            // Limit to max insights
            insights = Array(newInsights.prefix(maxInsights))
            
            // Update cache
            cacheTimestamp = Date()
            cachedDataHash = dataHash
            isGenerating = false
            
            #if DEBUG
            print("💡 Generated \(insights.count) insights")
            #endif
        }
        
        /// Invalidate cache to force refresh on next call
        func invalidateCache() {
            cacheTimestamp = nil
            cachedDataHash = nil
            
            #if DEBUG
            print("💡 Insights cache invalidated")
            #endif
        }
        
        // MARK: - Hash Generation
        
        private func generateDataHash(
            transactions: [Transaction],
            budgets: [Budget],
            mileageTrips: [MileageTrip],
            accounts: [Account] = []
        ) -> Int {
            var hasher = Hasher()
            // v1.2: Exclude transfers from hash (they don't affect insights)
            let nonTransferTransactions = transactions.filter { !$0.isTransfer }
            hasher.combine(nonTransferTransactions.count)
            hasher.combine(budgets.count)
            hasher.combine(mileageTrips.count)
            hasher.combine(accounts.count)
            
            // Include recent transaction amounts
            let recentTransactions = nonTransferTransactions.prefix(50)
            for tx in recentTransactions {
                hasher.combine(Int(tx.amount * 100))
            }
            
            // v1.2: Include account balances for debt tracking
            for account in accounts.prefix(10) {
                hasher.combine(Int(account.currentBalance * 100))
            }
            
            return hasher.finalize()
        }
    
    // MARK: - Spending Comparisons
    
    private func generateSpendingComparisons(
        transactions: [Transaction],
        categories: [Category]
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Get this month and last month transactions
        let now = Date()
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
        
        let thisMonthTransactions = transactions.filter {
            !$0.isIncome && $0.date >= thisMonthStart
        }
        let lastMonthTransactions = transactions.filter {
            !$0.isIncome && $0.date >= lastMonthStart && $0.date < thisMonthStart
        }
        
        // Group by category
        let thisMonthByCategory = Dictionary(grouping: thisMonthTransactions) { $0.category?.id }
        let lastMonthByCategory = Dictionary(grouping: lastMonthTransactions) { $0.category?.id }
        
        // Compare each category
        for (categoryId, thisMonthTxs) in thisMonthByCategory {
            let thisMonthTotal = thisMonthTxs.reduce(0) { $0 + $1.amount }
            let lastMonthTxs = lastMonthByCategory[categoryId] ?? []
            let lastMonthTotal = lastMonthTxs.reduce(0) { $0 + $1.amount }
            
            guard lastMonthTotal > 0 else { continue }
            
            let changePercent = (thisMonthTotal - lastMonthTotal) / lastMonthTotal
            let categoryName = thisMonthTxs.first?.category?.name ?? "Uncategorized"
            
            if changePercent > spendingIncreaseThreshold {
                let percentText = Int(changePercent * 100)
                insights.append(SpendingInsight(
                    type: .warning,
                    priority: changePercent > 0.5 ? .high : .normal,
                    title: "\(categoryName) Spending Up",
                    message: "You've spent \(percentText)% more on \(categoryName) this month compared to last month.",
                    actionable: true,
                    actionLabel: "View Transactions",
                    relatedEntityId: categoryId,
                    metadata: [
                        "thisMonth": formatCurrency(thisMonthTotal),
                        "lastMonth": formatCurrency(lastMonthTotal),
                        "change": "\(percentText)%"
                    ]
                ))
            } else if changePercent < -0.20 && thisMonthTotal > 50 {
                // Spending decreased significantly - celebrate!
                let percentText = Int(abs(changePercent) * 100)
                insights.append(SpendingInsight(
                    type: .success,
                    priority: .normal,
                    title: "Nice Savings!",
                    message: "Your \(categoryName) spending is down \(percentText)% from last month.",
                    metadata: [
                        "thisMonth": formatCurrency(thisMonthTotal),
                        "lastMonth": formatCurrency(lastMonthTotal),
                        "saved": formatCurrency(lastMonthTotal - thisMonthTotal)
                    ]
                ))
            }
        }
        
        // Overall spending comparison
        let thisMonthTotal = thisMonthTransactions.reduce(0) { $0 + $1.amount }
        let lastMonthTotal = lastMonthTransactions.reduce(0) { $0 + $1.amount }
        
        if lastMonthTotal > 0 {
            let overallChange = (thisMonthTotal - lastMonthTotal) / lastMonthTotal
            
            if overallChange > 0.25 {
                insights.append(SpendingInsight(
                    type: .warning,
                    priority: .high,
                    title: "Overall Spending Up",
                    message: "Your total spending is up \(Int(overallChange * 100))% this month. Review your expenses to stay on track.",
                    icon: "chart.line.uptrend.xyaxis",
                    actionable: true,
                    actionLabel: "View All Expenses"
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Budget Insights
    
    private func generateBudgetInsights(
        transactions: [Transaction],
        budgets: [Budget]
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Get current month budgets
        let now = Date()
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        let currentBudgets = budgets.filter { budget in
            calendar.isDate(budget.month, equalTo: thisMonthStart, toGranularity: .month)
        }
        
        var underBudgetCount = 0
        var overBudgetCategories: [String] = []
        
        for budget in currentBudgets {
            guard let category = budget.category else { continue }
            
            // Calculate spent amount for this budget's category
            let spent = transactions.filter { tx in
                !tx.isIncome &&
                tx.category?.id == category.id &&
                tx.date >= thisMonthStart &&
                tx.financeType == budget.financeType
            }.reduce(0) { $0 + $1.amount }
            
            let budgetAmount = budget.planned + budget.carryOver
            let percentUsed = budgetAmount > 0 ? spent / budgetAmount : 0
            
            if percentUsed > 1.0 {
                // Over budget
                overBudgetCategories.append(category.name)
                let overAmount = spent - budgetAmount
                
                insights.append(SpendingInsight(
                    type: .alert,
                    priority: .high,
                    title: "\(category.name) Over Budget",
                    message: "You've exceeded your \(category.name) budget by \(formatCurrency(overAmount)).",
                    icon: "exclamationmark.circle.fill",
                    color: .red,
                    actionable: true,
                    actionLabel: "Adjust Budget",
                    relatedEntityId: budget.id,
                    metadata: [
                        "budget": formatCurrency(budgetAmount),
                        "spent": formatCurrency(spent),
                        "over": formatCurrency(overAmount)
                    ]
                ))
            } else if percentUsed > 0.9 {
                // Approaching budget limit
                let remaining = budgetAmount - spent
                insights.append(SpendingInsight(
                    type: .warning,
                    priority: .normal,
                    title: "\(category.name) Budget Alert",
                    message: "You've used \(Int(percentUsed * 100))% of your \(category.name) budget. \(formatCurrency(remaining)) remaining.",
                    actionable: true,
                    actionLabel: "View Budget",
                    relatedEntityId: budget.id
                ))
            } else if percentUsed < 0.5 && spent > 0 {
                underBudgetCount += 1
            }
        }
        
        // Success insight for being under budget
        if underBudgetCount >= 3 {
            insights.append(SpendingInsight(
                type: .success,
                priority: .normal,
                title: "Great Budget Management!",
                message: "You're under budget in \(underBudgetCount) categories. Keep up the good work!",
                icon: "trophy.fill",
                color: .green
            ))
        }
        
        return insights
    }
    
    // MARK: - Tax Insights
    
    private func generateTaxInsights(transactions: [Transaction]) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Get this year's transactions
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1))!
        let yearTransactions = transactions.filter { $0.date >= yearStart }
        
        // Find business expenses not marked as tax deductible
        let businessExpenses = yearTransactions.filter {
            !$0.isIncome && $0.financeType == .business
        }
        
        let notDeductible = businessExpenses.filter {
            $0.category?.isTaxDeductible != true
        }
        
        let potentialDeductions = notDeductible.reduce(0) { $0 + $1.amount }
        
        if potentialDeductions > 100 {
            // Estimate tax savings (rough 25% effective rate)
            let potentialSavings = potentialDeductions * 0.25
            
            insights.append(SpendingInsight(
                type: .tip,
                priority: .normal,
                title: "Potential Tax Savings",
                message: "You have \(formatCurrency(potentialDeductions)) in business expenses that might be tax-deductible. This could save you ~\(formatCurrency(potentialSavings)) in taxes.",
                actionable: true,
                actionLabel: "Review Expenses",
                metadata: [
                    "amount": formatCurrency(potentialDeductions),
                    "potentialSavings": formatCurrency(potentialSavings),
                    "transactionCount": "\(notDeductible.count)"
                ]
            ))
        }
        
        // Check for uncategorized business expenses
        let uncategorizedBusiness = businessExpenses.filter { $0.category == nil }
        if uncategorizedBusiness.count >= 5 {
            insights.append(SpendingInsight(
                type: .tip,
                priority: .normal,
                title: "Categorize for Taxes",
                message: "You have \(uncategorizedBusiness.count) uncategorized business expenses. Categorizing them helps maximize deductions.",
                icon: "tag.fill",
                actionable: true,
                actionLabel: "Categorize Now"
            ))
        }
        
        return insights
    }
    
    // MARK: - Milestone Insights
    
    private func generateMilestoneInsights(
        transactions: [Transaction],
        mileageTrips: [MileageTrip]
    ) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Mileage milestones
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1))!
        let yearTrips = mileageTrips.filter { $0.startDate >= yearStart }
        let totalMiles = yearTrips.reduce(0) { $0 + $1.distanceMiles }
        
        // Check for mileage milestones
        let milestones = [100.0, 500.0, 1000.0, 2500.0, 5000.0, 10000.0]
        for milestone in milestones {
            if totalMiles >= milestone && totalMiles < milestone * 1.1 {
                // Just passed this milestone
                let deductionValue = totalMiles * 0.67 // 2024 IRS rate
                insights.append(SpendingInsight(
                    type: .milestone,
                    priority: .normal,
                    title: "\(Int(milestone)) Miles Tracked! 🎉",
                    message: "You've logged \(Int(totalMiles)) business miles this year, worth ~\(formatCurrency(deductionValue)) in deductions.",
                    icon: "car.fill",
                    color: .yellow
                ))
                break
            }
        }
        
        // This month's mileage
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let thisMonthTrips = mileageTrips.filter { $0.startDate >= thisMonthStart }
        let thisMonthMiles = thisMonthTrips.reduce(0) { $0 + $1.distanceMiles }
        
        if thisMonthMiles >= 100 {
            insights.append(SpendingInsight(
                type: .success,
                priority: .low,
                title: "Great Mileage Tracking!",
                message: "You've logged \(Int(thisMonthMiles)) miles this month. Keep tracking for maximum deductions!",
                icon: "location.fill"
            ))
        }
        
        // Transaction tracking milestone
        let yearTransactions = transactions.filter { $0.date >= yearStart }
        let transactionMilestones = [50, 100, 250, 500, 1000]
        for milestone in transactionMilestones {
            if yearTransactions.count >= milestone && yearTransactions.count < milestone + 10 {
                insights.append(SpendingInsight(
                    type: .milestone,
                    priority: .low,
                    title: "\(milestone) Transactions Tracked!",
                    message: "You're building great financial habits. Keep it up!",
                    icon: "checkmark.seal.fill",
                    color: .purple
                ))
                break
            }
        }
        
        return insights
    }
    
    // MARK: - Alert Insights
    
    private func generateAlertInsights(transactions: [Transaction]) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Find large transactions in the last 7 days
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentLarge = transactions.filter {
            !$0.isIncome &&
            $0.date >= weekAgo &&
            $0.amount >= largeTransactionThreshold
        }
        
        for tx in recentLarge.prefix(3) {
            let categoryName = tx.category?.name ?? "Uncategorized"
            insights.append(SpendingInsight(
                type: .alert,
                priority: .normal,
                title: "Large Expense",
                message: "\(formatCurrency(tx.amount)) spent on \(categoryName) on \(formatDate(tx.date)).",
                icon: "dollarsign.circle.fill",
                color: .orange,
                actionable: true,
                actionLabel: "View Details",
                relatedEntityId: tx.id,
                metadata: [
                    "amount": formatCurrency(tx.amount),
                    "category": categoryName,
                    "date": formatDate(tx.date)
                ]
            ))
        }
        
        // Duplicate transaction warning
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let thisMonth = transactions.filter {
            $0.date >= thisMonthStart
        }
        
        // Group by amount and check for potential duplicates
        let byAmount = Dictionary(grouping: thisMonth) { Int($0.amount * 100) }
        for (_, txs) in byAmount where txs.count >= 2 {
            let first = txs[0]
            let second = txs[1]
            
            // If same amount on same day, might be duplicate
            if calendar.isDate(first.date, inSameDayAs: second.date) && first.amount > 20 {
                insights.append(SpendingInsight(
                    type: .alert,
                    priority: .normal,
                    title: "Possible Duplicate",
                    message: "Two transactions of \(formatCurrency(first.amount)) on \(formatDate(first.date)). Worth checking!",
                    icon: "doc.on.doc.fill",
                    actionable: true,
                    actionLabel: "Review"
                ))
                break // Only show one duplicate warning
            }
        }
        
        return insights
    }
    
    // MARK: - Cash Flow Insights
    
    private func generateCashFlowInsights(transactions: [Transaction]) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // This month's cash flow
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let thisMonth = transactions.filter { $0.date >= thisMonthStart }
        
        let income = thisMonth.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        let expenses = thisMonth.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let netCashFlow = income - expenses
        
        if netCashFlow < 0 && abs(netCashFlow) > 500 {
            insights.append(SpendingInsight(
                type: .cashFlow,
                priority: .high,
                title: "Negative Cash Flow",
                message: "You've spent \(formatCurrency(abs(netCashFlow))) more than you've earned this month. Consider reviewing expenses.",
                icon: "arrow.down.circle.fill",
                color: .red,
                actionable: true,
                actionLabel: "View Details",
                metadata: [
                    "income": formatCurrency(income),
                    "expenses": formatCurrency(expenses),
                    "net": formatCurrency(netCashFlow)
                ]
            ))
        } else if netCashFlow > 1000 {
            insights.append(SpendingInsight(
                type: .cashFlow,
                priority: .normal,
                title: "Positive Cash Flow! 💰",
                message: "Great job! You're \(formatCurrency(netCashFlow)) ahead this month.",
                icon: "arrow.up.circle.fill",
                color: .green,
                metadata: [
                    "income": formatCurrency(income),
                    "expenses": formatCurrency(expenses),
                    "net": formatCurrency(netCashFlow)
                ]
            ))
        }
        
        return insights
    }
    
    // MARK: - Trend Insights
    
    private func generateTrendInsights(transactions: [Transaction]) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let calendar = Calendar.current
        
        // Compare last 3 months of income
        var monthlyIncome: [(month: Date, amount: Double)] = []
        
        for i in 0..<3 {
            let monthStart = calendar.date(byAdding: .month, value: -i, to: Date())!
            let monthStartNormalized = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart))!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStartNormalized)!
            
            let monthIncome = transactions.filter {
                $0.isIncome && $0.date >= monthStartNormalized && $0.date < monthEnd
            }.reduce(0) { $0 + $1.amount }
            
            monthlyIncome.append((monthStartNormalized, monthIncome))
        }
        
        // Check for income trend
        if monthlyIncome.count >= 3 {
            let current = monthlyIncome[0].amount
            let previous = monthlyIncome[1].amount
            let twoMonthsAgo = monthlyIncome[2].amount
            
            // Consistent growth
            if current > previous && previous > twoMonthsAgo && twoMonthsAgo > 0 {
                let growthRate = (current - twoMonthsAgo) / twoMonthsAgo
                if growthRate > 0.1 {
                    insights.append(SpendingInsight(
                        type: .trend,
                        priority: .normal,
                        title: "Income Growing! 📈",
                        message: "Your income has grown \(Int(growthRate * 100))% over the last 3 months. Great momentum!",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    ))
                }
            }
            
            // Income decline warning
            if current < previous && previous < twoMonthsAgo && current > 0 && twoMonthsAgo > 0 {
                let declineRate = (twoMonthsAgo - current) / twoMonthsAgo
                if declineRate > 0.15 {
                    insights.append(SpendingInsight(
                        type: .trend,
                        priority: .high,
                        title: "Income Declining",
                        message: "Your income has decreased \(Int(declineRate * 100))% over the last 3 months. Consider diversifying income sources.",
                        icon: "chart.line.downtrend.xyaxis",
                        color: .orange
                    ))
                }
            }
        }
        
        return insights
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview Support

extension InsightsService {
    /// Sample insights for SwiftUI previews
    static var previewInsights: [SpendingInsight] {
        [
            SpendingInsight(
                type: .warning,
                priority: .high,
                title: "Dining Out Spending Up",
                message: "You've spent 45% more on dining this month compared to last month.",
                actionable: true,
                actionLabel: "View Transactions"
            ),
            SpendingInsight(
                type: .success,
                priority: .normal,
                title: "Under Budget!",
                message: "You're under budget in 4 categories. Keep up the great work!"
            ),
            SpendingInsight(
                type: .tip,
                priority: .normal,
                title: "Tax Tip",
                message: "Marking your office supplies as tax-deductible could save you ~$150.",
                actionable: true,
                actionLabel: "Review"
            ),
            SpendingInsight(
                type: .milestone,
                priority: .normal,
                title: "500 Miles Tracked! 🎉",
                message: "You've logged 500 business miles, worth ~$335 in deductions."
            ),
            SpendingInsight(
                type: .cashFlow,
                priority: .normal,
                title: "Positive Cash Flow",
                message: "You're $2,450 ahead this month. Great job!"
            )
        ]
    }
}
