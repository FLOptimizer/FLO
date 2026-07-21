//  CreateBudgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.7 - Catalyst picker style · macOS Prediction Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6 - macOS Prediction Fix:
//  ✅ FIXED: Category Picker on macOS now uses .menu pickerStyle for reliable onChange
//  ✅ ADDED: .task(id:) fallback trigger for prediction on all platforms
//
//  CHANGES v1.5 - Predictive Budgeting:
//  ✅ ADDED: ML-powered budget prediction when category is selected
//  ✅ ADDED: "Suggested" badge with Apply button for predicted amount
//  ✅ ADDED: Prediction explanation (months of data + inflation rate)
//  ✅ ADDED: Confidence range displayed in footer
//  ✅ ADDED: Tracks isUserOverridden when user changes from prediction
//  ✅ ADDED: Stores suggestedAmount on Budget model for analytics
//
//  CHANGES v1.4 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double
//  ✅ UPDATED: isValid, save(), and footer to use Double amount directly
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Month date text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account section footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Budget amount footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "All Accounts" chip title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "All Accounts" chip finance type label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account chip name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account chip last four digits missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account chip finance type label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Category label text missing lineLimit + minimumScaleFactor
//
//  CHANGES FROM v1.2:
//  ✅ FIXED: FinanceType comparison (Account now uses Transaction.FinanceType)
//  ✅ FIXED: Used .displayName instead of .rawValue for display strings
//  ✅ FIXED: Explicit type annotations in sorted closure
//
//  CHANGES FROM v1.1:
//  ✅ ADDED: Account selection with horizontal chips (Premium+)
//  ✅ ADDED: Account-specific budget tracking
//  ✅ ADDED: Haptic feedback on interactions
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct CreateBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query private var allRecurring: [RecurringTransaction]
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businessProfiles: [BusinessProfile]

    let month: Date

    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var selectedBusinessProfile: BusinessProfile?
    @State private var amount: Double = 0
    @State private var financeType: Transaction.FinanceType = .personal

    // v1.5: Predictive budgeting
    @State private var prediction: PredictedBudget?
    @State private var didApplyPrediction = false
    
    var body: some View {
        NavigationStack {
            Form {
                monthSection
                financeTypeSection
                businessProfileSection
                categorySection
                accountSection
                amountSection
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("New Budget")
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
                    .accessibilityHint("Discard and go back")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Accessibility label via button text
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    .accessibilityHint("Creates the new budget")
                }
            }
            .onAppear {
                setDefaultAccount()
                AccessibilityAnnouncement.screenChanged("Create new budget")
            }
            .onChange(of: financeType) { _, newType in
                updateAccountForFinanceType(newType)
            }
            // v1.5: Fetch prediction when category changes
            .onChange(of: selectedCategory) { _, newCategory in
                updatePrediction(for: newCategory)
            }
        }
    }
    
    // MARK: - Sections
    
    private var monthSection: some View {
        Section("Month") {
            HStack {
                Image(systemName: "calendar")
                     .foregroundStyle(Color.brandPrimary)
                     .accessibilityHidden(true)
                
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
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
                Text("Select category").tag(Category?.none)
                Section(header: Text("BUSINESS")) {
                    ForEach(organizedBusinessCategories) { cat in
                        Label(cat.name, systemImage: cat.icon)
                            .tag(Optional(cat))
                    }
                }
                Section(header: Text("PERSONAL")) {
                    ForEach(organizedPersonalCategories) { cat in
                        Label(cat.name, systemImage: cat.icon)
                            .tag(Optional(cat))
                    }
                }
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            .pickerStyle(.menu)
            #endif
            // v1.6: Reliable fallback trigger for prediction (macOS onChange can be unreliable)
            .task(id: selectedCategory?.id) {
                updatePrediction(for: selectedCategory)
            }

            // Show recurring info when category has active recurring expenses
            if let category = selectedCategory,
               let suggestion = BudgetRecurringService.shared.suggestedBudgetAmount(
                   for: category, financeType: financeType, from: allRecurring
               ) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .font(.caption)
                        Text("This category has recurring expenses")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.brandPrimary)
                    }

                    ForEach(suggestion.items) { item in
                        HStack {
                            Text(item.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(item.monthlyAmount.formatted(.currency(code: "USD")))/mo")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if amount == 0 || amount < suggestion.recurring {
                        Button {
                            amount = suggestion.recurring
                            HapticService.play(.light)
                        } label: {
                            Text("Set to \(suggestion.recurring.formatted(.currency(code: "USD"))) (recurring total)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Account Section
    
    @ViewBuilder
    private var accountSection: some View {
        // All tiers can scope budgets to an account they own
        if !accounts.isEmpty {
            Section {
                accountChipsView
            } header: {
                HStack {
                    Text("Account (Optional)")
                    Spacer()
                    if selectedAccount != nil {
                        Button("All Accounts") {
                            withAnimation(FLOAnimation.quick) {
                                selectedAccount = nil
                            }
                            HapticService.play(.light)
                        }
                        .font(.caption)
                         .foregroundStyle(Color.brandPrimary)
                        .accessibilityHint("Clears account filter, applies budget to all accounts")
                    }
                }
            } footer: {
                if selectedAccount == nil {
                    Text("Budget will apply across all \(financeType.displayName) accounts")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Budget will be specific to \(selectedAccount?.name ?? "selected account")")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
    
    @ViewBuilder
    private var accountChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All Accounts" chip
                AllAccountsChip(
                    isSelected: selectedAccount == nil,
                    financeType: financeType
                ) {
                    withAnimation(FLOAnimation.quick) {
                        selectedAccount = nil
                    }
                    HapticService.play(.medium)
                }
                
                ForEach(sortedAccounts) { account in
                    BudgetAccountChip(
                        account: account,
                        isSelected: selectedAccount?.id == account.id,
                        showBalance: subscriptionManager.currentTier.hasBalanceTracking
                    ) {
                        withAnimation(FLOAnimation.quick) {
                            selectedAccount = account
                        }
                        HapticService.play(.medium)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    
    private var amountSection: some View {
        Section {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Budget amount"
            )
            .onChange(of: amount) { _, newAmount in
                // v1.5: Track if user changed from predicted amount
                if let pred = prediction, didApplyPrediction, newAmount != pred.suggestedAmount {
                    didApplyPrediction = false
                }
            }

            // v1.5: Prediction suggestion
            if let prediction = prediction, amount == 0 || didApplyPrediction == false {
                Button {
                    withAnimation(FLOAnimation.standard) {
                        amount = prediction.suggestedAmount
                        didApplyPrediction = true
                    }
                    HapticService.play(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Suggested:")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(prediction.formattedAmount)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            Text(prediction.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }

                        Spacer()

                        Text("Apply")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.brandPrimary)
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityLabel("Apply suggested budget of \(prediction.formattedAmount)")
                .accessibilityHint(prediction.explanation)
            }
        } header: {
            Text("Budget Amount")
        } footer: {
            if amount > 0 {
                if didApplyPrediction, let pred = prediction {
                    Text("ML-predicted: \(pred.formattedAmount) (range: \(AppConstants.currencyFormatter.string(from: NSNumber(value: pred.lowerBound)) ?? "") – \(AppConstants.currencyFormatter.string(from: NSNumber(value: pred.upperBound)) ?? ""))")
                        .foregroundStyle(Color.brandPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Monthly limit: \(amount.formatted(.currency(code: "USD")))")
                        .foregroundStyle(Color.brandPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCategories: [Category] {
        categories.filter { !$0.isIncome }
    }

    private var organizedBusinessCategories: [Category] {
        categories.filter { !$0.isIncome && $0.isBusiness }.sorted { $0.name < $1.name }
    }

    private var organizedPersonalCategories: [Category] {
        categories.filter { !$0.isIncome && !$0.isBusiness }.sorted { $0.name < $1.name }
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
    
    private var isValid: Bool {
        selectedCategory != nil && amount > 0
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
        // For budgets, default to "All Accounts" (nil)
        // Only auto-select if user has very few accounts
    }
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
        // If current account doesn't match new financeType, reset to "All Accounts"
        if let current = selectedAccount, current.financeType != newType {
            withAnimation(FLOAnimation.quick) {
                selectedAccount = nil
            }
        }
    }
    
    // MARK: - Prediction

    /// v1.5: Fetch budget prediction when category changes
    private func updatePrediction(for category: Category?) {
        guard let category = category, !category.isIncome else {
            prediction = nil
            return
        }

        prediction = BudgetPredictionService.shared.predictBudgetAmount(
            for: category,
            targetMonth: month,
            transactions: allTransactions
        )
    }

    // MARK: - Actions

    private func save() {
        let amt = amount
        guard amt > 0, let category = selectedCategory else { return }

        HapticService.play(.medium)

        let budget = Budget(
            month: month,
            planned: amt,
            category: category,
            account: selectedAccount,
            businessProfile: financeType == .business ? selectedBusinessProfile : nil,
            financeType: financeType
        )

        // v1.5: Store prediction metadata
        if let pred = prediction {
            budget.suggestedAmount = pred.suggestedAmount
            budget.isUserOverridden = !didApplyPrediction || amt != pred.suggestedAmount
        }

        context.insert(budget)

        do {
            try context.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            print("❌ Failed to save budget: \(error)")
            HapticService.play(.error)
        }
    }
}

// MARK: - All Accounts Chip

struct AllAccountsChip: View {
    let isSelected: Bool
    let financeType: Transaction.FinanceType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "building.columns")
                        .font(.subheadline)
                         .foregroundStyle(Color.brandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("All Accounts")
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    
                    Text(financeType.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.tertiary)
                }
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                         .foregroundStyle(Color.brandPrimary)
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
    }
}

// MARK: - Budget Account Chip

struct BudgetAccountChip: View {
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
    }
}

// MARK: - Preview

#Preview("Create Budget") {
    let container = try! ModelContainer(
        for: Category.self, Budget.self, Account.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "10B981", isIncome: false)
    let utilities = Category(name: "Utilities", icon: "bolt.fill", colorHex: "3B82F6", isIncome: false)
    
    context.insert(groceries)
    context.insert(utilities)
    
    return CreateBudgetView(month: Date())
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(container)
}
