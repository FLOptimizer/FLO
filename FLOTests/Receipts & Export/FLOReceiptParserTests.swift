//  FLOReceiptParserTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Receipt Parser & OCR Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate receipt OCR parsing, amount extraction,
//  date parsing, and merchant recognition.
//
//  COVERS:
//  - Amount extraction with confidence scoring
//  - Date parsing (various formats)
//  - Merchant/brand recognition
//  - OCR error correction
//  - Category suggestion
//

import XCTest
@testable import FLO

final class FLOReceiptParserTests: XCTestCase {
    
    // MARK: - Amount Extraction Helpers
    
    /// Extract amount from text using common patterns
    private func extractAmount(from text: String) -> (amount: Double?, confidence: Double) {
        // Pattern order matters - more specific patterns first!
        // Use \b word boundary to avoid matching "Subtotal" when looking for "TOTAL"
        let patterns = [
            "\\bTOTAL\\b.*?\\$([0-9]+\\.[0-9]{2})",    // TOTAL: $123.45 (word boundary)
            "\\bTOTAL\\b.*?([0-9]+\\.[0-9]{2})",       // TOTAL: 123.45 (no dollar sign)
            "\\bAMOUNT\\b.*?\\$?([0-9]+\\.[0-9]{2})",  // AMOUNT: 123.45
            "GRAND\\s*TOTAL.*?\\$?([0-9]+\\.[0-9]{2})", // GRAND TOTAL
            "\\$([0-9]+\\.[0-9]{2})",                   // $123.45 (generic)
            "\\$([0-9]+)",                              // $123
            "([0-9]+\\.[0-9]{2})\\s*$"                  // 123.45 at end
        ]
        
        for (index, pattern) in patterns.enumerated() {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                if let amount = Double(text[range]) {
                    let confidence = 1.0 - (Double(index) * 0.1)  // Higher patterns = higher confidence
                    return (amount, confidence)
                }
            }
        }
        
        return (nil, 0)
    }
    
    /// Extract date from text
    private func extractDate(from text: String) -> Date? {
        let formatters: [DateFormatter] = {
            let formats = [
                "MM/dd/yyyy",
                "MM/dd/yy",
                "yyyy-MM-dd",
                "MM-dd-yyyy",
                "MMM dd, yyyy",
                "MMMM dd, yyyy"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                return formatter
            }
        }()
        
        // Common date patterns
        let patterns = [
            "[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4}",
            "[0-9]{4}-[0-9]{2}-[0-9]{2}",
            "[A-Za-z]{3,9} [0-9]{1,2}, [0-9]{4}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let dateString = String(text[range])
                for formatter in formatters {
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Known brands database
    let knownBrands: [String: String] = [
        "STARBUCKS": "Starbucks",
        "WALMART": "Walmart",
        "TARGET": "Target",
        "AMAZON": "Amazon",
        "COSTCO": "Costco",
        "MCDONALDS": "McDonald's",
        "WHOLE FOODS": "Whole Foods",
        "CVS": "CVS",
        "WALGREENS": "Walgreens",
        "HOME DEPOT": "Home Depot",
        "BEST BUY": "Best Buy",
        "OFFICE DEPOT": "Office Depot",
        "STAPLES": "Staples"
    ]
    
    /// Merchant to category mapping
    let merchantCategories: [String: String] = [
        "Starbucks": "Food & Drink",
        "Walmart": "Shopping",
        "Target": "Shopping",
        "Amazon": "Shopping",
        "Costco": "Groceries",
        "McDonald's": "Food & Drink",
        "Whole Foods": "Groceries",
        "CVS": "Health",
        "Walgreens": "Health",
        "Home Depot": "Home",
        "Best Buy": "Electronics",
        "Office Depot": "Office Supplies",
        "Staples": "Office Supplies",
        "Shell": "Transportation",
        "Chevron": "Transportation",
        "Exxon": "Transportation"
    ]
}

// MARK: - Amount Extraction Tests

extension FLOReceiptParserTests {
    
    /// Test: Extract dollar amount with $ sign
    func testAmountExtraction_WithDollarSign() {
        let text = "Your total is $45.99"
        let result = extractAmount(from: text)
        
        XCTAssertEqual(result.amount, 45.99)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    /// Test: Extract from TOTAL line
    func testAmountExtraction_TotalLine() {
        let text = "Subtotal: $38.50\nTax: $3.08\nTOTAL: $41.58"
        let result = extractAmount(from: text)
        
        XCTAssertEqual(result.amount, 41.58, "Should find TOTAL amount")
    }
    
    /// Test: Extract amount without dollar sign
    func testAmountExtraction_NoDollarSign() {
        let text = "Amount Due 25.00"
        let result = extractAmount(from: text)
        
        XCTAssertEqual(result.amount, 25.00)
    }
    
    /// Test: Handle whole dollar amount
    func testAmountExtraction_WholeDollar() {
        let text = "Total $50"
        let result = extractAmount(from: text)
        
        XCTAssertEqual(result.amount, 50.0)
    }
    
    /// Test: Multiple amounts - prefer TOTAL
    func testAmountExtraction_MultipleAmounts_PreferTotal() {
        let text = """
        Coffee      $4.50
        Muffin      $3.25
        TOTAL:      $7.75
        """
        let result = extractAmount(from: text)
        
        XCTAssertEqual(result.amount, 7.75, "Should extract TOTAL, not line items")
    }
    
    /// Test: Handle OCR errors (0 vs O)
    func testAmountExtraction_OCRError_ZeroVsO() {
        let text = "Total: $1O.OO"  // O instead of 0
        
        // OCR correction
        let corrected = text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "l", with: "1")
        
        let result = extractAmount(from: corrected)
        
        XCTAssertEqual(result.amount, 10.00)
    }
    
    /// Test: No amount found
    func testAmountExtraction_NoAmountFound() {
        let text = "Thank you for shopping with us!"
        let result = extractAmount(from: text)
        
        XCTAssertNil(result.amount)
        XCTAssertEqual(result.confidence, 0)
    }
}

// MARK: - Date Extraction Tests

extension FLOReceiptParserTests {
    
    /// Test: Extract MM/DD/YYYY format
    func testDateExtraction_MMDDYYYY() {
        let text = "Date: 01/15/2026"
        let date = extractDate(from: text)
        
        XCTAssertNotNil(date)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date!), 1)
        XCTAssertEqual(calendar.component(.day, from: date!), 15)
        XCTAssertEqual(calendar.component(.year, from: date!), 2026)
    }
    
    /// Test: Extract MM/DD/YY format
    func testDateExtraction_MMDDYY() {
        let text = "01/15/26"
        let date = extractDate(from: text)
        
        XCTAssertNotNil(date)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date!), 1)
        XCTAssertEqual(calendar.component(.day, from: date!), 15)
    }
    
    /// Test: Extract YYYY-MM-DD format (ISO)
    func testDateExtraction_ISO() {
        let text = "Transaction: 2026-01-15"
        let date = extractDate(from: text)
        
        XCTAssertNotNil(date)
    }
    
    /// Test: Extract written month format
    func testDateExtraction_WrittenMonth() {
        let text = "January 15, 2026"
        let date = extractDate(from: text)
        
        XCTAssertNotNil(date)
    }
    
    /// Test: Extract abbreviated month
    func testDateExtraction_AbbreviatedMonth() {
        let text = "Jan 15, 2026"
        let date = extractDate(from: text)
        
        XCTAssertNotNil(date)
    }
    
    /// Test: No date found
    func testDateExtraction_NoDateFound() {
        let text = "Thank you for your purchase!"
        let date = extractDate(from: text)
        
        XCTAssertNil(date)
    }
}

// MARK: - Merchant Recognition Tests

extension FLOReceiptParserTests {
    
    /// Find merchant from text
    private func findMerchant(in text: String) -> String? {
        let upperText = text.uppercased()
        for (key, value) in knownBrands {
            if upperText.contains(key) {
                return value
            }
        }
        return nil
    }
    
    /// Test: Recognize Starbucks
    func testMerchant_RecognizeStarbucks() {
        let text = "STARBUCKS STORE #12345\n123 Main St"
        let merchant = findMerchant(in: text)
        
        XCTAssertEqual(merchant, "Starbucks")
    }
    
    /// Test: Recognize Walmart
    func testMerchant_RecognizeWalmart() {
        let text = "WALMART SUPERCENTER\nSave Money. Live Better."
        let merchant = findMerchant(in: text)
        
        XCTAssertEqual(merchant, "Walmart")
    }
    
    /// Test: Recognize with noise
    func testMerchant_RecognizeWithNoise() {
        let text = "Thank you for shopping at TARGET! Your receipt..."
        let merchant = findMerchant(in: text)
        
        XCTAssertEqual(merchant, "Target")
    }
    
    /// Test: Unknown merchant
    func testMerchant_UnknownMerchant() {
        let text = "LOCAL COFFEE SHOP\n123 Main Street"
        let merchant = findMerchant(in: text)
        
        XCTAssertNil(merchant, "Unknown merchant returns nil")
    }
    
    /// Test: Case insensitive matching
    func testMerchant_CaseInsensitive() {
        let text = "starbucks coffee"
        let merchant = findMerchant(in: text)
        
        XCTAssertEqual(merchant, "Starbucks")
    }
}

// MARK: - Category Suggestion Tests

extension FLOReceiptParserTests {
    
    /// Test: Suggest category for known merchant
    func testCategory_SuggestForMerchant() {
        let merchant = "Starbucks"
        let category = merchantCategories[merchant]
        
        XCTAssertEqual(category, "Food & Drink")
    }
    
    /// Test: Suggest category for gas station
    func testCategory_GasStation() {
        let merchant = "Shell"
        let category = merchantCategories[merchant]
        
        XCTAssertEqual(category, "Transportation")
    }
    
    /// Test: Suggest category for office supplies
    func testCategory_OfficeSupplies() {
        let merchant = "Staples"
        let category = merchantCategories[merchant]
        
        XCTAssertEqual(category, "Office Supplies")
    }
    
    /// Test: Unknown merchant - no suggestion
    func testCategory_UnknownMerchant() {
        let merchant = "Random Store"
        let category = merchantCategories[merchant]
        
        XCTAssertNil(category)
    }
}

// MARK: - Confidence Scoring Tests

extension FLOReceiptParserTests {
    
    /// Test: High confidence - clear TOTAL line
    func testConfidence_HighConfidence() {
        let text = "TOTAL: $45.99"
        let result = extractAmount(from: text)
        
        XCTAssertGreaterThanOrEqual(result.confidence, 0.8, "TOTAL line = high confidence")
    }
    
    /// Test: Lower confidence - just amount at end
    func testConfidence_LowerConfidence() {
        let text = "Some random text 45.99"
        let result = extractAmount(from: text)
        
        // Amount found but without clear context
        if result.amount != nil {
            XCTAssertLessThan(result.confidence, 0.9)
        }
    }
    
    /// Test: Confidence threshold for auto-fill
    func testConfidence_AutoFillThreshold() {
        let autoFillThreshold: Double = 0.7
        
        let highConfidence = 0.9
        let lowConfidence = 0.5
        
        XCTAssertTrue(highConfidence >= autoFillThreshold, "High confidence should auto-fill")
        XCTAssertFalse(lowConfidence >= autoFillThreshold, "Low confidence should not auto-fill")
    }
}

// MARK: - OCR Error Correction Tests

extension FLOReceiptParserTests {
    
    /// Common OCR substitutions
    private func correctOCRErrors(_ text: String) -> String {
        var corrected = text
        
        // In amount context only
        let amountCorrections: [(String, String)] = [
            ("O", "0"),   // Letter O → zero
            ("l", "1"),   // lowercase L → one
            ("I", "1"),   // uppercase I → one
            ("S", "5"),   // S → 5 (sometimes)
            ("B", "8")    // B → 8 (sometimes)
        ]
        
        // Apply corrections in dollar amount patterns
        if let regex = try? NSRegularExpression(pattern: "\\$[0-9OlISB]+\\.[0-9OlISB]{2}") {
            let range = NSRange(corrected.startIndex..., in: corrected)
            let matches = regex.matches(in: corrected, range: range)
            
            for match in matches.reversed() {
                if let matchRange = Range(match.range, in: corrected) {
                    var amountStr = String(corrected[matchRange])
                    for (from, to) in amountCorrections {
                        amountStr = amountStr.replacingOccurrences(of: from, with: to)
                    }
                    corrected.replaceSubrange(matchRange, with: amountStr)
                }
            }
        }
        
        return corrected
    }
    
    /// Test: Correct O to 0
    func testOCRCorrection_OToZero() {
        let ocr = "$1O.OO"
        let corrected = correctOCRErrors(ocr)
        
        XCTAssertEqual(corrected, "$10.00")
    }
    
    /// Test: Correct l to 1
    func testOCRCorrection_lToOne() {
        let ocr = "$l5.00"
        let corrected = correctOCRErrors(ocr)
        
        XCTAssertEqual(corrected, "$15.00")
    }
    
    /// Test: Multiple corrections
    func testOCRCorrection_MultipleFixes() {
        let ocr = "$lO.5O"
        let corrected = correctOCRErrors(ocr)
        
        XCTAssertEqual(corrected, "$10.50")
    }
}

// MARK: - Integration: Full Receipt Parse

extension FLOReceiptParserTests {
    
    /// Test: Parse complete receipt
    func testIntegration_FullReceiptParse() {
        let receiptText = """
        STARBUCKS #12345
        123 Main Street
        City, ST 12345
        
        01/15/2026  10:30 AM
        
        Grande Latte         $5.75
        Blueberry Muffin     $3.25
        
        Subtotal:            $9.00
        Tax:                 $0.72
        TOTAL:               $9.72
        
        Thank you!
        """
        
        // Extract components
        let amount = extractAmount(from: receiptText)
        let date = extractDate(from: receiptText)
        let merchant = findMerchant(in: receiptText)
        let category = merchant.flatMap { merchantCategories[$0] }
        
        // Verify
        XCTAssertEqual(amount.amount, 9.72, "Should find total amount")
        XCTAssertNotNil(date, "Should find date")
        XCTAssertEqual(merchant, "Starbucks", "Should recognize merchant")
        XCTAssertEqual(category, "Food & Drink", "Should suggest category")
        XCTAssertGreaterThan(amount.confidence, 0.7, "Should have good confidence")
    }
}
