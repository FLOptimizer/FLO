//  MoveMoneyView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Move Money between accounts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Transfer funds between any two accounts
//  ✅ Auto-detects transfer type (Owner's Draw, Contribution, Tax Set-Aside, etc.)
//  ✅ Creates linked transaction pair (source debit + destination credit)
//  ✅ Transfers excluded from P&L, tax estimates, and spending insights
//  ✅ Owner's Draw / Contribution tracking for year-end reporting
//  ✅ Tax Set-Aside tracking against quarterly estimate
//  ✅ Reimbursement option for business expenses paid personally
//  ✅ Full accessibility support
//

import SwiftUI
import SwiftData

struct MoveMoneyView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // MARK: - Queries
    
    @Query(filter: #Predicate<Account> { $0.isActive },
           sort: [SortDescriptor(\Account.name)])
    private var accounts: [Account]
    
    // MARK: - Form State
    
    @State private var fromAccount: Account?
    @State private var toAccount: Account?
    @State private var amount: String = ""
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var selectedTransferType: Transaction.TransferType?
    @State private var isManualTypeOverride: Bool = false
    
    // MARK: - UI State
    
    @State private var showingFromPicker = false
    @State private var showingToPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var isSaving = false
    
    // MARK: - Computed Properties
    
    /// Parsed amount value
    private var amountValue: Double {
        Double(amount.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    
    /// Whether the form is valid and ready to submit
    private var isFormValid: Bool {
        guard let from = fromAccount, let to = toAccount else { return false }
        return from.id != to.id && amountValue > 0
    }
    
    /// Auto-detected transfer type based on account selections
    private var detectedTransferType: Transaction.TransferType? {
        guard let from = fromAccount, let to = toAccount else { return nil }
        return Transaction.TransferType.detect(
            fromFinanceType: from.financeType,
            toFinanceType: to.financeType
        )
    }
    
    /// The active transfer type (manual override or auto-detected)
    private var activeTransferType: Transaction.TransferType? {
        isManualTypeOverride ? selectedTransferType : detectedTransferType
    }
    
    /// Accounts available as destination (excludes selected source)
    private var availableDestinations: [Account] {
        accounts.filter { $0.id != fromAccount?.id }
    }
    
    /// Business accounts for quick selection
    private var businessAccounts: [Account] {
        accounts.filter { $0.financeType == .business }
    }
    
    /// Personal accounts for quick selection
    private var personalAccounts: [Account] {
        accounts.filter { $0.financeType == .personal }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Accounts Section
                accountsSection
                
                // MARK: - Amount Section
                amountSection
                
                // MARK: - Transfer Type Section
                if fromAccount != nil && toAccount != nil {
                    transferTypeSection
                }
                
                // MARK: - Details Section
                detailsSection
                
                // MARK: - Summary Section
                if isFormValid {
                    summarySection
                }
            }
            .navigationTitle("Move Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        moveMoney()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isSaving)
                    .accessibilityHint("Moves the specified amount between the selected accounts")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Money Moved", isPresented: $showingSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                if let type = activeTransferType {
                    Text("\(amountFormatted) moved as \(type.displayName)")
                } else {
                    Text("\(amountFormatted) moved successfully")
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Move money between accounts")
            }
        }
    }
    
    // MARK: - Accounts Section
    
    private var accountsSection: some View {
        Section {
            // From Account
            Button {
                showingFromPicker = true
            } label: {
                HStack {
                    Label("From", systemImage: "arrow.up.circle.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    if let from = fromAccount {
                        accountBadge(from)
                    } else {
                        Text("Select Account")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("From account")
            .accessibilityValue(fromAccount?.name ?? "Not selected")
            .accessibilityHint("Select the account to move money from")
            .sheet(isPresented: $showingFromPicker) {
                AccountPickerSheet(
                    title: "Move From",
                    accounts: accounts,
                    selectedAccount: $fromAccount,
                    excludeAccount: toAccount
                )
            }
            
            // Swap Button
            if fromAccount != nil || toAccount != nil {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(FLOAnimation.quick) {
                            let temp = fromAccount
                            fromAccount = toAccount
                            toAccount = temp
                            isManualTypeOverride = false
                        }
                        HapticService.play(.light)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.brandPrimary)
                            .symbolRenderingMode(.hierarchical)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Swap accounts")
                    .accessibilityHint("Switches the from and to accounts")
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            // To Account
            Button {
                showingToPicker = true
            } label: {
                HStack {
                    Label("To", systemImage: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    if let to = toAccount {
                        accountBadge(to)
                    } else {
                        Text("Select Account")
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("To account")
            .accessibilityValue(toAccount?.name ?? "Not selected")
            .accessibilityHint("Select the account to move money to")
            .sheet(isPresented: $showingToPicker) {
                AccountPickerSheet(
                    title: "Move To",
                    accounts: accounts,
                    selectedAccount: $toAccount,
                    excludeAccount: fromAccount
                )
            }
        } header: {
            Text("Accounts")
        }
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        Section {
            HStack {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit())
                    .accessibilityLabel("Transfer amount in dollars")
                    .accessibilityValue(amountValue > 0 ? amountFormatted : "No amount entered")
            }
            .frame(minHeight: 44)
        } header: {
            Text("Amount")
        }
    }
    
    // MARK: - Transfer Type Section
    
    private var transferTypeSection: some View {
        Section {
            if let detected = detectedTransferType, !isManualTypeOverride {
                // Auto-detected type
                HStack(spacing: 12) {
                    Image(systemName: detected.icon)
                        .font(.title3)
                        .foregroundStyle(Color(hex: detected.colorHex))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detected.displayName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(detected.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                    Text("Auto")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.brandPrimary.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundStyle(Color.brandPrimary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Transfer type: \(detected.displayName), \(detected.subtitle), auto-detected")
            }
            
            // Override option
            if detectedTransferType != .internalTransfer {
                Button {
                    withAnimation(FLOAnimation.quick) {
                        isManualTypeOverride.toggle()
                        if isManualTypeOverride {
                            selectedTransferType = detectedTransferType
                        }
                    }
                } label: {
                    HStack {
                        Text(isManualTypeOverride ? "Use auto-detect" : "Change type")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: isManualTypeOverride ? "arrow.uturn.backward" : "pencil")
                            .font(.caption)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.brandPrimary)
                    .frame(minHeight: 44)
                }
                .accessibilityHint(isManualTypeOverride
                    ? "Reverts to auto-detected transfer type"
                    : "Allows manual selection of transfer type")
            }
            
            // Manual type picker
            if isManualTypeOverride {
                ForEach(Transaction.TransferType.allCases, id: \.rawValue) { type in
                    Button {
                        selectedTransferType = type
                        HapticService.play(.selection)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: type.icon)
                                .font(.body)
                                .foregroundStyle(Color(hex: type.colorHex))
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(type.displayName)
                                    .font(.subheadline)
                                Text(type.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            if selectedTransferType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.brandPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel(type.displayName)
                    .accessibilityHint(type.subtitle)
                    .accessibilityAddTraits(selectedTransferType == type ? .isSelected : [])
                }
            }
        } header: {
            Text("Transfer Type")
        } footer: {
            if let type = activeTransferType {
                Text(transferTypeFooter(type))
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
            }
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .frame(minHeight: 44)
                .accessibilityLabel("Transfer date")
            
            TextField("Note (optional)", text: $note)
                .frame(minHeight: 44)
                .accessibilityLabel("Note")
                .accessibilityHint("Add an optional description for this transfer")
        } header: {
            Text("Details")
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fromAccount?.name ?? "")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(fromAccount?.financeType.displayName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(toAccount?.name ?? "")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(toAccount?.financeType.displayName ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                HStack {
                    if let type = activeTransferType {
                        Label(type.displayName, systemImage: type.icon)
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: type.colorHex))
                    }
                    Spacer()
                    Text(amountFormatted)
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summaryAccessibilityLabel)
        } header: {
            Text("Summary")
        } footer: {
            Text("Transfers are not counted as income or expenses in your reports or tax estimates.")
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
    }
    
    // MARK: - Helper Views
    
    private func accountBadge(_ account: Account) -> some View {
        HStack(spacing: 6) {
            Image(systemName: account.icon)
                .font(.caption)
                .accessibilityHidden(true)
            Text(account.name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if account.financeType == .business {
                Text("BIZ")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.brandPrimary.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityLabel("Business account")
            }
        }
        .foregroundStyle(.primary)
    }
    
    // MARK: - Formatting Helpers
    
    private var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amountValue)) ?? "$\(amountValue)"
    }
    
    private var summaryAccessibilityLabel: String {
        let type = activeTransferType?.displayName ?? "Transfer"
        return "\(type): \(amountFormatted) from \(fromAccount?.name ?? "") to \(toAccount?.name ?? "")"
    }
    
    private func transferTypeFooter(_ type: Transaction.TransferType) -> String {
        switch type {
        case .ownersDraw:
            return "Owner's draws are not a business expense. You're taxed on profit, not what you withdraw."
        case .ownerContribution:
            return "Contributions increase your business equity. They are not counted as business income."
        case .taxSetAside:
            return "Track money set aside for quarterly estimated tax payments."
        case .reimbursement:
            return "Use when paying yourself back for a business expense you covered personally."
        case .internalTransfer:
            return "Moving money between accounts of the same type has no tax impact."
        }
    }
    
    // MARK: - Actions
    
    private func moveMoney() {
        guard let from = fromAccount, let to = toAccount else { return }
        guard amountValue > 0 else {
            errorMessage = "Please enter an amount greater than zero."
            showingError = true
            return
        }
        guard from.id != to.id else {
            errorMessage = "Source and destination accounts must be different."
            showingError = true
            return
        }
        
        isSaving = true
        
        let transferType = activeTransferType ?? .internalTransfer
        let transferAmount = amountValue
        let transferNote = note.isEmpty ? transferType.displayName : note
        
        // Generate linked IDs
        let sourceID = UUID()
        let destID = UUID()
        
        // Source transaction (money leaving this account = expense)
        let sourceTransaction = Transaction(
            id: sourceID,
            amount: transferAmount,
            date: date,
            note: transferNote,
            isIncome: false,
            merchantName: "Transfer to \(to.displayNameWithDigits)",
            financeType: from.financeType,
            account: from,
            importSource: .transfer,
            isTransfer: true,
            linkedTransferID: destID,
            transferType: transferType
        )
        
        // Destination transaction (money arriving = income)
        let destTransaction = Transaction(
            id: destID,
            amount: transferAmount,
            date: date,
            note: transferNote,
            isIncome: true,
            merchantName: "Transfer from \(from.displayNameWithDigits)",
            financeType: to.financeType,
            account: to,
            importSource: .transfer,
            isTransfer: true,
            linkedTransferID: sourceID,
            transferType: transferType
        )
        
        modelContext.insert(sourceTransaction)
        modelContext.insert(destTransaction)
        
        // Update account balances (currentBalance is stored, not computed)
        from.currentBalance -= transferAmount  // Money leaves source
        to.currentBalance += transferAmount    // Money arrives at destination
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(transferType.displayName) of \(amountFormatted) completed successfully")
            isSaving = false
            showingSuccess = true
        } catch {
            HapticService.play(.error)
            isSaving = false
            errorMessage = "Failed to save transfer: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    let title: String
    let accounts: [Account]
    @Binding var selectedAccount: Account?
    let excludeAccount: Account?
    
    @Environment(\.dismiss) private var dismiss
    
    private var businessAccounts: [Account] {
        accounts.filter { $0.financeType == .business && $0.id != excludeAccount?.id }
    }
    
    private var personalAccounts: [Account] {
        accounts.filter { $0.financeType == .personal && $0.id != excludeAccount?.id }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if !businessAccounts.isEmpty {
                    Section("Business Accounts") {
                        ForEach(businessAccounts) { account in
                            accountRow(account)
                        }
                    }
                }
                
                if !personalAccounts.isEmpty {
                    Section("Personal Accounts") {
                        ForEach(personalAccounts) { account in
                            accountRow(account)
                        }
                    }
                }
                
                if businessAccounts.isEmpty && personalAccounts.isEmpty {
                    ContentUnavailableView(
                        "No Accounts Available",
                        systemImage: "building.columns",
                        description: Text("Add at least two accounts to move money between them.")
                    )
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("\(title). \(businessAccounts.count + personalAccounts.count) accounts available.")
            }
        }
    }
    
    private func accountRow(_ account: Account) -> some View {
        Button {
            selectedAccount = account
            HapticService.play(.selection)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: account.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: account.colorHex ?? "14B8A6"))
                    .frame(width: 32)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if let digits = account.lastFourDigits {
                        Text("••••\(digits)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(formatCurrency(account.currentBalance))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                if selectedAccount?.id == account.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
        }
        .accessibilityLabel("\(account.name), balance \(formatCurrency(account.currentBalance))")
        .accessibilityAddTraits(selectedAccount?.id == account.id ? .isSelected : [])
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    MoveMoneyView()
        .environmentObject(SubscriptionManager.shared)
}
#endif
