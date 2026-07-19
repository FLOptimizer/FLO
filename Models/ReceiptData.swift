//  ReceiptData.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Tip parsing
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ Added optional tipAmount captured by SmartReceiptService OCR parsing
//
//  CHANGES v2.1:
//  ✅ Removed 'description' computed property from ReceiptLineItem
//  ✅ 'description' shadowed NSObject.description, breaking SwiftData schema
//  ✅ Use 'itemDescription' property instead
//
//  Enhanced receipt data model for smart scanning and matching
//

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
final class ReceiptData {
    var id: UUID = UUID()
    var transactionID: UUID?  // Link to associated Transaction (if created)
    var bankTransactionID: String?  // For matching to imported bank transactions

    // OCR Extracted Data
    var merchantName: String = ""
    var totalAmount: Double = 0.0
    var date: Date = Date()
    var rawOCRText: String = ""  // Full OCR text for reference

    /// Tip amount parsed from receipt OCR (gratuity, service charge).
    /// nil if no tip line was detected. Already included in totalAmount.
    var tipAmount: Double?

    // Enhanced Data
    var suggestedCategoryID: UUID?
    var suggestedCategoryName: String?
    var categorySuggestionConfidence: Double = 0.0  // 0.0 to 1.0

    // Receipt Image
    var imageData: Data?  // Compressed receipt image
    var imageURL: String?  // Alternative: store in file system

    // Line Items (for split receipts) - FIXED: Use @Relationship
    @Relationship(deleteRule: .cascade, inverse: \ReceiptLineItem.receipt)
    var lineItems: [ReceiptLineItem]?

    // Business/Personal Split
    var businessPercentage: Double = 100.0  // 0-100: what % is business expense
    var splitNotes: String?

    // Matching Status
    var matchStatus: MatchStatus = MatchStatus.unmatched
    var matchedDate: Date?
    var matchScore: Double?  // Confidence score for automatic matching

    // Tax & Deduction
    var isTaxDeductible: Bool = false
    var taxCategory: String?
    var deductionFlagged: Bool = false  // Has user been reminded about this?
    var deductionFlaggedDate: Date?

    // Payment Card Info (v2.3 — for auto-account matching)
    /// Last 4 digits extracted from payment method line on receipt
    var paymentLastFour: String?
    /// Card network detected (visa, mastercard, amex, discover)
    var paymentNetwork: String?

    // OCR Quality
    /// Average Vision OCR confidence across all recognized text (0.0–1.0).
    var ocrConfidence: Double = 0.0

    // Metadata
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var notes: String?
    
    init(
        merchantName: String,
        totalAmount: Double,
        date: Date,
        rawOCRText: String = "",
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.merchantName = merchantName
        self.totalAmount = totalAmount
        self.date = date
        self.rawOCRText = rawOCRText
        self.imageData = imageData
        self.lineItems = []
        self.businessPercentage = 100.0  // Default: assume fully business
        self.matchStatus = .unmatched
        self.isTaxDeductible = false
        self.deductionFlagged = false
        self.categorySuggestionConfidence = 0.0
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Convenience Initializers
    
    convenience init(
        merchantName: String,
        totalAmount: Double,
        date: Date,
        rawOCRText: String = "",
        imageData: Data? = nil,
        lineItems: [ReceiptLineItem]
    ) {
        self.init(
            merchantName: merchantName,
            totalAmount: totalAmount,
            date: date,
            rawOCRText: rawOCRText,
            imageData: imageData
        )
        self.lineItems = lineItems
    }
    
    // MARK: - Computed Properties
    
    /// Business portion of the receipt (for tax deductions)
    var businessAmount: Double {
        totalAmount * (businessPercentage / 100.0)
    }
    
    /// Personal portion of the receipt
    var personalAmount: Double {
        totalAmount * (1.0 - businessPercentage / 100.0)
    }
    
    var hasLineItems: Bool {
        !(lineItems ?? []).isEmpty
    }
    
    var isSplit: Bool {
        businessPercentage > 0 && businessPercentage < 100
    }
    
    var needsAttention: Bool {
        // Unmatched receipts over 7 days old need attention
        matchStatus == .unmatched &&
        Date().timeIntervalSince(date) > (7 * 86_400) &&
        !deductionFlagged
    }
}

// MARK: - Supporting Types

extension ReceiptData {
    enum MatchStatus: String, Codable {
        case unmatched = "unmatched"
        case automaticMatch = "autoMatched"
        case manualMatch = "manualMatch"
        case noBankTransaction = "cashPurchase"
        case duplicateWarning = "duplicateWarning"
        
        // Display names for UI
        var displayName: String {
            switch self {
            case .unmatched: return "Unmatched"
            case .automaticMatch: return "Auto-Matched"
            case .manualMatch: return "Manual Match"
            case .noBankTransaction: return "Cash Purchase"
            case .duplicateWarning: return "Possible Duplicate"
            }
        }
    }
}

// MARK: - Receipt Line Item (Now a @Model class)

@Model
final class ReceiptLineItem {
    var id: UUID = UUID()
    var receipt: ReceiptData?  // Back reference
    var itemDescription: String = ""  // Renamed from 'description' to avoid keyword conflict
    var amount: Double = 0.0
    var quantity: Int = 1
    var isBusiness: Bool = true  // For split receipts
    var categoryID: UUID?
    var categoryName: String?
    
    init(
        description: String,
        amount: Double,
        quantity: Int = 1,
        isBusiness: Bool = true
    ) {
        self.id = UUID()
        self.itemDescription = description
        self.amount = amount
        self.quantity = quantity
        self.isBusiness = isBusiness
    }
    
    var totalAmount: Double {
        amount * Double(quantity)
    }
    
    // REMOVED: 'description' computed property was shadowing NSObject.description
    // which breaks SwiftData schema generation. Use 'itemDescription' instead.
}

// MARK: - Receipt Matching

extension ReceiptData {
    /// Calculate match score with a transaction using fuzzy merchant matching
    /// Returns 0.0-1.0 score indicating likelihood of match
    ///
    /// Scoring breakdown:
    /// - Amount match: 0-40 points (exact = 40, within $1 = 32, within $5 = 20, within 10% = 12)
    /// - Date proximity: 0-30 points (same day = 30, next day = 21, within week = 9)
    /// - Merchant match: 0-30 points (using fuzzy matching with confidence scoring)
    func calculateMatchScore(
        withAmount transactionAmount: Double,
        transactionDate: Date,
        transactionMerchant: String
    ) -> Double {
        var score: Double = 0.0
        
        // AMOUNT MATCH (40% weight)
        let amountDifference = abs(totalAmount - transactionAmount)
        let amountScore: Double
        if amountDifference < 0.01 {
            amountScore = 1.0  // Exact match
        } else if amountDifference < 1.00 {
            amountScore = 0.8  // Within $1
        } else if amountDifference < 5.00 {
            amountScore = 0.5  // Within $5
        } else if totalAmount > 0 && (amountDifference / totalAmount) < 0.1 {
            amountScore = 0.3  // Within 10%
        } else {
            amountScore = 0.0
        }
        score += amountScore * 0.4
        
        // DATE MATCH (30% weight)
        let daysDifference = abs(date.timeIntervalSince(transactionDate) / 86_400)
        let dateScore: Double
        if daysDifference < 1 {
            dateScore = 1.0  // Same day
        } else if daysDifference < 2 {
            dateScore = 0.7  // Next day (common for pending transactions)
        } else if daysDifference < 7 {
            dateScore = 0.3  // Within a week
        } else {
            dateScore = 0.0
        }
        score += dateScore * 0.3
        
        // MERCHANT MATCH with fuzzy logic (30% weight)
        // Uses String.fuzzyMatchConfidence from TransactionMatchingService
        let merchantScore = merchantName.fuzzyMatchConfidence(with: transactionMerchant)
        score += merchantScore * 0.3
        
        return min(1.0, score)  // Cap at 1.0
    }
    
    /// Determine if this is a high-confidence match (>= 0.75)
    var isHighConfidenceMatch: Bool {
        guard let score = matchScore else { return false }
        return score >= 0.75
    }
}

// MARK: - Tax Deduction Helpers

extension ReceiptData {
    /// Categories that are typically tax deductible for freelancers/small businesses
    static let deductibleCategories = [
        "Office Supplies",
        "Software & Subscriptions",
        "Meals & Entertainment",
        "Travel",
        "Auto Expenses",
        "Marketing & Advertising",
        "Professional Services",
        "Education & Training",
        "Shipping & Postage",
        "Insurance",
        "Legal & Professional Fees",
        "Business Equipment",
        "Utilities",
        "Internet & Phone",
        "Bank Fees",
        "Contract Labor"
    ]
    
    /// Check if receipt is likely tax deductible based on category
    func updateDeductibleStatus(categoryName: String?) {
        guard let category = categoryName else {
            isTaxDeductible = false
            taxCategory = nil
            return
        }
        
        isTaxDeductible = Self.deductibleCategories.contains(category)
        
        if isTaxDeductible {
            taxCategory = category
        }
    }
}
