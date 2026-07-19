//  DashboardRedesignedView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Redesigned dashboard with hero metric, smart chips, budget circles.
//  Replaces the dashboardContent section of DashboardView with Build 10 visual redesign.
//  Uses inline FLO 3.0 design tokens (will migrate to FLODesignSystem package import later).
//
//  Per Build 10 spec:
//  - Hero metric: net cash flow with SpendingLine trend
//  - Smart chips row: tax deadline, budget warnings (urgency order)
//  - Budget circles grid: alphabetical, replaces progress bars
//  - Review badge: "N transactions to review"
//  - Category tags on recent transactions
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

// MARK: - Dashboard Hero Section

/// Large hero metric showing net cash flow with trend line.
struct DashboardHeroMetric: View {
    let netCashFlow: Double
    let dailyTotals: [Double]
    let budgetTotal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Cash Flow")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text(netCashFlow, format: .currency(code: "USD"))
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundStyle(netCashFlow >= 0 ? Color.green : Color.red)
                .contentTransition(.numericText())

            // Spending trend line
            if !dailyTotals.isEmpty {
                DashboardTrendLine(data: dailyTotals, budget: budgetTotal)
                    .frame(height: 80)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .floGlassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Net cash flow: \(netCashFlow >= 0 ? "positive" : "negative") \(abs(netCashFlow), format: .currency(code: "USD"))")
    }
}

// MARK: - Trend Line (Inline SpendingLine)

/// Gradient trend line for the hero area.
struct DashboardTrendLine: View {
    let data: [Double]
    let budget: Double

    private var maxValue: Double {
        max(data.max() ?? 0, budget, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .topLeading) {
                // Budget threshold line
                if budget > 0 {
                    let y = height * (1 - budget / maxValue)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.5))
                }

                // Trend line
                if data.count > 1 {
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height * (1 - value / maxValue)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )

                    // Gradient fill under curve
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(data.count - 1)
                            let y = height * (1 - value / maxValue)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.brandPrimary.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Smart Chips Row

/// Horizontal row of contextual info chips (tax deadlines, budget warnings).
struct DashboardSmartChips: View {
    let budgets: [(budget: Budget, spent: Double)]
    let taxDeadline: Date?
    var nextPayday: Date? = nil
    var incomeTrendPercent: Double? = nil    // +15 = 15% above avg, -10 = 10% below
    var savingsRate: Double? = nil           // 0.22 = 22% savings rate
    var currentMonthIncome: Double = 0
    var currentMonthExpenses: Double = 0

    private var chips: [(icon: String, text: String, style: ChipStyle, priority: Int)] {
        var result: [(String, String, ChipStyle, Int)] = []

        // Tax deadline chip (priority 1 — most urgent)
        if let deadline = taxDeadline {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
            if days <= 30 && days >= 0 {
                let quarter = TaxSettings.quarterNumber()
                let style: ChipStyle = days <= 7 ? .urgent : days <= 14 ? .warning : .info
                let priority = days <= 7 ? 0 : days <= 14 ? 1 : 3
                result.append(("🗓️", "Q\(quarter) taxes due in \(days)d", style, priority))
            }
        }

        // Spending exceeds income (priority 0 — critical)
        if currentMonthExpenses > currentMonthIncome && currentMonthIncome > 0 {
            let overBy = Int(((currentMonthExpenses / currentMonthIncome) - 1) * 100)
            result.append(("🔴", "Spending \(overBy)% over income", .urgent, 0))
        } else if let rate = savingsRate, rate > 0 {
            // Savings rate chip
            let pct = Int(rate * 100)
            if pct >= 20 {
                result.append(("💪", "Saving \(pct)% this month", .success, 5))
            } else if pct >= 10 {
                result.append(("💰", "Saving \(pct)% this month", .neutral, 5))
            }
        }

        // Over-budget chips (priority 1)
        for item in budgets where item.spent > item.budget.planned && item.budget.planned > 0 {
            let name = item.budget.displayName
            let pct = Int((item.spent / item.budget.planned) * 100)
            result.append(("🚨", "\(name) \(pct)%", .urgent, 1))
        }

        // Near-budget chips (priority 2)
        for item in budgets where item.budget.planned > 0 {
            let pct = item.spent / item.budget.planned
            if pct >= 0.8 && pct <= 1.0 {
                let name = item.budget.displayName
                result.append(("⚠️", "\(name) \(Int(pct * 100))%", .warning, 2))
            }
        }

        // Payday countdown (priority 3)
        if let payday = nextPayday {
            let days = Calendar.current.dateComponents([.day], from: Date(), to: payday).day ?? 0
            if days >= 0 && days <= 14 {
                result.append(("💰", "Payday in \(days)d", .info, 3))
            }
        }

        // Income trend (priority 4)
        if let trend = incomeTrendPercent {
            let pct = Int(abs(trend))
            if trend >= 10 {
                result.append(("📈", "Income \(pct)% above avg", .success, 4))
            } else if trend <= -10 {
                result.append(("📉", "Income \(pct)% below avg", .warning, 4))
            }
        }

        // Sort by priority (lowest = most urgent first)
        return result.sorted { $0.3 < $1.3 }
    }

    enum ChipStyle {
        case neutral, warning, urgent, success, info

        var background: Color {
            switch self {
            case .neutral: return .secondary.opacity(0.12)
            case .warning: return .orange.opacity(0.15)
            case .urgent: return .red.opacity(0.15)
            case .success: return .green.opacity(0.15)
            case .info: return Color.brandPrimary.opacity(0.12)
            }
        }

        var border: Color {
            switch self {
            case .neutral: return .secondary.opacity(0.2)
            case .warning: return .orange.opacity(0.3)
            case .urgent: return .red.opacity(0.3)
            case .success: return .green.opacity(0.3)
            case .info: return Color.brandPrimary.opacity(0.25)
            }
        }
    }

    var body: some View {
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                        HStack(spacing: 4) {
                            Text(chip.icon)
                                .font(.system(size: 12))
                            Text(chip.text)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(chip.style.background)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(chip.style.border, lineWidth: 0.5)
                        )
                    }
                }
                .padding(.horizontal)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(chips.map { "\($0.text)" }.joined(separator: ", "))
        }
    }
}

// MARK: - Budget Circles Grid

/// Grid of circular budget progress indicators, alphabetically ordered.
struct DashboardBudgetCircles: View {
    let budgets: [(budget: Budget, spent: Double)]
    let onTap: ((Budget) -> Void)?

    private var sortedBudgets: [(budget: Budget, spent: Double)] {
        budgets.sorted { $0.budget.displayName.localizedCompare($1.budget.displayName) == .orderedAscending }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 90, maximum: 120), spacing: 12)
    ]

    var body: some View {
        if !sortedBudgets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section header
                HStack {
                    Text("Budgets")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

                // Summary bar
                let totalSpent = sortedBudgets.reduce(0) { $0 + $1.spent }
                let totalBudget = sortedBudgets.reduce(0) { $0 + $1.budget.planned }
                if totalBudget > 0 {
                    HStack {
                        Text(totalSpent, format: .currency(code: "USD"))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                        Text("of")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(totalBudget, format: .currency(code: "USD"))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Circles grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(sortedBudgets, id: \.budget.id) { item in
                        budgetCircle(for: item)
                            .onTapGesture {
                                HapticService.play(.selection)
                                onTap?(item.budget)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func budgetCircle(for item: (budget: Budget, spent: Double)) -> some View {
        BudgetCircle(
            sfSymbol: item.budget.category?.icon,
            name: item.budget.displayName,
            spent: item.spent,
            budget: item.budget.planned,
            size: .standard
        )
        .accessibilityHint("Double tap to view budget details")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Review Badge (Inline)

/// "N to review" badge for unreviewed transactions.
struct DashboardReviewBadge: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        if count > 0 {
            Button(action: action) {
                HStack(spacing: 8) {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.brandPrimary)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Mark \(count) as reviewed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Tap to review transactions")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.brandPrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.brandPrimary.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(count) transactions to review")
            .accessibilityHint("Double tap to review")
        }
    }
}

// MARK: - Recent Transactions with Category Tags

/// Recent transaction row with inline category tag.
struct DashboardRecentRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 10) {
            // Category tag pill
            if let categoryName = transaction.category?.name {
                Text(categoryName)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: transaction.category?.colorHex ?? "64748B"))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(transaction.date, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(transaction.isIncome ? "+" : "-")
                .foregroundStyle(transaction.isIncome ? .green : .primary)
            +
            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(transaction.isIncome ? .green : .primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.merchantName), \(transaction.isIncome ? "income" : "expense"), \(transaction.amount, format: .currency(code: "USD"))")
    }
}

// MARK: - Assembled Redesigned Content

/// The redesigned dashboard content section. Drop this into DashboardView's dashboardContent.
struct DashboardRedesignedContent: View {
    let netCashFlow: Double
    let dailyTotals: [Double]
    let budgetTotal: Double
    let budgetItems: [(budget: Budget, spent: Double)]
    let recentTransactions: [Transaction]
    let reviewCount: Int
    let taxDeadline: Date?
    let financeMode: FinanceMode
    let onBudgetTap: ((Budget) -> Void)?
    let onReviewTap: () -> Void

    var body: some View {
        LazyVStack(spacing: 16) {
            // 1. Hero Metric
            DashboardHeroMetric(
                netCashFlow: netCashFlow,
                dailyTotals: dailyTotals,
                budgetTotal: budgetTotal
            )
            .padding(.horizontal)

            // 2. Smart Chips
            DashboardSmartChips(
                budgets: budgetItems,
                taxDeadline: taxDeadline
            )

            // 3. Review Badge
            DashboardReviewBadge(count: reviewCount, action: onReviewTap)
                .padding(.horizontal)

            // 4. Budget Circles (alphabetical)
            DashboardBudgetCircles(
                budgets: budgetItems,
                onTap: onBudgetTap
            )

            // 5. Recent Transactions with Category Tags
            if !recentTransactions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(recentTransactions.prefix(8)) { transaction in
                        DashboardRecentRow(transaction: transaction)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Dashboard Hero") {
    DashboardHeroMetric(
        netCashFlow: 2847.32,
        dailyTotals: [320, 580, 940, 1200, 1680, 2100, 2450],
        budgetTotal: 2800
    )
    .padding()
    .background(Color.floCanvas)
}
#endif
