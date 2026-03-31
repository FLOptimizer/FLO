//  TransactionSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 contextual summary for the Transactions tab.
//  Shows total spend hero metric, category pie chart,
//  daily average, and month-over-month delta.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import Charts

struct TransactionSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext

    @State private var thisMonthTransactions: [Transaction] = []
    @State private var lastMonthExpenses: Double = 0

    private var totalSpend: Double {
        thisMonthTransactions
            .filter { !$0.isIncome && !$0.isTransfer }
            .reduce(0) { $0 + abs($1.amount) }
    }

    private var totalIncome: Double {
        thisMonthTransactions
            .filter { $0.isIncome && !$0.isTransfer }
            .reduce(0) { $0 + $1.amount }
    }

    private var transactionCount: Int {
        thisMonthTransactions.filter { !$0.isTransfer }.count
    }

    private var dailyAverage: Double {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: Date())
        guard day > 0 else { return 0 }
        return totalSpend / Double(day)
    }

    private var monthOverMonthDelta: Double {
        guard lastMonthExpenses > 0 else { return 0 }
        return ((totalSpend - lastMonthExpenses) / lastMonthExpenses) * 100
    }

    private var categoryBreakdown: [CategorySlice] {
        var map: [String: Double] = [:]
        for t in thisMonthTransactions where !t.isIncome && !t.isTransfer {
            let cat = t.category?.name ?? "Uncategorized"
            map[cat, default: 0] += abs(t.amount)
        }
        let total = map.values.reduce(0, +)
        guard total > 0 else { return [] }

        let colors: [Color] = [.brandPrimary, .expenseRed, .incomeGreen, .brandWarning, .purple, .orange, .cyan, .pink]
        return map.sorted { $0.value > $1.value }
            .prefix(8)
            .enumerated()
            .map { index, item in
                CategorySlice(
                    category: item.key,
                    amount: item.value,
                    percentage: (item.value / total) * 100,
                    color: colors[index % colors.count]
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero: Total Spend
                SummaryHeroMetric(amount: totalSpend, subtitle: "Spending This Month", style: .neutral)
                    .floGlassCard()

                // Category Donut Chart
                if !categoryBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Category")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Chart(categoryBreakdown) { item in
                            SectorMark(
                                angle: .value("Amount", max(item.amount, 0)),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(item.color)
                            .annotation(position: .overlay) {
                                if item.percentage > 10 {
                                    Text("\(Int(item.percentage))%")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Spending by category chart")

                        // Legend
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(categoryBreakdown) { item in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 8, height: 8)
                                    Text(item.category)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .floGlassCard()
                }

                // Stats Row
                HStack(spacing: 12) {
                    statCard(title: "Daily Avg", value: dailyAverage, style: .neutral)
                    statCard(title: "Transactions", count: transactionCount)
                }

                // Month-over-Month
                if lastMonthExpenses > 0 {
                    HStack {
                        Image(systemName: monthOverMonthDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .foregroundStyle(monthOverMonthDelta >= 0 ? Color.expenseRed : Color.incomeGreen)
                        Text("\(abs(monthOverMonthDelta), specifier: "%.1f")% vs last month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .floGlassCard()
                }

                // Income summary
                SummaryHeroMetric(amount: totalIncome, subtitle: "Income This Month", style: .branded)
                    .floGlassCard()
            }
            .padding()
        }
        .navigationTitle("Transaction Summary")
        .task { loadData() }
    }

    private func statCard(title: String, value: Double, style: SummaryHeroMetric.MetricStyle = .auto) -> some View {
        VStack(spacing: 4) {
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .floGlassCard()
    }

    private func statCard(title: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.brandPrimaryText)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .floGlassCard()
    }

    private func loadData() {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.dateComponents([.calendar, .year, .month], from: now).date else { return }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= monthStart && $0.date < tomorrow },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        do {
            thisMonthTransactions = try modelContext.fetch(descriptor)
        } catch {
            thisMonthTransactions = []
        }

        // Last month expenses for comparison
        guard let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else { return }
        let lastMonthEnd = monthStart

        let lastDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= lastMonthStart && $0.date < lastMonthEnd }
        )

        do {
            let lastMonth = try modelContext.fetch(lastDescriptor)
            lastMonthExpenses = lastMonth
                .filter { !$0.isIncome && !$0.isTransfer }
                .reduce(0) { $0 + abs($1.amount) }
        } catch {
            lastMonthExpenses = 0
        }
    }
}

private struct CategorySlice: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
}
