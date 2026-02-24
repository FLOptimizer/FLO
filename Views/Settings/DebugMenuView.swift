//  DebugMenuView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Usage Limit Testing Controls
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  DEBUG ONLY - Hidden developer menu for testing
//
//  ACCESS: Triple-tap version info in Tax Disclaimer view
//
//  CHANGES v1.4:
//  - ADDED: "Usage Limit Testing" section with count override controls
//  - ADDED: Stepper controls for transactions, receipts, invoices
//  - ADDED: Quick preset buttons for 50%, 80%, 90%, 100% of current tier limits
//  - ADDED: "Clear All Overrides" button to revert to real counts
//  - ADDED: Visual indicator when overrides are active (orange dot)
//  - ADDED: Dynamic presets that adapt to current subscription tier
//  - ADDED: Override status banner showing active overrides
//  - Uses UsageLimitService static debug methods (no instance needed)
//
//  CHANGES v1.3:
//  - FIXED: Subscription tier buttons now actually work
//  - ADDED: "Clear Override" button to revert to default Pro
//  - ADDED: Visual indicator showing if override is active
//  - ADDED: Tier persists across app launches
//  - REMOVED: Broken SubscriptionManager extension (now built-in)
//
//  CHANGES v1.2:
//  - Fixed SubscriptionTier.allCases (not CaseIterable) - using manual array
//
//  CHANGES v1.1:
//  - Fixed complex expression error by breaking up List sections
//  - Removed MileageSetupPromptView from previews (requires complex dependencies)
//  - Simplified screen preview section
//

import SwiftUI
import SwiftData

#if DEBUG

struct DebugMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var isSeeding = false
    @State private var isResetting = false
    @State private var showingResetConfirmation = false
    @State private var showingSeedConfirmation = false
    @State private var dataCounts: [(String, Int)] = []
    @State private var statusMessage: String?
    
    // v1.4: Usage limit override state
    @State private var transactionOverride: Int = 0
    @State private var receiptOverride: Int = 0
    @State private var invoiceOverride: Int = 0
    @State private var hasTransactionOverride: Bool = false
    @State private var hasReceiptOverride: Bool = false
    @State private var hasInvoiceOverride: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                warningSection
                statusSection
                subscriptionSection
                usageLimitTestingSection
                dataManagementSection
                dataCountsSection
                screenPreviewsSection
                systemInfoSection
                appStateSection
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                refreshDataCounts()
                loadOverrideState()
            }
            .confirmationDialog("Seed Test Data?", isPresented: $showingSeedConfirmation, titleVisibility: .visible) {
                Button("Seed All Data") {
                    seedData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will add comprehensive test data including business profile, accounts, transactions, invoices, mileage trips, and more.")
            }
            .confirmationDialog("Reset All Data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) {
                    resetData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete ALL data. This cannot be undone!")
            }
        }
    }
    
    // MARK: - Sections (Broken up to help compiler)
    
    private var warningSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Developer Menu")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("DEBUG BUILD ONLY")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        if let message = statusMessage {
            Section {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(message)
                        .font(.subheadline)
                }
            }
        }
    }
    
    // MARK: - Subscription Section (FIXED in v1.3)
    
    // All subscription tiers for testing
    private let allTiers: [SubscriptionTier] = [.free, .premium, .pro]
    
    private var subscriptionSection: some View {
        Section {
            // Current tier display with override indicator
            currentTierRow
            
            // Divider
            Divider()
            
            // Tier selection buttons
            ForEach(allTiers, id: \.self) { tier in
                tierButton(tier)
            }
            
            // Clear override button
            clearOverrideButton
            
        } header: {
            Label("Subscription Testing", systemImage: "star.fill")
        } footer: {
            Text("Changes take effect immediately. Tier persists across app launches in DEBUG builds.")
        }
    }
    
    private var currentTierRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Tier")
                    .foregroundStyle(.secondary)
                Text(subscriptionManager.debugCurrentTierInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(subscriptionManager.currentTier.displayName)
                .font(.headline)
                .foregroundStyle(tierColor(subscriptionManager.currentTier))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tierColor(subscriptionManager.currentTier).opacity(0.15))
                .cornerRadius(8)
        }
    }
    
    private func tierButton(_ tier: SubscriptionTier) -> some View {
        Button {
            setSubscriptionTier(tier)
        } label: {
            HStack {
                Image(systemName: tier == subscriptionManager.currentTier ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(tier == subscriptionManager.currentTier ? tierColor(tier) : .secondary)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.displayName)
                        .foregroundStyle(.primary)
                        .fontWeight(tier == subscriptionManager.currentTier ? .semibold : .regular)
                    
                    Text(tier.tagline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Show price for reference
                Text(tier.monthlyPrice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var clearOverrideButton: some View {
        Button {
            clearTierOverride()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.orange)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear Override")
                        .foregroundStyle(.primary)
                    Text("Revert to default (Pro)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Usage Limit Testing Section (v1.4)
    
    /// Current tier for computing presets
    private var currentTier: SubscriptionTier {
        subscriptionManager.currentTier
    }
    
    /// Whether any usage override is active
    private var anyOverrideActive: Bool {
        hasTransactionOverride || hasReceiptOverride || hasInvoiceOverride
    }
    
    private var usageLimitTestingSection: some View {
        Section {
            // Override status banner
            if anyOverrideActive {
                overrideActiveBanner
            }
            
            // Transaction overrides (only if tier has a limit)
            if currentTier.transactionLimit != nil {
                transactionOverrideRow
            } else {
                unlimitedRow(label: "Transactions", icon: "arrow.left.arrow.right")
            }
            
            // Receipt overrides (only if tier has a limit)
            if currentTier.receiptStorageLimit != nil {
                receiptOverrideRow
            } else {
                unlimitedRow(label: "Receipts", icon: "doc.text")
            }
            
            // Invoice overrides (only if tier has a non-zero limit)
            if let limit = currentTier.invoiceLimit, limit > 0 {
                invoiceOverrideRow
            } else if currentTier.invoiceLimit == 0 {
                blockedRow(label: "Invoices", icon: "doc.plaintext")
            } else {
                unlimitedRow(label: "Invoices", icon: "doc.plaintext")
            }
            
            // Quick presets
            quickPresetButtons
            
            // Clear all overrides
            clearAllOverridesButton
            
        } header: {
            HStack {
                Label("Usage Limit Testing", systemImage: "gauge.with.dots.needle.67percent")
                if anyOverrideActive {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
            }
        } footer: {
            Text("Override usage counts to test warning banners and limit enforcement without creating real records. Overrides persist across app launches. Navigate to Add Transaction, Receipts, or Invoices after setting to see them in action.")
        }
    }
    
    // MARK: - Override Active Banner
    
    private var overrideActiveBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Overrides Active")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.orange)
                
                Text(activeOverrideSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var activeOverrideSummary: String {
        var parts: [String] = []
        if hasTransactionOverride {
            let limitStr = currentTier.transactionLimit.map { "/\($0)" } ?? ""
            parts.append("Txns: \(transactionOverride)\(limitStr)")
        }
        if hasReceiptOverride {
            let limitStr = currentTier.receiptStorageLimit.map { "/\($0)" } ?? ""
            parts.append("Rcpts: \(receiptOverride)\(limitStr)")
        }
        if hasInvoiceOverride {
            let limitStr = currentTier.invoiceLimit.map { "/\($0)" } ?? ""
            parts.append("Inv: \(invoiceOverride)\(limitStr)")
        }
        return parts.joined(separator: " | ")
    }
    
    // MARK: - Individual Override Rows
    
    private var transactionOverrideRow: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(hasTransactionOverride ? .orange : Color.brandPrimary)
                    .frame(width: 24)
                
                Text("Transactions")
                    .font(.subheadline)
                
                Spacer()
                
                if hasTransactionOverride {
                    Text("OVERRIDE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Text("\(transactionOverride) / \(currentTier.transactionLimit ?? 0)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(hasTransactionOverride ? .orange : .secondary)
            }
            
            Stepper(
                value: $transactionOverride,
                in: 0...(currentTier.transactionLimit ?? 100),
                step: 1
            ) {
                EmptyView()
            }
            .onChange(of: transactionOverride) { _, newValue in
                applyOverride(for: .transactions, count: newValue)
            }
        }
    }
    
    private var receiptOverrideRow: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(hasReceiptOverride ? .orange : Color.brandPrimary)
                    .frame(width: 24)
                
                Text("Receipts")
                    .font(.subheadline)
                
                Spacer()
                
                if hasReceiptOverride {
                    Text("OVERRIDE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Text("\(receiptOverride) / \(currentTier.receiptStorageLimit ?? 0)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(hasReceiptOverride ? .orange : .secondary)
            }
            
            Stepper(
                value: $receiptOverride,
                in: 0...(currentTier.receiptStorageLimit ?? 200),
                step: 1
            ) {
                EmptyView()
            }
            .onChange(of: receiptOverride) { _, newValue in
                applyOverride(for: .receipts, count: newValue)
            }
        }
    }
    
    private var invoiceOverrideRow: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "doc.plaintext")
                    .foregroundStyle(hasInvoiceOverride ? .orange : Color.brandPrimary)
                    .frame(width: 24)
                
                Text("Invoices")
                    .font(.subheadline)
                
                Spacer()
                
                if hasInvoiceOverride {
                    Text("OVERRIDE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
                
                Text("\(invoiceOverride) / \(currentTier.invoiceLimit ?? 0)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(hasInvoiceOverride ? .orange : .secondary)
            }
            
            Stepper(
                value: $invoiceOverride,
                in: 0...(currentTier.invoiceLimit ?? 50),
                step: 1
            ) {
                EmptyView()
            }
            .onChange(of: invoiceOverride) { _, newValue in
                applyOverride(for: .invoices, count: newValue)
            }
        }
    }
    
    private func unlimitedRow(label: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text("Unlimited")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }
    
    private func blockedRow(label: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.red)
                .frame(width: 24)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text("Blocked (0)")
                .font(.subheadline)
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Quick Preset Buttons
    
    private var quickPresetButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Presets")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                presetButton(label: "50%", percentage: 0.50, color: .blue)
                presetButton(label: "80%", percentage: 0.80, color: .orange)
                presetButton(label: "90%", percentage: 0.90, color: Color(.systemRed).opacity(0.8))
                presetButton(label: "100%", percentage: 1.00, color: .red)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func presetButton(label: String, percentage: Double, color: Color) -> some View {
        Button {
            applyPreset(percentage: percentage)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Clear All Overrides Button
    
    private var clearAllOverridesButton: some View {
        Button {
            clearAllOverrides()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(.orange)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear All Overrides")
                        .foregroundStyle(.primary)
                    Text("Revert to real SwiftData counts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .disabled(!anyOverrideActive)
    }
    
    // MARK: - Other Existing Sections
    
    private var dataManagementSection: some View {
        Section {
            seedDataButton
            resetDataButton
            refreshCountsButton
        } header: {
            Label("Data Management", systemImage: "cylinder.split.1x2.fill")
        }
    }
    
    private var seedDataButton: some View {
        Button {
            showingSeedConfirmation = true
        } label: {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text("Seed Test Data")
                        .foregroundStyle(.primary)
                    Text("Populates all models with realistic data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isSeeding {
                    ProgressView()
                }
            }
        }
        .disabled(isSeeding)
    }
    
    private var resetDataButton: some View {
        Button {
            showingResetConfirmation = true
        } label: {
            HStack {
                Image(systemName: "trash.fill")
                    .foregroundStyle(.red)
                    .frame(width: 30)
                
                VStack(alignment: .leading) {
                    Text("Reset All Data")
                        .foregroundStyle(.red)
                    Text("Permanently deletes everything")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isResetting {
                    ProgressView()
                }
            }
        }
        .disabled(isResetting)
    }
    
    private var refreshCountsButton: some View {
        Button {
            refreshDataCounts()
            HapticService.play(.light)
            statusMessage = "Data counts refreshed"
            
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    statusMessage = nil
                }
            }
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.blue)
                    .frame(width: 30)
                
                Text("Refresh Counts")
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private var dataCountsSection: some View {
        Section {
            ForEach(dataCounts, id: \.0) { label, count in
                dataCountRow(label: label, count: count)
            }
            
            if !dataCounts.isEmpty {
                totalCountRow
            }
        } header: {
            Label("Data Counts", systemImage: "number.circle.fill")
        }
    }
    
    private func dataCountRow(label: String, count: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
    }
    
    private var totalCountRow: some View {
        HStack {
            Text("Total Records")
                .fontWeight(.semibold)
            Spacer()
            Text("\(dataCounts.reduce(0) { $0 + $1.1 })")
                .font(.headline)
                .foregroundStyle(.blue)
        }
    }
    
    private var screenPreviewsSection: some View {
        Section {
            NavigationLink {
                OnboardingView()
            } label: {
                HStack {
                    Image(systemName: "hand.wave.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 30)
                    Text("Onboarding")
                }
            }
            
            NavigationLink {
                SubscriptionView()
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 30)
                    Text("Subscription")
                }
            }
            
            // Note: MileageSetupPromptView requires complex dependencies
            // Use Mileage Tracking main view instead for testing
            NavigationLink {
                MileageTrackingMainView()
            } label: {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 30)
                    Text("Mileage Tracking")
                }
            }
        } header: {
            Label("Screen Previews", systemImage: "rectangle.on.rectangle")
        } footer: {
            Text("Jump directly to specific screens for testing")
        }
    }
    
    private var systemInfoSection: some View {
        Section {
            InfoRow(label: "App Version", value: Bundle.main.appVersionLong)
            InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
            InfoRow(label: "Device", value: UIDevice.current.model)
            InfoRow(label: "Build Config", value: "DEBUG")
        } header: {
            Label("System Info", systemImage: "info.circle.fill")
        }
    }
    
    private var appStateSection: some View {
        Section {
            Button {
                resetOnboarding()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    Text("Reset Onboarding Flag")
                        .foregroundStyle(.primary)
                }
            }
            
            Button {
                resetGettingStarted()
            } label: {
                HStack {
                    Image(systemName: "checklist")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    Text("Reset Getting Started Card")
                        .foregroundStyle(.primary)
                }
            }
        } header: {
            Label("App State", systemImage: "gearshape.fill")
        } footer: {
            Text("Reset various app state flags for testing")
        }
    }
    
    // MARK: - Actions
    
    private func seedData() {
        isSeeding = true
        statusMessage = nil
        
        Task {
            await SeedDataService.shared.seedAllData(context: modelContext)
            
            await MainActor.run {
                isSeeding = false
                statusMessage = "Test data seeded successfully!"
                refreshDataCounts()
                HapticService.play(.success)
            }
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    private func resetData() {
        isResetting = true
        statusMessage = nil
        
        Task {
            await SeedDataService.shared.resetAllData(context: modelContext)
            
            await MainActor.run {
                isResetting = false
                statusMessage = "All data deleted successfully!"
                refreshDataCounts()
                HapticService.play(.success)
            }
            
            // Clear message after delay
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    private func refreshDataCounts() {
        dataCounts = SeedDataService.shared.getDataCounts(context: modelContext)
    }
    
    /// Set subscription tier - NOW ACTUALLY WORKS (v1.3)
    private func setSubscriptionTier(_ tier: SubscriptionTier) {
        subscriptionManager.debugSetTier(tier)
        HapticService.play(.selection)
        statusMessage = "Tier changed to \(tier.displayName)"
        
        // Reload override state since limits may have changed
        loadOverrideState()
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    /// Clear tier override and revert to default
    private func clearTierOverride() {
        subscriptionManager.debugClearTierOverride()
        HapticService.play(.selection)
        statusMessage = "Tier override cleared (now Pro)"
        
        // Reload override state since limits may have changed
        loadOverrideState()
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        HapticService.play(.success)
        statusMessage = "Onboarding will show on next launch"
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    private func resetGettingStarted() {
        UserDefaults.standard.set(false, forKey: "hasDismissedGettingStarted")
        HapticService.play(.success)
        statusMessage = "Getting Started card will reappear"
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    // MARK: - Usage Limit Override Actions (v1.4)
    
    /// Load current override state from UserDefaults
    private func loadOverrideState() {
        if let val = UsageLimitService.debugGetOverrideStatic(for: .transactions) {
            transactionOverride = val
            hasTransactionOverride = true
        } else {
            transactionOverride = 0
            hasTransactionOverride = false
        }
        
        if let val = UsageLimitService.debugGetOverrideStatic(for: .receipts) {
            receiptOverride = val
            hasReceiptOverride = true
        } else {
            receiptOverride = 0
            hasReceiptOverride = false
        }
        
        if let val = UsageLimitService.debugGetOverrideStatic(for: .invoices) {
            invoiceOverride = val
            hasInvoiceOverride = true
        } else {
            invoiceOverride = 0
            hasInvoiceOverride = false
        }
    }
    
    /// Apply an override for a specific limit type
    private func applyOverride(for limitType: LimitType, count: Int) {
        UsageLimitService.debugSetOverrideStatic(for: limitType, count: count)
        HapticService.play(.selection)
        
        // Update local state
        switch limitType {
        case .transactions:
            hasTransactionOverride = true
        case .receipts:
            hasReceiptOverride = true
        case .invoices:
            hasInvoiceOverride = true
        default:
            break
        }
    }
    
    /// Apply a percentage preset to all applicable limits
    private func applyPreset(percentage: Double) {
        let tier = currentTier
        
        // Transactions
        if let limit = tier.transactionLimit {
            let value = Int(Double(limit) * percentage)
            transactionOverride = value
            UsageLimitService.debugSetOverrideStatic(for: .transactions, count: value)
            hasTransactionOverride = true
        }
        
        // Receipts
        if let limit = tier.receiptStorageLimit {
            let value = Int(Double(limit) * percentage)
            receiptOverride = value
            UsageLimitService.debugSetOverrideStatic(for: .receipts, count: value)
            hasReceiptOverride = true
        }
        
        // Invoices (only if limit > 0)
        if let limit = tier.invoiceLimit, limit > 0 {
            let value = Int(Double(limit) * percentage)
            invoiceOverride = value
            UsageLimitService.debugSetOverrideStatic(for: .invoices, count: value)
            hasInvoiceOverride = true
        }
        
        HapticService.play(.medium)
        
        let pctString = "\(Int(percentage * 100))%"
        statusMessage = "All limits set to \(pctString) of \(tier.displayName) tier"
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    /// Clear all usage count overrides
    private func clearAllOverrides() {
        UsageLimitService.debugClearAllOverridesStatic()
        
        transactionOverride = 0
        receiptOverride = 0
        invoiceOverride = 0
        hasTransactionOverride = false
        hasReceiptOverride = false
        hasInvoiceOverride = false
        
        HapticService.play(.success)
        statusMessage = "All usage overrides cleared"
        
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                statusMessage = nil
            }
        }
    }
    
    // MARK: - Helpers
    
    private func tierColor(_ tier: SubscriptionTier) -> Color {
        switch tier {
        case .free: return .secondary
        case .premium: return .blue
        case .pro: return .purple
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    DebugMenuView()
        .modelContainer(for: [
            Transaction.self,
            Category.self,
            Account.self
        ], inMemory: true)
}

#endif
