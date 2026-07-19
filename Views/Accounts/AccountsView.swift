//  AccountsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.6 - Size-class-aware edit routing (Catalyst/iPad Zone 3) + Catalyst limit-reached sheet
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.4 - Crash Fix:
//  ✅ CRITICAL: Fixed fatal crash when deleting an account
//  ✅ Pre-nullify Transaction.account (prevents @Query race during post-save vacuum)
//  ✅ Pre-nullify Budget.account (same race condition)
//  ✅ Pre-nullify Transfer.fromAccount / .toAccount (no inverse on Account — SwiftData never cascaded)
//  ✅ Pre-nullify RecurringTransfer.fromAccount / .toAccount (same gap)
//  ✅ Pre-nullify RecurringTransaction.account (implicit relationship, no declared inverse)
//  ✅ All relationships resolved BEFORE modelContext.delete() to prevent backing data faults
//
//  CHANGES v4.3 - UTF-8 Fix:
//  ✅ FIXED: L898 Plaid teaser text mojibake → "— Pro feature"
//
//  CHANGES v4.2 - Dark Mode Optimization:
//  ✅ FIXED: L776 Color.gray.opacity(0.2) → Color.gray.opacity(0.3).opacity(0.2) for progress bar background (adapts to dark mode)
//
//  CHANGES v4.1 - Dynamic Type Verification:
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for adaptive layout detection
//  ✅ ADDED: isAccessibilitySize computed property for layout switching
//  ✅ FIXED: "Net Worth" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Net worth amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Assets" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Assets amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Liabilities" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Liabilities amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Segment picker labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Active accounts header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Active accounts count badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Swipe actions footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "No Accounts Yet" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Add Your First Account" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Suggested account name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Suggested account type/finance type missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Hide Balances on Dashboard" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Privacy description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Privacy footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account limit count text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Upgrade" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account limit warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Unlimited accounts" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "PRO" badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Connect Bank Account" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Auto-import transactions via Plaid" subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Auto-Import Transactions" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Plaid upgrade teaser text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Upgrade" button in Plaid section missing lineLimit + minimumScaleFactor
//  ✅ ADDED: Adaptive layout for net worth card at accessibility sizes
//  ✅ ADDED: Adaptive layout for assets/liabilities cards at accessibility sizes
//  ✅ FIXED: UTF-8 mojibake in Plaid text — corrected in v4.3
//
//  CHANGES v4.0:
//  ✅ Custom SwiftUI empty state illustration
//
//  CHANGES v3.6:
//  ✅ Restored Connect Bank section
//  ✅ Pro users: Branded connect button calling startPlaidLink()
//  ✅ Non-Pro users: Upgrade teaser with subscription prompt
//  ✅ Full VoiceOver accessibility on both states

import SwiftUI
import SwiftData
import FLODesignSystem

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \Account.name) private var accounts: [Account]
    
    @State private var showingAddAccount = false
    @State private var accountToEdit: Account?
    @State private var showingDeleteConfirmation = false
    @State private var accountToDelete: Account?
    @State private var showingUpgradePrompt = false
    @State private var showingLimitReached = false
    @State private var selectedSegment: FinanceSegment = .all
    @State private var animateBalances = false
    
    // MARK: - Plaid Link State (v3.3)
    @State private var showingPlaidLink = false
    @State private var showingConnectedAccounts = false
    @State private var plaidLinkToken: String?
    @State private var isLoadingLinkToken = false
    @State private var plaidError: String?
    @StateObject private var plaidService = PlaidService.shared
    
    // MARK: - Privacy Setting (v2.2)
    @AppStorage("hideBalancesOnDashboard") private var hideBalancesOnDashboard = true
    
    // Dynamic Type detection
    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }
    
    enum FinanceSegment: String, CaseIterable {
        case all = "All"
        case business = "Business"
        case personal = "Personal"
    }
    
    // MARK: - Filtered Accounts
    
    /// Sort order for account type groups: assets first, then liabilities
    private static let typeGroupOrder: [AccountType: Int] = [
        .checking: 0, .savings: 1, .cash: 2,
        .paypal: 3, .venmo: 4, .zelle: 5, .investment: 6,
        .creditCard: 7, .loan: 8, .other: 9
    ]

    private var filteredAccounts: [Account] {
        let active = accounts.filter { $0.isActive }
        let filtered: [Account]
        switch selectedSegment {
        case .all:      filtered = active
        case .business: filtered = active.filter { $0.financeType == .business }
        case .personal: filtered = active.filter { $0.financeType == .personal }
        }
        // Group by type, then sort by absolute balance descending within each group
        return filtered.sorted { a, b in
            let aOrder = Self.typeGroupOrder[a.accountType] ?? 9
            let bOrder = Self.typeGroupOrder[b.accountType] ?? 9
            if aOrder != bOrder { return aOrder < bOrder }
            return abs(a.currentBalance) > abs(b.currentBalance)
        }
    }
    
    private var inactiveAccounts: [Account] {
        accounts.filter { !$0.isActive }
    }
    
    // MARK: - Balance Calculations
    
    private var totalAssets: Double {
        filteredAccounts.filter { $0.isAsset }.reduce(0) { $0 + $1.currentBalance }
    }
    
    private var totalLiabilities: Double {
        filteredAccounts.filter { $0.isLiability }.reduce(0) { $0 + abs($1.currentBalance) }
    }
    
    private var netWorth: Double {
        totalAssets - totalLiabilities
    }
    
    private var canAddMoreAccounts: Bool {
        subscriptionManager.currentTier.canAddMore(current: accounts.count, limitType: .accounts)
    }

    private var linkedAccounts: [Account] {
        accounts.filter { $0.isLinked }
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            if subscriptionManager.currentTier.hasBalanceTracking && !filteredAccounts.isEmpty {
                balanceSummarySection
            }
            
            if !accounts.isEmpty {
                segmentPickerSection
            }
            
            if !filteredAccounts.isEmpty {
                activeAccountsSection
            }
            
            if !inactiveAccounts.isEmpty && selectedSegment == .all {
                inactiveAccountsSection
            }
            
            if accounts.isEmpty {
                emptyStateSection
            }
            
            if accounts.isEmpty {
                suggestedAccountsSection
            }
            
            if !accounts.isEmpty {
                accountLimitSection
            }
            
            // Plaid section always visible (independent of account count)
            plaidConnectionSection
        }
        .scrollContentBackground(.hidden)
        .refreshable {
            await refreshFromPlaid()
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddAccount()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                }
                // v3.5: VoiceOver
                .accessibilityLabel("Add account")
                .accessibilityHint(canAddMoreAccounts ? "Double tap to create a new account" : "Account limit reached. Double tap to view upgrade options.")
            }
        }
        // Add/Edit hosting is size-class-aware (works correctly on Mac Catalyst,
        // whose window resizes between regular and compact). On regular width the
        // row actions route to the Zone 3 detail pane via `editAccount` /
        // `handleAddAccount` and never set the sheet state, so these sheets simply
        // don't present there. On compact width they're the presentation path.
        // (Previously gated `#if os(macOS)`, which is dead on Catalyst.)
        .sheet(isPresented: $showingAddAccount) {
            AddAccountView()
        }
        .sheet(item: $accountToEdit) { account in
            EditAccountView(account: account)
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                HapticService.play(.light)
            }
            Button("Delete", role: .destructive) {
                if let account = accountToDelete {
                    deleteAccount(account)
                }
            }
        } message: {
            Text("Are you sure you want to delete this account? This action cannot be undone.")
        }
        .sheet(isPresented: $showingUpgradePrompt) {
            SubscriptionView()
        }
        // Catalyst: present the limit-reached UI as a sheet (Mac-native), not a
        // full-screen cover. fullScreenCover is the iPhone path.
        #if os(macOS) || targetEnvironment(macCatalyst)
        .sheet(isPresented: $showingLimitReached) {
            LimitReachedOverlay(
                limitType: .accounts,
                currentCount: accounts.count,
                limit: subscriptionManager.currentTier.accountLimit ?? 0,
                showingSubscription: $showingUpgradePrompt,
                onDismiss: {
                    showingLimitReached = false
                }
            )
        }
        #else
        .fullScreenCover(isPresented: $showingLimitReached) {
            LimitReachedOverlay(
                limitType: .accounts,
                currentCount: accounts.count,
                limit: subscriptionManager.currentTier.accountLimit ?? 0,
                showingSubscription: $showingUpgradePrompt,
                onDismiss: {
                    showingLimitReached = false
                }
            )
        }
        #endif
        #if canImport(LinkKit)
        .sheet(isPresented: $showingPlaidLink) {
            if let linkToken = plaidLinkToken {
                PlaidLinkView(
                    linkToken: linkToken,
                    onSuccess: { metadata in
                        handlePlaidSuccess(metadata)
                    },
                    onExit: { error in
                        handlePlaidExit(error)
                    }
                )
            }
        }
        #endif
        .sheet(isPresented: $showingConnectedAccounts) {
            NavigationStack {
                ConnectedAccountsListView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingConnectedAccounts = false
                            }
                        }
                    }
            }
            .floMacSheetFrame()
        }
        .alert("Connection Error", isPresented: .init(
            get: { plaidError != nil },
            set: { if !$0 { plaidError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(plaidError ?? "An error occurred connecting to your bank.")
        }
        .onAppear {
            // Defer to avoid "Publishing changes from within view updates" on macOS NavigationSplitView
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    animateBalances = true
                }
            }
            // v3.5: Announce screen
            AccessibilityAnnouncement.screenChanged("Accounts. \(accounts.count) total.")
        }
    }
    
    // MARK: - Balance Summary Section
    
    private var balanceSummarySection: some View {
        Section {
            VStack(spacing: 12) {
                // Net Worth Card - adaptive layout
                Group {
                    if isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Net Worth")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text(formatCurrency(netWorth))
                                .font(.title2)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(netWorth >= 0 ? Color.brandPrimary : .red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Net Worth")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text(formatCurrency(netWorth))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(netWorth >= 0 ? Color.brandPrimary : .red)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .contentTransition(.numericText())
                            }
                            
                            Spacer()
                            
                            Image(systemName: netWorth >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.title)
                                .foregroundStyle(netWorth >= 0 ? Color.brandPrimary : .red)
                                .symbolEffect(.bounce, value: animateBalances)
                                // v3.5: Decorative
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding()
                .background(Color.floSecondarySystemGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // v3.5: Net worth accessible
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Net worth: \(AccessibilityFormatters.spokenCurrency(netWorth))")
                .accessibilityAddTraits(.isSummaryElement)
                
                // Assets & Liabilities - adaptive layout
                if isAccessibilitySize {
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Assets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            Text(formatCurrency(totalAssets))
                                .floCurrency(isPositive: true)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.incomeGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // v3.5: Assets card
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Assets: \(AccessibilityFormatters.spokenCurrency(totalAssets))")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Liabilities")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            Text(formatCurrency(totalLiabilities))
                                .floCurrency(isPositive: false)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.expenseRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // v3.5: Liabilities card
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Liabilities: \(AccessibilityFormatters.spokenCurrency(totalLiabilities))")
                    }
                } else {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Assets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            Text(formatCurrency(totalAssets))
                                .floCurrency(isPositive: true)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.incomeGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // v3.5: Assets card
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Assets: \(AccessibilityFormatters.spokenCurrency(totalAssets))")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Liabilities")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            
                            Text(formatCurrency(totalLiabilities))
                                .floCurrency(isPositive: false)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.expenseRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        // v3.5: Liabilities card
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Liabilities: \(AccessibilityFormatters.spokenCurrency(totalLiabilities))")
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Segment Picker Section
    
    private var segmentPickerSection: some View {
        Section {
            Picker("Filter", selection: $selectedSegment) {
                ForEach(FinanceSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedSegment) { _, newValue in
                HapticService.play(.light)
                // v3.5: Announce filter change
                AccessibilityAnnouncement.announce("Showing \(newValue.rawValue) accounts. \(filteredAccounts.count) found.")
            }
            // v3.5: VoiceOver
            .accessibilityLabel("Account filter: \(selectedSegment.rawValue)")
            .accessibilityHint("Choose to view all, business, or personal accounts")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }
    
    // MARK: - Active Accounts Section
    
    private var activeAccountsSection: some View {
        Section {
            ForEach(filteredAccounts) { account in
                AccountRowEnhanced(account: account)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticService.play(.light)
                        editAccount(account)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showingDeleteConfirmation = true
                            HapticService.play(.medium)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete account")
                        
                        Button {
                            HapticService.play(.light)
                            editAccount(account)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color.brandPrimary)
                        .accessibilityLabel("Edit account")
                    }
                    .swipeActions(edge: .leading) {
                        if !account.isPrimary {
                            Button {
                                setPrimaryAccount(account)
                            } label: {
                                Label("Set Primary", systemImage: "star.fill")
                            }
                            .tint(.orange)
                            .accessibilityLabel("Set as primary account")
                        }
                        
                        Button {
                            toggleDashboardVisibility(account)
                        } label: {
                            Label(
                                account.showOnDashboard ? "Hide" : "Show",
                                systemImage: account.showOnDashboard ? "eye.slash" : "eye"
                            )
                        }
                        .tint(account.showOnDashboard ? .gray : .blue)
                        .accessibilityLabel(account.showOnDashboard ? "Hide from dashboard" : "Show on dashboard")
                    }
                    // v3.5: Rotor actions for VoiceOver
                    .accessibilityAction(named: "Edit") {
                        editAccount(account)
                    }
                    .accessibilityAction(named: "Delete") {
                        accountToDelete = account
                        showingDeleteConfirmation = true
                    }
                    .accessibilityAction(named: account.isPrimary ? "Already primary" : "Set as primary") {
                        if !account.isPrimary { setPrimaryAccount(account) }
                    }
                    .accessibilityAction(named: account.showOnDashboard ? "Hide from dashboard" : "Show on dashboard") {
                        toggleDashboardVisibility(account)
                    }
            }
        } header: {
            HStack {
                Text("Active Accounts")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("\(filteredAccounts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.floCardGlass)
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active Accounts, \(filteredAccounts.count)")
            .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Swipe right to set primary or toggle dashboard visibility")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Inactive Accounts Section
    
    private var inactiveAccountsSection: some View {
        Section("Inactive Accounts") {
            ForEach(inactiveAccounts) { account in
                AccountRowEnhanced(account: account)
                    .opacity(0.6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticService.play(.light)
                        editAccount(account)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete account")
                        
                        Button {
                            reactivateAccount(account)
                        } label: {
                            Label("Activate", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                        .accessibilityLabel("Reactivate account")
                    }
                    // v3.5: Rotor actions
                    .accessibilityAction(named: "Reactivate") {
                        reactivateAccount(account)
                    }
                    .accessibilityAction(named: "Delete") {
                        accountToDelete = account
                        showingDeleteConfirmation = true
                    }
            }
        }
    }
    
    // MARK: - Empty State Section
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                AccountsIllustration()
                
                Text("No Accounts Yet")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text("Add your bank accounts and payment methods to track balances and see where your money goes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                
                Button {
                    handleAddAccount()
                } label: {
                    Label("Add Your First Account", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                .accessibilityLabel("Add your first account")
                .accessibilityHint("Double tap to create a new account")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .accessibilityElement(children: .contain)
        }
    }
    
    // MARK: - Suggested Accounts Section
    
    private var suggestedAccountsSection: some View {
        Section("Quick Add") {
            ForEach(suggestedAccounts, id: \.name) { suggestion in
                Button {
                    HapticService.play(.light)
                    createAccount(name: suggestion.name, type: suggestion.type, financeType: suggestion.financeType)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: suggestion.type.color).opacity(0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: suggestion.type.icon)
                                .font(.body)
                                .foregroundStyle(Color(hex: suggestion.type.color))
                        }
                        .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            HStack(spacing: 4) {
                                Text(suggestion.type.displayName)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("-")
                                Text(suggestion.financeType.rawValue.capitalized)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .font(.title3)
                            .accessibilityHidden(true)
                    }
                }
                // v3.5: VoiceOver
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quick add \(suggestion.name), \(suggestion.type.displayName), \(suggestion.financeType.rawValue.capitalized)")
                .accessibilityHint("Double tap to create this account")
            }
        }
    }
    
    // MARK: - Privacy Settings Section (v2.2)
    
    private var privacySettingsSection: some View {
        Section {
            Toggle(isOn: $hideBalancesOnDashboard) {
                HStack(spacing: 12) {
                    Image(systemName: hideBalancesOnDashboard ? "eye.slash.fill" : "eye.fill")
                        .font(.title3)
                        .foregroundStyle(hideBalancesOnDashboard ? Color.brandPrimary : .secondary)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide Balances on Dashboard")
                            .font(.body)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        
                        Text("Blur account balances until you tap to reveal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .tint(Color.brandPrimary)
            .onChange(of: hideBalancesOnDashboard) { _, _ in
                HapticService.play(.light)
            }
            // v3.5: VoiceOver
            .accessibilityLabel("Hide balances on dashboard")
            .accessibilityHint("When enabled, account balances are blurred on the dashboard until tapped")
            .accessibilityValue(hideBalancesOnDashboard ? "Enabled" : "Disabled")
        } header: {
            Label("Privacy", systemImage: "lock.shield")
        } footer: {
            Text("When enabled, your account balances will be hidden on the dashboard until you tap the Accounts card to reveal them. This helps protect your financial information when others might see your screen.")
                .lineLimit(5)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Account Limit Section (v3.4 Enhanced)
    
    private var accountUsagePercentage: Double {
        guard let limit = subscriptionManager.currentTier.accountLimit, limit > 0 else { return 0 }
        return min(1.0, Double(accounts.count) / Double(limit))
    }
    
    private var accountLimitColor: Color {
        let percentage = accountUsagePercentage
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else {
            return Color.brandPrimary
        }
    }
    
    private var accountLimitSection: some View {
        Section {
            if let limit = subscriptionManager.currentTier.accountLimit {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: accounts.count >= limit ? "exclamationmark.triangle.fill" : "building.columns")
                            .foregroundStyle(accountLimitColor)
                            .accessibilityHidden(true)
                        
                        Text("\(accounts.count) of \(limit) accounts")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(accounts.count >= limit ? accountLimitColor : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Spacer()
                        
                        if accounts.count >= limit {
                            Button {
                                HapticService.play(.medium)
                                showingLimitReached = true
                            } label: {
                                Text("Upgrade")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.brandPrimary)
                                    .clipShape(Capsule())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .accessibilityLabel("Upgrade subscription")
                            .accessibilityHint("Double tap to view plans with more accounts")
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.floCardBorder)
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(accountLimitColor)
                                .frame(width: geometry.size.width * accountUsagePercentage, height: 8)
                        }
                    }
                    .frame(height: 8)
                    // v3.5: Progress bar accessible
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Account usage")
                    .accessibilityValue("\(accounts.count) of \(limit) accounts used, \(Int(accountUsagePercentage * 100)) percent")
                    
                    if accounts.count >= limit {
                        Text("Account limit reached. Upgrade for more accounts.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    } else if accountUsagePercentage >= 0.8 {
                        Text("Approaching account limit.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "infinity")
                         .foregroundStyle(Color.brandPrimary)
                    
                    Text("Unlimited accounts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                    
                    Text("PRO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Unlimited accounts, Pro tier")
            }
        }
    }
    
    // MARK: - Plaid Bank Connection
    
    private var plaidConnectionSection: some View {
        Group {
            if subscriptionManager.currentTier.hasPlaidIntegration {
                // Pro users: Show Connect Bank button
                Section {
                    Button {
                        startPlaidLink()
                    } label: {
                        HStack(spacing: 12) {
                            if isLoadingLinkToken {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "building.columns.fill")
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isLoadingLinkToken ? "Connecting..." : "Connect Bank Account")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("Auto-import transactions via Plaid")
                                    .font(.caption)
                                    .opacity(0.8)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .opacity(0.6)
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.brandPrimary)
                        .cornerRadius(10)
                    }
                    .disabled(isLoadingLinkToken)
                    .accessibilityLabel(isLoadingLinkToken ? "Connecting to bank" : "Connect bank account")
                    .accessibilityHint("Double tap to link a bank account via Plaid for automatic transaction import")

                    if !linkedAccounts.isEmpty {
                        Button {
                            HapticService.play(.medium)
                            Task { await refreshFromPlaid() }
                        } label: {
                            HStack(spacing: 12) {
                                if plaidService.isSyncing {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(Color.brandPrimary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plaidService.isSyncing ? "Refreshing..." : "Refresh Balances & Transactions")
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text(lastPlaidRefreshText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                Spacer()
                            }
                        }
                        .disabled(plaidService.isSyncing)
                        .accessibilityLabel(plaidService.isSyncing ? "Refreshing bank data" : "Refresh balances and transactions")
                        .accessibilityHint("Double tap to fetch the latest balances and transactions from your linked banks")

                        Button {
                            HapticService.play(.light)
                            showingConnectedAccounts = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(Color.brandPrimary)
                                Text("Manage Connections")
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text("\(linkedAccounts.count)")
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .accessibilityLabel("Manage bank connections. \(linkedAccounts.count) linked.")
                        .accessibilityHint("Double tap to view linked banks, sync status, and disconnect accounts")
                    }
                } header: {
                    Text("Bank Connection")
                } footer: {
                    if !linkedAccounts.isEmpty {
                        Text("You can also pull down on this screen to refresh.")
                    }
                }
            } else {
                // Non-Pro users: Upgrade teaser
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Import Transactions")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("Connect your bank with Plaid — Pro feature")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                        Button("Upgrade") {
                            showingUpgradePrompt = true
                            HapticService.play(.medium)
                        }
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Auto-import transactions. Connect your bank with Plaid. Pro feature.")
                    .accessibilityHint("Double tap the upgrade button to view Pro subscription options")
                } header: {
                    Text("Bank Connection")
                }
            }
        }
    }
    
    // MARK: - Plaid Refresh

    private var lastPlaidRefreshText: String {
        if let lastSync = plaidService.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last updated \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        }
        return "Fetch the latest balances and transactions"
    }

    /// Fetches current balances and new transactions for all linked accounts.
    /// No-ops for non-Pro tiers or when nothing is linked, so pull-to-refresh
    /// is safe to leave enabled for everyone.
    private func refreshFromPlaid() async {
        guard subscriptionManager.currentTier.hasPlaidIntegration,
              !linkedAccounts.isEmpty,
              !plaidService.isSyncing else { return }

        do {
            try await plaidService.updateAccountBalances(modelContext: modelContext)
            _ = try await plaidService.syncAllTransactions(modelContext: modelContext)
            HapticService.play(.success)
        } catch {
            plaidError = error.localizedDescription
            HapticService.play(.error)
        }
    }

    // MARK: - Helper Methods

    private func handleAddAccount() {
        HapticService.play(.medium)
        guard canAddMoreAccounts else {
            showingLimitReached = true
            return
        }
        // Build 10 Phase 2: Route to Zone 3 detail column on regular width
        // (macOS, iPad landscape). Fall back to sheet on compact (iPhone, iPad portrait).
        if useZone3 {
            withAnimation(FLOAnimation.quick) {
                NavigationService.shared.selectedDetail = .addAccount
            }
        } else {
            showingAddAccount = true
        }
    }

    /// Whether detail add/edit should be hosted in the Zone 3 detail pane instead
    /// of a sheet. True on a wide split-view layout — native macOS always, and
    /// iPad landscape / a wide Mac Catalyst window via the size class — false on
    /// compact (iPhone, narrow Catalyst window). Replaces the old hard
    /// `#if os(macOS)` switch, which was dead on Catalyst.
    private var useZone3: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    /// Edit an account: route to the Zone 3 detail pane on a wide layout, else
    /// present the edit sheet. `requestDetailNavigation` lets an in-progress
    /// Zone 3 edit prompt for confirmation before being discarded.
    private func editAccount(_ account: Account) {
        if useZone3 {
            NavigationService.shared.requestDetailNavigation(to: .accountDetail(id: account.id))
        } else {
            accountToEdit = account
        }
    }
    
    private func deleteAccount(_ account: Account) {
        let name = account.name
        HapticService.play(.heavy)
        do {
            try AccountBalanceService.shared.safelyDeleteAccount(account, context: modelContext)
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(name) deleted")
        } catch {
            print("Failed to delete account: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func setPrimaryAccount(_ account: Account) {
        HapticService.play(.medium)
        
        for acc in accounts where acc.isPrimary {
            acc.isPrimary = false
        }
        
        account.isPrimary = true
        account.touch()
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(account.name) set as primary account")
        } catch {
            print("Failed to set primary account: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func toggleDashboardVisibility(_ account: Account) {
        HapticService.play(.light)
        account.showOnDashboard.toggle()
        account.touch()
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(account.name) \(account.showOnDashboard ? "shown on" : "hidden from") dashboard")
        } catch {
            print("Failed to toggle dashboard visibility: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func reactivateAccount(_ account: Account) {
        HapticService.play(.medium)
        account.isActive = true
        account.touch()
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(account.name) reactivated")
        } catch {
            print("Failed to reactivate account: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func createAccount(name: String, type: AccountType, financeType: Transaction.FinanceType) {
        let account = Account(
            name: name,
            accountType: type,
            isPrimary: accounts.isEmpty,
            financeType: financeType
        )
        
        modelContext.insert(account)
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(name) account created")
        } catch {
            print("Failed to create account: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    // MARK: - Plaid Link Methods (v3.3)
    
    private func startPlaidLink() {
        isLoadingLinkToken = true
        plaidError = nil
        
        Task {
            do {
                let linkToken = try await plaidService.createLinkToken()
                await MainActor.run {
                    self.plaidLinkToken = linkToken
                    self.isLoadingLinkToken = false
                    self.showingPlaidLink = true
                }
            } catch {
                await MainActor.run {
                    self.isLoadingLinkToken = false
                    self.plaidError = error.localizedDescription
                    HapticService.play(.error)
                }
            }
        }
    }
    
    private func handlePlaidSuccess(_ metadata: LinkMetadata) {
        showingPlaidLink = false
        plaidLinkToken = nil
        HapticService.play(.success)
        
        Task {
            do {
                let itemId = try await plaidService.exchangePublicToken(
                    metadata.publicToken,
                    metadata: metadata
                )

                await MainActor.run {
                    do {
                        try plaidService.createAccounts(
                            from: metadata,
                            itemId: itemId,
                            modelContext: modelContext
                        )
                        HapticService.play(.success)
                        print("✅ Bank connected: \(metadata.institutionName ?? "Unknown") — \(metadata.accounts.count) account(s) created")
                    } catch {
                        print("❌ Failed to save accounts: \(error)")
                        HapticService.play(.error)
                    }
                }
                
                // Fetch real account balances from Plaid
                do {
                    try await plaidService.updateAccountBalances(modelContext: modelContext)
                    print("✅ Account balances updated")
                } catch {
                    print("⚠️ Balance fetch failed (non-blocking): \(error)")
                }
                
                // Attempt initial transaction sync (non-blocking)
                do {
                    _ = try await plaidService.syncAllTransactions(modelContext: modelContext)
                    print("✅ Initial transaction sync complete")
                } catch {
                    // Sync can fail if edge function format differs — not critical
                    print("⚠️ Transaction sync failed (non-blocking): \(error)")
                }
                
            } catch {
                await MainActor.run {
                    plaidError = "Failed to connect bank: \(error.localizedDescription)"
                    HapticService.play(.error)
                    print("❌ Plaid error: \(error)")
                }
            }
        }
    }
    
    private func handlePlaidExit(_ error: PlaidError?) {
        showingPlaidLink = false
        plaidLinkToken = nil
        
        if let error = error {
            if case .userCancelled = error {
                return
            }
            plaidError = error.localizedDescription
            HapticService.play(.error)
        }
    }
    
    // MARK: - Suggested Accounts Data
    
    private var suggestedAccounts: [(name: String, type: AccountType, financeType: Transaction.FinanceType)] {
        [
            ("Business Checking", .checking, .business),
            ("Personal Checking", .checking, .personal),
            ("Business Savings", .savings, .business),
            ("Cash on Hand", .cash, .personal),
            ("Business Credit Card", .creditCard, .business),
            ("Personal Credit Card", .creditCard, .personal)
        ]
    }
}

// MARK: - Preview

#Preview("With Accounts") {
    NavigationStack {
        AccountsView()
    }
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: [Account.self, InvoicePayment.self, Transaction.self])
}

#Preview("Empty State") {
    NavigationStack {
        AccountsView()
    }
    .environmentObject(SubscriptionManager.shared)
    .modelContainer(for: [Account.self, InvoicePayment.self, Transaction.self], inMemory: true)
}
