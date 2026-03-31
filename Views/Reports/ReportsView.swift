//  ReportsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.8 — Transfer Exclusion Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.8 — Transfer Exclusion:
//  ✅ FIXED: filteredTransactions now excludes isTransfer transactions
//  ✅ FIXED: totalIncome, totalExpense, businessExpenses, personalExpenses all now correct
//  ✅ FIXED: categoryChartData no longer inflated by uncategorized transfers
//  ✅ FIXED: monthlyTrendData excludes transfers (was using raw transactions)
//  ✅ FIXED: cashFlowProjection excludes transfers (was using raw transactions)
//  ✅ ROOT CAUSE: Transfers (Owner's Draw, Venmo, bank-to-bank) had no category and
//    were counted as expenses, inflating "Uncategorized" to 98% in Spending by Category
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
    // v5.1: Replaced @Query with FetchDescriptor for memory optimization.
    // @Query loaded all ~382 transactions; now we only load the needed date range.
    @Environment(\.modelContext) private var modelContext
    @State private var transactions: [Transaction] = []
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

    // MARK: - Cached Chart Data (Phase 1 Optimization)
    // Computed once in refreshChartData() instead of per-render.
    @State private var cachedFiltered: [Transaction] = []
    @State private var cachedTotalIncome: Double = 0
    @State private var cachedTotalExpense: Double = 0
    @State private var cachedBusinessExpenses: Double = 0
    @State private var cachedPersonalExpenses: Double = 0
    @State private var cachedCategoryData: [CategoryChartData] = []
    @State private var cachedMonthlyTrend: [MonthlyData] = []
    @State private var cachedCashFlow: [MonthlyData] = []
    
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
    
    // MARK: - Cached Property Accessors
    // These return pre-computed values from refreshChartData().
    // Eliminates ~30 redundant filter/sort/group ops per render cycle.

    var filteredTransactions: [Transaction] { cachedFiltered }
    var totalIncome: Double { cachedTotalIncome }
    var totalExpense: Double { cachedTotalExpense }
    var netCashFlow: Double { cachedTotalIncome - cachedTotalExpense }
    var businessExpenses: Double { cachedBusinessExpenses }
    var personalExpenses: Double { cachedPersonalExpenses }
    var categoryChartData: [CategoryChartData] { cachedCategoryData }
    var monthlyTrendData: [MonthlyData] { cachedMonthlyTrend }
    var cashFlowProjection: [MonthlyData] { cachedCashFlow }

    // MARK: - Refresh Chart Data (Single-Pass Computation)

    /// Computes all derived chart data from transactions + period in a single pass.
    /// Called from loadTransactions() and onChange handlers.
    private func refreshChartData() {
        // 1. Filter transactions for selected period
        let filtered = transactions.filter { transaction in
            guard !transaction.isTransfer else { return false }
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
        cachedFiltered = filtered

        // 2. Single-pass aggregation (income, expense, business, personal)
        var income: Double = 0
        var expense: Double = 0
        var business: Double = 0
        var personal: Double = 0
        for t in filtered {
            if t.isIncome {
                income += t.amount
            } else {
                expense += t.amount
                if t.financeType == .business { business += t.amount }
                if t.financeType == .personal { personal += t.amount }
            }
        }
        cachedTotalIncome = income
        cachedTotalExpense = expense
        cachedBusinessExpenses = business
        cachedPersonalExpenses = personal

        // 3. Category chart data
        let nonIncome = filtered.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: nonIncome) { $0.category?.name ?? "Uncategorized" }
        let sorted = grouped.map { (key, value) -> (category: String, amount: Double) in
            (category: key, amount: value.reduce(0.0) { $0 + $1.amount })
        }.sorted { $0.amount > $1.amount }

        cachedCategoryData = sorted.enumerated().map { index, item in
            let pct = expense > 0 ? (item.amount / expense) * 100 : 0
            return CategoryChartData(
                category: item.category,
                amount: item.amount,
                color: ChartColorPalette.color(at: index),
                colorHex: ChartColorPalette.hex(at: index),
                percentage: pct
            )
        }

        // 4. Monthly trend data (6 months)
        var trendData: [MonthlyData] = []
        for i in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: selectedDate) else { continue }
            let monthTxns = transactions.filter { !$0.isTransfer && calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) }
            let mIncome = monthTxns.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let mExpense = monthTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            trendData.append(MonthlyData(month: monthDate, income: mIncome, expense: mExpense, label: DateFormatter.shortMonth.string(from: monthDate)))
        }
        cachedMonthlyTrend = trendData

        // 5. Cash flow projection (3 past + 3 future)
        var cfData: [MonthlyData] = []
        var runningBalance: Double = 0
        let recentTxns = transactions.filter { !$0.isTransfer && $0.date >= (calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()) }
        let avgIncome = recentTxns.filter(\.isIncome).reduce(0) { $0 + $1.amount } / 3
        let avgExpense = recentTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } / 3

        for i in (0..<3).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: Date()) else { continue }
            let mTxns = transactions.filter { !$0.isTransfer && calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month) }
            let mIn = mTxns.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let mEx = mTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            runningBalance += (mIn - mEx)
            var md = MonthlyData(month: monthDate, income: mIn, expense: mEx, label: DateFormatter.shortMonth.string(from: monthDate))
            md.runningBalance = runningBalance
            cfData.append(md)
        }
        for i in 1...3 {
            guard let monthDate = calendar.date(byAdding: .month, value: i, to: Date()) else { continue }
            runningBalance += (avgIncome - avgExpense)
            var md = MonthlyData(month: monthDate, income: avgIncome, expense: avgExpense, label: DateFormatter.shortMonth.string(from: monthDate) + "*")
            md.runningBalance = runningBalance
            cfData.append(md)
        }
        cachedCashFlow = cfData
    }

    // MARK: - Data Loading (v5.1)

    /// Loads transactions for the widest needed date range.
    /// monthlyTrendData and cashFlowProjection look back 6 months,
    /// so we fetch from 7 months ago to cover all computed properties.
    private func loadTransactions() {
        let calendar = Calendar.current
        let now = Date()

        // Widest range: 6 months back for trend data + current period
        guard let rangeStart = calendar.date(byAdding: .month, value: -7, to: now) else { return }

        // Exclude future-dated (upcoming) items
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= rangeStart && $0.date < tomorrow },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )

        do {
            transactions = try modelContext.fetch(descriptor)
            #if DEBUG
            print("📊 [Reports] Loaded \(transactions.count) transactions (7-month window)")
            #endif
        } catch {
            #if DEBUG
            print("❌ [Reports] Failed to fetch: \(error.localizedDescription)")
            #endif
            transactions = []
        }
        refreshChartData()
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
                loadTransactions()
                DispatchQueue.main.async {
                    withAnimation(FLOAnimation.standard) {
                        viewAppeared = true
                    }
                }
                AccessibilityAnnouncement.screenChanged("Reports, \(selectedChartType.rawValue)")
            }
            .onDisappear {
                // Release memory when leaving Reports tab
                transactions = []
                cachedFiltered = []
                cachedCategoryData = []
                cachedMonthlyTrend = []
                cachedCashFlow = []
                cachedTotalIncome = 0
                cachedTotalExpense = 0
                cachedBusinessExpenses = 0
                cachedPersonalExpenses = 0
                exportData = nil
                exportURL = nil
                viewAppeared = false
            }
            .onChange(of: selectedPeriod) { _, _ in loadTransactions() }
            .onChange(of: selectedDate) { _, _ in loadTransactions() }
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

            // Chart Section (only selected chart renders)
            chartSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 15)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)

            // Phase 3: Lazy-load below-the-fold sections — only render when scrolled into view
            LazyVStack(spacing: 24) {
                // Business vs Personal
                if totalExpense > 0 {
                    businessPersonalSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                }

                // Monthly Comparison (only for trend chart types)
                if selectedChartType == .barTrend || selectedChartType == .lineComparison {
                    monthlyComparisonSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                }

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
            .background(Color.floSecondarySystemBackground)
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
            if !monthlyTrendData.isEmpty { barTrendChartSection }
        case .lineComparison:
            if !monthlyTrendData.isEmpty { lineComparisonChartSection }
        case .cashFlow:
            if !cashFlowProjection.isEmpty { cashFlowChartSection }
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
        .background(Color.floTertiarySystemBackground)
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
        switch selectedPeriod {
        case .week:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            return "\(DateFormatter.shortMonthDay.string(from: weekStart)) - \(DateFormatter.shortMonthDay.string(from: weekEnd))"
        case .month:
            return DateFormatter.monthYear.string(from: selectedDate)
        case .quarter:
            let quarter = (calendar.component(.month, from: selectedDate) - 1) / 3 + 1
            let year = calendar.component(.year, from: selectedDate)
            return "Q\(quarter) \(year)"
        case .year:
            return DateFormatter.yearOnly.string(from: selectedDate)
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
        NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$\(value)"
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
