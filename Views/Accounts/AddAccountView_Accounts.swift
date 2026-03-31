//  AddAccountView_Accounts.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - Loan Detail Fields
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  NOTE: Named AddAccountView_Accounts to avoid collision with any other
//  AddAccountView if one exists elsewhere. Contains AddAccountView struct.
//
//  CHANGES v1.4 - Balance Anchor on Account Creation:
//  ✅ ADDED: Creates BalanceAnchor with source .accountCreation after successful save
//  ✅ NOTE: Establishes initial anchor point for reconciliation (Issue #3)
//
//  CHANGES v1.3 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String for startingBalance with CurrencyInputField component
//  ✅ REPLACED: Old TextField + String for creditLimit with CurrencyInputField component
//  ✅ REPLACED: Old TextField + String for minimumPaymentFloor with CurrencyInputField component
//  ✅ CHANGED: startingBalance, creditLimit, minimumPaymentFloor from String to Double
//  ✅ UPDATED: previewBalance and saveAccount() to use Double values directly
//
//  CHANGES v1.2 - Credit Card Balance Polarity Fix:
//  ✅ FIXED: Auto-negate balance for liability accounts (credit cards, loans) in saveAccount()
//  ✅ FIXED: Preview now reflects correct negative balance for liability accounts
//  ✅ UPDATED: Caption hint for credit cards now says "Enter the amount you currently owe"
//
//  CHANGES v1.1 - Dynamic Type Verification:
//  ✅ VERIFIED: All text elements are within SwiftUI Form controls (system-managed)
//  ✅ VERIFIED: No standalone Text() elements require manual protection
//  ✅ VERIFIED: TextField, Picker, Toggle, Section headers all handle Dynamic Type automatically
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
    @State private var startingBalance: Double = 0
    @State private var lastFourDigits = ""
    @State private var institutionName = ""
    
    // Credit card specific
    @State private var creditLimit: Double = 0
    @State private var apr: String = ""
    @State private var minimumPaymentPercent: String = "2"
    @State private var minimumPaymentFloor: Double = 25
    @State private var paymentDueDay: Int = 1

    // Loan specific
    @State private var originalLoanAmount: Double = 0
    @State private var loanTermMonths: Int = 360
    @State private var monthlyPaymentAmount: Double = 0
    @State private var loanStartDate: Date = Date()
    @State private var loanType: LoanType = .personal
    
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
                        CurrencyInputField(
                            amount: $startingBalance,
                            accessibilityLabelText: "Starting balance in dollars",
                            showDoneButton: false
                        )
                        
                        if !accountType.isAsset {
                            Text("Enter the amount you currently owe")
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
                            CurrencyInputField(
                                amount: $creditLimit,
                                placeholder: "$0.00",
                                font: .body,
                                fontWeight: .regular,
                                accessibilityLabelText: "Credit limit in dollars",
                                showDoneButton: false
                            )
                            .frame(maxWidth: 150)
                        }
                        
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
                            CurrencyInputField(
                                amount: $minimumPaymentFloor,
                                placeholder: "$0.00",
                                font: .body,
                                fontWeight: .regular,
                                accessibilityLabelText: "Minimum payment floor in dollars",
                                showDoneButton: false
                            )
                            .frame(maxWidth: 120)
                        }
                    } header: {
                        Text("Minimum Payment")
                    } footer: {
                        Text("Most cards require 2% of balance or $25, whichever is greater")
                    }
                }
                
                // Loan Details
                if accountType == .loan {
                    Section {
                        Picker("Loan Type", selection: $loanType) {
                            ForEach(LoanType.allCases) { type in
                                Label(type.displayName, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .accessibilityLabel("Loan type: \(loanType.displayName)")

                        HStack {
                            Text("APR")
                            Spacer()
                            TextField("3.75", text: $apr)
                                .keyboardType(.decimalPad)
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Annual percentage rate")
                        .accessibilityValue(apr.isEmpty ? "Not set" : "\(apr) percent")

                        HStack {
                            Text("Original Amount")
                            Spacer()
                            CurrencyInputField(
                                amount: $originalLoanAmount,
                                placeholder: "$0.00",
                                font: .body,
                                fontWeight: .regular,
                                accessibilityLabelText: "Original loan amount in dollars",
                                showDoneButton: false
                            )
                            .frame(maxWidth: 150)
                        }

                        Picker("Term (Months)", selection: $loanTermMonths) {
                            Text("12 months (1 yr)").tag(12)
                            Text("24 months (2 yr)").tag(24)
                            Text("36 months (3 yr)").tag(36)
                            Text("48 months (4 yr)").tag(48)
                            Text("60 months (5 yr)").tag(60)
                            Text("84 months (7 yr)").tag(84)
                            Text("120 months (10 yr)").tag(120)
                            Text("180 months (15 yr)").tag(180)
                            Text("240 months (20 yr)").tag(240)
                            Text("360 months (30 yr)").tag(360)
                        }
                        .accessibilityLabel("Loan term: \(loanTermMonths) months")

                        HStack {
                            Text("Monthly Payment")
                            Spacer()
                            CurrencyInputField(
                                amount: $monthlyPaymentAmount,
                                placeholder: "$0.00",
                                font: .body,
                                fontWeight: .regular,
                                accessibilityLabelText: "Monthly payment amount in dollars",
                                showDoneButton: false
                            )
                            .frame(maxWidth: 150)
                        }

                        Picker("Payment Due Day", selection: $paymentDueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .accessibilityLabel("Payment due day: \(paymentDueDay)")

                        DatePicker("Loan Start Date", selection: $loanStartDate, displayedComponents: .date)
                            .accessibilityLabel("Loan origination date")
                    } header: {
                        Text("Loan Details")
                    } footer: {
                        Text("APR and monthly payment are used for interest/principal split calculations and debt payoff projections")
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
                        balance: previewBalance,
                        lastFourDigits: lastFourDigits.isEmpty ? nil : lastFourDigits
                    )
                    .accessibilityLabel("Preview of new account")
                }
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Single keyboard Done button for all numberPad/decimalPad fields
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
    
    // MARK: - Computed Properties

    /// Balance adjusted for liability accounts (auto-negated for preview)
    private var previewBalance: Double {
        var balance = startingBalance
        if !accountType.isAsset && balance > 0 {
            balance = -balance
        }
        return balance
    }

    // MARK: - Actions

    private func saveAccount() {
        HapticService.play(.medium)

        if isPrimary {
            for account in existingAccounts where account.isPrimary {
                account.isPrimary = false
            }
        }

        var balance = startingBalance
        // Auto-negate for liability accounts (credit cards, loans)
        // Users enter the amount owed as a positive number; we store it as negative
        if !accountType.isAsset && balance > 0 {
            balance = -balance
        }
        
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
            creditLimit: accountType == .creditCard && creditLimit > 0 ? creditLimit : nil,
            apr: accountType.hasDebtFields ? Double(apr) : nil,
            minimumPaymentPercent: accountType == .creditCard ? Double(minimumPaymentPercent) : nil,
            minimumPaymentFloor: accountType == .creditCard && minimumPaymentFloor > 0 ? minimumPaymentFloor : nil,
            paymentDueDay: accountType.hasDebtFields ? paymentDueDay : nil,
            originalLoanAmount: accountType == .loan && originalLoanAmount > 0 ? originalLoanAmount : nil,
            loanTermMonths: accountType == .loan ? loanTermMonths : nil,
            monthlyPaymentAmount: accountType == .loan && monthlyPaymentAmount > 0 ? monthlyPaymentAmount : nil,
            loanStartDate: accountType == .loan ? loanStartDate : nil,
            loanTypeRaw: accountType == .loan ? loanType.rawValue : nil
        )
        
        modelContext.insert(account)
        
        do {
            try modelContext.save()

            // Create initial balance anchor for reconciliation (v1.4)
            ReconciliationService.shared.createAccountCreationAnchor(
                for: account,
                context: modelContext
            )
            try? modelContext.save()  // Save the anchor too

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
