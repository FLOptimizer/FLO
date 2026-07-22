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

// MARK: - Action Tools (Tier 2)

/// Navigates the app immediately — harmless and reversible, so no
/// confirmation is required.
@available(iOS 26.0, macOS 26.0, *)
struct ShowInAppTool: Tool {
    let name = "showInApp"
    let description = "Navigate the app to a section for the user. Valid sections: dashboard, transactions, accounts, budgets, invoices, mileage, tax, reports, receipts, clients, debtAccelerator. Use when the user says things like 'show me' or 'take me to'."
    let dataProvider: AssistantDataProvider

    @Generable
    struct Arguments {
        @Guide(description: "The app section to open, e.g. transactions")
        var section: String
    }

    func call(arguments: Arguments) async throws -> String {
        let section = arguments.section
        return await MainActor.run {
            guard let tab = AppTab(pathComponent: section) else {
                return "Unknown section \"\(section)\". Valid sections: dashboard, transactions, accounts, budgets, invoices, mileage, tax, reports, receipts, clients, debtAccelerator."
            }
            NavigationService.shared.navigateTo(tab)
            return "Opened the \(tab.title) section for the user."
        }
    }
}

/// Stages a categorization — the user must confirm in the chat before
/// anything is written.
@available(iOS 26.0, macOS 26.0, *)
struct ProposeCategorizeTool: Tool {
    let name = "proposeCategorizeTransactions"
    let description = "Propose assigning a category to the user's UNCATEGORIZED transactions in a date range (optionally filtered by merchant/note text). This only stages a proposal — the user confirms it with a button in the chat. Use when asked to categorize or clean up transactions."
    let dataProvider: AssistantDataProvider
    let service: AssistantService

    @Generable
    struct Arguments {
        @Guide(description: "Start date in YYYY-MM-DD format")
        var startDate: String
        @Guide(description: "End date in YYYY-MM-DD format (inclusive)")
        var endDate: String
        @Guide(description: "Text to match against merchant or note. Empty string matches all uncategorized transactions in range.")
        var searchTerm: String
        @Guide(description: "The exact category name to assign")
        var categoryName: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            let validNames = dataProvider.categoryNames()
            guard let matchedCategory = validNames.first(where: { $0.lowercased() == arguments.categoryName.lowercased() }) else {
                return "No category named \"\(arguments.categoryName)\". The user's categories are: \(validNames.joined(separator: ", "))."
            }
            guard let match = dataProvider.findUncategorizedTransactions(
                startISO: arguments.startDate,
                endISO: arguments.endDate,
                searchTerm: arguments.searchTerm
            ) else {
                return "Dates must be in YYYY-MM-DD format."
            }
            guard match.count > 0 else {
                return "No uncategorized transactions found in that range."
            }
            let examples = match.examples.joined(separator: ", ")
            service.pendingAction = AssistantService.PendingAction(
                kind: .categorize(transactionIDs: match.ids, categoryName: matchedCategory),
                summary: "Assign \(match.count) uncategorized transaction\(match.count == 1 ? "" : "s") (e.g. \(examples)) to \(matchedCategory)"
            )
            return "Staged a proposal to assign \(match.count) uncategorized transactions to \(matchedCategory). Tell the user to review and tap Confirm in the chat to apply it — nothing has been changed yet."
        }
    }
}

/// Stages event creation — the user must confirm in the chat before
/// anything is written.
@available(iOS 26.0, macOS 26.0, *)
struct ProposeCreateEventTool: Tool {
    let name = "proposeCreateEvent"
    let description = "Propose creating a spending event (a named trip/occasion date range like 'Baseball trip, Jul 4-12'). This only stages a proposal — the user confirms it with a button in the chat."
    let dataProvider: AssistantDataProvider
    let service: AssistantService

    @Generable
    struct Arguments {
        @Guide(description: "Event name, e.g. Baseball trip")
        var name: String
        @Guide(description: "Start date in YYYY-MM-DD format")
        var startDate: String
        @Guide(description: "End date in YYYY-MM-DD format (inclusive)")
        var endDate: String
    }

    func call(arguments: Arguments) async throws -> String {
        await MainActor.run {
            service.pendingAction = AssistantService.PendingAction(
                kind: .createEvent(name: arguments.name, startISO: arguments.startDate, endISO: arguments.endDate),
                summary: "Create event \"\(arguments.name)\" (\(arguments.startDate) to \(arguments.endDate))"
            )
            return "Staged a proposal to create the event \"\(arguments.name)\". Tell the user to tap Confirm in the chat to create it — nothing has been created yet."
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
func makeAssistantTools(dataProvider: AssistantDataProvider, service: AssistantService) -> [any Tool] {
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
        EventsTool(dataProvider: dataProvider),
        ShowInAppTool(dataProvider: dataProvider),
        ProposeCategorizeTool(dataProvider: dataProvider, service: service),
        ProposeCreateEventTool(dataProvider: dataProvider, service: service)
    ]
}
#endif
