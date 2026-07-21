//  TransactionListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 5.1 - Catalyst list style · Build 10 Review Flow + Segmented Filter
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v5.0 - Build 10 Transaction List Redesign:
//  ✅ ADDED: TransactionSegment enum (all/toReview/income/expense) as segmented control
//  ✅ ADDED: "Mark N as reviewed" action button when unreviewed transactions exist
//  ✅ ADDED: Alphabetical sort by merchant within same-date groups
//  ✅ ADDED: Monospaced tabular figures for amounts in TransactionRow
//  ✅ REPLACED: Direction filter in menu → top-level segmented control
//  ✅ KEPT: All v4.7 functionality (finance type, category, search, batch, multi-select)
//
//  CHANGES v4.6 - FetchDescriptor Pagination (Memory Fix):
//  ✅ FIXED: Replaced @Query (loaded all ~946 transactions) with FetchDescriptor + fetchLimit
//  ✅ FIXED: Database-level pagination — only fetches displayLimit transactions from SQLite
//  ✅ ADDED: loadTransactions() function mirrors DashboardView v3.12 pattern
//  ✅ ADDED: totalTransactionCount for accurate "Load More" remaining count
//  ✅ ADDED: Reload triggers on onAppear, displayLimit change, refresh, and mutations
//  ✅ Memory reduced from 165-173MB to well under 150MB threshold
//
//  CHANGES v4.5 - Multi-Select Batch Category Assignment:
//  ✅ ADDED: Selection mode — "Select Transactions" in filter menu enters multi-select
//  ✅ ADDED: Checkmark circles on each row when selecting, tap toggles selection
//  ✅ ADDED: Selection toolbar with "Select All" / "Deselect All" and "Done" buttons
//  ✅ ADDED: Bottom bar showing selection count + "Set Category" button
//  ✅ ADDED: Category picker sheet to batch-assign category to all selected transactions
//  ✅ ADDED: VoiceOver support for selection mode, selection bar, and category picker
//  ✅ ADDED: Swipe actions hidden during selection mode to prevent conflicts
//
//  CHANGES v4.4 - Performance + Batch Categorization:
//  ✅ ADDED: Pagination with displayLimit (100 transactions per page, "Load More" button)
//  ✅ FIXED: Search filter now uses localizedCaseInsensitiveContains (no per-call .lowercased())
//  ✅ FIXED: Filter evaluation order optimized — cheapest checks first, text search last
//  ✅ FIXED: Calendar.current cached in displayedGroupedTransactions
//  ✅ ADDED: Batch Categorize menu option in filter menu
//  ✅ ADDED: BatchCategorizationView sheet presentation
//
//  CHANGES v4.3 - Move Money Button:
//  ✅ ADDED: "Move Money" button in toolbar alongside Add Transaction
//  ✅ ADDED: Sheet presentation for MoveMoneyView
//  ✅ ADDED: Full VoiceOver accessibility support
//  ✅ ADDED: Haptic feedback using HapticService
//  ✅ Uses arrow.left.arrow.right.circle.fill icon with brandPrimary tint
//  ✅ Provides quick access to transfer functionality between accounts
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
import FLODesignSystem
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject private var navService = NavigationService.shared  // Build 10

    // Build 10: Top-level segmented control replaces direction filter
    enum TransactionSegment: String, CaseIterable {
        case all = "All"
        case toReview = "To Review"
        case income = "Income"
        case expense = "Expense"
    }

    // v4.7: Date range quick picks
    enum DateRangeFilter: String, CaseIterable {
        case all = "All Time"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case last90Days = "Last 90 Days"
        case thisYear = "This Year"
        case lastYear = "Last Year"

        var dateRange: (start: Date, end: Date)? {
            let cal = Calendar.current
            let now = Date()
            switch self {
            case .all: return nil
            case .thisMonth:
                let start = cal.dateInterval(of: .month, for: now)!.start
                return (start, now)
            case .lastMonth:
                let prevMonth = cal.date(byAdding: .month, value: -1, to: now)!
                let interval = cal.dateInterval(of: .month, for: prevMonth)!
                return (interval.start, interval.end)
            case .last90Days:
                return (cal.date(byAdding: .day, value: -90, to: now)!, now)
            case .thisYear:
                let start = cal.dateInterval(of: .year, for: now)!.start
                return (start, now)
            case .lastYear:
                let prevYear = cal.date(byAdding: .year, value: -1, to: now)!
                let interval = cal.dateInterval(of: .year, for: prevYear)!
                return (interval.start, interval.end)
            }
        }
    }

    // v4.6: Replaced @Query (loaded all ~946 txns) with manual FetchDescriptor + fetchLimit
    @State private var allTransactions: [Transaction] = []
    @State private var totalTransactionCount: Int = 0
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businessProfiles: [BusinessProfile]
    @Query(sort: \Account.name) private var accounts: [Account]

    // Bills feature: pull all bills and filter in-memory
    // (SwiftData enum-equality predicates throw at runtime — see BillService.fetchUpcomingBills)
    @Query(sort: \Bill.createdDate, order: .reverse) private var allBills: [Bill]

    @State private var searchText = ""
    @State private var selectedCategory: Category?
    @State private var selectedFinanceType: Transaction.FinanceType?
    @State private var selectedSegment: TransactionSegment = .all  // Build 10
    @State private var hideReviewed = false  // Build 10: filter menu toggle
    @State private var showingAddTransaction = false
    @State private var showMoveMoneyView = false
    @State private var showingBatchCategorization = false  // v4.4: Batch categorization
    @State private var isSelecting = false                 // v4.5: Multi-select mode
    @State private var selectedTransactionIDs = Set<UUID>()  // v4.5: Selected transaction IDs
    @State private var showingCategoryPickerForSelection = false  // v4.5: Category picker for selection
    @State private var showingFinanceTypePicker = false           // v4.7: Batch financeType
    @State private var showingAccountPickerForSelection = false   // v4.7: Batch account
    @State private var showingDeleteConfirmation = false          // v4.7: Batch delete
    @State private var showingAnchorWarning = false               // v4.8: Balance anchor warning
    @State private var showingDeleteError = false
    @State private var selectedAccount: Account?                  // v4.7: Account filter
    @State private var selectedBusinessProfile: BusinessProfile?  // v4.7: Business profile filter
    @State private var selectedDateRange: DateRangeFilter = .all  // v4.7: Date range filter
    @State private var transactionToEdit: Transaction?
    @State private var isRefreshing = false
    @State private var listAppeared = false
    @State private var isInitialLoad = true

    // Bills feature: detail navigation, add, and mark-paid sheets
    @State private var selectedBill: Bill?
    @State private var showingAddBill = false
    @State private var billPendingMarkPaid: Bill?

    // v4.4: Pagination — display transactions in batches for performance
    @State private var displayLimit = 100

    // Undo support - temporarily hidden transaction
    @State private var pendingDeleteTransaction: Transaction?
    
    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoad && allTransactions.isEmpty {
                    skeletonLoadingView
                } else if filteredTransactions.isEmpty && upcomingBills.isEmpty {
                    emptyStateView
                } else {
                    transactionList
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $searchText, prompt: "Search transactions")
            .toolbar {
                if isSelecting {
                    // v4.5: Selection mode toolbar
                    ToolbarItem(placement: .topBarLeading) {
                        Button(allDisplayedSelected ? "Deselect All" : "Select All") {
                            toggleSelectAll()
                        }
                        .accessibilityHint("Double tap to select or deselect all visible transactions")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            exitSelectionMode()
                        }
                        .fontWeight(.semibold)
                        .accessibilityHint("Double tap to exit selection mode")
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                HapticService.play(.medium)
                                showingAddTransaction = true
                            } label: {
                                Label("New Transaction", systemImage: "creditcard")
                            }
                            Button {
                                HapticService.play(.medium)
                                showingAddBill = true
                            } label: {
                                Label("New Bill", systemImage: "doc.text.fill")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        // v3.2: VoiceOver label
                        .accessibilityLabel("Add")
                        .accessibilityHint("Choose to create a new transaction or bill")
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            HapticService.play(.medium)
                            showMoveMoneyView = true
                        } label: {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .foregroundStyle(Color.brandPrimary)
                        }
                        // v4.3: Move Money button accessibility
                        .accessibilityLabel("Move Money")
                        .accessibilityHint("Double tap to transfer money between accounts")
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
            }
            .sheet(isPresented: $showingAddTransaction, onDismiss: { loadTransactions() }) {
                AddTransactionView()
            }
            .sheet(isPresented: $showMoveMoneyView, onDismiss: { loadTransactions() }) {
                MoveMoneyView()
            }
            // v4.4: Batch categorization sheet
            .sheet(isPresented: $showingBatchCategorization, onDismiss: { loadTransactions() }) {
                BatchCategorizationView()
            }
            .sheet(item: $transactionToEdit, onDismiss: { loadTransactions() }) { transaction in
                EditTransactionView(transaction: transaction)
            }
            // Bills feature
            .sheet(isPresented: $showingAddBill) {
                BillFormView()
            }
            .sheet(item: $selectedBill) { bill in
                NavigationStack {
                    BillDetailView(bill: bill)
                }
            }
            .sheet(item: $billPendingMarkPaid) { bill in
                MarkBillPaidSheet(bill: bill)
            }
            // v4.5: Category picker for multi-select batch assignment
            .sheet(isPresented: $showingCategoryPickerForSelection) {
                selectionCategoryPicker
            }
            // v4.7: Account picker for multi-select batch assignment
            .sheet(isPresented: $showingAccountPickerForSelection) {
                selectionAccountPicker
            }
            // v4.7: FinanceType picker for multi-select batch assignment
            .confirmationDialog(
                "Set Type for \(selectedTransactionIDs.count) Transactions",
                isPresented: $showingFinanceTypePicker,
                titleVisibility: .visible
            ) {
                Button("Business") { applyFinanceTypeToSelection(.business) }
                Button("Personal") { applyFinanceTypeToSelection(.personal) }
                Button("Cancel", role: .cancel) { }
            }
            // v4.7: Delete confirmation for multi-select
            .alert(
                "Delete \(selectedTransactionIDs.count) Transactions?",
                isPresented: $showingDeleteConfirmation
            ) {
                Button("Delete", role: .destructive) { checkAnchorConflictAndDelete() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
            .alert("Delete Failed", isPresented: $showingDeleteError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The transaction couldn't be deleted. Please try again.")
            }
            // v4.8: Balance anchor conflict warning for batch delete
            .alert("Balance Checkpoint Warning", isPresented: $showingAnchorWarning) {
                Button("Delete Anyway", role: .destructive) {
                    deleteSelection()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Some transactions are dated before your last reconciliation checkpoint. Deleting them may cause balance drift.")
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                HapticService.play(.selection)
                if let cat = newValue {
                    AccessibilityAnnouncement.announce("Filtered by \(cat.name). \(filteredTransactions.count) transactions.")
                } else if oldValue != nil {
                    AccessibilityAnnouncement.announce("Category filter removed. \(filteredTransactions.count) transactions.")
                }
            }
            .onChange(of: selectedFinanceType) { oldValue, newValue in
                HapticService.play(.selection)
                if newValue != .business {
                    selectedBusinessProfile = nil
                }
                if let type = newValue {
                    AccessibilityAnnouncement.announce("Filtered by \(type.displayName). \(filteredTransactions.count) transactions.")
                } else if oldValue != nil {
                    AccessibilityAnnouncement.announce("Type filter removed. \(filteredTransactions.count) transactions.")
                }
            }
            // Build 10: Segment change announcement
            .onChange(of: selectedSegment) { oldValue, newValue in
                HapticService.play(.selection)
                AccessibilityAnnouncement.announce("Showing \(newValue.rawValue). \(filteredTransactions.count) transactions.")
            }
            // Build 10: Navigate from Dashboard review badge → open To Review segment
            .onChange(of: navService.openTransactionReviewSection) { _, shouldOpen in
                if shouldOpen {
                    withAnimation(FLOAnimation.quick) {
                        selectedSegment = .toReview
                    }
                    navService.openTransactionReviewSection = false
                }
            }
            .onAppear {
                loadTransactions()  // v4.6: Database-level pagination
                DispatchQueue.main.async {
                    withAnimation(FLOAnimation.standard) {
                        listAppeared = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(FLOAnimation.gentle) {
                        isInitialLoad = false
                    }
                    // v3.2: Screen announcement
                    AccessibilityAnnouncement.screenChanged("Transactions. \(totalTransactionCount) total.")
                }
            }
            .onChange(of: displayLimit) { _, _ in
                loadTransactions()  // v4.6: Re-fetch when "Load More" increases limit
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
        #if os(macOS) || targetEnvironment(macCatalyst)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        // v3.2: Hide skeleton from VoiceOver
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading transactions")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Transaction List

    // Build 10: Unreviewed transaction count
    /// Only count past/today transactions as needing review — upcoming are planned, not reviewable
    private var unreviewedCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        return allTransactions.filter { !$0.isReviewed && $0.date < tomorrow }.count
    }

    /// Transactions dated after today — user's planned/projected items
    private var upcomingTransactions: [Transaction] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return filteredTransactions.filter { $0.date >= tomorrow }
    }

    /// Transactions dated today or earlier — actual recorded items
    private var currentTransactions: [Transaction] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return filteredTransactions.filter { $0.date < tomorrow }
    }

    /// Pending or partially-paid bills, sorted with Upon Receipt first then by due date.
    private var upcomingBills: [Bill] {
        allBills
            .filter { $0.status == .pending || $0.status == .partiallyPaid }
            .sorted { lhs, rhs in
                if lhs.isUponReceipt != rhs.isUponReceipt {
                    return lhs.isUponReceipt
                }
                return lhs.effectiveSortDate < rhs.effectiveSortDate
            }
    }

    private var upcomingGrouped: [Date: [Transaction]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: upcomingTransactions) { calendar.startOfDay(for: $0.date) }
        return grouped.mapValues { $0.sorted { $0.merchantName.localizedCaseInsensitiveCompare($1.merchantName) == .orderedAscending } }
    }

    private var currentGrouped: [Date: [Transaction]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: currentTransactions) { calendar.startOfDay(for: $0.date) }
        return grouped.mapValues { $0.sorted { $0.merchantName.localizedCaseInsensitiveCompare($1.merchantName) == .orderedAscending } }
    }

    @ViewBuilder
    private var transactionList: some View {
        ScrollViewReader { scrollProxy in
        List {
            // Build 10: Segmented control (All / To Review / Income / Expense)
            Section {
                VStack(spacing: 12) {
                    Picker("View", selection: $selectedSegment) {
                        ForEach(TransactionSegment.allCases, id: \.self) { segment in
                            if segment == .toReview && unreviewedCount > 0 {
                                Text("\(segment.rawValue) (\(unreviewedCount))").tag(segment)
                            } else {
                                Text(segment.rawValue).tag(segment)
                            }
                        }
                    }
                    .pickerStyle(.segmented)

                    // Build 10: "Mark N as reviewed" action button
                    if unreviewedCount > 0 && selectedSegment == .toReview {
                        Button {
                            markAllAsReviewed()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Mark all \(unreviewedCount) as reviewed")
                                    .font(.system(size: 13, weight: .medium))

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.brandPrimary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.brandPrimary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mark \(unreviewedCount) transactions as reviewed")
                        .accessibilityHint("Double tap to mark all unreviewed transactions as reviewed")
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))

            if hasActiveFilters {
                Section {
                    activeFiltersView
                }
                .listRowBackground(Color.clear)
            }

            // MARK: — Upcoming (future-dated) transactions — hidden above scroll
            if !upcomingTransactions.isEmpty || !upcomingBills.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(Color.brandPrimary)
                        Text("Upcoming")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.brandPrimary)
                        Spacer()
                        Text("\(upcomingTransactions.count + upcomingBills.count)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.brandPrimary.opacity(0.7))
                            .clipShape(Capsule())
                    }
                    .listRowBackground(Color.clear)
                }

                // Bills subsection — Upon Receipt first, then by due date
                if !upcomingBills.isEmpty {
                    Section {
                        ForEach(upcomingBills, id: \.id) { bill in
                            BillRow(bill: bill)
                                .onTapGesture {
                                    HapticService.play(.light)
                                    selectedBill = bill
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        HapticService.play(.medium)
                                        billPendingMarkPaid = bill
                                    } label: {
                                        Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    .tint(.green)
                                }
                                .contextMenu {
                                    Button {
                                        HapticService.play(.light)
                                        billPendingMarkPaid = bill
                                    } label: {
                                        Label("Mark Paid", systemImage: "checkmark.circle.fill")
                                    }
                                    Button {
                                        HapticService.play(.light)
                                        selectedBill = bill
                                    } label: {
                                        Label("Open", systemImage: "doc.text.magnifyingglass")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Bills")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        }
                    }
                }

                ForEach(upcomingGrouped.keys.sorted(by: >), id: \.self) { date in
                    Section {
                        ForEach(upcomingGrouped[date] ?? [], id: \.id) { transaction in
                            if transaction.id != pendingDeleteTransaction?.id {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                        .foregroundStyle(Color.brandPrimary.opacity(0.6))
                                        .frame(width: 16)

                                    TransactionRow(transaction: transaction)
                                        .opacity(0.6)
                                }
                                .onTapGesture {
                                    HapticService.play(.light)
                                    transactionToEdit = transaction
                                }
                            }
                        }
                    } header: {
                        sectionHeader(for: date)
                    }
                }

                // Combined directional banner: Upcoming ▴ | ▾ Today
                Section {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.brandWarning)
                            .frame(height: 2)

                        HStack(spacing: 0) {
                            // Left half — Upcoming direction
                            HStack {
                                Spacer()
                                Text("▴ UPCOMING ▴")
                                    .font(.caption.weight(.heavy))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.brandWarning.opacity(0.7))
                                Spacer()
                            }

                            // Center divider
                            Rectangle()
                                .fill(Color.brandWarning.opacity(0.5))
                                .frame(width: 1.5)
                                .padding(.vertical, 4)

                            // Right half — Today direction
                            HStack {
                                Spacer()
                                Text("▾ TODAY ▾")
                                    .font(.caption.weight(.heavy))
                                    .tracking(1.2)
                                    .foregroundStyle(Color.brandWarning)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)

                        Rectangle()
                            .fill(Color.brandWarning)
                            .frame(height: 2)
                    }
                    .id("today-anchor")
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            }

            // MARK: — Current (today + past) transactions
            ForEach(Array(currentGrouped.keys.sorted(by: >).enumerated()), id: \.element) { sectionIndex, date in
                Section {
                    transactionRows(for: date, sectionIndex: sectionIndex)
                } header: {
                    sectionHeader(for: date)
                }
            }

            // v4.6: Pagination — "Load More" when database has more transactions than fetched
            if allTransactions.count < totalTransactionCount {
                Section {
                    Button {
                        withAnimation(FLOAnimation.standard) {
                            displayLimit += 100
                        }
                        HapticService.play(.light)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load More (\(totalTransactionCount - allTransactions.count) remaining)")
                                .font(.subheadline)
                                .foregroundStyle(Color.brandPrimary)
                            Spacer()
                        }
                    }
                    .accessibilityLabel("Load more transactions")
                    .accessibilityHint("\(totalTransactionCount - allTransactions.count) transactions remaining")
                }
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .scrollContentBackground(.hidden)
        // v4.5: Selection bottom bar
        .safeAreaInset(edge: .bottom) {
            if isSelecting && !selectedTransactionIDs.isEmpty {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .refreshable {
            await refresh()
        }
        .animation(FLOAnimation.standard, value: displayedTransactions.count)
        .animation(FLOAnimation.quick, value: hasActiveFilters)
        .animation(FLOAnimation.quick, value: isSelecting)
        .animation(FLOAnimation.quick, value: selectedTransactionIDs.count)
        .onAppear {
            // Auto-scroll to Today anchor so users don't have to scroll past upcoming
            if !upcomingTransactions.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        scrollProxy.scrollTo("today-anchor", anchor: .top)
                    }
                }
            }
        }
        } // ScrollViewReader
    }

    /// Sorted date keys for grouped transactions, extracted to reduce type-checker complexity.
    private var sortedDateKeys: [Date] {
        displayedGroupedTransactions.keys.sorted(by: >)
    }

    /// Rows for a single date section, extracted to reduce type-checker complexity.
    @ViewBuilder
    private func transactionRows(for date: Date, sectionIndex: Int) -> some View {
        let transactions: [Transaction] = displayedGroupedTransactions[date] ?? []
        ForEach(Array(transactions.enumerated()), id: \.element.id) { rowIndex, transaction in
            if transaction.id != pendingDeleteTransaction?.id {
                AnimatedRow(
                    transaction: transaction,
                    sectionIndex: sectionIndex,
                    rowIndex: rowIndex,
                    listAppeared: listAppeared,
                    isSelecting: isSelecting,
                    isSelected: selectedTransactionIDs.contains(transaction.id),
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
                    },
                    onSelect: {
                        toggleSelection(transaction.id)
                    },
                    onReview: { transaction in
                        toggleReviewed(transaction)
                    }
                )
            }
        }
    }

    private func refresh() async {
        HapticService.play(.light)
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        loadTransactions()  // v4.6: Reload from database on pull-to-refresh
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
        let isSelecting: Bool       // v4.5
        let isSelected: Bool        // v4.5
        let onTap: (Transaction) -> Void
        let onDelete: (Transaction) -> Void
        let onEdit: (Transaction) -> Void
        let onSelect: () -> Void    // v4.5
        let onReview: (Transaction) -> Void  // Build 10

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
            HStack(spacing: 12) {
                // v4.5: Selection checkmark
                if isSelecting {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.brandPrimary : .secondary)
                        .font(.title2)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }

                TransactionRow(transaction: transaction)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelecting {
                    onSelect()
                } else {
                    onTap(transaction)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // v4.5: Hide swipe actions while selecting
                if !isSelecting {
                    swipeActionsContent
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint(isSelecting
                ? (isSelected ? "Selected. Double tap to deselect." : "Double tap to select.")
                : "Double tap to view details. Swipe left for actions.")
            // v3.2: Rotor actions for VoiceOver users (only in normal mode)
            .accessibilityAction(named: "Edit") {
                if !isSelecting { onEdit(transaction) }
            }
            .accessibilityAction(named: "Delete") {
                if !isSelecting { onDelete(transaction) }
            }
            // Build 10: Context menu for macOS right-click (also long-press on iOS)
            .contextMenu {
                if !isSelecting {
                    Button {
                        onEdit(transaction)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button {
                        transaction.isReviewed.toggle()
                        try? transaction.modelContext?.save()
                        HapticService.play(.selection)
                    } label: {
                        Label(
                            transaction.isReviewed ? "Mark as Unreviewed" : "Mark as Reviewed",
                            systemImage: transaction.isReviewed ? "eye.slash" : "checkmark.circle"
                        )
                    }

                    Divider()

                    Button(role: .destructive) {
                        onDelete(transaction)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
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

            // Build 10: Review toggle swipe action
            Button {
                onReview(transaction)
            } label: {
                Label(
                    transaction.isReviewed ? "Unreviewed" : "Reviewed",
                    systemImage: transaction.isReviewed ? "eye.slash" : "checkmark.circle.fill"
                )
            }
            .tint(transaction.isReviewed ? .orange : .green)
            .accessibilityLabel(transaction.isReviewed ? "Mark as unreviewed" : "Mark as reviewed")
            .accessibilityHint("Toggles the review status of this transaction")
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

        // v4.7: Business Profile filter (when viewing business transactions with multiple profiles)
        if selectedFinanceType == .business && businessProfiles.count > 1 {
            Section("Business Profile") {
                ForEach(businessProfiles) { profile in
                    Button {
                        withAnimation(FLOAnimation.quick) {
                            selectedBusinessProfile = selectedBusinessProfile?.id == profile.id ? nil : profile
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedBusinessProfile?.id == profile.id ? "checkmark.circle.fill" : profile.displayIcon)
                                .accessibilityHidden(true)
                            Text(profile.businessName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }

        if !uniqueCategories.isEmpty {
            Section("Category") {
                ForEach(uniqueCategories) { category in
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

        // v4.7: Account filter
        let activeAccounts = accounts.filter { $0.isActive }
        if !activeAccounts.isEmpty {
            Section("Account") {
                ForEach(activeAccounts) { account in
                    Button {
                        withAnimation(FLOAnimation.quick) {
                            selectedAccount = selectedAccount?.id == account.id ? nil : account
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedAccount?.id == account.id ? "checkmark.circle.fill" : account.accountType.icon)
                                .accessibilityHidden(true)
                            Text(account.name)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }

        // v4.7: Date Range filter
        Section("Date Range") {
            ForEach(DateRangeFilter.allCases, id: \.self) { range in
                Button {
                    withAnimation(FLOAnimation.quick) {
                        selectedDateRange = selectedDateRange == range ? .all : range
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedDateRange == range ? "checkmark.circle.fill" : "calendar")
                            .accessibilityHidden(true)
                        Text(range.rawValue)
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

        // Build 10: Hide Reviewed toggle
        Section("Review") {
            Button {
                withAnimation(FLOAnimation.quick) {
                    hideReviewed.toggle()
                }
                HapticService.play(.selection)
            } label: {
                HStack {
                    Image(systemName: hideReviewed ? "checkmark.circle.fill" : "eye.slash")
                        .accessibilityHidden(true)
                    Text(hideReviewed ? "Showing Unreviewed Only" : "Hide Reviewed")
                }
            }
            .accessibilityLabel(hideReviewed ? "Show all transactions" : "Hide reviewed transactions")
            .accessibilityHint("Double tap to toggle visibility of reviewed transactions")
        }

        // v4.4: Batch Categorization
        Section {
            Button {
                HapticService.play(.medium)
                showingBatchCategorization = true
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .accessibilityHidden(true)
                    Text("Batch Categorize")
                }
            }
            .accessibilityLabel("Batch categorize transactions")
            .accessibilityHint("Double tap to categorize multiple transactions by merchant at once")

            // v4.5: Multi-select mode
            Button {
                HapticService.play(.medium)
                withAnimation(FLOAnimation.quick) {
                    isSelecting = true
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .accessibilityHidden(true)
                    Text("Select Transactions")
                }
            }
            .accessibilityLabel("Select transactions")
            .accessibilityHint("Double tap to enter selection mode and pick transactions to categorize")
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

                // v4.7: Business profile badge
                if let bp = selectedBusinessProfile {
                    filterBadge(
                        text: bp.businessName,
                        icon: bp.displayIcon,
                        color: .brandPrimary
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            selectedBusinessProfile = nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // v4.7: Account badge
                if let acct = selectedAccount {
                    filterBadge(
                        text: acct.name,
                        icon: acct.accountType.icon,
                        color: .teal
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            selectedAccount = nil
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // v4.7: Date range badge
                if selectedDateRange != .all {
                    filterBadge(
                        text: selectedDateRange.rawValue,
                        icon: "calendar",
                        color: .purple
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            selectedDateRange = .all
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Build 10: Hide Reviewed badge
                if hideReviewed {
                    filterBadge(
                        text: "Unreviewed",
                        icon: "eye.slash",
                        color: .orange
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            hideReviewed = false
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
                        .foregroundStyle(Color.expenseRed)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.expenseRed.opacity(0.1))
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
    
    // MARK: - Computed Properties (v4.4 Performance Optimized)
    //
    // Previously: filteredTransactions called .lowercased() on merchantName + note for
    // every transaction on each keystroke. groupedTransactions called Calendar.current.startOfDay()
    // 945+ times per render. No pagination — all rows rendered eagerly.
    //
    // Now: search text is lowercased once, Calendar is cached, and displayLimit
    // controls how many transactions are rendered.

    /// Categories deduplicated by name so the filter menu never shows "Accounting &
    /// Bookkeeping" five times. Defense-in-depth — `SeedData.migrateCategories`
    /// also prunes duplicates on every launch, but some installs have stale data
    /// that this hid before the migration fix landed.
    private var uniqueCategories: [Category] {
        var seen = Set<String>()
        return categories.filter { seen.insert($0.name).inserted }
    }

    private var filteredTransactions: [Transaction] {
        let lowercasedSearch = searchText.lowercased()
        let pendingDeleteID = pendingDeleteTransaction?.id
        let filterCategory = selectedCategory
        let filterFinanceType = selectedFinanceType
        let segment = selectedSegment  // Build 10
        let filterHideReviewed = hideReviewed  // Build 10

        return allTransactions.filter { transaction in
            if transaction.id == pendingDeleteID {
                return false
            }

            // Build 10: Segment filter (cheapest check first)
            switch segment {
            case .all: break
            case .toReview: if transaction.isReviewed { return false }
            case .income:   if !transaction.isIncome { return false }
            case .expense:  if transaction.isIncome { return false }
            }

            // Build 10: Hide reviewed filter (independent of segment)
            if filterHideReviewed && segment == .all && transaction.isReviewed {
                return false
            }

            // Finance type filter
            if let ft = filterFinanceType, transaction.financeType != ft {
                return false
            }

            // Category filter
            if let cat = filterCategory, transaction.category?.id != cat.id {
                return false
            }

            // v4.7: Business profile filter
            if let bp = selectedBusinessProfile {
                if transaction.account?.businessProfile?.id != bp.id { return false }
            }

            // v4.7: Account filter
            if let acct = selectedAccount {
                if transaction.account?.id != acct.id { return false }
            }

            // v4.7: Date range filter
            if let range = selectedDateRange.dateRange {
                if transaction.date < range.start || transaction.date > range.end { return false }
            }

            // Text search (most expensive, evaluated last)
            if !lowercasedSearch.isEmpty {
                let matchesMerchant = transaction.merchantName.localizedCaseInsensitiveContains(lowercasedSearch)
                let matchesNote = transaction.note.localizedCaseInsensitiveContains(lowercasedSearch)
                let matchesCategory = transaction.category?.name.localizedCaseInsensitiveContains(lowercasedSearch) ?? false
                if !matchesMerchant && !matchesNote && !matchesCategory {
                    return false
                }
            }

            return true
        }
    }

    /// v4.6: allTransactions is already limited by fetchLimit, so filteredTransactions
    /// is the display set. Kept as alias for compatibility with existing references.
    private var displayedTransactions: [Transaction] {
        filteredTransactions
    }

    /// Grouped transactions for the paginated display set (cached Calendar)
    /// Build 10: Within each date group, sorted alphabetically by merchant name
    private var displayedGroupedTransactions: [Date: [Transaction]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: displayedTransactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped.mapValues { transactions in
            transactions.sorted { $0.merchantName.localizedCaseInsensitiveCompare($1.merchantName) == .orderedAscending }
        }
    }

    private var hasActiveFilters: Bool {
        selectedCategory != nil || selectedFinanceType != nil || hideReviewed
        || selectedAccount != nil || selectedBusinessProfile != nil || selectedDateRange != .all
    }

    private var filterIconName: String {
        hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
    }
    
    // MARK: - Selection Mode (v4.5)

    /// Whether all displayed transactions are currently selected
    private var allDisplayedSelected: Bool {
        !displayedTransactions.isEmpty && displayedTransactions.allSatisfy { selectedTransactionIDs.contains($0.id) }
    }

    /// Bottom bar shown during selection mode
    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedTransactionIDs.count) selected")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            // Build 10: Bulk mark as reviewed
            Button {
                HapticService.play(.medium)
                markSelectionAsReviewed()
            } label: {
                Label("Review", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("Mark \(selectedTransactionIDs.count) transactions as reviewed")
            .accessibilityHint("Double tap to mark all selected transactions as reviewed")

            Button {
                HapticService.play(.medium)
                showingCategoryPickerForSelection = true
            } label: {
                Label("Category", systemImage: "tag.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .accessibilityLabel("Set category for \(selectedTransactionIDs.count) transactions")
            .accessibilityHint("Double tap to choose a category for all selected transactions")

            // v4.7: Batch financeType
            Button {
                HapticService.play(.medium)
                showingFinanceTypePicker = true
            } label: {
                Label("Type", systemImage: "briefcase.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .accessibilityLabel("Set type for \(selectedTransactionIDs.count) transactions")

            // v4.7: Batch account
            Button {
                HapticService.play(.medium)
                showingAccountPickerForSelection = true
            } label: {
                Label("Account", systemImage: "building.columns.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .accessibilityLabel("Set account for \(selectedTransactionIDs.count) transactions")

            // v4.7: Batch delete
            Button {
                HapticService.play(.medium)
                showingDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Delete \(selectedTransactionIDs.count) transactions")
        }
        .padding()
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
    }

    /// Category picker sheet for batch-assigning to selected transactions
    private var selectionCategoryPicker: some View {
        NavigationStack {
            List(categories) { category in
                Button {
                    applyCategoryToSelection(category)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .foregroundStyle(Color(flowHex: category.colorHex))
                            .frame(width: 28)
                            .accessibilityHidden(true)

                        Text(category.name)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                }
                .accessibilityLabel(category.name)
                .accessibilityHint("Double tap to assign \(category.name) to \(selectedTransactionIDs.count) transactions")
            }
            .navigationTitle("Set Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCategoryPickerForSelection = false
                    }
                }
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        HapticService.play(.selection)
        if selectedTransactionIDs.contains(id) {
            selectedTransactionIDs.remove(id)
        } else {
            selectedTransactionIDs.insert(id)
        }
    }

    private func exitSelectionMode() {
        withAnimation(FLOAnimation.quick) {
            isSelecting = false
            selectedTransactionIDs.removeAll()
        }
        HapticService.play(.light)
        AccessibilityAnnouncement.announce("Selection mode ended")
    }

    private func toggleSelectAll() {
        HapticService.play(.medium)
        if allDisplayedSelected {
            selectedTransactionIDs.removeAll()
            AccessibilityAnnouncement.announce("All deselected")
        } else {
            selectedTransactionIDs = Set(displayedTransactions.map { $0.id })
            AccessibilityAnnouncement.announce("\(displayedTransactions.count) transactions selected")
        }
    }

    private func applyCategoryToSelection(_ category: Category) {
        let matchingTransactions = allTransactions.filter { selectedTransactionIDs.contains($0.id) }

        for transaction in matchingTransactions {
            transaction.category = category
        }

        do {
            try context.save()
            HapticService.play(.success)
            let count = matchingTransactions.count
            AccessibilityAnnouncement.announce("\(count) transactions categorized as \(category.name)")
        } catch {
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to update categories")
            #if DEBUG
            print("Failed to batch categorize: \(error)")
            #endif
        }

        showingCategoryPickerForSelection = false
        exitSelectionMode()
    }

    // v4.7: Batch financeType assignment
    private func applyFinanceTypeToSelection(_ type: Transaction.FinanceType) {
        let matching = allTransactions.filter { selectedTransactionIDs.contains($0.id) }
        for t in matching { t.financeType = type }
        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(matching.count) transactions set to \(type.displayName)")
        } catch {
            HapticService.play(.error)
        }
        showingFinanceTypePicker = false
        exitSelectionMode()
    }

    // v4.7: Batch account assignment
    private func applyAccountToSelection(_ account: Account) {
        let matching = allTransactions.filter { selectedTransactionIDs.contains($0.id) }
        for t in matching { t.account = account }
        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(matching.count) transactions assigned to \(account.name)")
        } catch {
            HapticService.play(.error)
        }
        showingAccountPickerForSelection = false
        exitSelectionMode()
    }

    // v4.8: Check for balance anchor conflicts before batch delete
    private func checkAnchorConflictAndDelete() {
        let transactionsToDelete = allTransactions.filter { selectedTransactionIDs.contains($0.id) }
        let accountIds = Set(transactionsToDelete.compactMap { $0.account?.id })
        var hasAnchorConflict = false
        if let anchors = try? context.fetch(FetchDescriptor<BalanceAnchor>()) {
            for accountId in accountIds {
                let accountAnchors = anchors.filter { $0.account?.id == accountId }
                guard let latestAnchor = accountAnchors.max(by: { $0.anchorDate < $1.anchorDate }) else { continue }
                if transactionsToDelete.contains(where: { $0.account?.id == accountId && $0.date < latestAnchor.anchorDate }) {
                    hasAnchorConflict = true
                    break
                }
            }
        }
        if hasAnchorConflict {
            showingAnchorWarning = true
        } else {
            deleteSelection()
        }
    }

    // v4.7: Batch delete
    private func deleteSelection() {
        let matching = allTransactions.filter { selectedTransactionIDs.contains($0.id) }
        let count = matching.count
        for t in matching { context.delete(t) }
        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(count) transactions deleted")
        } catch {
            HapticService.play(.error)
        }
        loadTransactions()
        exitSelectionMode()
    }

    // v4.7: Account picker for batch assignment
    private var selectionAccountPicker: some View {
        NavigationStack {
            List(accounts.filter { $0.isActive }) { account in
                Button {
                    applyAccountToSelection(account)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: account.accountType.icon)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        Text(account.name)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Set Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAccountPickerForSelection = false }
                }
            }
        }
    }

    // MARK: - Data Loading (v4.6)

    /// Fetch transactions with database-level pagination.
    /// Uses FetchDescriptor with fetchLimit tied to displayLimit,
    /// same pattern as DashboardView v3.12.
    private func loadTransactions() {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        descriptor.fetchLimit = displayLimit

        do {
            allTransactions = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("❌ Failed to fetch transactions: \(error)")
            #endif
            allTransactions = []
        }

        loadTotalCount()
    }

    /// Get the total count of transactions in the database (cheap — no objects loaded).
    /// Used to show accurate "Load More (X remaining)" count.
    private func loadTotalCount() {
        let descriptor = FetchDescriptor<Transaction>()
        totalTransactionCount = (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Actions

    // Build 10: Bulk mark selected transactions as reviewed
    private func markSelectionAsReviewed() {
        let matching = allTransactions.filter { selectedTransactionIDs.contains($0.id) && !$0.isReviewed }
        for transaction in matching {
            transaction.isReviewed = true
        }

        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(matching.count) transactions marked as reviewed")
        } catch {
            HapticService.play(.error)
        }

        exitSelectionMode()
    }

    // Build 10: Toggle review status for a single transaction (swipe action)
    private func toggleReviewed(_ transaction: Transaction) {
        transaction.isReviewed.toggle()
        do {
            try context.save()
            HapticService.play(.selection)
            let verb = transaction.isReviewed ? "reviewed" : "unreviewed"
            AccessibilityAnnouncement.announce("\(transaction.merchantName) marked as \(verb)")
        } catch {
            HapticService.play(.error)
        }
    }

    // Build 10: Mark all visible unreviewed transactions as reviewed
    private func markAllAsReviewed() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let unreviewed = allTransactions.filter { !$0.isReviewed && $0.date < tomorrow }
        for transaction in unreviewed {
            transaction.isReviewed = true
        }

        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(unreviewed.count) transactions marked as reviewed")
        } catch {
            HapticService.play(.error)
            #if DEBUG
            print("❌ Failed to mark transactions as reviewed: \(error)")
            #endif
        }
    }

    private func clearFilters() {
        withAnimation(FLOAnimation.quick) {
            selectedCategory = nil
            selectedFinanceType = nil
            selectedAccount = nil
            selectedBusinessProfile = nil
            selectedDateRange = .all
            hideReviewed = false  // Build 10
            displayLimit = 100  // v4.4: Reset pagination on filter clear
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
            loadTransactions()  // v4.6: Refresh list after deletion
            #if DEBUG
            print("Transaction deleted")
            #endif
        } catch {
            // Undo the in-memory delete and balance adjustments so the ledger
            // doesn't silently drift from what's persisted
            context.rollback()
            loadTransactions()
            HapticService.play(.error)
            showingDeleteError = true
            AccessibilityAnnouncement.announce("Failed to delete transaction")
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
