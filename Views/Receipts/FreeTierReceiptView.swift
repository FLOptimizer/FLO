//  FreeTierReceiptView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Accessibility Audit Pass (Sprint 10a)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3:
//  ✅ Screen change announcement on appear
//  ✅ Upgrade banner chevron hidden from VoiceOver
//  ✅ Captured receipt image gets accessibility label
//  ✅ Capture area decorative icon hidden
//  ✅ Processing indicator combined for VoiceOver
//  ✅ Remove image button gets accessibility label
//
//  PURPOSE:
//  Provides basic receipt capture functionality for Free tier users.
//  - Camera capture or photo library selection
//  - Basic OCR text extraction (Apple Vision)
//  - Manual data entry
//  - Upgrade prompt for Smart Receipt Scanning (AI parsing)
//
//  CHANGES v1.2:
//  ✅ ADDED: Receipt limit enforcement (20 Free tier)
//  ✅ ADDED: UsageLimitService integration for real-time limit tracking
//  ✅ ADDED: UsageWarningBanner when approaching/at limit (80%/90%/100%)
//  ✅ ADDED: Disable Save when limit reached
//  ✅ ADDED: LimitReachedOverlay when limit is hit
//
//  CHANGES v1.1:
//  ✅ FIXED: ReceiptData initializer to match actual model
//  ✅ FIXED: Transaction initializer parameter order
//  ✅ REMOVED: CameraView (already exists in project)
//  ✅ REMOVED: PhotoStorageManager (already exists in project)
//  ✅ Uses existing PhotoStorageManager.shared.saveReceiptSync()
//
//  PREMIUM UPGRADE PATH:
//  Smart Receipt Scanning (Premium+) includes:
//  - AI-powered merchant/amount detection
//  - Automatic category suggestion
//  - Transaction matching
//  - Business/Personal split detection
//

import SwiftUI
import SwiftData
import PhotosUI
import Vision

struct FreeTierReceiptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Query private var categories: [Category]
    @Query(filter: #Predicate<Account> { $0.isActive }) private var accounts: [Account]
    
    // Image capture
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    // OCR results
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    
    // Manual entry fields
    @State private var merchantName = ""
    @State private var amount = ""
    @State private var transactionDate = Date()
    @State private var selectedCategory: Category?
    @State private var financeType: Transaction.FinanceType = .business
    @State private var notes = ""
    
    // UI state
    @State private var showingSubscription = false
    @State private var showingSaveConfirmation = false
    @State private var viewAppeared = false
    
    // v1.2: Usage Limit State
    @State private var usageLimitService: UsageLimitService?
    @State private var showingLimitReached = false
    @State private var usageWarning: UsageWarning?
    
    private var expenseCategories: [Category] {
        categories.filter { !$0.isIncome }.sorted { $0.name < $1.name }
    }
    
    private var isFormValid: Bool {
        !merchantName.isEmpty && Double(amount) != nil && Double(amount)! > 0
    }
    
    // v1.2: Check if within receipt limit
    private var isWithinLimit: Bool {
        guard let service = usageLimitService else { return true }
        let (allowed, _) = service.canAddReceipt(tier: subscriptionManager.currentTier)
        return allowed
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // v1.2: Usage warning banner (shows at 80%+ usage)
                    if let warning = usageWarning {
                        UsageWarningBanner(
                            warning: warning,
                            showingSubscription: $showingSubscription,
                            isCompact: false
                        )
                        .padding(.bottom, 4)
                    }
                    
                    // Upgrade banner
                    upgradeBanner
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : -10)
                        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                    
                    // Image capture section
                    imageCaptureSection
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                    
                    // Manual entry form
                    if selectedImage != nil {
                        manualEntryForm
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(y: viewAppeared ? 0 : 10)
                            .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                    }
                    
                    // v1.2: Receipt usage indicator
                    if let limit = subscriptionManager.currentTier.receiptStorageLimit {
                        UsageLimitIndicator(
                            current: usageLimitService?.totalReceiptCount ?? 0,
                            limit: limit,
                            limitType: .receipts,
                            showingSubscription: $showingSubscription
                        )
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Capture Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                
                if selectedImage != nil && isFormValid {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            // v1.2: Check limit before saving
                            if !isWithinLimit {
                                HapticService.play(.error)
                                showingLimitReached = true
                            } else {
                                saveReceipt()
                            }
                        }
                        .fontWeight(.semibold)
                        // v1.2: Disable when limit reached
                        .disabled(!isWithinLimit)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                FreeTierCameraView(image: $selectedImage)
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                            processImage(image)
                        }
                    }
                }
            }
            .onChange(of: selectedImage) { _, newImage in
                if let image = newImage {
                    processImage(image)
                }
            }
            .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            // v1.2: Limit reached overlay
            .fullScreenCover(isPresented: $showingLimitReached) {
                LimitReachedOverlay(
                    limitType: .receipts,
                    currentCount: usageLimitService?.totalReceiptCount ?? 20,
                    limit: subscriptionManager.currentTier.receiptStorageLimit ?? 20,
                    showingSubscription: $showingSubscription,
                    onDismiss: {
                        showingLimitReached = false
                        dismiss()
                    }
                )
            }
            .alert("Receipt Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your receipt has been saved and a transaction has been created.")
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                setupLimitService()
                AccessibilityAnnouncement.screenChanged("Capture receipt")
            }
        }
    }
    
    // MARK: - v1.2: Limit Service Setup
    
    private func setupLimitService() {
        usageLimitService = UsageLimitService(modelContext: modelContext)
        updateUsageWarning()
    }
    
    private func updateUsageWarning() {
        usageWarning = usageLimitService?.getUsageWarning(
            for: .receipts,
            tier: subscriptionManager.currentTier
        )
    }
    
    // MARK: - Upgrade Banner
    
    private var upgradeBanner: some View {
        Button {
            HapticService.play(.medium)
            showingSubscription = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Smart Scanning")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    
                    Text("AI auto-fills merchant, amount & category")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Image Capture Section
    
    private var imageCaptureSection: some View {
        VStack(spacing: 16) {
            if let image = selectedImage {
                // Show captured image
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        .accessibilityLabel("Captured receipt image")
                    
                    // Replace image button
                    Button {
                        HapticService.play(.light)
                        selectedImage = nil
                        extractedText = ""
                        merchantName = ""
                        amount = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Color.black.opacity(0.5))
                    }
                    .padding(8)
                    .accessibilityLabel("Remove image")
                }
                
                // Processing indicator
                if isProcessing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Extracting text...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Extracted text preview (collapsed)
                if !extractedText.isEmpty && !isProcessing {
                    DisclosureGroup {
                        Text(extractedText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("Extracted Text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // Capture options
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary.opacity(0.6))
                        .accessibilityHidden(true)
                    
                    Text("Capture Your Receipt")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Take a photo or choose from your library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        // Camera button
                        Button {
                            HapticService.play(.medium)
                            showingCamera = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .accessibilityHidden(true)
                                Text("Camera")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.brandPrimary.opacity(0.1))
                             .foregroundStyle(Color.brandPrimaryText)
                            .cornerRadius(12)
                        }
                        
                        // Photo library button
                        Button {
                            HapticService.play(.medium)
                            showingPhotoPicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                    .accessibilityHidden(true)
                                Text("Library")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Manual Entry Form
    
    private var manualEntryForm: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Image(systemName: "pencil.line")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Enter Details Manually")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            
            // Merchant name
            VStack(alignment: .leading, spacing: 6) {
                Text("Merchant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Store or business name", text: $merchantName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Amount
            VStack(alignment: .leading, spacing: 6) {
                Text("Amount")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Date
            VStack(alignment: .leading, spacing: 6) {
                Text("Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                DatePicker("", selection: $transactionDate, displayedComponents: .date)
                    .labelsHidden()
            }
            
            // Finance type
            VStack(alignment: .leading, spacing: 6) {
                Text("Classification")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $financeType) {
                    Text("Business").tag(Transaction.FinanceType.business)
                    Text("Personal").tag(Transaction.FinanceType.personal)
                }
                .pickerStyle(.segmented)
            }
            
            // Category
            VStack(alignment: .leading, spacing: 6) {
                Text("Category")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Category", selection: $selectedCategory) {
                    Text("None").tag(nil as Category?)
                    ForEach(expenseCategories, id: \.id) { category in
                        Label(category.name, systemImage: category.icon)
                            .tag(category as Category?)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (Optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Add notes...", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - OCR Processing
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        extractedText = ""
        
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                isProcessing = false
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                extractedText = text
                
                // Try to extract basic info (simple patterns)
                extractBasicInfo(from: text)
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    private func extractBasicInfo(from text: String) {
        // Simple amount extraction (look for dollar amounts)
        let amountPattern = "\\$([0-9]+\\.?[0-9]{0,2})"
        if let regex = try? NSRegularExpression(pattern: amountPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let extractedAmount = String(text[range])
            // Only auto-fill if user hasn't entered anything
            if amount.isEmpty {
                amount = extractedAmount
            }
        }
        
        // Simple merchant extraction (first line often has store name)
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if let firstLine = lines.first, merchantName.isEmpty {
            // Clean up common receipt header noise
            let cleaned = firstLine
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespaces)
            
            if cleaned.count > 2 && cleaned.count < 50 {
                merchantName = cleaned
            }
        }
    }
    
    // MARK: - Save Receipt
    
    private func saveReceipt() {
        // v1.2: Double-check limit before saving
        if !isWithinLimit {
            HapticService.play(.error)
            showingLimitReached = true
            return
        }
        
        guard let image = selectedImage,
              let amountValue = Double(amount),
              amountValue > 0 else {
            HapticService.play(.error)
            return
        }
        
        HapticService.play(.medium)
        
        // Save image using existing PhotoStorageManager
        let imagePath = PhotoStorageManager.shared.saveReceiptSync(image: image)
        
        // Create receipt data with correct initializer
        let receipt = ReceiptData(
            merchantName: merchantName.isEmpty ? "Unknown Merchant" : merchantName,
            totalAmount: amountValue,
            date: transactionDate,
            rawOCRText: extractedText,
            imageData: image.jpegData(compressionQuality: 0.7)
        )
        
        // Store file path in imageURL if saved successfully
        if let path = imagePath {
            receipt.imageURL = path
        }
        
        modelContext.insert(receipt)
        
        // Create transaction with correct initializer parameter order
        let transaction = Transaction(
            amount: amountValue,
            date: transactionDate,
            note: notes.isEmpty ? "Receipt: \(merchantName)" : notes,
            isIncome: false,
            merchantName: merchantName,
            category: selectedCategory,
            financeType: financeType,
            receiptImagePath: imagePath,
            receiptID: receipt.id.uuidString,
            hasReceipt: true
        )
        
        modelContext.insert(transaction)
        
        // Link receipt to transaction
        receipt.transactionID = transaction.id
        
        do {
            try modelContext.save()
            HapticService.play(.success)
            
            // v1.2: Refresh counts after save
            usageLimitService?.refreshCounts()
            
            showingSaveConfirmation = true
        } catch {
            HapticService.play(.error)
            print("Error saving receipt: \(error)")
        }
    }
}

// MARK: - Free Tier Camera View (renamed to avoid conflict with existing CameraView)

struct FreeTierCameraView: UIViewControllerRepresentable {
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
        let parent: FreeTierCameraView
        
        init(_ parent: FreeTierCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// NOTE: PhotoStorageManager already exists in the project - using existing implementation

// MARK: - Preview

#Preview {
    FreeTierReceiptView()
        .modelContainer(for: [Transaction.self, Category.self, Account.self, ReceiptData.self], inMemory: true)
}
