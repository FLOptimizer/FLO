//  AssistantService.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — My Assistant service with scored keyword matching + Zone 3 context updates.
//  Manages on-device language model sessions with financial tool calling.
//  Template fallback uses multi-keyword scoring for better query matching.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftData
import UserNotifications

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Template Pattern

/// A scored template pattern for matching user queries.
private struct TemplatePattern {
    let dataType: AssistantDataType
    let keywords: [(word: String, weight: Double)]
    let responseBuilder: (AssistantDataProvider, NumberFormatter) -> String
    let contextUpdater: (AssistantContext, AssistantDataProvider) -> Void

    /// Score this pattern against a query. Higher = better match.
    func score(for query: String) -> Double {
        let lowered = query.lowercased()
        var total: Double = 0
        for (word, weight) in keywords {
            if lowered.contains(word) {
                total += weight
            }
        }
        return total
    }
}

/// Manages the on-device AI assistant session.
@MainActor
@Observable
final class AssistantService {

    // MARK: - State

    var isGenerating = false

    /// Whether the on-device language model can actually run here (runtime
    /// check — device eligibility, Apple Intelligence enabled, model ready).
    /// When false the template fallback still answers common questions.
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }

    private var dataProvider: AssistantDataProvider?
    var context: AssistantContext?

    /// Persistent multi-turn session (type-erased; concretely a
    /// LanguageModelSession on OS 26+). The framework keeps the transcript,
    /// so each turn only sends the new message.
    private var sessionStorage: Any?

    /// Reset the model conversation (call when the user starts a new chat)
    func startNewConversation() {
        sessionStorage = nil
        pendingAction = nil
    }

    // MARK: - Guardrailed Actions

    /// A write the model has PROPOSED. Nothing mutates until the user taps
    /// Confirm in the chat UI — tools can only stage, never apply.
    struct PendingAction: Identifiable {
        enum Kind {
            case categorize(transactionIDs: [UUID], categoryName: String)
            case createEvent(name: String, startISO: String, endISO: String)
        }
        let id = UUID()
        let kind: Kind
        /// Human-readable description shown on the confirmation card
        let summary: String
    }

    /// The action awaiting user confirmation, if any (rendered by the view)
    var pendingAction: PendingAction?

    /// Apply the pending action. Only the view's Confirm button calls this.
    func applyPendingAction() -> String {
        guard let action = pendingAction, let dataProvider else {
            return "Nothing to confirm."
        }
        pendingAction = nil
        switch action.kind {
        case .categorize(let ids, let categoryName):
            return dataProvider.applyCategory(toTransactionIDs: ids, categoryName: categoryName)
        case .createEvent(let name, let startISO, let endISO):
            return dataProvider.applyCreateEvent(name: name, startISO: startISO, endISO: endISO)
        }
    }

    func cancelPendingAction() {
        pendingAction = nil
    }

    // MARK: - Weekly Digest (Tier 3 proactive layer)

    /// A fresh look at the user's week, computed from live data whenever the
    /// assistant is opened. Returns nil when there's nothing meaningful to say.
    func weeklyDigest() -> String? {
        guard let dataProvider else { return nil }
        let facts = dataProvider.getWeeklyDigestFacts()
        guard facts.weekTransactionCount > 0 else { return nil }

        let fmt = NumberFormatter.appCurrency
        func money(_ value: Double) -> String {
            fmt.string(from: NSNumber(value: value)) ?? "$0"
        }

        var lines: [String] = []
        lines.append("💸 Spent \(money(facts.weekSpent)) across \(facts.weekTransactionCount) transactions this week")

        if facts.priorWeekSpent > 0 {
            let change = ((facts.weekSpent - facts.priorWeekSpent) / facts.priorWeekSpent) * 100
            if abs(change) >= 10 {
                let direction = change > 0 ? "up" : "down"
                lines.append("\(change > 0 ? "📈" : "📉") That's \(direction) \(abs(Int(change)))% from last week")
            }
        }

        if let category = facts.topCategoryName, facts.topCategoryAmount > 0 {
            lines.append("🏷️ Top category: \(category) (\(money(facts.topCategoryAmount)))")
        }

        if let merchant = facts.biggestExpenseMerchant, facts.biggestExpenseAmount > 0 {
            lines.append("🧾 Biggest expense: \(merchant) (\(money(facts.biggestExpenseAmount)))")
        }

        for budget in facts.atRiskBudgets.prefix(2) {
            let state = budget.percentUsed >= 100 ? "over budget" : "at \(Int(budget.percentUsed))%"
            lines.append("⚠️ \(budget.categoryName) budget is \(state)")
        }

        if let event = facts.activeEventName {
            lines.append("✈️ \(event) so far: \(money(facts.activeEventTotal))")
        }

        if let days = facts.daysToNextDeadline {
            lines.append("🏛️ Estimated taxes due in \(days) day\(days == 1 ? "" : "s")")
        }

        return lines.joined(separator: "\n")
    }

    /// Schedules the recurring weekly digest notification (Monday 9 AM).
    /// The notification is deliberately generic — the digest content is
    /// computed fresh when the user opens the assistant, never stale.
    /// No-ops without notification permission; never prompts. Idempotent.
    static func scheduleWeeklyDigestNotification() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let identifier = "assistant_weekly_digest"
        let pending = await center.pendingNotificationRequests()
        guard !pending.contains(where: { $0.identifier == identifier }) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your week in review is ready"
        content.body = "See what you spent, where it went, and what's coming up — ask My Assistant anything about it."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_DIGEST"

        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func activeSession(dataProvider: AssistantDataProvider) -> LanguageModelSession {
        if let existing = sessionStorage as? LanguageModelSession {
            return existing
        }
        let session = LanguageModelSession(
            tools: makeAssistantTools(dataProvider: dataProvider, service: self),
            instructions: systemPrompt
        )
        sessionStorage = session
        return session
    }
    #endif

    // MARK: - Setup

    func configure(modelContext: ModelContext, context: AssistantContext) {
        self.dataProvider = AssistantDataProvider(modelContext: modelContext)
        self.context = context
    }

    // MARK: - System Prompt

    private var systemPrompt: String {
        """
        You are a helpful financial assistant for the FLO app (Finance Ledger Optimizer). \
        You help users understand their financial data, spending patterns, tax obligations, \
        and budget status.

        IMPORTANT RULES:
        - You are NOT a tax professional, CPA, or financial advisor.
        - Always recommend consulting a qualified tax professional for tax decisions.
        - Present data factually — do not make investment or tax strategy recommendations.
        - Format currency amounts clearly with dollar signs.
        - Be concise and direct in your answers.
        - When discussing tax data, clarify this is based on the data in FLO, not official tax calculations.
        - The current tax year is \(Calendar.current.component(.year, from: Date())).
        - The IRS business mileage rate is $0.70/mile for 2025 and $0.725/mile for 2026.
        - Self-employment tax rate is 15.3% on 92.35% of net self-employment income.

        You have TOOLS that query the user's live financial data in FLO: overview, \
        category breakdowns, transaction search by date range and text, top merchants, \
        tax snapshot, mileage, account balances, monthly trends, budgets, invoices and \
        debts, and spending events (trips/occasions). ALWAYS call the relevant tool to \
        get real numbers before answering a question about the user's finances — never \
        estimate or invent figures. You also have ACTION tools: showInApp navigates the \
        app for the user, and the propose* tools stage changes (categorizing \
        transactions, creating events) that the user approves with a Confirm button in \
        the chat — after staging one, tell the user to review and confirm it. Today's date is \(Date().formatted(date: .complete, time: .omitted)).
        """
    }

    // MARK: - Template Patterns (Scored Multi-Keyword)

    private var patterns: [TemplatePattern] {
        guard let dp = dataProvider else { return [] }
        _ = dp // suppress warning

        return [
            // Income by category/source breakdown (must be before general income)
            TemplatePattern(
                dataType: .income,
                keywords: [("income", 2), ("category", 3), ("source", 3), ("break", 2), ("breakdown", 3), ("by", 1)],
                responseBuilder: { dp, fmt in
                    let categories = dp.getIncomeByCategory(year: Calendar.current.component(.year, from: Date()))
                    let total = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date())).totalIncome
                    if categories.isEmpty { return "No categorized income found for 2025." }
                    var r = "Your 2025 income by category (**\(fmt.string(from: NSNumber(value: total)) ?? "$0")** total):\n\n"
                    for cat in categories {
                        r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\n"
                    }
                    r += "\n*\(categories.count) income source(s) tracked in FLO.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let categories = dp.getIncomeByCategory(year: Calendar.current.component(.year, from: Date()))
                    ctx.showCategories(items: categories, isIncome: true)
                }
            ),

            // General income summary
            TemplatePattern(
                dataType: .income,
                keywords: [("income", 3), ("earn", 2), ("revenue", 2), ("summarize", 1), ("total", 1)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let categories = dp.getIncomeByCategory(year: Calendar.current.component(.year, from: Date()))
                    var r = "Your total income for 2025 is **\(fmt.string(from: NSNumber(value: tax.totalIncome)) ?? "$0")**.\n\n"
                    if !categories.isEmpty {
                        r += "Broken down by source:\n\n"
                        for cat in categories {
                            r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\n"
                        }
                    }
                    return r
                },
                contextUpdater: { ctx, dp in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let categories = dp.getIncomeByCategory(year: Calendar.current.component(.year, from: Date()))
                    ctx.showIncome(total: tax.totalIncome, byCategory: categories)
                }
            ),

            // Business expenses
            TemplatePattern(
                dataType: .expenses,
                keywords: [("business", 3), ("expense", 2), ("spending", 2), ("cost", 1)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())).filter { $0.isBusiness }
                    var r = "Your total business expenses for 2025 are **\(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")**.\n\n"
                    if !categories.isEmpty {
                        r += "By category:\n\n"
                        for cat in categories.prefix(10) {
                            let flag = cat.isTaxDeductible ? " ✓ Deductible" : ""
                            r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\(flag)\n"
                        }
                    }
                    r += "\n*Make sure all business expenses are properly categorized for Schedule C.*\n*Consult a tax professional for deduction eligibility.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())).filter { $0.isBusiness }
                    ctx.showExpenses(total: tax.totalBusinessExpenses, business: tax.totalBusinessExpenses, personal: 0, byCategory: categories)
                }
            ),

            // Self-employment tax
            TemplatePattern(
                dataType: .tax,
                keywords: [("self-employment", 4), ("se tax", 4), ("self employment", 4), ("tax", 2), ("owe", 2), ("liability", 2)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    return "Based on your 2025 data:\n\n" +
                    "- **Total Income:** \(fmt.string(from: NSNumber(value: tax.totalIncome)) ?? "$0")\n" +
                    "- **Business Expenses:** \(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")\n" +
                    "- **Net SE Income:** \(fmt.string(from: NSNumber(value: tax.totalIncome - tax.totalBusinessExpenses)) ?? "$0")\n" +
                    "- **Estimated SE Tax:** \(fmt.string(from: NSNumber(value: tax.estimatedSETax)) ?? "$0")\n\n" +
                    "SE tax = 15.3% on 92.35% of net self-employment income.\n\n" +
                    "*This is an estimate. Consult a CPA for your actual tax liability.*"
                },
                contextUpdater: { ctx, dp in ctx.showTax(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // Deductions
            TemplatePattern(
                dataType: .tax,
                keywords: [("deduction", 4), ("deductible", 3), ("write off", 3), ("write-off", 3), ("eligible", 2)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let mileage = dp.getMileageSummary(year: Calendar.current.component(.year, from: Date()))
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())).filter { $0.isTaxDeductible }
                    var r = "Your estimated 2025 deductions:\n\n" +
                    "- **Total Deductions:** \(fmt.string(from: NSNumber(value: tax.totalDeductions)) ?? "$0")\n" +
                    "- **Mileage Deduction:** \(fmt.string(from: NSNumber(value: tax.mileageDeduction)) ?? "$0")\n\n"
                    if !categories.isEmpty {
                        r += "Deductible categories:\n\n"
                        for cat in categories.prefix(10) {
                            r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\n"
                        }
                    }
                    r += "\n*Verify all deductions with a tax professional.*"
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showTax(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // Mileage
            TemplatePattern(
                dataType: .mileage,
                keywords: [("mileage", 4), ("mile", 3), ("trip", 2), ("drive", 2), ("car", 2), ("vehicle", 2)],
                responseBuilder: { dp, fmt in
                    let m = dp.getMileageSummary(year: Calendar.current.component(.year, from: Date()))
                    return "Your 2025 mileage summary:\n\n" +
                    "- **Total Miles:** \(String(format: "%.1f", m.totalMiles))\n" +
                    "- **Total Trips:** \(m.totalTrips)\n" +
                    "- **IRS Rate:** $\(String(format: "%.3f", m.irsRate))/mile\n" +
                    "- **Deduction:** \(fmt.string(from: NSNumber(value: m.deductionAmount)) ?? "$0")\n\n" +
                    "This deduction goes on Schedule C, Line 9 (Car and truck expenses)."
                },
                contextUpdater: { ctx, dp in ctx.showMileage(summary: dp.getMileageSummary(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // Schedule C
            TemplatePattern(
                dataType: .schedule_c,
                keywords: [("schedule c", 5), ("schedule-c", 5), ("profit", 2), ("loss", 2), ("net profit", 3)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let m = dp.getMileageSummary(year: Calendar.current.component(.year, from: Date()))
                    return "Schedule C Overview (2025):\n\n" +
                    "- **Line 1 (Gross Income):** \(fmt.string(from: NSNumber(value: tax.totalIncome)) ?? "$0")\n" +
                    "- **Line 9 (Car/Truck Expenses):** \(fmt.string(from: NSNumber(value: m.deductionAmount)) ?? "$0")\n" +
                    "- **Total Expenses:** \(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")\n" +
                    "- **Net Profit/Loss:** \(fmt.string(from: NSNumber(value: tax.totalIncome - tax.totalBusinessExpenses)) ?? "$0")\n\n" +
                    "For detailed line items, use FLO's CPA Report in Reports.\n\n" +
                    "*These are estimates. Verify with a CPA.*"
                },
                contextUpdater: { ctx, dp in
                    ctx.showScheduleC(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date())), mileage: dp.getMileageSummary(year: Calendar.current.component(.year, from: Date())))
                }
            ),

            // Quarterly payments
            TemplatePattern(
                dataType: .tax,
                keywords: [("quarterly", 4), ("estimated payment", 4), ("estimated tax", 3), ("payment", 2)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let q = tax.estimatedSETax / 4
                    return "Based on your 2025 SE tax estimate, each quarterly payment would be approximately **\(fmt.string(from: NSNumber(value: q)) ?? "$0")**.\n\n" +
                    "2025 quarterly due dates:\n" +
                    "- Q1: April 15, 2025\n- Q2: June 16, 2025\n- Q3: September 15, 2025\n- Q4: January 15, 2026\n\n" +
                    "*Consult a tax professional for exact amounts.*"
                },
                contextUpdater: { ctx, dp in ctx.showTax(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // Expense category breakdown
            TemplatePattern(
                dataType: .categories,
                keywords: [("category", 3), ("categories", 3), ("spending", 2), ("breakdown", 3), ("break down", 3), ("break it down", 3), ("expense", 1)],
                responseBuilder: { dp, fmt in
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date()))
                    if categories.isEmpty { return "No categorized expenses found for 2025." }
                    var r = "Your 2025 expenses by category:\n\n"
                    for cat in categories.prefix(15) {
                        let flag = cat.isTaxDeductible ? " ✓ Deductible" : ""
                        let biz = cat.isBusiness ? " (Business)" : ""
                        r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\(biz)\(flag)\n"
                    }
                    if categories.count > 15 { r += "\n*...and \(categories.count - 15) more*" }
                    return r
                },
                contextUpdater: { ctx, dp in
                    ctx.showCategories(items: dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())), isIncome: false)
                }
            ),

            // Category-specific spending ("how much did I spend on groceries?")
            TemplatePattern(
                dataType: .categories,
                keywords: [("spend on", 4), ("spent on", 4), ("spending on", 4), ("how much on", 3), ("how much for", 3), ("cost of", 3), ("cost for", 3)],
                responseBuilder: { dp, fmt in
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date()))
                    if categories.isEmpty { return "No categorized expenses found for 2025." }
                    var r = "Here's your 2025 spending by category — find your specific one below:\n\n"
                    for cat in categories.prefix(20) {
                        let biz = cat.isBusiness ? " (Business)" : ""
                        let ded = cat.isTaxDeductible ? " ✓" : ""
                        r += "- **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0")\(biz)\(ded)\n"
                    }
                    if categories.count > 20 { r += "\n*...and \(categories.count - 20) more categories*" }
                    r += "\n*✓ = Tax deductible. Ask \"break down by category\" for a full sorted list.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    ctx.showCategories(items: dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())), isIncome: false)
                }
            ),

            // Account balances
            TemplatePattern(
                dataType: .accounts,
                keywords: [("account", 3), ("balance", 3), ("bank", 2), ("how much", 2), ("net worth", 3)],
                responseBuilder: { dp, fmt in
                    let accounts = dp.getAccountBalances()
                    if accounts.isEmpty { return "No accounts found in FLO." }
                    let total = accounts.reduce(0) { $0 + $1.balance }
                    var r = "Your account balances:\n\n"
                    for a in accounts {
                        r += "- **\(a.name)** (\(a.type)): \(fmt.string(from: NSNumber(value: a.balance)) ?? "$0")\n"
                    }
                    r += "\n**Total:** \(fmt.string(from: NSNumber(value: total)) ?? "$0")"
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showAccounts(balances: dp.getAccountBalances()) }
            ),

            // General expenses
            TemplatePattern(
                dataType: .expenses,
                keywords: [("expense", 3), ("spent", 2), ("spending", 2), ("spend", 2), ("cost", 1), ("personal", 2), ("how much", 1), ("total", 1)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let total = tax.totalBusinessExpenses + tax.totalPersonalExpenses
                    return "Your 2025 expense summary:\n\n" +
                    "- **Total Expenses:** \(fmt.string(from: NSNumber(value: total)) ?? "$0")\n" +
                    "- **Business:** \(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")\n" +
                    "- **Personal:** \(fmt.string(from: NSNumber(value: tax.totalPersonalExpenses)) ?? "$0")\n\n" +
                    "Ask \"break down by category\" for detailed spending by category."
                },
                contextUpdater: { ctx, dp in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let cats = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date()))
                    ctx.showExpenses(total: tax.totalBusinessExpenses + tax.totalPersonalExpenses, business: tax.totalBusinessExpenses, personal: tax.totalPersonalExpenses, byCategory: cats)
                }
            ),

            // MARK: — Batch 1: Monthly / Time Comparisons

            TemplatePattern(
                dataType: .monthly,
                keywords: [("month", 3), ("monthly", 3), ("trend", 3), ("compare", 2), ("average", 2), ("last month", 4), ("this month", 3), ("over time", 3)],
                responseBuilder: { dp, fmt in
                    let summaries = dp.getMonthlySummaries(year: Calendar.current.component(.year, from: Date()))
                    if summaries.isEmpty { return "No monthly data available for 2025." }
                    var r = "Your 2025 monthly breakdown:\n\n"
                    for s in summaries {
                        let flow = s.netCashFlow >= 0 ? "+" : ""
                        r += "**\(s.month):** Income \(fmt.string(from: NSNumber(value: s.income)) ?? "$0") | Expenses \(fmt.string(from: NSNumber(value: s.expenses)) ?? "$0") | Net \(flow)\(fmt.string(from: NSNumber(value: s.netCashFlow)) ?? "$0")\n"
                    }
                    let avgInc = summaries.reduce(0) { $0 + $1.income } / Double(summaries.count)
                    let avgExp = summaries.reduce(0) { $0 + $1.expenses } / Double(summaries.count)
                    r += "\n**Averages:** Income \(fmt.string(from: NSNumber(value: avgInc)) ?? "$0")/mo | Expenses \(fmt.string(from: NSNumber(value: avgExp)) ?? "$0")/mo"
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showMonthly(summaries: dp.getMonthlySummaries(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // MARK: — Batch 2: Transaction Queries

            TemplatePattern(
                dataType: .transactions,
                keywords: [("biggest", 4), ("largest", 4), ("top", 3), ("most expensive", 4), ("highest", 3)],
                responseBuilder: { dp, fmt in
                    let top = dp.getTopExpenses(year: Calendar.current.component(.year, from: Date()), limit: 10)
                    if top.isEmpty { return "No expenses found for 2025." }
                    var r = "Your 10 biggest expenses in 2025:\n\n"
                    for (i, t) in top.enumerated() {
                        r += "\(i+1). **\(t.merchant)** — \(fmt.string(from: NSNumber(value: t.amount)) ?? "$0") (\(t.date), \(t.category))\n"
                    }
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showTransactions(items: dp.getTopExpenses(year: Calendar.current.component(.year, from: Date()), limit: 10), title: "Biggest Expenses (2025)") }
            ),

            TemplatePattern(
                dataType: .transactions,
                keywords: [("recent", 4), ("latest", 3), ("last few", 3), ("show me", 1), ("transaction", 2)],
                responseBuilder: { dp, fmt in
                    let recent = dp.getRecentTransactions(limit: 10)
                    if recent.isEmpty { return "No recent transactions found." }
                    var r = "Your 10 most recent transactions:\n\n"
                    for t in recent {
                        let prefix = t.isIncome ? "+" : "-"
                        r += "- **\(t.merchant)** \(prefix)\(fmt.string(from: NSNumber(value: t.amount)) ?? "$0") (\(t.date))\n"
                    }
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showTransactions(items: dp.getRecentTransactions(limit: 10), title: "Recent Transactions") }
            ),

            // Transfers between accounts
            TemplatePattern(
                dataType: .transactions,
                keywords: [("transfer", 4), ("transfers", 4), ("move money", 4), ("moved money", 4), ("between accounts", 5), ("internal transfer", 5)],
                responseBuilder: { dp, fmt in
                    let transfers = dp.getTransfers(limit: 15)
                    if transfers.isEmpty { return "No transfers found in FLO.\n\n*Transfers are account-to-account movements (e.g., checking → savings) and are excluded from income & expense calculations.*" }
                    var r = "Your recent account transfers (\(transfers.count) shown):\n\n"
                    for t in transfers {
                        r += "- **\(t.merchant)** — \(fmt.string(from: NSNumber(value: t.amount)) ?? "$0") (\(t.date))\n"
                    }
                    r += "\n*Transfers between your own accounts are excluded from income & expense calculations to avoid double-counting.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    ctx.showTransactions(items: dp.getTransfers(limit: 15), title: "Recent Transfers")
                }
            ),

            TemplatePattern(
                dataType: .transactions,
                keywords: [("merchant", 3), ("store", 2), ("where", 2), ("shop", 2), ("amazon", 3), ("walmart", 3), ("vendor", 3)],
                responseBuilder: { dp, fmt in
                    let merchants = dp.getMerchantSpending(year: Calendar.current.component(.year, from: Date()))
                    if merchants.isEmpty { return "No merchant spending data for 2025." }
                    var r = "Your top merchants by spending (2025):\n\n"
                    for (i, m) in merchants.prefix(15).enumerated() {
                        r += "\(i+1). **\(m.merchant)** — \(fmt.string(from: NSNumber(value: m.total)) ?? "$0") (\(m.count) transactions)\n"
                    }
                    return r
                },
                contextUpdater: { ctx, dp in
                    let merchants = dp.getMerchantSpending(year: Calendar.current.component(.year, from: Date()))
                    ctx.dataType = .transactions
                    ctx.heroAmount = merchants.reduce(0) { $0 + $1.total }
                    ctx.heroLabel = "Spending by Merchant (2025)"
                    ctx.dataItems = merchants.prefix(15).map { AssistantDataItem(label: $0.merchant, amount: $0.total, subtitle: "\($0.count) transactions") }
                    ctx.secondaryMetrics = [("Merchants", "\(merchants.count)")]
                }
            ),

            // MARK: — Batch 3: Budget Questions

            TemplatePattern(
                dataType: .budget,
                keywords: [("budget", 4), ("over budget", 5), ("under budget", 5), ("remaining", 2), ("left", 2), ("limit", 2)],
                responseBuilder: { dp, fmt in
                    let statuses = dp.getBudgetStatus()
                    if statuses.isEmpty { return "No budgets set for the current month." }
                    let overBudget = statuses.filter { $0.percentUsed > 100 }
                    var r = "Budget status for this month:\n\n"
                    for s in statuses {
                        let status = s.percentUsed > 100 ? "⚠️ OVER" : "✅"
                        r += "\(status) **\(s.categoryName):** \(fmt.string(from: NSNumber(value: s.spent)) ?? "$0") of \(fmt.string(from: NSNumber(value: s.budgeted)) ?? "$0") (\(String(format: "%.0f%%", s.percentUsed)))\n"
                    }
                    if overBudget.isEmpty {
                        r += "\nAll budgets are on track!"
                    } else {
                        r += "\n**\(overBudget.count) budget(s) over limit.**"
                    }
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showBudgets(statuses: dp.getBudgetStatus()) }
            ),

            // MARK: — Batch 4: Tax Deep Dives

            TemplatePattern(
                dataType: .tax,
                keywords: [("effective", 3), ("tax rate", 3), ("rate", 2), ("set aside", 4), ("save for tax", 4)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let effectiveRate = tax.totalIncome > 0 ? (tax.estimatedSETax / tax.totalIncome) * 100 : 0
                    let monthlySetAside = tax.estimatedSETax / 12
                    return "Tax rate analysis (2025):\n\n" +
                    "- **SE Tax Rate:** 15.3% (on 92.35% of net income)\n" +
                    "- **Your Effective Rate:** \(String(format: "%.1f%%", effectiveRate))\n" +
                    "- **Monthly Set-Aside:** \(fmt.string(from: NSNumber(value: monthlySetAside)) ?? "$0")\n" +
                    "- **Total Tax Estimate:** \(fmt.string(from: NSNumber(value: tax.estimatedSETax)) ?? "$0")\n\n" +
                    "*This only includes SE tax. Federal income tax, state tax, and credits are not included. Consult a CPA.*"
                },
                contextUpdater: { ctx, dp in ctx.showTax(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))) }
            ),

            // MARK: — Batch 5: Cash Flow & Savings

            TemplatePattern(
                dataType: .cashflow,
                keywords: [("cash flow", 4), ("saving", 3), ("savings rate", 4), ("save enough", 4), ("net flow", 3), ("keeping", 2)],
                responseBuilder: { dp, fmt in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let savingsRate = avg.income > 0 ? (avg.savings / avg.income) * 100 : 0
                    return "Cash flow analysis (3-month average):\n\n" +
                    "- **Monthly Income:** \(fmt.string(from: NSNumber(value: avg.income)) ?? "$0")\n" +
                    "- **Monthly Expenses:** \(fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0")\n" +
                    "- **Monthly Savings:** \(fmt.string(from: NSNumber(value: avg.savings)) ?? "$0")\n" +
                    "- **Savings Rate:** \(String(format: "%.1f%%", savingsRate))\n" +
                    "- **Annual Pace:** \(fmt.string(from: NSNumber(value: avg.savings * 12)) ?? "$0")/year\n\n" +
                    (savingsRate >= 20 ? "Your savings rate is strong (20%+ recommended)." :
                     savingsRate >= 10 ? "Your savings rate is decent but could improve (20%+ recommended)." :
                     "Your savings rate is below recommended (target 20%+). Review expenses for reduction opportunities.")
                },
                contextUpdater: { ctx, dp in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let savingsRate = avg.income > 0 ? (avg.savings / avg.income) * 100 : 0
                    ctx.showCashFlow(avgIncome: avg.income, avgExpenses: avg.expenses, savingsRate: savingsRate)
                }
            ),

            // MARK: — Batch 6: Invoicing

            TemplatePattern(
                dataType: .invoices,
                keywords: [("invoice", 4), ("unpaid", 4), ("overdue", 4), ("owe me", 3), ("outstanding", 3), ("client", 2), ("receivable", 3)],
                responseBuilder: { dp, fmt in
                    let invoices = dp.getUnpaidInvoices()
                    if invoices.isEmpty { return "No unpaid invoices found. You're all caught up!" }
                    let overdue = invoices.filter(\.isOverdue)
                    var r = "Unpaid invoices (\(invoices.count)):\n\n"
                    for inv in invoices {
                        let flag = inv.isOverdue ? " ⚠️ OVERDUE" : ""
                        r += "- **\(inv.clientName):** \(fmt.string(from: NSNumber(value: inv.amount)) ?? "$0") (Due: \(inv.dueDate))\(flag)\n"
                    }
                    let total = invoices.reduce(0) { $0 + $1.amount }
                    r += "\n**Total Outstanding:** \(fmt.string(from: NSNumber(value: total)) ?? "$0")"
                    if !overdue.isEmpty {
                        r += "\n**⚠️ \(overdue.count) overdue** — follow up to collect."
                    }
                    return r
                },
                contextUpdater: { ctx, dp in ctx.showInvoices(invoices: dp.getUnpaidInvoices()) }
            ),

            // MARK: — Batch 7: Debt & Affordability

            TemplatePattern(
                dataType: .debt,
                keywords: [("debt", 4), ("owe", 3), ("pay off", 4), ("payoff", 4), ("heloc", 5), ("refinance", 4), ("consolidate", 4), ("credit card", 3), ("loan", 2), ("highest interest", 4)],
                responseBuilder: { dp, fmt in
                    let debts = dp.getDebtAccounts()
                    if debts.isEmpty { return "No debt accounts found in FLO. Great news — you're debt-free based on your tracked accounts!" }
                    let avg = dp.getMonthlyAverages(months: 3)
                    let totalDebt = debts.reduce(0) { $0 + $1.balance }
                    var r = "**Debt Overview:**\n\n"
                    for (i, d) in debts.enumerated() {
                        let rate = d.interestRate.map { String(format: "%.1f%% APR", $0) } ?? "No APR set"
                        r += "\(i+1). **\(d.name)** — \(fmt.string(from: NSNumber(value: d.balance)) ?? "$0") (\(rate))\n"
                    }
                    r += "\n**Total Debt:** \(fmt.string(from: NSNumber(value: totalDebt)) ?? "$0")\n\n"
                    r += "**Recommended Payoff Strategy (Avalanche Method):**\n"
                    r += "Pay minimums on all accounts, then put extra toward the **highest APR** first.\n\n"
                    r += "Your accounts are listed highest-to-lowest APR above. Focus extra payments on **\(debts.first?.name ?? "the top account")** first.\n\n"
                    if avg.savings > 0 {
                        r += "With your average monthly surplus of \(fmt.string(from: NSNumber(value: avg.savings)) ?? "$0"), you could accelerate payoff.\n\n"
                    }
                    r += "*If considering a HELOC or refinance to consolidate debt, compare the new interest rate against your highest-APR accounts above. Only consolidate if the new rate is significantly lower.*\n\n" +
                    "*Consult a financial advisor for personalized debt strategy.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let avg = dp.getMonthlyAverages(months: 3)
                    ctx.showDebt(accounts: dp.getDebtAccounts(), monthlyAvailable: avg.savings)
                }
            ),

            TemplatePattern(
                dataType: .affordability,
                keywords: [("afford", 5), ("can i buy", 5), ("purchase", 3), ("car", 3), ("house", 3), ("mortgage", 4), ("payment", 2), ("how much can", 4)],
                responseBuilder: { dp, fmt in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let debts = dp.getDebtAccounts()
                    let totalDebt = debts.reduce(0) { $0 + $1.balance }
                    let accounts = dp.getAccountBalances()
                    let totalAssets = accounts.filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
                    let dti = avg.income > 0 ? (avg.expenses / avg.income) * 100 : 0

                    var r = "**Affordability Snapshot:**\n\n" +
                    "- **Monthly Income:** \(fmt.string(from: NSNumber(value: avg.income)) ?? "$0")\n" +
                    "- **Monthly Expenses:** \(fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0")\n" +
                    "- **Monthly Surplus:** \(fmt.string(from: NSNumber(value: avg.savings)) ?? "$0")\n" +
                    "- **Available Assets:** \(fmt.string(from: NSNumber(value: totalAssets)) ?? "$0")\n" +
                    "- **Total Debt:** \(fmt.string(from: NSNumber(value: totalDebt)) ?? "$0")\n" +
                    "- **Debt-to-Income:** \(String(format: "%.1f%%", dti))\n\n"

                    // Housing affordability rule of thumb
                    let maxHousingPayment = avg.income * 0.28
                    let maxTotalDebt = avg.income * 0.36
                    let availableForHousing = maxTotalDebt - avg.expenses + avg.savings

                    r += "**Housing Rules of Thumb:**\n" +
                    "- Max housing payment (28% rule): \(fmt.string(from: NSNumber(value: maxHousingPayment)) ?? "$0")/mo\n" +
                    "- Max total debt payments (36% rule): \(fmt.string(from: NSNumber(value: maxTotalDebt)) ?? "$0")/mo\n\n"

                    // Car affordability
                    let maxCarPayment = avg.income * 0.10
                    r += "**Vehicle Rule of Thumb:**\n" +
                    "- Max car payment (10% rule): \(fmt.string(from: NSNumber(value: maxCarPayment)) ?? "$0")/mo\n\n"

                    r += "*These are general guidelines. Lenders consider credit score, down payment, and other factors. Consult a mortgage broker or financial advisor.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let debts = dp.getDebtAccounts()
                    let accounts = dp.getAccountBalances()
                    let totalAssets = accounts.filter { $0.balance > 0 }.reduce(0) { $0 + $1.balance }
                    let totalDebt = debts.reduce(0) { $0 + $1.balance }
                    ctx.dataType = .affordability
                    ctx.heroAmount = avg.savings
                    ctx.heroLabel = "Monthly Surplus Available"
                    let fmt = NumberFormatter.appCurrency
                    ctx.dataItems = []
                    ctx.secondaryMetrics = [
                        ("Monthly Income", fmt.string(from: NSNumber(value: avg.income)) ?? "$0"),
                        ("Monthly Expenses", fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0"),
                        ("Available Assets", fmt.string(from: NSNumber(value: totalAssets)) ?? "$0"),
                        ("Total Debt", fmt.string(from: NSNumber(value: totalDebt)) ?? "$0"),
                        ("Max Housing (28%)", fmt.string(from: NSNumber(value: avg.income * 0.28)) ?? "$0"),
                        ("Max Car (10%)", fmt.string(from: NSNumber(value: avg.income * 0.10)) ?? "$0")
                    ]
                }
            ),

            // MARK: — Batch 8: Financial Health Check

            TemplatePattern(
                dataType: .health,
                keywords: [("health", 4), ("financial health", 5), ("overview", 3), ("how am i doing", 5), ("summary", 2), ("check", 2), ("status", 2), ("snapshot", 3)],
                responseBuilder: { dp, fmt in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let savingsRate = avg.income > 0 ? (avg.savings / avg.income) * 100 : 0
                    let debts = dp.getDebtAccounts()
                    let totalDebt = debts.reduce(0) { $0 + $1.balance }
                    let dti = avg.income > 0 ? (totalDebt / (avg.income * 12)) * 100 : 0
                    let budgets = dp.getBudgetStatus()
                    let overBudget = budgets.filter { $0.percentUsed > 100 }.count
                    let invoices = dp.getUnpaidInvoices()
                    let overdue = invoices.filter(\.isOverdue).count
                    let accounts = dp.getAccountBalances()
                    let netWorth = accounts.reduce(0) { $0 + $1.balance }

                    var r = "**Financial Health Check:**\n\n"
                    r += "📊 **Net Worth:** \(fmt.string(from: NSNumber(value: netWorth)) ?? "$0")\n"
                    r += "💰 **Savings Rate:** \(String(format: "%.1f%%", savingsRate)) \(savingsRate >= 20 ? "✅" : savingsRate >= 10 ? "⚠️" : "❌")\n"
                    r += "💳 **Total Debt:** \(fmt.string(from: NSNumber(value: totalDebt)) ?? "$0") \(totalDebt == 0 ? "✅" : "")\n"
                    r += "📈 **Debt-to-Annual-Income:** \(String(format: "%.1f%%", dti)) \(dti < 30 ? "✅" : dti < 50 ? "⚠️" : "❌")\n"
                    r += "📋 **Budgets:** \(budgets.count - overBudget)/\(budgets.count) on track \(overBudget == 0 ? "✅" : "⚠️")\n"
                    r += "📄 **Overdue Invoices:** \(overdue) \(overdue == 0 ? "✅" : "⚠️")\n\n"

                    // Overall grade
                    var score = 0
                    if savingsRate >= 20 { score += 2 } else if savingsRate >= 10 { score += 1 }
                    if totalDebt == 0 { score += 2 } else if dti < 30 { score += 1 }
                    if overBudget == 0 { score += 1 }
                    if overdue == 0 { score += 1 }

                    let grade = score >= 5 ? "Excellent" : score >= 3 ? "Good" : score >= 2 ? "Needs Attention" : "Needs Improvement"
                    r += "**Overall: \(grade)** (\(score)/6)\n\n"
                    r += "*This is a simplified snapshot. Consult a financial advisor for comprehensive planning.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let savingsRate = avg.income > 0 ? (avg.savings / avg.income) * 100 : 0
                    let debts = dp.getDebtAccounts()
                    let totalDebt = debts.reduce(0) { $0 + $1.balance }
                    let dti = avg.income > 0 ? (totalDebt / (avg.income * 12)) * 100 : 0
                    let budgets = dp.getBudgetStatus()
                    let overBudget = budgets.filter { $0.percentUsed > 100 }.count
                    let invoices = dp.getUnpaidInvoices()
                    let overdue = invoices.filter(\.isOverdue).count
                    let accounts = dp.getAccountBalances()
                    let netWorth = accounts.reduce(0) { $0 + $1.balance }
                    ctx.showHealthCheck(savingsRate: savingsRate, debtToIncome: dti, overBudgetCount: overBudget, totalBudgets: budgets.count, overdueInvoices: overdue, netWorth: netWorth)
                }
            ),

            // MARK: — Batch 9: Income Goals & Living Within Means

            TemplatePattern(
                dataType: .cashflow,
                keywords: [("additional income", 5), ("need to earn", 5), ("need to make", 5), ("how much more", 5), ("live comfortably", 5), ("within my means", 5), ("break even", 4), ("break-even", 4), ("cover my expenses", 4), ("financial gap", 4), ("enough income", 4), ("living within", 4), ("comfortable", 3), ("comfortably", 3)],
                responseBuilder: { dp, fmt in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let debts = dp.getDebtAccounts()
                    let monthlyDebtPayments = debts.reduce(0) { total, d in
                        // Estimate minimum payment as 2% of balance or $25, whichever is higher
                        total + max(d.balance * 0.02, min(25, d.balance))
                    }
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let monthlyTaxBurden = tax.estimatedSETax / 12

                    // Tier 1: Break-even (cover expenses only)
                    let breakEven = avg.expenses
                    // Tier 2: Comfortable (expenses + taxes + debt minimums)
                    let comfortable = avg.expenses + monthlyTaxBurden + monthlyDebtPayments
                    // Tier 3: Thriving (comfortable + 20% savings)
                    let thriving = comfortable / 0.80 // solving for: expenses = 80% of income

                    let gap = comfortable - avg.income
                    let thrivingGap = thriving - avg.income

                    var r = "**Income Analysis Based on Your Spending:**\n\n"
                    r += "Your 3-month average monthly expenses: **\(fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0")**\n"
                    r += "Your 3-month average monthly income: **\(fmt.string(from: NSNumber(value: avg.income)) ?? "$0")**\n\n"

                    r += "**Income Tiers:**\n\n"
                    r += "1️⃣ **Break-Even** (cover expenses only): \(fmt.string(from: NSNumber(value: breakEven)) ?? "$0")/mo\n"
                    r += "2️⃣ **Comfortable** (expenses + taxes + debt payments): \(fmt.string(from: NSNumber(value: comfortable)) ?? "$0")/mo\n"
                    r += "3️⃣ **Thriving** (all above + 20% savings): \(fmt.string(from: NSNumber(value: thriving)) ?? "$0")/mo\n\n"

                    if avg.income >= thriving {
                        r += "✅ **You're in the Thriving tier!** Your income covers expenses, taxes, debt, and savings.\n\n"
                    } else if avg.income >= comfortable {
                        r += "✅ **You're in the Comfortable tier.** To reach Thriving, you'd need an additional **\(fmt.string(from: NSNumber(value: thrivingGap)) ?? "$0")**/mo.\n\n"
                    } else if avg.income >= breakEven {
                        r += "⚠️ **You're above break-even but below Comfortable.** You need an additional **\(fmt.string(from: NSNumber(value: gap)) ?? "$0")**/mo to comfortably cover taxes and debt.\n\n"
                    } else {
                        r += "❌ **You're currently below break-even.** You need an additional **\(fmt.string(from: NSNumber(value: abs(gap))) ?? "$0")**/mo to cover your expenses.\n\n"
                    }

                    r += "**Monthly Breakdown:**\n"
                    r += "- Expenses: \(fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0")\n"
                    r += "- Est. Tax Set-Aside: \(fmt.string(from: NSNumber(value: monthlyTaxBurden)) ?? "$0")\n"
                    r += "- Est. Debt Payments: \(fmt.string(from: NSNumber(value: monthlyDebtPayments)) ?? "$0")\n"
                    r += "- Target Savings (20%): \(fmt.string(from: NSNumber(value: thriving * 0.20)) ?? "$0")\n\n"

                    r += "**Ways to close the gap:**\n"
                    r += "- Increase income (side work, raise, new clients)\n"
                    r += "- Reduce expenses (review top spending categories)\n"
                    r += "- Refinance debt at lower rates\n"
                    r += "- Eliminate highest-APR debt first\n\n"
                    r += "*These calculations use your actual spending data. Consult a financial advisor for personalized planning.*"
                    return r
                },
                contextUpdater: { ctx, dp in
                    let avg = dp.getMonthlyAverages(months: 3)
                    let debts = dp.getDebtAccounts()
                    let monthlyDebtPayments = debts.reduce(0) { total, d in
                        total + max(d.balance * 0.02, min(25, d.balance))
                    }
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    let monthlyTax = tax.estimatedSETax / 12
                    let comfortable = avg.expenses + monthlyTax + monthlyDebtPayments
                    let thriving = comfortable / 0.80
                    let fmt = NumberFormatter.appCurrency

                    ctx.dataType = .cashflow
                    ctx.heroAmount = comfortable - avg.income
                    ctx.heroLabel = ctx.heroAmount <= 0 ? "You're Covered!" : "Monthly Income Gap"
                    ctx.dataItems = []
                    ctx.secondaryMetrics = [
                        ("Current Income", fmt.string(from: NSNumber(value: avg.income)) ?? "$0"),
                        ("Break-Even", fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0"),
                        ("Comfortable", fmt.string(from: NSNumber(value: comfortable)) ?? "$0"),
                        ("Thriving (20% savings)", fmt.string(from: NSNumber(value: thriving)) ?? "$0"),
                        ("Monthly Tax Burden", fmt.string(from: NSNumber(value: monthlyTax)) ?? "$0"),
                        ("Monthly Debt Payments", fmt.string(from: NSNumber(value: monthlyDebtPayments)) ?? "$0")
                    ]
                }
            ),

            // Reducing expenses / where can I cut
            TemplatePattern(
                dataType: .categories,
                keywords: [("cut", 3), ("reduce", 3), ("save more", 4), ("where can i", 3), ("unnecessary", 3), ("discretionary", 3), ("trim", 3), ("lower my", 3)],
                responseBuilder: { dp, fmt in
                    let categories = dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date()))
                    let avg = dp.getMonthlyAverages(months: 3)
                    if categories.isEmpty { return "No expense data found to analyze." }
                    var r = "**Expense Reduction Opportunities:**\n\n"
                    r += "Your monthly expenses average **\(fmt.string(from: NSNumber(value: avg.expenses)) ?? "$0")**. Here are your top spending categories:\n\n"
                    for (i, cat) in categories.prefix(10).enumerated() {
                        let monthly = cat.amount / max(1, Double(dp.getMonthlySummaries(year: Calendar.current.component(.year, from: Date())).count))
                        r += "\(i+1). **\(cat.categoryName):** \(fmt.string(from: NSNumber(value: cat.amount)) ?? "$0") total (\(fmt.string(from: NSNumber(value: monthly)) ?? "$0")/mo avg)\n"
                    }
                    r += "\n**Tips:**\n"
                    r += "- Review your top 3 categories — even a 10% reduction saves \(fmt.string(from: NSNumber(value: categories.prefix(3).reduce(0) { $0 + $1.amount } * 0.10)) ?? "$0")/year\n"
                    r += "- Check for subscriptions or recurring charges you've forgotten\n"
                    r += "- Compare merchant spending to find cheaper alternatives\n"
                    return r
                },
                contextUpdater: { ctx, dp in
                    ctx.showCategories(items: dp.getCategoryBreakdown(year: Calendar.current.component(.year, from: Date())), isIncome: false)
                }
            ),

            // Tax Summary PDF export
            TemplatePattern(
                dataType: .tax,
                keywords: [("tax summary", 5), ("tax pdf", 5), ("export tax", 5), ("tax report", 4), ("generate report", 3), ("cpa report", 4), ("print tax", 4)],
                responseBuilder: { dp, fmt in
                    let tax = dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))
                    return "Your 2025 tax summary is ready to export!\n\n" +
                    "**Quick Overview:**\n" +
                    "- Total Income: \(fmt.string(from: NSNumber(value: tax.totalIncome)) ?? "$0")\n" +
                    "- Business Expenses: \(fmt.string(from: NSNumber(value: tax.totalBusinessExpenses)) ?? "$0")\n" +
                    "- Estimated SE Tax: \(fmt.string(from: NSNumber(value: tax.estimatedSETax)) ?? "$0")\n\n" +
                    "**To export your Tax Summary PDF:**\n" +
                    "1. Go to the **Tax** tab in the sidebar\n" +
                    "2. Scroll to the **Export** section\n" +
                    "3. Tap **\"Export 2025 Tax Summary\"**\n\n" +
                    "The PDF includes your annual summary, Schedule C breakdown, quarterly estimates, deduction details, and effective tax rates — everything your CPA needs."
                },
                contextUpdater: { ctx, dp in ctx.showTax(snapshot: dp.getTaxSnapshot(year: Calendar.current.component(.year, from: Date()))) }
            ),
        ]
    }

    // MARK: - Generate Response

    func generateResponse(
        for userMessage: String,
        conversationHistory: [AssistantMessage]
    ) async -> String {
        await generateResponse(for: userMessage, conversationHistory: conversationHistory, onPartial: nil)
    }

    /// Generates a response, optionally streaming partial text as the model
    /// produces it. `onPartial` receives the cumulative response so far.
    func generateResponse(
        for userMessage: String,
        conversationHistory: [AssistantMessage],
        onPartial: ((String) -> Void)?
    ) async -> String {
        guard let dataProvider else {
            return "Assistant is not configured. Please try again."
        }

        isGenerating = true
        defer { isGenerating = false }

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *), isAvailable {
            do {
                // Persistent session: the framework keeps the transcript and
                // calls our data tools as the model needs them
                let session = activeSession(dataProvider: dataProvider)

                var finalText = ""
                if let onPartial {
                    let stream = session.streamResponse(to: userMessage)
                    for try await partial in stream {
                        finalText = partial.content
                        onPartial(finalText)
                    }
                } else {
                    finalText = try await session.respond(to: userMessage).content
                }

                // Update Zone 3 context based on best template match
                updateContext(for: userMessage, previousMessages: conversationHistory, dataProvider: dataProvider)

                return finalText
            } catch {
                #if DEBUG
                print("❌ [Assistant] Foundation Models error: \(error.localizedDescription)")
                #endif
                // A failed session (guardrail, context overflow) shouldn't
                // poison subsequent turns — start fresh next time
                sessionStorage = nil
            }
        }
        #endif

        // Template fallback
        return generateTemplateResponse(for: userMessage, previousMessages: conversationHistory, dataProvider: dataProvider)
    }

    // MARK: - Scored Template Matching

    private func generateTemplateResponse(
        for query: String,
        previousMessages: [AssistantMessage],
        dataProvider: AssistantDataProvider
    ) -> String {
        let fmt = NumberFormatter.appCurrency

        // Build enhanced query: if current query is short/vague, prepend previous user message for context
        let enhancedQuery = buildEnhancedQuery(query, previousMessages: previousMessages)

        // Score all patterns against the enhanced query
        let scored = patterns.map { ($0, $0.score(for: enhancedQuery)) }
            .filter { $0.1 >= 3.0 }  // Minimum score threshold
            .sorted { $0.1 > $1.1 }

        if let best = scored.first {
            // Update Zone 3 context
            best.0.contextUpdater(context ?? AssistantContext(), dataProvider)

            // Build response
            return best.0.responseBuilder(dataProvider, fmt)
        }

        // Default — update Zone 3 to show nothing specific
        context?.reset()

        return "I can help you with questions about your:\n\n" +
               "- **Income & Expenses** — totals, breakdowns by category, monthly trends\n" +
               "- **Category Spending** — \"how much did I spend on groceries?\"\n" +
               "- **Tax Estimates** — SE tax, deductions, Schedule C, tax rate, quarterly payments\n" +
               "- **Mileage** — trips, deductions, IRS rates\n" +
               "- **Budgets** — spending vs planned, which are over limit\n" +
               "- **Transactions** — biggest expenses, recent activity, merchant spending\n" +
               "- **Transfers** — account-to-account movements\n" +
               "- **Invoices** — unpaid, overdue, amounts owed\n" +
               "- **Debt & Payoff** — accounts, interest rates, payoff strategy, HELOC guidance\n" +
               "- **Affordability** — can I afford a car/house, debt-to-income\n" +
               "- **Cash Flow & Savings** — savings rate, monthly surplus, income goals\n" +
               "- **Net Worth** — total account balances across all accounts\n" +
               "- **Financial Health** — overall health check with score\n\n" +
               "Try: \"Give me a financial health check\" or \"How much did I spend on food?\""
    }

    // MARK: - Context Update (for Foundation Models path)

    private func updateContext(
        for query: String,
        previousMessages: [AssistantMessage],
        dataProvider: AssistantDataProvider
    ) {
        let enhancedQuery = buildEnhancedQuery(query, previousMessages: previousMessages)
        let scored = patterns.map { ($0, $0.score(for: enhancedQuery)) }
            .filter { $0.1 >= 3.0 }
            .sorted { $0.1 > $1.1 }

        if let best = scored.first {
            best.0.contextUpdater(context ?? AssistantContext(), dataProvider)
        }
    }

    // MARK: - Conversation Context Enhancement

    /// For short/vague follow-up queries, prepend previous user message for context.
    private func buildEnhancedQuery(_ query: String, previousMessages: [AssistantMessage]) -> String {
        let words = query.split(separator: " ")

        // If query is short (≤5 words) or contains follow-up phrases, add previous context
        let isFollowUp = words.count <= 5 ||
            query.lowercased().contains("what about") ||
            query.lowercased().contains("how about") ||
            query.lowercased().contains("what if") ||
            query.lowercased().contains("break it down") ||
            query.lowercased().contains("break that down") ||
            query.lowercased().contains("show me") ||
            query.lowercased().contains("by category") ||
            query.lowercased().contains("by source")

        if isFollowUp, let lastUserMessage = previousMessages.last(where: { $0.isUser })?.content {
            return lastUserMessage + " " + query
        }

        return query
    }
}
