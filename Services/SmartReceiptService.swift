//  SmartReceiptService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2 - Fixed Storage Architecture
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.2:
//  ✅ FIXED: Images now stored as FILES via PhotoStorageManager
//  ✅ FIXED: Only filename stored in database (imageURL field)
//  ✅ FIXED: imageData field no longer used (prevents database bloat)
//  ✅ ADDED: loadReceiptImage() helper for retrieving images
//  ✅ ADDED: migrateEmbeddedImages() for converting legacy receipts
//
//  PREVIOUS (v3.1):
//  - Threading crash fix - ModelContext operations on MainActor
//  - Uses ReceiptParser for text parsing
//  - Intelligent category suggestion with learning
//
//  STORAGE ARCHITECTURE:
//  - Images stored in: Documents/Receipts/*.jpg (via PhotoStorageManager)
//  - Database stores: filename reference only (imageURL field)
//  - Benefit: Prevents database bloat, faster queries, easy backup/export
//

import Foundation
import SwiftData
import Vision
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class SmartReceiptService {
    static let shared = SmartReceiptService()
    
    private init() {}
    
    // MARK: - Receipt Processing
    
    /// Process a scanned receipt with intelligence layer
    /// Images are stored as FILES, not embedded in database
    func processReceipt(
        image: UIImage,
        context: ModelContext
    ) async throws -> ReceiptData {
        // Step 1: Extract raw OCR text using Vision
        let rawText = try await extractRawOCRText(from: image)
        
        guard !rawText.isEmpty else {
            throw ReceiptError.noDataExtracted
        }
        
        // Step 2: Use ReceiptParser for accurate parsing
        let parsed = ReceiptParser.shared.parseReceipt(text: rawText)
        
        let merchantName = parsed.merchantName ?? "Unknown Merchant"
        let amount = parsed.amount ?? 0.0
        let date = parsed.date ?? Date()
        
        #if DEBUG
        print("🧠 SmartReceiptService Processing:")
        print("   Merchant: \(merchantName)")
        print("   Amount: $\(String(format: "%.2f", amount))")
        print("   Date: \(date.formatted(date: .abbreviated, time: .omitted))")
        #endif
        
        // Step 3: Save image to FILE SYSTEM (not database!)
        // This is the critical fix for storage architecture
        let imageFilename = try await PhotoStorageManager.shared.saveReceipt(image: image)
        
        #if DEBUG
        print("   📁 Image saved: \(imageFilename)")
        #endif
        
        // Step 4: Create receipt data
        // NOTE: imageData is nil - we use imageURL for file reference
        let receiptData = ReceiptData(
            merchantName: merchantName,
            totalAmount: amount,
            date: date,
            rawOCRText: rawText,
            imageData: nil  // ← CRITICAL: Don't store image in database!
        )
        
        // Store filename reference
        receiptData.imageURL = imageFilename
        
        // Step 5: Smart category suggestion
        if let suggestion = suggestCategoryWithLearning(
            for: merchantName,
            amount: amount,
            receiptParserSuggestion: parsed.suggestedCategory,
            context: context
        ) {
            receiptData.suggestedCategoryID = suggestion.categoryID
            receiptData.suggestedCategoryName = suggestion.categoryName
            receiptData.categorySuggestionConfidence = suggestion.confidence
            
            receiptData.updateDeductibleStatus(categoryName: suggestion.categoryName)
            
            #if DEBUG
            print("   Category: \(suggestion.categoryName ?? "None") (\(Int(suggestion.confidence * 100))%)")
            #endif
        }
        
        // Step 6: Extract line items
        receiptData.lineItems = extractLineItems(from: rawText)
        
        // Step 7: Insert into database (small footprint - no image data)
        context.insert(receiptData)
        try context.save()
        
        #if DEBUG
        print("✅ Receipt saved: \(merchantName) - $\(String(format: "%.2f", amount))")
        #endif
        
        return receiptData
    }
    
    // MARK: - Load Receipt Image
    
    /// Load receipt image from file storage
    /// Use this instead of accessing imageData directly
    func loadReceiptImage(for receipt: ReceiptData) async -> UIImage? {
        // Primary: Load from file storage
        if let filename = receipt.imageURL, !filename.isEmpty {
            do {
                return try await PhotoStorageManager.shared.loadReceipt(filename: filename)
            } catch {
                #if DEBUG
                print("⚠️ Failed to load image file \(filename): \(error)")
                #endif
            }
        }
        
        // Fallback: Legacy embedded data
        if let imageData = receipt.imageData {
            #if DEBUG
            print("⚠️ Loading from embedded data (legacy receipt)")
            #endif
            return UIImage(data: imageData)
        }
        
        return nil
    }
    
    // MARK: - Migration: Embedded → File Storage
    
    /// Migrate legacy receipts from embedded imageData to file storage
    /// Call this once to convert old receipts - frees up database space
    func migrateEmbeddedImages(
        receipts: [ReceiptData],
        context: ModelContext
    ) async -> (migrated: Int, failed: Int, spaceFreed: Int64) {
        var migrated = 0
        var failed = 0
        var spaceFreed: Int64 = 0
        
        // Find receipts with embedded images but no file reference
        let needsMigration = receipts.filter { receipt in
            receipt.imageData != nil && (receipt.imageURL == nil || receipt.imageURL!.isEmpty)
        }
        
        guard !needsMigration.isEmpty else {
            #if DEBUG
            print("✅ No receipts need migration")
            #endif
            return (0, 0, 0)
        }
        
        #if DEBUG
        print("🔄 Migrating \(needsMigration.count) receipts to file storage...")
        #endif
        
        for receipt in needsMigration {
            guard let imageData = receipt.imageData,
                  let image = UIImage(data: imageData) else {
                failed += 1
                continue
            }
            
            do {
                // Save to file
                let filename = try await PhotoStorageManager.shared.saveReceipt(image: image)
                
                // Update receipt to use file reference
                let originalSize = Int64(imageData.count)
                receipt.imageURL = filename
                receipt.imageData = nil  // Clear embedded data
                
                migrated += 1
                spaceFreed += originalSize
                
                #if DEBUG
                print("   ✓ Migrated: \(receipt.merchantName)")
                #endif
            } catch {
                failed += 1
                #if DEBUG
                print("   ✗ Failed: \(receipt.merchantName) - \(error)")
                #endif
            }
        }
        
        // Save all changes
        if migrated > 0 {
            do {
                try context.save()
                #if DEBUG
                print("✅ Migration complete: \(migrated) migrated, \(failed) failed")
                print("   Space freed: \(ByteCountFormatter.string(fromByteCount: spaceFreed, countStyle: .file))")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to save migration: \(error)")
                #endif
            }
        }
        
        return (migrated, failed, spaceFreed)
    }
    
    /// Check how many receipts have embedded images (need migration)
    func countEmbeddedImages(receipts: [ReceiptData]) -> Int {
        receipts.filter { receipt in
            receipt.imageData != nil && (receipt.imageURL == nil || receipt.imageURL!.isEmpty)
        }.count
    }
    
    // MARK: - Raw OCR Extraction
    
    private func extractRawOCRText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ReceiptError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptError.ocrFailed)
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                guard !recognizedStrings.isEmpty else {
                    continuation.resume(throwing: ReceiptError.noDataExtracted)
                    return
                }
                
                continuation.resume(returning: recognizedStrings.joined(separator: "\n"))
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Smart Category Suggestion
    
    private func suggestCategoryWithLearning(
        for merchantName: String,
        amount: Double,
        receiptParserSuggestion: String?,
        context: ModelContext
    ) -> CategorySuggestion? {
        let normalizedMerchant = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Priority 1: Learned mappings
        let descriptor = FetchDescriptor<MerchantCategoryMapping>()
        if let allMappings = try? context.fetch(descriptor) {
            for mapping in allMappings {
                if mapping.matches(merchantName) {
                    return CategorySuggestion(
                        categoryID: mapping.categoryID,
                        categoryName: mapping.categoryName,
                        confidence: mapping.confidence
                    )
                }
            }
        }
        
        // Priority 2: Common merchant patterns
        for mapping in MerchantCategoryMapping.commonMappings {
            for pattern in mapping.patterns {
                if normalizedMerchant.contains(pattern) {
                    let categoryDescriptor = FetchDescriptor<Category>()
                    
                    if let categories = try? context.fetch(categoryDescriptor),
                       let matchedCategory = categories.first(where: { $0.name == mapping.category }) {
                        return CategorySuggestion(
                            categoryID: matchedCategory.id,
                            categoryName: matchedCategory.name,
                            confidence: 0.75
                        )
                    } else {
                        return CategorySuggestion(
                            categoryID: nil,
                            categoryName: mapping.category,
                            confidence: 0.75
                        )
                    }
                }
            }
        }
        
        // Priority 3: ReceiptParser suggestion
        if let parserSuggestion = receiptParserSuggestion {
            let categoryDescriptor = FetchDescriptor<Category>()
            
            if let categories = try? context.fetch(categoryDescriptor),
               let matchedCategory = categories.first(where: { $0.name == parserSuggestion }) {
                return CategorySuggestion(
                    categoryID: matchedCategory.id,
                    categoryName: matchedCategory.name,
                    confidence: 0.6
                )
            } else {
                return CategorySuggestion(
                    categoryID: nil,
                    categoryName: parserSuggestion,
                    confidence: 0.6
                )
            }
        }
        
        // Priority 4: Amount-based heuristics
        if amount < 10.0 {
            return CategorySuggestion(categoryID: nil, categoryName: "Office Supplies", confidence: 0.3)
        } else if amount < 50.0 {
            return CategorySuggestion(categoryID: nil, categoryName: "Meals & Entertainment", confidence: 0.3)
        }
        
        return nil
    }
    
    // MARK: - Learning
    
    func learnFromUserChoice(
        merchantName: String,
        categoryID: UUID,
        categoryName: String,
        context: ModelContext
    ) throws {
        let descriptor = FetchDescriptor<MerchantCategoryMapping>()
        let allMappings = try context.fetch(descriptor)
        
        if let existing = allMappings.first(where: { $0.matches(merchantName) }) {
            existing.categoryID = categoryID
            existing.categoryName = categoryName
            existing.reinforceMapping()
        } else {
            let newMapping = MerchantCategoryMapping(
                merchantName: merchantName,
                categoryID: categoryID,
                categoryName: categoryName,
                confidence: 0.6,
                isManualOverride: true
            )
            context.insert(newMapping)
        }
        
        try context.save()
        
        #if DEBUG
        print("📚 Learned: \(merchantName) → \(categoryName)")
        #endif
    }
    
    // MARK: - Line Item Extraction
    
    private func extractLineItems(from text: String) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            if let amount = extractAmountFromLine(line), amount > 0 && amount < 10000 {
                let description = extractDescription(from: line, amount: amount)
                
                let lowerDesc = description.lowercased()
                if !description.isEmpty &&
                   !lowerDesc.contains("total") &&
                   !lowerDesc.contains("subtotal") &&
                   !lowerDesc.contains("tax") &&
                   !lowerDesc.contains("tip") {
                    items.append(ReceiptLineItem(description: description, amount: amount))
                }
            }
        }
        
        return items
    }
    
    private func extractAmountFromLine(_ line: String) -> Double? {
        let pattern = #/\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/#
        if let match = line.firstMatch(of: pattern) {
            let amountString = String(match.1).replacingOccurrences(of: ",", with: "")
            return Double(amountString)
        }
        return nil
    }
    
    private func extractDescription(from line: String, amount: Double) -> String {
        let amountStr = String(format: "%.2f", amount)
        
        var cleaned = line
            .replacingOccurrences(of: "$\(amountStr)", with: "")
            .replacingOccurrences(of: amountStr, with: "")
        
        cleaned = cleaned.replacing(#/\$\d+\.\d{2}/#, with: "")
                         .replacing(#/\d+\.\d{2}/#, with: "")
                         .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned.isEmpty ? "Item" : cleaned
    }
}

// MARK: - Supporting Types

struct CategorySuggestion {
    let categoryID: UUID?
    let categoryName: String?
    let confidence: Double
}

enum ReceiptError: Error, LocalizedError {
    case invalidImage
    case ocrFailed
    case noDataExtracted
    case imageStorageFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        case .ocrFailed: return "Text recognition failed"
        case .noDataExtracted: return "No text found in image"
        case .imageStorageFailed: return "Failed to save receipt image"
        }
    }
}
