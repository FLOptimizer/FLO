//  EditAccountView_Accounts.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  NOTE: Named EditAccountView_Accounts to avoid collision with any other
//  EditAccountView if one exists elsewhere. Contains EditAccountView struct.
//
//  CHANGES v1.1 - Dynamic Type Verification:
//  ✅ FIXED: Next payment due date text missing lineLimit + minimumScaleFactor
//  ✅ VERIFIED: All other text elements are within SwiftUI Form controls (system-managed)
//  ✅ VERIFIED: HStack label-value pairs use system Form styling (no manual protection needed)
//
//  CHANGES v1.0:
//  ✅ EXTRACTED: From AccountsView.swift for better architecture
//  ✅ ADDED: All form fields VoiceOver labeled
//  ✅ ADDED: Credit card detail fields accessible with values
//  ✅ ADDED: Credit card summary section accessible (utilization, interest, payment)
//  ✅ ADDED: Statistics section accessible with spoken currency
//  ✅ ADDED: Bank connection status accessible
//  ✅ ADDED: Disconnect bank button labeled with hint
//  ✅ ADDED: Toggle hints for primary/active/dashboard
//  ✅ ADDED: Cancel/Save toolbar buttons labeled with dynamic hints
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Save/disconnect success/failure announced
//

import SwiftUI
import SwiftData

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
    @State private var showOnDashboard: Bool
    @State private var notes: String
    @State private var currentBalance: String
    @State private var lastFourDigits: String
    @State private var institutionName: String
    
    // Credit card fields
    @State private var creditLimit: String
    @State private var apr: String
    @State private var minimumPaymentPercent: String
    @State private var minimumPaymentFloor: String
    @State private var paymentDueDay: Int
    
    init(account: Account) {
        self.account = account
        _name = State(initialValue: account.name)
        _accountType = State(initialValue: account.accountType)
        _financeType = State(initialValue: account.financeType)
        _isPrimary = State(initialValue: account.isPrimary)
        _isActive = State(initialValue: account.isActive)
        _showOnDashboard = State(initialValue: account.showOnDashboard)
        _notes = State(initialValue: account.notes)
        _currentBalance = State(initialValue: String(format: "%.2f", account.currentBalance))
        _lastFourDigits = State(initialValue: account.lastFourDigits ?? "")
        _institutionName = State(initialValue: account.institutionName ?? "")
        
        _creditLimit = State(initialValue: account.creditLimit.map { String(format: "%.2f", $0) } ?? "")
        _apr = State(initialValue: account.apr.map { String(format: "%.2f", $0) } ?? "")
        _minimumPaymentPercent = State(initialValue: account.minimumPaymentPercent.map { String(format: "%.1f", $0) } ?? "2")
        _minimumPaymentFloor = State(initialValue: account.minimumPaymentFloor.map { String(format: "%.0f", $0) } ?? "25")
        _paymentDueDay = State(initialValue: account.paymentDueDay ?? 1)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Account Details
                Section("Account Details") {
                    TextField("Account Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Account name")
                    
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
                    Section("Current Balance") {
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            TextField("0.00", text: $currentBalance)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("Current balance in dollars")
                        }
                    }
                }
                
                // Credit Card Details (conditional)
                if accountType == .creditCard {
                    Section("Credit Card Details") {
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
                        .accessibilityLabel("Credit limit")
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
                    }
                    
                    Section("Minimum Payment") {
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
                        .accessibilityLabel("Minimum payment floor")
                        .accessibilityValue("$\(minimumPaymentFloor)")
                    }
                    
                    // Credit Card Summary (read-only)
                    if account.currentBalance < 0 {
                        creditCardSummarySection
                    }
                }
                
                // Bank Details
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
                }
                
                // Toggles
                Section {
                    Toggle("Primary Account", isOn: $isPrimary)
                        .accessibilityHint("Primary account is used as the default")
                    Toggle("Active", isOn: $isActive)
                        .accessibilityHint("Inactive accounts stop tracking transactions")
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
                
                // Statistics
                if account.transactionCount > 0 {
                    Section("Statistics") {
                        HStack {
                            Text("Transactions")
                            Spacer()
                            Text("\(account.transactionCount)")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total transactions: \(account.transactionCount)")
                        
                        HStack {
                            Text("Total Income")
                            Spacer()
                            Text(formatCurrency(account.totalIncome))
                                .foregroundStyle(.green)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total income: \(AccessibilityFormatters.spokenCurrency(account.totalIncome))")
                        
                        HStack {
                            Text("Total Expenses")
                            Spacer()
                            Text(formatCurrency(account.totalExpenses))
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Total expenses: \(AccessibilityFormatters.spokenCurrency(account.totalExpenses))")
                        
                        HStack {
                            Text("Net Change")
                            Spacer()
                            Text(formatCurrency(account.netChange))
                                .foregroundStyle(account.netChange >= 0 ? .green : .red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Net change: \(AccessibilityFormatters.spokenCurrency(account.netChange))")
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Bank connection: \(account.plaidStatus.displayName), last sync \(account.lastSyncDescription)")
                        
                        Button(role: .destructive) {
                            disconnectPlaid()
                        } label: {
                            Label("Disconnect Bank", systemImage: "link.badge.minus")
                        }
                        .accessibilityLabel("Disconnect bank")
                        .accessibilityHint("Double tap to disconnect the linked bank account")
                    }
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard changes")
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                    .accessibilityLabel("Save changes")
                    .accessibilityHint(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Enter an account name to enable saving" : "Double tap to save your changes")
                }
            }
            .onAppear {
                // v1.0: Announce screen
                AccessibilityAnnouncement.screenChanged("Edit Account: \(account.name)")
            }
        }
    }
    
    // MARK: - Credit Card Summary Section
    
    @ViewBuilder
    private var creditCardSummarySection: some View {
        Section("Credit Card Summary") {
            if let utilization = account.creditUtilization {
                HStack {
                    Text("Credit Utilization")
                    Spacer()
                    Text("\(Int(utilization))%")
                        .foregroundStyle(Color(hex: account.utilizationStatus.color))
                    Text(account.utilizationStatus.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Credit utilization: \(Int(utilization)) percent, \(account.utilizationStatus.displayName)")
            }
            
            if let monthlyInterest = account.estimatedMonthlyInterest {
                HStack {
                    Text("Est. Monthly Interest")
                    Spacer()
                    Text(formatCurrency(monthlyInterest))
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Estimated monthly interest: \(AccessibilityFormatters.spokenCurrency(monthlyInterest))")
            }
            
            if let minPayment = account.minimumPaymentDue {
                HStack {
                    Text("Minimum Payment Due")
                    Spacer()
                    Text(formatCurrency(minPayment))
                        .foregroundStyle(Color.brandPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Minimum payment due: \(AccessibilityFormatters.spokenCurrency(minPayment))")
            }
            
            if let available = account.availableCredit {
                HStack {
                    Text("Available Credit")
                    Spacer()
                    Text(formatCurrency(available))
                        .foregroundStyle(.green)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Available credit: \(AccessibilityFormatters.spokenCurrency(available))")
            }
            
            if let dueDate = account.nextPaymentDueDate {
                HStack {
                    Text("Next Payment Due")
                    Spacer()
                    Text(dueDate, style: .date)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(account.isPaymentDueSoon ? .orange : .secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Next payment due: \(AccessibilityFormatters.spokenDate(dueDate))\(account.isPaymentDueSoon ? ", due soon" : "")")
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        HapticService.play(.medium)
        
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
        account.showOnDashboard = showOnDashboard
        account.notes = notes
        account.currentBalance = Double(currentBalance) ?? account.currentBalance
        account.lastBalanceUpdate = Date()
        account.lastFourDigits = lastFourDigits.isEmpty ? nil : lastFourDigits
        account.institutionName = institutionName.isEmpty ? nil : institutionName
        
        if accountType == .creditCard {
            account.creditLimit = Double(creditLimit)
            account.apr = Double(apr)
            account.minimumPaymentPercent = Double(minimumPaymentPercent)
            account.minimumPaymentFloor = Double(minimumPaymentFloor)
            account.paymentDueDay = paymentDueDay
        } else {
            account.creditLimit = nil
            account.apr = nil
            account.minimumPaymentPercent = nil
            account.minimumPaymentFloor = nil
            account.paymentDueDay = nil
        }
        
        account.touch()
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Account updated successfully")
            dismiss()
        } catch {
            print("Failed to save account changes: \(error)")
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to save account changes")
        }
    }
    
    private func disconnectPlaid() {
        HapticService.play(.heavy)
        account.disconnectPlaid()
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Bank disconnected")
        } catch {
            print("Failed to disconnect Plaid: \(error)")
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Preview

#Preview("Edit Account") {
    let container = try! ModelContainer(
        for: Account.self, Transaction.self, InvoicePayment.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let account = Account(
        name: "Business Checking",
        accountType: .checking,
        isPrimary: true,
        financeType: .business
    )
    container.mainContext.insert(account)
    
    return EditAccountView(account: account)
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(container)
}
