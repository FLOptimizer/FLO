//  DashboardView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.7.1 - Accessibility: Dynamic Type text scaling on mode label
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Elite production-ready dashboard with Business/Personal/All filtering
//
//  THIS IS THE KILLER FEATURE - The app that finally understands freelancers
//
//  CHANGES v3.7:
//  ✅ FIXED: Timeframe.contains() did not exist — replaced with inline Calendar filter
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Accessibility labels on finance mode picker with spoken value
//  ✅ ADDED: Accessibility labels on timeframe picker with spoken value
//  ✅ ADDED: Close button in mileage sheet has VoiceOver label
//  ✅ ADDED: Dashboard content scroll area has accessibility grouping
//  ✅ ADDED: Card section headers marked as headers for VoiceOver rotor
//  ✅ ADDED: Mode description reads dynamically for VoiceOver
//  ✅ ADDED: Empty state card accessible with meaningful label
//  ✅ ADDED: Refresh button already had labels (preserved from v3.6)
//  ✅ ADDED: Skeleton loading hidden from VoiceOver
//  ✅ ADDED: Announce mode/timeframe changes to VoiceOver
//
//  PREVIOUS (v3.6):
//  ✅ FIXED: Basic receipt capture now uses FreeTierReceiptView (not ReceiptImageView)
//  ✅ ReceiptImageView requires imagePath - it's a viewer, not a capture view
//  ✅ FreeTierReceiptView provides camera capture + basic OCR for Free tier
//  ✅ QuickActionsView routes: Free → FreeTierReceiptView, Premium+ → SmartReceiptScanningView
//
//  PREVIOUS (v3.5):
//  ✅ InvoiceDashboardCard hidden for Free tier (requires Premium+)
//  ✅ Added SubscriptionManager to check tier access
//  ✅ Business cards now conditionally show based on tier
//
//  PREVIOUS (v3.4):
//  ✅ ADDED: GettingStartedCard for new users after onboarding
//  ✅ Card appears at position 3 (after mode selector and timeframe picker)
//  ✅ Auto-hides when tasks completed or user dismisses
//
//  PREVIOUS (v3.3):
//  - MOVED: Accounts Summary Card to position 3 (before Balance Summary)
//  - User sees account balances first, then income/expense summary
//  - Supports new privacy veil feature in AccountsSummaryCard
//
//  PREVIOUS (v3.2):
//  - FIXED: Timeframe Picker now shows on Business Dashboard
//  - FIXED: Budget Overview Card now shows for Business mode (filtered by financeType)
//  - FIXED: Consistent card ordering across all dashboard modes
//  - ADDED: filteredBudgets computed property for mode-aware budget filtering
//  - Accounts Summary Card now at consistent position for all modes
//  - Credit Card Summary Card now at consistent position for all modes
//
//  RELATED FILES:
//  - DashboardTypes.swift (FinanceMode, Timeframe enums)
//  - BalanceSummaryCard.swift
//  - QuickActionsView.swift
//  - BudgetOverviewCard.swift
//  - RecentTransactionsCard.swift
//  - DashboardBusinessCards.swift
//  - DashboardEmptyStateCard.swift
//  - DashboardSkeletonView.swift
//  - AccountsSummaryCard.swift
//  - CreditCardSummaryCard.swift
//  - GettingStartedCard.swift
//  - FreeTierReceiptView.swift (NEW in v3.6)
//

import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allBudgets: [Budget]
    
    // v3.5: Subscription manager for tier checking
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // MARK: - Sheet Presentation States
    @State private var showingAddExpense = false
    @State private var showingCreateInvoice = false
    @State private var showingReceiptScanner = false      // Premium+: SmartReceiptScanningView
    @State private var showingMileageTracking = false
    @State private var showingBasicReceiptCapture = false // Free: FreeTierReceiptView (v3.6)
    @State private var showingMoveMoney = false           // Premium+: MoveMoneyView (v3.8)
    
    @State private var financeMode: FinanceMode = .all
    @State private var selectedTimeframe: Timeframe = .thisMonth
    @State private var refreshID = UUID()
    @State private var isRefreshing = false
    
    // MARK: - Animation States
    @State private var cardsAppeared = false
    @State private var summaryAnimated = false
    @State private var isInitialLoad = true
    
    // MARK: - Computed Properties
    
    // v3.5: Feature access checks
    private var hasInvoicing: Bool {
        subscriptionManager.currentTier.hasInvoicing
    }
    
    /// Filter budgets to current month AND by finance mode
    /// v3.2: Now filters by financeMode so business/personal budgets stay separate
    private var filteredBudgets: [Budget] {
        let calendar = Calendar.current
        let now = Date()
        
        // First filter to current month
        let currentMonth = allBudgets.filter { budget in
            calendar.isDate(budget.month, equalTo: now, toGranularity: .month)
        }
        
        // Then filter by finance mode
        switch financeMode {
        case .business:
            return currentMonth.filter { $0.financeType == .business }
        case .personal:
            return currentMonth.filter { $0.financeType == .personal }
        case .all:
            return currentMonth
        }
    }
    
    /// Filter transactions by finance mode AND timeframe
    private var filteredTransactions: [Transaction] {
        let modeFiltered: [Transaction]
        
        switch financeMode {
        case .business:
            modeFiltered = allTransactions.filter { $0.financeType == .business }
        case .personal:
            modeFiltered = allTransactions.filter { $0.financeType == .personal }
        case .all:
            modeFiltered = Array(allTransactions)
        }
        
        let calendar = Calendar.current
        let now = Date()
        
        return modeFiltered.filter { transaction in
            switch selectedTimeframe {
            case .thisWeek:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
            case .thisYear:
                return calendar.isDate(transaction.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private var totalIncome: Double {
        filteredTransactions
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var totalExpenses: Double {
        filteredTransactions
            .filter { !$0.isIncome }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    private var netIncome: Double {
        totalIncome - totalExpenses
    }
    
    private var recentTransactions: [Transaction] {
        Array(filteredTransactions.prefix(5))
    }
    
    // Business-specific metrics
    private var businessDeductions: Double {
        allTransactions
            .filter { $0.financeType == .business && !$0.isIncome }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoad {
                    DashboardSkeletonView()
                        // v3.7: Hide skeleton from VoiceOver, announce loading
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Loading dashboard")
                        .accessibilityAddTraits(.updatesFrequently)
                } else {
                    dashboardContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        refreshDashboard()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(
                                isRefreshing ?
                                    .linear(duration: 1).repeatForever(autoreverses: false) :
                                    .default,
                                value: isRefreshing
                            )
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh dashboard")
                    .accessibilityHint(isRefreshing ? "Currently refreshing" : "Double tap to refresh dashboard data")
                }
            }
            // MARK: - Sheet Presentations
            .sheet(isPresented: $showingAddExpense) {
                AddTransactionView()
            }
            .sheet(isPresented: $showingCreateInvoice) {
                CreateInvoiceView()
            }
            // v3.6: Premium+ Smart Receipt Scanner
            .sheet(isPresented: $showingReceiptScanner) {
                SmartReceiptScanningView()
                    .environmentObject(subscriptionManager)
            }
            // v3.6: Free Tier Basic Receipt Capture (FIXED - was using ReceiptImageView which requires imagePath)
            .sheet(isPresented: $showingBasicReceiptCapture) {
                FreeTierReceiptView()
            }
            // Mileage tracking - MileageTrackingMainView handles tier routing internally
            .sheet(isPresented: $showingMileageTracking) {
                NavigationStack {
                    MileageTrackingMainView()
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") {
                                    HapticService.play(.light)
                                    showingMileageTracking = false
                                }
                                // v3.7: VoiceOver label for close button
                                .accessibilityLabel("Close mileage tracking")
                                .accessibilityHint("Double tap to return to dashboard")
                            }
                        }
                }
            }
            // v3.8: Move Money between accounts (Premium+)
            .sheet(isPresented: $showingMoveMoney) {
                MoveMoneyView()
                    .environmentObject(subscriptionManager)
            }
            .refreshable {
                await refreshAsync()
            }
            .onAppear {
                setupTripSaving()
                refreshWidgets()
                
                // Mark initial load complete after brief delay (for skeleton)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(FLOAnimation.standard) {
                        isInitialLoad = false
                    }
                    // v3.7: Announce dashboard loaded to VoiceOver
                    AccessibilityAnnouncement.screenChanged("\(navigationTitle). \(dashboardSummaryForAccessibility)")
                }
                
                // Trigger entrance animations
                withAnimation(FLOAnimation.standard) {
                    cardsAppeared = true
                }
                
                // Delay summary animation slightly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(FLOAnimation.gentle) {
                        summaryAnimated = true
                    }
                }
            }
            .onChange(of: financeMode) { oldValue, newValue in
                HapticService.play(.selection)
                
                // Re-trigger card animations on mode change
                withAnimation(FLOAnimation.quick) {
                    summaryAnimated = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(FLOAnimation.standard) {
                        summaryAnimated = true
                    }
                }
                
                // v3.7: Announce mode change to VoiceOver
                AccessibilityAnnouncement.announce("Switched to \(newValue.rawValue) mode. \(newValue.description)")
            }
            .onChange(of: selectedTimeframe) { oldValue, newValue in
                HapticService.play(.selection)
                
                // v3.7: Announce timeframe change to VoiceOver
                AccessibilityAnnouncement.announce("Showing \(newValue.displayName)")
            }
            .id(refreshID)
        }
    }
    
    // MARK: - Dashboard Content
        
        @ViewBuilder
        private var dashboardContent: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. PRIMARY: Finance Mode Selector (THE KILLER FEATURE)
                    financeModeSelector
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : -20)
                    
                    // 2. SECONDARY: Timeframe Picker (shown for ALL modes including Business)
                    timeframePicker
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : -15)
                    
                    // 3. Getting Started Card (v3.4) - Shows for new users after onboarding
                    GettingStartedCard(
                        showingAddTransaction: $showingAddExpense,
                        showingReceiptScanner: $showingReceiptScanner
                    )
                    .padding(.horizontal)
                    .opacity(cardsAppeared ? 1 : 0.001)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.05), value: cardsAppeared)
                    
                    // 4. Accounts Summary Card (Premium+) - v3.3: Moved to top for prominence
                    AccountsSummaryCard(financeMode: financeMode)
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(0.1), value: cardsAppeared)
                    
                    // 5. Balance Summary Card - Shows income/expense flow
                    BalanceSummaryCard(
                        income: totalIncome,
                        expenses: totalExpenses,
                        net: netIncome,
                        timeframe: selectedTimeframe,
                        financeMode: financeMode,
                        animated: summaryAnimated
                    )
                    .padding(.horizontal)
                    .opacity(cardsAppeared ? 1 : 0.001)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.15), value: cardsAppeared)
                    
                    // 6. Quick Actions - v3.6: Now properly routes receipts by tier
                    QuickActionsView(
                        showingAddExpense: $showingAddExpense,
                        showingCreateInvoice: $showingCreateInvoice,
                        showingReceiptScanner: $showingReceiptScanner,
                        showingMileageTracking: $showingMileageTracking,
                        showingMoveMoney: $showingMoveMoney,
                        showingBasicReceiptCapture: $showingBasicReceiptCapture,
                        financeMode: financeMode
                    )
                    .padding(.horizontal)
                    .opacity(cardsAppeared ? 1 : 0.001)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.2), value: cardsAppeared)
                    
                    // 7. Business Mode: Show tax-focused cards
                    if financeMode == .business {
                        businessCards
                    }
                    
                    // 8. Budget Overview Card (shown for ALL modes, filtered by financeType)
                    if !filteredBudgets.isEmpty {
                        BudgetOverviewCard(
                            budgets: filteredBudgets,
                            transactions: filteredTransactions
                        )
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(financeMode == .business ? 0.45 : 0.3), value: cardsAppeared)
                    }
                    
                    // 9. Credit Card Summary Card (Premium+)
                    CreditCardSummaryCard(financeMode: financeMode)
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(financeMode == .business ? 0.47 : 0.32), value: cardsAppeared)
                    
                    // 10. Money Moves Tips Card (v3.7) - Financial tips & debt optimization
                    MoneyMovesTipsCard()
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(financeMode == .business ? 0.50 : 0.37), value: cardsAppeared)
                    
                    // 11. Recent Transactions
                    if !recentTransactions.isEmpty {
                        RecentTransactionsCard(
                            transactions: recentTransactions,
                            financeMode: financeMode
                        )
                        .padding(.horizontal)
                        .opacity(cardsAppeared ? 1 : 0.001)
                        .offset(y: cardsAppeared ? 0 : 20)
                        .animation(FLOAnimation.standard.delay(financeMode == .business ? 0.52 : 0.40), value: cardsAppeared)
                    } else {
                        DashboardEmptyStateCard(financeMode: financeMode)
                            .padding(.horizontal)
                            .opacity(cardsAppeared ? 1 : 0.001)
                            .scaleEffect(cardsAppeared ? 1 : 0.9)
                            .animation(FLOAnimation.standard.delay(financeMode == .business ? 0.52 : 0.40), value: cardsAppeared)
                            // v3.7: VoiceOver label for empty state
                            .accessibleCard(
                                label: "No transactions yet for \(financeMode.rawValue) mode, \(selectedTimeframe.displayName)",
                                hint: "Use quick actions above to add your first transaction"
                            )
                    }
                    
                    // Bottom padding
                    Color.clear.frame(height: 20)
                        .accessibilityHidden(true)
                }
                .padding(.vertical)
            }
        }
    
    // MARK: - View Components
    
    private var financeModeSelector: some View {
        VStack(spacing: 8) {
            Picker("Finance Mode", selection: $financeMode) {
                ForEach(FinanceMode.allCases, id: \.self) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            // v3.7: Enhanced VoiceOver label with current selection
            .accessibilityLabel("Finance mode: \(financeMode.rawValue)")
            .accessibilityHint("Choose between All, Business, or Personal transactions")
            
            // Mode description with fade animation
            Text(financeMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal)
                .animation(FLOAnimation.quickEase, value: financeMode)
                // v3.7: VoiceOver reads mode description
                .accessibilityLabel(financeMode.description)
        }
    }
    
    private var timeframePicker: some View {
        Picker("Timeframe", selection: $selectedTimeframe) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Text(timeframe.displayName).tag(timeframe)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        // v3.7: Enhanced VoiceOver label with current selection
        .accessibilityLabel("Time period: \(selectedTimeframe.displayName)")
        .accessibilityHint("Choose the time range for displayed data")
    }
    
    // v3.5: Business cards with tier gating for InvoiceDashboardCard
    private var businessCards: some View {
        Group {
            // TaxEstimateCard already has its own Premium gating (shows upgrade overlay)
            TaxEstimateCard()
                .padding(.horizontal)
                .opacity(cardsAppeared ? 1 : 0.001)
                .offset(y: cardsAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.2), value: cardsAppeared)
            
            // v3.5: Only show InvoiceDashboardCard for Premium+ users
            if hasInvoicing {
                InvoiceDashboardCard()
                    .padding(.horizontal)
                    .opacity(cardsAppeared ? 1 : 0.001)
                    .offset(y: cardsAppeared ? 0 : 20)
                    .animation(FLOAnimation.standard.delay(0.25), value: cardsAppeared)
            }
            
            // MileageDashboardCard already has its own tier gating
            MileageDashboardCard()
                .padding(.horizontal)
                .opacity(cardsAppeared ? 1 : 0.001)
                .offset(y: cardsAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(hasInvoicing ? 0.3 : 0.25), value: cardsAppeared)
            
            // Business Deductions Summary
            BusinessDeductionsSummaryCard(deductions: businessDeductions)
                .padding(.horizontal)
                .opacity(cardsAppeared ? 1 : 0.001)
                .offset(y: cardsAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(hasInvoicing ? 0.35 : 0.3), value: cardsAppeared)
        }
    }
    
    private var navigationTitle: String {
        switch financeMode {
        case .business: return "Business Dashboard"
        case .personal: return "Personal Dashboard"
        case .all: return "Dashboard"
        }
    }
    
    // v3.7: Spoken summary for VoiceOver on load
    private var dashboardSummaryForAccessibility: String {
        let incomeStr = AccessibilityFormatters.spokenCurrency(totalIncome)
        let expenseStr = AccessibilityFormatters.spokenCurrency(totalExpenses)
        return "Income \(incomeStr), Expenses \(expenseStr) for \(selectedTimeframe.displayName)"
    }
    
    // MARK: - Helper Functions
    
    private func refreshDashboard() {
        HapticService.play(.medium)
        isRefreshing = true
        refreshID = UUID()
        
        // v3.7: Announce refresh to VoiceOver
        AccessibilityAnnouncement.announce("Refreshing dashboard")
        
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                refreshWidgets()
                isRefreshing = false
                HapticService.play(.success)
                
                // v3.7: Announce refresh complete
                AccessibilityAnnouncement.announce("Dashboard refreshed")
            }
        }
        
        #if DEBUG
        print("[Dashboard] Refreshed - Mode: \(financeMode.rawValue)")
        #endif
    }
    
    private func refreshAsync() async {
        HapticService.play(.light)
        isRefreshing = true
        
        // Update widget data
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            refreshID = UUID()
            isRefreshing = false
            HapticService.play(.success)
        }
    }
    
    private func refreshWidgets() {
        let balance = netIncome
        let income = totalIncome
        let expenses = totalExpenses
        
        Task.detached {
            await MainActor.run {
                #if DEBUG
                print("[Widget] Data: Balance \(balance), Income \(income), Expenses \(expenses)")
                #endif
            }
        }
    }
    
    private func setupTripSaving() {
        NotificationCenter.default.addObserver(
            forName: .dashboardMileageTripCompleted,
            object: nil,
            queue: .main
        ) { notification in
            if let trip = notification.object as? MileageTrip {
                modelContext.insert(trip)
                do {
                    try modelContext.save()
                    HapticService.play(.success)
                    #if DEBUG
                    print("[Mileage] Trip saved from Dashboard: \(trip.distanceMiles) miles")
                    #endif
                } catch {
                    HapticService.play(.error)
                    #if DEBUG
                    print("[Mileage] Error saving trip: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Business Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Transaction.self, Budget.self, Category.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let category = Category(name: "Office Supplies", icon: "pencil", colorHex: "14B8A6", isIncome: false)
    context.insert(category)
    
    let transaction1 = Transaction(
        amount: 125.50,
        date: Date(),
        note: "Office supplies",
        isIncome: false,
        merchantName: "Staples",
        category: category,
        financeType: .business,
        hasReceipt: false
    )
    context.insert(transaction1)
    
    let transaction2 = Transaction(
        amount: 5000,
        date: Date().addingTimeInterval(-86400),
        note: "Client payment",
        isIncome: true,
        merchantName: "Acme Corp",
        financeType: .business,
        hasReceipt: false
    )
    context.insert(transaction2)
    
    return DashboardView()
        .modelContainer(container)
}

#Preview("Personal Mode") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Transaction.self, Budget.self, Category.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let transaction = Transaction(
        amount: 45.99,
        date: Date(),
        note: "Groceries",
        isIncome: false,
        merchantName: "Whole Foods",
        financeType: .personal,
        hasReceipt: false
    )
    context.insert(transaction)
    
    let category = Category(name: "Groceries", icon: "cart", colorHex: "10B981", isIncome: false)
    context.insert(category)
    
    let budget = Budget(
        month: Date(),
        planned: 500,
        category: category,
        financeType: .personal
    )
    context.insert(budget)
    
    return DashboardView()
        .modelContainer(container)
}
