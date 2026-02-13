//  ReceiptStorageManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Initial Implementation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Manages receipt storage statistics and granular purging
//  Supports purge by month OR year independently
//
//  FEATURES:
//  ✅ Storage statistics (count, size, by month/year)
//  ✅ Purge by specific month (e.g., January 2025)
//  ✅ Purge by year (e.g., all of 2024)
//  ✅ Purge by date range
//  ✅ Export data retrieval before purging
//  ✅ Business/Personal receipt tracking
//  ✅ Orphaned image cleanup
//  ✅ HapticService integration
//

import Foundation
import SwiftData
import UIKit

// MARK: - Storage Statistics Models

/// Overall storage statistics
struct ReceiptStorageStats {
    let totalReceipts: Int
    let totalSizeBytes: Int64
    let businessReceipts: Int
    let personalReceipts: Int
    let receiptsByMonth: [MonthlyReceiptStats]
    let receiptsByYear: [YearlyReceiptStats]
    let oldestReceiptDate: Date?
    let newestReceiptDate: Date?
    
    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }
    
    var averageSizePerReceipt: String {
        guard totalReceipts > 0 else { return "0 KB" }
        let avgBytes = totalSizeBytes / Int64(totalReceipts)
        return ByteCountFormatter.string(fromByteCount: avgBytes, countStyle: .file)
    }
    
    var yearsAvailable: [Int] {
        receiptsByYear.map { $0.year }.sorted(by: >)
    }
}

/// Statistics for a single month
struct MonthlyReceiptStats: Identifiable, Hashable {
    let id: String  // Format: "2025-01"
    let year: Int
    let month: Int
    let count: Int
    let sizeBytes: Int64
    let businessCount: Int
    let personalCount: Int
    
    var displayName: String {
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return "\(month)/\(year)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    var shortDisplayName: String {
        let dateComponents = DateComponents(year: year, month: month)
        guard let date = Calendar.current.date(from: dateComponents) else {
            return "\(month)/\(year)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MonthlyReceiptStats, rhs: MonthlyReceiptStats) -> Bool {
        lhs.id == rhs.id
    }
}

/// Statistics for a single year
struct YearlyReceiptStats: Identifiable, Hashable {
    let id: Int  // Year
    let year: Int
    let count: Int
    let sizeBytes: Int64
    let businessCount: Int
    let personalCount: Int
    let months: [MonthlyReceiptStats]
    
    var displayName: String {
        "\(year)"
    }
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: YearlyReceiptStats, rhs: YearlyReceiptStats) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Purge Result

struct PurgeResult {
    let receiptsDeleted: Int
    let imagesDeleted: Int
    let spaceFreed: Int64
    let errors: [String]
    
    var spaceFreedFormatted: String {
        ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file)
    }
    
    var isSuccess: Bool {
        errors.isEmpty && receiptsDeleted > 0
    }
}

// MARK: - Export Data (for pre-purge backup)

struct ReceiptExportItem: Identifiable {
    let id: UUID
    let merchantName: String
    let amount: Double
    let date: Date
    let categoryName: String?
    let isBusinessExpense: Bool
    let imageFilename: String?
    let image: UIImage?
    
    var amountFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Receipt Storage Manager

@MainActor
class ReceiptStorageManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ReceiptStorageManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var stats: ReceiptStorageStats?
    @Published private(set) var isCalculating: Bool = false
    @Published private(set) var isPurging: Bool = false
    
    private init() {}
    
    // MARK: - Calculate Statistics
    
    /// Calculate comprehensive storage statistics from receipts
    func calculateStats(receipts: [ReceiptData]) async -> ReceiptStorageStats {
        isCalculating = true
        
        // Get file storage size from PhotoStorageManager
        let fileStorageSize = await PhotoStorageManager.shared.totalStorageUsed()
        
        // Calculate embedded image sizes (legacy)
        var embeddedSize: Int64 = 0
        var oldestDate: Date?
        var newestDate: Date?
        
        // Group by month
        var monthlyData: [String: (count: Int, size: Int64, business: Int, personal: Int, year: Int, month: Int)] = [:]
        
        let calendar = Calendar.current
        
        for receipt in receipts {
            // Track date range
            if oldestDate == nil || receipt.date < oldestDate! {
                oldestDate = receipt.date
            }
            if newestDate == nil || receipt.date > newestDate! {
                newestDate = receipt.date
            }
            
            // Calculate size
            var receiptSize: Int64 = 0
            if let imageData = receipt.imageData {
                receiptSize = Int64(imageData.count)
                embeddedSize += receiptSize
            } else if receipt.imageURL != nil {
                // Estimate ~400KB per external file
                receiptSize = 400_000
            }
            
            // Group by month
            let components = calendar.dateComponents([.year, .month], from: receipt.date)
            guard let year = components.year, let month = components.month else { continue }
            
            let key = String(format: "%04d-%02d", year, month)
            let isBusiness = receipt.businessPercentage >= 50
            
            var current = monthlyData[key] ?? (count: 0, size: 0, business: 0, personal: 0, year: year, month: month)
            current.count += 1
            current.size += receiptSize
            if isBusiness {
                current.business += 1
            } else {
                current.personal += 1
            }
            monthlyData[key] = current
        }
        
        // Build monthly stats array (sorted newest first)
        let monthlyStats: [MonthlyReceiptStats] = monthlyData.map { key, data in
            MonthlyReceiptStats(
                id: key,
                year: data.year,
                month: data.month,
                count: data.count,
                sizeBytes: data.size,
                businessCount: data.business,
                personalCount: data.personal
            )
        }.sorted { ($0.year, $0.month) > ($1.year, $1.month) }
        
        // Build yearly stats
        var yearlyData: [Int: [MonthlyReceiptStats]] = [:]
        for monthly in monthlyStats {
            yearlyData[monthly.year, default: []].append(monthly)
        }
        
        let yearlyStats: [YearlyReceiptStats] = yearlyData.map { year, months in
            YearlyReceiptStats(
                id: year,
                year: year,
                count: months.reduce(0) { $0 + $1.count },
                sizeBytes: months.reduce(0) { $0 + $1.sizeBytes },
                businessCount: months.reduce(0) { $0 + $1.businessCount },
                personalCount: months.reduce(0) { $0 + $1.personalCount },
                months: months.sorted { $0.month > $1.month }
            )
        }.sorted { $0.year > $1.year }
        
        // Calculate totals
        let totalSize = fileStorageSize + embeddedSize
        let businessTotal = receipts.filter { $0.businessPercentage >= 50 }.count
        let personalTotal = receipts.count - businessTotal
        
        let result = ReceiptStorageStats(
            totalReceipts: receipts.count,
            totalSizeBytes: totalSize,
            businessReceipts: businessTotal,
            personalReceipts: personalTotal,
            receiptsByMonth: monthlyStats,
            receiptsByYear: yearlyStats,
            oldestReceiptDate: oldestDate,
            newestReceiptDate: newestDate
        )
        
        stats = result
        isCalculating = false
        
        #if DEBUG
        print("📊 Storage Stats Calculated:")
        print("   Total: \(result.totalReceipts) receipts")
        print("   Size: \(result.totalSizeFormatted)")
        print("   Business: \(businessTotal), Personal: \(personalTotal)")
        print("   Years: \(yearlyStats.map { $0.year })")
        #endif
        
        return result
    }
    
    // MARK: - Get Receipts for Export
    
    /// Get receipt data for export/backup before purging
    func getReceiptsForExport(
        from receipts: [ReceiptData],
        year: Int? = nil,
        month: Int? = nil
    ) async -> [ReceiptExportItem] {
        let filtered = filterReceipts(receipts, year: year, month: month)
        
        var exportItems: [ReceiptExportItem] = []
        
        for receipt in filtered {
            // Load image if available
            var image: UIImage?
            if let imageData = receipt.imageData {
                image = UIImage(data: imageData)
            } else if let filename = receipt.imageURL {
                image = try? await PhotoStorageManager.shared.loadReceipt(filename: filename)
            }
            
            let item = ReceiptExportItem(
                id: receipt.id,
                merchantName: receipt.merchantName,
                amount: receipt.totalAmount,
                date: receipt.date,
                categoryName: receipt.suggestedCategoryName,
                isBusinessExpense: receipt.businessPercentage >= 50,
                imageFilename: receipt.imageURL,
                image: image
            )
            exportItems.append(item)
        }
        
        return exportItems.sorted { $0.date > $1.date }
    }
    
    // MARK: - Purge by Month
    
    /// Purge all receipts from a specific month
    /// - Parameters:
    ///   - year: The year (e.g., 2025)
    ///   - month: The month (1-12)
    ///   - receipts: All receipts to filter from
    ///   - context: ModelContext for deletion
    func purgeMonth(
        year: Int,
        month: Int,
        receipts: [ReceiptData],
        context: ModelContext
    ) async -> PurgeResult {
        isPurging = true
        HapticService.play(.heavy)
        
        let toDelete = filterReceipts(receipts, year: year, month: month)
        let result = await performPurge(toDelete, context: context)
        
        isPurging = false
        
        if result.isSuccess {
            HapticService.play(.success)
        } else {
            HapticService.play(.error)
        }
        
        return result
    }
    
    // MARK: - Purge by Year
    
    /// Purge all receipts from a specific year
    /// - Parameters:
    ///   - year: The year to purge (e.g., 2024)
    ///   - receipts: All receipts to filter from
    ///   - context: ModelContext for deletion
    func purgeYear(
        year: Int,
        receipts: [ReceiptData],
        context: ModelContext
    ) async -> PurgeResult {
        isPurging = true
        HapticService.play(.heavy)
        
        let toDelete = filterReceipts(receipts, year: year, month: nil)
        let result = await performPurge(toDelete, context: context)
        
        isPurging = false
        
        if result.isSuccess {
            HapticService.play(.success)
        } else {
            HapticService.play(.error)
        }
        
        return result
    }
    
    // MARK: - Purge by Date Range
    
    /// Purge receipts within a date range
    func purgeDateRange(
        from startDate: Date,
        to endDate: Date,
        receipts: [ReceiptData],
        context: ModelContext
    ) async -> PurgeResult {
        isPurging = true
        HapticService.play(.heavy)
        
        let toDelete = receipts.filter { $0.date >= startDate && $0.date <= endDate }
        let result = await performPurge(toDelete, context: context)
        
        isPurging = false
        
        if result.isSuccess {
            HapticService.play(.success)
        }
        
        return result
    }
    
    // MARK: - Count Receipts (for confirmation UI)
    
    /// Get count of receipts that would be affected by a purge
    func countReceiptsForMonth(year: Int, month: Int, receipts: [ReceiptData]) -> Int {
        filterReceipts(receipts, year: year, month: month).count
    }
    
    func countReceiptsForYear(_ year: Int, receipts: [ReceiptData]) -> Int {
        filterReceipts(receipts, year: year, month: nil).count
    }
    
    // MARK: - Cleanup Orphaned Images
    
    /// Remove image files without corresponding ReceiptData records
    func cleanupOrphanedImages(receipts: [ReceiptData]) async -> Int {
        var validFilenames = Set<String>()
        
        for receipt in receipts {
            if let filename = receipt.imageURL {
                validFilenames.insert(filename)
            }
        }
        
        let cleaned = await PhotoStorageManager.shared.cleanupOrphanedReceipts(validFilenames: validFilenames)
        
        if cleaned > 0 {
            HapticService.play(.light)
            #if DEBUG
            print("🧹 Cleaned up \(cleaned) orphaned receipt images")
            #endif
        }
        
        return cleaned
    }
    
    // MARK: - Private Helpers
    
    private func filterReceipts(_ receipts: [ReceiptData], year: Int?, month: Int?) -> [ReceiptData] {
        let calendar = Calendar.current
        
        return receipts.filter { receipt in
            let components = calendar.dateComponents([.year, .month], from: receipt.date)
            
            if let targetYear = year {
                guard components.year == targetYear else { return false }
            }
            
            if let targetMonth = month {
                guard components.month == targetMonth else { return false }
            }
            
            return true
        }
    }
    
    private func performPurge(_ receipts: [ReceiptData], context: ModelContext) async -> PurgeResult {
        var imagesDeleted = 0
        var spaceFreed: Int64 = 0
        var errors: [String] = []
        
        for receipt in receipts {
            // Track embedded image size
            if let imageData = receipt.imageData {
                spaceFreed += Int64(imageData.count)
            }
            
            // Delete external image file
            if let filename = receipt.imageURL, !filename.isEmpty {
                do {
                    // Get file size before deletion
                    let fileURL = PhotoStorageManager.shared.directoryURL.appendingPathComponent(filename)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let size = attrs[.size] as? Int64 {
                        spaceFreed += size
                    }
                    
                    let deleted = try await PhotoStorageManager.shared.deleteReceipt(filename: filename)
                    if deleted {
                        imagesDeleted += 1
                    }
                } catch {
                    errors.append("Failed to delete \(filename): \(error.localizedDescription)")
                }
            }
            
            // Delete from database
            context.delete(receipt)
        }
        
        // Save changes
        do {
            try context.save()
        } catch {
            errors.append("Failed to save: \(error.localizedDescription)")
        }
        
        // Clear cached stats
        stats = nil
        
        #if DEBUG
        print("🗑️ Purge Complete:")
        print("   Receipts: \(receipts.count)")
        print("   Images: \(imagesDeleted)")
        print("   Freed: \(ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file))")
        if !errors.isEmpty {
            print("   Errors: \(errors)")
        }
        #endif
        
        return PurgeResult(
            receiptsDeleted: receipts.count,
            imagesDeleted: imagesDeleted,
            spaceFreed: spaceFreed,
            errors: errors
        )
    }
}

// MARK: - Usage Examples

/*
 // === CALCULATE STATS ===
 let stats = await ReceiptStorageManager.shared.calculateStats(receipts: allReceipts)
 print("Total: \(stats.totalReceipts) using \(stats.totalSizeFormatted)")
 
 // Display by year
 for year in stats.receiptsByYear {
     print("\(year.displayName): \(year.count) receipts (\(year.sizeFormatted))")
     for month in year.months {
         print("  - \(month.shortDisplayName): \(month.count)")
     }
 }
 
 // === EXPORT BEFORE PURGE ===
 
 // Get January 2025 for export
 let exportData = await ReceiptStorageManager.shared.getReceiptsForExport(
     from: allReceipts,
     year: 2025,
     month: 1
 )
 // User saves to Files app...
 
 // === PURGE BY MONTH ===
 let result = await ReceiptStorageManager.shared.purgeMonth(
     year: 2025,
     month: 1,
     receipts: allReceipts,
     context: modelContext
 )
 print("Freed \(result.spaceFreedFormatted)")
 
 // === PURGE BY YEAR ===
 let result = await ReceiptStorageManager.shared.purgeYear(
     year: 2024,
     receipts: allReceipts,
     context: modelContext
 )
 */
