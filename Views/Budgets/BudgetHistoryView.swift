//  BudgetHistoryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Month navigator selected month text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card "Month Summary" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card "Total Budget" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card total budget amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card "Total Spent" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card total spent amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Summary card performance indicator text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty history view description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: No budgets for month message missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard budget name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard "Spent" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard spent amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard "Budget" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard budget amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard "Saved/Over" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: HistoryBudgetCard remaining amount missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.2:
//  ✅ Screen change announcement on appear
//  ✅ Month navigator buttons get accessibility labels
//  ✅ Summary card icon hidden, performance indicator combined
//  ✅ HistoryBudgetCard status icon hidden, progress bar hidden, card combined
//  ✅ Fixed garbled UTF-8 emoji
//
//  CHANGES v1.1:
//  ✅ Enhanced month navigation haptics
//  ✅ Finance mode filter haptics
//  ✅ Summary card entrance animation
//  ✅ Budget card staggered animations
//  ✅ Progress bar animated fill
//  ✅ Empty state icon animation
//
//  PREVIOUS (v1.0):
//  - Basic budget history with month-by-month breakdown

import SwiftUI
import FLODesignSystem
import SwiftData

struct BudgetHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let allBudgets: [Budget]
    let allTransactions: [Transaction]
    
    @State private var selectedMonth: Date
    @State private var financeMode: FinanceMode = .all
    @State private var viewAppeared = false
    @State private var cardsAppeared = false
    
    // Haptic Generators
                
    private let calendar = Calendar.current
    
    enum FinanceMode: String, CaseIterable {
        case business = "Business"
        case personal = "Personal"
        case all = "All"
    }
    
    init(allBudgets: [Budget], allTransactions: [Transaction]) {
        self.allBudgets = allBudgets
        self.allTransactions = allTransactions
        
        let calendar = Calendar.current
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? Date()
        _selectedMonth = State(initialValue: previousMonth)
    }
    
    // MARK: - Available Months
    
    private var availableMonths: [Date] {
        let uniqueMonths = Set(allBudgets.map { budget -> Date in
            let components = calendar.dateComponents([.year, .month], from: budget.month)
            return calendar.date(from: components) ?? budget.month
        })
        return uniqueMonths.sorted(by: >)
    }
    
    // MARK: - Filtered Budgets
    
    private var budgetsForSelectedMonth: [Budget] {
        let filtered = allBudgets.filter { budget in
            calendar.isDate(budget.month, equalTo: selectedMonth, toGranularity: .month)
        }
        
        switch financeMode {
        case .business:
            return filtered.filter { $0.financeType == .business }
        case .personal:
            return filtered.filter { $0.financeType == .personal }
        case .all:
            return filtered
        }
    }
    
    // MARK: - Month Navigation
    
    private var canGoBack: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: selectedMonth) else { return false }
        return currentIndex < availableMonths.count - 1
    }
    
    private var canGoForward: Bool {
        guard let currentIndex = availableMonths.firstIndex(of: selectedMonth) else { return false }
        return currentIndex > 0
    }
    
    private func goToPreviousMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: selectedMonth),
              currentIndex < availableMonths.count - 1 else { return }
        
        HapticService.play(.light)
        
        // Reset card animations for new month
        cardsAppeared = false
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMonth = availableMonths[currentIndex + 1]
        }
        
        // Trigger card animations after month change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(FLOAnimation.standard) {
                cardsAppeared = true
            }
        }
    }
    
    private func goToNextMonth() {
        guard let currentIndex = availableMonths.firstIndex(of: selectedMonth),
              currentIndex > 0 else { return }
        
        HapticService.play(.light)
        
        // Reset card animations for new month
        cardsAppeared = false
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMonth = availableMonths[currentIndex - 1]
        }
        
        // Trigger card animations after month change
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(FLOAnimation.standard) {
                cardsAppeared = true
            }
        }
    }
    
    // MARK: - Calculations
    
    private func calculateSpent(for budget: Budget) -> Double {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: budget.month)) ?? budget.month
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? budget.month
        
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
    
    private var monthSummary: (totalBudget: Double, totalSpent: Double, underBudget: Int, total: Int) {
        var totalBudget: Double = 0
        var totalSpent: Double = 0
        var underBudget = 0
        
        for budget in budgetsForSelectedMonth {
            let spent = calculateSpent(for: budget)
            totalBudget += budget.totalAvailable
            totalSpent += spent
            
            if spent <= budget.totalAvailable {
                underBudget += 1
            }
        }
        
        return (totalBudget, totalSpent, underBudget, budgetsForSelectedMonth.count)
    }
    
    // MARK: - Formatting
    
    private var selectedMonthName: String {
        DateFormatter.monthYear.string(from: selectedMonth)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Finance mode filter
                Picker("Finance Mode", selection: $financeMode) {
                    ForEach(FinanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: financeMode) { _, _ in
                    HapticService.play(.selection)
                    
                    // Re-trigger card animations
                    cardsAppeared = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(FLOAnimation.standard) {
                            cardsAppeared = true
                        }
                    }
                }
                
                if availableMonths.isEmpty {
                    emptyHistoryView
                } else {
                    // Month navigator
                    monthNavigator
                        .padding(.horizontal)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : -10)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Content
                    historyScrollContent
                }
            }
            .navigationTitle("Budget History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(FLOAnimation.standard) {
                        cardsAppeared = true
                    }
                }
                AccessibilityAnnouncement.screenChanged("Budget history")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - History Scroll Content

    private var historyScrollContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary card
                summaryCard
                    .padding(.horizontal)
                    .opacity(cardsAppeared ? 1 : 0.001)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.15), value: cardsAppeared)

                // Budget cards
                if budgetsForSelectedMonth.isEmpty {
                    noBudgetsForMonth
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .animation(FLOAnimation.standard.delay(0.2), value: cardsAppeared)
                } else {
                    ForEach(Array(budgetsForSelectedMonth.enumerated()), id: \.element.id) { index, budget in
                        HistoryBudgetCard(
                            budget: budget,
                            spent: calculateSpent(for: budget),
                            animateProgress: cardsAppeared
                        )
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(x: cardsAppeared ? 0 : 30)
                        .animation(
                            FLOAnimation.standard
                            .delay(0.2 + Double(index) * 0.05),
                            value: cardsAppeared
                        )
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Month Navigator
    
    private var monthNavigator: some View {
        HStack {
            Button {
                goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoBack ? Color.brandPrimary : Color.secondary)
            }
            .disabled(!canGoBack)
            .accessibilityLabel("Previous month")
            
            Spacer()
            
            Text(selectedMonthName)
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            
            Spacer()
            
            Button {
                goToNextMonth()
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canGoForward ? Color.brandPrimary : Color.secondary)
            }
            .disabled(!canGoForward)
            .accessibilityLabel("Next month")
        }
    }
    
    private var summaryCard: some View {
        let summary = monthSummary
        
        return VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .symbolEffect(.bounce, value: cardsAppeared)
                    .accessibilityHidden(true)
                
                Text("Month Summary")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                // Total Budget
                VStack(spacing: 4) {
                    Text("Total Budget")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Text(summary.totalBudget.formatted(.currency(code: "USD")))
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                }
                
                Divider()
                    .frame(height: 40)
                
                // Total Spent
                VStack(spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Text(summary.totalSpent.formatted(.currency(code: "USD")))
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(summary.totalSpent > summary.totalBudget ? Color.expenseRed : Color.primary)
                        .contentTransition(.numericText())
                }
            }
            
            // Performance indicator
            HStack(spacing: 8) {
                Image(systemName: summary.underBudget == summary.total ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(summary.underBudget == summary.total ? Color.incomeGreen : Color.orange)
                    .symbolEffect(.bounce, value: cardsAppeared)
                
                Text("\(summary.underBudget) of \(summary.total) budgets stayed under limit")
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Empty States
    
    private var emptyHistoryView: some View {
        ContentUnavailableView {
            Label("No Budget History", systemImage: "clock.arrow.circlepath")
                .symbolEffect(.bounce, value: viewAppeared)
        } description: {
            Text("Your past budgets will appear here")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var noBudgetsForMonth: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: cardsAppeared)
            
            Text("No \(financeMode == .all ? "" : financeMode.rawValue.lowercased() + " ")budgets for this month")
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
    }
}

// MARK: - History Budget Card

struct HistoryBudgetCard: View {
    let budget: Budget
    let spent: Double
    let animateProgress: Bool
    
    @State private var progressAnimated = false
    
    private var remaining: Double {
        budget.totalAvailable - spent
    }
    
    private var progress: Double {
        guard budget.totalAvailable > 0 else { return 0 }
        return min(spent / budget.totalAvailable, 1.0)
    }
    
    private var progressColor: Color {
        if progress >= 1.0 {
            return .expenseRed
        } else if progress >= 0.8 {
            return .orange
        } else {
            return .incomeGreen
        }
    }
    
    private var statusIcon: String {
        if remaining >= 0 {
            return "checkmark.circle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }
    
    private var statusColor: Color {
        remaining >= 0 ? .incomeGreen : .expenseRed
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
                
                Text(budget.financeType == .business ? "💼" : "👤")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * (progressAnimated ? progress : 0), height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progressAnimated)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            
            // Amounts
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spent")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Text(spent.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("Budget")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Text(budget.totalAvailable.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(remaining >= 0 ? "Saved" : "Over")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Text(abs(remaining).formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(statusColor)
                        .contentTransition(.numericText())
                }
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .shadow(radius: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(budget.displayName), \(budget.financeType == .business ? "business" : "personal"), spent \(spent.formatted(.currency(code: "USD"))) of \(budget.totalAvailable.formatted(.currency(code: "USD"))), \(remaining >= 0 ? "under budget by \(abs(remaining).formatted(.currency(code: "USD")))" : "over budget by \(abs(remaining).formatted(.currency(code: "USD")))")")
        .onChange(of: animateProgress) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    progressAnimated = true
                }
            } else {
                progressAnimated = false
            }
        }
        .onAppear {
            if animateProgress {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    progressAnimated = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With History") {
    let container = try! ModelContainer(
        for: Budget.self, Transaction.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let category = Category(name: "Dining Out", icon: "fork.knife", colorHex: "F59E0B", isIncome: false)
    context.insert(category)
    
    let calendar = Calendar.current
    let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
    let lastMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
    
    let budget1 = Budget(month: lastMonth, planned: 300, category: category, financeType: .personal)
    let budget2 = Budget(month: currentMonth, planned: 300, category: category, financeType: .personal)
    
    context.insert(budget1)
    context.insert(budget2)
    
    return BudgetHistoryView(allBudgets: [budget1, budget2], allTransactions: [])
}

#Preview("Empty") {
    BudgetHistoryView(allBudgets: [], allTransactions: [])
}
