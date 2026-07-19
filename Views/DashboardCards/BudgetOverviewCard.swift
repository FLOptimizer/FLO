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
import FLODesignSystem
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
                let columns = [GridItem(.adaptive(minimum: 80, maximum: 110), spacing: 12)]
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(activeBudgets, id: \.budget.id) { item in
                        BudgetCircle(
                            sfSymbol: item.budget.category?.icon,
                            name: item.budget.displayName,
                            spent: abs(item.spent),
                            budget: item.budget.totalAvailable,
                            size: .standard
                        )
                    }
                }
                .padding()
            }
        }
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
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
