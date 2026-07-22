//  AssistantTools.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Real tool calling for My Assistant
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Wraps AssistantDataProvider's query surface as FoundationModels tools so
//  the on-device model fetches exactly the data each question needs — any
//  merchant, any date range, always current — instead of reasoning over a
//  single static snapshot.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
struct SpendingByCategoryTool: Tool {
    let name = "getSpendingByCategory"
    let description = "Get the user's income or expenses broken down by category for a year"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit year, e.g. 2026")
        var year: Int
        @Guide(description: "true for income by category, false for expenses by category")
        var income: Bool
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run {
            dataProvider.toolCategoryBreakdown(year: arguments.year, income: arguments.income)
        }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct SearchTransactionsTool: Tool {
    let name = "searchTransactions"
    let description = "Search the user's transactions in a date range, optionally filtered by merchant, note, or category text. Returns matches plus their expense total."
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Start date in YYYY-MM-DD format")
        var startDate: String
        @Guide(description: "End date in YYYY-MM-DD format (inclusive)")
        var endDate: String
        @Guide(description: "Text to match against merchant, note, or category. Empty string returns all transactions in range.")
        var searchTerm: String
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run {
            dataProvider.toolSearchTransactions(
                startISO: arguments.startDate,
                endISO: arguments.endDate,
                searchTerm: arguments.searchTerm
            )
        }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct TopMerchantsTool: Tool {
    let name = "getTopMerchants"
    let description = "Get the merchants the user spent the most at during a year, with totals and transaction counts"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit year, e.g. 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolTopMerchants(year: arguments.year) }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct TaxSnapshotTool: Tool {
    let name = "getTaxSnapshot"
    let description = "Get the user's tax position for a year: income, business/personal expenses, estimated self-employment tax, deductions, and mileage deduction"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit tax year, e.g. 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolTaxSnapshot(year: arguments.year) }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct MileageSummaryTool: Tool {
    let name = "getMileageSummary"
    let description = "Get the user's business mileage for a year: total miles, trips, and the IRS deduction amount"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit year, e.g. 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolMileage(year: arguments.year) }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct AccountBalancesTool: Tool {
    let name = "getAccountBalances"
    let description = "Get the user's current account balances across all accounts"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolAccounts() }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct MonthlyTrendTool: Tool {
    let name = "getMonthlyTrend"
    let description = "Get month-by-month income and expense totals for a year, for trends and month comparisons"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit year, e.g. 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolMonthlyTrend(year: arguments.year) }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct BudgetStatusTool: Tool {
    let name = "getBudgetStatus"
    let description = "Get the user's current budgets with spent amounts and remaining room"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolBudgets() }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct InvoicesAndDebtsTool: Tool {
    let name = "getInvoicesAndDebts"
    let description = "Get the user's unpaid invoices and debt accounts (credit cards, loans)"
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolInvoicesAndDebts() }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct EventsTool: Tool {
    let name = "getSpendingEvents"
    let description = "Get the user's spending events (trips, holidays, occasions) with dates, total cost, and per-category breakdown. Use when asked about a trip or what an occasion cost."
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.toolEvents() }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
struct FinancialOverviewTool: Tool {
    let name = "getFinancialOverview"
    let description = "Get a broad overview of the user's finances for a year: income, expenses, tax estimate, top categories, and balances. Use for general questions before drilling into specific tools."
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "Four-digit year, e.g. 2026")
        var year: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let result = await MainActor.run { dataProvider.getFinancialContext(year: arguments.year) }
        return result
    }
}

@available(iOS 26.0, macOS 26.0, *)
func makeAssistantTools(dataProvider: AssistantDataProvider) -> [any Tool] {
    [
        FinancialOverviewTool(dataProvider: dataProvider),
        SpendingByCategoryTool(dataProvider: dataProvider),
        SearchTransactionsTool(dataProvider: dataProvider),
        TopMerchantsTool(dataProvider: dataProvider),
        TaxSnapshotTool(dataProvider: dataProvider),
        MileageSummaryTool(dataProvider: dataProvider),
        AccountBalancesTool(dataProvider: dataProvider),
        MonthlyTrendTool(dataProvider: dataProvider),
        BudgetStatusTool(dataProvider: dataProvider),
        InvoicesAndDebtsTool(dataProvider: dataProvider),
        EventsTool(dataProvider: dataProvider)
    ]
}
#endif
