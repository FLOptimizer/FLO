//  MultiYearComparisonView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Year-over-year income, expense, and depreciation comparison
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Compares financial performance across multiple tax years per entity,
//  using TaxLineAggregationService for consistent form-line totals.
//

import SwiftUI
import Charts
import FLODesignSystem
import SwiftData

struct MultiYearComparisonView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @Query private var allTransactions: [Transaction]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedBusiness: BusinessProfile?
    @State private var yearRange: Int = 3
    @State private var yearData: [YearSummary] = []
    @State private var viewAppeared = false

    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                controlsSection

                if yearData.isEmpty {
                    emptyState
                } else {
                    trendChartSection
                    overviewSection
                    detailSections
                }
            }
            .padding()
        }

        .navigationTitle("Year Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if selectedBusiness == nil {
                selectedBusiness = businesses.first
            }
            refreshData()
            withAnimation(.easeOut(duration: 0.3)) { viewAppeared = true }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "chart.bar.xaxis",
            title: "Multi-Year Comparison",
            subtitle: "Year-over-year income, expenses & depreciation",
            color: .purple
        )
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: 10) {
            if businesses.count > 1 {
                Picker("Business", selection: $selectedBusiness) {
                    ForEach(businesses) { biz in
                        Text(biz.businessName).tag(Optional(biz))
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBusiness) { _, _ in refreshData() }
            }

            Picker("Years", selection: $yearRange) {
                Text("2 Years").tag(2)
                Text("3 Years").tag(3)
                Text("5 Years").tag(5)
            }
            .pickerStyle(.segmented)
            .onChange(of: yearRange) { _, _ in refreshData() }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Data", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Add business transactions to see year-over-year comparisons.")
        }
    }

    // MARK: - Trend Chart

    private var trendChartSection: some View {
        GroupBox {
            let sortedData = yearData.sorted { $0.year < $1.year }
            Chart {
                ForEach(sortedData) { year in
                    LineMark(
                        x: .value("Year", String(year.year)),
                        y: .value("Amount", year.totalIncome)
                    )
                    .foregroundStyle(.green)
                    .symbol(.circle)
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Year", String(year.year)),
                        y: .value("Amount", year.totalExpenses)
                    )
                    .foregroundStyle(.red)
                    .symbol(.triangle)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Year", String(year.year)),
                        y: .value("Amount", year.netIncome)
                    )
                    .foregroundStyle(.blue.opacity(0.1))

                    LineMark(
                        x: .value("Year", String(year.year)),
                        y: .value("Amount", year.netIncome)
                    )
                    .foregroundStyle(.blue)
                    .symbol(.diamond)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompact(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "Income": Color.green,
                "Expenses": Color.red,
                "Net": Color.blue
            ])
            .frame(height: 200)
            .padding(.top, 4)

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green, label: "Income", symbol: "circle.fill")
                legendItem(color: .red, label: "Expenses", symbol: "triangle.fill")
                legendItem(color: .blue, label: "Net", symbol: "diamond.fill")
            }
            .font(.caption2)
            .padding(.top, 4)
        } label: {
            Label("Trend", systemImage: "chart.xyaxis.line")
                .font(.headline)
        }
    }

    private func legendItem(color: Color, label: String, symbol: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        GroupBox {
            VStack(spacing: 0) {
                comparisonHeaderRow
                ForEach(yearData) { year in
                    Divider()
                    comparisonRow(year)
                }
            }
        } label: {
            Label("Summary", systemImage: "chart.bar.fill")
                .font(.headline)
        }
    }

    private var comparisonHeaderRow: some View {
        HStack {
            Text("Year")
                .font(.caption.bold())
                .frame(width: 50, alignment: .leading)
            Text("Income")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Expenses")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Net")
                .font(.caption.bold())
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }

    private func comparisonRow(_ year: YearSummary) -> some View {
        HStack {
            Text(String(year.year))
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 50, alignment: .leading)

            Text(formatCompact(year.totalIncome))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(formatCompact(year.totalExpenses))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(formatCompact(year.netIncome))
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(year.netIncome >= 0 ? .green : .red)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Detail Sections

    private var detailSections: some View {
        VStack(spacing: 16) {
            changeSection
            depreciationSection
        }
    }

    private var changeSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                ForEach(Array(yearData.dropFirst())) { year in
                    if let prior = yearData.first(where: { $0.year == year.year - 1 }) {
                        changeRow(current: year, prior: prior)
                    }
                }
            }
        } label: {
            Label("Year-Over-Year Change", systemImage: "arrow.up.arrow.down")
                .font(.headline)
        }
    }

    private func changeRow(current: YearSummary, prior: YearSummary) -> some View {
        let incomeChange = prior.totalIncome > 0 ? ((current.totalIncome - prior.totalIncome) / prior.totalIncome) * 100 : 0
        let expenseChange = prior.totalExpenses > 0 ? ((current.totalExpenses - prior.totalExpenses) / prior.totalExpenses) * 100 : 0
        let netChange = current.netIncome - prior.netIncome

        return VStack(alignment: .leading, spacing: 6) {
            Text("\(current.year) vs \(prior.year)")
                .font(.subheadline.bold())

            HStack(spacing: 16) {
                changeMetric(label: "Income", pct: incomeChange)
                changeMetric(label: "Expenses", pct: expenseChange)
                VStack(spacing: 1) {
                    Text("Net \u{0394}")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(formatCompact(netChange))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(netChange >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func changeMetric(label: String, pct: Double) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 2) {
                Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text(String(format: "%.1f%%", abs(pct)))
                    .font(.caption.bold().monospacedDigit())
            }
            .foregroundStyle(pct >= 0 ? .green : .red)
        }
    }

    // MARK: - Depreciation

    private var depreciationSection: some View {
        let hasDepreciation = yearData.contains { $0.totalDepreciation > 0 }
        return Group {
            if hasDepreciation {
                GroupBox {
                    VStack(spacing: 8) {
                        ForEach(yearData) { year in
                            HStack {
                                Text(String(year.year))
                                    .font(.subheadline.bold().monospacedDigit())
                                Spacer()
                                let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: year.totalDepreciation)) ?? "$0"
                                Text(formatted)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(year.totalDepreciation > 0 ? .primary : .secondary)
                            }
                        }
                    }
                } label: {
                    Label("Depreciation", systemImage: "chart.line.downtrend.xyaxis")
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatCompact(_ value: Double) -> String {
        let absVal = abs(value)
        let sign = value < 0 ? "-" : ""
        if absVal >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", absVal / 1_000_000))M"
        } else if absVal >= 1_000 {
            return "\(sign)$\(String(format: "%.1f", absVal / 1_000))K"
        } else {
            return NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0"
        }
    }

    private func refreshData() {
        guard let biz = selectedBusiness else {
            yearData = []
            return
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = currentYear - yearRange + 1
        let calendar = Calendar.current

        yearData = (startYear...currentYear).map { year in
            let yearTxns = allTransactions.filter { txn in
                calendar.component(.year, from: txn.date) == year
                && txn.financeType == .business
                && !txn.isTransfer
            }

            let income = yearTxns.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
            let expenses = yearTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }

            let depreciation: Double
            if let assets = biz.assets {
                depreciation = MACRSCalculationService.shared.totalDepreciationForYear(year, assets: assets)
            } else {
                depreciation = 0
            }

            return YearSummary(
                year: year,
                totalIncome: income,
                totalExpenses: expenses,
                netIncome: income - expenses,
                totalDepreciation: depreciation
            )
        }
        .sorted { $0.year > $1.year }
    }
}

// MARK: - Year Summary

private struct YearSummary: Identifiable {
    let id = UUID()
    let year: Int
    let totalIncome: Double
    let totalExpenses: Double
    let netIncome: Double
    let totalDepreciation: Double
}
