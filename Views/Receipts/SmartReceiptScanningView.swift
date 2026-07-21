//  SmartReceiptScanningView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.12 - Mac Catalyst capture parity: UIImage-based drag-drop + hide the
//                 (unavailable) camera Scan buttons on Catalyst. v3.11 added the
//                 .fileImporter path replacing the unreachable NSOpenPanel.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.10.1 - Batch Queue Memory Fix:
//  ✅ Images entering batchQueue are downscaled to 1800 px on the longest edge.
//     VisionKit returns pages up to ~3400 px tall; a 10-receipt queue at full
//     resolution was pushing peak memory to 326 MB. Post-fix a 10-page batch
//     sits under ~30 MB on the queue. OCR quality unaffected — receipts at
//     1800 px remain well above the ~300 DPI threshold Vision cares about.
//     Single-scan path (1 image, not in batch) is unchanged.
//
//  CHANGES v3.10 - Batch Receipt Scanning:
//  ✅ Added batch mode: scan or pick multiple receipts in a single session.
//  ✅ VisionKit document camera now returns every scanned page; each becomes
//     one receipt in the batch queue (one camera burst → N receipts).
//  ✅ PHPicker selection limit raised from 1 to unlimited; batch kicks in
//     automatically when the user selects 2+ photos.
//  ✅ macOS NSOpenPanel allows multiple selection; drag-drop accepts any
//     number of images at once.
//  ✅ After save, link, or cash-purchase, the view returns to the capture
//     screen and auto-processes the next queued receipt instead of
//     dismissing. "Saved N · Done" banner + "Receipt N of M" progress title.
//  ✅ Failed OCR inside a batch is skipped — the next image auto-processes
//     so one bad capture doesn't break the run.
//
//  CHANGES v3.8:
//  ✅ Added editable tip field, auto-populated from receipt OCR
//  ✅ saveAndCreateTransaction is now split-aware: when receipt.businessPercentage
//     is not 0/100, two linked transactions are created sharing a splitGroupId.
//  ✅ Single-transaction save also persists tipAmount
//  ✅ Receipt review screen surfaces a Split badge when split has been applied
//
//  CHANGES v3.7 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String editedAmount with CurrencyInputField component
//  ✅ CHANGED: editedAmount state and binding from String to Double
//  ✅ UPDATED: Auto-fill, save, and reset to use Double directly
//
//  CHANGES v3.6 - Dynamic Type Verification:
//  ✅ FIXED: ProcessingView title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ProcessingView description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CaptureOptionsView title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CaptureOptionsView description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CaptureOptionsView button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ErrorBanner message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount field labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount amount dollar sign missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Classification" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Tax Deductible" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Account" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Clear" button missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount type mismatch warning missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount duplicate warning title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount duplicate warning description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount linkable matches title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Save Transaction" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EditableReceiptReviewViewWithAccount "Scan Different Receipt" button missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ReceiptAccountChip account name missing minimumScaleFactor (already had lineLimit)
//  ✅ FIXED: MatchRow merchant name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: MatchRow date missing lineLimit + minimumScaleFactor
//  ✅ FIXED: MatchRow confidence label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: MatchRow amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DuplicateMatchRow merchant name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DuplicateMatchRow date missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DuplicateMatchRow match percentage text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DuplicateMatchRow amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView list row merchant name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView list row date missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView list row confidence missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView list row amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TransactionMatchingView "No Match" button missing lineLimit + minimumScaleFactor
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
import FLODesignSystem
import SwiftData
import PhotosUI
import VisionKit
import AVFoundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// What kind of record the scanner produces.
/// v3.9: Added bill mode for Phase 2 scanner consolidation.
enum ScanMode {
    case transaction
    case bill
}

@MainActor
struct SmartReceiptScanningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    /// What the scanner should produce on save — chosen by the user
    /// via the Scan Receipt / Scan Bill buttons on the capture screen.
    @State private var mode: ScanMode = .transaction

    @Query private var categories: [Category]
    @Query private var transactions: [Transaction]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businessProfiles: [BusinessProfile]

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
    @State private var editedAmount: Double = 0
    @State private var editedTipAmount: Double = 0
    @State private var editedShowTipField: Bool = false
    @State private var editedDate: Date = Date()
    @State private var editedCategoryName: String = ""
    @State private var editedFinanceType: Transaction.FinanceType = .business
    @State private var selectedAccount: Account?
    @State private var editedNote: String = ""
    @State private var selectedBusinessProfile: BusinessProfile?

    // Bill-mode editable fields (v3.9)
    @State private var editedDueDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var editedIsUponReceipt: Bool = false
    
    // Transaction Matching
    @State private var potentialMatches: [TransactionMatch] = []
    @State private var showingMatchConfirmation = false
    
    // Business/Personal Split
    @State private var showingSplitView = false

    // Batch Scanning (v3.10)
    /// Images waiting to be processed after the current one.
    @State private var batchQueue: [UIImage] = []
    /// Count of receipts successfully saved/linked in this session.
    @State private var batchSavedCount: Int = 0
    /// True while a multi-image burst (camera/multi-pick/multi-drop) is in flight.
    @State private var isBatchActive: Bool = false
    /// 1-based index of the receipt currently on the review screen. Used for the
    /// "Receipt N of M" navigation title.
    @State private var batchCurrentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                if let receipt = processedReceipt {
                    if mode == .bill {
                        EditableBillReviewView(
                            receipt: receipt,
                            editedVendor: $editedMerchant,
                            editedAmount: $editedAmount,
                            editedDueDate: $editedDueDate,
                            editedIsUponReceipt: $editedIsUponReceipt,
                            editedCategoryName: $editedCategoryName,
                            editedFinanceType: $editedFinanceType,
                            selectedAccount: $selectedAccount,
                            categories: categories,
                            accounts: accounts,
                            onSave: saveAndCreateBill,
                            onReset: resetState
                        )
                    } else {
                        EditableReceiptReviewViewWithAccount(
                            receipt: receipt,
                            editedMerchant: $editedMerchant,
                            editedAmount: $editedAmount,
                            editedTipAmount: $editedTipAmount,
                            editedShowTipField: $editedShowTipField,
                            editedDate: $editedDate,
                            editedCategoryName: $editedCategoryName,
                            editedFinanceType: $editedFinanceType,
                            selectedAccount: $selectedAccount,
                            editedNote: $editedNote,
                            selectedBusinessProfile: $selectedBusinessProfile,
                            categories: categories,
                            accounts: accounts,
                            businessProfiles: businessProfiles,
                            subscriptionTier: subscriptionManager.currentTier,
                            matches: potentialMatches,
                            onMatch: linkReceiptToTransaction,
                            onSplit: { showingSplitView = true },
                            onSave: saveAndCreateTransaction,
                            onReset: resetState
                        )
                    }
                } else if isProcessing {
                    ProcessingView()
                } else {
                    CaptureOptionsView(
                        batchSavedCount: batchSavedCount,
                        onScanSelected: { selectedMode in
                            mode = selectedMode
                            #if canImport(UIKit)
                            handleCameraButtonTapped()
                            #endif
                        },
                        onPhotoSelected: { showingImagePicker = true },
                        onImagesPicked: { images in
                            enqueueImages(images)
                        },
                        onFinishBatch: {
                            HapticService.play(.success)
                            resetBatchState()
                            dismiss()
                        }
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
            .navigationTitle(scannerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        resetState()
                        resetBatchState()
                        dismiss()
                    }
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker { images in
                    enqueueImages(images)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                DocumentCameraView { pages in
                    enqueueImages(pages)
                }
                .ignoresSafeArea()
            }
            #endif
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
            .task {
                // Defer to avoid "Publishing changes from within view updates"
                try? await Task.sleep(for: .milliseconds(50))
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
    
    private func setDefaultAccount(cardLastFour: String? = nil) {
        guard selectedAccount == nil else { return }

        let active = accounts.filter { $0.isActive }

        // Priority 0: Match by card last-4 digits from receipt OCR
        if let lastFour = cardLastFour, !lastFour.isEmpty {
            for account in active {
                if let cards = account.linkedCards,
                   cards.contains(where: { $0.lastFourDigits == lastFour && !$0.isExpired }) {
                    selectedAccount = account
                    // Also set finance type to match the matched account
                    if account.financeType != editedFinanceType {
                        editedFinanceType = account.financeType
                    }
                    #if DEBUG
                    print("💳 Auto-matched account via card ****\(lastFour): \(account.name)")
                    #endif
                    return
                }
            }
        }

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

        // Auto-assign business profile if business classification
        if editedFinanceType == .business && selectedBusinessProfile == nil && !businessProfiles.isEmpty {
            if businessProfiles.count == 1 {
                selectedBusinessProfile = businessProfiles.first
            }
        }
    }
    
    private func updateAccountForFinanceType(_ newType: Transaction.FinanceType) {
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

    // MARK: - Batch Helpers (v3.10)

    /// Upper bound on the long edge of any image held in the batch queue.
    /// Receipts below this resolution still OCR perfectly; the cap shrinks
    /// per-image memory ~5× vs VisionKit's native ~3400 px output.
    private static let batchImageMaxDimension: CGFloat = 1800

    /// Returns a smaller copy of `image` when its long edge exceeds
    /// `batchImageMaxDimension`, otherwise returns `image` untouched. Used
    /// to keep queued receipts light in memory during a multi-receipt batch.
    private func downscaledForBatchQueue(_ image: UIImage) -> UIImage {
        let cap = SmartReceiptScanningView.batchImageMaxDimension
        let longest = max(image.size.width, image.size.height)
        guard longest > cap, longest > 0 else { return image }

        let ratio = cap / longest
        let newSize = CGSize(
            width: floor(image.size.width * ratio),
            height: floor(image.size.height * ratio)
        )

        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1            // render at 1x — no Retina doubling
        format.opaque = true        // receipts are opaque; skip alpha channel
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        #else
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0
        )
        result.unlockFocus()
        return result
        #endif
    }

    /// Navigation title that reflects batch progress. Examples:
    /// "Scanner", "Scanner — 2 of 5", "Scanner — 1 saved".
    private var scannerTitle: String {
        if isBatchActive {
            let remaining = batchQueue.count
            let total = batchCurrentIndex + remaining
            if total > 1 && batchCurrentIndex > 0 {
                return "Scanner — \(batchCurrentIndex) of \(total)"
            }
        }
        if batchSavedCount > 0 {
            return batchSavedCount == 1 ? "Scanner — 1 saved" : "Scanner — \(batchSavedCount) saved"
        }
        return "Scanner"
    }

    /// Hands a set of freshly-captured images to the pipeline. A single image
    /// flows through the legacy one-at-a-time path. Two or more images switch
    /// the view into batch mode — the first goes to processing immediately and
    /// the rest wait in `batchQueue`.
    private func enqueueImages(_ images: [UIImage]) {
        guard !images.isEmpty else { return }

        if images.count == 1 && !isBatchActive {
            selectedImage = images[0]
            return
        }

        isBatchActive = true
        batchCurrentIndex = batchSavedCount + 1

        // Downscale before holding references. VisionKit can return 3400 px
        // pages; a 10-receipt queue at full resolution peaked at 326 MB in
        // real captures. Capping at 1800 px keeps the queue lean while
        // leaving OCR quality untouched.
        var prepared: [UIImage] = []
        prepared.reserveCapacity(images.count)
        for image in images {
            prepared.append(downscaledForBatchQueue(image))
        }

        let first = prepared[0]
        batchQueue.append(contentsOf: prepared.dropFirst())
        // If we're already showing a review/processing screen, queue everything.
        if processedReceipt != nil || isProcessing {
            batchQueue.insert(first, at: 0)
        } else {
            selectedImage = first
        }
    }

    /// Called after a save, link, cash-purchase, or OCR failure while in batch.
    /// Clears per-receipt state and either starts the next queued image or
    /// returns to the capture screen (keeping the saved-count banner visible).
    private func advanceBatch(incrementSaved: Bool) {
        guard isBatchActive else { return }
        if incrementSaved { batchSavedCount += 1 }

        resetReceiptState()

        if !batchQueue.isEmpty {
            let next = batchQueue.removeFirst()
            batchCurrentIndex += 1
            // Force an onChange fire even if the next image is somehow identical.
            selectedImage = nil
            DispatchQueue.main.async {
                selectedImage = next
            }
        } else {
            // Queue drained — back to capture with "N saved" banner.
            // Leave isBatchActive = true so another pick extends the same session.
            isBatchActive = false
            batchCurrentIndex = 0
        }
    }

    /// Resets everything about the current receipt but leaves batch counters intact.
    private func resetReceiptState() {
        selectedImage = nil
        processedReceipt = nil
        potentialMatches = []
        errorMessage = nil
        isProcessing = false
        editedMerchant = ""
        editedAmount = 0
        editedTipAmount = 0
        editedShowTipField = false
        editedDate = Date()
        editedCategoryName = ""
        selectedAccount = nil
        editedNote = ""
        selectedBusinessProfile = nil
    }

    /// Fully clears batch state. Call before dismissing the scanner.
    private func resetBatchState() {
        batchQueue = []
        batchSavedCount = 0
        isBatchActive = false
        batchCurrentIndex = 0
    }

    /// Shared completion handler for save / link / cash-purchase paths.
    /// - Queue has more items: advance to the next receipt.
    /// - Batch session is live (active OR has saved items already): bump the
    ///   saved count and return to the capture screen so the user can keep
    ///   scanning. The user exits via Done on the banner.
    /// - Otherwise: dismiss (legacy single-receipt behavior).
    private func completeReceiptAction() {
        if isBatchActive && !batchQueue.isEmpty {
            advanceBatch(incrementSaved: true)
        } else if isBatchActive || batchSavedCount > 0 {
            batchSavedCount += 1
            resetReceiptState()
            isBatchActive = false
            batchCurrentIndex = 0
        } else {
            dismiss()
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
                context: modelContext,
                isBillMode: mode == .bill
            )
            
            editedMerchant = receipt.merchantName
            editedAmount = receipt.totalAmount
            editedTipAmount = receipt.tipAmount ?? 0
            editedShowTipField = (receipt.tipAmount ?? 0) > 0
            editedDate = receipt.date
            editedCategoryName = receipt.suggestedCategoryName ?? ""
            editedFinanceType = mode == .bill ? .personal : .business

            // Bill mode: seed due date from OCR if it looks like a future date,
            // otherwise default to one week out.
            if mode == .bill {
                if receipt.date > Date() {
                    editedDueDate = receipt.date
                } else {
                    editedDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                }
                editedIsUponReceipt = false
            }

            setDefaultAccount(cardLastFour: receipt.paymentLastFour)

            // Bill mode skips transaction matching — bills don't dedupe against transactions.
            if mode == .bill {
                potentialMatches = []
            } else {
                potentialMatches = TransactionMatchingService.shared.findPotentialMatches(
                    for: receipt,
                    in: transactions
                )
            }
            
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

            // In batch mode, skip the failed image and auto-advance so one bad
            // capture doesn't strand the whole run.
            if isBatchActive && !batchQueue.isEmpty {
                advanceBatch(incrementSaved: false)
            }
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

                #if DEBUG
                print("🔗 Linked receipt to transaction: \(transaction.merchantName)")
                #endif

                completeReceiptAction()
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

                #if DEBUG
                print("🔗 Marked as cash purchase: \(receipt.merchantName)")
                #endif

                completeReceiptAction()
            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticService.play(.error)
            }
        }
    }
    
    private func saveAndCreateTransaction() {
        guard let receipt = processedReceipt else { return }

        HapticService.play(.medium)

        let finalAmount = editedAmount > 0 ? editedAmount : receipt.totalAmount
        let finalMerchant = editedMerchant.isEmpty ? receipt.merchantName : editedMerchant
        let finalCategory = editedCategoryName
        let resolvedTip: Double? = (editedShowTipField && editedTipAmount > 0) ? editedTipAmount : nil

        receipt.merchantName = finalMerchant
        receipt.totalAmount = finalAmount
        receipt.date = editedDate
        receipt.suggestedCategoryName = finalCategory.isEmpty ? nil : finalCategory
        receipt.tipAmount = resolvedTip

        // Determine whether the user has split this receipt 0 < % < 100.
        // If so, we will create two linked transactions instead of one.
        let isSplitReceipt = receipt.businessPercentage > 0 && receipt.businessPercentage < 100

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

                    if isSplitReceipt {
                        // Two-transaction split: business + personal
                        let groupId = UUID()
                        let bizFraction = receipt.businessPercentage / 100.0
                        let bizAmount = (finalAmount * bizFraction * 100).rounded() / 100
                        let personalAmount = ((finalAmount - bizAmount) * 100).rounded() / 100

                        // Tip is allocated proportionally to each side. Either side gets nil if its share rounds to 0.
                        let bizTip: Double? = {
                            guard let tip = resolvedTip else { return nil }
                            let val = (tip * bizFraction * 100).rounded() / 100
                            return val > 0 ? val : nil
                        }()
                        let personalTip: Double? = {
                            guard let tip = resolvedTip else { return nil }
                            let val = ((tip - (bizTip ?? 0)) * 100).rounded() / 100
                            return val > 0 ? val : nil
                        }()

                        // Choose accounts: keep selected for the side that matches editedFinanceType,
                        // and try to find a matching account for the other side. Fall back to nil.
                        let active = accounts.filter { $0.isActive }
                        let bizAccount: Account? = {
                            if editedFinanceType == .business { return selectedAccount }
                            return active.first(where: { $0.financeType == .business && $0.isPrimary })
                                ?? active.first(where: { $0.financeType == .business })
                        }()
                        let personalAccount: Account? = {
                            if editedFinanceType == .personal { return selectedAccount }
                            return active.first(where: { $0.financeType == .personal && $0.isPrimary })
                                ?? active.first(where: { $0.financeType == .personal })
                        }()

                        let bizNote = editedNote.isEmpty ? "Scanned receipt (business portion)" : "\(editedNote) (business portion)"
                        let bizTx = Transaction(
                            amount: bizAmount,
                            date: editedDate,
                            note: bizNote,
                            isIncome: false,
                            merchantName: finalMerchant,
                            category: categoryObject,
                            financeType: .business,
                            account: bizAccount,
                            hasReceipt: true,
                            tipAmount: bizTip,
                            splitGroupId: groupId
                        )
                        bizTx.receiptImagePath = imagePath

                        let personalNote = editedNote.isEmpty ? "Scanned receipt (personal portion)" : "\(editedNote) (personal portion)"
                        let personalTx = Transaction(
                            amount: personalAmount,
                            date: editedDate,
                            note: personalNote,
                            isIncome: false,
                            merchantName: finalMerchant,
                            // Personal side intentionally has no category — categories are usually business-relevant.
                            category: nil,
                            financeType: .personal,
                            account: personalAccount,
                            hasReceipt: true,
                            tipAmount: personalTip,
                            splitGroupId: groupId
                        )
                        personalTx.receiptImagePath = imagePath

                        modelContext.insert(bizTx)
                        modelContext.insert(personalTx)

                        // Primary link goes to the business side (more likely to need receipt access).
                        receipt.transactionID = bizTx.id
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
                        print("🔗 Created SPLIT transactions from receipt: \(finalMerchant)")
                        print("   Business: \(bizAmount.asCurrency) → \(bizAccount?.name ?? "no account")")
                        print("   Personal: \(personalAmount.asCurrency) → \(personalAccount?.name ?? "no account")")
                        #endif
                    } else {
                        // Single-transaction path (existing flow)
                        let singleNote = editedNote.isEmpty ? "Scanned receipt" : editedNote
                        let transaction = Transaction(
                            amount: finalAmount,
                            date: editedDate,
                            note: singleNote,
                            isIncome: false,
                            merchantName: finalMerchant,
                            category: categoryObject,
                            financeType: editedFinanceType,
                            account: selectedAccount,
                            hasReceipt: true,
                            tipAmount: resolvedTip
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
                }

                completeReceiptAction()

            } catch {
                errorMessage = "Failed to save: \(error.localizedDescription)"
                HapticService.play(.error)

                #if DEBUG
                print("❌ Save error: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Save (Bill mode, v3.9)

    private func saveAndCreateBill() {
        guard let receipt = processedReceipt else { return }

        HapticService.play(.medium)

        let finalAmount = editedAmount > 0 ? editedAmount : receipt.totalAmount
        let finalVendor = editedMerchant.isEmpty ? receipt.merchantName : editedMerchant

        // Resolve category by name
        var categoryObject: Category? = nil
        if !editedCategoryName.isEmpty {
            let name = editedCategoryName
            let categoryDescriptor = FetchDescriptor<Category>(
                predicate: #Predicate<Category> { $0.name == name }
            )
            categoryObject = try? modelContext.fetch(categoryDescriptor).first
        }

        // Use the scanned image as the bill's stored image (if available).
        let imageData: Data? = {
            if let data = receipt.imageData { return data }
            #if canImport(UIKit)
            if let image = selectedImage { return image.jpegData(compressionQuality: 0.8) }
            #endif
            return nil
        }()

        do {
            _ = try BillService.shared.createBill(
                vendorName: finalVendor,
                amount: finalAmount,
                dueDate: editedIsUponReceipt ? nil : editedDueDate,
                isUponReceipt: editedIsUponReceipt,
                note: "Scanned bill",
                financeType: editedFinanceType,
                category: categoryObject,
                account: selectedAccount,
                scannedImageData: imageData,
                context: modelContext
            )
            HapticService.play(.success)

            #if DEBUG
            print("🧾 Created bill from scanner: \(finalVendor) - \(finalAmount.asCurrency)")
            #endif

            completeReceiptAction()
        } catch {
            errorMessage = "Failed to save bill: \(error.localizedDescription)"
            HapticService.play(.error)
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
            // Generate thumbnail alongside the full image (best-effort)
            try? await PhotoStorageManager.shared.saveThumbnail(forFilename: filename, from: image)
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
        editedAmount = 0
        editedDate = Date()
        editedCategoryName = ""
        selectedAccount = nil
        editedNote = ""
        selectedBusinessProfile = nil
    }
}

// MARK: - Editable Receipt Review View with Account

struct EditableReceiptReviewViewWithAccount: View {
    let receipt: ReceiptData
    @Binding var editedMerchant: String
    @Binding var editedAmount: Double
    @Binding var editedTipAmount: Double
    @Binding var editedShowTipField: Bool
    @Binding var editedDate: Date
    @Binding var editedCategoryName: String
    @Binding var editedFinanceType: Transaction.FinanceType
    @Binding var selectedAccount: Account?
    @Binding var editedNote: String
    @Binding var selectedBusinessProfile: BusinessProfile?
    let categories: [Category]
    let accounts: [Account]
    let businessProfiles: [BusinessProfile]
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

    /// Expense categories deduplicated by name first, then split by classification.
    /// Dedup must happen BEFORE the business/personal split because duplicate
    /// records from multiple seed runs may have inconsistent isBusiness flags.
    private var uniqueExpenseCategories: [Category] {
        let expense = categories.filter { !$0.isIncome }.sorted { $0.name < $1.name }
        var seen = Set<String>()
        return expense.filter { seen.insert($0.name).inserted }
    }

    /// Categories filtered by the current classification, already deduplicated.
    private var filteredCategories: [Category] {
        editedFinanceType == .business
            ? uniqueExpenseCategories.filter { $0.isBusiness }
            : uniqueExpenseCategories.filter { !$0.isBusiness }
    }
    
    /// Returns the edited category name only if it exists in the *filtered* category list
    /// This prevents "invalid selection" picker warnings when a business category is
    /// suggested but the classification is set to personal (or vice versa)
    private var validatedCategoryName: Binding<String> {
        Binding(
            get: {
                // Must match the FILTERED list (what the picker actually shows)
                if filteredCategories.contains(where: { $0.name == editedCategoryName }) {
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
        let active = accounts.filter { $0.isActive && $0.includeInTransactions }

        return active.sorted { (a: Account, b: Account) -> Bool in
            if a.financeType == editedFinanceType && b.financeType != editedFinanceType { return true }
            if b.financeType == editedFinanceType && a.financeType != editedFinanceType { return false }
            if a.isPrimary && !b.isPrimary { return true }
            if b.isPrimary && !a.isPrimary { return false }
            return a.name < b.name
        }
    }

    /// True if the receipt has been split (some non-100/non-0 business percentage).
    private var hasSplitApplied: Bool {
        receipt.businessPercentage > 0 && receipt.businessPercentage < 100
    }

    @ViewBuilder
    private var splitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                HapticService.play(.light)
                onSplit()
            }) {
                HStack {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.subheadline)
                    Text(hasSplitApplied ? "Edit Split" : "Split Business / Personal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandPrimary.opacity(hasSplitApplied ? 0.15 : 0.08))
                )
                .foregroundStyle(Color.brandPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasSplitApplied ? "Edit business and personal split" : "Split this receipt between business and personal")
            .accessibilityHint("Opens split editor with percentage, line item, or fixed amount modes")

            if hasSplitApplied {
                let bizPct = Int(receipt.businessPercentage.rounded())
                let perPct = 100 - bizPct
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Split: \(bizPct)% Business / \(perPct)% Personal")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Split applied: \(bizPct) percent business, \(perPct) percent personal")
            } else if (receipt.lineItems?.count ?? 0) > 1 {
                // Nudge: line items detected — suggest split
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("Multiple items detected — tap to split")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - OCR Confidence Banner

    @ViewBuilder
    private var ocrConfidenceBanner: some View {
        let pct = Int(receipt.ocrConfidence * 100)
        let isLow = receipt.ocrConfidence < 0.5
        let isMedium = receipt.ocrConfidence >= 0.5 && receipt.ocrConfidence < 0.8

        HStack(spacing: 8) {
            Image(systemName: isLow ? "exclamationmark.triangle.fill" : (isMedium ? "info.circle.fill" : "checkmark.circle.fill"))
                .font(.subheadline)
                .foregroundStyle(isLow ? .orange : (isMedium ? .yellow : .green))

            VStack(alignment: .leading, spacing: 2) {
                Text("Scan Quality: \(pct)%")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isLow {
                    Text("Low quality — please verify all fields")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else if isMedium {
                    Text("Review fields for accuracy")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer()

            if isLow {
                Button {
                    onReset()
                } label: {
                    Text("Retry")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isLow ? Color.orange.opacity(0.08) : (isMedium ? Color.yellow.opacity(0.08) : Color.green.opacity(0.08)))
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan quality \(pct) percent\(isLow ? ", low quality, verify all fields" : "")")
    }

    // MARK: - Merchant, Amount, Tip & Date Section

    @ViewBuilder
    private var merchantAmountDateSection: some View {
        // Merchant
        VStack(alignment: .leading, spacing: 4) {
            Text("Merchant")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            CurrencyInputField(
                amount: $editedAmount,
                accessibilityLabelText: "Receipt amount"
            )
        }

        Divider()

        // Tip (optional, included in amount above)
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $editedShowTipField.animation(.easeInOut(duration: 0.2))) {
                Text("Includes tip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .onChange(of: editedShowTipField) { _, isOn in
                if !isOn { editedTipAmount = 0 }
                HapticService.play(.light)
            }

            if editedShowTipField {
                CurrencyInputField(
                    amount: $editedTipAmount,
                    accessibilityLabelText: "Tip amount"
                )
                Text("Tip is already included in the receipt total above.")
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
        }

        Divider()

        // Date
        VStack(alignment: .leading, spacing: 4) {
            Text("Date")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            DatePicker("", selection: $editedDate, displayedComponents: .date)
                .labelsHidden()
        }
    }

    // MARK: - Classification Section (broken out to avoid type-checker timeout)

    @ViewBuilder
    private var classificationSection: some View {
        // Classification (Business/Personal) — shown BEFORE Category
        VStack(alignment: .leading, spacing: 4) {
            Text("Classification")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            Picker("Classification", selection: $editedFinanceType) {
                Label("Business", systemImage: "briefcase.fill")
                    .tag(Transaction.FinanceType.business)
                Label("Personal", systemImage: "person.fill")
                    .tag(Transaction.FinanceType.personal)
            }
            .pickerStyle(.segmented)
            .onChange(of: editedFinanceType) { _, newType in
                if newType == .personal {
                    selectedBusinessProfile = nil
                } else if newType == .business && businessProfiles.count == 1 {
                    selectedBusinessProfile = businessProfiles.first
                    if let profile = businessProfiles.first,
                       let matchingAccount = accounts.first(where: { $0.businessProfile?.id == profile.id }) {
                        selectedAccount = matchingAccount
                    }
                }
                HapticService.play(.light)
            }
            // v4.7: Auto-set classification when selecting a business account
            .onChange(of: selectedAccount) { _, newAccount in
                if let account = newAccount, account.businessProfile != nil, editedFinanceType != .business {
                    editedFinanceType = .business
                }
            }
        }

        if editedFinanceType == .business {
            HStack {
                Label("Tax Deductible", systemImage: "checkmark.seal.fill")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.green)
                    .font(.footnote)
                Spacer()
            }

            businessProfilePicker
        }
    }

    // MARK: - Business Profile Picker

    @ViewBuilder
    private var businessProfilePicker: some View {
        if businessProfiles.count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Business Profile")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(businessProfiles) { profile in
                            businessProfileChip(for: profile)
                        }
                    }
                }
            }
        }
    }

    private func businessProfileChip(for profile: BusinessProfile) -> some View {
        let isSelected = selectedBusinessProfile?.id == profile.id
        return Button {
            withAnimation(FLOAnimation.quick) {
                if isSelected {
                    selectedBusinessProfile = nil
                } else {
                    selectedBusinessProfile = profile
                    if let matchingAccount = accounts.first(where: { $0.businessProfile?.id == profile.id }) {
                        selectedAccount = matchingAccount
                    }
                }
            }
            HapticService.play(.medium)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "building.2.fill")
                    .font(.caption2)
                Text(profile.businessName)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.2) : Color.floSecondarySystemBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.brandPrimary : .primary)
    }

    // MARK: - Category & Note Section

    @ViewBuilder
    private var categoryAndNoteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Category")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            Picker("Category", selection: validatedCategoryName) {
                Text("None").tag("")
                ForEach(filteredCategories) { cat in
                    Label(cat.name, systemImage: cat.icon)
                        .tag(cat.name)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.brandPrimary)
        }

        Divider()

        VStack(alignment: .leading, spacing: 4) {
            Text("Note")
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            TextField("Add a note (optional)", text: $editedNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        // All tiers can pick among their accounts
        if !accounts.isEmpty {
            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Account")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Receipt Image
                if let imageData = receipt.imageData,
                   let image = UIImage(data: imageData) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .accessibilityLabel("Scanned receipt image")
                }
                
                // OCR Confidence Indicator
                if receipt.ocrConfidence > 0 {
                    ocrConfidenceBanner
                }

                // Editable Fields Card
                VStack(spacing: 16) {
                    merchantAmountDateSection
                    Divider()
                    classificationSection
                    Divider()
                    categoryAndNoteSection
                    Divider()
                    splitSection
                    accountSection
                }
                .padding()
                .background(Color.floSecondarySystemBackground)
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
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            Text("You may have already scanned this receipt:")
                                .font(.caption)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
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
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
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
                    .background(duplicates.isEmpty ? Color.brandPrimary.opacity(0.05) : Color.brandWarning.opacity(0.08))
                    .cornerRadius(12)
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("Save Transaction", systemImage: "checkmark.circle.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    
                    Button(role: .destructive, action: onReset) {
                        Text("Scan Different Receipt")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
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

// MARK: - Editable Bill Review View (v3.9)

struct EditableBillReviewView: View {
    let receipt: ReceiptData
    @Binding var editedVendor: String
    @Binding var editedAmount: Double
    @Binding var editedDueDate: Date
    @Binding var editedIsUponReceipt: Bool
    @Binding var editedCategoryName: String
    @Binding var editedFinanceType: Transaction.FinanceType
    @Binding var selectedAccount: Account?
    let categories: [Category]
    let accounts: [Account]
    let onSave: () -> Void
    let onReset: () -> Void

    @FocusState private var vendorFocused: Bool

    private var expenseCategories: [Category] {
        categories.filter { !$0.isIncome }
    }

    /// Expense categories deduplicated by name, then filtered by classification.
    private var uniqueExpenseCategories: [Category] {
        let expense = categories.filter { !$0.isIncome }.sorted { $0.name < $1.name }
        var seen = Set<String>()
        return expense.filter { seen.insert($0.name).inserted }
    }

    private var filteredCategories: [Category] {
        editedFinanceType == .business
            ? uniqueExpenseCategories.filter { $0.isBusiness }
            : uniqueExpenseCategories.filter { !$0.isBusiness }
    }

    private var validatedCategoryName: Binding<String> {
        Binding(
            get: {
                // Must match the FILTERED list (what the picker actually shows)
                filteredCategories.contains(where: { $0.name == editedCategoryName }) ? editedCategoryName : ""
            },
            set: { editedCategoryName = $0 }
        )
    }

    private var sortedAccounts: [Account] {
        let active = accounts.filter { $0.isActive && $0.includeInTransactions }
        return active.sorted { (a, b) -> Bool in
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
                // Scanned bill image (cross-platform via UIImage = NSImage typealias on macOS)
                if let imageData = receipt.imageData,
                   let image = UIImage(data: imageData) {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .accessibilityLabel("Scanned bill image")
                }

                VStack(spacing: 16) {
                    // Vendor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vendor")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        TextField("Vendor name", text: $editedVendor)
                            .textFieldStyle(.roundedBorder)
                            .focused($vendorFocused)
                    }

                    Divider()

                    // Amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount Due")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        CurrencyInputField(
                            amount: $editedAmount,
                            accessibilityLabelText: "Bill amount"
                        )
                    }

                    Divider()

                    // Due Date / Upon Receipt
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $editedIsUponReceipt.animation(.easeInOut(duration: 0.2))) {
                            Text("Upon Receipt")
                                .font(.subheadline)
                        }
                        .onChange(of: editedIsUponReceipt) { _, _ in
                            HapticService.play(.light)
                            vendorFocused = false
                        }

                        if !editedIsUponReceipt {
                            DatePicker("Due Date", selection: $editedDueDate, displayedComponents: .date)
                        } else {
                            Text("Bill will appear in Upcoming with no fixed date and is treated as overdue 24 hours after creation.")
                                .font(.caption)
                                .lineLimit(3)
                                .minimumScaleFactor(0.85)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // Classification
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Classification")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        Picker("Classification", selection: $editedFinanceType) {
                            Label("Personal", systemImage: "person.fill")
                                .tag(Transaction.FinanceType.personal)
                            Label("Business", systemImage: "briefcase.fill")
                                .tag(Transaction.FinanceType.business)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: editedFinanceType) { _, _ in
                            HapticService.play(.light)
                        }
                    }

                    Divider()

                    // Category — filtered by selected classification, deduplicated
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        Picker("Category", selection: validatedCategoryName) {
                            Text("None").tag("")
                            ForEach(filteredCategories) { cat in
                                Label(cat.name, systemImage: cat.icon).tag(cat.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.brandPrimary)
                    }

                    // Pay From (account)
                    if !accounts.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pay From")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if selectedAccount != nil {
                                    Button("Clear") {
                                        withAnimation(FLOAnimation.quick) { selectedAccount = nil }
                                        HapticService.play(.light)
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
                                            showBalance: false
                                        ) {
                                            withAnimation(FLOAnimation.quick) {
                                                selectedAccount = (selectedAccount?.id == account.id) ? nil : account
                                            }
                                            HapticService.play(.medium)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.floSecondarySystemBackground)
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("Save Bill", systemImage: "checkmark.circle.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                    .disabled(editedVendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedAmount <= 0)

                    Button(role: .destructive, action: onReset) {
                        Text("Scan Different Bill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding()
            }
        }
        .onTapGesture { vendorFocused = false }
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
                        .font(.caption)
                        .foregroundStyle(Color(hex: account.color))
                }
                
                Text(account.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                         .foregroundStyle(Color.brandPrimary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.brandPrimary.opacity(0.1) : Color.secondary.opacity(0.12))
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("Extracting merchant, amount, and date")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Processing receipt, extracting merchant, amount, and date")
    }
}

struct CaptureOptionsView: View {
    /// Number of receipts successfully saved in the current batch session.
    /// Drives the "N saved" banner + Done button. Zero hides both.
    let batchSavedCount: Int
    /// Called when the user taps Scan Receipt or Scan Bill — sets mode and opens camera.
    let onScanSelected: (ScanMode) -> Void
    /// Called when the user taps Choose from Library — opens photo picker (defaults to transaction mode).
    let onPhotoSelected: () -> Void
    /// Called when the user picks a file or drops image(s) (macOS path, or multi-pick batch).
    let onImagesPicked: ([UIImage]) -> Void
    /// Called when the user taps Done on the batch banner — exits the scanner.
    let onFinishBatch: () -> Void

    @State private var isDropTargeted = false
    /// Drives the Mac Catalyst `.fileImporter` (native open panel) for picking a
    /// receipt/bill file — the cross-platform replacement for the macOS-only
    /// NSOpenPanel path, which is excluded on Catalyst (no AppKit).
    @State private var showingFileImporter = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if batchSavedCount > 0 {
                batchSavedBanner
                    .padding(.horizontal, 40)
            }

            Image(systemName: "doc.text.viewfinder")
                .font(.largeTitle)
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)

            Text(batchSavedCount > 0 ? "Scan Another" : "Scan a Document")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(batchSavedCount > 0
                 ? "Keep scanning or tap Done when finished"
                 : "Capture a receipt or bill to get started")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            // Drop target
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDropTargeted ? Color.brandPrimary : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .frame(height: 160)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.title)
                            .foregroundStyle(isDropTargeted ? Color.brandPrimary : .secondary)
                        Text(isDropTargeted ? "Release to scan" : "Drag an image here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                )
                .padding(.horizontal, 40)
                .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDrop(providers: providers)
                }
                .accessibilityLabel("Drop zone for receipt or bill image")

            VStack(spacing: 12) {
                Button {
                    HapticService.play(.light)
                    presentMacFilePicker(mode: .transaction)
                } label: {
                    Label("Choose Receipt File…", systemImage: "doc.text.viewfinder")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)

                Button {
                    HapticService.play(.light)
                    presentMacFilePicker(mode: .bill)
                } label: {
                    Label("Choose Bill File…", systemImage: "doc.text.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 40)
            #else
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst: drag a receipt/bill image or PDF from Finder or Mail.
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDropTargeted ? Color.brandPrimary : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .frame(height: 140)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.title)
                            .foregroundStyle(isDropTargeted ? Color.brandPrimary : .secondary)
                        Text(isDropTargeted ? "Release to scan" : "Drag an image or PDF here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                )
                .padding(.horizontal, 40)
                .onDrop(of: [UTType.image, UTType.pdf, UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleDropCatalyst(providers: providers)
                }
                .accessibilityLabel("Drop zone for receipt or bill file")
            #endif

            VStack(spacing: 12) {
                // Camera scanning is unavailable on Mac Catalyst (VisionKit's
                // document camera is iOS/iPadOS only), so hide the Scan buttons
                // there and rely on drag-drop / Choose File / Choose from Library.
                #if !targetEnvironment(macCatalyst)
                Button {
                    onScanSelected(.transaction)
                } label: {
                    Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)

                Button {
                    onScanSelected(.bill)
                } label: {
                    Label("Scan Bill", systemImage: "doc.text.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.blue)
                #endif

                Button {
                    HapticService.play(.light)
                    onPhotoSelected()
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)

                // Mac Catalyst: pick a receipt/bill file from Finder. Fills the
                // gap left by the excluded macOS NSOpenPanel path (camera/Photos
                // aren't the Mac way). iPhone/iPad are unchanged.
                #if targetEnvironment(macCatalyst)
                Button {
                    HapticService.play(.light)
                    showingFileImporter = true
                } label: {
                    Label("Choose File…", systemImage: "folder")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                #endif
            }
            .padding(.horizontal, 40)
            #endif

            Spacer()
        }
        #if targetEnvironment(macCatalyst)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true,
            onCompletion: importPickedFiles
        )
        #endif
    }

    // MARK: - Batch Saved Banner (v3.10)

    @ViewBuilder
    private var batchSavedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(batchSavedCount == 1 ? "1 receipt saved" : "\(batchSavedCount) receipts saved")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Ready for the next one")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Button {
                onFinishBatch()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
            .accessibilityLabel("Finish scanning, \(batchSavedCount) receipt\(batchSavedCount == 1 ? "" : "s") saved")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
    }

    #if os(macOS)
    // MARK: - macOS File Picker

    private func presentMacFilePicker(mode: ScanMode) {
        let panel = NSOpenPanel()
        panel.title = mode == .bill ? "Choose Bill Image(s)" : "Choose Receipt Image(s)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image, .pdf, .png, .jpeg, .tiff, .heic]

        if panel.runModal() == .OK {
            let images = panel.urls.compactMap { NSImage(contentsOf: $0) }
            guard !images.isEmpty else { return }
            // Set mode before loading so processImage uses the right parser path
            onScanSelected(mode)
            onImagesPicked(images)
        }
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        let collector = DropImageCollector(expected: providers.count) { images in
            guard !images.isEmpty else { return }
            onImagesPicked(images)
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    let image = url.flatMap { NSImage(contentsOf: $0) }
                    collector.submit(image)
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    collector.submit(object as? NSImage)
                }
            } else {
                collector.submit(nil)
            }
        }

        return true
    }
    #endif

    #if targetEnvironment(macCatalyst)
    // MARK: - Mac Catalyst File Import
    // `.fileImporter` (a native open panel on Catalyst) → UIImage(s) → the same
    // `onImagesPicked` pipeline the camera/library paths use. Replaces the
    // macOS-only NSOpenPanel, which Catalyst can't reach. Imports as a receipt
    // (the scanner's default `.transaction` mode).

    private func importPickedFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        let images = urls.compactMap { loadImage(from: $0) }
        guard !images.isEmpty else { return }
        onImagesPicked(images)
    }

    private func loadImage(from url: URL) -> UIImage? {
        // Security-scoped: the picked URL lives outside the app sandbox.
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let image = UIImage(data: data) { return image }
        return Self.firstPDFPageImage(from: data)   // PDF receipts → rasterize page 1
    }

    private static func firstPDFPageImage(from data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else { return nil }
        let pageRect = page.getBoxRect(.mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: pageRect.size))
            ctx.cgContext.translateBy(x: 0, y: pageRect.size.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            ctx.cgContext.drawPDFPage(page)
        }
    }

    // Drag-drop landing for Catalyst. UIImage-based (the macOS DropImageCollector
    // is NSImage-based, which Catalyst can't use). Waits for every dropped
    // provider to resolve, then feeds the full set into onImagesPicked.
    private func handleDropCatalyst(providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }

        let buffer = DropImageBuffer(expected: providers.count) { images in
            guard !images.isEmpty else { return }
            onImagesPicked(images)
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    let image = url.flatMap { loadImage(from: $0) }
                    buffer.submit(image)
                }
            } else if provider.canLoadObject(ofClass: UIImage.self) {
                _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                    buffer.submit(object as? UIImage)
                }
            } else {
                buffer.submit(nil)
            }
        }

        return true
    }
    #endif
}

#if os(macOS)
/// Thread-safe accumulator for drag-drop image providers — lets us wait until
/// every provider has resolved before firing `onImagesPicked` with the full set.
private final class DropImageCollector {
    private let expected: Int
    private let onComplete: ([NSImage]) -> Void
    private var images: [NSImage] = []
    private var received: Int = 0
    private let queue = DispatchQueue(label: "com.flo.dropCollector")

    init(expected: Int, onComplete: @escaping ([NSImage]) -> Void) {
        self.expected = expected
        self.onComplete = onComplete
    }

    func submit(_ image: NSImage?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let image = image { self.images.append(image) }
            self.received += 1
            if self.received >= self.expected {
                let collected = self.images
                DispatchQueue.main.async {
                    self.onComplete(collected)
                }
            }
        }
    }
}
#endif

#if targetEnvironment(macCatalyst)
/// Catalyst counterpart to DropImageCollector — accumulates UIImages from a
/// drag-drop batch and fires once every provider has resolved.
private final class DropImageBuffer {
    private let expected: Int
    private let onComplete: ([UIImage]) -> Void
    private var images: [UIImage] = []
    private var received: Int = 0
    private let queue = DispatchQueue(label: "com.flo.catalystDropBuffer")

    init(expected: Int, onComplete: @escaping ([UIImage]) -> Void) {
        self.expected = expected
        self.onComplete = onComplete
    }

    func submit(_ image: UIImage?) {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let image = image { self.images.append(image) }
            self.received += 1
            if self.received >= self.expected {
                let collected = self.images
                DispatchQueue.main.async {
                    self.onComplete(collected)
                }
            }
        }
    }
}
#endif

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.expenseRed.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.expenseRed.opacity(0.3), lineWidth: 1)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text(match.transaction.date, style: .date)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    
                    Text(match.displayConfidence)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(colorForConfidence(match.matchType))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(match.transaction.amount.asCurrency)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(Color.floSecondarySystemBackground)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Text(match.transaction.date, style: .date)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                
                Text("\(Int(match.score * 100))% match - already has receipt")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(match.transaction.amount.asCurrency)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                if match.transaction.hasReceipt {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding()
        .background(Color.brandWarning.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.brandWarning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Image Picker

#if canImport(UIKit)
struct ImagePicker: UIViewControllerRepresentable {
    /// Invoked once with all selected images. Empty array if the user cancels
    /// or every item fails to load.
    var onSelect: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // unlimited — batch scanning (v3.10)
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

            guard !results.isEmpty else {
                parent.onSelect([])
                return
            }

            // Preserve user selection order while loading asynchronously.
            var buffer: [Int: UIImage] = [:]
            let group = DispatchGroup()
            let lock = NSLock()

            for (index, result) in results.enumerated() {
                let provider = result.itemProvider
                guard provider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    if let image = object as? UIImage {
                        lock.lock()
                        buffer[index] = image
                        lock.unlock()
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) { [parent] in
                let ordered = buffer.keys.sorted().compactMap { buffer[$0] }
                parent.onSelect(ordered)
            }
        }
    }
}
#endif

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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
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
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    
                                    Text(match.transaction.date, style: .date)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(match.displayConfidence)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(colorForConfidence(match.matchType))
                                }
                                
                                Spacer()
                                
                                Text(match.transaction.amount.asCurrency)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                    }
                }
                
                Section {
                    Button("No Match - New Transaction") {
                        onCashPurchase()
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
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
