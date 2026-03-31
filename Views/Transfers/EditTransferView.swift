//  EditTransferView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  View for editing existing transfers.
//
//  CHANGES v1.2 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double
//  ✅ REMOVED: parsedAmount computed property (String parsing no longer needed)
//  ✅ UPDATED: canSave, loadTransferData(), saveChanges() to use Double amount directly
//
//  CHANGES v1.1:
//  ✅ FIXED: Use account.color instead of account.colorHex (optional unwrapping error)
//
//  FEATURES:
//  ✅ Pre-populated form with existing values
//  ✅ Change accounts (with balance adjustment)
//  ✅ Update amount, date, notes
//  ✅ Tax payment field editing
//  ✅ Haptics and animations
//  ✅ Full VoiceOver accessibility
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct EditTransferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Account.name) private var accounts: [Account]
    
    let transfer: Transfer
    
    // MARK: - Form State
    
    @State private var fromAccount: Account?
    @State private var toAccount: Account?
    @State private var amount: Double = 0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var reference: String = ""
    @State private var transferType: TransferType = .internal
    
    // Tax Payment Fields
    @State private var taxQuarter: Int = 1
    @State private var taxYear: Int = Calendar.current.component(.year, from: Date())
    @State private var taxAuthority: TaxAuthority = .federalIRS
    
    // UI State
    @State private var isSaving: Bool = false
    @State private var showFromPicker: Bool = false
    @State private var showToPicker: Bool = false
    @State private var viewAppeared: Bool = false
    
    // MARK: - Computed Properties
    
    private var activeAccounts: [Account] {
        accounts.filter { $0.isActive }
    }
    
    private var businessAccounts: [Account] {
        activeAccounts.filter { $0.financeType == .business }
    }
    
    private var personalAccounts: [Account] {
        activeAccounts.filter { $0.financeType == .personal }
    }
    
    private var canSave: Bool {
        guard amount > 0 else { return false }
        guard fromAccount != nil, toAccount != nil else { return false }
        guard fromAccount?.id != toAccount?.id else { return false }
        return true
    }
    
    private var isTaxPayment: Bool {
        transferType == .taxPayment
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Accounts
                accountsSection
                
                // Section 2: Transfer Type
                transferTypeSection
                
                // Section 3: Amount & Date
                amountSection
                
                // Section 4: Tax Payment Details (conditional)
                if isTaxPayment {
                    taxPaymentSection
                }
                
                // Section 5: Notes & Reference
                notesSection
                
                // Section 6: Info
                infoSection
            }
            .navigationTitle("Edit Transfer")
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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave || isSaving)
                }
            }
            .sheet(isPresented: $showFromPicker) {
                accountPickerSheet(
                    title: "From Account",
                    selected: $fromAccount,
                    excluding: toAccount
                )
            }
            .sheet(isPresented: $showToPicker) {
                accountPickerSheet(
                    title: "To Account",
                    selected: $toAccount,
                    excluding: fromAccount
                )
            }
            .onAppear {
                loadTransferData()
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Edit Transfer")
            }
        }
    }
    
    // MARK: - Load Data
    
    private func loadTransferData() {
        fromAccount = transfer.fromAccount
        toAccount = transfer.toAccount
        amount = transfer.amount
        date = transfer.date
        notes = transfer.notes ?? ""
        reference = transfer.reference ?? ""
        transferType = transfer.transferType
        taxQuarter = transfer.taxQuarter ?? 1
        taxYear = transfer.taxYear ?? Calendar.current.component(.year, from: Date())
        taxAuthority = transfer.taxAuthority ?? .federalIRS
    }
    
    // MARK: - Accounts Section
    
    private var accountsSection: some View {
        Section {
            // From Account
            Button {
                HapticService.play(.light)
                showFromPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("From")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let account = fromAccount {
                            HStack(spacing: 8) {
                                Image(systemName: account.accountType.icon)
                                    .foregroundStyle(Color(flowHex: account.color))
                                Text(account.name)
                                    .fontWeight(.medium)
                            }
                        } else {
                            Text("Select Account")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let account = fromAccount {
                        Text(account.currentBalance, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Direction Arrow
            HStack {
                Spacer()
                Image(systemName: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .padding(.vertical, 4)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .accessibilityHidden(true)
            
            // To Account
            Button {
                HapticService.play(.light)
                showToPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let account = toAccount {
                            HStack(spacing: 8) {
                                Image(systemName: account.accountType.icon)
                                    .foregroundStyle(Color(flowHex: account.color))
                                Text(account.name)
                                    .fontWeight(.medium)
                            }
                        } else {
                            Text("Select Account")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let account = toAccount {
                        Text(account.currentBalance, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } header: {
            Text("Accounts")
        }
    }
    
    // MARK: - Transfer Type Section
    
    private var transferTypeSection: some View {
        Section {
            Picker("Type", selection: $transferType) {
                ForEach(TransferType.allCases) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .onChange(of: transferType) { _, _ in
                HapticService.play(.selection)
            }
        } header: {
            Text("Transfer Type")
        } footer: {
            Text(transferType.description)
        }
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        Section {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Transfer amount"
            )

            DatePicker("Date", selection: $date, displayedComponents: .date)
        } header: {
            Text("Amount")
        }
    }
    
    // MARK: - Tax Payment Section
    
    private var taxPaymentSection: some View {
        Section {
            Picker("Tax Authority", selection: $taxAuthority) {
                ForEach(TaxAuthority.allCases, id: \.self) { authority in
                    Label(authority.displayName, systemImage: authority.icon)
                        .tag(authority)
                }
            }
            
            Picker("Quarter", selection: $taxQuarter) {
                Text("Q1 (Jan-Mar)").tag(1)
                Text("Q2 (Apr-Jun)").tag(2)
                Text("Q3 (Jul-Sep)").tag(3)
                Text("Q4 (Oct-Dec)").tag(4)
            }
            
            Picker("Tax Year", selection: $taxYear) {
                ForEach((taxYear - 2)...(taxYear + 1), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
        } header: {
            Text("Tax Payment Details")
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        Section {
            TextField("Notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
            
            TextField("Reference # (optional)", text: $reference)
        } header: {
            Text("Details")
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            LabeledContent("Created") {
                Text(transfer.createdAt, format: .dateTime.month().day().year().hour().minute())
                    .foregroundStyle(.secondary)
            }
            
            if transfer.createdAt != transfer.updatedAt {
                LabeledContent("Last Updated") {
                    Text(transfer.updatedAt, format: .dateTime.month().day().year().hour().minute())
                        .foregroundStyle(.secondary)
                }
            }
            
            if transfer.isFromRecurring {
                LabeledContent("Source") {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                        Text("Recurring")
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Info")
        }
    }
    
    // MARK: - Account Picker Sheet
    
    private func accountPickerSheet(
        title: String,
        selected: Binding<Account?>,
        excluding: Account?
    ) -> some View {
        NavigationStack {
            List {
                if !businessAccounts.isEmpty {
                    Section {
                        ForEach(businessAccounts) { account in
                            if account.id != excluding?.id {
                                accountRow(account: account, selected: selected)
                            }
                        }
                    } header: {
                        Label("Business", systemImage: "briefcase.fill")
                    }
                }
                
                if !personalAccounts.isEmpty {
                    Section {
                        ForEach(personalAccounts) { account in
                            if account.id != excluding?.id {
                                accountRow(account: account, selected: selected)
                            }
                        }
                    } header: {
                        Label("Personal", systemImage: "person.fill")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showFromPicker = false
                        showToPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func accountRow(account: Account, selected: Binding<Account?>) -> some View {
        Button {
            HapticService.play(.selection)
            selected.wrappedValue = account
            showFromPicker = false
            showToPicker = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: account.accountType.icon)
                    .font(.title3)
                    .foregroundStyle(Color(flowHex: account.color))
                    .frame(width: 36, height: 36)
                    .background(Color(flowHex: account.color).opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(account.financeType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(account.currentBalance, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if selected.wrappedValue?.id == account.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.brandPrimary)
                        .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Save
    
    private func saveChanges() {
        let amt = amount
        guard amt > 0,
              let from = fromAccount,
              let to = toAccount else {
            return
        }
        
        isSaving = true
        HapticService.play(.medium)
        
        let success = TransferService.shared.updateTransfer(
            context: context,
            transfer: transfer,
            newAmount: amt,
            newFromAccount: from,
            newToAccount: to,
            newDate: date,
            newNotes: notes.isEmpty ? nil : notes,
            newReference: reference.isEmpty ? nil : reference,
            newTransferType: transferType
        )
        
        // Update tax fields manually if needed
        if isTaxPayment {
            transfer.taxQuarter = taxQuarter
            transfer.taxYear = taxYear
            transfer.taxAuthority = taxAuthority
        } else {
            transfer.taxQuarter = nil
            transfer.taxYear = nil
            transfer.taxAuthority = nil
        }
        
        if success {
            HapticService.play(.success)
            dismiss()
        } else {
            HapticService.play(.error)
            isSaving = false
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    EditTransferView(transfer: .previewOwnersDraw)
        .modelContainer(for: [Transfer.self, Account.self], inMemory: true)
}
#endif
