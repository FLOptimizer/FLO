//  AddTransactionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5.1 - Fixed FinanceType comparison issues
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.5:
//  ✅ FIXED: FinanceType comparison (Account now uses Transaction.FinanceType)
//  ✅ FIXED: Explicit type annotations in sorted closure
//
//  CHANGES FROM v2.4:
//  ✅ ADDED: Account selection with horizontal chips (Premium+)
//  ✅ ADDED: Smart account defaults based on financeType
//  ✅ ADDED: Account auto-switch when financeType changes
//

import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // Transaction Properties
    @State private var amountValue: Decimal = 0
    @State private var note = ""
    @State private var isIncome = false
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?
    @State private var date = Date()
    @State private var merchantName = ""
    @State private var financeType: Transaction.FinanceType = .personal
    
    // Receipt Scanning
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var receiptImagePath: String?
    @State private var isProcessingReceipt = false
    @State private var showingReceiptPreview = false
    
    // Validation & Alerts
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingLargeAmountConfirmation = false
    
    // Loading state
    @State private var isSaving = false
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case amount, merchant, note
    }
    
    private let largeAmountThreshold: Decimal = 10_000
    
    var body: some View {
        NavigationStack {
            Form {
                receiptScanSection
                amountSection
                typeSection
                financeTypeSection
                categorySection
                accountSection
                dateSection
                detailsSection
            }
            .navigationTitle("New Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingCamera) {
                DocumentCameraView(image: $capturedImage)
            }
            .sheet(isPresented: $showingReceiptPreview) {
                receiptPreviewSheet
            }
            .onChange(of: capturedImage) {
                if let image = capturedImage {
                    processReceipt(image: image)
                    capturedImage = nil
                }
            }
            .onChange(of: financeType) { _, newType in
                updateAccountForFinanceType(newType)
            }
            .alert("Validation Error", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert("Large Amount", isPresented: $showingLargeAmountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    saveTransaction()
                }
            } message: {
                Text("You're about to save a transaction for \(formattedAmount). Is this correct?")
            }
            .onAppear {
                setDefaultAccount()
            }
            .onDisappear {
                cleanupOnCancel()
            }
        }
    }

    // MARK: - Form Sections

    private var amountSection: some View {
        Section("Amount") {
            TextField("0.00", text: amountBinding)
                .keyboardType(.decimalPad)
                .font(.title2)
                .fontWeight(.semibold)
                .focused($focusedField, equals: .amount)
                .disabled(isProcessingReceipt)
                .accessibilityLabel("Transaction amount")
                .accessibilityHint("Enter the amount in dollars")
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
            .disabled(isProcessingReceipt)
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
            .disabled(isProcessingReceipt)
            .accessibilityLabel("Transaction classification")
            .onChange(of: financeType) { _, _ in
                HapticService.play(.light)
            }
        } header: {
            Text("Classification")
        } footer: {
            Text(financeType == .business ?
                 "Business expenses are tax deductible" :
                 "Personal expenses are for your records only")
                .font(.caption)
        }
    }

    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Category?.none)
                
                if isIncome {
                    ForEach(organizedIncomeCategories) { cat in
                        categoryLabel(for: cat)
                    }
                } else {
                    Section(header: Text("BUSINESS")) {
                        ForEach(organizedBusinessCategories) { cat in
                            categoryLabel(for: cat)
                        }
                    }
                    
                    Section(header: Text("PERSONAL")) {
                        ForEach(organizedPersonalCategories) { cat in
                            categoryLabel(for: cat)
                        }
                    }
                }
            }
            .disabled(isProcessingReceipt)
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
            Text("Select an account to track where this money flows")
        } else if let account = selectedAccount, account.financeType != financeType {
            Label("Account type differs from transaction classification", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
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
            .filter { $0.isIncome == false && isBusinessCategory($0) }
            .sorted { $0.name < $1.name }
    }
    
    private var organizedPersonalCategories: [Category] {
        categories
            .filter { $0.isIncome == false && !isBusinessCategory($0) }
            .sorted { $0.name < $1.name }
    }
    
    private func isBusinessCategory(_ category: Category) -> Bool {
        let businessKeywords = ["(Business)", "Business Travel", "Office", "Professional",
                               "Contract Labor", "Marketing", "Advertising", "Software & Subscriptions"]
        return businessKeywords.contains { category.name.contains($0) }
    }
    
    private func categoryLabel(for category: Category) -> some View {
        Label {
            Text(category.name)
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(Color(flowHex: category.colorHex))
        }
        .tag(Optional(category))
    }

    private var dateSection: some View {
        Section("Date") {
            DatePicker("", selection: $date, displayedComponents: .date)
                .disabled(isProcessingReceipt)
            
            if isFutureDate {
                Label("Future date selected", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Merchant (optional)", text: $merchantName)
                .focused($focusedField, equals: .merchant)
                .disabled(isProcessingReceipt)
                .accessibilityLabel("Merchant name")
            
            TextField("Note (optional)", text: $note)
                .focused($focusedField, equals: .note)
                .disabled(isProcessingReceipt)
                .accessibilityLabel("Transaction note")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
            .disabled(isProcessingReceipt || isSaving)
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
            } else {
                Button("Save") {
                    validateAndSave()
                }
                .disabled(!canSave || isProcessingReceipt)
            }
        }
        
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                focusedField = nil
            }
        }
    }
    
    // MARK: - Amount Binding
    
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: amountValue as NSDecimalNumber) ?? "$0.00"
    }
    
    private var amountBinding: Binding<String> {
        Binding(
            get: {
                if amountValue == 0 {
                    return ""
                }
                return String(describing: amountValue)
            },
            set: { newValue in
                let sanitized = newValue.filter { "0123456789.,".contains($0) }
                
                if let decimal = Decimal(string: sanitized, locale: .current) {
                    amountValue = decimal
                } else if sanitized.isEmpty {
                    amountValue = 0
                }
            }
        )
    }
    
    // MARK: - Receipt Scan Section
    
    @ViewBuilder
    private var receiptScanSection: some View {
        Section {
            scanReceiptButton
            
            if let image = capturedImage {
                receiptPreviewRow(image: image)
            }
        }
    }

    private var scanReceiptButton: some View {
        Button {
            focusedField = nil
            showingCamera = true
        } label: {
            scanReceiptButtonLabel
        }
        .disabled(isProcessingReceipt)
        .accessibilityLabel("Scan receipt with camera")
        .accessibilityHint(isProcessingReceipt ? "Processing receipt" : "Double tap to scan")
    }
    
    private var scanReceiptButtonLabel: some View {
        HStack {
            Image(systemName: isProcessingReceipt ? "doc.text.magnifyingglass" : "doc.text.viewfinder")
                .font(.title2)
                .foregroundStyle(Color.brandPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isProcessingReceipt ? "Processing..." : "Scan Receipt")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Auto-fill from receipt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isProcessingReceipt {
                ProgressView()
            } else {
                Image(systemName: "camera.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func receiptPreviewRow(image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Receipt Captured")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isProcessingReceipt {
                    Text("Extracting data...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Tap to view full size")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                showingReceiptPreview = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.brandPrimary)
            }
            .disabled(isProcessingReceipt)
        }
    }
    
    @ViewBuilder
    private var receiptPreviewSheet: some View {
        if let image = capturedImage {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                .navigationTitle("Receipt Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showingReceiptPreview = false
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - Process Receipt
    
    private func processReceipt(image: UIImage) {
        isProcessingReceipt = true
        focusedField = nil

        if let imagePath = PhotoStorageManager.shared.saveReceiptSync(image: image) {
            receiptImagePath = imagePath
        }

        Task {
            do {
                let scannedText = try await ReceiptScannerService.shared.scanReceiptSafe(from: image)
                let parsedData = ReceiptParser.shared.parseReceipt(text: scannedText)

                await MainActor.run {
                    if let parsedAmount = parsedData.amount {
                        let roundedAmount = (parsedAmount * 100).rounded() / 100
                        amountValue = Decimal(string: String(format: "%.2f", roundedAmount)) ?? Decimal(roundedAmount)
                        announceAccessibilityChange("Amount filled from receipt: \(formattedAmount)")
                    }
                    if let parsedDate = parsedData.date {
                        date = parsedDate
                        announceAccessibilityChange("Date filled from receipt")
                    }
                    if let merchant = parsedData.merchantName {
                        merchantName = merchant
                        if note.isEmpty { note = merchant }
                        announceAccessibilityChange("Merchant filled from receipt: \(merchant)")
                    }
                    if let suggested = parsedData.suggestedCategory,
                       let cat = categories.first(where: { $0.name == suggested }) {
                        selectedCategory = cat
                        announceAccessibilityChange("Category suggested: \(suggested)")
                    }

                    isProcessingReceipt = false
                }
            } catch {
                await MainActor.run {
                    print("Receipt scanning failed: \(error)")
                    isProcessingReceipt = false
                }
            }
        }
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
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
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        
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
    
    // MARK: - Validation & Save
    
    private var canSave: Bool {
        amountValue > 0
    }
    
    private var isFutureDate: Bool {
        let calendar = Calendar.current
        let today = Date()
        
        if calendar.isDate(date, inSameDayAs: today) {
            return false
        }
        
        return calendar.startOfDay(for: date) > calendar.startOfDay(for: today)
    }
    
    private func validateAndSave() {
        if amountValue <= 0 {
            validationMessage = "Amount must be greater than zero"
            showingValidationAlert = true
            return
        }
        
        if amountValue > largeAmountThreshold {
            showingLargeAmountConfirmation = true
            return
        }
        
        if isFutureDate {
            print("Saving future-dated transaction")
        }
        
        saveTransaction()
    }
    
    private func saveTransaction() {
        isSaving = true
        
        let transaction = Transaction(
            amount: Double(truncating: amountValue as NSDecimalNumber),
            date: date,
            note: note,
            isIncome: isIncome,
            merchantName: merchantName,
            category: selectedCategory,
            financeType: financeType,
            account: selectedAccount,
            receiptImagePath: receiptImagePath,
            hasReceipt: receiptImagePath != nil
        )
        
        context.insert(transaction)
        
        do {
            try context.save()
            print("Transaction saved: \(transaction.displayName) - \(financeType.displayName) - Account: \(selectedAccount?.name ?? "None")")
            
            HapticService.play(.success)
            
            dismiss()
        } catch {
            print("Failed to save transaction: \(error)")
            
            HapticService.play(.error)
            
            isSaving = false
            validationMessage = "Failed to save transaction. Please try again."
            showingValidationAlert = true
        }
    }
    
    // MARK: - Helper Methods
    
    private func cleanupOnCancel() {
        if let path = receiptImagePath {
            print("Receipt orphaned on cancel: \(path)")
        }
    }
    
    private func announceAccessibilityChange(_ message: String) {
        #if !os(macOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}

// MARK: - Account Chip View

struct AccountChipView: View {
    let account: Account
    let isSelected: Bool
    let showBalance: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: account.color).opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: account.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: account.color))
                }
                
                // Account Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("•••• \(digits)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if showBalance {
                        Text(formatCurrency(account.currentBalance))
                            .font(.caption2)
                            .foregroundStyle(account.currentBalance >= 0 ? .green : .red)
                    }
                }
                
                // Checkmark if selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.brandPrimary)
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
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    AddTransactionView()
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(for: [Transaction.self, Category.self, Account.self], inMemory: true)
}
