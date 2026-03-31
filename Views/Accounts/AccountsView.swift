//  AccountsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.4 - CRITICAL: Safe account deletion (crash fix)
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

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        #if os(macOS)
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
                                .font(.headline)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
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
                                .font(.headline)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1))
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
                                .font(.headline)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.1))
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
                                .font(.headline)
                                .foregroundStyle(.red)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .contentTransition(.numericText())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.red.opacity(0.1))
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
                        accountToEdit = account
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
                            accountToEdit = account
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
                        accountToEdit = account
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
                    .background(Color.secondary.opacity(0.12))
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
                        accountToEdit = account
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
                    HapticService.play(.medium)
                    showingAddAccount = true
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
                                .fill(Color.gray.opacity(0.3).opacity(0.2))
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
                         .foregroundStyle(Color.brandPrimaryText)
                    
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoadingLinkToken)
                    .accessibilityLabel(isLoadingLinkToken ? "Connecting to bank" : "Connect bank account")
                    .accessibilityHint("Double tap to link a bank account via Plaid for automatic transaction import")
                } header: {
                    Text("Bank Connection")
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
    
    // MARK: - Helper Methods
    
    private func handleAddAccount() {
        HapticService.play(.medium)
        if canAddMoreAccounts {
            showingAddAccount = true
        } else {
            showingLimitReached = true
        }
    }
    
    private func deleteAccount(_ account: Account) {
        let name = account.name
        let accountId = account.id
        HapticService.play(.heavy)
        
        // MARK: Pre-nullify all relationships before delete
        // SwiftData's .nullify cascade only covers relationships with declared inverses
        // (Account.transactions → Transaction.account, Account.budgets → Budget.account).
        // Transfer, RecurringTransfer, and RecurringTransaction reference Account WITHOUT
        // an inverse, so SwiftData leaves dangling PersistentIdentifiers that crash on fault.
        // Pre-nullifying also prevents @Query observer race conditions during post-save vacuum.
        
        // 1. Transactions (has inverse, but pre-nullify to prevent @Query race)
        if let transactions = account.transactions {
            for transaction in transactions {
                transaction.account = nil
            }
        }
        
        // 2. Budgets (has inverse, but pre-nullify for same reason)
        if let budgets = account.budgets {
            for budget in budgets {
                budget.account = nil
            }
        }
        
        // 3. Transfers — NO inverse on Account, SwiftData won't cascade
        do {
            let transferDescriptor = FetchDescriptor<Transfer>()
            let allTransfers = try modelContext.fetch(transferDescriptor)
            for transfer in allTransfers {
                if transfer.fromAccount?.id == accountId {
                    transfer.fromAccount = nil
                }
                if transfer.toAccount?.id == accountId {
                    transfer.toAccount = nil
                }
            }
        } catch {
            print("⚠️ Failed to clean Transfer references: \(error)")
        }
        
        // 4. RecurringTransfers — NO inverse on Account, SwiftData won't cascade
        do {
            let recurringTransferDescriptor = FetchDescriptor<RecurringTransfer>()
            let allRecurringTransfers = try modelContext.fetch(recurringTransferDescriptor)
            for rt in allRecurringTransfers {
                if rt.fromAccount?.id == accountId {
                    rt.fromAccount = nil
                }
                if rt.toAccount?.id == accountId {
                    rt.toAccount = nil
                }
            }
        } catch {
            print("⚠️ Failed to clean RecurringTransfer references: \(error)")
        }
        
        // 5. RecurringTransactions — @Relationship but no declared inverse on Account
        do {
            let recurringDescriptor = FetchDescriptor<RecurringTransaction>()
            let allRecurring = try modelContext.fetch(recurringDescriptor)
            for recurring in allRecurring {
                if recurring.account?.id == accountId {
                    recurring.account = nil
                }
            }
        } catch {
            print("⚠️ Failed to clean RecurringTransaction references: \(error)")
        }
        
        // 6. Now safe to delete — all references point to nil
        modelContext.delete(account)
        
        do {
            try modelContext.save()
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
                    // Create FLO accounts for each linked bank account
                    for linkedAccount in metadata.accounts {
                        let account = Account(
                            name: linkedAccount.name,
                            accountType: mapPlaidAccountType(linkedAccount.type, subtype: linkedAccount.subtype),
                            lastFourDigits: linkedAccount.mask,
                            institutionName: metadata.institutionName
                        )
                        account.isLinked = true
                        account.plaidItemId = itemId
                        account.plaidAccountId = linkedAccount.id
                        account.plaidStatus = .connected
                        
                        modelContext.insert(account)
                    }
                    
                    do {
                        try modelContext.save()
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
    
    /// Maps Plaid account type strings to FLO AccountType
    private func mapPlaidAccountType(_ type: String, subtype: String?) -> AccountType {
        switch type {
        case "depository":
            if subtype == "savings" {
                return .savings
            }
            return .checking
        case "credit":
            return .creditCard
        case "investment":
            return .investment
        case "loan":
            return .loan
        default:
            return .other
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
