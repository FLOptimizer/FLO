//  SmartReceiptScanningView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.1.1 - Fixed FinanceType comparison issues
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.1.1:
//  ✅ FIXED: FinanceType comparison (Account now uses Transaction.FinanceType)
//  ✅ FIXED: Explicit type annotations in sorted closure
//
//  CHANGES v3.1:
//  ✅ ADDED: Account selection with horizontal chips (Premium+)
//  ✅ ADDED: Smart account defaults based on financeType
//  ✅ ADDED: Account passed to created transaction
//
//  CHANGES v3.0:
//  - Editable fields for merchant, amount, date, category
//  - Learning from user corrections when category changed
//

import SwiftUI
import SwiftData
import PhotosUI
import VisionKit

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
                        onCameraSelected: { showingCamera = true },
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
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            .onChange(of: selectedImage) { _, newImage in
                guard !isProcessing, let image = newImage else { return }
                Task {
                    await processImage(image)
                }
            }
            .onAppear {
                setDefaultAccount()
            }
            .onChange(of: editedFinanceType) { _, newType in
                updateAccountForFinanceType(newType)
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
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedAccount = matching
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else if let matching = active.first(where: { $0.financeType == newType }) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedAccount = matching
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            
            #if DEBUG
            print("✅ Receipt processed: \(receipt.merchantName) - \(receipt.totalAmount.asCurrency)")
            #endif
            
        } catch {
            errorMessage = "Failed to process receipt: \(error.localizedDescription)"
            isProcessing = false
            
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            
            #if DEBUG
            print("❌ Receipt processing error: \(error)")
            #endif
        }
    }
    
    // MARK: - Actions
    
    private func linkReceiptToTransaction(_ transaction: Transaction, score: Double) {
        guard let receipt = processedReceipt else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
                
                #if DEBUG
                print("🔗 Linked receipt to transaction: \(transaction.merchantName)")
                #endif
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    private func markAsCashPurchase() {
        guard let receipt = processedReceipt else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
                
                #if DEBUG
                print("💵 Marked as cash purchase: \(receipt.merchantName)")
                #endif
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
    
    private func saveAndCreateTransaction() {
        guard let receipt = processedReceipt else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
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
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    #if DEBUG
                    print("💾 Created transaction from receipt: \(finalMerchant) - Account: \(selectedAccount?.name ?? "None")")
                    #endif
                }
                
                dismiss()
                
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                
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
                        Picker("Category", selection: $editedCategoryName) {
                            Text("None").tag("")
                            ForEach(expenseCategories, id: \.name) { category in
                                Label(category.name, systemImage: category.icon)
                                    .tag(category.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.brandPrimary)
                    }
                    
                    // Account Section (Premium+)
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
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedAccount = nil
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.brandPrimary)
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
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                if selectedAccount?.id == account.id {
                                                    selectedAccount = nil
                                                } else {
                                                    selectedAccount = account
                                                }
                                            }
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    }
                                }
                            }
                            
                            if let account = selectedAccount, account.financeType != editedFinanceType {
                                Label("Account type differs from transaction", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Finance Type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Finance Type", selection: $editedFinanceType) {
                            Label("Business", systemImage: "briefcase.fill")
                                .tag(Transaction.FinanceType.business)
                            Label("Personal", systemImage: "person.fill")
                                .tag(Transaction.FinanceType.personal)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: editedFinanceType) { _, _ in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Potential Matches
                if !matches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Found \(matches.count) potential match(es)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        ForEach(matches.prefix(3), id: \.transaction.id) { match in
                            MatchRow(match: match, onTap: {
                                onMatch(match.transaction, match.score)
                            })
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.05))
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
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandPrimary)
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
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
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
            
            Text("Scan a Receipt")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Take a photo or select from your library")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onCameraSelected()
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
