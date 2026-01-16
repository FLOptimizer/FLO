//  ReportsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.4 - Complete merge of v3.2 features + v3.3 color palette
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.4:
//  ✅ MERGED: Multi-color chart palette from v3.3 (12 distinct colors)
//  ✅ MERGED: Tax deadline countdown card from v3.2
//  ✅ MERGED: EnhancedStatCard with trend indicators from v3.2
//  ✅ MERGED: Full chart implementations with area marks, rule lines from v3.2
//  ✅ MERGED: Smart insights card from v3.2
//  ✅ MERGED: Monthly comparison horizontal scroll from v3.2
//  ✅ MERGED: Category breakdown with color legend from v3.3
//  ✅ MERGED: All haptics and staggered animations from v3.2
//  ✅ NEW: Button to open ComprehensiveReportView for CPA-ready reports
//  ✅ NEW: Tax deductible summary section
//  ✅ IMPROVED: Business vs Personal section with chart
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Chart Color Palette

/// Provides a diverse set of visually distinct colors for charts
struct ChartColorPalette {
    
    /// 12 distinct colors that work well together in charts
    /// Colors are ordered to maximize visual distinction between adjacent slices
    static let colors: [Color] = [
        Color(flowHex: "14B8A6"),  // Teal (brand)
        Color(flowHex: "F59E0B"),  // Amber
        Color(flowHex: "8B5CF6"),  // Purple
        Color(flowHex: "EC4899"),  // Pink
        Color(flowHex: "3B82F6"),  // Blue
        Color(flowHex: "10B981"),  // Emerald
        Color(flowHex: "F97316"),  // Orange
        Color(flowHex: "06B6D4"),  // Cyan
        Color(flowHex: "EF4444"),  // Red
        Color(flowHex: "84CC16"),  // Lime
        Color(flowHex: "6366F1"),  // Indigo
        Color(flowHex: "A855F7"),  // Violet
    ]
    
    /// Hex values for the palette (for storing/matching)
    static let hexValues: [String] = [
        "14B8A6", "F59E0B", "8B5CF6", "EC4899",
        "3B82F6", "10B981", "F97316", "06B6D4",
        "EF4444", "84CC16", "6366F1", "A855F7"
    ]
    
    /// Get color by index (wraps around if more than 12 categories)
    static func color(at index: Int) -> Color {
        colors[index % colors.count]
    }
    
    /// Get hex value by index
    static func hex(at index: Int) -> String {
        hexValues[index % hexValues.count]
    }
}

// MARK: - Chart Type Enum

enum ChartType: String, CaseIterable, Identifiable {
    case pie = "Category Breakdown"
    case barTrend = "Monthly Trend"
    case lineComparison = "Income vs Expense"
    case cashFlow = "Cash Flow Projection"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .pie: return "chart.pie.fill"
        case .barTrend: return "chart.bar.fill"
        case .lineComparison: return "chart.line.uptrend.xyaxis"
        case .cashFlow: return "chart.line.flattrend.xyaxis.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .pie: return "See where your money goes"
        case .barTrend: return "Track monthly spending patterns"
        case .lineComparison: return "Compare income against expenses"
        case .cashFlow: return "Project future cash position"
        }
    }
}

// MARK: - Data Models for Charts

struct MonthlyData: Identifiable, Equatable {
    let id = UUID()
    let month: Date
    let income: Double
    let expense: Double
    let label: String
    
    var netCashFlow: Double { income - expense }
    var runningBalance: Double = 0
    
    init(month: Date, income: Double, expense: Double, label: String) {
        self.month = month
        self.income = income
        self.expense = expense
        self.label = label
    }
}

/// Category data with assigned chart color
struct CategoryChartData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: Color
    let colorHex: String
    let percentage: Double
}

// MARK: - Main Reports View

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @Query private var budgets: [Budget]
    @Query private var taxSettingsQuery: [TaxSettings]
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    @State private var selectedChartType: ChartType = .pie
    @State private var showExportSheet = false
    @State private var showComprehensiveReport = false
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var isExporting = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                    
    private var taxSettings: TaxSettings? {
        taxSettingsQuery.first
    }
    
    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
    }
    
    private var calendar: Calendar { .current }
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    // MARK: - Filtered Transactions
    
    var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            let date = transaction.date
            switch selectedPeriod {
            case .week:
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
                guard let weekStart = calendar.date(from: components) else { return false }
                let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
                return date >= weekStart && date <= weekEnd
            case .month:
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)
            case .quarter:
                let currentQuarter = (calendar.component(.month, from: selectedDate) - 1) / 3
                let transactionQuarter = (calendar.component(.month, from: date) - 1) / 3
                let sameYear = calendar.isDate(date, equalTo: selectedDate, toGranularity: .year)
                return sameYear && currentQuarter == transactionQuarter
            case .year:
                return calendar.isDate(date, equalTo: selectedDate, toGranularity: .year)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var totalIncome: Double {
        filteredTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
    }
    
    var totalExpense: Double {
        filteredTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var netCashFlow: Double {
        totalIncome - totalExpense
    }
    
    var businessExpenses: Double {
        filteredTransactions
            .filter { !$0.isIncome && $0.financeType == .business }
            .reduce(0) { $0 + $1.amount }
    }
    
    var personalExpenses: Double {
        filteredTransactions
            .filter { !$0.isIncome && $0.financeType == .personal }
            .reduce(0) { $0 + $1.amount }
    }
    
    /// Category chart data with assigned colors by index
    var categoryChartData: [CategoryChartData] {
        let nonIncomeTransactions = filteredTransactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: nonIncomeTransactions) { transaction in
            transaction.category?.name ?? "Uncategorized"
        }
        
        let sorted = grouped.map { (key, value) -> (category: String, amount: Double) in
            let totalAmount = value.reduce(0.0) { $0 + $1.amount }
            return (category: key, amount: totalAmount)
        }.sorted { $0.amount > $1.amount }
        
        // Assign colors by index for visual distinction
        return sorted.enumerated().map { index, item in
            let percentage = totalExpense > 0 ? (item.amount / totalExpense) * 100 : 0
            return CategoryChartData(
                category: item.category,
                amount: item.amount,
                color: ChartColorPalette.color(at: index),
                colorHex: ChartColorPalette.hex(at: index),
                percentage: percentage
            )
        }
    }
    
    // Legacy property for compatibility
    var categoryBreakdown: [(category: String, amount: Double, color: String)] {
        categoryChartData.map { ($0.category, $0.amount, $0.colorHex) }
    }
    
    // MARK: - Monthly Data for Trend Charts
    
    var monthlyTrendData: [MonthlyData] {
        let monthsToShow = 6
        var data: [MonthlyData] = []
        
        for i in (0..<monthsToShow).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: selectedDate) else { continue }
            
            let monthTransactions = transactions.filter { transaction in
                calendar.isDate(transaction.date, equalTo: monthDate, toGranularity: .month)
            }
            
            let income = monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let expense = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthDate)
            
            data.append(MonthlyData(month: monthDate, income: income, expense: expense, label: label))
        }
        
        return data
    }
    
    // MARK: - Cash Flow Projection Data
    
    var cashFlowProjection: [MonthlyData] {
        let pastMonths = 3
        let futureMonths = 3
        var data: [MonthlyData] = []
        var runningBalance: Double = 0
        
        let recentTransactions = transactions.filter { transaction in
            guard let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) else { return false }
            return transaction.date >= threeMonthsAgo
        }
        
        let avgMonthlyIncome = recentTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount } / 3
        let avgMonthlyExpense = recentTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } / 3
        
        for i in (0..<pastMonths).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: Date()) else { continue }
            
            let monthTransactions = transactions.filter { transaction in
                calendar.isDate(transaction.date, equalTo: monthDate, toGranularity: .month)
            }
            
            let income = monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let expense = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            runningBalance += (income - expense)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthDate)
            
            var monthData = MonthlyData(month: monthDate, income: income, expense: expense, label: label)
            monthData.runningBalance = runningBalance
            data.append(monthData)
        }
        
        for i in 1...futureMonths {
            guard let monthDate = calendar.date(byAdding: .month, value: i, to: Date()) else { continue }
            
            runningBalance += (avgMonthlyIncome - avgMonthlyExpense)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let label = formatter.string(from: monthDate) + "*"
            
            var monthData = MonthlyData(month: monthDate, income: avgMonthlyIncome, expense: avgMonthlyExpense, label: label)
            monthData.runningBalance = runningBalance
            data.append(monthData)
        }
        
        return data
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if filteredTransactions.isEmpty && selectedChartType == .pie {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // CPA Report Button
                        Button {
                            HapticService.play(.medium)
                            showComprehensiveReport = true
                        } label: {
                            Image(systemName: "doc.text.fill.viewfinder")
                                .foregroundStyle(Color.brandPrimary)
                        }
                        
                        // Export Button
                        Button {
                            HapticService.play(.medium)
                            showExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(Color.brandPrimary)
                        }
                        
                        // Chart Type Menu
                        Menu {
                            ForEach(ChartType.allCases) { chartType in
                                Button {
                                    HapticService.play(.selection)
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedChartType = chartType
                                    }
                                } label: {
                                    Label(chartType.rawValue, systemImage: chartType.icon)
                                }
                            }
                        } label: {
                            Image(systemName: selectedChartType.icon)
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ReportExportSheet(
                    transactions: filteredTransactions,
                    allTransactions: transactions,
                    dateRangeText: dateRangeText,
                    selectedPeriod: selectedPeriod,
                    totalIncome: totalIncome,
                    totalExpense: totalExpense,
                    businessExpenses: businessExpenses
                )
            }
            .sheet(isPresented: $showComprehensiveReport) {
                ComprehensiveReportView()
            }
            .overlay {
                if showExportSuccess {
                    exportSuccessOverlay
                }
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Main Content
    
    private var content: some View {
        VStack(spacing: 24) {
            // Tax Deadline Countdown
            TaxDeadlineCountdownCard()
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            // Tax Disclaimer
            taxDisclaimerSection
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            // Chart Type Header
            chartTypeHeader
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
            
            // Period Selector
            periodSelector
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            
            // Date Navigation
            dateNavigation
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            
            // Summary Cards with Trends
            summaryCards
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            
            // Chart Section
            chartSection
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Business vs Personal
            if totalExpense > 0 {
                businessPersonalSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
            
            // Monthly Comparison
            monthlyComparisonSection
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
            
            // Category Breakdown (for pie chart)
            if selectedChartType == .pie && !categoryChartData.isEmpty {
                categoryBreakdownSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
            }
            
            // Tax Deductible Summary
            TaxDeductibleSummary(transactions: filteredTransactions)
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
            
            // Smart Insights
            insightsCard
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
            
            // CPA Report CTA
            cpaReportCTA
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
        }
        .padding(.vertical)
    }
    
    // MARK: - Export Success Overlay
    
    private var exportSuccessOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                Text("Report exported successfully!")
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
            }
            .padding()
            .background(Color.incomeGreen)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            HapticService.play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showExportSuccess = false }
            }
        }
    }
    
    // MARK: - Tax Disclaimer Section
    
    private var taxDisclaimerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .symbolEffect(.pulse, options: .repeating.speed(0.5))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Information Disclaimer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("These reports are for informational purposes only. FLO is not a substitute for professional tax advice. Always consult a qualified tax professional.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Chart Type Header
    
    private var chartTypeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: selectedChartType.icon)
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, value: selectedChartType)
                Text(selectedChartType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Text(selectedChartType.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: selectedPeriod) { _, _ in
            HapticService.play(.selection)
        }
    }
    
    // MARK: - Date Navigation
    
    private var dateNavigation: some View {
        HStack {
            Button {
                HapticService.play(.light)
                withAnimation(.easeInOut(duration: 0.2)) { adjustDate(by: -1) }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
            }
            
            Spacer()
            
            Text(dateRangeText)
                .font(.headline)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: selectedDate)
            
            Spacer()
            
            Button {
                HapticService.play(.light)
                withAnimation(.easeInOut(duration: 0.2)) { adjustDate(by: 1) }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Summary Cards with Trends
    
    private var summaryCards: some View {
        HStack(spacing: 12) {
            EnhancedStatCard(
                title: "Income",
                amount: totalIncome,
                color: Color.incomeGreen,
                icon: "arrow.down.circle.fill",
                trend: calculateTrend(for: .income)
            )
            EnhancedStatCard(
                title: "Expenses",
                amount: totalExpense,
                color: Color.expenseRed,
                icon: "arrow.up.circle.fill",
                trend: calculateTrend(for: .expense)
            )
            EnhancedStatCard(
                title: "Net",
                amount: netCashFlow,
                color: netCashFlow >= 0 ? Color.brandPrimary : .orange,
                icon: netCashFlow >= 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                trend: nil
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Chart Section
    
    @ViewBuilder
    private var chartSection: some View {
        switch selectedChartType {
        case .pie:
            if !categoryChartData.isEmpty { pieChartSection }
        case .barTrend:
            barTrendChartSection
        case .lineComparison:
            lineComparisonChartSection
        case .cashFlow:
            cashFlowChartSection
        }
    }
    
    // MARK: - Pie Chart with Multi-Color Palette
    
    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .padding(.horizontal)
            
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
            
            // Category Legend with colors
            categoryLegend
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Category Legend
    
    private var categoryLegend: some View {
        VStack(spacing: 8) {
            ForEach(categoryChartData.prefix(8)) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(item.color)
                        .frame(width: 16, height: 16)
                    
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
    
    private var barTrendChartSection: some View {
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
            
            monthlyNetSummary
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Line Comparison Chart with Area Marks
    
    private var lineComparisonChartSection: some View {
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
            
            trendInsightView
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Cash Flow Projection Chart
    
    private var cashFlowChartSection: some View {
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
            
            projectionSummaryView
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Business vs Personal Section
    
    private var businessPersonalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Business vs Personal")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                // Business Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(Color.businessColor)
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
                    Text("\(businessPercent)% of expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.businessColor.opacity(0.1))
                .cornerRadius(12)
                
                // Personal Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.personalColor)
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
                    Text("\(personalPercent)% of expenses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.personalColor.opacity(0.1))
                .cornerRadius(12)
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
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Monthly Comparison Section
    
    private var monthlyComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Comparison")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(monthlyTrendData.enumerated()), id: \.element.id) { index, data in
                        MonthComparisonCard(data: data, currencyCode: currencyCode)
                            .opacity(viewAppeared ? 1 : 0)
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
    
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Details")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(categoryChartData.enumerated()), id: \.element.id) { index, item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 12, height: 12)
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
                .opacity(viewAppeared ? 1 : 0)
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
    
    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, options: .speed(0.5))
                Text("Smart Insights")
                    .font(.headline)
            }
            
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
    
    private var cpaReportCTA: some View {
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
    }
    
    // MARK: - Supporting Views
    
    private var legendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(Color.incomeGreen).frame(width: 8, height: 8)
                Text("Income").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.expenseRed).frame(width: 8, height: 8)
                Text("Expense").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    
    private var monthlyNetSummary: some View {
        HStack {
            ForEach(monthlyTrendData.suffix(3)) { data in
                VStack(spacing: 4) {
                    Text(data.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatCompactCurrency(data.netCashFlow))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(data.netCashFlow >= 0 ? Color.incomeGreen : Color.expenseRed)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }
    
    private var trendInsightView: some View {
        let trend = calculateOverallTrend()
        return HStack {
            Image(systemName: trend >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .foregroundStyle(trend >= 0 ? Color.incomeGreen : Color.expenseRed)
            Text(trend >= 0 ? "Positive trend: Net income improving" : "Watch spending: Expenses trending higher")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var projectionSummaryView: some View {
        let futureData = cashFlowProjection.suffix(3)
        let projectedNet = futureData.reduce(0) { $0 + $1.netCashFlow }
        
        return HStack {
            Image(systemName: projectedNet >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .foregroundStyle(projectedNet >= 0 ? Color.incomeGreen : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("3-Month Projection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatCurrency(projectedNet))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(projectedNet >= 0 ? Color.incomeGreen : Color.orange)
                    .contentTransition(.numericText())
            }
            Spacer()
            Text("Based on recent averages")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
            Text("No transactions in this period")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add transactions to see your reports")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "MMM d"
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        case .quarter:
            let quarter = (calendar.component(.month, from: selectedDate) - 1) / 3 + 1
            let year = calendar.component(.year, from: selectedDate)
            return "Q\(quarter) \(year)"
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: selectedDate)
        }
    }
    
    private func adjustDate(by value: Int) {
        switch selectedPeriod {
        case .week:
            selectedDate = calendar.date(byAdding: .day, value: value * 7, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: value, to: selectedDate) ?? selectedDate
        case .quarter:
            selectedDate = calendar.date(byAdding: .month, value: value * 3, to: selectedDate) ?? selectedDate
        case .year:
            selectedDate = calendar.date(byAdding: .year, value: value, to: selectedDate) ?? selectedDate
        }
    }
    
    private enum TrendType { case income, expense }
    
    private func calculateTrend(for type: TrendType) -> Double? {
        guard monthlyTrendData.count >= 2 else { return nil }
        let recent = monthlyTrendData.suffix(2)
        guard let prev = recent.first, let curr = recent.last else { return nil }
        let prevValue = type == .income ? prev.income : prev.expense
        let currValue = type == .income ? curr.income : curr.expense
        guard prevValue > 0 else { return nil }
        return ((currValue - prevValue) / prevValue) * 100
    }
    
    private func calculateOverallTrend() -> Double {
        guard monthlyTrendData.count >= 2 else { return 0 }
        let recent = monthlyTrendData.suffix(2)
        guard let prev = recent.first, let curr = recent.last else { return 0 }
        return (curr.income - curr.expense) - (prev.income - prev.expense)
    }
    
    private func formatCompactCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1000000 {
            return "\(sign)$\(String(format: "%.1fM", absValue / 1000000))"
        } else if absValue >= 1000 {
            return "\(sign)$\(String(format: "%.1fK", absValue / 1000))"
        } else {
            return "\(sign)$\(String(format: "%.0f", absValue))"
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Tax Deadline Countdown Card

struct TaxDeadlineCountdownCard: View {
    @State private var iconAppeared = false
    
    private var nextDeadline: Date? { TaxSettings.nextQuarterlyDeadline() }
    private var daysUntilDeadline: Int? {
        guard let deadline = nextDeadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    private var urgencyLevel: UrgencyLevel {
        guard let days = daysUntilDeadline else { return .none }
        if days <= 7 { return .urgent }
        if days <= 14 { return .warning }
        if days <= 30 { return .upcoming }
        return .relaxed
    }
    
    enum UrgencyLevel {
        case urgent, warning, upcoming, relaxed, none
        
        var color: Color {
            switch self {
            case .urgent: return .red
            case .warning: return .orange
            case .upcoming: return Color.brandPrimary
            case .relaxed: return .incomeGreen
            case .none: return .secondary
            }
        }
        
        var icon: String {
            switch self {
            case .urgent: return "exclamationmark.triangle.fill"
            case .warning: return "clock.badge.exclamationmark.fill"
            case .upcoming: return "calendar.badge.clock"
            case .relaxed: return "checkmark.circle.fill"
            case .none: return "calendar"
            }
        }
    }
    
    var body: some View {
        if let days = daysUntilDeadline, let deadline = nextDeadline {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: urgencyLevel.icon)
                        .font(.title2)
                        .foregroundStyle(urgencyLevel.color)
                        .symbolEffect(.bounce, value: iconAppeared)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Tax Deadline")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(deadline, style: .date)
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(days)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(urgencyLevel.color)
                            .contentTransition(.numericText())
                        Text("days left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if urgencyLevel == .urgent || urgencyLevel == .warning {
                    Text(urgencyLevel == .urgent ?
                         "Payment due soon! Make sure to submit your estimated taxes." :
                         "Deadline approaching. Prepare your estimated tax payment.")
                        .font(.caption)
                        .foregroundStyle(urgencyLevel.color)
                }
            }
            .padding()
            .background(urgencyLevel.color.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    iconAppeared = true
                }
            }
        }
    }
}

// MARK: - Enhanced Stat Card with Trends

struct EnhancedStatCard: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    let trend: Double?
    
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(amount, format: .currency(code: currencyCode))
                .font(.system(.callout, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())
            
            if let trend = trend {
                HStack(spacing: 2) {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(String(format: "%.1f", abs(trend)))%")
                        .font(.caption2)
                }
                .foregroundStyle(
                    trend >= 0 ?
                    (title == "Expenses" ? Color.expenseRed : Color.incomeGreen) :
                    (title == "Expenses" ? Color.incomeGreen : Color.expenseRed)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Month Comparison Card

struct MonthComparisonCard: View {
    let data: MonthlyData
    let currencyCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(data.label)
                .font(.headline)
                .foregroundStyle(Color.brandPrimary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(Color.incomeGreen)
                        .font(.caption)
                    Text(data.income, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(Color.incomeGreen)
                        .contentTransition(.numericText())
                }
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(Color.expenseRed)
                        .font(.caption)
                    Text(data.expense, format: .currency(code: currencyCode))
                        .font(.caption)
                        .foregroundStyle(Color.expenseRed)
                        .contentTransition(.numericText())
                }
            }
            
            Divider()
            
            HStack {
                Text("Net:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(data.netCashFlow, format: .currency(code: currencyCode))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(data.netCashFlow >= 0 ? Color.incomeGreen : Color.expenseRed)
                    .contentTransition(.numericText())
            }
        }
        .padding()
        .frame(width: 140)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let icon: String
    let color: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tax Deductible Summary

struct TaxDeductibleSummary: View {
    let transactions: [Transaction]
    
    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }
    
    var deductibleAmount: Double {
        transactions
            .filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }
            .reduce(0) { $0 + $1.amount }
    }
    
    var deductibleCount: Int {
        transactions
            .filter { !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }
            .count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color.incomeGreen)
                Text("Tax Deductible Expenses")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Deductible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(deductibleAmount, format: .currency(code: currencyCode))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.incomeGreen)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(deductibleCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .background(Color.incomeGreen.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Report Export Sheet

struct ReportExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transactions: [Transaction]
    let allTransactions: [Transaction]
    let dateRangeText: String
    let selectedPeriod: ReportsView.TimePeriod
    let totalIncome: Double
    let totalExpense: Double
    let businessExpenses: Double
    
    // Haptic Generators
                
    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        
        var icon: String {
            switch self {
            case .pdf: return "doc.richtext.fill"
            case .csv: return "tablecells.fill"
            }
        }
    }
    
    @State private var exportFormat: ExportFormat = .pdf
    @State private var includeAllTransactions = false
    @State private var includeTotals = true
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showShareSheet = false
    @State private var exportedData: Data?
    @State private var exportedURL: URL?
    
    private var transactionsToExport: [Transaction] {
        includeAllTransactions ? allTransactions : transactions
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Label(format.rawValue, systemImage: format.icon).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: exportFormat) { _, _ in
                        HapticService.play(.selection)
                    }
                } header: {
                    Text("Export Format")
                }
                
                Section {
                    Toggle("Include All Transactions", isOn: $includeAllTransactions)
                        .onChange(of: includeAllTransactions) { _, _ in
                            HapticService.play(.light)
                        }
                    if exportFormat == .csv {
                        Toggle("Include Totals Row", isOn: $includeTotals)
                            .onChange(of: includeTotals) { _, _ in
                                HapticService.play(.light)
                            }
                    }
                } header: {
                    Text("Options")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Period:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(includeAllTransactions ? "All Time" : dateRangeText)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Transactions:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(transactionsToExport.count)")
                                .fontWeight(.medium)
                                .contentTransition(.numericText())
                        }
                        HStack {
                            Text("Income:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(Color.incomeGreen)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Expenses:")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalExpense, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                .foregroundStyle(Color.expenseRed)
                                .fontWeight(.medium)
                        }
                        if businessExpenses > 0 {
                            HStack {
                                Text("Business (Deductible):")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(businessExpenses, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .foregroundStyle(Color.businessColor)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                } header: {
                    Text("Export Preview")
                }
                
                if let error = exportError {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section {
                    Button {
                        HapticService.play(.medium)
                        performExport()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Image(systemName: "square.and.arrow.up")
                            Text("Export & Share")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(isExporting || transactionsToExport.isEmpty)
                }
            }
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = exportedData {
                    ShareSheet(items: [data])
                } else if let url = exportedURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func performExport() {
        isExporting = true
        exportError = nil
        
        Task {
            switch exportFormat {
            case .pdf:
                let result = ExportService.shared.generatePDF(
                    transactions: transactionsToExport,
                    title: "FLO Financial Report - \(includeAllTransactions ? "All Time" : dateRangeText)"
                )
                switch result {
                case .success(let data):
                    exportedData = data
                    isExporting = false
                    showShareSheet = true
                case .failure(let error):
                    exportError = error.localizedDescription
                    isExporting = false
                }
                
            case .csv:
                let result = ExportService.shared.generateCSV(
                    transactions: transactionsToExport,
                    includeTotals: includeTotals
                )
                switch result {
                case .success(let csv):
                    let filename = "FLO_Report_\(Date().formatted(.iso8601.year().month().day()))"
                    let saveResult = ExportService.shared.saveCSVToTemporaryFile(csv: csv, filename: filename)
                    switch saveResult {
                    case .success(let url):
                        exportedURL = url
                        isExporting = false
                        showShareSheet = true
                    case .failure(let error):
                        exportError = error.localizedDescription
                        isExporting = false
                    }
                case .failure(let error):
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Color Extensions

extension Color {
    
    // MARK: - Preview
    
    #Preview("Reports - Full Experience") {
        let container = try! ModelContainer(
            for: Transaction.self, Category.self, Budget.self, TaxSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        
        context.insert(TaxSettings())
        
        let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "F59E0B", isIncome: false, isTaxDeductible: false)
        let supplies = Category(name: "Office Supplies", icon: "pencil", colorHex: "3B82F6", isIncome: false, isTaxDeductible: true)
        let travel = Category(name: "Travel", icon: "airplane", colorHex: "8B5CF6", isIncome: false, isTaxDeductible: true)
        let utilities = Category(name: "Utilities", icon: "bolt.fill", colorHex: "EC4899", isIncome: false, isTaxDeductible: true)
        let income = Category(name: "Client Income", icon: "dollarsign.circle.fill", colorHex: "10B981", isIncome: true, isTaxDeductible: false)
        
        [groceries, supplies, travel, utilities, income].forEach { context.insert($0) }
        
        let calendar = Calendar.current
        for monthOffset in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: Date()) else { continue }
            
            context.insert(Transaction(
                amount: Double.random(in: 4000...8000),
                date: monthDate,
                note: "Client payment",
                isIncome: true,
                merchantName: "Acme Corp",
                category: income,
                financeType: .business
            ))
            
            context.insert(Transaction(
                amount: Double.random(in: 100...300),
                date: monthDate,
                note: "Shopping",
                isIncome: false,
                merchantName: "Whole Foods",
                category: groceries,
                financeType: .personal
            ))
            
            context.insert(Transaction(
                amount: Double.random(in: 50...150),
                date: monthDate,
                note: "Supplies",
                isIncome: false,
                merchantName: "Staples",
                category: supplies,
                financeType: .business
            ))
            
            context.insert(Transaction(
                amount: Double.random(in: 200...500),
                date: monthDate,
                note: "Business trip",
                isIncome: false,
                merchantName: "Delta Airlines",
                category: travel,
                financeType: .business
            ))
            
            context.insert(Transaction(
                amount: Double.random(in: 80...150),
                date: monthDate,
                note: "Electric bill",
                isIncome: false,
                merchantName: "Power Company",
                category: utilities,
                financeType: .business
            ))
        }
        
        return ReportsView().modelContainer(container)
    }
    
    #Preview("Tax Deadline Card") {
        TaxDeadlineCountdownCard()
            .padding()
    }
}
