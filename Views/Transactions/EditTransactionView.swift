//  EditTransactionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.3 - Split Pay sibling display
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.3:
//  ✅ Shows Split Pay info section when transaction has a splitGroupId
//  ✅ Displays the linked sibling (amount, classification) loaded from SwiftData
//  ✅ Delete confirmation now offers to delete the entire split pair when applicable
//
//  CHANGES v3.2:
//  ✅ Added editable tip field for expense transactions, pre-populated from transaction.tipAmount
//  ✅ Tip section auto-expands when transaction was created with a tip
//  ✅ hasChanges check now includes tip + showTipField changes
//
//  CHANGES v3.1 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double (initialized from transaction.amount)
//  ✅ REMOVED: parsedAmount, formattedEnteredAmount, amountFormatter computed properties
//  ✅ UPDATED: All validation/save logic to use Double amount directly
//  ✅ UPDATED: hasChanges check uses Double comparison
//  ✅ UPDATED: Keyboard Done button uses resignFirstResponder for CurrencyInputField
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters
//
//  CHANGES v3.0:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (chart emoji)
//
//  CHANGES v2.9 - Dynamic Type Verification:
//  ✅ FIXED: Receipt "Receipt Attached" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Receipt "Tap to view full size" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Finance type footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account footer "Optionally assign..." text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account footer warning label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Future date warning label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Large amount confirmation alert message missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Delete confirmation alert message missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.8:
//  ✅ ADDED: Receipt section button VoiceOver label + chevron hidden
//  ✅ ADDED: Delete button accessibility hint
//  ✅ ADDED: Date picker accessibility label
//  ✅ ADDED: Clear account button VoiceOver label
//  ✅ ADDED: Save/Cancel toolbar hints
//  ✅ ADDED: Future date warning accessibility
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Account mismatch warning accessibility
//  ✅ ADDED: Metadata section accessible labels
//
//  CHANGES v2.7:
//  - Restored account.touch() calls after balance updates
//  - Restored cancel button red styling when hasChanges
//  - Merged all v2.5 and v2.6 functionality
//
//  CHANGES v2.6:
//  - Account balance reverts when transaction is edited/deleted
//  - New account balance updates when transaction is reassigned
//  - Proper handling of income/expense balance changes
//
//  CHANGES v2.5:
//  - Added Account selection with horizontal chips (Premium+)
//  - Smart account defaults based on financeType
//  - Account auto-switch when financeType changes
//  - Account included in hasChanges check
//  - Uses AccountChipView from AddTransactionView
//
//  CHANGES v2.4:
//  - Haptic feedback on all picker changes (type, finance, category)
//  - Form entrance animations
//  - Changes indicator animation
//  - Delete confirmation with heavy haptic
//  - Success animation on save
//
//  PREVIOUS FIXES:
//  - Fixed locale-aware number parsing (CRITICAL for EU users)
//  - Disabled Save button when no changes
//  - Fixed compiler timeout by extracting sections

import SwiftUI
import FLODesignSystem
import SwiftData

struct EditTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    let transaction: Transaction
    
    // Editable Properties
    @State private var amount: Double
    @State private var tipAmount: Double
    @State private var showTipField: Bool
    @State private var note: String
    @State private var isIncome: Bool
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var date: Date
    @State private var merchantName: String
    @State private var financeType: Transaction.FinanceType
    
    // UI State
    @State private var showingReceiptImage = false
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingLargeAmountConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingAnchorWarning = false               // v4.8: Balance anchor warning
    @State private var isSaving = false
    @State private var formAppeared = false
    // v3.3: Split Pay sibling state
    @State private var splitSibling: Transaction?
    @State private var deleteEntireSplitPair: Bool = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case amount, merchant, note
    }
                        
    private let largeAmountThreshold: Double = 10_000
    
    init(transaction: Transaction) {
        self.transaction = transaction

        _amount = State(initialValue: transaction.amount)
        _tipAmount = State(initialValue: transaction.tipAmount ?? 0)
        _showTipField = State(initialValue: (transaction.tipAmount ?? 0) > 0)
        _note = State(initialValue: transaction.note)
        _isIncome = State(initialValue: transaction.isIncome)
        _selectedCategory = State(initialValue: transaction.category)
        _selectedAccount = State(initialValue: transaction.account)
        _date = State(initialValue: transaction.date)
        _merchantName = State(initialValue: transaction.merchantName)
        _financeType = State(initialValue: transaction.financeType)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                receiptSectionView
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                amountSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)

                if !isIncome {
                    tipSection
                        .opacity(formAppeared ? 1 : 0.001)
                        .offset(y: formAppeared ? 0 : 10)
                }

                typeSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                financeTypeSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                categorySection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                accountSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                dateSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                detailsSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                if transaction.splitGroupId != nil {
                    splitInfoSection
                        .opacity(formAppeared ? 1 : 0.001)
                        .offset(y: formAppeared ? 0 : 10)
                }

                metadataSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
                
                deleteSection
                    .opacity(formAppeared ? 1 : 0.001)
                    .offset(y: formAppeared ? 0 : 10)
            }
            .navigationTitle("Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingReceiptImage) {
                if let receiptPath = transaction.receiptImagePath {
                    ReceiptImageView(imagePath: receiptPath)
                }
            }
            .onChange(of: isIncome) { oldValue, newValue in
                HapticService.play(.selection)
                if newValue {
                    showTipField = false
                    tipAmount = 0
                }
            }
            .onChange(of: financeType) { oldValue, newValue in
                HapticService.play(.selection)
                updateAccountForFinanceType(newValue)
            }
            .onChange(of: selectedCategory) { oldValue, newValue in
                if newValue != nil {
                    HapticService.play(.selection)
                }
            }
            .onChange(of: selectedAccount) { oldValue, newValue in
                HapticService.play(.selection)
            }
            .onChange(of: date) { oldValue, newValue in
                HapticService.play(.light)
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) {
                    HapticService.play(.warning)
                }
            } message: {
                Text(validationMessage)
            }
            .alert("Large Amount", isPresented: $showingLargeAmountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    saveTransaction()
                }
            } message: {
                Text("You're about to save a transaction for \(amount, format: .currency(code: "USD")). Is this correct?")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    deleteEntireSplitPair = false
                }
                if splitSibling != nil {
                    Button("Delete This Half Only", role: .destructive) {
                        deleteEntireSplitPair = false
                        checkAnchorConflictAndDelete()
                    }
                    Button("Delete Both Halves", role: .destructive) {
                        deleteEntireSplitPair = true
                        checkAnchorConflictAndDelete()
                    }
                } else {
                    Button("Delete", role: .destructive) {
                        checkAnchorConflictAndDelete()
                    }
                }
            } message: {
                if splitSibling != nil {
                    Text("This transaction is part of a Split Pay pair. You can delete just this half or both halves. This cannot be undone.")
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                } else {
                    Text("Are you sure you want to delete this transaction? This cannot be undone.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            // v4.8: Balance anchor conflict warning for single delete
            .alert("Balance Checkpoint Warning", isPresented: $showingAnchorWarning) {
                Button("Delete Anyway", role: .destructive) {
                    deleteTransaction()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This transaction is dated before your last reconciliation checkpoint. Deleting it may cause balance drift.")
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    formAppeared = true
                }
                // v2.8: Screen announcement
                AccessibilityAnnouncement.screenChanged("Edit Transaction: \(transaction.displayName)")
                // v3.3: Load split sibling if applicable
                loadSplitSibling()
            }
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var receiptSectionView: some View {
        if transaction.hasReceipt {
            receiptSection
        }
    }
    
    @ViewBuilder
    private var receiptSection: some View {
        if let receiptPath = transaction.receiptImagePath,
           let image = PhotoStorageManager.shared.loadReceiptSync(filename: receiptPath) {
            Section {
                Button {
                    HapticService.play(.light)
                    showingReceiptImage = true
                } label: {
                    HStack {
                        Image(platformImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Receipt Attached")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.primary)
                            
                            Text("Tap to view full size")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            // v2.8: Decorative, parent handles
                            .accessibilityHidden(true)
                    }
                }
                // v2.8: VoiceOver label for receipt button
                .accessibilityElement(children: .combine)
                .accessibilityLabel("View attached receipt")
                .accessibilityHint("Double tap to view full size receipt image")
            } header: {
                HStack {
                    Image(systemName: "doc.text.fill")
                    Text("Receipt")
                }
                .foregroundStyle(Color.brandPrimary)
            }
        }
    }
    
    private var amountSection: some View {
        Section("Amount") {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Transaction amount",
                showDoneButton: false
            )
        }
    }

    private var tipSection: some View {
        Section {
            Toggle("Includes tip", isOn: $showTipField.animation(.easeInOut(duration: 0.2)))
                .accessibilityHint("Enable to record a tip or gratuity included in this amount")
                .onChange(of: showTipField) { _, isOn in
                    if !isOn { tipAmount = 0 }
                    HapticService.play(.light)
                }

            if showTipField {
                CurrencyInputField(
                    amount: $tipAmount,
                    accessibilityLabelText: "Tip amount",
                    showDoneButton: false
                )
            }
        } header: {
            Text("Tip")
        } footer: {
            if showTipField {
                Text("Tip is already included in the amount above. Recording it separately helps with reporting and CSV export.")
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
        }
    }
    
    private var typeSection: some View {
        Section("Transaction Type") {
            Picker("Type", selection: $isIncome) {
                Label("Expense", systemImage: "arrow.up.circle")
                    .tag(false)
                Label("Income", systemImage: "arrow.down.circle")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Transaction type")
        }
    }
    
    private var financeTypeSection: some View {
        Section {
            Picker("Classification", selection: $financeType) {
                Label("Business", systemImage: "briefcase.fill")
                    .tag(Transaction.FinanceType.business)
                Label("Personal", systemImage: "person.fill")
                    .tag(Transaction.FinanceType.personal)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Transaction classification")
        } header: {
            Text("Classification")
        } footer: {
            Text(financeTypeFooterText)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Category?.none)
                
                if isIncome {
                    ForEach(organizedIncomeCategories) { cat in
                        categoryLabel(for: cat)
                            .tag(Optional(cat))
                    }
                } else {
                    Section(header: Text("BUSINESS")) {
                        ForEach(organizedBusinessCategories) { cat in
                            categoryLabel(for: cat)
                                .tag(Optional(cat))
                        }
                    }
                    
                    Section(header: Text("PERSONAL")) {
                        ForEach(organizedPersonalCategories) { cat in
                            categoryLabel(for: cat)
                                .tag(Optional(cat))
                        }
                    }
                }
            }
            // v2.8: VoiceOver hint
            .accessibilityHint("Select a category for this transaction")
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
                        // v2.8: VoiceOver label
                        .accessibilityLabel("Clear account selection")
                        .accessibilityHint("Double tap to remove account assignment")
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
                    AccountChipView(
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
            Text("Optionally assign to an account for balance tracking")
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        } else if let account = selectedAccount, account.financeType != financeType {
            Label("Account type differs from transaction classification", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.orange)
                // v2.8: VoiceOver reads warning
                .accessibilityLabel("Warning: Account type differs from transaction classification")
        }
    }
    
    /// Accounts sorted: matching financeType first, then primary, then others
    private var sortedAccounts: [Account] {
        let active = accounts.filter { $0.isActive && $0.includeInTransactions }
        
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
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        
        // Only auto-switch if current account doesn't match new type
        if let current = selectedAccount, current.financeType != newType {
            let active = accounts.filter { $0.isActive }
            
            // Try to find a matching account
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
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("", selection: $date, displayedComponents: .date)
                // v2.8: VoiceOver label
                .accessibilityLabel("Transaction date")
                .accessibilityHint("Select the date for this transaction")
            
            if isFutureDate {
                futureDateWarning
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(FLOAnimation.quick, value: isFutureDate)
    }
    
    private var detailsSection: some View {
        Section("Details") {
            TextField("Merchant", text: $merchantName)
                .focused($focusedField, equals: .merchant)
                .accessibilityLabel("Merchant name")
            
            TextField("Note", text: $note)
                .focused($focusedField, equals: .note)
                .accessibilityLabel("Transaction note")
        }
    }
    
    // v3.3: Split Pay sibling info
    @ViewBuilder
    private var splitInfoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "rectangle.split.2x1.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Part of a Split Pay pair")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if let sibling = splitSibling {
                        Text("Linked: \(sibling.financeType == .business ? "Business" : "Personal") • \(sibling.amount.formatted(.currency(code: "USD")))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Linked transaction not found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Split Pay")
        } footer: {
            Text("Both halves share the same Split Group ID and can be exported as a pair.")
                .lineLimit(3)
                .minimumScaleFactor(0.8)
        }
    }

    private func loadSplitSibling() {
        guard let groupId = transaction.splitGroupId else {
            splitSibling = nil
            return
        }
        let txId = transaction.id
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.splitGroupId == groupId && $0.id != txId }
        )
        do {
            let results = try context.fetch(descriptor)
            splitSibling = results.first
        } catch {
            print("Failed to fetch split sibling: \(error)")
            splitSibling = nil
        }
    }

    private var metadataSection: some View {
        Section("Information") {
            LabeledContent("Created", value: transaction.createdAt, format: .dateTime)
            LabeledContent("Last Updated", value: transaction.updatedAt, format: .dateTime)
            
            // Show current account if assigned
            if let account = transaction.account {
                LabeledContent("Account", value: account.name)
            }
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                HapticService.play(.heavy)
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Transaction", systemImage: "trash")
                    Spacer()
                }
            }
            // v2.8: VoiceOver hint
            .accessibilityLabel("Delete transaction")
            .accessibilityHint("Double tap to permanently delete this transaction. A confirmation will appear.")
        }
    }
    
    // MARK: - Helper Views
    
    private var futureDateWarning: some View {
        Label("Future date selected", systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.orange)
            // v2.8: VoiceOver reads warning
            .accessibilityLabel("Warning: Future date selected")
    }
    
    private var financeTypeFooterText: String {
        financeType == .business ?
            "Business expenses may be tax deductible" :
            "Personal expenses for your records only"
    }
    
    @ViewBuilder
    private func categoryLabel(for category: Category) -> some View {
        Label(category.name, systemImage: category.icon)
            .foregroundStyle(category.color)
    }
    
    // MARK: - Category Organization
    
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
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                HapticService.play(.light)
                dismiss()
            }
            .disabled(isSaving)
            .foregroundStyle(hasChanges ? .red : .primary)  // v2.7: Restored red styling
            // v2.8: VoiceOver hint
            .accessibilityHint(hasChanges ? "Double tap to discard changes and close" : "Double tap to close")
        }
        
        ToolbarItem(placement: .confirmationAction) {
            ZStack {
                if isSaving {
                    ProgressView()
                        .accessibilityLabel("Saving changes")
                } else {
                    Button("Save") {
                        HapticService.play(.medium)
                        validateAndSave()
                    }
                    .disabled(!canSave || !hasChanges)
                    .bold(hasChanges && canSave)
                    .foregroundStyle(hasChanges && canSave ? Color.brandPrimary : .secondary)
                    // v2.8: VoiceOver hint
                    .accessibilityLabel(hasChanges ? "Save changes" : "No changes to save")
                    .accessibilityHint(hasChanges && canSave ? "Double tap to save your changes" : "")
                }
            }
        }
        
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                HapticService.play(.light)
                focusedField = nil
                #if canImport(UIKit)
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                #endif
            }
        }
    }
    
    // MARK: - Validation & Save
    
    private var canSave: Bool {
        amount > 0
    }

    private var isFutureDate: Bool {
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.isDate(date, inSameDayAs: today) {
            return false
        }
        
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: today)
    }
    
    private var hasChanges: Bool {
        return amount != transaction.amount ||
               resolvedTipAmount != transaction.tipAmount ||
               note != transaction.note ||
               isIncome != transaction.isIncome ||
               selectedCategory?.id != transaction.category?.id ||
               selectedAccount?.id != transaction.account?.id ||
               date != transaction.date ||
               merchantName != transaction.merchantName ||
               financeType != transaction.financeType
    }

    /// Tip value to persist: nil unless the toggle is on, the section is visible (expense), and value > 0.
    private var resolvedTipAmount: Double? {
        guard !isIncome, showTipField, tipAmount > 0 else { return nil }
        return tipAmount
    }
    
    private func validateAndSave() {
        if amount <= 0 {
            validationMessage = "Amount must be greater than zero"
            showingValidationAlert = true
            HapticService.play(.warning)
            return
        }

        if amount > largeAmountThreshold {
            showingLargeAmountConfirmation = true
            return
        }
        
        if isFutureDate {
            print("⚠️ Saving future-dated transaction")
        }
        
        saveTransaction()
    }
    
    private func saveTransaction() {
        let amt = amount
        guard amt > 0 else { return }

        guard hasChanges else {
            dismiss()
            return
        }
        
        isSaving = true
        
        // Store original values for balance calculations
        let originalAmount = transaction.amount
        let originalIsIncome = transaction.isIncome
        let originalAccount = transaction.account
        
        // STEP 1: Revert balance on the ORIGINAL account (if any)
        if let oldAccount = originalAccount {
            if originalIsIncome {
                oldAccount.currentBalance -= originalAmount
            } else {
                oldAccount.currentBalance += originalAmount
            }
            oldAccount.lastBalanceUpdate = Date()
            oldAccount.touch()  // v2.7: Restored touch() call
            print("📊 Reverted balance on \(oldAccount.name): \(oldAccount.formattedBalance)")
        }
        
        // STEP 2: Apply changes to transaction
        transaction.amount = amt
        transaction.tipAmount = resolvedTipAmount
        transaction.note = note
        transaction.isIncome = isIncome
        transaction.category = selectedCategory
        transaction.account = selectedAccount
        transaction.date = date
        transaction.merchantName = merchantName
        transaction.financeType = financeType
        transaction.updatedAt = Date()
        
        // STEP 3: Apply balance to the NEW account (if any)
        if let newAccount = selectedAccount {
            if isIncome {
                newAccount.currentBalance += amt
            } else {
                newAccount.currentBalance -= amt
            }
            newAccount.lastBalanceUpdate = Date()
            newAccount.touch()  // v2.7: Restored touch() call
            print("📊 Applied balance to \(newAccount.name): \(newAccount.formattedBalance)")
        }
        
        do {
            try context.save()
            print("✅ Transaction updated: \(transaction.displayName) - \(financeType.displayName) - Account: \(selectedAccount?.name ?? "None")")
            
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Transaction updated successfully")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                dismiss()
            }
        } catch {
            print("❌ Failed to update transaction: \(error)")
            
            HapticService.play(.error)
            
            isSaving = false
            validationMessage = "Failed to update transaction. Please try again."
            showingValidationAlert = true
        }
    }
    
    // v4.8: Check for balance anchor conflict before deleting
    private func checkAnchorConflictAndDelete() {
        guard let account = transaction.account else {
            deleteTransaction()
            return
        }
        if let anchors = try? context.fetch(FetchDescriptor<BalanceAnchor>()) {
            let accountAnchors = anchors.filter { $0.account?.id == account.id }
            if let latestAnchor = accountAnchors.max(by: { $0.anchorDate < $1.anchorDate }),
               transaction.date < latestAnchor.anchorDate {
                showingAnchorWarning = true
                return
            }
        }
        deleteTransaction()
    }

    private func deleteTransaction() {
        let transactionName = transaction.displayName

        // Revert account balance before deleting
        if let account = transaction.account {
            if transaction.isIncome {
                account.currentBalance -= transaction.amount
            } else {
                account.currentBalance += transaction.amount
            }
            account.lastBalanceUpdate = Date()
            account.touch()  // v2.7: Restored touch() call
            print("📊 Reverted balance on \(account.name) before delete: \(account.formattedBalance)")
        }

        context.delete(transaction)

        // v3.3: Optionally delete the split sibling too
        if deleteEntireSplitPair, let sibling = splitSibling {
            if let account = sibling.account {
                if sibling.isIncome {
                    account.currentBalance -= sibling.amount
                } else {
                    account.currentBalance += sibling.amount
                }
                account.lastBalanceUpdate = Date()
                account.touch()
            }
            context.delete(sibling)
            print("📊 Also deleted split sibling")
        }
        
        do {
            try context.save()
            print("✅ Transaction deleted: \(transactionName)")
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Transaction deleted")
            dismiss()
        } catch {
            print("❌ Failed to delete transaction: \(error)")
            HapticService.play(.error)
            validationMessage = "Failed to delete transaction. Please try again."
            showingValidationAlert = true
        }
    }
}

// MARK: - Preview

#Preview("Edit Expense") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, Account.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let category = Category(
        name: "Office Supplies",
        icon: "pencil.circle.fill",
        colorHex: "F59E0B",
        isIncome: false
    )
    container.mainContext.insert(category)
    
    let account = Account(
        name: "Business Checking",
        accountType: .checking,
        currentBalance: 5000,
        financeType: .business
    )
    container.mainContext.insert(account)
    
    let transaction = Transaction(
        amount: 125.50,
        date: .now,
        note: "Office Supplies",
        isIncome: false,
        merchantName: "Staples",
        category: category,
        financeType: .business,
        account: account,
        hasReceipt: false
    )
    container.mainContext.insert(transaction)
    
    return EditTransactionView(transaction: transaction)
        .modelContainer(container)
        .environmentObject(SubscriptionManager.shared)
}

#Preview("Edit Income") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, Account.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let category = Category(
        name: "Client Payment",
        icon: "dollarsign.circle.fill",
        colorHex: "14B8A6",
        isIncome: true
    )
    container.mainContext.insert(category)
    
    let transaction = Transaction(
        amount: 5000,
        date: .now,
        note: "Client Payment",
        isIncome: true,
        merchantName: "Acme Corp",
        category: category,
        financeType: .business,
        hasReceipt: true
    )
    container.mainContext.insert(transaction)
    
    return EditTransactionView(transaction: transaction)
        .modelContainer(container)
        .environmentObject(SubscriptionManager.shared)
}
