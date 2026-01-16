//  AccountsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Fixed FinanceType to use Transaction.FinanceType - Enhanced with balance tracking and subscription gating
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Balance tracking display with color-coded status
//  ✅ Business/Personal segmentation
//  ✅ Subscription tier feature gating
//  ✅ Account statistics (transaction count, net change)
//  ✅ Enhanced haptic feedback throughout
//  ✅ Smooth animations and transitions
//  ✅ Total balance summary cards
//  ✅ Plaid integration indicators (Pro tier)
//
//  CHANGES v2.0:
//  ✅ Added balance display in account rows
//  ✅ Added summary cards for total balances
//  ✅ Added financeType segmentation
//  ✅ Added subscription limit checking
//  ✅ Added upgrade prompts for locked features
//  ✅ Enhanced animations with spring physics
//  ✅ Improved haptic feedback
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
    @State private var selectedSegment: FinanceSegment = .all
    @State private var animateBalances = false
    
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
            // Summary Cards (Premium+ feature)
            if subscriptionManager.currentTier.hasBalanceTracking && !filteredAccounts.isEmpty {
                balanceSummarySection
            }
            
            // Segment Picker
            if !accounts.isEmpty {
                segmentPickerSection
            }
            
            // Active Accounts
            if !filteredAccounts.isEmpty {
                activeAccountsSection
            }
            
            // Inactive Accounts
            if !inactiveAccounts.isEmpty && selectedSegment == .all {
                inactiveAccountsSection
            }
            
            // Empty State
            if accounts.isEmpty {
                emptyStateSection
            }
            
            // Suggested Accounts (only for empty state)
            if accounts.isEmpty {
                suggestedAccountsSection
            }
            
            // Account Limit Info
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
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateBalances = true
            }
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
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Assets & Liabilities
                HStack(spacing: 12) {
                    // Assets
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
                    
                    // Liabilities
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
            .onChange(of: selectedSegment) { _, _ in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        accountToEdit = account
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showingDeleteConfirmation = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            accountToEdit = account
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(Color.brandPrimary)
                    }
                    .swipeActions(edge: .leading) {
                        if !account.isPrimary {
                            Button {
                                setPrimaryAccount(account)
                            } label: {
                                Label("Set Primary", systemImage: "star.fill")
                            }
                            .tint(.orange)
                        }
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
        } footer: {
            Text("Swipe right to set as primary • Tap to edit")
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        accountToEdit = account
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            accountToDelete = account
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            reactivateAccount(account)
                        } label: {
                            Label("Activate", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
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
                
                Text("No Accounts Yet")
                    .font(.headline)
                
                Text("Add your bank accounts and payment methods to track balances and see where your money goes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showingAddAccount = true
                } label: {
                    Label("Add Your First Account", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }
    
    // MARK: - Suggested Accounts Section
    
    private var suggestedAccountsSection: some View {
        Section("Quick Add") {
            ForEach(suggestedAccounts, id: \.name) { suggestion in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 4) {
                                Text(suggestion.type.displayName)
                                Text("•")
                                Text(suggestion.financeType.rawValue.capitalized)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Account Limit Section
    
    private var accountLimitSection: some View {
        Section {
            if let limit = subscriptionManager.currentTier.accountLimit {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.brandPrimary)
                    
                    Text("\(accounts.count) of \(limit) accounts used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if accounts.count >= limit {
                        Button("Upgrade") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingUpgradePrompt = true
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandPrimary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "infinity.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                    
                    Text("Unlimited accounts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Plaid integration teaser for non-Pro users
            if !subscriptionManager.currentTier.hasPlaidIntegration {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showingUpgradePrompt = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect Your Bank")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            Text("Auto-sync transactions with Pro")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("PRO")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Suggested Accounts Data
    
    private var suggestedAccounts: [(name: String, type: AccountType, financeType: Transaction.FinanceType)] {
        [
            ("Business Checking", .checking, .business),
            ("Business Savings", .savings, .business),
            ("Personal Checking", .checking, .personal),
            ("PayPal", .paypal, .business),
            ("Cash", .cash, .business)
        ]
    }
    
    // MARK: - Actions
    
    private func handleAddAccount() {
        if canAddMoreAccounts {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingAddAccount = true
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showingUpgradePrompt = true
        }
    }
    
    private func setPrimaryAccount(_ account: Account) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Remove primary from all others
        for acc in accounts where acc.isPrimary {
            acc.isPrimary = false
        }
        
        // Set new primary
        account.isPrimary = true
        account.touch()
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to set primary account: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    private func reactivateAccount(_ account: Account) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            account.isActive = true
            account.touch()
        }
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to reactivate account: \(error)")
        }
    }
    
    private func deleteAccount(_ account: Account) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            modelContext.delete(account)
        }
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to delete account: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        accountToDelete = nil
    }
    
    private func createAccount(name: String, type: AccountType, financeType: Transaction.FinanceType) {
        guard canAddMoreAccounts else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            showingUpgradePrompt = true
            return
        }
        
        let account = Account(
            name: name,
            accountType: type,
            isPrimary: accounts.isEmpty,
            financeType: financeType
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            modelContext.insert(account)
        }
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to create account: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Enhanced Account Row

struct AccountRowEnhanced: View {
    let account: Account
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Account Icon
            ZStack {
                Circle()
                    .fill(Color(hex: account.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: account.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: account.color))
            }
            
            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if account.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    if account.isLinked {
                        Image(systemName: "link.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(account.accountType.displayName)
                    
                    Text("•")
                    
                    Text(account.financeType.displayName)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("•")
                        Text("•••• \(digits)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Balance (if Premium+)
            if subscriptionManager.currentTier.hasBalanceTracking {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(account.currentBalance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(balanceColor)
                    
                    if account.transactionCount > 0 {
                        Text("\(account.transactionCount) txns")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var balanceColor: Color {
        if account.isLiability {
            return account.currentBalance >= 0 ? .green : .primary
        } else {
            return account.currentBalance >= 0 ? (account.currentBalance > 0 ? .green : .primary) : .red
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Add Account View (Enhanced)

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \Account.name) private var existingAccounts: [Account]
    
    @State private var name = ""
    @State private var accountType: AccountType = .checking
    @State private var financeType: Transaction.FinanceType = .business
    @State private var isPrimary = false
    @State private var notes = ""
    @State private var startingBalance: String = ""
    @State private var lastFourDigits = ""
    @State private var institutionName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Details
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Picker("Classification", selection: $financeType) {
                        ForEach(Transaction.FinanceType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                // Balance (Premium feature)
                if subscriptionManager.currentTier.hasBalanceTracking {
                    Section("Starting Balance") {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $startingBalance)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                // Bank Details (Optional)
                Section("Bank Details (Optional)") {
                    TextField("Institution Name", text: $institutionName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.prefix(4))
                        }
                }
                
                // Settings
                Section {
                    Toggle("Set as Primary Account", isOn: $isPrimary)
                } footer: {
                    Text("Primary account is selected by default for new transactions")
                }
                
                // Notes
                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Preview
                Section("Preview") {
                    AccountRowPreview(
                        name: name.isEmpty ? "Account Name" : name,
                        accountType: accountType,
                        financeType: financeType,
                        isPrimary: isPrimary,
                        balance: Double(startingBalance) ?? 0,
                        lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits
                    )
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveAccount() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // If setting as primary, remove primary from others
        if isPrimary {
            for account in existingAccounts where account.isPrimary {
                account.isPrimary = false
            }
        }
        
        let balance = Double(startingBalance) ?? 0
        
        let account = Account(
            name: name.trimmingCharacters(in: .whitespaces),
            accountType: accountType,
            isPrimary: isPrimary || existingAccounts.isEmpty,
            notes: notes,
            currentBalance: balance,
            startingBalance: balance,
            financeType: financeType,
            lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits,
            institutionName: institutionName.isEmpty ? nil : institutionName
        )
        
        modelContext.insert(account)
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            print("❌ Failed to save account: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

// MARK: - Account Row Preview (for Add/Edit)

struct AccountRowPreview: View {
    let name: String
    let accountType: AccountType
    let financeType: Transaction.FinanceType
    let isPrimary: Bool
    let balance: Double
    let lastFourDigits: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: accountType.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: accountType.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: accountType.color))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(name == "Account Name" ? .secondary : .primary)
                    
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(accountType.displayName)
                    Text("•")
                    Text(financeType.rawValue.capitalized)
                    
                    if let digits = lastFourDigits {
                        Text("•")
                        Text("•••• \(digits)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if balance != 0 {
                Text(formatCurrency(balance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Edit Account View (Enhanced)

struct EditAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \Account.name) private var allAccounts: [Account]
    
    let account: Account
    
    @State private var name: String
    @State private var accountType: AccountType
    @State private var financeType: Transaction.FinanceType
    @State private var isPrimary: Bool
    @State private var isActive: Bool
    @State private var notes: String
    @State private var currentBalance: String
    @State private var lastFourDigits: String
    @State private var institutionName: String
    
    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _accountType = State(initialValue: account.accountType)
        _financeType = State(initialValue: account.financeType)
        _isPrimary = State(initialValue: account.isPrimary)
        _isActive = State(initialValue: account.isActive)
        _notes = State(initialValue: account.notes)
        _currentBalance = State(initialValue: String(format: "%.2f", account.currentBalance))
        _lastFourDigits = State(initialValue: account.lastFourDigits ?? "")
        _institutionName = State(initialValue: account.institutionName ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Picker("Classification", selection: $financeType) {
                        ForEach(Transaction.FinanceType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }
                
                // Balance (Premium feature)
                if subscriptionManager.currentTier.hasBalanceTracking {
                    Section("Current Balance") {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $currentBalance)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                // Bank Details
                Section("Bank Details (Optional)") {
                    TextField("Institution Name", text: $institutionName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.prefix(4))
                        }
                }
                
                Section {
                    Toggle("Primary Account", isOn: $isPrimary)
                    Toggle("Active", isOn: $isActive)
                } footer: {
                    Text("Inactive accounts won't appear in transaction selections")
                }
                
                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Statistics
                if account.transactionCount > 0 {
                    Section("Statistics") {
                        HStack {
                            Text("Transactions")
                            Spacer()
                            Text("\(account.transactionCount)")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Total Income")
                            Spacer()
                            Text(formatCurrency(account.totalIncome))
                                .foregroundStyle(.green)
                        }
                        
                        HStack {
                            Text("Total Expenses")
                            Spacer()
                            Text(formatCurrency(account.totalExpenses))
                                .foregroundStyle(.red)
                        }
                        
                        HStack {
                            Text("Net Change")
                            Spacer()
                            Text(formatCurrency(account.netChange))
                                .foregroundStyle(account.netChange >= 0 ? .green : .red)
                        }
                    }
                }
                
                // Plaid Status (if linked)
                if account.isLinked {
                    Section("Bank Connection") {
                        HStack {
                            Image(systemName: account.plaidStatus.icon)
                                .foregroundStyle(Color(hex: account.plaidStatus.color))
                            Text(account.plaidStatus.displayName)
                            Spacer()
                            Text(account.lastSyncDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Button(role: .destructive) {
                            disconnectPlaid()
                        } label: {
                            Label("Disconnect Bank", systemImage: "link.badge.minus")
                        }
                    }
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveChanges() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // If setting as primary, remove primary from others
        if isPrimary && !account.isPrimary {
            for acc in allAccounts where acc.isPrimary && acc.id != account.id {
                acc.isPrimary = false
            }
        }
        
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.accountType = accountType
        account.financeType = financeType
        account.isPrimary = isPrimary
        account.isActive = isActive
        account.notes = notes
        account.currentBalance = Double(currentBalance) ?? account.currentBalance
        account.lastBalanceUpdate = Date()
        account.lastFourDigits = lastFourDigits.isEmpty ? nil : lastFourDigits
        account.institutionName = institutionName.isEmpty ? nil : institutionName
        account.touch()
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            print("❌ Failed to save account changes: \(error)")
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    private func disconnectPlaid() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        account.disconnectPlaid()
        
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            print("❌ Failed to disconnect Plaid: \(error)")
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
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
