//  SmartReceiptService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.1 - Fixed Threading Crash
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.1:
//  ✅ FIXED: Threading crash - ModelContext operations now on MainActor
//  ✅ Uses ReceiptParser for text parsing (proven accuracy)
//  ✅ Keeps intelligent category suggestion with learning
//
//  Architecture:
//  - Vision framework → Raw OCR text (background thread OK)
//  - ReceiptParser → Parse amount, date, merchant (background thread OK)
//  - SmartReceiptService → Database ops on MainActor
//

import Foundation
import SwiftData
import Vision
import UIKit

@MainActor
class SmartReceiptService {
    static let shared = SmartReceiptService()
    
    private init() {}
    
    // MARK: - Receipt Processing
    
    /// Process a scanned receipt with intelligence layer
    /// Uses ReceiptParser for text parsing, adds learning and matching
    func processReceipt(
        image: UIImage,
        context: ModelContext
    ) async throws -> ReceiptData {
        // Step 1: Extract raw OCR text using Vision
        let rawText = try await extractRawOCRText(from: image)
        
        guard !rawText.isEmpty else {
            throw ReceiptError.noDataExtracted
        }
        
        // Step 2: Use ReceiptParser for accurate parsing (the proven approach)
        let parsed = ReceiptParser.shared.parseReceipt(text: rawText)
        
        let merchantName = parsed.merchantName ?? "Unknown Merchant"
        let amount = parsed.amount ?? 0.0
        let date = parsed.date ?? Date()
        
        #if DEBUG
        print("🧠 SmartReceiptService using ReceiptParser results:")
        print("   Merchant: \(merchantName)")
        print("   Amount: $\(String(format: "%.2f", amount))")
        print("   Date: \(date.formatted(date: .abbreviated, time: .omitted))")
        print("   ReceiptParser Category: \(parsed.suggestedCategory ?? "None")")
        #endif
        
        // Step 3: Create receipt data object
        let receiptData = ReceiptData(
            merchantName: merchantName,
            totalAmount: amount,
            date: date,
            rawOCRText: rawText,
            imageData: image.jpegData(compressionQuality: 0.7)
        )
        
        // Step 4: Smart category suggestion (with learning from past choices)
        // First try our learned mappings, then fall back to ReceiptParser's suggestion
        if let suggestion = suggestCategoryWithLearning(
            for: merchantName,
            amount: amount,
            receiptParserSuggestion: parsed.suggestedCategory,
            context: context
        ) {
            receiptData.suggestedCategoryID = suggestion.categoryID
            receiptData.suggestedCategoryName = suggestion.categoryName
            receiptData.categorySuggestionConfidence = suggestion.confidence
            
            #if DEBUG
            print("   Smart Category: \(suggestion.categoryName ?? "None") (\(String(format: "%.0f%%", suggestion.confidence * 100)))")
            #endif
            
            // Update tax deductible status
            receiptData.updateDeductibleStatus(categoryName: suggestion.categoryName)
        }
        
        // Step 5: Extract line items for detailed view
        receiptData.lineItems = extractLineItems(from: rawText)
        
        #if DEBUG
        print("   Line Items: \(receiptData.lineItems.count)")
        #endif
        
        // Step 6: Insert into database
        context.insert(receiptData)
        try context.save()
        
        #if DEBUG
        print("✅ Receipt processed: \(merchantName) - $\(String(format: "%.2f", amount))")
        #endif
        
        return receiptData
    }
    
    // MARK: - Raw OCR Extraction (Vision Framework)
    
    /// Extract raw text from image using Vision framework
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
                
                // Extract all recognized text and join with newlines
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                guard !recognizedStrings.isEmpty else {
                    continuation.resume(throwing: ReceiptError.noDataExtracted)
                    return
                }
                
                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
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
    
    // MARK: - Smart Category Suggestion (with Learning)
    
    /// Suggest category using learned mappings first, then ReceiptParser's suggestion
    private func suggestCategoryWithLearning(
        for merchantName: String,
        amount: Double,
        receiptParserSuggestion: String?,
        context: ModelContext
    ) -> CategorySuggestion? {
        let normalizedMerchant = merchantName.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Priority 1: Check if we have a LEARNED mapping for this merchant
        // This is the "intelligence" - it learns from user corrections
        let descriptor = FetchDescriptor<MerchantCategoryMapping>()
        if let allMappings = try? context.fetch(descriptor) {
            for mapping in allMappings {
                if mapping.matches(merchantName) {
                    #if DEBUG
                    print("   📚 Using learned mapping: \(merchantName) → \(mapping.categoryName ?? "?")")
                    #endif
                    return CategorySuggestion(
                        categoryID: mapping.categoryID,
                        categoryName: mapping.categoryName,
                        confidence: mapping.confidence
                    )
                }
            }
        }
        
        // Priority 2: Check common merchant patterns from MerchantCategoryMapping
        for mapping in MerchantCategoryMapping.commonMappings {
            for pattern in mapping.patterns {
                if normalizedMerchant.contains(pattern) {
                    // Try to find this category in the database
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
        
        // Priority 3: Use ReceiptParser's suggestion (keyword-based)
        if let parserSuggestion = receiptParserSuggestion {
            // Try to find this category in the database
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
        
        // Priority 4: Amount-based heuristics (low confidence fallback)
        if amount < 10.0 {
            return CategorySuggestion(
                categoryID: nil,
                categoryName: "Office Supplies",
                confidence: 0.3
            )
        } else if amount < 50.0 {
            return CategorySuggestion(
                categoryID: nil,
                categoryName: "Meals & Entertainment",
                confidence: 0.3
            )
        }
        
        return nil
    }
    
    // MARK: - Learning
    
    /// Learn from user's category selection - improves future suggestions
    func learnFromUserChoice(
        merchantName: String,
        categoryID: UUID,
        categoryName: String,
        context: ModelContext
    ) throws {
        // Check if mapping already exists
        let descriptor = FetchDescriptor<MerchantCategoryMapping>()
        let allMappings = try context.fetch(descriptor)
        
        if let existing = allMappings.first(where: { $0.matches(merchantName) }) {
            // Update existing mapping
            existing.categoryID = categoryID
            existing.categoryName = categoryName
            existing.reinforceMapping()
        } else {
            // Create new mapping
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
    
    /// Extract individual line items from receipt for detailed view
    private func extractLineItems(from text: String) -> [ReceiptLineItem] {
        var items: [ReceiptLineItem] = []
        
        let lines = text.components(separatedBy: .newlines)
        
        for line in lines {
            // Look for lines with both a description and an amount
            if let amount = extractAmountFromLine(line), amount > 0 && amount < 10000 {
                let description = extractDescription(from: line, amount: amount)
                
                // Skip total/subtotal lines and empty descriptions
                let lowerDesc = description.lowercased()
                if !description.isEmpty &&
                   !lowerDesc.contains("total") &&
                   !lowerDesc.contains("subtotal") &&
                   !lowerDesc.contains("tax") &&
                   !lowerDesc.contains("tip") {
                    let item = ReceiptLineItem(
                        description: description,
                        amount: amount
                    )
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    /// Extract amount from a single line
    private func extractAmountFromLine(_ line: String) -> Double? {
        // Pattern to match currency amounts like $12.34, 12.34, $12,345.67
        let pattern = #/\$?\s?(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)/#
        
        if let match = line.firstMatch(of: pattern) {
            let amountString = String(match.1).replacingOccurrences(of: ",", with: "")
            return Double(amountString)
        }
        
        return nil
    }
    
    /// Extract clean description from line item
    private func extractDescription(from line: String, amount: Double) -> String {
        let amountStr = String(format: "%.2f", amount)
        
        var cleaned = line
            .replacingOccurrences(of: "$\(amountStr)", with: "")
            .replacingOccurrences(of: amountStr, with: "")
        
        // Remove any remaining dollar amounts using regex
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
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .ocrFailed:
            return "Text recognition failed"
        case .noDataExtracted:
            return "No text found in image"
        }
    }
}
