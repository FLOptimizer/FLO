//  AddTransactionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.0 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + amountBinding with CurrencyInputField component
//  ✅ CHANGED: Amount state from Decimal (amountValue) to Double (amountDouble)
//  ✅ REMOVED: amountBinding computed property (penny-up handles formatting internally)
//  ✅ REMOVED: formattedAmount computed property (CurrencyInputField formats display)
//  ✅ UPDATED: largeAmountThreshold from Decimal to Double
//  ✅ UPDATED: Receipt auto-fill sets amountDouble directly
//  ✅ UPDATED: Celebration overlay uses amountDouble directly
//  ✅ UPDATED: All validation and save logic uses amountDouble
//
//  CHANGES v3.2 - VoiceOver Audit:
//  ✅ ADDED: Category picker icons hidden (decorative, text describes category)
//  ✅ ADDED: Account icon hidden in single account display
//  ✅ ADDED: Camera icon hidden in scan receipt button
//  ✅ ADDED: Checkmark icon hidden in receipt attached state
//  ✅ VERIFIED: All icon-only buttons have explicit accessibility labels
//  ✅ VERIFIED: Excellent accessibility coverage already in place
//
//  CHANGES v3.1 - Dynamic Type Verification:
//  ✅ FIXED: "No accounts created" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Receipt attached" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Scan Receipt" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Processing receipt..." text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AccountChipView balance text missing lineLimit + minimumScaleFactor
//
//  CHANGES v3.0:
//  ✅ ADDED: VoiceOver labels on receipt scan/view/processing states
//  ✅ ADDED: Account chip accessibility labels
//  ✅ ADDED: Save/Cancel toolbar button hints
//  ✅ ADDED: Category picker hint
//  ✅ ADDED: Date picker accessibility hint
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Receipt processing announced to VoiceOver
//  ✅ ADDED: Upgrade button accessibility label
//
//  CHANGES v2.9:
//  ✅ ADDED: Transaction limit enforcement (50/month Free tier)
//  ✅ ADDED: UsageLimitService integration for real-time limit tracking
//  ✅ ADDED: UsageWarningBanner when approaching/at limit (80%/90%/100%)
//  ✅ ADDED: LimitReachedOverlay when limit is hit
//  ✅ ADDED: Disable Save button when limit reached
//  ✅ ADDED: Monthly reset on 1st of each month
//  ✅ ADDED: Upgrade prompt via SubscriptionView
//
//  CHANGES v2.8:
//  ✅ ADDED: Camera permission check before showing camera (Apple 5.1.1 compliance)
//  ✅ ADDED: Settings redirect alert when permission denied
//  ✅ ADDED: CameraPermissionHelper integration
//  ✅ No pre-permission screens - permission requested contextually
//
//  CHANGES v2.7:
//  - Added automatic account balance updates when transactions are created
//  - Income increases account balance, expenses decrease it
//
//  CHANGES v2.6:
//  - Fixed UTF-8 encoding in account chip display (garbled bullet characters)
//
//  CHANGES v2.5.1:
//  - Fixed FinanceType comparison (Account now uses Transaction.FinanceType)
//  - Fixed explicit type annotations in sorted closure
//
//  CHANGES v2.5:
//  - Added account selection with horizontal chips (Premium+)
//  - Added smart account defaults based on financeType
//  - Added account auto-switch when financeType changes
//

import SwiftUI
import SwiftData
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct AddTransactionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // Optional: start with Income toggle on
    var startAsIncome: Bool = false

    // Transaction Properties
    @State private var amountDouble: Double = 0
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
    
    // v2.8: Camera permission state
    @State private var showingCameraPermissionAlert = false
    
    // Validation & Alerts
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""
    @State private var showingLargeAmountConfirmation = false
    
    // Loading state
    @State private var isSaving = false
    
    // Celebration
    @State private var showIncomeCelebration = false
    
    // v2.9: Usage Limit State
    @State private var usageLimitService: UsageLimitService?
    @State private var showingSubscription = false
    @State private var showingLimitReached = false
    @State private var usageWarning: UsageWarning?
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case amount, merchant, note
    }
    
    private let largeAmountThreshold: Double = 10_000
    
    // v2.9: Check if within transaction limit
    private var isWithinLimit: Bool {
        guard let service = usageLimitService else { return true }
        let (allowed, _) = service.canAddTransaction(tier: subscriptionManager.currentTier)
        return allowed
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // v2.9: Usage warning banner (shows at 80%+ usage)
                if let warning = usageWarning {
                    Section {
                        UsageWarningBanner(
                            warning: warning,
                            showingSubscription: $showingSubscription,
                            isCompact: true
                        )
                    }
                }
                
                receiptScanSection
                amountSection
                typeSection
                financeTypeSection
                categorySection
                accountSection
                dateSection
                detailsSection
                
                // v2.9: Monthly usage indicator for Free tier
                if subscriptionManager.currentTier.transactionLimit != nil {
                    Section {
                        MonthlyUsageIndicator(
                            current: usageLimitService?.currentMonthTransactionCount ?? 0,
                            limit: subscriptionManager.currentTier.transactionLimit,
                            limitType: .transactions,
                            showingSubscription: $showingSubscription
                        )
                    }
                }
            }
            .navigationTitle("New Transaction")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            #if canImport(UIKit)
            .sheet(isPresented: $showingCamera) {
                DocumentCameraView(image: $capturedImage)
            }
            #endif
            .sheet(isPresented: $showingReceiptPreview) {
                receiptPreviewSheet
            }
            // v2.9: Subscription upgrade sheet
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            // v2.9: Limit reached overlay
            #if os(macOS)
            .sheet(isPresented: $showingLimitReached) {
                LimitReachedOverlay(
                    limitType: .transactions,
                    currentCount: usageLimitService?.currentMonthTransactionCount ?? 50,
                    limit: subscriptionManager.currentTier.transactionLimit ?? 50,
                    showingSubscription: $showingSubscription,
                    onDismiss: {
                        showingLimitReached = false
                        dismiss()
                    }
                )
            }
            #else
            .fullScreenCover(isPresented: $showingLimitReached) {
                LimitReachedOverlay(
                    limitType: .transactions,
                    currentCount: usageLimitService?.currentMonthTransactionCount ?? 50,
                    limit: subscriptionManager.currentTier.transactionLimit ?? 50,
                    showingSubscription: $showingSubscription,
                    onDismiss: {
                        showingLimitReached = false
                        dismiss()
                    }
                )
            }
            #endif
            // v2.8: Camera permission denied alert
            .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
                Button("Open Settings") {
                    CameraPermissionHelper.openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FLO needs camera access to scan receipts. Please enable it in Settings.")
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
            .onChange(of: showingValidationAlert) { _, isShowing in
                if isShowing {
                    AccessibilityAnnouncement.announce("Validation error: \(validationMessage)")
                    HapticService.play(.error)
                }
            }
            .alert("Large Amount", isPresented: $showingLargeAmountConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm", role: .destructive) {
                    saveTransaction()
                }
            } message: {
                Text("You're about to save a transaction for \(amountDouble, format: .currency(code: "USD")). Is this correct?")
            }
            .onAppear {
                if startAsIncome { isIncome = true }
                setDefaultAccount()
                setupLimitService()
                // v3.0: Screen announcement
                AccessibilityAnnouncement.screenChanged("New Transaction form")
            }
            .onDisappear {
                cleanupOnCancel()
            }
            .celebrationOverlay(
                isPresented: $showIncomeCelebration,
                style: .incomeReceived,
                amount: amountDouble > 0 ? amountDouble : nil,
                onDismiss: {
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - v2.9: Limit Service Setup
    
    private func setupLimitService() {
        usageLimitService = UsageLimitService(modelContext: context)
        updateUsageWarning()
    }
    
    private func updateUsageWarning() {
        usageWarning = usageLimitService?.getUsageWarning(
            for: .transactions,
            tier: subscriptionManager.currentTier
        )
    }

    // MARK: - Form Sections

    private var amountSection: some View {
        Section("Amount") {
            CurrencyInputField(
                amount: $amountDouble,
                accessibilityLabelText: "Transaction amount",
                showDoneButton: false  // Parent toolbar handles Done button
            )
            .disabled(isProcessingReceipt)
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
                 "This expense may be tax deductible" :
                 "Personal expenses are not tax deductible")
        }
    }
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None")
                    .tag(nil as Category?)
                
                let filtered = isIncome ?
                    categories.filter { $0.isIncome } :
                    categories.filter { !$0.isIncome }
                
                ForEach(filtered, id: \.id) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .accessibilityHidden(true)
                        Text(category.name)
                    }
                    .tag(category as Category?)
                }
            }
            .disabled(isProcessingReceipt)
            // v3.0: VoiceOver hint
            .accessibilityHint("Select a category for this transaction")
        }
    }
    
    private var accountSection: some View {
        Section {
            if subscriptionManager.currentTier.hasMultipleAccounts {
                // Premium+ users see all accounts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredAccounts, id: \.id) { account in
                            AccountChipView(
                                account: account,
                                isSelected: selectedAccount?.id == account.id,
                                showBalance: true
                            ) {
                                HapticService.play(.light)
                                selectedAccount = account
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // Free users see single account picker
                if let account = accounts.first {
                    HStack {
                        Image(systemName: account.icon)
                            .foregroundStyle(Color.brandPrimaryText)
                            .accessibilityHidden(true)
                        Text(account.name)
                        Spacer()
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No accounts created")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Account")
        } footer: {
            if !subscriptionManager.currentTier.hasMultipleAccounts && accounts.count > 1 {
                Button("Upgrade for multiple accounts") {
                    HapticService.play(.light)
                    showingSubscription = true
                }
                .font(.caption)
                // v3.0: VoiceOver label
                .accessibilityLabel("Upgrade to Premium for multiple account support")
                .accessibilityHint("Double tap to view subscription options")
            }
        }
    }
    
    private var filteredAccounts: [Account] {
        let active = accounts.filter { $0.isActive }
        
        // Sort: matching financeType first, then by name
        return active.sorted { (a: Account, b: Account) -> Bool in
            let aMatches = a.financeType == financeType
            let bMatches = b.financeType == financeType
            
            if aMatches != bMatches {
                return aMatches
            }
            return a.name < b.name
        }
    }
    
    private var dateSection: some View {
        Section("Date") {
            DatePicker("Transaction Date", selection: $date, displayedComponents: .date)
                .disabled(isProcessingReceipt)
                // v3.0: VoiceOver hint
                .accessibilityHint("Select the date this transaction occurred")
        }
    }
    
    private var detailsSection: some View {
        Section("Details") {
            TextField("Merchant Name", text: $merchantName)
                .focused($focusedField, equals: .merchant)
                .disabled(isProcessingReceipt)
                .accessibilityLabel("Merchant name")
            
            TextField("Notes (optional)", text: $note, axis: .vertical)
                .lineLimit(3...6)
                .focused($focusedField, equals: .note)
                .disabled(isProcessingReceipt)
                .accessibilityLabel("Transaction notes")
        }
    }
    
    private var receiptScanSection: some View {
        Section {
            if receiptImagePath != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Receipt attached")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Button("View") {
                        showingReceiptPreview = true
                    }
                    .buttonStyle(.borderless)
                    // v3.0: VoiceOver label
                    .accessibilityLabel("View receipt")
                    .accessibilityHint("Double tap to see the attached receipt image")
                }
                // v3.0: Group for VoiceOver
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Receipt attached")
                .accessibilityHint("View button available")
            } else {
                Button {
                    checkCameraPermissionAndScan()
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                            .accessibilityHidden(true)
                        Text("Scan Receipt")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .disabled(isProcessingReceipt)
                // v3.0: VoiceOver label
                .accessibilityLabel("Scan receipt")
                .accessibilityHint("Double tap to open camera and scan a receipt")
            }
            
            if isProcessingReceipt {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Processing receipt...")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                // v3.0: Announce processing
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Processing receipt, please wait")
                .accessibilityAddTraits(.updatesFrequently)
            }
        } header: {
            Text("Receipt")
        } footer: {
            Text("Scan a receipt to auto-fill amount and merchant")
        }
    }
    
    @ViewBuilder
    private var receiptPreviewSheet: some View {
        if let path = receiptImagePath {
            NavigationStack {
                ReceiptImageView(imagePath: path)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showingReceiptPreview = false
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Remove", role: .destructive) {
                                receiptImagePath = nil
                                showingReceiptPreview = false
                            }
                        }
                    }
            }
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
            // v3.0: VoiceOver hint
            .accessibilityHint("Double tap to discard and close")
        }
        
        ToolbarItem(placement: .confirmationAction) {
            if isSaving {
                ProgressView()
                    .accessibilityLabel("Saving transaction")
            } else {
                Button("Save") {
                    validateAndSave()
                }
                // v2.9: Disable if limit reached
                .disabled(!canSave || isProcessingReceipt || !isWithinLimit)
                // v3.0: VoiceOver hint
                .accessibilityLabel(isWithinLimit ? "Save transaction" : "Transaction limit reached")
                .accessibilityHint(canSave && isWithinLimit ? "Double tap to save this transaction" : "")
            }
        }
        
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                focusedField = nil
                // Also dismiss CurrencyInputField's internal keyboard
                #if canImport(UIKit)
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                #endif
            }
        }
    }
    
    // MARK: - Validation

    private var canSave: Bool {
        amountDouble > 0
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
        // v2.9: Check transaction limit first
        if !isWithinLimit {
            HapticService.play(.error)
            showingLimitReached = true
            return
        }
        
        if amountDouble <= 0 {
            validationMessage = "Amount must be greater than zero"
            showingValidationAlert = true
            return
        }

        if amountDouble > largeAmountThreshold {
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
        
        let amount = amountDouble
        
        let transaction = Transaction(
            amount: amount,
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
        
        // Update account balance
        if let account = selectedAccount {
            if isIncome {
                account.currentBalance += amount
            } else {
                account.currentBalance -= amount
            }
            account.lastBalanceUpdate = Date()
            account.touch()
        }
        
        do {
            try context.save()
            print("Transaction saved: \(transaction.displayName) - \(financeType.displayName) - Account: \(selectedAccount?.name ?? "None")")
            
            AccessibilityAnnouncement.announce("Transaction saved successfully")
            
            // Show celebration for income transactions, otherwise dismiss normally
            if isIncome {
                showIncomeCelebration = true
            } else {
                HapticService.play(.success)
                dismiss()
            }
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
    
    private func setDefaultAccount() {
        if selectedAccount == nil {
            // Try to find an account matching the finance type
            let matching = accounts.filter { $0.isActive && $0.financeType == financeType }
            selectedAccount = matching.first ?? accounts.filter { $0.isActive }.first
        }
    }
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
        // When finance type changes, try to switch to a matching account
        let matching = accounts.filter { $0.isActive && $0.financeType == newType }
        if let matchingAccount = matching.first {
            selectedAccount = matchingAccount
        }
    }
    
    // MARK: - v2.8: Camera Permission Check
    
    private func checkCameraPermissionAndScan() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    }
                }
            }
        case .denied, .restricted:
            showingCameraPermissionAlert = true
        @unknown default:
            showingCameraPermissionAlert = true
        }
    }
    
    // MARK: - Receipt Processing
    
    private func processReceipt(image: UIImage) {
        isProcessingReceipt = true
        focusedField = nil
        
        // Save image
        if let imagePath = PhotoStorageManager.shared.saveReceiptSync(image: image) {
            receiptImagePath = imagePath
        }
        
        Task {
            do {
                // Scan the receipt image to extract text
                let scannedText = try await ReceiptScannerService.shared.scanReceiptSafe(from: image)
                // Parse the extracted text
                let parsedData = ReceiptParser.shared.parseReceipt(text: scannedText)
                
                await MainActor.run {
                    if let parsedAmount = parsedData.amount {
                        let roundedAmount = (parsedAmount * 100).rounded() / 100
                        amountDouble = roundedAmount
                        let formatted = roundedAmount.formatted(.currency(code: "USD"))
                        announceAccessibilityChange("Amount filled from receipt: \(formatted)")
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
                    HapticService.play(.success)
                }
            } catch {
                await MainActor.run {
                    print("Receipt scanning failed: \(error)")
                    isProcessingReceipt = false
                }
            }
        }
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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: account.icon)
                        .font(.caption)
                    Text(account.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                
                if showBalance {
                    Text(account.currentBalance.formatted(.currency(code: "USD")))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.15) : Color.floSecondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.brandPrimary : .primary)
        // v3.0: VoiceOver label for account chip
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.name)\(showBalance ? ", balance \(AccessibilityFormatters.spokenCurrency(account.currentBalance))" : "")")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") this account")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Transaction.self, Category.self, Account.self,
        configurations: config
    )
    
    return AddTransactionView()
        .modelContainer(container)
        .environmentObject(SubscriptionManager.shared)
}
