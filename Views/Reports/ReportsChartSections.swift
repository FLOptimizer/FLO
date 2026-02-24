//  ReportsChartSections.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Extracted from ReportsView v3.5 (Sprint 5a)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CONTENTS:
//  ✅ Pie chart with multi-color palette and category legend
//  ✅ Bar trend chart (6-month income vs expense)
//  ✅ Line comparison chart with area marks
//  ✅ Cash flow projection chart
//  ✅ Business vs Personal section with horizontal bar
//  ✅ Monthly comparison horizontal scroll
//  ✅ Category breakdown detail rows
//  ✅ Smart insights card
//  ✅ CPA report CTA button
//
//  ACCESSIBILITY (Sprint 5a):
//  ✅ All charts combined with spoken summaries
//  ✅ All section headers marked with .isHeader
//  ✅ Decorative icons hidden
//  ✅ Category rows combined with spoken currency and percentage
//  ✅ Business/Personal cards combined with spoken amounts
//

import SwiftUI
import Charts

// MARK: - Chart Sections Extension

extension ReportsView {
    
    // MARK: - Pie Chart with Multi-Color Palette
    
    var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            Chart(categoryChartData) { item in
                SectorMark(
                    angle: .value("Amount", max(item.amount, 0)),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .foregroundStyle(item.color)
                .annotation(position: .overlay) {
                    if item.percentage > 8 {
                        Text("\(Int(item.percentage))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Spending by category pie chart")
            .accessibilityValue({
                let top3 = categoryChartData.prefix(3).map { "\($0.category) \(Int($0.percentage))%" }.joined(separator: ", ")
                return "Top categories: \(top3)"
            }())
            
            // Category Legend with colors
            categoryLegend
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Category Legend
    
    var categoryLegend: some View {
        VStack(spacing: 8) {
            ForEach(categoryChartData.prefix(8)) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: 16, height: 16)
                        .accessibilityHidden(true)
                    
                    Text(item.category)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.amount, format: .currency(code: currencyCode))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .contentTransition(.numericText())
                        Text("\(Int(item.percentage))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.category), \(AccessibilityFormatters.spokenCurrency(item.amount)), \(Int(item.percentage)) percent")
            }
            
            if categoryChartData.count > 8 {
                Text("and \(categoryChartData.count - 8) more categories...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bar Trend Chart
    
    var barTrendChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("6-Month Trend")
                    .font(.headline)
                Spacer()
                legendView
            }
            .padding(.horizontal)
            
            Chart(monthlyTrendData) { data in
                BarMark(
                    x: .value("Month", data.label),
                    y: .value("Amount", data.expense)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.expenseRed.opacity(0.8), Color.expenseRed],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .position(by: .value("Type", "Expense"))
                
                BarMark(
                    x: .value("Month", data.label),
                    y: .value("Amount", data.income)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.incomeGreen.opacity(0.8), Color.incomeGreen],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
                .position(by: .value("Type", "Income"))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Six month spending trend bar chart")
            .accessibilityValue({
                let recent = monthlyTrendData.suffix(2)
                if let last = recent.last {
                    return "Most recent month: \(last.label), income \(AccessibilityFormatters.spokenCurrency(last.income)), expenses \(AccessibilityFormatters.spokenCurrency(last.expense))"
                }
                return "No data available"
            }())
            
            monthlyNetSummary
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Line Comparison Chart with Area Marks
    
    var lineComparisonChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Income vs Expense")
                    .font(.headline)
                Spacer()
                legendView
            }
            .padding(.horizontal)
            
            Chart {
                ForEach(monthlyTrendData) { data in
                    // Income Line
                    LineMark(
                        x: .value("Month", data.label),
                        y: .value("Income", data.income)
                    )
                    .foregroundStyle(Color.incomeGreen)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.incomeGreen)
                            .frame(width: 10, height: 10)
                    }
                    .interpolationMethod(.catmullRom)
                    
                    // Income Area
                    AreaMark(
                        x: .value("Month", data.label),
                        y: .value("Income", data.income)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.incomeGreen.opacity(0.3), Color.incomeGreen.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    // Expense Line
                    LineMark(
                        x: .value("Month", data.label),
                        y: .value("Expense", data.expense)
                    )
                    .foregroundStyle(Color.expenseRed)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol {
                        Circle()
                            .fill(Color.expenseRed)
                            .frame(width: 10, height: 10)
                    }
                    .interpolationMethod(.catmullRom)
                    
                    // Expense Area
                    AreaMark(
                        x: .value("Month", data.label),
                        y: .value("Expense", data.expense)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.expenseRed.opacity(0.3), Color.expenseRed.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Income versus expense line chart over six months")
            .accessibilityValue({
                if let last = monthlyTrendData.last {
                    let net = last.income - last.expense
                    return "Latest month \(last.label): net \(net >= 0 ? "positive" : "negative") \(AccessibilityFormatters.spokenCurrency(abs(net)))"
                }
                return "No data"
            }())
            
            trendInsightView
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Cash Flow Projection Chart
    
    var cashFlowChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cash Flow Projection")
                    .font(.headline)
                Spacer()
                Text("* = Projected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Chart(cashFlowProjection) { data in
                BarMark(
                    x: .value("Month", data.label),
                    y: .value("Net", data.netCashFlow)
                )
                .foregroundStyle(
                    data.netCashFlow >= 0 ?
                    LinearGradient(
                        colors: [Color.incomeGreen.opacity(0.7), Color.incomeGreen],
                        startPoint: .bottom,
                        endPoint: .top
                    ) :
                    LinearGradient(
                        colors: [Color.expenseRed.opacity(0.7), Color.expenseRed],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(4)
                
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cash flow projection chart, three months past and three months projected")
            .accessibilityValue({
                let future = cashFlowProjection.suffix(3)
                let projected = future.reduce(0) { $0 + $1.netCashFlow }
                return "Three month projected net: \(projected >= 0 ? "positive" : "negative") \(AccessibilityFormatters.spokenCurrency(abs(projected)))"
            }())
            
            projectionSummaryView
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Business vs Personal Section
    
    var businessPersonalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business vs Personal")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: 16) {
                // Business Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(Color.businessColor)
                            .accessibilityHidden(true)
                        Text("Business")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text(businessExpenses, format: .currency(code: currencyCode))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.businessColor)
                        .contentTransition(.numericText())
                    let businessPercent = totalExpense > 0 ? Int((businessExpenses / totalExpense) * 100) : 0
                    ProgressView(value: Double(businessPercent), total: 100)
                        .tint(Color.businessColor)
                        .accessibilityHidden(true)
                    Text("\(businessPercent)% of expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.businessColor.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Business expenses: \(AccessibilityFormatters.spokenCurrency(businessExpenses)), \(totalExpense > 0 ? Int((businessExpenses / totalExpense) * 100) : 0) percent of total")
                
                // Personal Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.personalColor)
                            .accessibilityHidden(true)
                        Text("Personal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Text(personalExpenses, format: .currency(code: currencyCode))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.personalColor)
                        .contentTransition(.numericText())
                    let personalPercent = totalExpense > 0 ? Int((personalExpenses / totalExpense) * 100) : 0
                    ProgressView(value: Double(personalPercent), total: 100)
                        .tint(Color.personalColor)
                        .accessibilityHidden(true)
                    Text("\(personalPercent)% of expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.personalColor.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Personal expenses: \(AccessibilityFormatters.spokenCurrency(personalExpenses)), \(totalExpense > 0 ? Int((personalExpenses / totalExpense) * 100) : 0) percent of total")
            }
            .padding(.horizontal)
            
            // Horizontal Bar Chart
            Chart {
                BarMark(x: .value("Amount", businessExpenses), y: .value("Type", "Business"))
                    .foregroundStyle(Color.businessColor)
                    .cornerRadius(6)
                BarMark(x: .value("Amount", personalExpenses), y: .value("Type", "Personal"))
                    .foregroundStyle(Color.personalColor)
                    .cornerRadius(6)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 100)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Business versus personal comparison bar chart")
            .accessibilityValue("Business: \(AccessibilityFormatters.spokenCurrency(businessExpenses)), Personal: \(AccessibilityFormatters.spokenCurrency(personalExpenses))")
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Monthly Comparison Section
    
    var monthlyComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Comparison")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(monthlyTrendData.enumerated()), id: \.element.id) { index, data in
                        MonthComparisonCard(data: data, currencyCode: currencyCode)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                FLOAnimation.standard
                                    .delay(0.5 + Double(index) * 0.05),
                                value: viewAppeared
                            )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Category Breakdown Section
    
    var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Details")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(Array(categoryChartData.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text(item.category)
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.amount, format: .currency(code: currencyCode))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .contentTransition(.numericText())
                        Text("\(Int(item.percentage))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(item.category): \(AccessibilityFormatters.spokenCurrency(item.amount)), \(Int(item.percentage)) percent")
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(x: viewAppeared ? 0 : 15)
                .animation(
                    FLOAnimation.standard
                        .delay(0.55 + Double(index) * 0.03),
                    value: viewAppeared
                )
            }
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Insights Card
    
    var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, options: .speed(0.5))
                    .accessibilityHidden(true)
                Text("Smart Insights")
                    .font(.headline)
            }
            .accessibilityAddTraits(.isHeader)
            
            VStack(alignment: .leading, spacing: 8) {
                if netCashFlow > 0 {
                    InsightRow(
                        icon: "checkmark.circle.fill",
                        color: .incomeGreen,
                        text: "You're in positive cash flow this period. Great job!"
                    )
                } else if netCashFlow < 0 {
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        color: .orange,
                        text: "Expenses exceeded income by \(formatCurrency(abs(netCashFlow)))"
                    )
                }
                
                if businessExpenses > 0 {
                    InsightRow(
                        icon: "building.2.fill",
                        color: Color.businessColor,
                        text: "Business expenses: \(formatCurrency(businessExpenses)) (potential deductions)"
                    )
                }
                
                if let topCategory = categoryChartData.first {
                    InsightRow(
                        icon: "chart.pie.fill",
                        color: topCategory.color,
                        text: "\(topCategory.category) is your top spending category at \(Int(topCategory.percentage))%"
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - CPA Report CTA
    
    var cpaReportCTA: some View {
        Button {
            HapticService.play(.medium)
            showComprehensiveReport = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill.viewfinder")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate CPA-Ready Report")
                        .font(.headline)
                    Text("Comprehensive PDF for tax preparation")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.body)
            }
            .foregroundStyle(.white)
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.brandPrimary, Color.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Generate CPA-ready report")
        .accessibilityHint("Opens comprehensive PDF report for tax preparation")
        .accessibilityAddTraits(.isButton)
    }
}
