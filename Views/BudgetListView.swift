//  BudgetListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1:
//  ✅ Haptic feedback on all segment/picker changes
//  ✅ Haptic feedback on add, delete, copy actions
//  ✅ Card entrance animations with staggered delays
//  ✅ Progress bar animations with spring physics
//  ✅ Banner dismiss animation
//  ✅ Empty state icon animation
//  ✅ Prepared haptic generators for responsiveness
//
//  PREVIOUS CHANGES (v2.0):
//  - Current month focus with inline comparisons
//  - Smart wrap-up banner (first 7 days of month)
//  - Separate Budget History view for deep dive

import SwiftUI
import SwiftData

struct BudgetListView: View {
    @Query(sort: \Budget.month, order: .reverse) private var allBudgets: [Budget]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \RecurringTransaction.startDate, order: .reverse) private var allRecurring: [RecurringTransaction]
    @Environment(\.modelContext) private var modelContext
    
    @State private var financeMode: FinanceMode = .all
    @State private var selectedTab: ContentTab = .budgets
    @State private var showingCreateBudget = false
    @State private var showingAddRecurring = false
    @State private var showingBudgetHistory = false
    @State private var wrapUpBannerDismissed = false
    @State private var viewAppeared = false
    
    @AppStorage("lastWrapUpBannerDismissedMonth") private var lastDismissedMonth: String = ""
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private let calendar = Calendar.current
    
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }
    
    private var previousMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: previousMonthStart)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
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
        switch mode {
        case .business:
            return budgets.filter { $0.financeType == .business }
        case .personal:
            return budgets.filter { $0.financeType == .personal }
        case .all:
            return budgets
        }
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
            .filter { $0.budgetType == .envelope }
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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                financeModeSegment
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : -10)
                
                contentTypeSegment
                    .opacity(viewAppeared ? 1 : 0)
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
            .onChange(of: financeMode) { oldValue, newValue in
                selectionFeedback.selectionChanged()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                selectionFeedback.selectionChanged()
            }
            .onAppear {
                prepareHaptics()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - View Components
    
    private var financeModeSegment: some View {
        Picker("Finance Mode", selection: $financeMode) {
            ForEach(FinanceMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var contentTypeSegment: some View {
        Picker("Content", selection: $selectedTab) {
            ForEach(ContentTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding()
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
                impactMedium.impactOccurred()
                if selectedTab == .budgets {
                    showingCreateBudget = true
                } else {
                    showingAddRecurring = true
                }
            } label: {
                Image(systemName: "plus.circle.fill")
            }
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
        ContentUnavailableView {
            Label(emptyBudgetsTitle, systemImage: "chart.bar.fill")
                .symbolEffect(.bounce, value: viewAppeared)
        } description: {
            Text(emptyBudgetsDescription)
        } actions: {
            Button {
                impactMedium.impactOccurred()
                showingCreateBudget = true
            } label: {
                Text("Create Budget")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
        }
        .opacity(viewAppeared ? 1 : 0)
        .scaleEffect(viewAppeared ? 1 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewAppeared)
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
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                }
                
                // Month header
                monthHeader
                    .padding(.horizontal)
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                
                // Current month budgets
                if currentMonthBudgets.isEmpty {
                    noBudgetsThisMonth
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0)
                        .scaleEffect(viewAppeared ? 1 : 0.95)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                } else {
                    ForEach(Array(currentMonthBudgets.enumerated()), id: \.element.id) { index, budget in
                        NavigationLink(destination: EditBudgetView(budget: budget)) {
                            BudgetCardWithComparison(
                                budget: budget,
                                currentMonthStart: currentMonthStart,
                                previousMonthStart: previousMonthStart,
                                previousMonthBudgets: previousMonthBudgets,
                                allTransactions: allTransactions,
                                previousMonthName: previousMonthName
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0)
                        .offset(y: viewAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                            .delay(0.2 + Double(index) * 0.05),
                            value: viewAppeared
                        )
                    }
                }
                
                // View History button
                viewHistoryButton
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: viewAppeared)
                
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
                
                Text("\(previousMonthName) Wrap-up")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismissWrapUpBanner()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss wrap-up banner")
            }
            
            let stats = previousMonthStats
            HStack(spacing: 4) {
                Image(systemName: stats.underBudget == stats.total ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(stats.underBudget == stats.total ? Color.incomeGreen : Color.orange)
                
                Text("\(stats.underBudget) of \(stats.total) budgets under control")
                    .font(.subheadline)
            }
            
            if totalCarryover > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(Color.incomeGreen)
                    
                    Text("\(totalCarryover.formatted(.currency(code: "USD"))) rolling into \(currentMonthName)")
                        .font(.subheadline)
                }
            }
            
            Button {
                impactLight.impactOccurred()
                showingBudgetHistory = true
            } label: {
                HStack {
                    Spacer()
                    Text("View \(previousMonthName)")
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.brandPrimary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func dismissWrapUpBanner() {
        impactLight.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            lastDismissedMonth = formatMonthKey(currentMonthStart)
        }
    }
    
    // MARK: - Carryover Banner
    
    private var carryoverBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.incomeGreen)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(totalCarryover.formatted(.currency(code: "USD"))) rolled over")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("From \(previousMonthName) envelope budgets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.incomeGreen.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Month Header
    
    private var monthHeader: some View {
        HStack {
            Text("\(currentMonthName) Budgets")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    // MARK: - No Budgets This Month
    
    private var noBudgetsThisMonth: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: viewAppeared)
            
            Text("No budgets for \(currentMonthName) yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if !previousMonthBudgets.isEmpty {
                Text("Your \(previousMonthName) budgets can be copied over")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    copyPreviousMonthBudgets()
                } label: {
                    Label("Copy from \(previousMonthName)", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func copyPreviousMonthBudgets() {
        impactMedium.impactOccurred()
        
        for previousBudget in previousMonthBudgets {
            let carryOver = previousBudget.budgetType == .envelope ?
                calculateCarryOver(for: previousBudget) : 0
            
            let newBudget = Budget(
                month: currentMonthStart,
                planned: previousBudget.planned,
                carryOver: carryOver,
                category: previousBudget.category,
                budgetType: previousBudget.budgetType,
                financeType: previousBudget.financeType
            )
            
            modelContext.insert(newBudget)
        }
        
        do {
            try modelContext.save()
            notificationFeedback.notificationOccurred(.success)
        } catch {
            print("❌ Failed to copy budgets: \(error)")
            notificationFeedback.notificationOccurred(.error)
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
            impactLight.impactOccurred()
            showingBudgetHistory = true
        } label: {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                Text("View Budget History")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
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
                impactMedium.impactOccurred()
                showingAddRecurring = true
            } label: {
                Text("Add Recurring")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
        }
        .opacity(viewAppeared ? 1 : 0)
        .scaleEffect(viewAppeared ? 1 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewAppeared)
    }
    
    private var recurringList: some View {
        List {
            ForEach(filteredRecurring) { recurring in
                NavigationLink(destination: EditRecurringView(recurringTransaction: recurring)) {
                    RecurringRow(recurring: recurring)
                }
            }
            .onDelete(perform: deleteRecurring)
        }
        .listStyle(.plain)
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
        impactMedium.impactOccurred()
        
        let recurringToDelete = offsets.map { filteredRecurring[$0] }
        recurringToDelete.forEach { modelContext.delete($0) }
        
        do {
            try modelContext.save()
            notificationFeedback.notificationOccurred(.success)
        } catch {
            notificationFeedback.notificationOccurred(.error)
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
    
    @State private var animatedProgress: Double = 0
    @State private var appeared = false
    
    private let calendar = Calendar.current
    
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
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart
        
        let relevantTransactions = allTransactions.filter { transaction in
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
                }
                
                Text(budget.displayName)
                    .font(.headline)
                
                Spacer()
                
                Text(budget.financeType == .business ? "🏢" : "👤")
                    .font(.caption)
            }
            
            // Progress bar with animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 10)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * animatedProgress, height: 10)
                }
                .cornerRadius(5)
            }
            .frame(height: 10)
            
            // Amounts row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(spent.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Budget")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(budget.totalAvailable.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(remaining.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(remaining < 0 ? Color.expenseRed : Color.incomeGreen)
                        .contentTransition(.numericText())
                }
            }
            
            // Comparison line with animation
            if let comp = comparison {
                HStack(spacing: 4) {
                    Image(systemName: comp.icon)
                        .font(.caption2)
                    Text(comp.text)
                        .font(.caption)
                }
                .foregroundStyle(comp.isGood ? Color.incomeGreen : Color.orange)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .animation(.easeIn.delay(0.3), value: appeared)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
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
    
    private var progressColor: Color {
        if animatedProgress >= 1.0 {
            return .expenseRed
        } else if animatedProgress >= 0.8 {
            return .orange
        } else {
            return .incomeGreen
        }
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
