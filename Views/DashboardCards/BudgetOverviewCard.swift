//  BudgetOverviewCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 — Transfer Exclusion Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 — Transfer Exclusion (Bulletproof):
//  ✅ FIXED: activeBudgets spent calculation excludes isTransfer transactions
//  ✅ FIXED: @Query predicate (with category) adds isTransfer == false at query level
//  ✅ FIXED: @Query predicate (no category) adds isTransfer == false at query level
//  ✅ Transfers now excluded at 3 layers: DashboardView, @Query, and computed property
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: amountColumn currency text missing lineLimit + minimumScaleFactor
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for layout adaptation
//  ✅ ADDED: Spent/Budget/Remaining row switches to VStack at AX sizes
//  ✅ ADDED: lineLimit + minimumScaleFactor on amount labels
//
//  CHANGES v1.1 - Accessibility Audit:
//  ✅ Header chart icon hidden from VoiceOver
//  ✅ Header text marked with isHeader trait
//  ✅ Empty state decorative icon hidden
//  ✅ Progress bar accessible with value trait
//  ✅ Finance type emoji hidden (info in label)
//  ✅ Amount columns use spoken currency
//
//  FEATURES:
//  ✅ Budget overview with progress bars
//  ✅ Animated progress bar fill
//  ✅ Color-coded progress (green → orange → red)
//  ✅ FLOAnimation presets
//  ✅ Full accessibility support
//

import SwiftUI
import SwiftData

struct BudgetOverviewCard: View {
    let budgets: [Budget]
    let transactions: [Transaction]
    
    private var activeBudgets: [(budget: Budget, spent: Double)] {
        budgets.compactMap { budget in
            let categoryName = budget.category?.name
            let spent = transactions
                .filter { !$0.isIncome && !$0.isTransfer }
                .filter { $0.category?.name == categoryName }
                .reduce(0) { $0 + $1.amount }
            
            return (budget, spent)
        }
        .prefix(5)
        .map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                FLOBrandedIcon(icon: .budgets, size: .medium, color: .brandPrimary)
                
                Text("Budget Overview")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button {
                    HapticService.play(.light)
                    NavigationService.shared.selectedTab = .budgets
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View all budgets")
            }
            .padding()
            
            Divider()
            
            // Budget Items
            if activeBudgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.pie")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    
                    Text("No budgets yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    NavigationLink {
                        CreateBudgetView(month: Date())
                    } label: {
                        Text("Create Budget")
                            .font(.subheadline)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activeBudgets.enumerated()), id: \.element.budget.id) { index, item in
                        BudgetRow(budget: item.budget, animationDelay: Double(index) * 0.05)
                        
                        if item.budget.id != activeBudgets.last?.budget.id {
                            Divider()
                                .padding(.leading)
                        }
                    }
                }
            }
        }
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
    }
}

// MARK: - Budget Row

struct BudgetRow: View {
    let budget: Budget
    var animationDelay: Double = 0
    
    // v1.2: Dynamic Type awareness
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    @Query private var allTransactions: [Transaction]
    @State private var animatedProgress: Double = 0
    
    /// v1.2: Whether current Dynamic Type size is an accessibility size
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    init(budget: Budget, animationDelay: Double = 0) {
        self.budget = budget
        self.animationDelay = animationDelay
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: budget.month)
        ) ?? budget.month
        let endOfMonth = calendar.date(
            byAdding: DateComponents(month: 1, day: -1),
            to: startOfMonth
        ) ?? budget.month
        
        // v1.3: Both predicates exclude transfers at the query level
        if let categoryName = budget.category?.name {
            let predicate = #Predicate<Transaction> { transaction in
                !transaction.isIncome &&
                transaction.isTransfer == false &&
                transaction.date >= startOfMonth &&
                transaction.date <= endOfMonth &&
                transaction.category?.name == categoryName
            }
            _allTransactions = Query(filter: predicate, sort: \.date)
        } else {
            let predicate = #Predicate<Transaction> { transaction in
                !transaction.isIncome &&
                transaction.isTransfer == false &&
                transaction.date >= startOfMonth &&
                transaction.date <= endOfMonth
            }
            _allTransactions = Query(filter: predicate, sort: \.date)
        }
    }
    
    private var transactions: [Transaction] {
        allTransactions.filter { $0.financeType == budget.financeType }
    }
    
    private var spent: Double {
        abs(transactions.reduce(0) { $0 + $1.amount })
    }
    
    private var remaining: Double {
        budget.totalAvailable - spent
    }
    
    private var progress: Double {
        guard budget.totalAvailable > 0 else { return 0 }
        return min(spent / budget.totalAvailable, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            budgetHeader
            progressBar
            amountsRow
        }
        .padding(.vertical, 4)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation(FLOAnimation.gentle.delay(animationDelay)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(FLOAnimation.standard) {
                animatedProgress = newValue
            }
        }
    }
    
    private var budgetHeader: some View {
        HStack {
            Text(budget.displayName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            Text(budget.financeType == .business ? "💼" : "👤")
                .font(.caption)
                .accessibilityHidden(true)
        }
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 8)
                
                Rectangle()
                    .fill(progressColor)
                    .frame(width: geometry.size.width * animatedProgress, height: 8)
            }
            .cornerRadius(4)
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
    
    // v1.2: Adaptive amounts row — switches to vertical at accessibility sizes
    private var amountsRow: some View {
        Group {
            if isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    amountColumn(title: "Spent", amount: spent)
                    amountColumn(title: "Budget", amount: budget.totalAvailable)
                    amountColumn(title: "Remaining", amount: remaining, color: remaining < 0 ? .expenseRed : .incomeGreen)
                }
            } else {
                HStack {
                    amountColumn(title: "Spent", amount: spent)
                    Spacer()
                    amountColumn(title: "Budget", amount: budget.totalAvailable)
                    Spacer()
                    amountColumn(title: "Remaining", amount: remaining, color: remaining < 0 ? .expenseRed : .incomeGreen)
                }
            }
        }
    }
    
    // v1.2: Added lineLimit + minimumScaleFactor to currency text
    private func amountColumn(title: String, amount: Double, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(amount.formatted(.currency(code: "USD")))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color ?? Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
    
    private var accessibilityLabel: String {
        let percent = Int(progress * 100)
        let typeLabel = budget.financeType == .business ? "Business" : "Personal"
        return "\(budget.displayName), \(typeLabel): Spent \(spent.formatted(.currency(code: "USD"))) of \(budget.totalAvailable.formatted(.currency(code: "USD"))), \(percent) percent used. \(remaining >= 0 ? remaining.formatted(.currency(code: "USD")) + " remaining" : "Over budget by " + abs(remaining).formatted(.currency(code: "USD")))"
    }
}

// MARK: - Preview

#Preview("With Budgets") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, Category.self, Transaction.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let groceries = Category(name: "Groceries", icon: "cart", colorHex: "22C55E", isIncome: false)
    context.insert(groceries)
    
    let budget = Budget(month: Date(), planned: 500, category: groceries, financeType: .personal)
    context.insert(budget)
    
    return BudgetOverviewCard(budgets: [budget], transactions: [])
        .padding()
        .modelContainer(container)
}

#Preview("Empty State") {
    BudgetOverviewCard(budgets: [], transactions: [])
        .padding()
}

#Preview("Accessibility Size") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Budget.self, Category.self, Transaction.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let groceries = Category(name: "Groceries", icon: "cart", colorHex: "22C55E", isIncome: false)
    context.insert(groceries)
    
    let budget = Budget(month: Date(), planned: 500, category: groceries, financeType: .personal)
    context.insert(budget)
    
    return BudgetOverviewCard(budgets: [budget], transactions: [])
        .padding()
        .modelContainer(container)
        .dynamicTypeSize(.accessibility5)
}
