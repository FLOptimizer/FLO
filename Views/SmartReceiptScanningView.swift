//  SmartReceiptScanningView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.5 - Accessibility audit (Sprint 7)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.5:
//  ✅ Screen change announcements across all sub-views
//  ✅ CaptureOptionsView header icon hidden from VoiceOver
//  ✅ Receipt image gets accessibility label
//  ✅ ProcessingView announced to VoiceOver
//  ✅ MatchRow chevron hidden, row combined
//  ✅ DuplicateMatchRow combined with spoken status
//  ✅ ErrorBanner combined with dismiss hint
//  ✅ ReceiptAccountChip spoken selection state and traits
//  ✅ Fixed garbled UTF-8 characters in print statements
//
//  CHANGES v3.4:
//  ✅ ADDED: Camera permission check before showing camera (Apple 5.1.1 compliance)
//  ✅ ADDED: Settings redirect alert when permission denied
//  ✅ ADDED: CameraPermissionHelper integration
//  ✅ No pre-permission screens - permission requested contextually
//
//  CHANGES v3.3:
//  ✅ Added DuplicateMatchRow component for showing potential duplicate receipts
//  ✅ Matches section now shows duplicates separately with orange warning styling
//  ✅ Distinguishes between "link to existing" and "possible duplicate" matches
//
//  CHANGES v3.2.2:
//  ✅ Added validatedCategoryName binding to prevent picker warnings
//  ✅ If suggested category doesn't exist in expense categories, defaults to "None"
//
//  CHANGES v3.2.1:
//  ✅ Fixed ForEach using id: \.name -> id: \.id to prevent duplicate ID warnings
//
//  CHANGES v3.2:
//  ✅ Moved Classification (Business/Personal) BEFORE Account selection
//  ✅ Renamed "Type" to "Classification" for consistency with other views
//  ✅ Logical flow: Classification determines which accounts are relevant
//
//  PREVIOUS (v3.1.1):
//  - Fixed FinanceType comparison (Account now uses Transaction.FinanceType)
//  - Explicit type annotations in sorted closure
//
//  PREVIOUS (v3.1):
//  - Account selection with horizontal chips (Premium+)
//  - Smart account defaults based on financeType
//  - Account passed to created transaction
//

import SwiftUI
import SwiftData
import PhotosUI
import VisionKit
import AVFoundation

@MainActor
struct SmartReceiptScanningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query private var categories: [Category]
    @Query private var transactions: [Transaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var processedReceipt: ReceiptData?
    @State private var errorMessage: String?
    
    // v3.4: Camera permission state
    @State private var showingCameraPermissionAlert = false
    
    // Editable fields
    @State private var editedMerchant: String = ""
    @State private var editedAmount: String = ""
    @State private var editedDate: Date = Date()
    @State private var editedCategoryName: String = ""
    @State private var editedFinanceType: Transaction.FinanceType = .business
    @State private var selectedAccount: Account?
    
    // Transaction Matching
    @State private var potentialMatches: [TransactionMatch] = []
    @State private var showingMatchConfirmation = false
    
    // Business/Personal Split
    @State private var showingSplitView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let receipt = processedReceipt {
                    EditableReceiptReviewViewWithAccount(
                        receipt: receipt,
                        editedMerchant: $editedMerchant,
                        editedAmount: $editedAmount,
                        editedDate: $editedDate,
                        editedCategoryName: $editedCategoryName,
                        editedFinanceType: $editedFinanceType,
                        selectedAccount: $selectedAccount,
                        categories: categories,
                        accounts: accounts,
                        subscriptionTier: subscriptionManager.currentTier,
                        matches: potentialMatches,
                        onMatch: linkReceiptToTransaction,
                        onSplit: { showingSplitView = true },
                        onSave: saveAndCreateTransaction,
                        onReset: resetState
                    )
                } else if isProcessing {
                    ProcessingView()
                } else {
                    CaptureOptionsView(
                        onCameraSelected: handleCameraButtonTapped,
                        onPhotoSelected: { showingImagePicker = true }
                    )
                }
                
                if let error = errorMessage {
                    VStack {
                        Spacer()
                        ErrorBanner(message: error, onDismiss: {
                            errorMessage = nil
                        })
                        .padding()
                        .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle("Smart Receipt Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        resetState()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $selectedImage)
            }
            .sheet(isPresented: $showingMatchConfirmation) {
                if let receipt = processedReceipt, !potentialMatches.isEmpty {
                    TransactionMatchingView(
                        receipt: receipt,
                        matches: potentialMatches,
                        onMatch: linkReceiptToTransaction,
                        onCashPurchase: markAsCashPurchase
                    )
                }
            }
            .sheet(isPresented: $showingSplitView) {
                if let receipt = processedReceipt {
                    SplitReceiptView(receipt: receipt)
                }
            }
            // v3.4: Camera permission denied alert
            .alert("Camera Access Required", isPresented: $showingCameraPermissionAlert) {
                Button("Open Settings") {
                    CameraPermissionHelper.openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FLO needs camera access to scan receipts. Please enable it in Settings.")
            }
            .onChange(of: selectedImage) { _, newImage in
                guard !isProcessing, let image = newImage else { return }
                Task {
                    await processImage(image)
                }
            }
            .onAppear {
                setDefaultAccount()
                AccessibilityAnnouncement.screenChanged("Smart receipt scanner")
            }
            .onChange(of: editedFinanceType) { _, newType in
                updateAccountForFinanceType(newType)
            }
        }
    }
    
    // MARK: - Camera Permission Handler (v3.4)
    
    private func handleCameraButtonTapped() {
        HapticService.play(.medium)
        
        Task {
            let result = await CameraPermissionHelper.handleCameraAccess()
            
            await MainActor.run {
                switch result {
                case .proceed:
                    showingCamera = true
                case .denied:
                    // User just denied permission in system dialog
                    // Don't show another alert - they made their choice
                    break
                case .needsSettings:
                    // Permission was previously denied - show settings alert
                    showingCameraPermissionAlert = true
                }
            }
        }
    }
    
    // MARK: - Account Helpers
    
    private func setDefaultAccount() {
        guard subscriptionManager.currentTier.hasMultipleAccounts else { return }
        guard selectedAccount == nil else { return }
        
        let active = accounts.filter { $0.isActive }
        
        if let primary = active.first(where: { $0.isPrimary && $0.financeType == editedFinanceType }) {
            selectedAccount = primary
            return
        }
        
        if let matching = active.first(where: { $0.financeType == editedFinanceType }) {
            selectedAccount = matching
            return
        }
        
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
                HapticService.play(.light)
            } else if let matching = active.first(where: { $0.financeType == newType }) {
                withAnimation(FLOAnimation.quick) {
                    selectedAccount = matching
                }
                HapticService.play(.light)
            }
        }
    }
    
    // MARK: - Processing Methods
    
    private func processImage(_ image: UIImage) async {
        guard !isProcessing else { return }
        
        isProcessing = true
        errorMessage = nil
        
        do {
            let receipt = try await SmartReceiptService.shared.processReceipt(
                image: image,
                context: modelContext
            )
            
            editedMerchant = receipt.merchantName
            editedAmount = String(format: "%.2f", receipt.totalAmount)
            editedDate = receipt.date
            editedCategoryName = receipt.suggestedCategoryName ?? ""
            editedFinanceType = .business
            
            setDefaultAccount()
            
            potentialMatches = TransactionMatchingService.shared.findPotentialMatches(
                for: receipt,
                in: transactions
            )
            
            processedReceipt = receipt
            isProcessing = false
            
            HapticService.play(.success)
            
            #if DEBUG
            print("✅ Receipt processed: \(receipt.merchantName) - \(receipt.totalAmount.asCurrency)")
            #endif
            
        } catch {
            errorMessage = "Failed to process receipt: \(error.localizedDescription)"
            isProcessing = false
            
            HapticService.play(.error)
            
            #if DEBUG
            print("❌ Receipt processing error: \(error)")
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func linkReceiptToTransaction(_ transaction: Transaction, score: Double) {
        guard let receipt = processedReceipt else { return }
        
        HapticService.play(.medium)
        
        Task {
            let imagePath = await saveReceiptImage(receipt)
            
            TransactionMatchingService.shared.linkReceiptToTransaction(
                transaction,
                receipt: receipt,
                imagePath: imagePath
            )
            
            do {
                try modelContext.save()
                showingMatchConfirmation = false
                HapticService.play(.success)
                dismiss()
                
                #if DEBUG
                print("🔗 Linked receipt to transaction: \(transaction.merchantName)")
                #endif
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticService.play(.error)
            }
        }
    }
    
    private func markAsCashPurchase() {
        guard let receipt = processedReceipt else { return }
        
        HapticService.play(.medium)
        
        Task {
            let imagePath = await saveReceiptImage(receipt)
            
            TransactionMatchingService.shared.markAsCashPurchase(
                receipt: receipt,
                imagePath: imagePath,
                context: modelContext
            )
            
            do {
                try modelContext.save()
                showingMatchConfirmation = false
                HapticService.play(.success)
                dismiss()
                
                #if DEBUG
                print("🔗 Marked as cash purchase: \(receipt.merchantName)")
                #endif
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticService.play(.error)
            }
        }
    }
    
    private func saveAndCreateTransaction() {
        guard let receipt = processedReceipt else { return }
        
        HapticService.play(.medium)
        
        let finalAmount = Double(editedAmount) ?? receipt.totalAmount
        let finalMerchant = editedMerchant.isEmpty ? receipt.merchantName : editedMerchant
        let finalCategory = editedCategoryName
        
        receipt.merchantName = finalMerchant
        receipt.totalAmount = finalAmount
        receipt.date = editedDate
        receipt.suggestedCategoryName = finalCategory.isEmpty ? nil : finalCategory
        
        Task {
            do {
                try modelContext.save()
                
                if receipt.transactionID == nil {
                    var categoryObject: Category? = nil
                    if !finalCategory.isEmpty {
                        let categoryDescriptor = FetchDescriptor<Category>(
                            predicate: #Predicate<Category> { $0.name == finalCategory }
                        )
                        categoryObject = try? modelContext.fetch(categoryDescriptor).first
                    }
                    
                    let imagePath = await saveReceiptImage(receipt)
                    
                    let transaction = Transaction(
                        amount: finalAmount,
                        date: editedDate,
                        note: "Scanned receipt",
                        isIncome: false,
                        merchantName: finalMerchant,
                        category: categoryObject,
                        financeType: editedFinanceType,
                        account: selectedAccount,
                        hasReceipt: true
                    )
                    transaction.receiptImagePath = imagePath
                    
                    modelContext.insert(transaction)
                    
                    receipt.transactionID = transaction.id
                    receipt.modifiedDate = Date()
                    
                    if let cat = categoryObject, receipt.suggestedCategoryName != finalCategory {
                        try? SmartReceiptService.shared.learnFromUserChoice(
                            merchantName: finalMerchant,
                            categoryID: cat.id,
                            categoryName: cat.name,
                            context: modelContext
                        )
                    }
                    
                    try modelContext.save()
                    HapticService.play(.success)
                    
                    #if DEBUG
                    print("🔗 Created transaction from receipt: \(finalMerchant) - Account: \(selectedAccount?.name ?? "None")")
                    #endif
                }
                
                dismiss()
                
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticService.play(.error)
                
                #if DEBUG
                print("❌ Save error: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveReceiptImage(_ receipt: ReceiptData) async -> String {
        guard let imageData = receipt.imageData,
              let image = UIImage(data: imageData) else {
            return ""
        }
        
        do {
            let filename = try await PhotoStorageManager.shared.saveReceipt(image: image)
            return filename
        } catch {
            print("❌ Failed to save receipt image: \(error)")
            return ""
        }
    }
    
    private func resetState() {
        selectedImage = nil
        processedReceipt = nil
        potentialMatches = []
        errorMessage = nil
        isProcessing = false
        editedMerchant = ""
        editedAmount = ""
        editedDate = Date()
        editedCategoryName = ""
        selectedAccount = nil
    }
}

// MARK: - Editable Receipt Review View with Account

struct EditableReceiptReviewViewWithAccount: View {
    let receipt: ReceiptData
    @Binding var editedMerchant: String
    @Binding var editedAmount: String
    @Binding var editedDate: Date
    @Binding var editedCategoryName: String
    @Binding var editedFinanceType: Transaction.FinanceType
    @Binding var selectedAccount: Account?
    let categories: [Category]
    let accounts: [Account]
    let subscriptionTier: SubscriptionTier
    let matches: [TransactionMatch]
    let onMatch: (Transaction, Double) -> Void
    let onSplit: () -> Void
    let onSave: () -> Void
    let onReset: () -> Void
    
    @FocusState private var focusedField: Field?
    
    enum Field {
        case merchant, amount
    }
    
    private var expenseCategories: [Category] {
        categories.filter { !$0.isIncome }
    }
    
    /// Returns the edited category name only if it exists in expense categories
    /// This prevents "invalid selection" picker warnings
    private var validatedCategoryName: Binding<String> {
        Binding(
            get: {
                // Only return the category name if it exists in our expense categories
                if expenseCategories.contains(where: { $0.name == editedCategoryName }) {
                    return editedCategoryName
                }
                return ""
            },
            set: { newValue in
                editedCategoryName = newValue
            }
        )
    }
    
    private var sortedAccounts: [Account] {
        let active = accounts.filter { $0.isActive }
        
        return active.sorted { (a: Account, b: Account) -> Bool in
            if a.financeType == editedFinanceType && b.financeType != editedFinanceType { return true }
            if b.financeType == editedFinanceType && a.financeType != editedFinanceType { return false }
            if a.isPrimary && !b.isPrimary { return true }
            if b.isPrimary && !a.isPrimary { return false }
            return a.name < b.name
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt Image
                if let imageData = receipt.imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .accessibilityLabel("Scanned receipt image")
                }
                
                // Editable Fields Card
                VStack(spacing: 16) {
                    // Merchant
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merchant")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Merchant name", text: $editedMerchant)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .merchant)
                    }
                    
                    Divider()
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("$")
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $editedAmount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .amount)
                        }
                    }
                    
                    Divider()
                    
                    // Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $editedDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    Divider()
                    
                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: validatedCategoryName) {
                            Text("None").tag("")
                            ForEach(expenseCategories, id: \.id) { category in
                                Label(category.name, systemImage: category.icon)
                                    .tag(category.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.brandPrimary)
                    }
                    
                    Divider()
                    
                    // Classification (Business/Personal) - MOVED BEFORE Account
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Classification")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Classification", selection: $editedFinanceType) {
                            Label("Business", systemImage: "briefcase.fill")
                                .tag(Transaction.FinanceType.business)
                            Label("Personal", systemImage: "person.fill")
                                .tag(Transaction.FinanceType.personal)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: editedFinanceType) { _, _ in
                            HapticService.play(.light)
                        }
                    }
                    
                    if editedFinanceType == .business {
                        HStack {
                            Label("Tax Deductible", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.footnote)
                            Spacer()
                        }
                    }
                    
                    // Account Section (Premium+) - NOW AFTER Classification
                    if subscriptionTier.hasMultipleAccounts && !accounts.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Account")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                if selectedAccount != nil {
                                    Button("Clear") {
                                        withAnimation(FLOAnimation.quick) {
                                            selectedAccount = nil
                                        }
                                        HapticService.play(.light)
                                    }
                                    .font(.caption)
                                     .foregroundStyle(Color.brandPrimaryText)
                                }
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(sortedAccounts) { account in
                                        ReceiptAccountChip(
                                            account: account,
                                            isSelected: selectedAccount?.id == account.id,
                                            showBalance: subscriptionTier.hasBalanceTracking
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
                            }
                            
                            if let account = selectedAccount, account.financeType != editedFinanceType {
                                Label("Account type differs from classification", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Potential Matches
                if !matches.isEmpty {
                    let duplicates = matches.filter { $0.isDuplicate }
                    let linkable = matches.filter { !$0.isDuplicate }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Duplicate Warning Section
                        if !duplicates.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Possible Duplicate Receipt")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            Text("You may have already scanned this receipt:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            ForEach(duplicates.prefix(2), id: \.transaction.id) { match in
                                DuplicateMatchRow(match: match)
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Linkable Matches Section
                        if !linkable.isEmpty {
                            if !duplicates.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                            
                            HStack {
                                Image(systemName: "link.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Link to Existing Transaction")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            ForEach(linkable.prefix(3), id: \.transaction.id) { match in
                                MatchRow(match: match, onTap: {
                                    onMatch(match.transaction, match.score)
                                })
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .background(duplicates.isEmpty ? Color.blue.opacity(0.05) : Color.orange.opacity(0.08))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("Save Transaction", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    
                    Button(role: .destructive, action: onReset) {
                        Text("Scan Different Receipt")
                    }
                }
                .padding()
            }
        }
        .onTapGesture {
            focusedField = nil
        }
    }
}

// MARK: - Receipt Account Chip

struct ReceiptAccountChip: View {
    let account: Account
    let isSelected: Bool
    let showBalance: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: account.color).opacity(isSelected ? 0.3 : 0.15))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: account.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: account.color))
                }
                
                Text(account.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                         .foregroundStyle(Color.brandPrimaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.1) : Color(UIColor.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(FLOAnimation.quick, value: isSelected)
        .accessibilityLabel("\(account.name)\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Supporting Views

struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Processing Receipt...")
                .font(.headline)
            
            Text("Extracting merchant, amount, and date")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing receipt, extracting merchant, amount, and date")
    }
}

struct CaptureOptionsView: View {
    let onCameraSelected: () -> Void
    let onPhotoSelected: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            
            Text("Scan a Receipt")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Take a photo or select from your library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Button {
                    // v3.4: Permission check now handled in parent view
                    onCameraSelected()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                
                Button {
                    HapticService.play(.light)
                    onPhotoSelected()
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.red.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Error: \(message)")
        .accessibilityHint("Tap to dismiss")
    }
}

struct MatchRow: View {
    let match: TransactionMatch
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.transaction.merchantName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(match.transaction.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(match.displayConfidence)
                        .font(.caption)
                        .foregroundStyle(colorForConfidence(match.matchType))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(match.transaction.amount.asCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorForConfidence(_ type: MatchType) -> Color {
        switch type {
        case .perfect, .veryStrong: return .green
        case .strong: return .blue
        case .moderate: return .orange
        case .weak: return .red
        }
    }
}

// MARK: - Duplicate Match Row

struct DuplicateMatchRow: View {
    let match: TransactionMatch
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(match.transaction.merchantName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Text(match.transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(match.score * 100))% match - already has receipt")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(match.transaction.amount.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if match.transaction.hasReceipt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Camera & Image Picker

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

struct TransactionMatchingView: View {
    @Environment(\.dismiss) private var dismiss
    let receipt: ReceiptData
    let matches: [TransactionMatch]
    let onMatch: (Transaction, Double) -> Void
    let onCashPurchase: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("We found \(matches.count) potential match(es) for this receipt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Potential Matches") {
                    ForEach(matches, id: \.transaction.id) { match in
                        Button {
                            onMatch(match.transaction, match.score)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(match.transaction.merchantName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text(match.transaction.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(match.displayConfidence)
                                        .font(.caption)
                                        .foregroundStyle(colorForConfidence(match.matchType))
                                }
                                
                                Spacer()
                                
                                Text(match.transaction.amount.asCurrency)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
                
                Section {
                    Button("No Match - New Transaction") {
                        onCashPurchase()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Match Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Match transaction")
            }
        }
    }
    
    private func colorForConfidence(_ type: MatchType) -> Color {
        switch type {
        case .perfect, .veryStrong: return .green
        case .strong: return .blue
        case .moderate: return .orange
        case .weak: return .red
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: ReceiptData.self, Transaction.self, Category.self, Account.self,
        configurations: config
    )
    
    return SmartReceiptScanningView()
        .environmentObject(SubscriptionManager.shared)
        .modelContainer(container)
}
