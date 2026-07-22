//  AssistantDataProvider.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Aggregates FLO financial data for My Assistant queries.
//  Provides structured financial snapshots, category breakdowns,
//  tax estimates, and mileage summaries for the on-device AI model.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftData

/// Provides financial data context for My Assistant queries.
/// All methods operate on pre-fetched data or use the provided ModelContext.
@MainActor
final class AssistantDataProvider {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Transaction Summary

    struct TransactionSummary: Codable {
        let totalIncome: Double
        let totalExpenses: Double
        let netCashFlow: Double
        let transactionCount: Int
        let periodDescription: String
    }

    func getTransactionSummary(startDate: Date, endDate: Date) -> TransactionSummary {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= startDate && $0.date < endDate }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let nonTransfer = transactions.filter { !$0.isTransfer }

        let income = nonTransfer.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expenses = nonTransfer.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

        let fmt = DateFormatter.shortMonthYear
        let period = "\(fmt.string(from: startDate)) - \(fmt.string(from: endDate))"

        return TransactionSummary(
            totalIncome: income,
            totalExpenses: expenses,
            netCashFlow: income - expenses,
            transactionCount: nonTransfer.count,
            periodDescription: period
        )
    }

    // MARK: - Category Breakdown

    struct CategorySpending: Codable {
        let categoryName: String
        let amount: Double
        let isBusiness: Bool
        let isTaxDeductible: Bool
    }

    /// Income broken down by category/source
    func getIncomeByCategory(year: Int) -> [CategorySpending] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let income = transactions.filter { $0.isIncome && !$0.isTransfer }

        let grouped = Dictionary(grouping: income) { $0.category?.name ?? "Uncategorized" }

        return grouped.map { (name, txns) in
            let amount = txns.reduce(0) { $0 + $1.amount }
            let category = txns.first?.category
            return CategorySpending(
                categoryName: name,
                amount: amount,
                isBusiness: category?.isBusiness ?? false,
                isTaxDeductible: category?.isTaxDeductible ?? false
            )
        }.sorted { $0.amount > $1.amount }
    }

    /// Expenses broken down by category
    func getCategoryBreakdown(year: Int) -> [CategorySpending] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }

        let grouped = Dictionary(grouping: expenses) { $0.category?.name ?? "Uncategorized" }

        return grouped.map { (name, txns) in
            let amount = txns.reduce(0) { $0 + $1.amount }
            let category = txns.first?.category
            return CategorySpending(
                categoryName: name,
                amount: amount,
                isBusiness: category?.isBusiness ?? false,
                isTaxDeductible: category?.isTaxDeductible ?? false
            )
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Tax Estimate

    struct TaxSnapshot: Codable {
        let totalIncome: Double
        let totalBusinessExpenses: Double
        let totalPersonalExpenses: Double
        let estimatedSETax: Double
        let totalDeductions: Double
        let mileageDeduction: Double
        let state: String
        let filingStatus: String
    }

    func getTaxSnapshot(year: Int) -> TaxSnapshot {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else {
            return TaxSnapshot(totalIncome: 0, totalBusinessExpenses: 0, totalPersonalExpenses: 0,
                             estimatedSETax: 0, totalDeductions: 0, mileageDeduction: 0,
                             state: "Unknown", filingStatus: "Unknown")
        }

        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd }
        )
        let transactions = (try? modelContext.fetch(txDescriptor)) ?? []
        let nonTransfer = transactions.filter { !$0.isTransfer }

        let income = nonTransfer.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let businessExpenses = nonTransfer.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }
        let personalExpenses = nonTransfer.filter { !$0.isIncome && $0.financeType == .personal }.reduce(0) { $0 + $1.amount }

        // Deductible expenses
        let deductible = nonTransfer.filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }.reduce(0) { $0 + $1.amount }

        // Mileage
        let tripDescriptor = FetchDescriptor<MileageTrip>(
            predicate: #Predicate<MileageTrip> { $0.startDate >= yearStart && $0.startDate < yearEnd }
        )
        let trips = (try? modelContext.fetch(tripDescriptor)) ?? []
        let totalMiles = trips.reduce(0) { $0 + $1.distanceMiles }
        let mileageRate: Double = year >= 2026 ? 0.725 : 0.70 // IRS standard rate by year
        let mileageDeduction = totalMiles * mileageRate

        // Tax settings
        let settingsDescriptor = FetchDescriptor<TaxSettings>()
        let settings = (try? modelContext.fetch(settingsDescriptor))?.first

        // SE Tax estimate (15.3% on 92.35% of net self-employment income)
        let netSEIncome = income - businessExpenses
        let seTax = netSEIncome > 0 ? netSEIncome * 0.9235 * 0.153 : 0

        return TaxSnapshot(
            totalIncome: income,
            totalBusinessExpenses: businessExpenses,
            totalPersonalExpenses: personalExpenses,
            estimatedSETax: seTax,
            totalDeductions: deductible + mileageDeduction,
            mileageDeduction: mileageDeduction,
            state: settings?.state ?? "Not Set",
            filingStatus: settings?.filingStatus.rawValue ?? "Not Set"
        )
    }

    // MARK: - Mileage Summary

    struct MileageSummary: Codable {
        let totalMiles: Double
        let totalTrips: Int
        let deductionAmount: Double
        let irsRate: Double
    }

    func getMileageSummary(year: Int) -> MileageSummary {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return MileageSummary(totalMiles: 0, totalTrips: 0, deductionAmount: 0, irsRate: 0.70) }

        let descriptor = FetchDescriptor<MileageTrip>(
            predicate: #Predicate<MileageTrip> { $0.startDate >= yearStart && $0.startDate < yearEnd }
        )
        let trips = (try? modelContext.fetch(descriptor)) ?? []
        let totalMiles = trips.reduce(0) { $0 + $1.distanceMiles }
        let rate: Double = year >= 2026 ? 0.725 : 0.70

        return MileageSummary(
            totalMiles: totalMiles,
            totalTrips: trips.count,
            deductionAmount: totalMiles * rate,
            irsRate: rate
        )
    }

    // MARK: - Account Balances

    struct AccountBalance: Codable {
        let name: String
        let balance: Double
        let type: String
    }

    func getAccountBalances() -> [AccountBalance] {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        let accounts = (try? modelContext.fetch(descriptor)) ?? []

        return accounts.map {
            AccountBalance(
                name: $0.name,
                balance: $0.currentBalance,
                type: $0.accountType.rawValue
            )
        }
    }

    // MARK: - Monthly Summary (for time comparisons)

    struct MonthlySummary: Codable {
        let month: String
        let income: Double
        let expenses: Double
        let netCashFlow: Double
        let transactionCount: Int
    }

    func getMonthlySummaries(year: Int) -> [MonthlySummary] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let nonTransfer = transactions.filter { !$0.isTransfer }

        var summaries: [MonthlySummary] = []
        for month in 1...12 {
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                  monthStart <= Date()
            else { continue }

            let monthTxns = nonTransfer.filter { calendar.component(.month, from: $0.date) == month }
            guard !monthTxns.isEmpty else { continue }

            let inc = monthTxns.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let exp = monthTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

            summaries.append(MonthlySummary(
                month: DateFormatter.fullMonth.string(from: monthStart),
                income: inc,
                expenses: exp,
                netCashFlow: inc - exp,
                transactionCount: monthTxns.count
            ))
        }
        return summaries
    }

    // MARK: - Top Transactions

    struct TransactionInfo: Codable {
        let merchant: String
        let amount: Double
        let date: String
        let category: String
        let isIncome: Bool
    }

    func getTopExpenses(year: Int, limit: Int = 10) -> [TransactionInfo] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd },
            sortBy: [SortDescriptor(\Transaction.amount, order: .reverse)]
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []

        return transactions
            .filter { !$0.isIncome && !$0.isTransfer }
            .prefix(limit)
            .map { TransactionInfo(
                merchant: $0.merchantName,
                amount: $0.amount,
                date: DateFormatter.mediumDate.string(from: $0.date),
                category: $0.category?.name ?? "Uncategorized",
                isIncome: false
            )}
    }

    func getRecentTransactions(limit: Int = 10) -> [TransactionInfo] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []

        return transactions
            .filter { !$0.isTransfer }
            .prefix(limit)
            .map { TransactionInfo(
                merchant: $0.merchantName,
                amount: $0.amount,
                date: DateFormatter.mediumDate.string(from: $0.date),
                category: $0.category?.name ?? "Uncategorized",
                isIncome: $0.isIncome
            )}
    }

    func getTransfers(limit: Int = 15) -> [TransactionInfo] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []

        return transactions
            .filter { $0.isTransfer }
            .prefix(limit)
            .map { TransactionInfo(
                merchant: $0.merchantName,
                amount: $0.amount,
                date: DateFormatter.mediumDate.string(from: $0.date),
                category: "Transfer",
                isIncome: $0.isIncome
            )}
    }

    func getMerchantSpending(year: Int) -> [(merchant: String, total: Double, count: Int)] {
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return [] }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }

        let grouped = Dictionary(grouping: expenses) { $0.merchantName }
        return grouped.map { (merchant, txns) in
            (merchant: merchant, total: txns.reduce(0) { $0 + $1.amount }, count: txns.count)
        }.sorted { $0.total > $1.total }
    }

    // MARK: - Budget Status

    struct BudgetStatus: Codable {
        let categoryName: String
        let budgeted: Double
        let spent: Double
        let remaining: Double
        let percentUsed: Double
    }

    func getBudgetStatus() -> [BudgetStatus] {
        let calendar = Calendar.current
        let now = Date()
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!

        let budgetDescriptor = FetchDescriptor<Budget>()
        let budgets = (try? modelContext.fetch(budgetDescriptor)) ?? []
        let currentBudgets = budgets.filter { calendar.isDate($0.month, equalTo: now, toGranularity: .month) }

        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= monthStart && $0.date < monthEnd }
        )
        let transactions = (try? modelContext.fetch(txDescriptor)) ?? []

        return currentBudgets.compactMap { budget in
            let catName = budget.category?.name ?? "Uncategorized"
            let spent = transactions
                .filter { !$0.isIncome && !$0.isTransfer && $0.category?.name == catName }
                .reduce(0) { $0 + $1.amount }

            let budgeted = budget.planned
            guard budgeted > 0 else { return nil }

            return BudgetStatus(
                categoryName: catName,
                budgeted: budgeted,
                spent: spent,
                remaining: budgeted - spent,
                percentUsed: (spent / budgeted) * 100
            )
        }.sorted { $0.percentUsed > $1.percentUsed }
    }

    // MARK: - Invoice Summary

    struct InvoiceSummary: Codable {
        let clientName: String
        let amount: Double
        let dueDate: String
        let status: String
        let isOverdue: Bool
    }

    func getUnpaidInvoices() -> [InvoiceSummary] {
        let descriptor = FetchDescriptor<Invoice>(
            sortBy: [SortDescriptor(\Invoice.dueDate, order: .forward)]
        )
        let invoices = (try? modelContext.fetch(descriptor)) ?? []

        return invoices
            .filter { $0.status != .paid && $0.status != .cancelled }
            .map { invoice in
                InvoiceSummary(
                    clientName: invoice.client?.name ?? "Unknown",
                    amount: invoice.totalAmount,
                    dueDate: DateFormatter.mediumDate.string(from: invoice.dueDate),
                    status: invoice.status.rawValue,
                    isOverdue: invoice.dueDate < Date() && invoice.status != .paid
                )
            }
    }

    // MARK: - Debt & Affordability Analysis

    struct DebtAccount: Codable {
        let name: String
        let balance: Double
        let type: String
        let interestRate: Double?
    }

    func getDebtAccounts() -> [DebtAccount] {
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        let accounts = (try? modelContext.fetch(descriptor)) ?? []

        // Debt = negative balance accounts (credit cards, loans)
        return accounts
            .filter { $0.currentBalance < 0 || $0.accountType == .creditCard || $0.accountType == .loan }
            .filter { abs($0.currentBalance) > 0 }
            .map { DebtAccount(
                name: $0.name,
                balance: abs($0.currentBalance),
                type: $0.accountType.rawValue,
                interestRate: $0.apr
            )}
            .sorted { ($0.interestRate ?? 0) > ($1.interestRate ?? 0) }
    }

    func getMonthlyAverages(months: Int = 3) -> (income: Double, expenses: Double, savings: Double) {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .month, value: -months, to: Date()) else {
            return (0, 0, 0)
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start }
        )
        let transactions = (try? modelContext.fetch(descriptor)) ?? []
        let nonTransfer = transactions.filter { !$0.isTransfer }

        let totalIncome = nonTransfer.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let totalExpenses = nonTransfer.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

        let avgIncome = totalIncome / Double(months)
        let avgExpenses = totalExpenses / Double(months)

        return (income: avgIncome, expenses: avgExpenses, savings: avgIncome - avgExpenses)
    }

    // MARK: - Financial Snapshot (Combined)

    func getFinancialContext(year: Int = Calendar.current.component(.year, from: Date())) -> String {
        let tax = getTaxSnapshot(year: year)
        let mileage = getMileageSummary(year: year)
        let categories = getCategoryBreakdown(year: year)
        let accounts = getAccountBalances()

        let fmt = NumberFormatter.appCurrency

        var context = """
        FINANCIAL DATA FOR \(year):

        INCOME & EXPENSES:
        - Total Income: \(fmt.string(from: NSNumber(value: tax.totalIncome)) ?? "$0")
        - Total Business Expenses: \(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")
        - Total Personal Expenses: \(fmt.string(from: NSNumber(value: tax.totalPersonalExpenses)) ?? "$0")
        - Net Cash Flow: \(fmt.string(from: NSNumber(value: tax.totalIncome - tax.totalBusinessExpenses - tax.totalPersonalExpenses)) ?? "$0")

        TAX INFORMATION:
        - State: \(tax.state)
        - Filing Status: \(tax.filingStatus)
        - Estimated Self-Employment Tax: \(fmt.string(from: NSNumber(value: tax.estimatedSETax)) ?? "$0")
        - Total Deductions: \(fmt.string(from: NSNumber(value: tax.totalDeductions)) ?? "$0")

        MILEAGE:
        - Total Miles: \(String(format: "%.1f", mileage.totalMiles))
        - Total Trips: \(mileage.totalTrips)
        - Mileage Deduction: \(fmt.string(from: NSNumber(value: mileage.deductionAmount)) ?? "$0")
        - IRS Rate: $\(String(format: "%.3f", mileage.irsRate))/mile

        """

        if !categories.isEmpty {
            context += "EXPENSE CATEGORIES (Top 10):\n"
            for cat in categories.prefix(10) {
                let amount = fmt.string(from: NSNumber(value: cat.amount)) ?? "$0"
                let flags = [
                    cat.isBusiness ? "Business" : "Personal",
                    cat.isTaxDeductible ? "Tax Deductible" : nil
                ].compactMap { $0 }.joined(separator: ", ")
                context += "- \(cat.categoryName): \(amount) (\(flags))\n"
            }
        }

        if !accounts.isEmpty {
            context += "\nACCOUNT BALANCES:\n"
            for account in accounts {
                let balance = fmt.string(from: NSNumber(value: account.balance)) ?? "$0"
                context += "- \(account.name) (\(account.type)): \(balance)\n"
            }
        }

        return context
    }

    // MARK: - Tool Backends (JSON-formatted, consumed by AssistantTools)

    private func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    func toolCategoryBreakdown(year: Int, income: Bool) -> String {
        json(income ? getIncomeByCategory(year: year) : getCategoryBreakdown(year: year))
    }

    func toolTaxSnapshot(year: Int) -> String { json(getTaxSnapshot(year: year)) }

    func toolMileage(year: Int) -> String { json(getMileageSummary(year: year)) }

    func toolAccounts() -> String { json(getAccountBalances()) }

    func toolMonthlyTrend(year: Int) -> String { json(getMonthlySummaries(year: year)) }

    func toolBudgets() -> String { json(getBudgetStatus()) }

    func toolInvoicesAndDebts() -> String {
        "{\"unpaidInvoices\":\(json(getUnpaidInvoices())),\"debtAccounts\":\(json(getDebtAccounts()))}"
    }

    private struct MerchantTotal: Codable {
        let merchant: String
        let total: Double
        let transactionCount: Int
    }

    func toolTopMerchants(year: Int, limit: Int = 15) -> String {
        let merchants = getMerchantSpending(year: year).prefix(limit).map {
            MerchantTotal(merchant: $0.merchant, total: $0.total, transactionCount: $0.count)
        }
        return json(Array(merchants))
    }

    /// Search transactions in an arbitrary date range, optionally filtered by
    /// a term matched against merchant, note, and category.
    func toolSearchTransactions(startISO: String, endISO: String, searchTerm: String, limit: Int = 40) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let start = formatter.date(from: startISO),
              let endDay = formatter.date(from: endISO),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: endDay) else {
            return "{\"error\":\"Dates must be in YYYY-MM-DD format\"}"
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var results = (try? modelContext.fetch(descriptor)) ?? []
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            results = results.filter {
                $0.merchantName.lowercased().contains(term) ||
                $0.note.lowercased().contains(term) ||
                ($0.category?.name.lowercased().contains(term) ?? false)
            }
        }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let infos = results.prefix(limit).map {
            TransactionInfo(
                merchant: $0.merchantName.isEmpty ? $0.note : $0.merchantName,
                amount: $0.amount,
                date: dateFmt.string(from: $0.date),
                category: $0.category?.name ?? "Uncategorized",
                isIncome: $0.isIncome
            )
        }
        let total = results.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        return "{\"matchCount\":\(results.count),\"totalExpenses\":\(total),\"transactions\":\(json(Array(infos)))}"
    }

    private struct EventSummary: Codable {
        let name: String
        let startDate: String
        let endDate: String
        let totalSpent: Double
        let transactionCount: Int
        let byCategory: [String: Double]
    }

    /// Spending events (trips/occasions) with totals and category breakdowns
    func toolEvents() -> String {
        let descriptor = FetchDescriptor<SpendingEvent>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let summaries = events.map { event in
            EventSummary(
                name: event.name,
                startDate: dateFmt.string(from: event.startDate),
                endDate: dateFmt.string(from: event.endDate),
                totalSpent: event.totalSpent,
                transactionCount: event.transactionCount,
                byCategory: Dictionary(uniqueKeysWithValues: event.categoryBreakdown.map { ($0.name, $0.total) })
            )
        }
        return json(summaries)
    }

    // MARK: - Action Backends (staged writes applied only after user confirmation)

    struct UncategorizedMatch {
        let ids: [UUID]
        let count: Int
        let totalAmount: Double
        let examples: [String]
    }

    /// Find uncategorized transactions in a date range (for a staged
    /// categorization proposal). Never mutates anything.
    func findUncategorizedTransactions(startISO: String, endISO: String, searchTerm: String) -> UncategorizedMatch? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let start = formatter.date(from: startISO),
              let endDay = formatter.date(from: endISO),
              let end = Calendar.current.date(byAdding: .day, value: 1, to: endDay) else { return nil }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var results = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.category == nil && !$0.isTransfer }
        let term = searchTerm.trimmingCharacters(in: .whitespaces).lowercased()
        if !term.isEmpty {
            results = results.filter {
                $0.merchantName.lowercased().contains(term) || $0.note.lowercased().contains(term)
            }
        }
        return UncategorizedMatch(
            ids: results.map(\.id),
            count: results.count,
            totalAmount: results.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount },
            examples: results.prefix(3).map { $0.merchantName.isEmpty ? $0.note : $0.merchantName }
        )
    }

    /// All category names, for validating a proposed category
    func categoryNames() -> [String] {
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
    }

    /// APPLY: assign a category to transactions by id. Called only from the
    /// user-confirmed action path, never directly by a tool.
    func applyCategory(toTransactionIDs ids: [UUID], categoryName: String) -> String {
        let catDescriptor = FetchDescriptor<Category>()
        guard let category = ((try? modelContext.fetch(catDescriptor)) ?? [])
            .first(where: { $0.name.lowercased() == categoryName.lowercased() }) else {
            return "Category \"\(categoryName)\" no longer exists."
        }
        let txDescriptor = FetchDescriptor<Transaction>()
        let all = (try? modelContext.fetch(txDescriptor)) ?? []
        let idSet = Set(ids)
        var updated = 0
        for tx in all where idSet.contains(tx.id) {
            tx.category = category
            updated += 1
        }
        do {
            try modelContext.save()
            return "Assigned \(updated) transaction\(updated == 1 ? "" : "s") to \(category.name)."
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }

    /// APPLY: create a spending event. Called only from the user-confirmed
    /// action path, never directly by a tool.
    func applyCreateEvent(name: String, startISO: String, endISO: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let start = formatter.date(from: startISO), let end = formatter.date(from: endISO) else {
            return "Invalid dates."
        }
        let event = SpendingEvent(name: name, startDate: start, endDate: end)
        modelContext.insert(event)
        do {
            try modelContext.save()
            return "Created event \"\(name)\" (\(event.dateRangeDisplay))."
        } catch {
            return "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - Weekly Digest Facts (Tier 3 proactive layer)

    struct WeeklyDigestFacts {
        let weekSpent: Double
        let weekIncome: Double
        let priorWeekSpent: Double
        let topCategoryName: String?
        let topCategoryAmount: Double
        let biggestExpenseMerchant: String?
        let biggestExpenseAmount: Double
        let atRiskBudgets: [BudgetStatus]
        let daysToNextDeadline: Int?
        let activeEventName: String?
        let activeEventTotal: Double
        let weekTransactionCount: Int
    }

    /// Everything the weekly digest needs, computed fresh from live data
    func getWeeklyDigestFacts() -> WeeklyDigestFacts {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let priorWeekStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= priorWeekStart && $0.date <= now }
        )
        let transactions = ((try? modelContext.fetch(descriptor)) ?? []).filter { !$0.isTransfer }

        let week = transactions.filter { $0.date >= weekStart }
        let priorWeek = transactions.filter { $0.date < weekStart }

        let weekExpenses = week.filter { !$0.isIncome }
        let weekSpent = weekExpenses.reduce(0) { $0 + $1.amount }
        let weekIncome = week.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let priorWeekSpent = priorWeek.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

        let byCategory = Dictionary(grouping: weekExpenses) { $0.category?.name ?? "Uncategorized" }
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let topCategory = byCategory.max { $0.value < $1.value }

        let biggest = weekExpenses.max { $0.amount < $1.amount }

        let atRisk = getBudgetStatus().filter { $0.percentUsed >= 90 }

        var daysToDeadline: Int?
        if let deadline = TaxSettings.nextQuarterlyDeadline(from: now) {
            let days = calendar.dateComponents([.day], from: now, to: deadline).day ?? 0
            if days <= 30 { daysToDeadline = days }
        }

        let eventDescriptor = FetchDescriptor<SpendingEvent>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let activeEvent = ((try? modelContext.fetch(eventDescriptor)) ?? []).first { $0.isActive }

        return WeeklyDigestFacts(
            weekSpent: weekSpent,
            weekIncome: weekIncome,
            priorWeekSpent: priorWeekSpent,
            topCategoryName: topCategory?.key,
            topCategoryAmount: topCategory?.value ?? 0,
            biggestExpenseMerchant: biggest.map { $0.merchantName.isEmpty ? $0.note : $0.merchantName },
            biggestExpenseAmount: biggest?.amount ?? 0,
            atRiskBudgets: atRisk,
            daysToNextDeadline: daysToDeadline,
            activeEventName: activeEvent?.name,
            activeEventTotal: activeEvent?.totalSpent ?? 0,
            weekTransactionCount: week.count
        )
    }
}
