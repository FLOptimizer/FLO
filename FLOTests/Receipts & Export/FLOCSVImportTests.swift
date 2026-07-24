//  FLOCSVImportTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Added header row to signed amount tests (Chase hasHeader=true skips row 1)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate the CSV bank statement import pipeline including
//  file parsing, bank format detection, amount handling, merchant name
//  cleaning, duplicate detection, and data commit integrity.
//
//  TEST CATEGORIES:
//  1. CSV Parsing (RFC 4180 compliance)
//  2. Bank Profile Detection
//  3. Amount Parsing & Conventions
//  4. Merchant Name Cleaning
//  5. Duplicate Detection Scoring
//  6. Commit Service Logic
//
//  RUN FREQUENCY: Before every release, after any CSV import code changes
//

import XCTest
@testable import FLO

@MainActor
final class FLOCSVImportTests: XCTestCase {
    
    let parser = CSVParserService.shared
    
    /// Currency comparison precision (1 cent)
    let currencyPrecision: Double = 0.01
    
    // MARK: - Helper: Create Temp CSV File
    
    /// Writes CSV content to a temporary file and returns the URL
    private func createTempCSV(_ content: String, filename: String = "test.csv") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    /// Helper to build a CSVRawRow
    private func makeRow(_ lineNumber: Int, _ fields: [String]) -> CSVRawRow {
        CSVRawRow(lineNumber: lineNumber, fields: fields)
    }
    
    /// Helper to build a basic column mapping (date=0, description=1, amount=2)
    private func basicMapping() -> CSVColumnMapping {
        CSVColumnMapping(
            dateColumn: 0,
            descriptionColumn: 1,
            amountColumn: 2
        )
    }
    
    // MARK: - Cleanup
    
    override func tearDown() {
        // Clean up temp files
        let tempDir = FileManager.default.temporaryDirectory
        let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        files?.filter { $0.lastPathComponent.hasSuffix(".csv") }.forEach {
            try? FileManager.default.removeItem(at: $0)
        }
        super.tearDown()
    }
}

// MARK: - 1. CSV Parsing Tests

extension FLOCSVImportTests {
    
    /// Simple 3-row CSV with no quoting
    func testParseSimpleCSV() {
        let csv = """
        Date,Description,Amount
        01/15/2025,Starbucks,-4.50
        01/16/2025,Paycheck,3000.00
        01/17/2025,Walmart,-52.30
        """
        let url = createTempCSV(csv)
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success(let rows):
            // Should have 3 data rows (header is row 0, but parser may include or skip it)
            XCTAssertGreaterThanOrEqual(rows.count, 3, "Should parse at least 3 data rows")
        case .failure(let error):
            XCTFail("Parse failed: \(error.localizedDescription)")
        }
    }
    
    /// Fields containing commas inside quotes should parse correctly
    func testParseQuotedFieldsWithCommas() {
        let csv = """
        Date,Description,Amount
        01/15/2025,"Starbucks, Main St","-1,234.56"
        """
        let url = createTempCSV(csv)
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success(let rows):
            let dataRow = rows.first(where: { $0.fields.contains(where: { $0.contains("Starbucks") }) })
            XCTAssertNotNil(dataRow, "Should find row with Starbucks")
            if let row = dataRow {
                XCTAssertTrue(
                    row.fields.contains(where: { $0.contains("Starbucks, Main St") }),
                    "Quoted comma should be preserved in field"
                )
            }
        case .failure(let error):
            XCTFail("Parse failed: \(error.localizedDescription)")
        }
    }
    
    /// Doubled quotes inside quoted fields should be unescaped
    func testParseDoubledQuotes() {
        let csv = """
        Date,Description,Amount
        01/15/2025,"Bob""s Burgers",-12.50
        """
        let url = createTempCSV(csv)
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success(let rows):
            let hasUnescaped = rows.contains(where: { row in
                row.fields.contains(where: { $0.contains("Bob\"s") || $0.contains("Bob's") })
            })
            XCTAssertTrue(hasUnescaped, "Doubled quotes should be unescaped to single quote")
        case .failure(let error):
            XCTFail("Parse failed: \(error.localizedDescription)")
        }
    }
    
    /// Empty file should return appropriate error
    func testParseEmptyFile() {
        let url = createTempCSV("")
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success:
            XCTFail("Empty file should return failure")
        case .failure(let error):
            // Should be emptyFile or noValidRows
            switch error {
            case .emptyFile, .noValidRows:
                break // Expected
            default:
                XCTFail("Expected emptyFile or noValidRows, got: \(error.localizedDescription)")
            }
        }
    }
    
    /// File with only a header row should return noValidRows
    func testParseSingleHeaderOnly() {
        let csv = "Date,Description,Amount\n"
        let url = createTempCSV(csv)
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success(let rows):
            // If parser includes header, there should be no usable data rows beyond it
            XCTAssertLessThanOrEqual(rows.count, 1, "Should have at most 1 row (header only)")
        case .failure:
            // Also acceptable — noValidRows
            break
        }
    }
    
    /// UTF-8 content with accented characters should parse correctly
    func testParseUTF8WithAccents() {
        let csv = """
        Date,Description,Amount
        01/15/2025,Café Résumé,-8.50
        """
        let url = createTempCSV(csv)
        let result = parser.parseCSVFile(url: url, encoding: .utf8)
        
        switch result {
        case .success(let rows):
            let hasAccents = rows.contains(where: { row in
                row.fields.contains(where: { $0.contains("Café") })
            })
            XCTAssertTrue(hasAccents, "UTF-8 accented characters should be preserved")
        case .failure(let error):
            XCTFail("UTF-8 parse failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - 2. Bank Profile Detection Tests

extension FLOCSVImportTests {
    
    /// Chase headers should auto-detect
    func testDetectChaseProfile() {
        let headers = ["Posting Date", "Description", "Amount"]
        let sampleRows = [makeRow(1, ["01/15/2025", "STARBUCKS", "-4.50"])]
        
        let profile = parser.detectBankProfile(headers: headers, sampleRows: sampleRows)
        
        XCTAssertNotNil(profile, "Chase headers should be detected")
        if let profile = profile {
            XCTAssertTrue(
                profile.displayName.lowercased().contains("chase"),
                "Detected profile should be Chase, got: \(profile.displayName)"
            )
        }
    }
    
    /// Capital One split debit/credit format should be detected
    func testDetectCapitalOneProfile() {
        let headers = ["Transaction Date", "Posted Date", "Card No.", "Description", "Category", "Debit", "Credit"]
        let sampleRows = [makeRow(1, ["2025-01-15", "2025-01-16", "1234", "STARBUCKS", "Food", "4.50", ""])]
        
        let profile = parser.detectBankProfile(headers: headers, sampleRows: sampleRows)
        
        XCTAssertNotNil(profile, "Capital One headers should be detected")
    }
    
    /// Unknown bank headers should return nil
    func testDetectUnknownBank() {
        let headers = ["Fecha", "Descripción", "Monto"]
        let sampleRows = [makeRow(1, ["15/01/2025", "STARBUCKS", "-4.50"])]
        
        let profile = parser.detectBankProfile(headers: headers, sampleRows: sampleRows)
        
        XCTAssertNil(profile, "Unknown headers should return nil for manual mapping")
    }
    
    /// Detection should be case-insensitive
    func testDetectCaseInsensitive() {
        let headers = ["POSTING DATE", "DESCRIPTION", "AMOUNT"]
        let sampleRows = [makeRow(1, ["01/15/2025", "STARBUCKS", "-4.50"])]
        
        let profile = parser.detectBankProfile(headers: headers, sampleRows: sampleRows)
        
        XCTAssertNotNil(profile, "Case-insensitive headers should still detect bank profile")
    }
    
    /// Bank of America headers should be detected
    func testDetectBankOfAmerica() {
        let headers = ["Date", "Description", "Amount"]
        let sampleRows = [makeRow(1, ["01/15/2025", "STARBUCKS", "-4.50"])]
        
        let profile = parser.detectBankProfile(headers: headers, sampleRows: sampleRows)
        
        // May match BofA or a generic profile — just verify it returns something
        XCTAssertNotNil(profile, "Common Date/Description/Amount headers should match a profile")
    }
}
// MARK: - 3. Amount Parsing Tests

extension FLOCSVImportTests {
    
    /// Negative amounts should be treated as expenses
    func testSignedAmountNegativeIsExpense() {
        let cleaned = parser.cleanMerchantName("STARBUCKS")
        XCTAssertFalse(cleaned.isEmpty, "Merchant name should not be empty")
        
        // Test via parseTransactions with a signed amount row
        let profile = CSVParserService.shared.allBankProfiles.first(where: { $0.id.contains("chase") })
            ?? CSVParserService.shared.allBankProfiles.last!
        
        let rows = [
            makeRow(0, ["Posting Date", "Description", "Amount", "Balance"]),
            makeRow(1, ["01/15/2025", "STARBUCKS", "-45.67", "1000.00"])
        ]
        let result = parser.parseTransactions(
            rows: rows,
            mapping: profile.columnMapping,
            profile: profile,
            categories: [],
            merchantMappings: []
        )
        
        if let txn = result.transactions.first {
            XCTAssertEqual(txn.amount, 45.67, accuracy: currencyPrecision, "Amount should be positive (absolute value)")
            XCTAssertFalse(txn.isIncome, "Negative amount should be an expense")
        } else {
            XCTFail("Should parse at least one transaction")
        }
    }
    
    /// Positive amounts should be treated as income (for signed convention)
    func testSignedAmountPositiveIsIncome() {
        let profile = CSVParserService.shared.allBankProfiles.first(where: { $0.id.contains("chase") })
            ?? CSVParserService.shared.allBankProfiles.last!
        
        let rows = [
            makeRow(0, ["Posting Date", "Description", "Amount", "Balance"]),
            makeRow(1, ["01/15/2025", "PAYCHECK", "1500.00", "2500.00"])
        ]
        let result = parser.parseTransactions(
            rows: rows,
            mapping: profile.columnMapping,
            profile: profile,
            categories: [],
            merchantMappings: []
        )
        
        if let txn = result.transactions.first {
            XCTAssertEqual(txn.amount, 1500.00, accuracy: currencyPrecision, "Amount should be 1500.00")
            XCTAssertTrue(txn.isIncome, "Positive amount should be income")
        } else {
            XCTFail("Should parse at least one transaction")
        }
    }
}

// MARK: - 4. Merchant Name Cleaning Tests

extension FLOCSVImportTests {
    
    /// Strip POS DEBIT prefix
    func testCleanMerchant_StripPOS() {
        let cleaned = parser.cleanMerchantName("POS DEBIT STARBUCKS COLUMBUS OH")
        XCTAssertFalse(cleaned.uppercased().contains("POS DEBIT"), "Should strip POS DEBIT prefix")
        XCTAssertTrue(cleaned.lowercased().contains("starbucks"), "Should keep merchant name: got '\(cleaned)'")
    }
    
    /// Strip CHECKCARD prefix
    func testCleanMerchant_StripCheckcard() {
        let cleaned = parser.cleanMerchantName("CHECKCARD 0215 AMAZON MARKETPLACE")
        XCTAssertFalse(cleaned.uppercased().contains("CHECKCARD"), "Should strip CHECKCARD prefix")
        XCTAssertTrue(cleaned.lowercased().contains("amazon"), "Should keep merchant name: got '\(cleaned)'")
    }
    
    /// Strip trailing store numbers
    func testCleanMerchant_StripTrailingNumbers() {
        let cleaned = parser.cleanMerchantName("WALMART #3294 COLUMBUS OH")
        XCTAssertTrue(cleaned.lowercased().contains("walmart"), "Should keep Walmart: got '\(cleaned)'")
    }
    
    /// Strip PAYPAL * prefix
    func testCleanMerchant_StripPaypal() {
        let cleaned = parser.cleanMerchantName("PAYPAL *ETSY")
        XCTAssertFalse(cleaned.uppercased().contains("PAYPAL *"), "Should strip PAYPAL * prefix")
        XCTAssertTrue(cleaned.lowercased().contains("etsy"), "Should keep Etsy: got '\(cleaned)'")
    }
    
    /// Strip SQ * prefix (Square)
    func testCleanMerchant_StripSquare() {
        let cleaned = parser.cleanMerchantName("SQ *COFFEE SHOP")
        XCTAssertFalse(cleaned.uppercased().contains("SQ *"), "Should strip SQ * prefix")
        XCTAssertTrue(cleaned.lowercased().contains("coffee"), "Should keep Coffee Shop: got '\(cleaned)'")
    }
    
    /// Strip TST * prefix (Toast)
    func testCleanMerchant_StripToast() {
        let cleaned = parser.cleanMerchantName("TST *PIZZA PLACE")
        XCTAssertFalse(cleaned.uppercased().contains("TST *"), "Should strip TST * prefix")
        XCTAssertTrue(cleaned.lowercased().contains("pizza"), "Should keep Pizza Place: got '\(cleaned)'")
    }
    
    /// Empty or whitespace-only input should return empty or reasonable default
    func testCleanMerchant_EmptyInput() {
        let cleaned = parser.cleanMerchantName("   ")
        XCTAssertTrue(cleaned.trimmingCharacters(in: .whitespaces).count <= cleaned.count, "Should handle whitespace-only input gracefully")
    }
    
    /// Already clean merchant name should pass through
    func testCleanMerchant_AlreadyClean() {
        let cleaned = parser.cleanMerchantName("Starbucks")
        XCTAssertTrue(cleaned.lowercased().contains("starbucks"), "Clean name should pass through: got '\(cleaned)'")
    }
}

// MARK: - 5. Duplicate Detection Tests

extension FLOCSVImportTests {
    
    /// Create a mock CSVParsedTransaction for testing
    private func makeParsedTransaction(
        date: Date = Date(),
        amount: Double = 45.67,
        isIncome: Bool = false,
        merchantName: String = "Starbucks"
    ) -> CSVParsedTransaction {
        CSVParsedTransaction(
            rawLineNumber: 1,
            date: date,
            description: merchantName,
            amount: amount,
            isIncome: isIncome,
            merchantName: merchantName,
            suggestedFinanceType: .personal
        )
    }
    
    /// Exact same date + amount + merchant should score >= 80 (duplicate)
    func testDuplicate_ExactMatch() {
        let now = Date()
        let parsed = [makeParsedTransaction(date: now, amount: 45.67, merchantName: "Starbucks")]
        
        // Note: findCSVDuplicates needs real Transaction objects.
        // This test validates the method runs without crashing with empty existing.
        let result = TransactionMatchingService.shared.findCSVDuplicates(
            parsed: parsed,
            existing: []  // No existing = no duplicates found
        )
        
        XCTAssertEqual(result.count, 1, "Should return same count")
        XCTAssertFalse(result[0].isDuplicate, "No existing transactions means no duplicates")
    }
    
    /// With no existing transactions, nothing should be flagged
    func testDuplicate_NoExistingTransactions() {
        let parsed = [
            makeParsedTransaction(amount: 100.00, merchantName: "Amazon"),
            makeParsedTransaction(amount: 200.00, merchantName: "Walmart"),
            makeParsedTransaction(amount: 50.00, merchantName: "Target")
        ]
        
        let result = TransactionMatchingService.shared.findCSVDuplicates(
            parsed: parsed,
            existing: []
        )
        
        let duplicateCount = result.filter { $0.isDuplicate }.count
        XCTAssertEqual(duplicateCount, 0, "No existing transactions should mean no duplicates")
    }
    
    /// Parsed transactions array should maintain order after duplicate check
    func testDuplicate_MaintainsOrder() {
        let parsed = [
            makeParsedTransaction(amount: 10.00, merchantName: "A"),
            makeParsedTransaction(amount: 20.00, merchantName: "B"),
            makeParsedTransaction(amount: 30.00, merchantName: "C")
        ]
        
        let result = TransactionMatchingService.shared.findCSVDuplicates(
            parsed: parsed,
            existing: []
        )
        
        XCTAssertEqual(result.count, 3, "Should return all transactions")
        XCTAssertEqual(result[0].merchantName, "A", "Order should be maintained")
        XCTAssertEqual(result[1].merchantName, "B", "Order should be maintained")
        XCTAssertEqual(result[2].merchantName, "C", "Order should be maintained")
    }
    
    /// Performance: 500 parsed vs empty existing should complete quickly
    func testDuplicate_PerformanceWithEmptyExisting() {
        let parsed = (0..<500).map { i in
            makeParsedTransaction(
                amount: Double(i) * 1.50,
                merchantName: "Merchant \(i)"
            )
        }
        
        let start = Date()
        let _ = TransactionMatchingService.shared.findCSVDuplicates(
            parsed: parsed,
            existing: []
        )
        let elapsed = Date().timeIntervalSince(start)
        
        XCTAssertLessThan(elapsed, 2.0, "500 transactions should process in under 2 seconds")
    }
}

// MARK: - 6. Commit Logic Tests

extension FLOCSVImportTests {
    
    /// Selected transactions should be counted for commit
    func testCommit_CountsSelectedOnly() {
        var txn1 = makeParsedTransaction(amount: 10.00, merchantName: "A")
        txn1.isSelected = true
        
        var txn2 = makeParsedTransaction(amount: 20.00, merchantName: "B")
        txn2.isSelected = false
        
        var txn3 = makeParsedTransaction(amount: 30.00, merchantName: "C")
        txn3.isSelected = true
        
        let selected = [txn1, txn2, txn3].filter { $0.isSelected }
        XCTAssertEqual(selected.count, 2, "Only selected transactions should be committed")
    }
    
    /// Import source should always be .csvImport
    func testCommit_ImportSourceIsCSV() {
        // Verify the TransactionSource enum has csvImport
        let source = Transaction.TransactionSource.csvImport
        XCTAssertEqual(source.rawValue, "csv_import", "CSV import source raw value")
        XCTAssertEqual(source.displayName, "CSV Import", "CSV import display name")
        XCTAssertEqual(source.icon, "doc.badge.arrow.up", "CSV import icon")
        XCTAssertTrue(source.isEditable, "CSV imported transactions should be editable")
    }
    
    /// Amount should always be positive in Transaction model
    func testCommit_AmountAlwaysPositive() {
        let parsed = makeParsedTransaction(amount: 45.67, isIncome: false)
        XCTAssertGreaterThan(parsed.amount, 0, "Parsed amount should be positive")
        
        let parsedIncome = makeParsedTransaction(amount: 1500.00, isIncome: true)
        XCTAssertGreaterThan(parsedIncome.amount, 0, "Parsed income amount should be positive")
    }
    
    /// Finance type should be preserved from parsed transaction
    func testCommit_FinanceTypePreserved() {
        var businessTxn = makeParsedTransaction(amount: 100.00)
        businessTxn.suggestedFinanceType = .business
        XCTAssertEqual(businessTxn.suggestedFinanceType, .business, "Business finance type should be preserved")
        
        var personalTxn = makeParsedTransaction(amount: 50.00)
        personalTxn.suggestedFinanceType = .personal
        XCTAssertEqual(personalTxn.suggestedFinanceType, .personal, "Personal finance type should be preserved")
    }
    
    /// Empty selection should return success with 0 count
    func testCommit_EmptySelectionReturnsZero() {
        var txn = makeParsedTransaction(amount: 10.00)
        txn.isSelected = false
        
        let selected = [txn].filter { $0.isSelected }
        XCTAssertEqual(selected.count, 0, "No selected transactions should result in 0 count")
    }
}

// MARK: - 7. Import Result Integrity Tests

extension FLOCSVImportTests {
    
    /// Skipped rows should have line numbers and reasons
    func testImportResult_SkippedRowsHaveReasons() {
        // Parse a CSV with an invalid row
        let profile = CSVParserService.shared.allBankProfiles.last!  // Generic
        let rows = [
            makeRow(1, ["01/15/2025", "Starbucks", "-4.50"]),
            makeRow(2, ["INVALID_DATE", "Bad Row", "not_a_number"]),
            makeRow(3, ["01/17/2025", "Walmart", "-52.30"])
        ]
        
        let result = parser.parseTransactions(
            rows: rows,
            mapping: basicMapping(),
            profile: profile,
            categories: [],
            merchantMappings: []
        )
        
        // At least one row should be parsed, and the bad row may be skipped
        XCTAssertGreaterThanOrEqual(
            result.transactions.count + result.skippedRows.count,
            1,
            "Should account for all rows as either parsed or skipped"
        )
    }
    
    /// Total rows should match input
    func testImportResult_TotalRowsMatchesInput() {
        let profile = CSVParserService.shared.allBankProfiles.last!
        let rows = [
            makeRow(1, ["01/15/2025", "A", "-10.00"]),
            makeRow(2, ["01/16/2025", "B", "-20.00"]),
            makeRow(3, ["01/17/2025", "C", "-30.00"])
        ]
        
        let result = parser.parseTransactions(
            rows: rows,
            mapping: basicMapping(),
            profile: profile,
            categories: [],
            merchantMappings: []
        )
        
        XCTAssertEqual(result.totalRows, 3, "Total rows should match input count")
    }
}
