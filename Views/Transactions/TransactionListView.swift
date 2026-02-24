//  TransactionListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.2 - VoiceOver Audit: Decorative icons hidden
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.2 - VoiceOver Audit:
//  ✅ ADDED: Filter menu icons hidden (briefcase, person, checkmark icons)
//  ✅ ADDED: Category icons hidden in filter menu
//  ✅ ADDED: Filter badge icons hidden (type/category icon + x button)
//  ✅ VERIFIED: All icon-only buttons have explicit accessibility labels
//  ✅ VERIFIED: Excellent accessibility coverage already in place
//
//  CHANGES v4.1 - Dynamic Type Verification:
//  ✅ FIXED: Section header date text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Filter badge text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Clear All button text - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Empty state title text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Empty state description text - lineLimit(3) + minimumScaleFactor(0.7)
//  ✅ FIXED: Empty state button labels - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Filter menu category text - lineLimit(1) + minimumScaleFactor(0.7)
//
//  CHANGES v3.2:
//  ✅ ADDED: VoiceOver label + hint on Add Transaction toolbar button
//  ✅ ADDED: VoiceOver label + hint on Filter menu button
//  ✅ ADDED: Skeleton loading view hidden from VoiceOver
//  ✅ ADDED: Empty state view accessible with meaningful labels
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Filter change announcements for VoiceOver
//  ✅ ADDED: Clear All button in active filters has VoiceOver label
//  ✅ ADDED: Active filters section has VoiceOver summary
//  ✅ ADDED: Undo/restore announced to VoiceOver
//  ✅ ADDED: Transaction count announced after filter changes
//  ✅ ADDED: Rotor actions (Edit, Delete) on each row for VoiceOver
//  ✅ ADDED: Filter badge grouped for VoiceOver
//
//  CHANGES v3.1:
//  - Added account balance reversal when deleting transactions
//  - Fixed UTF-8 encoding in print statements
//
//  CHANGES v3.0:
//  - Added Undo support for deleted transactions (5-second window)
//  - Migrated all haptics to centralized HapticService
//  - Migrated all animations to FLOAnimation presets
//

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
    @State private var isInitialLoad = true
    
    // Undo support - temporarily hidden transaction
    @State private var pendingDeleteTransaction: Transaction?
    
    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoad && allTransactions.isEmpty {
                    skeletonLoadingView
                } else if filteredTransactions.isEmpty {
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
                        HapticService.play(.medium)
                        showingAddTransaction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    // v3.2: VoiceOver label
                    .accessibilityLabel("Add transaction")
                    .accessibilityHint("Double tap to create a new transaction")
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        filterMenu
                    } label: {
                        Label("Filter", systemImage: filterIconName)
                            .foregroundStyle(hasActiveFilters ? Color.brandPrimary : .primary)
                    }
                    // v3.2: VoiceOver label with filter state
                    .accessibilityLabel(hasActiveFilters ? "Filters active" : "Filter transactions")
                    .accessibilityHint("Double tap to open filter options by type and category")
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .sheet(item: $transactionToEdit) { transaction in
                EditTransactionView(transaction: transaction)
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                HapticService.play(.selection)
                // v3.2: Announce filter change
                if let cat = newValue {
                    AccessibilityAnnouncement.announce("Filtered by \(cat.name). \(filteredTransactions.count) transactions.")
                } else if oldValue != nil {
                    AccessibilityAnnouncement.announce("Category filter removed. \(filteredTransactions.count) transactions.")
                }
            }
            .onChange(of: selectedFinanceType) { oldValue, newValue in
                HapticService.play(.selection)
                // v3.2: Announce filter change
                if let type = newValue {
                    AccessibilityAnnouncement.announce("Filtered by \(type.displayName). \(filteredTransactions.count) transactions.")
                } else if oldValue != nil {
                    AccessibilityAnnouncement.announce("Type filter removed. \(filteredTransactions.count) transactions.")
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    listAppeared = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(FLOAnimation.gentle) {
                        isInitialLoad = false
                    }
                    // v3.2: Screen announcement
                    AccessibilityAnnouncement.screenChanged("Transactions. \(allTransactions.count) total.")
                }
            }
        }
    }
    
    // MARK: - Skeleton Loading View
    
    @ViewBuilder
    private var skeletonLoadingView: some View {
        List {
            Section {
                SkeletonList(count: 3) {
                    TransactionRowSkeleton()
                }
            } header: {
                SkeletonShape()
                    .frame(width: 120, height: 14)
            }
            
            Section {
                SkeletonList(count: 2) {
                    TransactionRowSkeleton()
                }
            } header: {
                SkeletonShape()
                    .frame(width: 100, height: 14)
            }
        }
        .listStyle(.insetGrouped)
        // v3.2: Hide skeleton from VoiceOver
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading transactions")
        .accessibilityAddTraits(.updatesFrequently)
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
                        if transaction.id != pendingDeleteTransaction?.id {
                            AnimatedRow(
                                transaction: transaction,
                                sectionIndex: sectionIndex,
                                rowIndex: rowIndex,
                                listAppeared: listAppeared,
                                onTap: { transaction in
                                    HapticService.play(.light)
                                    transactionToEdit = transaction
                                },
                                onDelete: { transaction in
                                    deleteTransactionWithUndo(transaction)
                                },
                                onEdit: { transaction in
                                    HapticService.play(.light)
                                    transactionToEdit = transaction
                                }
                            )
                        }
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
        .animation(FLOAnimation.standard, value: filteredTransactions.count)
        .animation(FLOAnimation.quick, value: hasActiveFilters)
    }

    private func refresh() async {
        HapticService.play(.light)
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        isRefreshing = false
        HapticService.play(.success)
    }

    private func sectionHeader(for date: Date) -> some View {
        Text(date, format: .dateTime.month(.wide).day().year())
            .font(.subheadline)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
                .opacity(listAppeared ? 1 : 0.001)
                .offset(x: listAppeared ? 0 : 20)
                .animation(
                    FLOAnimation.staggered(index: sectionIndex * 3 + rowIndex, baseDelay: 0.02),
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
                .accessibilityElement(children: .combine)
                .accessibilityHint("Double tap to view details. Swipe left for actions.")
                // v3.2: Rotor actions for VoiceOver users
                .accessibilityAction(named: "Edit") {
                    onEdit(transaction)
                }
                .accessibilityAction(named: "Delete") {
                    onDelete(transaction)
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
            .accessibilityHint("Permanently removes this transaction. Can be undone for 5 seconds.")
            
            Button {
                onEdit(transaction)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.brandPrimary)
            .accessibilityLabel("Edit transaction")
            .accessibilityHint("Opens form to modify this transaction")
        }
    }
    
    // MARK: - Filter Menu
    
    @ViewBuilder
    private var filterMenu: some View {
        Section("Finance Type") {
            Button {
                withAnimation(FLOAnimation.quick) {
                    selectedFinanceType = selectedFinanceType == .business ? nil : .business
                }
            } label: {
                HStack {
                    Image(systemName: selectedFinanceType == .business ? "checkmark.circle.fill" : "briefcase")
                        .accessibilityHidden(true)
                    Text("Business")
                }
            }
            
            Button {
                withAnimation(FLOAnimation.quick) {
                    selectedFinanceType = selectedFinanceType == .personal ? nil : .personal
                }
            } label: {
                HStack {
                    Image(systemName: selectedFinanceType == .personal ? "checkmark.circle.fill" : "person")
                        .accessibilityHidden(true)
                    Text("Personal")
                }
            }
        }
        
        if !categories.isEmpty {
            Section("Category") {
                ForEach(categories) { category in
                    Button {
                        withAnimation(FLOAnimation.quick) {
                            selectedCategory = selectedCategory?.id == category.id ? nil : category
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedCategory?.id == category.id ? "checkmark.circle.fill" : category.icon)
                                .foregroundStyle(Color(flowHex: category.colorHex))
                                .accessibilityHidden(true)
                            Text(category.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        
        if hasActiveFilters {
            Section {
                Button(role: .destructive) {
                    HapticService.play(.medium)
                    clearFilters()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .accessibilityHidden(true)
                        Text("Clear All Filters")
                    }
                }
            }
        }
    }
    
    // MARK: - Active Filters View
    
    @ViewBuilder
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let financeType = selectedFinanceType {
                    filterBadge(
                        text: financeType.displayName,
                        icon: financeType.icon,
                        color: financeType == .business ? .businessColor : .personalColor
                    ) {
                        withAnimation(FLOAnimation.quick) {
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
                        withAnimation(FLOAnimation.quick) {
                            selectedCategory = nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button {
                    HapticService.play(.medium)
                    clearFilters()
                } label: {
                    Text("Clear All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
                // v3.2: VoiceOver label
                .accessibilityLabel("Clear all filters")
                .accessibilityHint("Double tap to remove all active filters")
            }
            .padding(.horizontal, 4)
        }
        .animation(FLOAnimation.quick, value: selectedFinanceType)
        .animation(FLOAnimation.quick, value: selectedCategory?.id)
    }
    
    private func filterBadge(text: String, icon: String, color: Color, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Button {
                HapticService.play(.light)
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .accessibilityLabel("Remove filter: \(text)")
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        // v3.2: Group badge for VoiceOver
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) filter active")
        .accessibilityHint("Contains remove button")
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            if !hasActiveFilters && searchText.isEmpty {
                TransactionsIllustration()
            }
            
            Text("No Transactions")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            emptyStateDescription
                .font(.subheadline)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            emptyStateActions
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .opacity(listAppeared ? 1 : 0.001)
        .scaleEffect(listAppeared ? 1 : 0.95)
        .animation(FLOAnimation.standard, value: listAppeared)
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
                    HapticService.play(.medium)
                    clearFilters()
                }
                .buttonStyle(.bordered)
                .tint(Color.brandPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                // v3.2: VoiceOver
                .accessibilityLabel("Clear all filters")
                .accessibilityHint("Double tap to remove all filters and show all transactions")
            }
            
            Button("Add Transaction") {
                HapticService.play(.medium)
                showingAddTransaction = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            // v3.2: VoiceOver
            .accessibilityLabel("Add transaction")
            .accessibilityHint("Double tap to create your first transaction")
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTransactions: [Transaction] {
        let lowercasedSearch = searchText.lowercased()
        return allTransactions.filter { transaction in
            if transaction.id == pendingDeleteTransaction?.id {
                return false
            }
            
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
        withAnimation(FLOAnimation.quick) {
            selectedCategory = nil
            selectedFinanceType = nil
        }
        // v3.2: Announce
        AccessibilityAnnouncement.announce("All filters cleared. \(allTransactions.count) transactions.")
    }
    
    private func deleteTransactionWithUndo(_ transaction: Transaction) {
        let transactionName = transaction.displayName
        
        withAnimation(FLOAnimation.quick) {
            pendingDeleteTransaction = transaction
        }
        
        // v3.2: Announce deletion
        AccessibilityAnnouncement.announce("\(transactionName) deleted. Shake to undo.")
        
        FLOUndoManager.shared.scheduleDelete(
            message: "\(transactionName) deleted",
            icon: "trash"
        ) {
            performDelete(transaction)
        } undoAction: {
            withAnimation(FLOAnimation.standard) {
                pendingDeleteTransaction = nil
            }
            HapticService.play(.success)
            // v3.2: Announce restore
            AccessibilityAnnouncement.announce("\(transactionName) restored.")
        }
    }
    
    private func performDelete(_ transaction: Transaction) {
        let account = transaction.account
        let amount = transaction.amount
        let isIncome = transaction.isIncome
        
        if let account = account {
            if isIncome {
                account.currentBalance -= amount
            } else {
                account.currentBalance += amount
            }
            account.lastBalanceUpdate = Date()
            account.touch()
        }
        
        withAnimation(FLOAnimation.quick) {
            context.delete(transaction)
            pendingDeleteTransaction = nil
        }
        
        do {
            try context.save()
            #if DEBUG
            print("Transaction deleted")
            #endif
        } catch {
            HapticService.play(.error)
            #if DEBUG
            print("Failed to delete transaction: \(error)")
            #endif
        }
    }
}

// MARK: - Transaction Backup (for Undo)

private struct TransactionBackup {
    let amount: Double
    let date: Date
    let note: String
    let isIncome: Bool
    let merchantName: String
    let financeType: Transaction.FinanceType
    let hasReceipt: Bool
    let categoryID: UUID?
    
    init(from transaction: Transaction) {
        self.amount = transaction.amount
        self.date = transaction.date
        self.note = transaction.note
        self.isIncome = transaction.isIncome
        self.merchantName = transaction.merchantName
        self.financeType = transaction.financeType
        self.hasReceipt = transaction.hasReceipt
        self.categoryID = transaction.category?.id
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

#Preview("Loading State") {
    TransactionListView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
