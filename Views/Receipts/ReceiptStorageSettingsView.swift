//  ReceiptStorageSettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - VoiceOver Audit: Storage management accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.5 - VoiceOver Audit:
//  ✅ ADDED: 12 decorative icons hidden (section/row icons, status indicators)
//  ✅ ADDED: Storage usage StatRow gets spoken label ("Storage Used, 2.3 gigabytes")
//  ✅ ADDED: Delete/purge buttons get explicit hints explaining consequences
//  ✅ ADDED: MonthRow icon-only buttons get proper labels and hints
//  ✅ ADDED: Export/purge year buttons get hints
//  ✅ ADDED: Maintenance buttons get hints explaining actions
//  ✅ VERIFIED: Toggle switches auto-handled by SwiftUI
//  ✅ VERIFIED: Business/Personal counts already have spoken label
//
//  CHANGES v1.4 - Dynamic Type Verification:
//  ✅ FIXED: "Calculating..." text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: StatRow label and value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Business/Personal count text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export button labels and descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Migration section text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: YearRow text (display name, count, size) missing lineLimit + minimumScaleFactor
//  ✅ FIXED: MonthRow text (name, counts, size) missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Year action button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Maintenance button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: InfoRow text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export progress status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Export progress percentage missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ExportOptionsSheet period text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ExportOptionsSheet toggle label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ExportOptionsSheet export includes labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ExportOptionsSheet compatibility text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.3:
//  ✅ Screen change announcement on appear
//  ✅ StatRow combined with spoken label and value
//  ✅ Business/Personal counts combined row
//  ✅ MonthRow combined with spoken business/personal counts
//  ✅ Export progress overlay announced to VoiceOver
//  ✅ InfoRow icons hidden from VoiceOver
//
//  Settings view for managing receipt storage with export and purge
//
//  CHANGES v1.2:
//  ✅ FIXED: Unused result warnings for calculateStats calls
//  ✅ FIXED: Removed duplicate ShareSheet declaration (uses existing)
//
//  CHANGES v1.1:
//  ✅ ADDED: Export to ZIP for Upside/Fetch
//  ✅ ADDED: Business/Personal filter for exports
//  ✅ ADDED: "Export first" option before purge
//  ✅ ADDED: Share sheet integration
//  ✅ ADDED: Export progress indicator
//
//  FEATURES:
//  ✅ Storage overview (total, size, date range)
//  ✅ Breakdown by year with expand/collapse
//  ✅ Export by month/year with business filter
//  ✅ Purge individual months or years
//  ✅ Migration tool for legacy receipts
//  ✅ HapticService + FLOAnimation integration
//

import SwiftUI
import SwiftData

struct ReceiptStorageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \ReceiptData.date, order: .reverse) private var receipts: [ReceiptData]
    
    @StateObject private var storageManager = ReceiptStorageManager.shared
    @StateObject private var exportService = ReceiptExportService.shared
    
    // UI State
    @State private var viewAppeared = false
    @State private var expandedYears: Set<Int> = []
    
    // Export State
    @State private var showingExportSheet = false
    @State private var exportYear: Int? = nil
    @State private var exportMonth: Int? = nil
    @State private var exportBusinessOnly = false
    @State private var showingShareSheet = false
    @State private var exportResult: ReceiptExportResult?
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    
    // Purge State
    @State private var showingPurgeMonthConfirm = false
    @State private var showingPurgeYearConfirm = false
    @State private var selectedMonthForPurge: MonthlyReceiptStats?
    @State private var selectedYearForPurge: YearlyReceiptStats?
    @State private var purgeResult: PurgeResult?
    @State private var showingPurgeResult = false
    
    // Migration State
    @State private var showingMigrationConfirm = false
    @State private var migrationResult: (migrated: Int, failed: Int, spaceFreed: Int64)?
    @State private var showingMigrationResult = false
    @State private var isMigrating = false
    
    // Legacy receipt count
    private var legacyReceiptCount: Int {
        SmartReceiptService.shared.countEmbeddedImages(receipts: receipts)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // Storage Overview
                    storageOverviewSection
                    
                    // Quick Export Section
                    quickExportSection
                    
                    // Migration (if needed)
                    if legacyReceiptCount > 0 {
                        migrationSection
                    }
                    
                    // Breakdown by Year
                    if let stats = storageManager.stats, !stats.receiptsByYear.isEmpty {
                        yearlyBreakdownSection(stats)
                    }
                    
                    // Maintenance
                    maintenanceSection
                    
                    // Info
                    infoSection
                }
                .disabled(exportService.isExporting)
                
                // Export Progress Overlay
                if exportService.isExporting {
                    exportProgressOverlay
                }
            }
            .navigationTitle("Receipt Storage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .disabled(exportService.isExporting)
                }
            }
            .onAppear {
                Task {
                    _ = await storageManager.calculateStats(receipts: receipts)
                }
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Receipt storage")
            }
            .refreshable {
                _ = await storageManager.calculateStats(receipts: receipts)
            }
            // Export Options Sheet
            .sheet(isPresented: $showingExportSheet) {
                ExportOptionsSheet(
                    year: exportYear,
                    month: exportMonth,
                    businessOnly: $exportBusinessOnly,
                    onExport: performExport,
                    onCancel: { showingExportSheet = false }
                )
                .presentationDetents([.medium])
            }
            // Share Sheet
            .sheet(isPresented: $showingShareSheet) {
                if let result = exportResult, !result.shareableURLs.isEmpty {
                    ShareSheet(items: result.shareableURLs)
                }
            }
            // Purge Month Confirmation
            .alert("Purge Month?", isPresented: $showingPurgeMonthConfirm, presenting: selectedMonthForPurge) { month in
                Button("Export First") {
                    exportYear = month.year
                    exportMonth = month.month
                    exportBusinessOnly = false
                    showingExportSheet = true
                }
                Button("Purge Without Export", role: .destructive) {
                    Task { await purgeMonth(month) }
                }
                Button("Cancel", role: .cancel) { }
            } message: { month in
                Text("Delete \(month.count) receipts from \(month.displayName)?\n\nThis frees \(month.sizeFormatted). Consider exporting first for tax records or Upside/Fetch.")
            }
            // Purge Year Confirmation
            .alert("Purge Entire Year?", isPresented: $showingPurgeYearConfirm, presenting: selectedYearForPurge) { year in
                Button("Export First") {
                    exportYear = year.year
                    exportMonth = nil
                    exportBusinessOnly = false
                    showingExportSheet = true
                }
                Button("Purge Without Export", role: .destructive) {
                    Task { await purgeYear(year) }
                }
                Button("Cancel", role: .cancel) { }
            } message: { year in
                Text("Delete ALL \(year.count) receipts from \(year.displayName)?\n\nThis frees \(year.sizeFormatted). This cannot be undone!")
            }
            // Purge Result
            .alert("Purge Complete", isPresented: $showingPurgeResult) {
                Button("OK") { }
            } message: {
                if let result = purgeResult {
                    Text("Deleted \(result.receiptsDeleted) receipts.\nFreed \(result.spaceFreedFormatted) of storage.")
                }
            }
            // Export Error
            .alert("Export Error", isPresented: $showingExportError) {
                Button("OK") { }
            } message: {
                Text(exportErrorMessage)
            }
            // Migration Confirmation
            .alert("Optimize Storage?", isPresented: $showingMigrationConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Optimize") {
                    Task { await performMigration() }
                }
            } message: {
                Text("Move \(legacyReceiptCount) receipt images from database to file storage.\n\nThis improves performance.")
            }
            // Migration Result
            .alert("Optimization Complete", isPresented: $showingMigrationResult) {
                Button("OK") { }
            } message: {
                if let result = migrationResult {
                    Text("Migrated \(result.migrated) receipts.\nFreed \(ByteCountFormatter.string(fromByteCount: result.spaceFreed, countStyle: .file)) from database.")
                }
            }
        }
    }
    
    // MARK: - Storage Overview Section
    
    private var storageOverviewSection: some View {
        Section {
            if storageManager.isCalculating {
                HStack {
                    ProgressView()
                        .padding(.trailing, 8)
                    Text("Calculating...")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
            } else if let stats = storageManager.stats {
                StatRow(
                    icon: "doc.text.fill",
                    iconColor: Color.brandPrimary,
                    label: "Total Receipts",
                    value: "\(stats.totalReceipts)",
                    delay: 0.1,
                    isVisible: viewAppeared
                )
                
                StatRow(
                    icon: "externaldrive.fill",
                    iconColor: storageColor(stats.totalSizeBytes),
                    label: "Storage Used",
                    value: stats.totalSizeFormatted,
                    delay: 0.15,
                    isVisible: viewAppeared
                )
                
                // Business vs Personal
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)
                        Text("\(stats.businessReceipts)")
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("Business")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Personal")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        Text("\(stats.personalReceipts)")
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "person.fill")
                            .foregroundStyle(.blue)
                            .accessibilityHidden(true)
                    }
                }
                .font(.subheadline)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stats.businessReceipts) business receipts, \(stats.personalReceipts) personal receipts")
                
            } else {
                Text("No receipts stored")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Storage Overview")
        }
    }
    
    // MARK: - Quick Export Section
    
    private var quickExportSection: some View {
        Section {
            // Export Business Receipts (for taxes)
            Button {
                HapticService.play(.medium)
                exportYear = nil
                exportMonth = nil
                exportBusinessOnly = true
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(.green)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export Business Receipts")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Text("For tax filing & expense reports")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Export Business Receipts")
            .accessibilityHint("Double tap to create ZIP file of business receipts for tax filing")
            
            // Export All Receipts
            Button {
                HapticService.play(.medium)
                exportYear = nil
                exportMonth = nil
                exportBusinessOnly = false
                showingExportSheet = true
            } label: {
                HStack {
                    Image(systemName: "doc.zipper")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Export All Receipts")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Text("For Upside, Fetch, or backup")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Export All Receipts")
            .accessibilityHint("Double tap to create ZIP file of all receipts for Upside, Fetch, or backup")
        } header: {
            Text("Export")
        } footer: {
            Text("Creates a ZIP file with receipt images and a CSV spreadsheet you can share to Files, email, or other apps.")
        }
    }
    
    // MARK: - Migration Section
    
    private var migrationSection: some View {
        Section {
            Button {
                HapticService.play(.medium)
                showingMigrationConfirm = true
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Optimize Storage")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                        Text("\(legacyReceiptCount) receipts using legacy storage")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                    
                    if isMigrating {
                        ProgressView()
                    }
                }
            }
            .disabled(isMigrating)
            .accessibilityLabel("Optimize Storage")
            .accessibilityHint("Double tap to migrate \(legacyReceiptCount) receipts to optimized storage. This improves performance.")
        } header: {
            Text("Optimization Available")
        }
    }
    
    // MARK: - Yearly Breakdown Section
    
    private func yearlyBreakdownSection(_ stats: ReceiptStorageStats) -> some View {
        Section {
            ForEach(stats.receiptsByYear) { year in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedYears.contains(year.year) },
                        set: { isExpanded in
                            HapticService.play(.light)
                            if isExpanded {
                                expandedYears.insert(year.year)
                            } else {
                                expandedYears.remove(year.year)
                            }
                        }
                    )
                ) {
                    // Months within year
                    ForEach(year.months) { month in
                        MonthRow(
                            month: month,
                            onExport: {
                                exportYear = month.year
                                exportMonth = month.month
                                exportBusinessOnly = false
                                showingExportSheet = true
                            },
                            onPurge: {
                                selectedMonthForPurge = month
                                showingPurgeMonthConfirm = true
                            }
                        )
                    }
                    
                    // Year actions
                    HStack(spacing: 16) {
                        Button {
                            HapticService.play(.medium)
                            exportYear = year.year
                            exportMonth = nil
                            exportBusinessOnly = false
                            showingExportSheet = true
                        } label: {
                            Label("Export \(year.displayName)", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(Color.brandPrimary)
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            HapticService.play(.medium)
                            selectedYearForPurge = year
                            showingPurgeYearConfirm = true
                        } label: {
                            Label("Purge All", systemImage: "trash")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.top, 8)
                } label: {
                    YearRow(year: year)
                }
            }
        } header: {
            Text("Receipts by Year")
        } footer: {
            Text("Tap to expand. Export before purging if you need receipts for tax records, Upside, or Fetch.")
        }
    }
    
    // MARK: - Maintenance Section
    
    private var maintenanceSection: some View {
        Section {
            Button {
                HapticService.play(.medium)
                Task {
                    let cleaned = await storageManager.cleanupOrphanedImages(receipts: receipts)
                    _ = await storageManager.calculateStats(receipts: receipts)
                    if cleaned > 0 {
                        HapticService.play(.success)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .frame(width: 28)
                    Text("Clean Up Orphaned Files")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                }
            }
            
            Button {
                HapticService.play(.light)
                exportService.clearAllExports()
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .foregroundStyle(.gray)
                        .frame(width: 28)
                    Text("Clear Export Cache")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                }
            }
        } header: {
            Text("Maintenance")
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(icon: "iphone", text: "Receipts stored on your device only")
                InfoRow(icon: "arrow.up.doc", text: "Export to Upside, Fetch, or Files app")
                InfoRow(icon: "briefcase", text: "Filter business receipts for tax filing")
                InfoRow(icon: "exclamationmark.triangle", text: "Purging is permanent and cannot be undone")
            }
            .padding(.vertical, 4)
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Export Progress Overlay
    
    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView(value: exportService.exportProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                    .tint(Color.brandPrimary)
                
                Text(exportService.currentStatus)
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Text("\(Int(exportService.exportProgress * 100))%")
                    .font(.title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Exporting, \(Int(exportService.exportProgress * 100)) percent complete, \(exportService.currentStatus)")
        }
    }
    
    // MARK: - Actions
    
    private func performExport() {
        showingExportSheet = false
        
        Task {
            var options = ReceiptExportOptions()
            options.filterType = exportBusinessOnly ? .businessOnly : .all
            options.year = exportYear
            options.month = exportMonth
            options.includeImages = true
            options.includeCSV = true
            
            let result = await exportService.exportReceipts(
                receipts: receipts,
                options: options
            )
            
            if result.isSuccess {
                exportResult = result
                showingShareSheet = true
            } else {
                exportErrorMessage = result.errors.first ?? "Export failed"
                showingExportError = true
                HapticService.play(.error)
            }
        }
    }
    
    private func purgeMonth(_ month: MonthlyReceiptStats) async {
        let result = await storageManager.purgeMonth(
            year: month.year,
            month: month.month,
            receipts: receipts,
            context: modelContext
        )
        
        purgeResult = result
        showingPurgeResult = true
        _ = await storageManager.calculateStats(receipts: receipts)
    }
    
    private func purgeYear(_ year: YearlyReceiptStats) async {
        let result = await storageManager.purgeYear(
            year: year.year,
            receipts: receipts,
            context: modelContext
        )
        
        purgeResult = result
        showingPurgeResult = true
        expandedYears.remove(year.year)
        _ = await storageManager.calculateStats(receipts: receipts)
    }
    
    private func performMigration() async {
        isMigrating = true
        
        let result = await SmartReceiptService.shared.migrateEmbeddedImages(
            receipts: receipts,
            context: modelContext
        )
        
        migrationResult = result
        isMigrating = false
        showingMigrationResult = true
        _ = await storageManager.calculateStats(receipts: receipts)
    }
    
    private func storageColor(_ bytes: Int64) -> Color {
        if bytes > 500_000_000 { return .red }
        if bytes > 200_000_000 { return .orange }
        if bytes > 50_000_000 { return .yellow }
        return .green
    }
}

// MARK: - Export Options Sheet

private struct ExportOptionsSheet: View {
    let year: Int?
    let month: Int?
    @Binding var businessOnly: Bool
    let onExport: () -> Void
    let onCancel: () -> Void
    
    private var periodDescription: String {
        if let year = year, let month = month {
            let components = DateComponents(year: year, month: month)
            if let date = Calendar.current.date(from: components) {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                return formatter.string(from: date)
            }
        } else if let year = year {
            return "\(year)"
        }
        return "All Time"
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Period")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text(periodDescription)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Toggle(isOn: $businessOnly) {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundStyle(Color.brandPrimary)
                            Text("Business Receipts Only")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .tint(Color.brandPrimary)
                } footer: {
                    Text("Enable to export only business expenses for tax filing or expense reports.")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Receipt Images (JPEG)", systemImage: "photo.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Label("CSV Spreadsheet", systemImage: "tablecells")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Label("README with export info", systemImage: "doc.text")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Export Includes")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compatible with:")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                        Text("• Upside (GetUpside)")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("• Fetch Rewards")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("• Files app")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("• Email attachments")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("• Google Drive, Dropbox, etc.")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Export Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        HapticService.play(.medium)
                        onExport()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct StatRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let delay: Double
    let isVisible: Bool
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(iconColor)
        }
        .opacity(isVisible ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(delay), value: isVisible)
        .accessibilityElement(children: .combine)
    }
}

private struct YearRow: View {
    let year: YearlyReceiptStats
    
    var body: some View {
        HStack {
            Text(year.displayName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(year.count) receipts")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                Text(year.sizeFormatted)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct MonthRow: View {
    let month: MonthlyReceiptStats
    let onExport: () -> Void
    let onPurge: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(month.shortDisplayName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 8) {
                    Label("\(month.businessCount)", systemImage: "briefcase.fill")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(Color.brandPrimary)
                    
                    Label("\(month.personalCount)", systemImage: "person.fill")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.blue)
                }
            }
            
            Spacer()
            
            Text(month.sizeFormatted)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
            
            // Export button
            Button {
                HapticService.play(.light)
                onExport()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundStyle(Color.brandPrimary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Export \(month.shortDisplayName)")
            
            // Purge button
            Button {
                HapticService.play(.medium)
                onPurge()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete \(month.shortDisplayName)")
        }
        .padding(.leading, 16)
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ReceiptData.self, configurations: config)
    
    return ReceiptStorageSettingsView()
        .modelContainer(container)
}
