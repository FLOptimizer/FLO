//  TransactionSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — Zone 3 transaction analysis panel.
//  Shows monthly income/expenses/net, spending by category with expandable
//  transaction lists, top merchants, and tappable drill-down navigation.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct TransactionSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext

    @State private var transactions: [Transaction] = []
    @State private var lastMonthExpenses: Double = 0
    @State private var expandedCategories: Set<String> = []
    @State private var expandedMerchants: Bool = false

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed Data

    private var monthStart: Date {
        Calendar.current.dateComponents([.calendar, .year, .month], from: Date()).date ?? Date()
    }

    private var expenses: [Transaction] {
        transactions.filter { !$0.isIncome && !$0.isTransfer }
    }

    private var income: [Transaction] {
        transactions.filter { $0.isIncome && !$0.isTransfer }
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + abs($1.amount) }
    }

    private var totalIncome: Double {
        income.reduce(0) { $0 + $1.amount }
    }

    private var netAmount: Double {
        totalIncome - totalExpenses
    }

    private var monthOverMonthDelta: Double {
        guard lastMonthExpenses > 0 else { return 0 }
        return ((totalExpenses - lastMonthExpenses) / lastMonthExpenses) * 100
    }

    private var categoryData: [TransactionCategoryData] {
        var map: [String: [Transaction]] = [:]
        for t in expenses {
            let cat = t.category?.name ?? "Uncategorized"
            map[cat, default: []].append(t)
        }
        return map
            .map { name, txns in
                TransactionCategoryData(
                    name: name,
                    transactions: txns.sorted { $0.date > $1.date },
                    total: txns.reduce(0) { $0 + abs($1.amount) }
                )
            }
            .sorted { $0.total > $1.total }
    }

    private var topMerchants: [(name: String, total: Double, count: Int)] {
        var map: [String: (total: Double, count: Int)] = [:]
        for t in expenses {
            let merchant = t.merchantName.isEmpty ? "Unknown" : t.merchantName
            var entry = map[merchant] ?? (0, 0)
            entry.total += abs(t.amount)
            entry.count += 1
            map[merchant] = entry
        }
        return map
            .map { (name: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Monthly totals
                monthlyTotalsSection

                // Month-over-month delta
                if lastMonthExpenses > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: monthOverMonthDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(monthOverMonthDelta >= 0 ? Color.expenseRed : Color.incomeGreen)
                        Text("\(abs(monthOverMonthDelta), specifier: "%.1f")% vs last month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.floSystemGroupedSectionBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.floCardBorder, lineWidth: 1))
                }

                // Category breakdown
                if categoryData.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Category")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)

                        ForEach(categoryData) { category in
                            categorySection(category)
                        }
                    }
                }

                // Top merchants
                if !topMerchants.isEmpty {
                    merchantsSection
                }
            }
            .padding()
        }
        .navigationTitle("Transaction Analysis")
        .task { loadData() }
        .onDisappear { transactions = [] }
    }

    // MARK: - Monthly Totals

    private var monthlyTotalsSection: some View {
        HStack(spacing: 10) {
            metricBox(label: "Income", amount: totalIncome, color: .incomeGreen)
            metricBox(label: "Expenses", amount: totalExpenses, color: .expenseRed)
            metricBox(label: "Net", amount: netAmount, color: netAmount >= 0 ? .incomeGreen : .expenseRed)
        }
    }

    private func metricBox(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(fmt.string(from: NSNumber(value: abs(amount))) ?? "$0")
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
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Category Section

    private func categorySection(_ data: TransactionCategoryData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    // Percentage bar indicator
                    let pct = totalExpenses > 0 ? data.total / totalExpenses : 0
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.floCardBorder)
                            .frame(width: 32, height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.brandPrimary)
                            .frame(width: max(CGFloat(pct) * 32, 2), height: 6)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(data.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("\(fmt.string(from: NSNumber(value: data.total)) ?? "$0") · \(Int((pct) * 100))% of spending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: expandedCategories.contains(data.name) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(data.transactions.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.floCardGlass)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Transaction list (expanded)
            if expandedCategories.contains(data.name) {
                Divider().padding(.leading, 56)

                ForEach(data.transactions) { transaction in
                    Button {
                        NavigationService.shared.selectedDetail = .transactionDetail(id: transaction.id)
                    } label: {
                        HStack(spacing: 10) {
                            Text(DateFormatter.shortMonthDay.string(from: transaction.date))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(width: 42, alignment: .leading)

                            Text(transaction.merchantName.isEmpty ? transaction.note : transaction.merchantName)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Text(fmt.string(from: NSNumber(value: abs(transaction.amount))) ?? "$0")
                                .font(.caption.monospacedDigit().weight(.medium))
                                .foregroundColor(.primary)

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
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.floCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Top Merchants

    private var merchantsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(FLOAnimation.quick) {
                    expandedMerchants.toggle()
                }
            } label: {
                HStack {
                    Text("Top Merchants")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expandedMerchants ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if expandedMerchants {
                Divider()
                ForEach(Array(topMerchants.enumerated()), id: \.offset) { index, merchant in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.quaternary)
                            .frame(width: 16)

                        Text(merchant.name)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text("\(merchant.count) txn\(merchant.count == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        Text(fmt.string(from: NSNumber(value: merchant.total)) ?? "$0")
                            .font(.caption.monospacedDigit().weight(.medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)

                    if index < topMerchants.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.floCardBorder, lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No transactions this month")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let now = Date()
        guard let start = calendar.dateComponents([.calendar, .year, .month], from: now).date else { return }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < tomorrow },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        transactions = (try? modelContext.fetch(descriptor)) ?? []

        // Load last month for delta
        guard let lastStart = calendar.date(byAdding: .month, value: -1, to: start) else { return }
        let lastDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= lastStart && $0.date < start }
        )
        let lastMonth = (try? modelContext.fetch(lastDescriptor)) ?? []
        lastMonthExpenses = lastMonth
            .filter { !$0.isIncome && !$0.isTransfer }
            .reduce(0) { $0 + abs($1.amount) }
    }
}

// MARK: - Supporting Data

private struct TransactionCategoryData: Identifiable {
    let id = UUID()
    let name: String
    let transactions: [Transaction]
    let total: Double
}
