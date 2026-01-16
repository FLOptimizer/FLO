//  AddRecurringView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2.1 - Fixed FinanceType comparison issues
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.2:
//  ✅ FIXED: FinanceType comparison (Account now uses Transaction.FinanceType)
//  ✅ FIXED: Used .displayName instead of .rawValue for display strings
//  ✅ FIXED: Explicit type annotations in sorted closure
//
//  CHANGES FROM v2.1.1:
//  ✅ ADDED: Account selection with horizontal chips (Premium+)
//  ✅ ADDED: Smart account defaults based on financeType
//  ✅ ADDED: Account stored with RecurringTransaction for auto-apply
//  ✅ Enhanced haptic feedback throughout
//

import SwiftUI
import SwiftData

struct AddRecurringView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    let preselectedFinanceType: Transaction.FinanceType?
    
    @State private var amount = ""
    @State private var merchantName = ""
    @State private var note = ""
    @State private var isIncome = false
    @State private var financeType: Transaction.FinanceType = .personal
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    
    init(preselectedFinanceType: Transaction.FinanceType? = nil) {
        self.preselectedFinanceType = preselectedFinanceType
    }
    
    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                financeTypeSection
                categorySection
                accountSection
                frequencySection
                scheduleSection
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let preselected = preselectedFinanceType {
                    financeType = preselected
                }
                setDefaultAccount()
            }
            .onChange(of: financeType) { _, newType in
                updateAccountForFinanceType(newType)
            }
        }
    }
    
    // MARK: - Sections
    
    private var typeSection: some View {
        Section {
            Picker("Type", selection: $isIncome) {
                Label("Expense", systemImage: "arrow.up.circle.fill")
                    .tag(false)
                Label("Income", systemImage: "arrow.down.circle.fill")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isIncome) { _, _ in
                HapticService.play(.light)
            }
        }
    }
    
    private var detailsSection: some View {
        Section {
            TextField("Merchant Name", text: $merchantName)
                .textContentType(.organizationName)
            
            TextField("Description (optional)", text: $note)
            
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Details")
        } footer: {
            Text("Enter merchant name for better organization")
        }
    }
    
    private var financeTypeSection: some View {
        Section("Classification") {
            Picker("Type", selection: $financeType) {
                Label("Business", systemImage: "briefcase.fill")
                    .tag(Transaction.FinanceType.business)
                Label("Personal", systemImage: "person.fill")
                    .tag(Transaction.FinanceType.personal)
            }
            .pickerStyle(.segmented)
            .onChange(of: financeType) { _, _ in
                HapticService.play(.light)
            }
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Category?.none)
                
                if isIncome {
                    ForEach(organizedIncomeCategories) { category in
                        categoryLabel(for: category)
                    }
                } else {
                    Section(header: Text("BUSINESS")) {
                        ForEach(organizedBusinessCategories) { category in
                            categoryLabel(for: category)
                        }
                    }
                    
                    Section(header: Text("PERSONAL")) {
                        ForEach(organizedPersonalCategories) { category in
                            categoryLabel(for: category)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Account Section
    
    @ViewBuilder
    private var accountSection: some View {
        if subscriptionManager.currentTier.hasMultipleAccounts && !accounts.isEmpty {
            Section {
                accountChipsView
            } header: {
                HStack {
                    Text("Account")
                    Spacer()
                    if selectedAccount != nil {
                        Button("Clear") {
                            withAnimation(FLOAnimation.quick) {
                                selectedAccount = nil
                            }
                            HapticService.play(.light)
                        }
                        .font(.caption)
                        .foregroundStyle(Color.brandPrimary)
                    }
                }
            } footer: {
                accountFooterText
            }
        }
    }
    
    @ViewBuilder
    private var accountChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(sortedAccounts) { account in
                    RecurringAccountChip(
                        account: account,
                        isSelected: selectedAccount?.id == account.id,
                        showBalance: subscriptionManager.currentTier.hasBalanceTracking
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            if selectedAccount?.id == account.id {
                                selectedAccount = nil
                            } else {
                                selectedAccount = account
                            }
                        }
                        HapticService.play(.medium)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    
    @ViewBuilder
    private var accountFooterText: some View {
        if selectedAccount == nil {
            Text("Generated transactions won't be assigned to a specific account")
        } else if let account = selectedAccount, account.financeType != financeType {
            Label("Account type differs from transaction classification", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("All generated transactions will use \(selectedAccount?.name ?? "this account")")
        }
    }
    
    private func categoryLabel(for category: Category) -> some View {
        Label {
            Text(category.name)
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(Color(flowHex: category.colorHex))
        }
        .tag(Optional(category))
    }
    
    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Repeats", selection: $frequency) {
                ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                    Label {
                        Text(freq.displayName)
                    } icon: {
                        Image(systemName: freq.systemImageName)
                    }
                    .tag(freq)
                }
            }
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
            
            Toggle("Set End Date", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, _ in
                    HapticService.play(.light)
                }
            
            if hasEndDate {
                DatePicker("Ends", selection: $endDate, displayedComponents: .date)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCategories: [Category] {
        categories.filter { $0.isIncome == isIncome }
    }
    
    /// Accounts sorted: matching financeType first, then primary, then others
    private var sortedAccounts: [Account] {
        let active = accounts.filter { $0.isActive }
        
        return active.sorted { (a: Account, b: Account) -> Bool in
            // First: match financeType
            if a.financeType == financeType && b.financeType != financeType { return true }
            if b.financeType == financeType && a.financeType != financeType { return false }
            
            // Second: primary accounts
            if a.isPrimary && !b.isPrimary { return true }
            if b.isPrimary && !a.isPrimary { return false }
            
            // Third: alphabetical
            return a.name < b.name
        }
    }
    
    // MARK: - Category Organization Helpers
    
    private var organizedIncomeCategories: [Category] {
        categories
            .filter { $0.isIncome == true }
            .sorted { $0.name < $1.name }
    }
    
    private var organizedBusinessCategories: [Category] {
        categories
            .filter { $0.isIncome == false && isBusinessCategory($0) }
            .sorted { $0.name < $1.name }
    }
    
    private var organizedPersonalCategories: [Category] {
        categories
            .filter { $0.isIncome == false && !isBusinessCategory($0) }
            .sorted { $0.name < $1.name }
    }
    
    private func isBusinessCategory(_ category: Category) -> Bool {
        let businessKeywords = ["(Business)", "Business Travel", "Office", "Professional",
                               "Contract Labor", "Marketing", "Advertising", "Software & Subscriptions"]
        return businessKeywords.contains { category.name.contains($0) }
    }
    
    private var isValid: Bool {
        guard !merchantName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let amt = Double(amount), amt > 0 else { return false }
        return true
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        guard selectedAccount == nil else { return }
        
        let active = accounts.filter { $0.isActive }
        
        // First: Primary account matching financeType
        if let primary = active.first(where: { $0.isPrimary && $0.financeType == financeType }) {
            selectedAccount = primary
            return
        }
        
        // Second: Any account matching financeType
        if let matching = active.first(where: { $0.financeType == financeType }) {
            selectedAccount = matching
            return
        }
        
        // Third: Any primary account
        if let primary = active.first(where: { $0.isPrimary }) {
            selectedAccount = primary
        }
    }
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        
        if let current = selectedAccount, current.financeType != newType {
            let active = accounts.filter { $0.isActive }
            
            if let matching = active.first(where: { $0.financeType == newType && $0.isPrimary }) {
                withAnimation(FLOAnimation.quick) {
                    selectedAccount = matching
                }
            } else if let matching = active.first(where: { $0.financeType == newType }) {
                withAnimation(FLOAnimation.quick) {
                    selectedAccount = matching
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func save() {
        guard let amt = Double(amount), amt > 0 else { return }
        
        let trimmedMerchant = merchantName.trimmingCharacters(in: .whitespaces)
        guard !trimmedMerchant.isEmpty else { return }
        
        HapticService.play(.medium)
        
        let recurring = RecurringTransaction(
            amount: amt,
            merchantName: trimmedMerchant,
            note: note,
            isIncome: isIncome,
            financeType: financeType,
            frequency: frequency,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            category: selectedCategory,
            account: selectedAccount,
            isActive: true
        )
        
        context.insert(recurring)
        
        do {
            try context.save()
            
            HapticService.play(.success)
            print("✅ Recurring saved: \(trimmedMerchant) - Account: \(selectedAccount?.name ?? "None")")
            
            dismiss()
        } catch {
            print("❌ Failed to save recurring transaction: \(error)")
            
            HapticService.play(.error)
        }
    }
}

// MARK: - Recurring Account Chip

struct RecurringAccountChip: View {
    let account: Account
    let isSelected: Bool
    let showBalance: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: account.color).opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: account.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: account.color))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("•••• \(digits)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(account.financeType.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.1) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(FLOAnimation.quick, value: isSelected)
    }
}

// MARK: - Preview

#Preview("Add Recurring - Default") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Category.self, Account.self, RecurringTransaction.self,
        configurations: config
    )
    
    return AddRecurringView()
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(container)
}

#Preview("Add Recurring - Preselected Business") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Category.self, Account.self, RecurringTransaction.self,
        configurations: config
    )
    
    return AddRecurringView(preselectedFinanceType: .business)
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(container)
}
