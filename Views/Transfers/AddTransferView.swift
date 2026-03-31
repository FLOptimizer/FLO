//  AddTransferView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Debt Payment Split
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  View for creating new transfers between accounts.
//  Auto-detects transfer type based on account selection.
//
//  CHANGES v1.2 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double
//  ✅ REMOVED: parsedAmount computed property (String parsing no longer needed)
//  ✅ UPDATED: canSave and saveTransfer() to use Double amount directly
//
//  CHANGES v1.1:
//  ✅ FIXED: Use account.color instead of account.colorHex (optional unwrapping error)
//
//  FEATURES:
//  ✅ From/To account pickers with balance display
//  ✅ Auto-detection of transfer type (Owner's Draw, Contribution, etc.)
//  ✅ Educational callout explaining the transfer type
//  ✅ Tax payment fields (quarter, year, authority)
//  ✅ Make Recurring option with frequency picker
//  ✅ Full haptics and animations
//  ✅ Complete VoiceOver accessibility
//  ✅ Dark mode support
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct AddTransferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // MARK: - Form State
    
    @State private var fromAccount: Account?
    @State private var toAccount: Account?
    @State private var amount: Double = 0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var reference: String = ""

    // Tax Payment Fields
    @State private var taxQuarter: Int = 1
    @State private var taxYear: Int = Calendar.current.component(.year, from: Date())
    @State private var taxAuthority: TaxAuthority = .federalIRS
    
    // Debt Payment Split Fields
    @State private var showPaymentBreakdown: Bool = false
    @State private var interestPortion: Double = 0
    @State private var principalPortion: Double = 0
    @State private var useAutoCalculate: Bool = true

    // Recurring Fields
    @State private var makeRecurring: Bool = false
    @State private var recurringName: String = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var dayOfMonth: Int = 1
    
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
    
    private var detectedTransferType: TransferType {
        guard let from = fromAccount, let to = toAccount else {
            return .internal
        }
        return TransferService.shared.detectTransferType(from: from, to: to)
    }
    
    private var canSave: Bool {
        guard amount > 0 else { return false }
        guard fromAccount != nil, toAccount != nil else { return false }
        guard fromAccount?.id != toAccount?.id else { return false }
        if makeRecurring && recurringName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }
    
    private var isTaxPayment: Bool {
        detectedTransferType == .taxPayment
    }

    private var isDebtPayment: Bool {
        detectedTransferType == .debtPayment
    }

    /// Whether the destination account has APR set (enables auto-calculate)
    private var destinationHasAPR: Bool {
        guard let to = toAccount else { return false }
        return (to.apr ?? 0) > 0
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Accounts
                accountsSection
                
                // Section 2: Transfer Type Explanation
                if fromAccount != nil && toAccount != nil {
                    transferTypeSection
                }
                
                // Section 3: Amount & Date
                amountSection
                
                // Section 4: Tax Payment Details (conditional)
                if isTaxPayment {
                    taxPaymentSection
                }
                
                // Section 5: Debt Payment Breakdown (conditional)
                if isDebtPayment {
                    paymentBreakdownSection
                }

                // Section 6: Notes & Reference
                notesSection
                
                // Section 7: Make Recurring
                recurringSection
            }
            .navigationTitle("New Transfer")
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
                        saveTransfer()
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
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("New Transfer")
            }
            .onChange(of: amount) { _, _ in
                if showPaymentBreakdown && useAutoCalculate && destinationHasAPR {
                    autoCalculateSplit()
                }
            }
            .onChange(of: toAccount) { _, _ in
                if showPaymentBreakdown && useAutoCalculate && destinationHasAPR {
                    autoCalculateSplit()
                }
            }
        }
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
            .accessibilityLabel("From account: \(fromAccount?.name ?? "not selected")")
            .accessibilityHint("Double tap to select source account")
            
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
            .accessibilityLabel("To account: \(toAccount?.name ?? "not selected")")
            .accessibilityHint("Double tap to select destination account")
        } header: {
            Text("Accounts")
        }
    }
    
    // MARK: - Transfer Type Section
    
    private var transferTypeSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: detectedTransferType.icon)
                    .font(.title2)
                    .foregroundStyle(Color(flowHex: detectedTransferType.color))
                    .frame(width: 44, height: 44)
                    .background(Color(flowHex: detectedTransferType.color).opacity(0.12))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(detectedTransferType.displayName)
                        .font(.headline)
                    Text(detectedTransferType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Transfer Type")
        } footer: {
            if detectedTransferType == .ownersDraw {
                Text("⚠️ Owner's draws are NOT business expenses. The income was already taxed as pass-through.")
            } else if detectedTransferType == .capitalContribution {
                Text("💡 Capital contributions increase your basis in the business. They are NOT business income.")
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .animation(FLOAnimation.standard, value: detectedTransferType)
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        Section {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Transfer amount"
            )

            DatePicker("Date", selection: $date, displayedComponents: .date)
                .onChange(of: date) { _, _ in
                    HapticService.play(.light)
                }
        } header: {
            Text("Amount")
        }
    }
    
    // MARK: - Payment Breakdown Section

    private var paymentBreakdownSection: some View {
        Section {
            Toggle("Split Payment (Interest / Principal)", isOn: $showPaymentBreakdown.animation())
                .accessibilityHint("Break down this debt payment into interest and principal portions")
                .onChange(of: showPaymentBreakdown) { _, isOn in
                    HapticService.play(.light)
                    if isOn && useAutoCalculate && destinationHasAPR {
                        autoCalculateSplit()
                    }
                }

            if showPaymentBreakdown {
                if destinationHasAPR {
                    Picker("Calculation Method", selection: $useAutoCalculate) {
                        Text("Auto-calculate").tag(true)
                        Text("Enter manually").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: useAutoCalculate) { _, auto in
                        if auto { autoCalculateSplit() }
                    }
                }

                HStack {
                    Text("Interest")
                    Spacer()
                    if useAutoCalculate && destinationHasAPR {
                        Text(interestPortion, format: .currency(code: "USD"))
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    } else {
                        CurrencyInputField(
                            amount: $interestPortion,
                            placeholder: "$0.00",
                            font: .body,
                            fontWeight: .regular,
                            accessibilityLabelText: "Interest portion in dollars"
                        )
                        .frame(maxWidth: 150)
                        .onChange(of: interestPortion) { _, newInterest in
                            if amount > 0 {
                                principalPortion = max(0, amount - newInterest)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Interest portion: \(interestPortion, format: .currency(code: "USD"))")

                HStack {
                    Text("Principal")
                    Spacer()
                    if useAutoCalculate && destinationHasAPR {
                        Text(principalPortion, format: .currency(code: "USD"))
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    } else {
                        CurrencyInputField(
                            amount: $principalPortion,
                            placeholder: "$0.00",
                            font: .body,
                            fontWeight: .regular,
                            accessibilityLabelText: "Principal portion in dollars"
                        )
                        .frame(maxWidth: 150)
                        .onChange(of: principalPortion) { _, newPrincipal in
                            if amount > 0 {
                                interestPortion = max(0, amount - newPrincipal)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Principal portion: \(principalPortion, format: .currency(code: "USD"))")

                if interestPortion + principalPortion != amount && amount > 0 &&
                    interestPortion > 0 && principalPortion > 0 {
                    Text("Interest + Principal should equal total payment (\(amount, format: .currency(code: "USD")))")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Payment Breakdown")
        } footer: {
            if showPaymentBreakdown {
                Text("Interest is categorized as a tax-deductible expense (Schedule C Line 16a). Principal reduces the loan balance.")
            } else {
                Text("Optional: Split this payment into interest and principal for accurate tax reporting")
            }
        }
    }

    private func autoCalculateSplit() {
        guard let to = toAccount,
              let apr = to.apr, apr > 0,
              amount > 0 else { return }

        let monthlyRate = apr / 12.0 / 100.0
        let calculatedInterest = abs(to.currentBalance) * monthlyRate
        interestPortion = min(calculatedInterest, amount)
        principalPortion = amount - interestPortion
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
            .onChange(of: taxAuthority) { _, _ in
                HapticService.play(.selection)
            }
            
            Picker("Quarter", selection: $taxQuarter) {
                Text("Q1 (Jan-Mar)").tag(1)
                Text("Q2 (Apr-Jun)").tag(2)
                Text("Q3 (Jul-Sep)").tag(3)
                Text("Q4 (Oct-Dec)").tag(4)
            }
            .onChange(of: taxQuarter) { _, _ in
                HapticService.play(.selection)
            }
            
            Picker("Tax Year", selection: $taxYear) {
                ForEach((taxYear - 1)...(taxYear + 1), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .onChange(of: taxYear) { _, _ in
                HapticService.play(.selection)
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
                .keyboardType(.default)
        } header: {
            Text("Details")
        }
    }
    
    // MARK: - Recurring Section
    
    private var recurringSection: some View {
        Section {
            Toggle("Make Recurring", isOn: $makeRecurring)
                .onChange(of: makeRecurring) { _, newValue in
                    HapticService.play(newValue ? .medium : .light)
                    if newValue && recurringName.isEmpty {
                        recurringName = "Monthly \(detectedTransferType.displayName)"
                    }
                }
            
            if makeRecurring {
                TextField("Name", text: $recurringName)
                    .accessibilityLabel("Recurring transfer name")
                
                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .onChange(of: frequency) { _, _ in
                    HapticService.play(.selection)
                }
                
                if frequency == .monthly {
                    Picker("Day of Month", selection: $dayOfMonth) {
                        Text("Last Day").tag(0)
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }
                    .onChange(of: dayOfMonth) { _, _ in
                        HapticService.play(.selection)
                    }
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            if makeRecurring {
                Text("FLO will automatically create this transfer on schedule.")
            }
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
                // Business Accounts
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
                
                // Personal Accounts
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
        .accessibilityLabel("\(account.name), \(account.financeType.displayName), balance \(AccessibilityFormatters.spokenCurrency(account.currentBalance))")
        .accessibilityAddTraits(selected.wrappedValue?.id == account.id ? .isSelected : [])
    }
    
    // MARK: - Save
    
    private func saveTransfer() {
        let amt = amount
        guard amt > 0,
              let from = fromAccount,
              let to = toAccount else {
            return
        }
        
        isSaving = true
        HapticService.play(.medium)
        
        // Create recurring transfer if requested
        var recurringTransfer: RecurringTransfer? = nil
        if makeRecurring {
            let recurring = RecurringTransfer(
                name: recurringName.trimmingCharacters(in: .whitespaces),
                amount: amount,
                transferType: detectedTransferType,
                frequency: frequency,
                dayOfMonth: frequency == .monthly ? dayOfMonth : nil,
                fromAccount: from,
                toAccount: to,
                taxAuthority: isTaxPayment ? taxAuthority : nil
            )
            context.insert(recurring)
            recurringTransfer = recurring
        }
        
        // Create the transfer
        let transfer = TransferService.shared.createTransfer(
            context: context,
            amount: amount,
            fromAccount: from,
            toAccount: to,
            date: date,
            notes: notes.isEmpty ? nil : notes,
            reference: reference.isEmpty ? nil : reference,
            transferType: detectedTransferType,
            taxQuarter: isTaxPayment ? taxQuarter : nil,
            taxYear: isTaxPayment ? taxYear : nil,
            taxAuthority: isTaxPayment ? taxAuthority : nil,
            recurringTransfer: recurringTransfer
        )

        // Apply payment split data if breakdown was enabled
        if showPaymentBreakdown, let transfer = transfer,
           interestPortion > 0 || principalPortion > 0 {
            transfer.interestPortion = interestPortion
            transfer.principalPortion = principalPortion
            transfer.paymentGroupId = UUID()
            try? context.save()
        }
        
        if transfer != nil {
            HapticService.play(.success)
            dismiss()
        } else {
            HapticService.play(.error)
            isSaving = false
        }
    }
}

// MARK: - Preview

#Preview {
    AddTransferView()
        .modelContainer(for: [Transfer.self, Account.self, RecurringTransfer.self], inMemory: true)
}
