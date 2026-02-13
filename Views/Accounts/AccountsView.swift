//  AccountsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.5 - Accessibility Audit + Architecture: Split into focused files
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.5:
//  ✅ SPLIT: Extracted AccountRowEnhanced → AccountRowEnhanced.swift
//  ✅ SPLIT: Extracted AddAccountView → AddAccountView_Accounts.swift
//  ✅ SPLIT: Extracted EditAccountView → EditAccountView_Accounts.swift
//  ✅ SPLIT: Extracted AccountRowPreview → AccountRowPreview.swift
//  ✅ ADDED: Add button VoiceOver label + hint
//  ✅ ADDED: Balance summary cards accessible with spoken currency
//  ✅ ADDED: Net worth/assets/liabilities grouped labels
//  ✅ ADDED: Segment picker VoiceOver label with current value
//  ✅ ADDED: Rotor actions (Edit, Delete, Set Primary, Toggle Dashboard)
//  ✅ ADDED: Empty state accessible
//  ✅ ADDED: Suggested accounts VoiceOver labels
//  ✅ ADDED: Privacy toggle VoiceOver label + hint
//  ✅ ADDED: Account limit progress bar accessible with value
//  ✅ ADDED: Upgrade button labeled
//  ✅ ADDED: Screen change announcements
//  ✅ ADDED: Delete/reactivate/primary announced
//
//  CHANGES v3.4:
//  - Added LimitReachedOverlay full-screen when at account limit
//  - Added progress bar to account limit section
//

import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
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
    
    enum FinanceSegment: String, CaseIterable {
        case all = "All"
        case business = "Business"
        case personal = "Personal"
    }
    
    // MARK: - Filtered Accounts
    
    private var filteredAccounts: [Account] {
        let active = accounts.filter { $0.isActive }
        switch selectedSegment {
        case .all:
            return active
        case .business:
            return active.filter { $0.financeType == .business }
        case .personal:
            return active.filter { $0.financeType == .personal }
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
                privacySettingsSection
            }
            
            if !accounts.isEmpty {
                accountLimitSection
            }
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
        .alert("Connection Error", isPresented: .init(
            get: { plaidError != nil },
            set: { if !$0 { plaidError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(plaidError ?? "An error occurred connecting to your bank.")
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateBalances = true
            }
            // v3.5: Announce screen
            AccessibilityAnnouncement.screenChanged("Accounts. \(accounts.count) total.")
        }
    }
    
    // MARK: - Balance Summary Section
    
    private var balanceSummarySection: some View {
        Section {
            VStack(spacing: 12) {
                // Net Worth Card
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Worth")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(formatCurrency(netWorth))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(netWorth >= 0 ? Color.brandPrimary : .red)
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
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                // v3.5: Net worth accessible
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Net worth: \(AccessibilityFormatters.spokenCurrency(netWorth))")
                .accessibilityAddTraits(.isSummaryElement)
                
                // Assets & Liabilities
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundStyle(.green)
                            Text("Assets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(formatCurrency(totalAssets))
                            .font(.headline)
                            .foregroundStyle(.green)
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
                        }
                        
                        Text(formatCurrency(totalLiabilities))
                            .font(.headline)
                            .foregroundStyle(.red)
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
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Segment Picker Section
    
    private var segmentPickerSection: some View {
        Section {
            Picker("Filter", selection: $selectedSegment) {
                ForEach(FinanceSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
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
                Spacer()
                Text("\(filteredAccounts.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Active Accounts, \(filteredAccounts.count)")
            .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Swipe right to set primary or toggle dashboard visibility")
                .font(.caption)
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
                Image(systemName: "building.columns")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandPrimary.opacity(0.6))
                    .symbolEffect(.pulse, options: .repeating)
                    // v3.5: Decorative
                    .accessibilityHidden(true)
                
                Text("No Accounts Yet")
                    .font(.headline)
                
                Text("Add your bank accounts and payment methods to track balances and see where your money goes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    HapticService.play(.medium)
                    showingAddAccount = true
                } label: {
                    Label("Add Your First Account", systemImage: "plus.circle.fill")
                        .font(.headline)
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
                            
                            HStack(spacing: 4) {
                                Text(suggestion.type.displayName)
                                Text("-")
                                Text(suggestion.financeType.rawValue.capitalized)
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
                        
                        Text("Blur account balances until you tap to reveal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                            }
                            .accessibilityLabel("Upgrade subscription")
                            .accessibilityHint("Double tap to view plans with more accounts")
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
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
                    } else if accountUsagePercentage >= 0.8 {
                        Text("Approaching account limit.")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
                    
                    Spacer()
                    
                    Text("PRO")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.brandPrimary)
                        .clipShape(Capsule())
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Unlimited accounts, Pro tier")
            }
            
            // Plaid integration teaser - TEMPORARILY HIDDEN for App Store launch
            /*
            if !subscriptionManager.currentTier.hasPlaidIntegration {
                ...
            } else {
                ...
            }
            */
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
        HapticService.play(.heavy)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
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
                _ = try await plaidService.exchangePublicToken(
                    metadata.publicToken,
                    metadata: metadata
                )
                
                await MainActor.run {
                    HapticService.play(.success)
                    print("Bank connected successfully: \(metadata.institutionName ?? "Unknown")")
                }
            } catch {
                await MainActor.run {
                    plaidError = "Failed to connect bank: \(error.localizedDescription)"
                    HapticService.play(.error)
                    print("Plaid error: \(error)")
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
