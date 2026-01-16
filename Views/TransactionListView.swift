//  TransactionListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.3:
//  ✅ Haptic feedback on filter changes
//  ✅ Haptic feedback on swipe actions
//  ✅ Haptic on add transaction button
//  ✅ Pull-to-refresh with haptic
//  ✅ List entrance animations
//  ✅ Filter badge animations
//  ✅ Empty state icon animation
//  ✅ Prepared haptic generators for responsiveness
//
//  PREVIOUS FIXES:
//  - Fixed Color(hex:) to Color(flowHex:)
//  - Fixed compiler timeout by extracting categoryIcon
//  - Uses centralized Color.brandPrimary

import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]
    
    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var selectedFinanceType: Transaction.FinanceType?
    @State private var showingAddTransaction = false
    @State private var transactionToEdit: Transaction?
    @State private var isRefreshing = false
    @State private var listAppeared = false
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredTransactions.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        impactMedium.impactOccurred()
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        filterMenu
                    } label: {
                        Label("Filter", systemImage: filterIconName)
                            .foregroundStyle(hasActiveFilters ? Color.brandPrimary : .primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $transactionToEdit) { transaction in
                EditTransactionView(transaction: transaction)
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                selectionFeedback.selectionChanged()
            }
            .onChange(of: selectedFinanceType) { oldValue, newValue in
                selectionFeedback.selectionChanged()
            }
            .onAppear {
                prepareHaptics()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    listAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Transaction List

    @ViewBuilder
    private var transactionList: some View {
        List {
            if hasActiveFilters {
                Section {
                    activeFiltersView
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(Array(groupedTransactions.keys.sorted(by: >).enumerated()), id: \.element) { sectionIndex, date in
                Section {
                    ForEach(Array((groupedTransactions[date] ?? []).enumerated()), id: \.element.id) { rowIndex, transaction in
                        AnimatedRow(
                            transaction: transaction,
                            sectionIndex: sectionIndex,
                            rowIndex: rowIndex,
                            listAppeared: listAppeared,
                            onTap: { transaction in
                                impactLight.impactOccurred()
                                transactionToEdit = transaction
                            },
                            onDelete: { transaction in
                                impactHeavy.impactOccurred()
                                deleteTransaction(transaction)
                            },
                            onEdit: { transaction in
                                impactLight.impactOccurred()
                                transactionToEdit = transaction
                            }
                        )
                    }
                } header: {
                    sectionHeader(for: date)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refresh()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTransactions.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: hasActiveFilters)
    }

    private func refresh() async {
        impactLight.impactOccurred()
        isRefreshing = true
        
        // Small delay for visual feedback
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        isRefreshing = false
        notificationFeedback.notificationOccurred(.success)
    }

    private func sectionHeader(for date: Date) -> some View {
        Text(date, format: .dateTime.month(.wide).day().year())
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.brandPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private struct AnimatedRow: View {
        let transaction: Transaction
        let sectionIndex: Int
        let rowIndex: Int
        let listAppeared: Bool
        let onTap: (Transaction) -> Void
        let onDelete: (Transaction) -> Void
        let onEdit: (Transaction) -> Void
        
        var body: some View {
            rowContent
                .opacity(listAppeared ? 1 : 0)
                .offset(x: listAppeared ? 0 : 20)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.8)
                    .delay(Double(sectionIndex) * 0.05 + Double(rowIndex) * 0.02),
                    value: listAppeared
                )
        }
        
        @ViewBuilder
        private var rowContent: some View {
            TransactionRow(transaction: transaction)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap(transaction)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    swipeActionsContent
                }
        }
        
        @ViewBuilder
        private var swipeActionsContent: some View {
            Button(role: .destructive) {
                onDelete(transaction)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .accessibilityLabel("Delete transaction")
            
            Button {
                onEdit(transaction)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.brandPrimary)
            .accessibilityLabel("Edit transaction")
        }
    }
    
    // MARK: - Filter Menu
    
    @ViewBuilder
    private var filterMenu: some View {
        Section("Classification") {
            financeTypeButtons
        }
        
        Section("Category") {
            categoryButtons
        }
        
        if hasActiveFilters {
            Section {
                Button(role: .destructive) {
                    impactMedium.impactOccurred()
                    clearFilters()
                } label: {
                    Label("Clear All Filters", systemImage: "xmark.circle")
                }
            }
        }
    }
    
    private var financeTypeButtons: some View {
        Group {
            Button {
                selectedFinanceType = nil
            } label: {
                Label("All", systemImage: selectedFinanceType == nil ? "checkmark" : "")
            }
            
            Button {
                selectedFinanceType = .business
            } label: {
                Label("Business", systemImage: selectedFinanceType == .business ? "checkmark" : "briefcase.fill")
            }
            
            Button {
                selectedFinanceType = .personal
            } label: {
                Label("Personal", systemImage: selectedFinanceType == .personal ? "checkmark" : "person.fill")
            }
        }
    }
    
    private var categoryButtons: some View {
        Group {
            Button {
                selectedCategory = nil
            } label: {
                Label("All Categories", systemImage: selectedCategory == nil ? "checkmark" : "")
            }
            
            ForEach(categories) { category in
                Button {
                    toggleCategory(category)
                } label: {
                    Label {
                        Text(category.name)
                    } icon: {
                        categoryIcon(for: category)
                    }
                }
            }
        }
    }
    
    private func categoryIcon(for category: Category) -> some View {
        let isSelected = selectedCategory?.id == category.id
        let iconName = isSelected ? "checkmark" : category.icon
        return Image(systemName: iconName)
            .foregroundStyle(Color(flowHex: category.colorHex))
    }
    
    private func toggleCategory(_ category: Category) {
        if selectedCategory?.id == category.id {
            selectedCategory = nil
        } else {
            selectedCategory = category
        }
    }
    
    // MARK: - Active Filters Display
    
    @ViewBuilder
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("Active Filters:")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                if let financeType = selectedFinanceType {
                    filterBadge(
                        text: financeType.displayName,
                        icon: financeType.icon,
                        color: financeType == .business ? .businessColor : .personalColor
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFinanceType = nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                if let category = selectedCategory {
                    filterBadge(
                        text: category.name,
                        icon: category.icon,
                        color: Color(flowHex: category.colorHex)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button {
                    impactMedium.impactOccurred()
                    clearFilters()
                } label: {
                    Text("Clear All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedFinanceType)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedCategory?.id)
    }
    
    private func filterBadge(text: String, icon: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
            Button {
                impactLight.impactOccurred()
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Remove filter: \(text)")
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Transactions", systemImage: "doc.text.magnifyingglass")
                .symbolEffect(.bounce, value: listAppeared)
        } description: {
            emptyStateDescription
        } actions: {
            emptyStateActions
        }
        .opacity(listAppeared ? 1 : 0)
        .scaleEffect(listAppeared ? 1 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: listAppeared)
    }
    
    private var emptyStateDescription: some View {
        Group {
            if hasActiveFilters {
                Text("No transactions match your filters. Try adjusting your filters or add a new transaction.")
            } else if !searchText.isEmpty {
                Text("No transactions match '\(searchText)'")
            } else {
                Text("Get started by adding your first transaction")
            }
        }
    }
    
    private var emptyStateActions: some View {
        Group {
            if hasActiveFilters {
                Button("Clear Filters") {
                    impactMedium.impactOccurred()
                    clearFilters()
                }
                .buttonStyle(.bordered)
                .tint(Color.brandPrimary)
            }
            
            Button("Add Transaction") {
                impactMedium.impactOccurred()
                showingAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTransactions: [Transaction] {
        let lowercasedSearch = searchText.lowercased()
        return allTransactions.filter { transaction in
            let matchesSearch = searchText.isEmpty ||
                transaction.merchantName.lowercased().contains(lowercasedSearch) ||
                transaction.note.lowercased().contains(lowercasedSearch) ||
                (transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false)
            
            let matchesCategory = selectedCategory == nil ||
                transaction.category?.id == selectedCategory?.id
            
            let matchesFinanceType = selectedFinanceType == nil ||
                transaction.financeType == selectedFinanceType
            
            return matchesSearch && matchesCategory && matchesFinanceType
        }
    }
    
    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedCategory != nil || selectedFinanceType != nil
    }
    
    private var filterIconName: String {
        hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }
    
    // MARK: - Actions
    
    private func clearFilters() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedCategory = nil
            selectedFinanceType = nil
        }
    }
    
    private func deleteTransaction(_ transaction: Transaction) {
        let transactionName = transaction.displayName
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            context.delete(transaction)
        }
        
        do {
            try context.save()
            notificationFeedback.notificationOccurred(.success)
            print("✅ Transaction deleted: \(transactionName)")
        } catch {
            notificationFeedback.notificationOccurred(.error)
            print("❌ Failed to delete transaction: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("With Transactions") {
    let container: ModelContainer = {
        do {
            return try ModelContainer(
                for: Transaction.self, Category.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }()
    
    let context = container.mainContext
    
    let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "10B981", isIncome: false)
    let clientPayment = Category(name: "Client Payment", icon: "dollarsign.circle.fill", colorHex: "14B8A6", isIncome: true)
    
    context.insert(groceries)
    context.insert(clientPayment)
    
    let transactions = [
        Transaction(amount: 5000, date: .now, note: "Website Design", isIncome: true, merchantName: "Acme Corp", category: clientPayment, financeType: .business, hasReceipt: true),
        Transaction(amount: 125.50, date: .now, note: "Office Supplies", isIncome: false, merchantName: "Staples", financeType: .business, hasReceipt: false),
        Transaction(amount: 42.99, date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, note: "Weekly Shopping", isIncome: false, merchantName: "Whole Foods", category: groceries, financeType: .personal, hasReceipt: true),
        Transaction(amount: 3500, date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!, note: "Logo Design", isIncome: true, merchantName: "TechStart Inc", category: clientPayment, financeType: .business, hasReceipt: false)
    ]
    
    transactions.forEach { context.insert($0) }
    
    return TransactionListView()
        .modelContainer(container)
}

#Preview("Empty State") {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
