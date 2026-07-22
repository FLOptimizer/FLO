//  CSVFilePickerView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Dynamic Column Mapping Integration
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4:
//  ✅ FIXED: proceedToNextStep() now uses dynamic header-based column mapping
//  ✅ FIXED: Handles alternate CSV formats (e.g., Chase 16-column export) correctly
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Hero section title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Hero section description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Instructions header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InstructionRow title and description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Import button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Profile override section text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Detected bank name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Bank not recognized" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Choose Different Bank" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Supported Banks header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Supported Banks description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BankBadge profile name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BankProfilePickerSheet instruction text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BankProfileRow profile name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BankProfileRow "Auto-detected" label missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.2:
//  - Added screen announcement on appear
//  - Full VoiceOver accessibility coverage for all interactive elements
//  - Decorative icons hidden from VoiceOver
//  - Bank profile rows with selection state
//  - Error announcements for dynamic feedback
//
//  CHANGES v1.1:
//  - CRITICAL FIX: Now calls CSVParserService.parseTransactions() before navigating to review
//  - Added importResult state property to hold CSVImportResult
//  - Review view now receives properly parsed CSVImportResult instead of raw data
//  - Fixed proceedToNextStep() to parse transactions before navigation
//

import SwiftUI
import UniformTypeIdentifiers
import os.log

/// Entry point for CSV import flow
/// Presents file picker, detects bank profile, and routes to either column mapper or review
struct CSVFilePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingFilePicker = false
    @State private var showingProfilePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    // File processing state
    @State private var selectedFileURL: URL?
    @State private var rawRows: [CSVRawRow] = []
    @State private var detectedProfile: CSVBankProfile?
    @State private var selectedProfile: CSVBankProfile?
    @State private var importResult: CSVImportResult?
    
    // Navigation destinations
    @State private var showingColumnMapper = false
    @State private var showingReview = false
    @State private var showingUpgrade = false
    
    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CSVFilePickerView"
    )
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    heroSection

                    // Free-tier allowance status (all entry points funnel here)
                    if let remaining = CSVImportQuota.remaining(for: SubscriptionManager.shared.currentTier) {
                        allowanceBanner(remaining: remaining)
                    }

                    // Instructions
                    instructionsSection

                    // Import Button
                    importButton
                    
                    // Bank Profile Override (shown after file selected)
                    if !rawRows.isEmpty {
                        profileOverrideSection
                    }
                    
                    // Supported Banks
                    supportedBanksSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color.floSystemGroupedBackground)
            .navigationTitle("Import CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .sheet(isPresented: $showingProfilePicker) {
                BankProfilePickerSheet(
                    availableProfiles: CSVParserService.shared.allBankProfiles,
                    detectedProfile: detectedProfile,
                    onSelect: { profile in
                        selectedProfile = profile
                        showingProfilePicker = false
                        proceedToNextStep()
                    },
                    onCancel: {
                        showingProfilePicker = false
                    }
                )
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: errorMessage) { oldValue, newValue in
                if !newValue.isEmpty {
                    AccessibilityAnnouncement.announce("Error: \(newValue)")
                }
            }
            .navigationDestination(isPresented: $showingColumnMapper) {
                if let url = selectedFileURL {
                    CSVColumnMapperView(
                        fileURL: url,
                        rawRows: rawRows,
                        detectedProfile: detectedProfile
                    )
                }
            }
            .navigationDestination(isPresented: $showingReview) {
                if let result = importResult {
                    CSVImportReviewView(importResult: result)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Import Bank Statement")
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.arrow.up.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandPrimaryDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
            
            Text("Import Bank Statement")
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text("Import transactions from your bank's CSV export file")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How it works:")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            InstructionRow(
                number: 1,
                icon: "arrow.down.doc",
                title: "Download CSV from your bank",
                description: "Export your transaction history as a CSV file"
            )
            
            InstructionRow(
                number: 2,
                icon: "doc.viewfinder",
                title: "Select your file",
                description: "We'll automatically detect your bank's format"
            )
            
            InstructionRow(
                number: 3,
                icon: "checkmark.circle",
                title: "Review and import",
                description: "Verify transactions and assign categories"
            )
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Import Button
    
    private var importsExhausted: Bool {
        !CSVImportQuota.canImport(tier: SubscriptionManager.shared.currentTier)
    }

    @ViewBuilder
    private func allowanceBanner(remaining: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: remaining > 0 ? "info.circle.fill" : "lock.fill")
                .foregroundStyle(remaining > 0 ? Color.brandPrimary : .orange)
                .accessibilityHidden(true)
            if remaining > 0 {
                Text("\(remaining) of \(SubscriptionManager.shared.currentTier.csvImportLimit ?? 0) free imports remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Free imports used")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Try Premium Free") {
                    HapticService.play(.medium)
                    showingUpgrade = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
    }

    private var importButton: some View {
        Button {
            HapticService.play(.medium)
            if importsExhausted {
                showingUpgrade = true
            } else {
                showingFilePicker = true
            }
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                        .accessibilityLabel("Parsing CSV file")
                } else {
                    Image(systemName: "doc.badge.plus")
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text("Select CSV File")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.brandPrimary)
            .foregroundStyle(.white)
            .cornerRadius(10)
        }
        .disabled(isProcessing)
        .accessibilityLabel(importsExhausted ? "Free imports used. Upgrade for unlimited imports." : "Select CSV file to import")
        .accessibilityHint(importsExhausted ? "Double tap to view Premium subscription options" : "Opens file browser to choose a bank statement CSV file")
        .sheet(isPresented: $showingUpgrade) {
            SubscriptionView()
        }
    }
    
    // MARK: - Profile Override Section
    
    private var profileOverrideSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "building.columns")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text("Detected Bank")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            
            if let profile = detectedProfile {
                HStack {
                    Image(systemName: profile.icon)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(profile.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(Color.floTertiarySystemBackground)
                .cornerRadius(8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(profile.displayName), auto-detected")
            } else {
                HStack {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("Bank not recognized")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .padding()
                .background(Color.floTertiarySystemBackground)
                .cornerRadius(8)
                .accessibilityLabel("Bank not recognized")
            }
            
            Button {
                HapticService.play(.light)
                showingProfilePicker = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .accessibilityHidden(true)
                    Text("Choose Different Bank")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityLabel("Choose different bank profile")
            .accessibilityHint("Opens bank selection list")
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - Supported Banks Section
    
    private var supportedBanksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Banks")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("We automatically detect formats from these banks:")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(CSVParserService.shared.allBankProfiles.filter { !$0.displayName.contains("Generic") }, id: \.id) { profile in
                    BankBadge(profile: profile)
                }
            }
            
            Text("Don't see your bank? We support custom CSV formats too.")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(12)
    }
    
    // MARK: - File Processing
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            processFile(url)
            
        case .failure(let error):
            Self.logger.error("File picker error: \(error.localizedDescription)")
            errorMessage = "Failed to access file: \(error.localizedDescription)"
            showingError = true
            HapticService.play(.error)
        }
    }
    
    private func processFile(_ url: URL) {
        isProcessing = true
        selectedFileURL = url
        
        Task { @MainActor in
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file"
                showingError = true
                isProcessing = false
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Parse CSV file
            let parseResult = CSVParserService.shared.parseCSVFile(url: url, encoding: .utf8)
            
            switch parseResult {
            case .success(let rows):
                Self.logger.info("Successfully parsed CSV file: \(rows.count) rows")
                self.rawRows = rows
                
                // Attempt auto-detection
                if rows.count >= 2 {
                    let headers = rows.first?.fields ?? []
                    let sampleRows = Array(rows.prefix(10))
                    detectedProfile = CSVParserService.shared.detectBankProfile(
                        headers: headers,
                        sampleRows: sampleRows
                    )
                    
                    if let profile = detectedProfile {
                        Self.logger.info("Auto-detected bank profile: \(profile.displayName)")
                    } else {
                        Self.logger.warning("Could not auto-detect bank profile")
                    }
                }
                
                isProcessing = false
                HapticService.play(.success)
                
                // Auto-proceed if we have a detected profile
                if detectedProfile != nil {
                    proceedToNextStep()
                }
                
            case .failure(let error):
                Self.logger.error("CSV parsing failed: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                showingError = true
                isProcessing = false
                HapticService.play(.error)
            }
        }
    }
    
    private func proceedToNextStep() {
        let profile = selectedProfile ?? detectedProfile
        
        if let profile = profile {
            // We have a profile — resolve dynamic column mapping then parse
            Self.logger.info("Proceeding to review with profile: \(profile.displayName)")
            
            // Use dynamic header-based column mapping for better format handling
            let headers = rawRows.first?.fields ?? []
            let resolvedMapping = CSVParserService.shared.dynamicColumnMapping(
                headers: headers,
                profile: profile
            )
            
            // Parse raw rows into structured transactions
            let result = CSVParserService.shared.parseTransactions(
                rows: rawRows,
                mapping: resolvedMapping,
                profile: profile,
                categories: [],           // Review view has @Query for these
                merchantMappings: []      // Review view has @Query for these
            )
            
            self.importResult = result
            self.showingReview = true
        } else {
            // No profile — go to manual column mapper
            Self.logger.info("No profile detected — proceeding to manual column mapper")
            showingColumnMapper = true
        }
    }
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 40, height: 40)
                Text("\(number)")
                    .font(.headline.bold())
                    .lineLimit(1)
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                Text(description)
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct BankBadge: View {
    let profile: CSVBankProfile
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: profile.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(profile.displayName)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.floTertiarySystemBackground)
        .cornerRadius(8)
    }
}

// MARK: - Bank Profile Picker Sheet

struct BankProfilePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let availableProfiles: [CSVBankProfile]
    let detectedProfile: CSVBankProfile?
    let onSelect: (CSVBankProfile) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select the bank that matches your CSV file format")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                Section("Detected") {
                    if let detected = detectedProfile {
                        BankProfileRow(
                            profile: detected,
                            isDetected: true,
                            isSelected: false
                        ) {
                            HapticService.play(.light)
                            onSelect(detected)
                        }
                    } else {
                        Text("No bank detected automatically")
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("All Banks") {
                    ForEach(availableProfiles, id: \.id) { profile in
                        BankProfileRow(
                            profile: profile,
                            isDetected: profile.id == detectedProfile?.id,
                            isSelected: false
                        ) {
                            HapticService.play(.light)
                            onSelect(profile)
                        }
                    }
                }
            }
            .navigationTitle("Choose Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        onCancel()
                    }
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Choose Bank")
            }
        }
    }
}

struct BankProfileRow: View {
    let profile: CSVBankProfile
    let isDetected: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: profile.icon)
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName)
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                    
                    if isDetected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text("Auto-detected")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.displayName)\(isDetected ? ", auto-detected" : "")\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Double tap to select this bank profile")
    }
}

// MARK: - Preview

#Preview {
    CSVFilePickerView()
}
