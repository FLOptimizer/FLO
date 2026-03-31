//  BudgetSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 contextual summary for the Budgets tab.
//  Shows total budget utilization hero metric and a grid
//  of BudgetCircle progress rings for each active budget.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData

struct BudgetSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]

    @State private var transactions: [Transaction] = []

    private var currentMonthBudgets: [Budget] {
        let calendar = Calendar.current
        let now = Date()
        return budgets.filter { budget in
            calendar.isDate(budget.month, equalTo: now, toGranularity: .month)
        }
    }

    private var budgetItems: [BudgetItem] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.dateComponents([.calendar, .year, .month], from: now).date else { return [] }

        return currentMonthBudgets.map { budget in
            let catName = budget.category?.name ?? "Unknown"
            let emoji = categoryEmoji(for: catName)
            let planned = budget.planned + budget.carryOver

            let spent = transactions
                .filter { !$0.isIncome && !$0.isTransfer && $0.category?.name == catName && $0.date >= monthStart }
                .reduce(0) { $0 + abs($1.amount) }

            return BudgetItem(emoji: emoji, name: catName, spent: spent, budget: planned)
        }
        .sorted { $0.budget > $1.budget }
    }

    private func categoryEmoji(for name: String) -> String {
        let emojiMap: [String: String] = [
            "Dining Out": "🍽️", "Groceries": "🥬", "Coffee": "☕",
            "Software & Tools": "💻", "Transportation": "🚗", "Entertainment": "🎬",
            "Shopping": "🛍️", "Housing": "🏠", "Office Supplies": "📎",
            "Health": "🏥", "Utilities": "💡", "Client Payment": "💰",
            "Education": "📚", "Travel": "✈️", "Insurance": "🛡️",
            "Subscriptions": "📱", "Personal Care": "💇", "Gifts": "🎁",
        ]
        return emojiMap[name] ?? "📊"
    }

    private var totalBudgeted: Double {
        budgetItems.reduce(0) { $0 + $1.budget }
    }

    private var totalSpent: Double {
        budgetItems.reduce(0) { $0 + $1.spent }
    }

    private var overBudgetCount: Int {
        budgetItems.filter { $0.spent > $0.budget && $0.budget > 0 }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero: Total Budget Utilization
                VStack(spacing: 8) {
                    SummaryHeroMetric(amount: totalSpent, subtitle: "Spent of \(formatted(totalBudgeted)) Budgeted", style: .neutral)

                    if totalBudgeted > 0 {
                        ProgressView(value: min(totalSpent / totalBudgeted, 1.0))
                            .tint(totalSpent > totalBudgeted ? Color.expenseRed : Color.brandPrimary)
                            .accessibilityLabel("Budget utilization \(Int((totalSpent / totalBudgeted) * 100))%")
                    }
                }
                .floGlassCard()

                // Alert chips
                if overBudgetCount > 0 {
                    SummaryChip(
                        icon: "exclamationmark.triangle.fill",
                        text: "\(overBudgetCount) budget\(overBudgetCount == 1 ? "" : "s") over limit",
                        style: .urgent
                    )
                }

                // Budget Circles Grid
                if !budgetItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category Budgets")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 16) {
                            ForEach(budgetItems) { item in
                                SummaryBudgetRing(
                                    emoji: item.emoji,
                                    name: item.name,
                                    spent: item.spent,
                                    budget: item.budget
                                )
                            }
                        }
                    }
                    .floGlassCard()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.pie")
                            .font(.system(size: 40, weight: .ultraLight))
                            .foregroundStyle(.quaternary)
                        Text("No budgets set for this month")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .floGlassCard()
                }

                // Quick stats
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("\(currentMonthBudgets.count)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.brandPrimaryText)
                        Text("Active Budgets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .floGlassCard()

                    VStack(spacing: 4) {
                        let remaining = max(totalBudgeted - totalSpent, 0)
                        Text(remaining, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.incomeGreen)
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .floGlassCard()
                }
            }
            .padding()
        }
        .navigationTitle("Budget Overview")
        .task { loadTransactions() }
    }

    private func loadTransactions() {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.dateComponents([.calendar, .year, .month], from: now).date else { return }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= monthStart }
        )

        do {
            transactions = try modelContext.fetch(descriptor)
        } catch {
            transactions = []
        }
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}

private struct BudgetItem: Identifiable {
    let id = UUID()
    let emoji: String
    let name: String
    let spent: Double
    let budget: Double
}
