//  CreateBudgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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
import SwiftData

struct CreateBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    let month: Date
    
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var amount = ""
    @State private var financeType: Transaction.FinanceType = .personal
    
    var body: some View {
        NavigationStack {
            Form {
                monthSection
                financeTypeSection
                categorySection
                accountSection
                amountSection
            }
            .navigationTitle("New Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
        }
    }
    
    // MARK: - Sections
    
    private var monthSection: some View {
        Section("Month") {
            HStack {
                Image(systemName: "calendar")
                     .foregroundStyle(Color.brandPrimaryText)
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
            .onChange(of: financeType) { _, _ in
                HapticService.play(.light)
            }
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("Select category").tag(Category?.none)
                ForEach(filteredCategories) { cat in
                    CategoryLabel(category: cat)
                        .tag(Optional(cat))
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
                         .foregroundStyle(Color.brandPrimaryText)
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
            HStack {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Budget amount in dollars")
            }
        } header: {
            Text("Budget Amount")
        } footer: {
            if let amt = Double(amount), amt > 0 {
                Text("Monthly limit: \(amt.formatted(.currency(code: "USD")))")
                     .foregroundStyle(Color.brandPrimaryText)
                     .lineLimit(1)
                     .minimumScaleFactor(0.7)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredCategories: [Category] {
        categories.filter { !$0.isIncome }
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
        selectedCategory != nil && !amount.isEmpty && Double(amount) != nil
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
        // For budgets, default to "All Accounts" (nil)
        // Only auto-select if user has very few accounts
    }
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        
        // If current account doesn't match new financeType, reset to "All Accounts"
        if let current = selectedAccount, current.financeType != newType {
            withAnimation(FLOAnimation.quick) {
                selectedAccount = nil
            }
        }
    }
    
    // MARK: - Actions
    
    private func save() {
        guard let amt = Double(amount), let category = selectedCategory else { return }
        
        HapticService.play(.medium)
        
        let budget = Budget(
            month: month,
            planned: amt,
            category: category,
            account: selectedAccount,
            financeType: financeType
        )
        
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
                         .foregroundStyle(Color.brandPrimaryText)
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
                         .foregroundStyle(Color.brandPrimaryText)
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
                         .foregroundStyle(Color.brandPrimaryText)
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

// MARK: - Category Label

struct CategoryLabel: View {
    let category: Category
    
    var body: some View {
        Label {
            Text(category.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(Color(flowHex: category.colorHex))
        }
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
