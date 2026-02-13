//  ReceiptExportService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Initial Implementation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Export receipts to ZIP (images) and CSV (data) for:
//  - Upside, Fetch, and other receipt cashback apps
//  - Tax filing and accountants
//  - Personal backup before purging
//
//  FEATURES:
//  ✅ Export images as ZIP file
//  ✅ Export data as CSV spreadsheet
//  ✅ Filter by business/personal
//  ✅ Filter by date range (month/year)
//  ✅ Descriptive filenames for organization
//  ✅ Progress tracking for large exports
//  ✅ Share sheet integration ready
//

import Foundation
import UIKit
import SwiftData

// MARK: - Export Options

struct ReceiptExportOptions {
    var includeImages: Bool = true
    var includeCSV: Bool = true
    var filterType: FilterType = .all
    var year: Int? = nil
    var month: Int? = nil
    
    enum FilterType: String, CaseIterable {
        case all = "All Receipts"
        case businessOnly = "Business Only"
        case personalOnly = "Personal Only"
    }
    
    var exportName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        var name = "FLO_Receipts"
        
        // Add filter suffix
        if filterType == .businessOnly {
            name += "_Business"
        } else if filterType == .personalOnly {
            name += "_Personal"
        }
        
        // Add date suffix
        if let year = year, let month = month {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            if let monthDate = Calendar.current.date(from: DateComponents(year: year, month: month)) {
                name += "_\(monthFormatter.string(from: monthDate))_\(year)"
            }
        } else if let year = year {
            name += "_\(year)"
        }
        
        name += "_\(today)"
        return name
    }
}

// MARK: - Export Result

struct ReceiptExportResult {
    let zipURL: URL?
    let csvURL: URL?
    let receiptCount: Int
    let imageCount: Int
    let totalSize: Int64
    let errors: [String]
    
    var isSuccess: Bool {
        (zipURL != nil || csvURL != nil) && receiptCount > 0
    }
    
    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    /// All URLs to share (ZIP and/or CSV)
    var shareableURLs: [URL] {
        var urls: [URL] = []
        if let zip = zipURL { urls.append(zip) }
        if let csv = csvURL { urls.append(csv) }
        return urls
    }
}

// MARK: - Receipt Export Service

@MainActor
class ReceiptExportService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ReceiptExportService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isExporting: Bool = false
    @Published private(set) var exportProgress: Double = 0.0
    @Published private(set) var currentStatus: String = ""
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    
    private var exportDirectory: URL {
        fileManager.temporaryDirectory.appendingPathComponent("FLO_Exports", isDirectory: true)
    }
    
    private init() {
        // Ensure export directory exists
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Main Export Function
    
    /// Export receipts to ZIP and/or CSV based on options
    func exportReceipts(
        receipts: [ReceiptData],
        options: ReceiptExportOptions
    ) async -> ReceiptExportResult {
        isExporting = true
        exportProgress = 0.0
        currentStatus = "Preparing export..."
        
        // Filter receipts
        let filtered = filterReceipts(receipts, options: options)
        
        guard !filtered.isEmpty else {
            isExporting = false
            return ReceiptExportResult(
                zipURL: nil, csvURL: nil,
                receiptCount: 0, imageCount: 0, totalSize: 0,
                errors: ["No receipts match the selected criteria"]
            )
        }
        
        currentStatus = "Found \(filtered.count) receipts"
        exportProgress = 0.1
        
        // Clean up old exports
        cleanupOldExports()
        
        var zipURL: URL? = nil
        var csvURL: URL? = nil
        var imageCount = 0
        var totalSize: Int64 = 0
        var errors: [String] = []
        
        // Export ZIP with images
        if options.includeImages {
            currentStatus = "Creating image archive..."
            
            let zipResult = await createZipArchive(
                receipts: filtered,
                name: options.exportName
            )
            
            zipURL = zipResult.url
            imageCount = zipResult.imageCount
            totalSize += zipResult.size
            errors.append(contentsOf: zipResult.errors)
        }
        
        // Export CSV
        if options.includeCSV {
            currentStatus = "Creating spreadsheet..."
            exportProgress = 0.85
            
            let csvResult = createCSV(
                receipts: filtered,
                name: options.exportName
            )
            
            csvURL = csvResult.url
            totalSize += csvResult.size
            if let error = csvResult.error {
                errors.append(error)
            }
        }
        
        exportProgress = 1.0
        currentStatus = "Export complete!"
        isExporting = false
        
        HapticService.play(.success)
        
        #if DEBUG
        print("📦 Export Complete:")
        print("   Receipts: \(filtered.count)")
        print("   Images: \(imageCount)")
        print("   Size: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
        #endif
        
        return ReceiptExportResult(
            zipURL: zipURL,
            csvURL: csvURL,
            receiptCount: filtered.count,
            imageCount: imageCount,
            totalSize: totalSize,
            errors: errors
        )
    }
    
    // MARK: - Quick Export Helpers
    
    /// Export a specific month's receipts
    func exportMonth(
        year: Int,
        month: Int,
        receipts: [ReceiptData],
        businessOnly: Bool = false
    ) async -> ReceiptExportResult {
        var options = ReceiptExportOptions()
        options.year = year
        options.month = month
        options.filterType = businessOnly ? .businessOnly : .all
        
        return await exportReceipts(receipts: receipts, options: options)
    }
    
    /// Export a specific year's receipts
    func exportYear(
        year: Int,
        receipts: [ReceiptData],
        businessOnly: Bool = false
    ) async -> ReceiptExportResult {
        var options = ReceiptExportOptions()
        options.year = year
        options.filterType = businessOnly ? .businessOnly : .all
        
        return await exportReceipts(receipts: receipts, options: options)
    }
    
    /// Export all business receipts (for tax filing)
    func exportBusinessReceipts(
        receipts: [ReceiptData],
        year: Int? = nil
    ) async -> ReceiptExportResult {
        var options = ReceiptExportOptions()
        options.filterType = .businessOnly
        options.year = year
        
        return await exportReceipts(receipts: receipts, options: options)
    }
    
    // MARK: - Filter Receipts
    
    private func filterReceipts(_ receipts: [ReceiptData], options: ReceiptExportOptions) -> [ReceiptData] {
        var filtered = receipts
        let calendar = Calendar.current
        
        // Filter by business/personal
        switch options.filterType {
        case .businessOnly:
            filtered = filtered.filter { $0.businessPercentage >= 50 }
        case .personalOnly:
            filtered = filtered.filter { $0.businessPercentage < 50 }
        case .all:
            break
        }
        
        // Filter by year
        if let year = options.year {
            filtered = filtered.filter { receipt in
                calendar.component(.year, from: receipt.date) == year
            }
        }
        
        // Filter by month
        if let month = options.month {
            filtered = filtered.filter { receipt in
                calendar.component(.month, from: receipt.date) == month
            }
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    // MARK: - Create ZIP Archive
    
    private func createZipArchive(
        receipts: [ReceiptData],
        name: String
    ) async -> (url: URL?, imageCount: Int, size: Int64, errors: [String]) {
        let zipURL = exportDirectory.appendingPathComponent("\(name).zip")
        
        // Remove existing file
        try? fileManager.removeItem(at: zipURL)
        
        var errors: [String] = []
        var imageCount = 0
        
        // Create temp directory for images
        let tempDir = exportDirectory.appendingPathComponent("temp_\(UUID().uuidString)", isDirectory: true)
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Export each receipt image
        for (index, receipt) in receipts.enumerated() {
            let progress = 0.1 + (0.7 * Double(index) / Double(receipts.count))
            exportProgress = progress
            currentStatus = "Exporting image \(index + 1) of \(receipts.count)"
            
            // Generate filename
            let filename = generateImageFilename(for: receipt, index: index)
            let destURL = tempDir.appendingPathComponent(filename)
            
            // Load image
            if let image = await loadReceiptImage(receipt) {
                if let jpegData = image.jpegData(compressionQuality: 0.85) {
                    do {
                        try jpegData.write(to: destURL)
                        imageCount += 1
                    } catch {
                        errors.append("Failed to save \(receipt.merchantName)")
                    }
                }
            }
        }
        
        guard imageCount > 0 else {
            try? fileManager.removeItem(at: tempDir)
            return (nil, 0, 0, ["No images to export"])
        }
        
        // Create ZIP using NSFileCoordinator
        currentStatus = "Compressing \(imageCount) images..."
        exportProgress = 0.8
        
        do {
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?
            var finalURL: URL?
            
            coordinator.coordinate(readingItemAt: tempDir, options: .forUploading, error: &coordinatorError) { tempZipURL in
                do {
                    try self.fileManager.copyItem(at: tempZipURL, to: zipURL)
                    finalURL = zipURL
                } catch {
                    errors.append("Failed to create ZIP: \(error.localizedDescription)")
                }
            }
            
            if let error = coordinatorError {
                errors.append("Compression error: \(error.localizedDescription)")
            }
            
            // Cleanup temp directory
            try? fileManager.removeItem(at: tempDir)
            
            // Get file size
            if let url = finalURL {
                let attrs = try fileManager.attributesOfItem(atPath: url.path)
                let size = attrs[.size] as? Int64 ?? 0
                return (url, imageCount, size, errors)
            }
            
            return (nil, imageCount, 0, errors)
            
        } catch {
            try? fileManager.removeItem(at: tempDir)
            errors.append("Export failed: \(error.localizedDescription)")
            return (nil, 0, 0, errors)
        }
    }
    
    // MARK: - Create CSV
    
    private func createCSV(
        receipts: [ReceiptData],
        name: String
    ) -> (url: URL?, size: Int64, error: String?) {
        let csvURL = exportDirectory.appendingPathComponent("\(name).csv")
        
        try? fileManager.removeItem(at: csvURL)
        
        // CSV Header
        var csv = "Date,Merchant,Amount,Category,Type,Tax Deductible,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Add rows
        for receipt in receipts {
            let date = dateFormatter.string(from: receipt.date)
            let merchant = escapeCSV(receipt.merchantName)
            let amount = String(format: "%.2f", receipt.totalAmount)
            let category = escapeCSV(receipt.suggestedCategoryName ?? "Uncategorized")
            let type = receipt.businessPercentage >= 50 ? "Business" : "Personal"
            let taxDeductible = receipt.isTaxDeductible ? "Yes" : "No"
            let notes = escapeCSV(receipt.notes ?? "")
            
            csv += "\(date),\(merchant),\(amount),\(category),\(type),\(taxDeductible),\(notes)\n"
        }
        
        // Write file
        do {
            try csv.write(to: csvURL, atomically: true, encoding: .utf8)
            
            let attrs = try fileManager.attributesOfItem(atPath: csvURL.path)
            let size = attrs[.size] as? Int64 ?? 0
            
            return (csvURL, size, nil)
        } catch {
            return (nil, 0, "Failed to create CSV: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func generateImageFilename(for receipt: ReceiptData, index: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: receipt.date)
        
        // Clean merchant name
        let merchant = receipt.merchantName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .prefix(25)
        
        let amount = String(format: "%.2f", receipt.totalAmount)
            .replacingOccurrences(of: ".", with: "_")
        
        return "\(dateStr)_\(merchant)_$\(amount).jpg"
    }
    
    private func escapeCSV(_ string: String) -> String {
        var result = string
        if result.contains(",") || result.contains("\"") || result.contains("\n") {
            result = result.replacingOccurrences(of: "\"", with: "\"\"")
            result = "\"\(result)\""
        }
        return result
    }
    
    private func loadReceiptImage(_ receipt: ReceiptData) async -> UIImage? {
        // Try file storage
        if let filename = receipt.imageURL, !filename.isEmpty {
            return try? await PhotoStorageManager.shared.loadReceipt(filename: filename)
        }
        
        // Fallback to embedded
        if let data = receipt.imageData {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    private func cleanupOldExports() {
        let cutoff = Date().addingTimeInterval(-3600) // 1 hour
        
        guard let files = try? fileManager.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for file in files {
            if let attrs = try? file.resourceValues(forKeys: [.creationDateKey]),
               let created = attrs.creationDate,
               created < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    /// Clear all exports (manual cleanup)
    func clearAllExports() {
        try? fileManager.removeItem(at: exportDirectory)
        try? fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Usage Examples

/*
 // === EXPORT BUSINESS RECEIPTS FOR 2024 TAX FILING ===
 
 let result = await ReceiptExportService.shared.exportBusinessReceipts(
     receipts: allReceipts,
     year: 2024
 )
 
 if result.isSuccess {
     // Present share sheet with result.shareableURLs
 }
 
 // === EXPORT JANUARY 2025 ===
 
 let result = await ReceiptExportService.shared.exportMonth(
     year: 2025,
     month: 1,
     receipts: allReceipts,
     businessOnly: false
 )
 
 // === CUSTOM EXPORT ===
 
 var options = ReceiptExportOptions()
 options.filterType = .businessOnly
 options.includeImages = true
 options.includeCSV = true
 options.year = 2024
 
 let result = await ReceiptExportService.shared.exportReceipts(
     receipts: allReceipts,
     options: options
 )
 */
