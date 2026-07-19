//  BudgetListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.1 — Wrap-Up View + Carryover Override
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.1 — Wrap-Up View + Carryover Override:
//  ✅ ADDED: BudgetWrapUpView sheet presentation from wrap-up banner
//  ✅ UPDATED: totalCarryover uses effectiveShouldCarryOver
//  ✅ UPDATED: copyPreviousMonthBudgets propagates allowCarryOverOverride + respects effectiveShouldCarryOver
//
//  CHANGES v4.0 — Build 10 Budget Circles:
//  ✅ REPLACED: Individual BudgetCardWithComparison list → DashboardBudgetCircles grid
//  ✅ ADDED: Alphabetical sorting of budget circles by display name
//  ✅ ADDED: Circle tap opens budget detail as sheet
//  ✅ KEPT: Monthly summary card, wrap-up banner, carryover, view history
//
//  CHANGES v3.3 — Monthly Budget Summary Card:
//  ✅ ADDED: Monthly budget summary card between month header and individual budget cards
//  ✅ ADDED: Shows Total Budgeted, Total Spent, Remaining with progress bar
//  ✅ ADDED: Progress bar color-coded green/orange/red matching individual card pattern
//  ✅ ADDED: Adaptive layout for accessibility sizes (VStack at large text)
//  ✅ ADDED: VoiceOver summary element with spoken currency totals
//  ✅ ADDED: Works across Business, Personal, and All finance modes
//
//  CHANGES v3.2:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (person emoji)
//
//  CHANGES v3.1 - Dynamic Type Verification:
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for adaptive layout detection
//  ✅ ADDED: isAccessibilitySize computed property for layout switching
//  ✅ FIXED: Finance mode picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Content type picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty budgets title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty budgets description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Create Budget" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Wrap-up banner title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Wrap-up banner budget stats text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Wrap-up banner carryover text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Wrap-up banner button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Carryover banner amount text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Carryover banner description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Month header title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: No budgets this month title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: No budgets this month description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Copy from" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: View history button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Add Recurring" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison budget name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison "Spent" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison spent amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison "Budget" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison budget amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison "Remaining" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison remaining amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BudgetCardWithComparison comparison text missing lineLimit + minimumScaleFactor
//  ✅ ADDED: Adaptive layout for BudgetCardWithComparison amounts row at accessibility sizes
//  ✅ NOTE: ContentUnavailableView empty recurring title and description scale automatically (system component)
//
//  CHANGES v3.0:
//  ✅ Custom SwiftUI empty state illustrations
//
//  CHANGES v2.2:
//  ✅ Added VoiceOver labels to BudgetCardWithComparison
//  ✅ Added accessibility to finance mode and content pickers
//  ✅ Added accessibility to wrap-up and carryover banners
//  ✅ Added accessibility to empty states
//  ✅ Added accessibility hints to all interactive elements
//  ✅ Added header traits to section headers

import SwiftUI
import FLODesignSystem
import SwiftData

struct BudgetListView: View {
    @Query(sort: \Budget.month, order: .reverse) private var allBudgets: [Budget]
    @Query(sort: \RecurringTransaction.startDate, order: .reverse) private var allRecurring: [RecurringTransaction]
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businessProfiles: [BusinessProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var allTransactions: [Transaction] = []
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedBusinessProfile: BusinessProfile?
    @State private var financeMode: FinanceMode = .all
    @State private var selectedTab: ContentTab = .budgets
    @State private var showingCreateBudget = false
    @State private var showingAddRecurring = false
    @State private var showingBudgetHistory = false
    @State private var showingWrapUp = false  // v4.1: Wrap-up sheet
    @State private var wrapUpBannerDismissed = false
    @State private var viewAppeared = false
    @State private var selectedBudgetForDetail: Budget?  // Build 10: Circle tap navigation
    
    @AppStorage("lastWrapUpBannerDismissedMonth") private var lastDismissedMonth: String = ""
    
    private let calendar = Calendar.current
    
    // Dynamic Type detection
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    enum FinanceMode: String, CaseIterable {
        case business = "Business"
        case personal = "Personal"
        case all = "All"
    }
    
    enum ContentTab: String, CaseIterable {
        case budgets = "Budgets"
        case recurring = "Recurring"
    }
    
    // MARK: - Date Calculations
    
    private var currentMonthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }
    
    private var previousMonthStart: Date {
        calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? Date()
    }
    
    private var currentMonthName: String {
        DateFormatter.fullMonth.string(from: Date())
    }

    private var previousMonthName: String {
        DateFormatter.fullMonth.string(from: previousMonthStart)
    }
    
    private var dayOfMonth: Int {
        calendar.component(.day, from: Date())
    }
    
    private var shouldShowWrapUpBanner: Bool {
        guard dayOfMonth <= 7 else { return false }
        let currentMonthKey = formatMonthKey(currentMonthStart)
        guard lastDismissedMonth != currentMonthKey else { return false }
        return !previousMonthBudgets.isEmpty
    }
    
    private func formatMonthKey(_ date: Date) -> String {
        DateFormatter.yearMonth.string(from: date)
    }
    
    // MARK: - Filtered Data
    
    private var currentMonthBudgets: [Budget] {
        let filtered = allBudgets.filter { budget in
            calendar.isDate(budget.month, equalTo: currentMonthStart, toGranularity: .month)
        }
        return filterBudgets(filtered, by: financeMode)
    }
    
    private var previousMonthBudgets: [Budget] {
        let filtered = allBudgets.filter { budget in
            calendar.isDate(budget.month, equalTo: previousMonthStart, toGranularity: .month)
        }
        return filterBudgets(filtered, by: financeMode)
    }
    
    private var filteredRecurring: [RecurringTransaction] {
        filterRecurring(allRecurring, by: financeMode)
    }
    
    private func filterBudgets(_ budgets: [Budget], by mode: FinanceMode) -> [Budget] {
        var result: [Budget]
        switch mode {
        case .business:
            result = budgets.filter { $0.financeType == .business }
        case .personal:
            result = budgets.filter { $0.financeType == .personal }
        case .all:
            result = budgets
        }
        // v4.1: Per-business filtering
        if let profile = selectedBusinessProfile {
            result = result.filter { $0.businessProfile?.id == profile.id }
        }
        return result
    }
    
    private func filterRecurring(_ recurring: [RecurringTransaction], by mode: FinanceMode) -> [RecurringTransaction] {
        switch mode {
        case .business:
            return recurring.filter { $0.financeType == .business }
        case .personal:
            return recurring.filter { $0.financeType == .personal }
        case .all:
            return recurring
        }
    }
    
    // MARK: - Carryover & Wrap-up Calculations
    
    private var totalCarryover: Double {
        currentMonthBudgets
            .filter { $0.effectiveShouldCarryOver }
            .reduce(0) { $0 + $1.carryOver }
    }
    
    private var previousMonthStats: (underBudget: Int, total: Int) {
        var underBudget = 0
        let total = previousMonthBudgets.count
        
        for budget in previousMonthBudgets {
            let spent = calculateSpent(for: budget, in: previousMonthStart)
            if spent <= budget.totalAvailable {
                underBudget += 1
            }
        }
        
        return (underBudget, total)
    }

    private func calculateSpent(for budget: Budget, in monthStart: Date) -> Double {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        let relevantTransactions = allTransactions.filter { transaction in
            guard !transaction.isDeleted else { return false }
            guard !transaction.isIncome else { return false }
            guard transaction.financeType == budget.financeType else { return false }
            guard transaction.date >= monthStart && transaction.date <= monthEnd else { return false }

            if let budgetCategory = budget.category {
                return transaction.category?.id == budgetCategory.id
            }
            return true
        }

        return abs(relevantTransactions.reduce(0) { $0 + $1.amount })
    }

    // MARK: - Monthly Budget Totals (v3.3)

    /// Total budgeted amount across all current month budgets (filtered by finance mode)
    private var monthlyBudgetTotal: Double {
        currentMonthBudgets.reduce(0) { $0 + $1.totalAvailable }
    }

    /// Total spent across all current month budgets (filtered by finance mode)
    private var monthlySpentTotal: Double {
        currentMonthBudgets.reduce(0) { total, budget in
            total + calculateSpent(for: budget, in: currentMonthStart)
        }
    }

    /// Total committed (recurring) across all current month budgets
    private var monthlyCommittedTotal: Double {
        currentMonthBudgets.reduce(0) { total, budget in
            guard let category = budget.category else { return total }
            return total + BudgetRecurringService.shared.committedAmount(
                for: category, financeType: budget.financeType, from: allRecurring
            )
        }
    }

    /// Total discretionary spent (actual - committed)
    private var monthlyDiscretionaryTotal: Double {
        max(0, monthlySpentTotal - monthlyCommittedTotal)
    }

    /// Total remaining across all current month budgets
    private var monthlyRemainingTotal: Double {
        monthlyBudgetTotal - monthlySpentTotal
    }

    /// Overall spending progress (0.0 to 1.0, capped at 1.0)
    private var monthlyProgress: Double {
        guard monthlyBudgetTotal > 0 else { return 0 }
        return min(monthlySpentTotal / monthlyBudgetTotal, 1.0)
    }

    /// Progress bar color using the BudgetStatus tier system. Uses the
    /// cent-precise factory so the new onTarget tier fires only when we're
    /// actually at (not just near) 100 %.
    private var monthlyProgressColor: Color {
        BudgetStatus.from(spent: monthlySpentTotal, budget: monthlyBudgetTotal).color
    }

    /// Build 10: Budget items paired with spent amounts for circle grid, alphabetically sorted
    private var budgetCircleItems: [(budget: Budget, spent: Double)] {
        currentMonthBudgets
            .map { budget in
                (budget: budget, spent: calculateSpent(for: budget, in: currentMonthStart))
            }
            .sorted { $0.budget.displayName.localizedCaseInsensitiveCompare($1.budget.displayName) == .orderedAscending }
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                financeModeSegment
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : -10)

                businessProfileFilter

                contentTypeSegment
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : -10)
                
                mainContent
            }
            .navigationTitle(navigationTitle)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingCreateBudget) {
                createBudgetSheet
            }
            .sheet(isPresented: $showingAddRecurring) {
                addRecurringSheet
            }
            .sheet(isPresented: $showingBudgetHistory) {
                BudgetHistoryView(allBudgets: allBudgets, allTransactions: allTransactions)
            }
            // v4.1: Wrap-up sheet with per-budget paid/carryover controls
            .sheet(isPresented: $showingWrapUp) {
                BudgetWrapUpView(
                    budgets: previousMonthBudgets,
                    allTransactions: allTransactions,
                    monthStart: previousMonthStart,
                    monthName: previousMonthName
                )
            }
            // Build 10: Navigate to budget detail when circle tapped
            .sheet(item: $selectedBudgetForDetail) { budget in
                NavigationStack {
                    EditBudgetView(budget: budget)
                }
            }
            .onChange(of: financeMode) { oldValue, newValue in
                HapticService.play(.selection)
                if newValue != .business {
                    selectedBusinessProfile = nil
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                HapticService.play(.selection)
            }
            .task {
                loadTransactions()
            }
            .onDisappear {
                allTransactions = []
            }
            .onAppear {
                DispatchQueue.main.async {
                    withAnimation(FLOAnimation.standard) {
                        viewAppeared = true
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadTransactions() {
        let endOfCurrentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= previousMonthStart && $0.date < endOfCurrentMonth },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        do {
            allTransactions = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BudgetListView loadTransactions error: \(error)")
            #endif
        }
    }
    
    // MARK: - View Components
    
    private var financeModeSegment: some View {
        Picker("Finance Mode", selection: $financeMode) {
            ForEach(FinanceMode.allCases, id: \.self) { mode in
                Text(mode.rawValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top)
        .accessibilityLabel("Finance mode: \(financeMode.rawValue)")
        .accessibilityValue(financeMode.rawValue)
        .accessibilityHint("Select to filter by business, personal, or all")
    }
    
    @ViewBuilder
    private var businessProfileFilter: some View {
        if financeMode == .business && businessProfiles.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(FLOAnimation.quick) { selectedBusinessProfile = nil }
                        HapticService.play(.light)
                    } label: {
                        Text("All")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedBusinessProfile == nil ? Color.brandPrimary : Color.floSecondarySystemBackground)
                            .foregroundStyle(selectedBusinessProfile == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    ForEach(businessProfiles) { profile in
                        Button {
                            withAnimation(FLOAnimation.quick) { selectedBusinessProfile = profile }
                            HapticService.play(.light)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: profile.displayIcon)
                                    .font(.caption2)
                                Text(profile.businessName)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedBusinessProfile?.id == profile.id ? Color.brandPrimary : Color.floSecondarySystemBackground)
                            .foregroundStyle(selectedBusinessProfile?.id == profile.id ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }

    private var contentTypeSegment: some View {
        Picker("Content", selection: $selectedTab) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
        .accessibilityLabel("Content type: \(selectedTab.rawValue)")
        .accessibilityValue(selectedTab.rawValue)
        .accessibilityHint("Select to view budgets or recurring transactions")
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            if selectedTab == .budgets {
                budgetsContent
            } else {
                recurringContent
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: financeMode)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                HapticService.play(.medium)
                if selectedTab == .budgets {
                    showingCreateBudget = true
                } else {
                    showingAddRecurring = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityLabel(selectedTab == .budgets ? "Create new budget" : "Add recurring transaction")
            .accessibilityHint(selectedTab == .budgets ? "Double tap to create a new budget" : "Double tap to add a recurring transaction")
        }
    }
    
    @ViewBuilder
    private var createBudgetSheet: some View {
        CreateBudgetView(month: currentMonthStart)
    }
    
    @ViewBuilder
    private var addRecurringSheet: some View {
        AddRecurringView(preselectedFinanceType: preselectedType)
    }
    
    private var preselectedType: Transaction.FinanceType? {
        switch financeMode {
        case .business: return .business
        case .personal: return .personal
        case .all: return nil
        }
    }
    
    // MARK: - Navigation Title
    
    private var navigationTitle: String {
        let content = selectedTab == .budgets ? "Budgets" : "Recurring"
        
        switch financeMode {
        case .business:
            return "🏢 \(content)"
        case .personal:
            return "👤 \(content)"
        case .all:
            return content
        }
    }
    
    // MARK: - Budgets Content
    
    private var budgetsContent: some View {
        Group {
            if currentMonthBudgets.isEmpty && previousMonthBudgets.isEmpty {
                emptyBudgetsView
            } else {
                budgetsList
            }
        }
        .transition(.opacity)
    }
    
    private var emptyBudgetsView: some View {
        VStack(spacing: 16) {
            BudgetsIllustration()
            
            Text(emptyBudgetsTitle)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            
            Text(emptyBudgetsDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
            
            Button {
                HapticService.play(.medium)
                showingCreateBudget = true
            } label: {
                Text("Create Budget")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyBudgetsTitle). \(emptyBudgetsDescription)")
        .accessibilityHint("Double tap the Create Budget button to get started")
        .opacity(viewAppeared ? 1 : 0.001)
        .scaleEffect(viewAppeared ? 1 : 0.95)
        .animation(FLOAnimation.standard, value: viewAppeared)
    }
    
    private var budgetsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Wrap-up banner (first 7 days of month)
                if shouldShowWrapUpBanner {
                    wrapUpBanner
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                }
                
                // Carryover banner (if applicable)
                if totalCarryover > 0 && !shouldShowWrapUpBanner {
                    carryoverBanner
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                }
                
                // Month header
                monthHeader
                    .padding(.horizontal)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                // v3.3: Monthly budget summary card
                if !currentMonthBudgets.isEmpty {
                    monthBudgetSummaryCard
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 15)
                        .animation(FLOAnimation.standard.delay(0.17), value: viewAppeared)
                }

                // Build 10: Budget Circles Grid (replaces individual card list)
                if currentMonthBudgets.isEmpty {
                    noBudgetsThisMonth
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .scaleEffect(viewAppeared ? 1 : 0.95)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                } else {
                    DashboardBudgetCircles(
                        budgets: budgetCircleItems,
                        onTap: { budget in
                            selectedBudgetForDetail = budget
                        }
                    )
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.22), value: viewAppeared)
                }
                
                // View History button
                viewHistoryButton
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Wrap-up Banner
    
    private var wrapUpBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                Text("\(previousMonthName) Wrap-up")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button {
                    dismissWrapUpBanner()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss wrap-up banner")
                .accessibilityHint("Double tap to hide this summary")
            }
            
            let stats = previousMonthStats
            HStack(spacing: 4) {
                Image(systemName: stats.underBudget == stats.total ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(stats.underBudget == stats.total ? Color.incomeGreen : Color.orange)
                    .accessibilityHidden(true)
                
                Text("\(stats.underBudget) of \(stats.total) budgets under control")
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            
            if totalCarryover > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(Color.incomeGreen)
                        .accessibilityHidden(true)
                    
                    Text("\(totalCarryover.formatted(.currency(code: "USD"))) rolling into \(currentMonthName)")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            
            Button {
                HapticService.play(.light)
                showingWrapUp = true
            } label: {
                HStack {
                    Spacer()
                    Text("Review \(previousMonthName)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.right")
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityLabel("Review \(previousMonthName) budgets")
            .accessibilityHint("Double tap to mark paid and set carryover for each budget")
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(wrapUpBannerAccessibilityLabel)
    }
    
    private var wrapUpBannerAccessibilityLabel: String {
        let stats = previousMonthStats
        var label = "\(previousMonthName) Wrap-up. \(stats.underBudget) of \(stats.total) budgets under control."
        if totalCarryover > 0 {
            label += " \(totalCarryover.formatted(.currency(code: "USD"))) rolling into \(currentMonthName)."
        }
        return label
    }
    
    private func dismissWrapUpBanner() {
        HapticService.play(.light)
        
        withAnimation(FLOAnimation.quick) {
            lastDismissedMonth = formatMonthKey(currentMonthStart)
        }
    }
    
    // MARK: - Carryover Banner
    
    private var carryoverBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.incomeGreen)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalCarryover.formatted(.currency(code: "USD"))) rolled over")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text("From \(previousMonthName) envelope budgets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.incomeGreen.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(totalCarryover.formatted(.currency(code: "USD"))) rolled over from \(previousMonthName) envelope budgets")
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Text("\(currentMonthName) Budgets")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
        }
    }
    
    // MARK: - Monthly Budget Summary Card (v3.3)

    @State private var animatedMonthlyProgress: Double = 0

    private var monthBudgetSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)

                Text("\(currentMonthName) Budget Summary")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text("\(Int(monthlyProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(monthlyProgressColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 10)

                    Rectangle()
                        .fill(monthlyProgressColor)
                        .frame(width: geometry.size.width * animatedMonthlyProgress, height: 10)
                }
                .cornerRadius(5)
            }
            .frame(height: 10)
            .accessibilityHidden(true)

            // Amounts row — adaptive layout for accessibility sizes
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    summaryAmountsContent
                }
            } else {
                HStack {
                    summaryAmountsContent
                }
            }

            // Committed vs Discretionary toggle
            if monthlyCommittedTotal > 0 {
                Divider()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showCommittedBreakdown.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCommittedBreakdown ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                        Text("Committed: \(monthlyCommittedTotal.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2)
                        Text("Discretionary: \(monthlyDiscretionaryTotal.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if showCommittedBreakdown {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(currentMonthBudgets, id: \.id) { budget in
                            if let category = budget.category {
                                let items = BudgetRecurringService.shared.recurringForCategory(
                                    category, financeType: budget.financeType, from: allRecurring
                                )
                                if !items.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(budget.displayName)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        ForEach(items) { item in
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise.circle")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.brandPrimary)
                                                Text(item.name)
                                                    .font(.caption2)
                                                Spacer()
                                                Text(item.monthlyAmount.formatted(.currency(code: "USD")))
                                                    .font(.caption2.monospacedDigit())
                                                Text("/mo")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monthlySummaryAccessibilityLabel)
        .accessibilityAddTraits(.isSummaryElement)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedMonthlyProgress = monthlyProgress
            }
        }
        .onChange(of: monthlyProgress) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedMonthlyProgress = newValue
            }
        }
    }

    @State private var showCommittedBreakdown = false

    @ViewBuilder
    private var summaryAmountsContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Spent")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(monthlySpentTotal.formatted(.currency(code: "USD")))
                .floFinancialNumber()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }

        if !isAccessibilitySize {
            Spacer()
        }

        VStack(alignment: isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text("Budgeted")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(monthlyBudgetTotal.formatted(.currency(code: "USD")))
                .floFinancialNumber()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }

        if !isAccessibilitySize {
            Spacer()
        }

        VStack(alignment: isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text("Remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(monthlyRemainingTotal.formatted(.currency(code: "USD")))
                .floFinancialNumber()
                .foregroundStyle(monthlyRemainingTotal < 0 ? Color.expenseRed : Color.incomeGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
    }

    private var monthlySummaryAccessibilityLabel: String {
        let spent = AccessibilityFormatters.spokenCurrency(monthlySpentTotal)
        let budgeted = AccessibilityFormatters.spokenCurrency(monthlyBudgetTotal)
        let remaining = AccessibilityFormatters.spokenCurrency(monthlyRemainingTotal)
        var label = "Monthly budget summary. Spent \(spent) of \(budgeted) budgeted, \(remaining) remaining."
        if monthlyRemainingTotal < 0 {
            label += " Over budget."
        } else if monthlyProgress >= 0.8 {
            label += " Approaching budget limit."
        }
        return label
    }

    // MARK: - No Budgets This Month

    private var noBudgetsThisMonth: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: viewAppeared)
                .accessibilityHidden(true)
            
            Text("No budgets for \(currentMonthName) yet")
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            if !previousMonthBudgets.isEmpty {
                Text("Your \(previousMonthName) budgets can be copied over")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                
                Button {
                    copyPreviousMonthBudgets()
                } label: {
                    Label("Copy from \(previousMonthName)", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                .accessibilityHint("Double tap to copy all budgets from \(previousMonthName)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(noBudgetsAccessibilityLabel)
    }
    
    private var noBudgetsAccessibilityLabel: String {
        var label = "No budgets for \(currentMonthName) yet."
        if !previousMonthBudgets.isEmpty {
            label += " Your \(previousMonthName) budgets can be copied over."
        }
        return label
    }
    
    private func copyPreviousMonthBudgets() {
        HapticService.play(.medium)

        for previousBudget in previousMonthBudgets {
            let carryOver = previousBudget.effectiveShouldCarryOver ?
                calculateCarryOver(for: previousBudget) : 0

            let newBudget = Budget(
                month: currentMonthStart,
                planned: previousBudget.planned,
                carryOver: carryOver,
                category: previousBudget.category,
                budgetType: previousBudget.budgetType,
                financeType: previousBudget.financeType
            )
            // v4.1: Propagate persistent carryover preference (not monthly skip)
            newBudget.allowCarryOverOverride = previousBudget.allowCarryOverOverride

            modelContext.insert(newBudget)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            print("❌ Failed to copy budgets: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func calculateCarryOver(for budget: Budget) -> Double {
        let spent = calculateSpent(for: budget, in: previousMonthStart)
        let remaining = budget.totalAvailable - spent
        return max(remaining, 0)
    }
    
    // MARK: - View History Button
    
    private var viewHistoryButton: some View {
        Button {
            HapticService.play(.light)
            showingBudgetHistory = true
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .accessibilityHidden(true)
                Text("View Budget History")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
        }
        .accessibilityLabel("View Budget History")
        .accessibilityHint("Double tap to see past months' budgets")
    }
    
    // MARK: - Recurring Content
    
    private var recurringContent: some View {
        Group {
            if filteredRecurring.isEmpty {
                emptyRecurringView
            } else {
                recurringList
            }
        }
        .transition(.opacity)
    }
    
    private var emptyRecurringView: some View {
        ContentUnavailableView {
            Label(emptyRecurringTitle, systemImage: "arrow.clockwise")
                .symbolEffect(.bounce, value: viewAppeared)
        } description: {
            Text(emptyRecurringDescription)
        } actions: {
            Button {
                HapticService.play(.medium)
                showingAddRecurring = true
            } label: {
                Text("Add Recurring")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyRecurringTitle). \(emptyRecurringDescription)")
        .accessibilityHint("Double tap the Add Recurring button to get started")
        .opacity(viewAppeared ? 1 : 0.001)
        .scaleEffect(viewAppeared ? 1 : 0.95)
        .animation(FLOAnimation.standard, value: viewAppeared)
    }
    
    private var recurringList: some View {
        List {
            ForEach(filteredRecurring) { recurring in
                NavigationLink(destination: EditRecurringView(recurringTransaction: recurring)) {
                    RecurringRow(recurring: recurring)
                }
                .accessibilityHint("Double tap to edit this recurring transaction")
            }
            .onDelete(perform: deleteRecurring)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Empty State Messages
    
    private var emptyBudgetsTitle: String {
        switch financeMode {
        case .business: return "No Business Budgets"
        case .personal: return "No Personal Budgets"
        case .all: return "No Budgets Yet"
        }
    }
    
    private var emptyBudgetsDescription: String {
        switch financeMode {
        case .business: return "Create a business budget to track company spending by category"
        case .personal: return "Create a personal budget to track household spending by category"
        case .all: return "Create a budget to track your spending by category"
        }
    }
    
    private var emptyRecurringTitle: String {
        switch financeMode {
        case .business: return "No Business Recurring Transactions"
        case .personal: return "No Personal Recurring Transactions"
        case .all: return "No Recurring Transactions"
        }
    }
    
    private var emptyRecurringDescription: String {
        switch financeMode {
        case .business: return "Set up recurring business expenses like software subscriptions and office rent"
        case .personal: return "Set up recurring personal expenses like mortgage, utilities, and subscriptions"
        case .all: return "Set up recurring transactions for bills, subscriptions, and regular income"
        }
    }
    
    // MARK: - Actions
    
    private func deleteRecurring(at offsets: IndexSet) {
        HapticService.play(.medium)
        
        let recurringToDelete = offsets.map { filteredRecurring[$0] }
        recurringToDelete.forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
        }
    }
}

// MARK: - Budget Card With Comparison

struct BudgetCardWithComparison: View {
    let budget: Budget
    let currentMonthStart: Date
    let previousMonthStart: Date
    let previousMonthBudgets: [Budget]
    let allTransactions: [Transaction]
    let previousMonthName: String
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @State private var animatedProgress: Double = 0
    @State private var appeared = false
    
    private let calendar = Calendar.current
    
    // Dynamic Type detection
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    private var spent: Double {
        calculateSpent(for: budget, in: currentMonthStart)
    }
    
    private var remaining: Double {
        budget.totalAvailable - spent
    }
    
    private var progress: Double {
        guard budget.totalAvailable > 0 else { return 0 }
        return min(spent / budget.totalAvailable, 1.0)
    }
    
    private var previousBudget: Budget? {
        previousMonthBudgets.first { prev in
            prev.category?.id == budget.category?.id &&
            prev.financeType == budget.financeType
        }
    }
    
    private var previousSpent: Double? {
        guard let prev = previousBudget else { return nil }
        return calculateSpent(for: prev, in: previousMonthStart)
    }
    
    private var comparison: (text: String, isGood: Bool, icon: String)? {
        guard let prevSpent = previousSpent else { return nil }
        
        let difference = spent - prevSpent
        
        if abs(difference) < 1 {
            return ("Same as \(previousMonthName)", true, "arrow.right")
        } else if difference < 0 {
            let amount = abs(difference).formatted(.currency(code: "USD"))
            return ("\(amount) less than \(previousMonthName)", true, "arrow.down")
        } else {
            let amount = difference.formatted(.currency(code: "USD"))
            return ("\(amount) more than \(previousMonthName)", false, "arrow.up")
        }
    }

    private func calculateSpent(for budget: Budget, in monthStart: Date) -> Double {
        let calendar = Calendar.current
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        let relevantTransactions = allTransactions.filter { transaction in
            guard !transaction.isDeleted else { return false }
            guard !transaction.isIncome else { return false }
            guard transaction.financeType == budget.financeType else { return false }
            guard transaction.date >= monthStart && transaction.date <= monthEnd else { return false }

            if let budgetCategory = budget.category {
                return transaction.category?.id == budgetCategory.id
            }
            return true
        }

        return abs(relevantTransactions.reduce(0) { $0 + $1.amount })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                if let category = budget.category {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color(flowHex: category.colorHex))
                        .accessibilityHidden(true)
                }
                
                Text(budget.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                Text(budget.financeType == .business ? "🏢" : "👤")
                    .font(.caption)
                    .accessibilityLabel(budget.financeType == .business ? "Business" : "Personal")
            }
            
            // Progress bar with animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 10)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * animatedProgress, height: 10)
                }
                .cornerRadius(5)
            }
            .frame(height: 10)
            .accessibilityHidden(true)
            
            // Amounts row - adaptive layout
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    amountsRowContent
                }
            } else {
                HStack {
                    amountsRowContent
                }
            }
            
            // Comparison line with animation
            if let comp = comparison {
                HStack(spacing: 4) {
                    Image(systemName: comp.icon)
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text(comp.text)
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(comp.isGood ? Color.incomeGreen : Color.orange)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0.001)
                .animation(.easeIn.delay(0.3), value: appeared)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(budgetAccessibilityLabel)
        .accessibilityHint("Double tap to edit this budget")
        .onAppear {
            appeared = true
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
    
    // MARK: - Amounts Row Content
    
    @ViewBuilder
    private var amountsRowContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Spent")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(spent.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
        
        if !isAccessibilitySize {
            Spacer()
        }
        
        VStack(alignment: isAccessibilitySize ? .leading : .center, spacing: 2) {
            Text("Budget")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(budget.totalAvailable.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        
        if !isAccessibilitySize {
            Spacer()
        }
        
        VStack(alignment: isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text("Remaining")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(remaining.formatted(.currency(code: "USD")))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(remaining < 0 ? Color.expenseRed : Color.incomeGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
        }
    }
    
    // MARK: - Accessibility
    
    private var budgetAccessibilityLabel: String {
        var label = "\(budget.displayName) budget"
        label += ", \(budget.financeType == .business ? "Business" : "Personal")"
        label += ". Spent \(spent.formatted(.currency(code: "USD")))"
        label += " of \(budget.totalAvailable.formatted(.currency(code: "USD")))"
        label += ", \(remaining.formatted(.currency(code: "USD"))) remaining"
        
        if remaining < 0 {
            label += ", over budget"
        } else if progress >= 0.8 {
            label += ", approaching limit"
        }
        
        if let comp = comparison {
            label += ". \(comp.text)"
        }
        
        return label
    }
    
    private var progressColor: Color {
        // Use the real spent/budget values (not the animation-clamped percentage)
        // so the onTarget tier never gets stuck during the ring's growth animation.
        BudgetStatus.from(spent: spent, budget: budget.totalAvailable).color
    }
}

// MARK: - Preview

#Preview("With Budgets") {
    BudgetListView()
        .modelContainer(for: [Budget.self, RecurringTransaction.self, Transaction.self, Category.self])
}

#Preview("Empty State") {
    BudgetListView()
        .modelContainer(for: [Budget.self, RecurringTransaction.self])
}
