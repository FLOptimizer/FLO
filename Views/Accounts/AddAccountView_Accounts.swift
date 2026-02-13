//  AddAccountView_Accounts.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Extracted from AccountsView.swift + Accessibility Audit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  NOTE: Named AddAccountView_Accounts to avoid collision with any other
//  AddAccountView if one exists elsewhere. Contains AddAccountView struct.
//
//  CHANGES v1.0:
//  ✅ EXTRACTED: From AccountsView.swift for better architecture
//  ✅ ADDED: All form fields VoiceOver labeled
//  ✅ ADDED: Credit card fields accessible (credit limit, APR, payment day)
//  ✅ ADDED: Minimum payment fields accessible with values
//  ✅ ADDED: Bank details fields labeled
//  ✅ ADDED: Toggle hints for primary/dashboard settings
//  ✅ ADDED: Cancel/Save toolbar buttons labeled with dynamic hints
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Save success/failure announced
//

import SwiftUI
import SwiftData

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Query(sort: \Account.name) private var existingAccounts: [Account]
    
    @State private var name = ""
    @State private var accountType: AccountType = .checking
    @State private var financeType: Transaction.FinanceType = .business
    @State private var isPrimary = false
    @State private var showOnDashboard = true
    @State private var notes = ""
    @State private var startingBalance: String = ""
    @State private var lastFourDigits = ""
    @State private var institutionName = ""
    
    // Credit card specific
    @State private var creditLimit: String = ""
    @State private var apr: String = ""
    @State private var minimumPaymentPercent: String = "2"
    @State private var minimumPaymentFloor: String = "25"
    @State private var paymentDueDay: Int = 1
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Details
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                        .textInputAutocapitalization(.words)
                        // v1.0: VoiceOver
                        .accessibilityLabel("Account name")
                        .accessibilityHint("Enter a name for this account")
                    
                    Picker("Account Type", selection: $accountType) {
                        ForEach(AccountType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .accessibilityLabel("Account type: \(accountType.displayName)")
                    
                    Picker("Classification", selection: $financeType) {
                        ForEach(Transaction.FinanceType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .accessibilityLabel("Classification: \(financeType.displayName)")
                }
                
                // Balance (Premium feature)
                if subscriptionManager.currentTier.hasBalanceTracking {
                    Section("Starting Balance") {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            TextField("0.00", text: $startingBalance)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("Starting balance in dollars")
                        }
                        
                        if accountType == .creditCard {
                            Text("Enter as negative for amount owed (e.g., -500)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Credit Card Details
                if accountType == .creditCard {
                    Section {
                        HStack {
                            Text("Credit Limit")
                            Spacer()
                            Text("$")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            TextField("5000", text: $creditLimit)
                                .keyboardType(.decimalPad)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Credit limit in dollars")
                        .accessibilityValue(creditLimit.isEmpty ? "Not set" : "$\(creditLimit)")
                        
                        HStack {
                            Text("APR")
                            Spacer()
                            TextField("24.99", text: $apr)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Annual percentage rate")
                        .accessibilityValue(apr.isEmpty ? "Not set" : "\(apr) percent")
                        
                        Picker("Payment Due Day", selection: $paymentDueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .accessibilityLabel("Payment due day: \(paymentDueDay)")
                    } footer: {
                        Text("APR is used to estimate monthly interest charges")
                    }
                    
                    Section {
                        HStack {
                            Text("Percentage")
                            Spacer()
                            TextField("2", text: $minimumPaymentPercent)
                                .keyboardType(.decimalPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Minimum payment percentage")
                        .accessibilityValue("\(minimumPaymentPercent) percent")
                        
                        HStack {
                            Text("Minimum Floor")
                            Spacer()
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("25", text: $minimumPaymentFloor)
                                .keyboardType(.decimalPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Minimum payment floor in dollars")
                        .accessibilityValue(minimumPaymentFloor.isEmpty ? "Not set" : "$\(minimumPaymentFloor)")
                    } header: {
                        Text("Minimum Payment")
                    } footer: {
                        Text("Most cards require 2% of balance or $25, whichever is greater")
                    }
                }
                
                // Bank Details (Optional)
                Section("Bank Details (Optional)") {
                    TextField("Institution Name", text: $institutionName)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Bank or institution name")
                    
                    TextField("Last 4 Digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newValue in
                            lastFourDigits = String(newValue.prefix(4))
                        }
                        .accessibilityLabel("Last four digits of account number")
                        .accessibilityHint("Enter up to 4 digits for identification")
                }
                
                // Settings
                Section {
                    Toggle("Set as Primary Account", isOn: $isPrimary)
                        .accessibilityHint("Primary account is used as the default for new transactions")
                    Toggle("Show on Dashboard", isOn: $showOnDashboard)
                        .accessibilityHint("When disabled, this account won't appear on the main dashboard")
                } footer: {
                    Text("Hidden accounts are still tracked but won't appear on the dashboard summary")
                }
                
                // Notes
                Section("Notes (Optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Account notes")
                }
                
                // Preview
                Section("Preview") {
                    AccountRowPreview(
                        name: name.isEmpty ? "Account Name" : name,
                        accountType: accountType,
                        financeType: financeType,
                        isPrimary: isPrimary,
                        showOnDashboard: showOnDashboard,
                        balance: Double(startingBalance) ?? 0,
                        lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits
                    )
                    .accessibilityLabel("Preview of new account")
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard and go back")
                }
            
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAccount()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save account")
                    .accessibilityHint(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter an account name to enable saving" : "Double tap to save this account")
                }
            }
            .onAppear {
                // v1.0: Announce screen
                AccessibilityAnnouncement.screenChanged("Add Account form")
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveAccount() {
        HapticService.play(.medium)
        
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
            showOnDashboard: showOnDashboard,
            currentBalance: balance,
            startingBalance: balance,
            financeType: financeType,
            lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits,
            institutionName: institutionName.isEmpty ? nil : institutionName,
            creditLimit: accountType == .creditCard ? Double(creditLimit) : nil,
            apr: accountType == .creditCard ? Double(apr) : nil,
            minimumPaymentPercent: accountType == .creditCard ? Double(minimumPaymentPercent) : nil,
            minimumPaymentFloor: accountType == .creditCard ? Double(minimumPaymentFloor) : nil,
            paymentDueDay: accountType == .creditCard ? paymentDueDay : nil
        )
        
        modelContext.insert(account)
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Account saved successfully")
            dismiss()
        } catch {
            print("Failed to save account: \(error)")
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to save account")
        }
    }
}

// MARK: - Preview

#Preview("Add Account") {
    AddAccountView()
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(for: [Account.self], inMemory: true)
}
