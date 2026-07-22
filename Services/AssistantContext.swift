//  AssistantContext.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Shared observable state between My Assistant Zone 2 (chat) and Zone 3 (data panel).
//  Updates automatically when the assistant answers a question, driving live data cards.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftUI

/// The type of data currently displayed in Zone 3.
enum AssistantDataType: String, Identifiable {
    case none           // Show capabilities help
    case income         // Income summary + category breakdown
    case expenses       // Expense summary + top categories
    case tax            // Tax snapshot (SE tax, deductions, filing)
    case mileage        // Mileage summary + deduction
    case categories     // Full category breakdown chart
    case budget         // Budget status overview
    case accounts       // Account balances
    case schedule_c     // Schedule C line items
    case transactions   // Transaction list (recent, top, merchant)
    case monthly        // Monthly comparison / trends
    case invoices       // Unpaid/overdue invoices
    case debt           // Debt accounts + payoff strategy
    case affordability  // Can I afford analysis
    case cashflow       // Cash flow & savings analysis
    case health         // Financial health check

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "My Assistant"
        case .income: return "Income Summary"
        case .expenses: return "Expense Summary"
        case .tax: return "Tax Estimate"
        case .mileage: return "Mileage Summary"
        case .categories: return "Category Breakdown"
        case .budget: return "Budget Status"
        case .accounts: return "Account Balances"
        case .schedule_c: return "Schedule C Overview"
        case .transactions: return "Transactions"
        case .monthly: return "Monthly Comparison"
        case .invoices: return "Invoices"
        case .debt: return "Debt Analysis"
        case .affordability: return "Affordability"
        case .cashflow: return "Cash Flow"
        case .health: return "Financial Health"
        }
    }

    var icon: String {
        switch self {
        case .none: return "bubble.left.and.text.bubble.right.fill"
        case .income: return "arrow.down.circle.fill"
        case .expenses: return "arrow.up.circle.fill"
        case .tax: return "building.columns.fill"
        case .mileage: return "car.fill"
        case .categories: return "chart.pie.fill"
        case .budget: return "chart.bar.fill"
        case .accounts: return "banknote.fill"
        case .schedule_c: return "doc.text.fill"
        case .transactions: return "creditcard.fill"
        case .monthly: return "calendar.badge.clock"
        case .invoices: return "doc.text.fill"
        case .debt: return "creditcard.trianglebadge.exclamationmark"
        case .affordability: return "house.fill"
        case .cashflow: return "arrow.left.arrow.right.circle.fill"
        case .health: return "heart.text.clipboard.fill"
        }
    }
}

/// Represents a single data item for display in Zone 3 cards.
struct AssistantDataItem: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let subtitle: String?
    let isBusiness: Bool
    let isTaxDeductible: Bool

    init(label: String, amount: Double, subtitle: String? = nil, isBusiness: Bool = false, isTaxDeductible: Bool = false) {
        self.label = label
        self.amount = amount
        self.subtitle = subtitle
        self.isBusiness = isBusiness
        self.isTaxDeductible = isTaxDeductible
    }
}

/// Shared observable context between Zone 2 (chat) and Zone 3 (data panel).
@MainActor
@Observable
final class AssistantContext {
    /// What type of data to show in Zone 3
    var dataType: AssistantDataType = .none

    /// Hero metric value (e.g., total income, total expenses)
    var heroAmount: Double = 0

    /// Hero metric label
    var heroLabel: String = ""

    /// Breakdown items for the current data type
    var dataItems: [AssistantDataItem] = []

    /// Secondary metrics (key-value pairs for supporting info)
    var secondaryMetrics: [(label: String, value: String)] = []

    /// Reset to empty state
    func reset() {
        dataType = .none
        heroAmount = 0
        heroLabel = ""
        dataItems = []
        secondaryMetrics = []
    }

    /// Update with income data
    func showIncome(total: Double, byCategory: [AssistantDataProvider.CategorySpending]) {
        dataType = .income
        heroAmount = total
        heroLabel = "Total Income (\(Calendar.current.component(.year, from: Date())))"
        dataItems = byCategory.map {
            AssistantDataItem(label: $0.categoryName, amount: $0.amount, isBusiness: $0.isBusiness)
        }
        secondaryMetrics = []
    }

    /// Update with expense data
    func showExpenses(total: Double, business: Double, personal: Double, byCategory: [AssistantDataProvider.CategorySpending]) {
        dataType = .expenses
        heroAmount = total
        heroLabel = "Total Expenses (\(Calendar.current.component(.year, from: Date())))"
        dataItems = byCategory.map {
            AssistantDataItem(label: $0.categoryName, amount: $0.amount, isBusiness: $0.isBusiness, isTaxDeductible: $0.isTaxDeductible)
        }
        let fmt = NumberFormatter.appCurrency
        secondaryMetrics = [
            ("Business", fmt.string(from: NSNumber(value: business)) ?? "$0"),
            ("Personal", fmt.string(from: NSNumber(value: personal)) ?? "$0")
        ]
    }

    /// Update with tax snapshot
    func showTax(snapshot: AssistantDataProvider.TaxSnapshot) {
        dataType = .tax
        heroAmount = snapshot.estimatedSETax
        heroLabel = "Estimated SE Tax (\(Calendar.current.component(.year, from: Date())))"
        dataItems = []
        let fmt = NumberFormatter.appCurrency
        secondaryMetrics = [
            ("Total Income", fmt.string(from: NSNumber(value: snapshot.totalIncome)) ?? "$0"),
            ("Business Expenses", fmt.string(from: NSNumber(value: snapshot.totalBusinessExpenses)) ?? "$0"),
            ("Total Deductions", fmt.string(from: NSNumber(value: snapshot.totalDeductions)) ?? "$0"),
            ("Mileage Deduction", fmt.string(from: NSNumber(value: snapshot.mileageDeduction)) ?? "$0"),
            ("State", snapshot.state),
            ("Filing Status", snapshot.filingStatus)
        ]
    }

    /// Update with mileage summary
    func showMileage(summary: AssistantDataProvider.MileageSummary) {
        dataType = .mileage
        heroAmount = summary.deductionAmount
        heroLabel = "Mileage Deduction (\(Calendar.current.component(.year, from: Date())))"
        dataItems = []
        secondaryMetrics = [
            ("Total Miles", String(format: "%.1f", summary.totalMiles)),
            ("Total Trips", "\(summary.totalTrips)"),
            ("IRS Rate", "$\(String(format: "%.3f", summary.irsRate))/mile")
        ]
    }

    /// Update with category breakdown
    func showCategories(items: [AssistantDataProvider.CategorySpending], isIncome: Bool) {
        dataType = .categories
        heroAmount = items.reduce(0) { $0 + $1.amount }
        heroLabel = isIncome ? "Income by Category (\(Calendar.current.component(.year, from: Date())))" : "Expenses by Category (\(Calendar.current.component(.year, from: Date())))"
        dataItems = items.map {
            AssistantDataItem(label: $0.categoryName, amount: $0.amount, isBusiness: $0.isBusiness, isTaxDeductible: $0.isTaxDeductible)
        }
        secondaryMetrics = []
    }

    /// Update with account balances
    func showAccounts(balances: [AssistantDataProvider.AccountBalance]) {
        dataType = .accounts
        heroAmount = balances.reduce(0) { $0 + $1.balance }
        heroLabel = "Total Balance"
        dataItems = balances.map {
            AssistantDataItem(label: $0.name, amount: $0.balance, subtitle: $0.type)
        }
        secondaryMetrics = []
    }

    /// Update with Schedule C overview
    func showScheduleC(snapshot: AssistantDataProvider.TaxSnapshot, mileage: AssistantDataProvider.MileageSummary) {
        dataType = .schedule_c
        heroAmount = snapshot.totalIncome - snapshot.totalBusinessExpenses
        heroLabel = "Net Profit/Loss (\(Calendar.current.component(.year, from: Date())))"
        dataItems = []
        let fmt = NumberFormatter.appCurrency
        secondaryMetrics = [
            ("Line 1: Gross Income", fmt.string(from: NSNumber(value: snapshot.totalIncome)) ?? "$0"),
            ("Line 9: Car/Truck", fmt.string(from: NSNumber(value: mileage.deductionAmount)) ?? "$0"),
            ("Total Expenses", fmt.string(from: NSNumber(value: snapshot.totalBusinessExpenses)) ?? "$0"),
            ("Net Profit", fmt.string(from: NSNumber(value: snapshot.totalIncome - snapshot.totalBusinessExpenses)) ?? "$0")
        ]
    }

    /// Update with transaction list
    func showTransactions(items: [AssistantDataProvider.TransactionInfo], title: String) {
        dataType = .transactions
        heroAmount = items.reduce(0) { $0 + $1.amount }
        heroLabel = title
        dataItems = items.map {
            AssistantDataItem(label: $0.merchant, amount: $0.amount, subtitle: "\($0.date) · \($0.category)")
        }
        secondaryMetrics = [("Transactions", "\(items.count)")]
    }

    /// Update with monthly comparison
    func showMonthly(summaries: [AssistantDataProvider.MonthlySummary]) {
        dataType = .monthly
        heroAmount = summaries.last?.netCashFlow ?? 0
        heroLabel = "Monthly Trend (\(Calendar.current.component(.year, from: Date())))"
        dataItems = summaries.map {
            AssistantDataItem(label: $0.month, amount: $0.netCashFlow, subtitle: "\($0.transactionCount) transactions")
        }
        let fmt = NumberFormatter.appCurrency
        let avgIncome = summaries.isEmpty ? 0 : summaries.reduce(0) { $0 + $1.income } / Double(summaries.count)
        let avgExpenses = summaries.isEmpty ? 0 : summaries.reduce(0) { $0 + $1.expenses } / Double(summaries.count)
        secondaryMetrics = [
            ("Avg Monthly Income", fmt.string(from: NSNumber(value: avgIncome)) ?? "$0"),
            ("Avg Monthly Expenses", fmt.string(from: NSNumber(value: avgExpenses)) ?? "$0"),
            ("Months Tracked", "\(summaries.count)")
        ]
    }

    /// Update with budget status
    func showBudgets(statuses: [AssistantDataProvider.BudgetStatus]) {
        dataType = .budget
        let overBudget = statuses.filter { $0.percentUsed > 100 }
        heroAmount = Double(overBudget.count)
        heroLabel = overBudget.isEmpty ? "All Budgets On Track" : "\(overBudget.count) Over Budget"
        dataItems = statuses.map {
            let pct = String(format: "%.0f%%", $0.percentUsed)
            return AssistantDataItem(label: $0.categoryName, amount: $0.spent, subtitle: "\(pct) of budget used")
        }
        let fmt = NumberFormatter.appCurrency
        let totalBudgeted = statuses.reduce(0) { $0 + $1.budgeted }
        let totalSpent = statuses.reduce(0) { $0 + $1.spent }
        secondaryMetrics = [
            ("Total Budgeted", fmt.string(from: NSNumber(value: totalBudgeted)) ?? "$0"),
            ("Total Spent", fmt.string(from: NSNumber(value: totalSpent)) ?? "$0"),
            ("Remaining", fmt.string(from: NSNumber(value: totalBudgeted - totalSpent)) ?? "$0")
        ]
    }

    /// Update with invoice data
    func showInvoices(invoices: [AssistantDataProvider.InvoiceSummary]) {
        dataType = .invoices
        heroAmount = invoices.reduce(0) { $0 + $1.amount }
        heroLabel = "Outstanding Invoices"
        dataItems = invoices.map {
            AssistantDataItem(label: $0.clientName, amount: $0.amount, subtitle: "Due: \($0.dueDate)\($0.isOverdue ? " ⚠️ OVERDUE" : "")")
        }
        let overdue = invoices.filter(\.isOverdue)
        secondaryMetrics = [
            ("Unpaid", "\(invoices.count)"),
            ("Overdue", "\(overdue.count)"),
            ("Overdue Amount", NumberFormatter.appCurrency.string(from: NSNumber(value: overdue.reduce(0) { $0 + $1.amount })) ?? "$0")
        ]
    }

    /// Update with debt analysis
    func showDebt(accounts: [AssistantDataProvider.DebtAccount], monthlyAvailable: Double) {
        dataType = .debt
        let totalDebt = accounts.reduce(0) { $0 + $1.balance }
        heroAmount = totalDebt
        heroLabel = "Total Debt"
        let fmt = NumberFormatter.appCurrency
        dataItems = accounts.map {
            let rateStr = $0.interestRate.map { String(format: "%.1f%% APR", $0) } ?? "No APR set"
            return AssistantDataItem(label: $0.name, amount: $0.balance, subtitle: "\($0.type) · \(rateStr)")
        }
        secondaryMetrics = [
            ("Accounts", "\(accounts.count)"),
            ("Highest APR", accounts.first.flatMap { a in a.interestRate.map { String(format: "%.1f%%", $0) } } ?? "N/A"),
            ("Monthly Available", fmt.string(from: NSNumber(value: monthlyAvailable)) ?? "$0")
        ]
    }

    /// Update with cash flow / savings analysis
    func showCashFlow(avgIncome: Double, avgExpenses: Double, savingsRate: Double) {
        dataType = .cashflow
        heroAmount = avgIncome - avgExpenses
        heroLabel = "Monthly Savings (3-mo avg)"
        let fmt = NumberFormatter.appCurrency
        dataItems = []
        secondaryMetrics = [
            ("Avg Income", fmt.string(from: NSNumber(value: avgIncome)) ?? "$0"),
            ("Avg Expenses", fmt.string(from: NSNumber(value: avgExpenses)) ?? "$0"),
            ("Savings Rate", String(format: "%.1f%%", savingsRate)),
            ("Annual Savings Pace", fmt.string(from: NSNumber(value: (avgIncome - avgExpenses) * 12)) ?? "$0")
        ]
    }

    /// Update with financial health check
    func showHealthCheck(
        savingsRate: Double,
        debtToIncome: Double,
        overBudgetCount: Int,
        totalBudgets: Int,
        overdueInvoices: Int,
        netWorth: Double
    ) {
        dataType = .health
        heroAmount = netWorth
        heroLabel = "Net Worth"
        let fmt = NumberFormatter.appCurrency
        dataItems = []
        secondaryMetrics = [
            ("Net Worth", fmt.string(from: NSNumber(value: netWorth)) ?? "$0"),
            ("Savings Rate", String(format: "%.1f%%", savingsRate)),
            ("Debt-to-Income", String(format: "%.1f%%", debtToIncome)),
            ("Budgets On Track", "\(totalBudgets - overBudgetCount)/\(totalBudgets)"),
            ("Overdue Invoices", "\(overdueInvoices)")
        ]
    }
}
