//  AddRecurringView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.4 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double
//  ✅ REMOVED: String-to-Double parsing in isValid and save()
//  ✅ UPDATED: All validation/save logic to use Double amount directly
//
//  CHANGES v2.3 - Dynamic Type Verification:
//  ✅ FIXED: Account footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account mismatch warning label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Category label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecurringAccountChip name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecurringAccountChip last four digits text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecurringAccountChip finance type text missing lineLimit + minimumScaleFactor
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
import FLODesignSystem
import SwiftData

struct AddRecurringView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Budget.month, order: .reverse) private var allBudgets: [Budget]
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businessProfiles: [BusinessProfile]
    
    let preselectedFinanceType: Transaction.FinanceType?
    
    @State private var amount: Double = 0
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
    @State private var selectedBusinessProfile: BusinessProfile?
    @State private var showBudgetOffer = false
    @State private var savedRecurringAmount: Double = 0
    
    init(preselectedFinanceType: Transaction.FinanceType? = nil) {
        self.preselectedFinanceType = preselectedFinanceType
    }
    
    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                financeTypeSection
                businessProfileSection
                categorySection
                accountSection
                frequencySection
                scheduleSection
            }
            .navigationTitle("New Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        #endif
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Discard changes and go back")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save recurring transaction")
                    .accessibilityHint(isValid ? "Double tap to save" : "Enter merchant name and amount first")
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
            .alert("Create a Budget?", isPresented: $showBudgetOffer) {
                Button("Create Budget") {
                    createBudgetForRecurring()
                    dismiss()
                }
                Button("Skip", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("No budget exists for \(selectedCategory?.name ?? "this category"). Would you like to create a \(savedRecurringAmount.formatted(.currency(code: "USD")))/mo budget?")
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

            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Recurring amount"
            )
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
            .onChange(of: financeType) { _, newType in
                HapticService.play(.light)
                if newType == .business && businessProfiles.count == 1 {
                    selectedBusinessProfile = businessProfiles.first
                } else if newType == .personal {
                    selectedBusinessProfile = nil
                }
            }
        }
    }

    @ViewBuilder
    private var businessProfileSection: some View {
        if financeType == .business && businessProfiles.count > 1 {
            Section("Business Profile") {
                Picker("Business", selection: $selectedBusinessProfile) {
                    Text("Select...").tag(nil as BusinessProfile?)
                    ForEach(businessProfiles) { profile in
                        Text(profile.businessName).tag(profile as BusinessProfile?)
                    }
                }
                .pickerStyle(.menu)
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
        // All tiers can pick among their accounts
        if !accounts.isEmpty {
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
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        } else if let account = selectedAccount, account.financeType != financeType {
            Label("Account type differs from transaction classification", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.orange)
        } else {
            Text("All generated transactions will use \(selectedAccount?.name ?? "this account")")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    private func categoryLabel(for category: Category) -> some View {
        Label {
            Text(category.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
            .filter { !$0.isIncome && $0.isBusiness }
            .sorted { $0.name < $1.name }
    }

    private var organizedPersonalCategories: [Category] {
        categories
            .filter { !$0.isIncome && !$0.isBusiness }
            .sorted { $0.name < $1.name }
    }
    
    private var isValid: Bool {
        guard !merchantName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard amount > 0 else { return false }
        return true
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
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
        let amt = amount
        guard amt > 0 else { return }

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
            businessProfile: financeType == .business ? selectedBusinessProfile : nil,
            isActive: true
        )
        
        context.insert(recurring)
        
        do {
            try context.save()

            HapticService.play(.success)
            print("✅ Recurring saved: \(trimmedMerchant) - Account: \(selectedAccount?.name ?? "None")")

            // Check if expense has a matching budget — offer to create one if not
            if !isIncome, let category = selectedCategory {
                let calendar = Calendar.current
                let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
                let hasMatchingBudget = allBudgets.contains { budget in
                    budget.category?.id == category.id &&
                    budget.financeType == financeType &&
                    calendar.isDate(budget.month, equalTo: currentMonth, toGranularity: .month)
                }

                if !hasMatchingBudget {
                    savedRecurringAmount = BudgetRecurringService.monthlyEquivalent(amount: amt, frequency: frequency)
                    showBudgetOffer = true
                    return  // Don't dismiss yet — wait for budget offer response
                }
            }

            dismiss()
        } catch {
            print("✓ Failed to save recurring transaction: \(error)")

            HapticService.play(.error)
        }
    }

    private func createBudgetForRecurring() {
        guard let category = selectedCategory else { return }

        let calendar = Calendar.current
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!

        let budget = Budget(
            month: currentMonth,
            planned: savedRecurringAmount,
            category: category,
            account: selectedAccount,
            financeType: financeType
        )
        context.insert(budget)
        try? context.save()
        HapticService.play(.success)
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
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: account.color))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("•••• \(digits)")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(account.financeType.displayName)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                         .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.1) : Color.floSecondarySystemGroupedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(FLOAnimation.quick, value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name) account\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
