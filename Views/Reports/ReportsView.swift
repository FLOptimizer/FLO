//  ReportsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.7 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.7 - Dynamic Type Verification:
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for adaptive layout detection
//  ✅ ADDED: isAccessibilitySize computed property for layout switching
//  ✅ FIXED: Tax disclaimer title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tax disclaimer body text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Chart type header title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Chart type description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Period picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date range text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Legend labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Monthly net summary month labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Monthly net summary values missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Trend insight text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Projection summary title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Projection summary value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Projection summary note missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export success message missing lineLimit + minimumScaleFactor
//
//  CHANGES v3.6:
//  ✅ Split into 3 files for maintainability:
//     - ReportsView.swift (this file) - Core view, state, body, helpers
//     - ReportsChartSections.swift - All chart/section views as extension
//     - ReportsSupportingViews.swift - Standalone child structs
//  ✅ Fixed garbled UTF-8 characters throughout
//  ✅ Removed empty Color extension wrapper around previews
//  ✅ Changed cross-file properties from private to internal
//
//  CHANGES v3.5:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ All charts accessible with spoken summaries
//  ✅ EnhancedStatCard, MonthComparisonCard, InsightRow combined elements
//  ✅ TaxDeadlineCountdownCard combined with urgency context
//  ✅ TaxDeductibleSummary combined with spoken currency
//  ✅ All toolbar buttons labeled with hints
//  ✅ Date navigation buttons labeled with period context
//  ✅ Category legend/breakdown rows combined elements
//  ✅ Business vs Personal cards combined with spoken amounts
//  ✅ ReportExportSheet fully accessible with spoken currency previews
//  ✅ Empty state and export success overlay accessible
//  ✅ Screen change announcements on appear
//  ✅ All section headers marked with .isHeader trait
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
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var selectedPeriod: TimePeriod = .month
    @State private var selectedDate = Date()
    @State private var selectedChartType: ChartType = .pie
    @State private var showExportSheet = false
    @State var showComprehensiveReport = false
    @State private var showShareSheet = false
    @State private var exportData: Data?
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var showExportSuccess = false
    @State private var isExporting = false
    @State var viewAppeared = false
    
    // Dynamic Type detection
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
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
    
    var currencyCode: String {
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
                                 .foregroundStyle(Color.brandPrimaryText)
                        }
                        .accessibilityLabel("Generate CPA report")
                        .accessibilityHint("Opens comprehensive report generator for tax preparation")
                        
                        // Export Button
                        Button {
                            HapticService.play(.medium)
                            showExportSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                 .foregroundStyle(Color.brandPrimaryText)
                        }
                        .accessibilityLabel("Export report")
                        .accessibilityHint("Opens export options for PDF or CSV")
                        
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
                                 .foregroundStyle(Color.brandPrimaryText)
                        }
                        .accessibilityLabel("Chart type")
                        .accessibilityValue(selectedChartType.rawValue)
                        .accessibilityHint("Select between category breakdown, monthly trend, income vs expense, or cash flow projection")
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
                AccessibilityAnnouncement.screenChanged("Reports, \(selectedChartType.rawValue)")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Main Content
    
    private var content: some View {
        VStack(spacing: 24) {
            // Tax Deadline Countdown
            TaxDeadlineCountdownCard()
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
            
            // Tax Disclaimer
            taxDisclaimerSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            // Chart Type Header
            chartTypeHeader
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
            
            // Period Selector
            periodSelector
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            
            // Date Navigation
            dateNavigation
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            
            // Summary Cards with Trends
            summaryCards
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            
            // Chart Section
            chartSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Business vs Personal
            if totalExpense > 0 {
                businessPersonalSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
            
            // Monthly Comparison
            monthlyComparisonSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
            
            // Category Breakdown (for pie chart)
            if selectedChartType == .pie && !categoryChartData.isEmpty {
                categoryBreakdownSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
            }
            
            // Tax Deductible Summary
            TaxDeductibleSummary(transactions: filteredTransactions)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
            
            // Smart Insights
            insightsCard
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
            
            // CPA Report CTA
            cpaReportCTA
                .opacity(viewAppeared ? 1 : 0.001)
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
                    .accessibilityHidden(true)
                Text("Report exported successfully!")
                    .foregroundStyle(.white)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding()
            .background(Color.incomeGreen)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.bottom, 40)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
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
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tax Information Disclaimer")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("These reports are for informational purposes only. FLO is not a substitute for professional tax advice. Always consult a qualified tax professional.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .accessibilityElement(children: .combine)
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
                    .accessibilityHidden(true)
                Text(selectedChartType.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(selectedChartType.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Period Selector
    
    private var periodSelector: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .tag(period)
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
                     .foregroundStyle(Color.brandPrimaryText)
            }
            .accessibilityLabel("Previous \(selectedPeriod.rawValue.lowercased())")
            
            Spacer()
            
            Text(dateRangeText)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: selectedDate)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            Button {
                HapticService.play(.light)
                withAnimation(.easeInOut(duration: 0.2)) { adjustDate(by: 1) }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                     .foregroundStyle(Color.brandPrimaryText)
            }
            .accessibilityLabel("Next \(selectedPeriod.rawValue.lowercased())")
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
    
    // MARK: - Supporting Views
    
    var legendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(Color.incomeGreen).frame(width: 8, height: 8)
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 4) {
                Circle().fill(Color.expenseRed).frame(width: 8, height: 8)
                Text("Expense")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: green is income, red is expense")
    }
    
    var monthlyNetSummary: some View {
        HStack {
            ForEach(monthlyTrendData.suffix(3)) { data in
                VStack(spacing: 4) {
                    Text(data.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(formatCompactCurrency(data.netCashFlow))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(data.netCashFlow >= 0 ? Color.incomeGreen : Color.expenseRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(data.label) net: \(data.netCashFlow >= 0 ? "positive" : "negative") \(AccessibilityFormatters.spokenCurrency(abs(data.netCashFlow)))")
            }
        }
        .padding(.horizontal)
    }
    
    var trendInsightView: some View {
        let trend = calculateOverallTrend()
        return HStack {
            Image(systemName: trend >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                .foregroundStyle(trend >= 0 ? Color.incomeGreen : Color.expenseRed)
                .accessibilityHidden(true)
            Text(trend >= 0 ? "Positive trend: Net income improving" : "Watch spending: Expenses trending higher")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
    
    var projectionSummaryView: some View {
        let futureData = cashFlowProjection.suffix(3)
        let projectedNet = futureData.reduce(0) { $0 + $1.netCashFlow }
        
        return HStack {
            Image(systemName: projectedNet >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                .foregroundStyle(projectedNet >= 0 ? Color.incomeGreen : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("3-Month Projection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(formatCurrency(projectedNet))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(projectedNet >= 0 ? Color.incomeGreen : Color.orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
            }
            Spacer()
            Text("Based on recent averages")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("3-month projection: \(projectedNet >= 0 ? "positive" : "negative") \(AccessibilityFormatters.spokenCurrency(abs(projectedNet))), based on recent averages")
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
                .accessibilityHidden(true)
            Text("No transactions in this period")
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text("Add transactions to see your reports")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
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
    
    func formatCompactCurrency(_ value: Double) -> String {
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
    
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}


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
