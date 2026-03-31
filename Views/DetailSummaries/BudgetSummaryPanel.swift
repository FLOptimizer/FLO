//  BudgetSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — Zone 3 budget analysis panel.
//  Shows monthly totals, each budgeted category with its transactions,
//  over-budget categories highlighted, and tappable transactions for reclassification.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct BudgetSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]

    @State private var transactions: [Transaction] = []
    @State private var expandedCategories: Set<String> = []

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed Data

    private var currentMonthBudgets: [Budget] {
        let calendar = Calendar.current
        return budgets.filter { calendar.isDate($0.month, equalTo: Date(), toGranularity: .month) }
    }

    private var monthStart: Date {
        Calendar.current.dateComponents([.calendar, .year, .month], from: Date()).date ?? Date()
    }

    private var categoryData: [CategoryBudgetData] {
        currentMonthBudgets
            .compactMap { budget -> CategoryBudgetData? in
                guard let category = budget.category else { return nil }
                let catName = category.name
                let planned = budget.planned + budget.carryOver

                let catTransactions = transactions
                    .filter { !$0.isIncome && !$0.isTransfer && $0.category?.name == catName && $0.date >= monthStart }
                    .sorted { $0.date > $1.date }

                let spent = catTransactions.reduce(0) { $0 + abs($1.amount) }

                return CategoryBudgetData(
                    name: catName,
                    budgeted: planned,
                    spent: spent,
                    transactions: catTransactions,
                    isOverBudget: spent > planned && planned > 0,
                    percentUsed: planned > 0 ? (spent / planned) * 100 : 0
                )
            }
            .sorted { a, b in
                // Over-budget first, then by percent used descending
                if a.isOverBudget != b.isOverBudget { return a.isOverBudget }
                return a.percentUsed > b.percentUsed
            }
    }

    private var totalBudgeted: Double { categoryData.reduce(0) { $0 + $1.budgeted } }
    private var totalSpent: Double { categoryData.reduce(0) { $0 + $1.spent } }
    private var totalRemaining: Double { max(totalBudgeted - totalSpent, 0) }
    private var overBudgetCount: Int { categoryData.filter(\.isOverBudget).count }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Monthly totals
                monthlyTotalsSection

                // Over-budget alert
                if overBudgetCount > 0 {
                    SummaryChip(
                        icon: "exclamationmark.triangle.fill",
                        text: "\(overBudgetCount) budget\(overBudgetCount == 1 ? "" : "s") over limit",
                        style: .urgent
                    )
                }

                // Category sections with transactions
                if categoryData.isEmpty {
                    emptyState
                } else {
                    ForEach(categoryData) { category in
                        categorySection(category)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Budget Analysis")
        .task { loadTransactions() }
        .onDisappear { transactions = [] }
    }

    // MARK: - Monthly Totals

    private var monthlyTotalsSection: some View {
        HStack(spacing: 12) {
            metricBox(label: "Spent", amount: totalSpent, color: totalSpent > totalBudgeted ? .expenseRed : .primary)
            metricBox(label: "Budgeted", amount: totalBudgeted, color: .secondary)
            metricBox(label: "Remaining", amount: totalRemaining, color: .incomeGreen)
        }
    }

    private func metricBox(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(fmt.string(from: NSNumber(value: amount)) ?? "$0")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(10)
    }

    // MARK: - Category Section

    private func categorySection(_ data: CategoryBudgetData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category header — tappable to expand/collapse
            Button {
                withAnimation(FLOAnimation.quick) {
                    if expandedCategories.contains(data.name) {
                        expandedCategories.remove(data.name)
                    } else {
                        expandedCategories.insert(data.name)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    // Progress indicator
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.1), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        Circle()
                            .trim(from: 0, to: min(data.percentUsed / 100, 1.0))
                            .stroke(
                                data.isOverBudget ? Color.expenseRed : data.percentUsed >= 80 ? Color.orange : Color.brandPrimary,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(data.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            if data.isOverBudget {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                        }
                        Text("\(fmt.string(from: NSNumber(value: data.spent)) ?? "$0") of \(fmt.string(from: NSNumber(value: data.budgeted)) ?? "$0") · \(Int(data.percentUsed))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Expand/collapse indicator
                    Image(systemName: expandedCategories.contains(data.name) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(data.transactions.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Transaction list (expanded)
            if expandedCategories.contains(data.name) {
                Divider().padding(.leading, 56)

                if data.transactions.isEmpty {
                    Text("No transactions this month")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 56)
                        .padding(.vertical, 8)
                } else {
                    ForEach(data.transactions) { transaction in
                        Button {
                            NavigationService.shared.selectedDetail = .transactionDetail(id: transaction.id)
                        } label: {
                            HStack(spacing: 10) {
                                // Date
                                Text(DateFormatter.shortMonthDay.string(from: transaction.date))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 42, alignment: .leading)

                                // Merchant
                                Text(transaction.merchantName)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Spacer()

                                // Amount
                                Text(fmt.string(from: NSNumber(value: transaction.amount)) ?? "$0")
                                    .font(.caption.monospacedDigit().weight(.medium))
                                    .foregroundColor(.primary)

                                // Navigate chevron
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.quaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.leading, 42)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if transaction.id != data.transactions.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    data.isOverBudget ? Color.expenseRed.opacity(0.3) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No budgets set for this month")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data Loading

    private func loadTransactions() {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= monthStart }
        )
        transactions = (try? modelContext.fetch(descriptor)) ?? []

        // Auto-expand over-budget categories
        for cat in categoryData where cat.isOverBudget {
            expandedCategories.insert(cat.name)
        }
    }
}

// MARK: - Supporting Data

private struct CategoryBudgetData: Identifiable {
    let id = UUID()
    let name: String
    let budgeted: Double
    let spent: Double
    let transactions: [Transaction]
    let isOverBudget: Bool
    let percentUsed: Double
}
