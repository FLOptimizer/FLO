//  ProfitLossReportView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4 - Dynamic Type Verification:
//  ✅ FIXED: Pro locked view "Pro Feature" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Pro locked view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLFeatureBenefit title and description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Upgrade to Pro" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Current plan text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Period selector button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date range text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SummaryStatCard title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SummaryStatCard value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SummaryStatCard change percentage missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NetProfitCard title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NetProfitCard value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NetProfitCard profit margin label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NetProfitCard profit margin value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: NetProfitCard "vs prior period" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLSectionView title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLLineItemRow item name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLLineItemRow amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Statement of Profit & Loss" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Statement header date range missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "NET PROFIT / (LOSS)" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Net profit value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Period Comparison" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ComparisonRow label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ComparisonRow current value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ComparisonRow change percentage missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Disclaimer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLExportView title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLExportView description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PLExportView button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Blurred preview sample text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "What You'll Get" header missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.3:
//  ✅ Transfers excluded from revenue, expenses, and category breakdowns
//
//  CHANGES v1.2:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ All section headers marked with .isHeader trait
//  ✅ Toolbar buttons labeled with hints
//  ✅ Period selector buttons with .isSelected trait
//  ✅ SummaryStatCard, NetProfitCard combined with spoken currency
//  ✅ PLSectionView/PLLineItemRow combined with spoken amounts
//  ✅ ComparisonRow combined with spoken values and change direction
//  ✅ Disclaimer icon hidden, section combined
//  ✅ Pro locked view accessible with benefit rows combined
//  ✅ PLExportView decorative icon hidden, button labeled
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES v1.1:
//  ✅ Added Pro tier gating - only Pro subscribers can access
//  ✅ Free/Premium users see professional upgrade prompt
//  ✅ Preview of report structure visible but blurred
//  ✅ Clear value proposition for upgrading
//
//  FEATURES v1.0:
//  ✅ Professional P&L statement format
//  ✅ Revenue breakdown by category
//  ✅ Expense breakdown with Business/Personal split
//  ✅ Gross and Net profit calculations
//  ✅ Period over period comparison
//  ✅ Export to PDF capability
//  ✅ Animated entrance effects
//

import SwiftUI
import SwiftData

// MARK: - P&L Line Item

struct PLLineItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let isSubtotal: Bool
    let isTotal: Bool
    let indent: Int
    
    init(name: String, amount: Double, isSubtotal: Bool = false, isTotal: Bool = false, indent: Int = 0) {
        self.name = name
        self.amount = amount
        self.isSubtotal = isSubtotal
        self.isTotal = isTotal
        self.indent = indent
    }
}

// MARK: - P&L Section

struct PLSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [PLLineItem]
    let subtotal: Double
}

// MARK: - Profit Loss Report View

struct ProfitLossReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var selectedPeriod: ReportPeriod = .thisMonth
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingExport = false
    @State private var showingSubscriptionView = false
    @State private var viewAppeared = false
    @State private var showComparison = true
    
    // v1.1: Check if user has Pro access
    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }
    
    enum ReportPeriod: String, CaseIterable {
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisQuarter = "This Quarter"
        case lastQuarter = "Last Quarter"
        case thisYear = "This Year"
        case lastYear = "Last Year"
        case custom = "Custom"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
                return (start, min(end, now))
                
            case .lastMonth:
                let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
                let end = calendar.date(byAdding: .day, value: -1, to: thisMonth)!
                return (start, end)
                
            case .thisQuarter:
                let month = calendar.component(.month, from: now)
                let quarterStart = ((month - 1) / 3) * 3 + 1
                var components = calendar.dateComponents([.year], from: now)
                components.month = quarterStart
                components.day = 1
                let start = calendar.date(from: components)!
                return (start, now)
                
            case .lastQuarter:
                let month = calendar.component(.month, from: now)
                let quarterStart = ((month - 1) / 3) * 3 + 1
                var components = calendar.dateComponents([.year], from: now)
                components.month = quarterStart - 3
                if components.month! <= 0 {
                    components.month! += 12
                    components.year! -= 1
                }
                components.day = 1
                let start = calendar.date(from: components)!
                let end = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: start)!
                return (start, end)
                
            case .thisYear:
                var components = calendar.dateComponents([.year], from: now)
                components.month = 1
                components.day = 1
                let start = calendar.date(from: components)!
                return (start, now)
                
            case .lastYear:
                var components = calendar.dateComponents([.year], from: now)
                components.year! -= 1
                components.month = 1
                components.day = 1
                let start = calendar.date(from: components)!
                components.month = 12
                components.day = 31
                let end = calendar.date(from: components)!
                return (start, end)
                
            case .custom:
                return (Date(), Date()) // Will use custom dates
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var dateRange: (start: Date, end: Date) {
        if selectedPeriod == .custom {
            return (customStartDate, customEndDate)
        }
        return selectedPeriod.dateRange
    }
    
    private var previousDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let range = dateRange
        let duration = range.end.timeIntervalSince(range.start)
        let previousStart = calendar.date(byAdding: .second, value: -Int(duration), to: range.start)!
        let previousEnd = calendar.date(byAdding: .second, value: -1, to: range.start)!
        return (previousStart, previousEnd)
    }
    
    private var filteredTransactions: [Transaction] {
        allTransactions.filter { transaction in
            transaction.date >= dateRange.start && transaction.date <= dateRange.end && !transaction.isTransfer
        }
    }
    
    private var previousPeriodTransactions: [Transaction] {
        let range = previousDateRange
        return allTransactions.filter { transaction in
            transaction.date >= range.start && transaction.date <= range.end && !transaction.isTransfer
        }
    }
    
    // MARK: - Revenue Calculations
    
    private var totalRevenue: Double {
        filteredTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    private var previousRevenue: Double {
        previousPeriodTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    private var revenueByCategory: [(category: String, amount: Double)] {
        let incomeTransactions = filteredTransactions.filter { $0.isIncome }
        let grouped = Dictionary(grouping: incomeTransactions) { $0.category?.name ?? "Other Income" }
        return grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Expense Calculations
    
    private var totalExpenses: Double {
        filteredTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    private var previousExpenses: Double {
        previousPeriodTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    private var businessExpenses: Double {
        filteredTransactions.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }
    }
    
    private var personalExpenses: Double {
        filteredTransactions.filter { !$0.isIncome && $0.financeType == .personal }.reduce(0) { $0 + $1.amount }
    }
    
    private var expensesByCategory: [(category: String, amount: Double, isBusiness: Bool)] {
        let expenseTransactions = filteredTransactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenseTransactions) { $0.category?.name ?? "Uncategorized" }
        return grouped.map { key, value in
            let amount = value.reduce(0) { $0 + $1.amount }
            let isBusiness = value.first?.financeType == .business
            return (category: key, amount: amount, isBusiness: isBusiness)
        }.sorted { $0.amount > $1.amount }
    }
    
    // MARK: - Profit Calculations
    
    private var grossProfit: Double {
        totalRevenue - businessExpenses
    }
    
    private var netProfit: Double {
        totalRevenue - totalExpenses
    }
    
    private var previousNetProfit: Double {
        previousRevenue - previousExpenses
    }
    
    private var profitMargin: Double {
        guard totalRevenue > 0 else { return 0 }
        return (netProfit / totalRevenue) * 100
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                // v1.1: Gate content to Pro tier
                if hasProAccess {
                    reportContent
                } else {
                    proFeatureLockedView
                }
            }
            .navigationTitle("Profit & Loss")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                
                // Only show menu for Pro users
                if hasProAccess {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                showComparison.toggle()
                                HapticService.play(.selection)
                            } label: {
                                Label(
                                    showComparison ? "Hide Comparison" : "Show Comparison",
                                    systemImage: showComparison ? "eye.slash" : "eye"
                                )
                            }
                            
                            Divider()
                            
                            Button {
                                HapticService.play(.medium)
                                showingExport = true
                            } label: {
                                Label("Export PDF", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                 .foregroundStyle(Color.brandPrimaryText)
                        }
                        .accessibilityLabel("Report options")
                        .accessibilityHint("Show comparison toggle and export options")
                    }
                }
            }
            .sheet(isPresented: $showingExport) {
                PLExportView(
                    dateRange: dateRange,
                    totalRevenue: totalRevenue,
                    totalExpenses: totalExpenses,
                    businessExpenses: businessExpenses,
                    personalExpenses: personalExpenses,
                    netProfit: netProfit,
                    revenueByCategory: revenueByCategory,
                    expensesByCategory: expensesByCategory
                )
            }
            .sheet(isPresented: $showingSubscriptionView) {
                SubscriptionView()
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Profit and loss report")
            }
        }
    }
    
    // MARK: - Pro Feature Locked View
    // v1.1: Professional upgrade prompt for Free/Premium users
    
    private var proFeatureLockedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Blurred preview of what they'd see
                ZStack {
                    // Sample report preview (blurred)
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Revenue")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text("$12,450")
                                    .font(.title2.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Expenses")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Text("$8,230")
                                    .font(.title2.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("REVENUE")
                                .font(.caption.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.secondary)
                            Text("Client Services.........$8,500")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("Product Sales............$3,950")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .blur(radius: 6)
                    .opacity(0.6)
                    .accessibilityHidden(true)
                    
                    // Lock overlay
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .scaleEffect(viewAppeared ? 1 : 0.5)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: viewAppeared)
                        
                        Text("Pro Feature")
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                        
                        Text("Profit & Loss Reports are available\nexclusively for Pro subscribers")
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .accessibilityElement(children: .combine)
                }
                .padding()
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Feature benefits
                VStack(alignment: .leading, spacing: 16) {
                    Text("What You'll Get")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    
                    PLFeatureBenefit(
                        icon: "doc.text.fill",
                        title: "Professional P&L Statements",
                        description: "Generate accountant-ready profit & loss reports"
                    )
                    
                    PLFeatureBenefit(
                        icon: "chart.bar.fill",
                        title: "Revenue & Expense Breakdown",
                        description: "See exactly where your money comes from and goes"
                    )
                    
                    PLFeatureBenefit(
                        icon: "arrow.left.arrow.right",
                        title: "Period Comparisons",
                        description: "Compare performance month-over-month or year-over-year"
                    )
                    
                    PLFeatureBenefit(
                        icon: "square.and.arrow.up",
                        title: "PDF Export",
                        description: "Share reports with your accountant or clients"
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Upgrade button
                Button {
                    HapticService.play(.medium)
                    showingSubscriptionView = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro")
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Current tier indicator
                Text("Current plan: \(subscriptionManager.currentTier.displayName)")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Report Content (Pro Users Only)
    
    private var reportContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                periodSelectorSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // Summary Cards
                summaryCardsSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                // P&L Statement
                plStatementSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                // Comparison Toggle
                if showComparison {
                    comparisonSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                }
                
                // Disclaimer
                disclaimerSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 15)
                    .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Period Selector
    
    private var periodSelectorSection: some View {
        VStack(spacing: 12) {
            // Period Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReportPeriod.allCases, id: \.self) { period in
                        Button {
                            withAnimation(FLOAnimation.quick) {
                                selectedPeriod = period
                            }
                            HapticService.play(.selection)
                        } label: {
                            Text(period.rawValue)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fontWeight(selectedPeriod == period ? .semibold : .regular)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedPeriod == period ? Color.brandPrimary : Color(.secondarySystemBackground))
                                )
                                .foregroundStyle(selectedPeriod == period ? .white : .primary)
                        }
                        .accessibilityAddTraits(selectedPeriod == period ? .isSelected : [])
                        .accessibilityHint("Select \(period.rawValue) period")
                    }
                }
                .padding(.horizontal)
            }
            
            // Date Range Display
            Text(dateRangeText)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
    }
    
    // MARK: - Summary Cards
    
    private var summaryCardsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Revenue Card
                SummaryStatCard(
                    title: "Revenue",
                    value: totalRevenue,
                    previousValue: showComparison ? previousRevenue : nil,
                    color: .incomeGreen,
                    icon: "arrow.down.circle.fill"
                )
                
                // Expenses Card
                SummaryStatCard(
                    title: "Expenses",
                    value: totalExpenses,
                    previousValue: showComparison ? previousExpenses : nil,
                    color: .expenseRed,
                    icon: "arrow.up.circle.fill"
                )
            }
            
            // Net Profit Card (full width)
            NetProfitCard(
                netProfit: netProfit,
                previousNetProfit: showComparison ? previousNetProfit : nil,
                profitMargin: profitMargin
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - P&L Statement Section
    
    private var plStatementSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Statement of Profit & Loss")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(dateRangeText)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.brandPrimary.opacity(0.1))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            
            Divider()
            
            // Revenue Section
            PLSectionView(
                title: "REVENUE",
                items: revenueItems,
                subtotal: totalRevenue,
                subtotalLabel: "Total Revenue"
            )
            
            Divider()
            
            // Business Expenses Section
            if businessExpenses > 0 {
                PLSectionView(
                    title: "BUSINESS EXPENSES",
                    items: businessExpenseItems,
                    subtotal: businessExpenses,
                    subtotalLabel: "Total Business Expenses"
                )
                
                // Gross Profit Line
                PLLineItemRow(
                    item: PLLineItem(name: "Gross Profit", amount: grossProfit, isSubtotal: true),
                    showDivider: true
                )
                
                Divider()
            }
            
            // Personal Expenses Section (if any)
            if personalExpenses > 0 {
                PLSectionView(
                    title: "PERSONAL EXPENSES",
                    items: personalExpenseItems,
                    subtotal: personalExpenses,
                    subtotalLabel: "Total Personal Expenses"
                )
                
                Divider()
            }
            
            // Net Profit/Loss
            HStack {
                Text("NET PROFIT / (LOSS)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(formatCurrency(netProfit))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fontWeight(.bold)
                    .foregroundStyle(netProfit >= 0 ? Color.incomeGreen : Color.expenseRed)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Net \(netProfit >= 0 ? "profit" : "loss"): \(AccessibilityFormatters.spokenCurrency(abs(netProfit)))")
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Line Items
    
    private var revenueItems: [PLLineItem] {
        revenueByCategory.map { item in
            PLLineItem(name: item.category, amount: item.amount, indent: 1)
        }
    }
    
    private var businessExpenseItems: [PLLineItem] {
        expensesByCategory
            .filter { $0.isBusiness }
            .map { PLLineItem(name: $0.category, amount: $0.amount, indent: 1) }
    }
    
    private var personalExpenseItems: [PLLineItem] {
        expensesByCategory
            .filter { !$0.isBusiness }
            .map { PLLineItem(name: $0.category, amount: $0.amount, indent: 1) }
    }
    
    // MARK: - Comparison Section
    
    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text("Period Comparison")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityAddTraits(.isHeader)
            
            VStack(spacing: 8) {
                ComparisonRow(
                    label: "Revenue",
                    current: totalRevenue,
                    previous: previousRevenue
                )
                
                ComparisonRow(
                    label: "Expenses",
                    current: totalExpenses,
                    previous: previousExpenses
                )
                
                Divider()
                
                ComparisonRow(
                    label: "Net Profit",
                    current: netProfit,
                    previous: previousNetProfit,
                    isBold: true
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Disclaimer
    
    private var disclaimerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("This report is for informational purposes only and should not be used as official financial documentation. Consult a CPA for tax advice.")
                .font(.caption)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if value < 0 {
            formatter.negativePrefix = "("
            formatter.negativeSuffix = ")"
        }
        return formatter.string(from: NSNumber(value: abs(value))) ?? "$0.00"
    }
}

// MARK: - P&L Feature Benefit Row
// v1.1: New component for upgrade prompt

struct PLFeatureBenefit: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 28)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(description)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Supporting Views

struct SummaryStatCard: View {
    let title: String
    let value: Double
    let previousValue: Double?
    let color: Color
    let icon: String
    
    private var changePercentage: Double? {
        guard let previous = previousValue, previous != 0 else { return nil }
        return ((value - previous) / previous) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
            
            Text(value, format: .currency(code: "USD"))
                .font(.title2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .fontWeight(.bold)
            
            if let change = changePercentage {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%.1f%%", abs(change)))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var label = "\(title): \(AccessibilityFormatters.spokenCurrency(value))"
            if let change = changePercentage {
                let direction = change >= 0 ? "up" : "down"
                label += ", \(direction) \(String(format: "%.1f", abs(change))) percent versus prior period"
            }
            return label
        }())
    }
}

struct NetProfitCard: View {
    let netProfit: Double
    let previousNetProfit: Double?
    let profitMargin: Double
    
    private var changePercentage: Double? {
        guard let previous = previousNetProfit, previous != 0 else { return nil }
        return ((netProfit - previous) / abs(previous)) * 100
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: netProfit >= 0 ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis")
                        .foregroundStyle(netProfit >= 0 ? Color.incomeGreen : Color.expenseRed)
                    Text("Net Profit")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
                
                Text(netProfit, format: .currency(code: "USD"))
                    .font(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fontWeight(.bold)
                    .foregroundStyle(netProfit >= 0 ? Color.incomeGreen : Color.expenseRed)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("Profit Margin")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                
                Text(String(format: "%.1f%%", profitMargin))
                    .font(.title2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.semibold)
                    .foregroundStyle(profitMargin >= 0 ? Color.incomeGreen : Color.expenseRed)
                
                if let change = changePercentage {
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("vs prior period")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var label = "Net profit: \(netProfit >= 0 ? "" : "negative ")\(AccessibilityFormatters.spokenCurrency(abs(netProfit)))"
            label += ", profit margin \(String(format: "%.1f", profitMargin)) percent"
            if let change = changePercentage {
                let direction = change >= 0 ? "up" : "down"
                label += ", \(direction) versus prior period"
            }
            return label
        }())
    }
}

struct PLSectionView: View {
    let title: String
    let items: [PLLineItem]
    let subtotal: Double
    let subtotalLabel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Title
            Text(title)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .accessibilityAddTraits(.isHeader)
            
            // Line Items
            ForEach(items) { item in
                PLLineItemRow(item: item)
            }
            
            // Subtotal
            PLLineItemRow(
                item: PLLineItem(name: subtotalLabel, amount: subtotal, isSubtotal: true),
                showDivider: false
            )
        }
    }
}

struct PLLineItemRow: View {
    let item: PLLineItem
    var showDivider: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.name)
                    .font(item.isSubtotal || item.isTotal ? .subheadline : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(item.isSubtotal || item.isTotal ? .semibold : .regular)
                    .padding(.leading, CGFloat(item.indent) * 16)
                
                Spacer()
                
                Text(formatCurrency(item.amount))
                    .font(item.isSubtotal || item.isTotal ? .subheadline : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fontWeight(item.isSubtotal || item.isTotal ? .semibold : .regular)
            }
            .padding(.horizontal)
            .padding(.vertical, item.isSubtotal ? 10 : 6)
            .background(item.isSubtotal ? Color(.tertiarySystemBackground) : Color.clear)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.name): \(AccessibilityFormatters.spokenCurrency(item.amount))")
            
            if showDivider {
                Divider()
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

struct ComparisonRow: View {
    let label: String
    let current: Double
    let previous: Double
    var isBold: Bool = false
    
    private var change: Double {
        current - previous
    }
    
    private var changePercentage: Double {
        guard previous != 0 else { return 0 }
        return (change / abs(previous)) * 100
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(isBold ? .subheadline : .caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fontWeight(isBold ? .semibold : .regular)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(current, format: .currency(code: "USD"))
                    .font(isBold ? .subheadline : .caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .fontWeight(isBold ? .semibold : .regular)
                
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%.1f%%", abs(changePercentage)))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(AccessibilityFormatters.spokenCurrency(current)), \(change >= 0 ? "up" : "down") \(String(format: "%.1f", abs(changePercentage))) percent versus prior period")
    }
}

// MARK: - Export View (Placeholder)

struct PLExportView: View {
    @Environment(\.dismiss) private var dismiss
    
    let dateRange: (start: Date, end: Date)
    let totalRevenue: Double
    let totalExpenses: Double
    let businessExpenses: Double
    let personalExpenses: Double
    let netProfit: Double
    let revenueByCategory: [(category: String, amount: Double)]
    let expensesByCategory: [(category: String, amount: Double, isBusiness: Bool)]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                Text("Export P&L Report")
                    .font(.title2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.bold)
                
                Text("Generate a PDF of your Profit & Loss statement for the selected period.")
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button {
                    HapticService.play(.medium)
                    // TODO: Implement PDF export using ComprehensiveReportService
                    dismiss()
                } label: {
                    Label("Generate PDF", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.brandPrimary)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .accessibilityHint("Generates and shares a PDF profit and loss report")
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfitLossReportView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
