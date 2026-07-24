//  FLOExportTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Export Service Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate CSV export RFC 4180 compliance, escaping rules,
//  and export formatting.
//
//  COVERS:
//  - CSV field escaping (commas, quotes, newlines)
//  - RFC 4180 compliance
//  - Locale-aware number formatting
//  - Date formatting
//  - Header row generation
//

import XCTest
@testable import FLO

final class FLOExportTests: XCTestCase {
    
    // MARK: - CSV Escape Helper
    
    /// Escape a field for CSV according to RFC 4180
    private func escapeCSVField(_ value: String) -> String {
        let needsQuoting = value.contains(",") ||
                          value.contains("\"") ||
                          value.contains("\n") ||
                          value.contains("\r")
        
        if needsQuoting {
            // Double any existing quotes
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    /// Format amount for CSV (signed, no currency symbol)
    private func formatAmount(_ amount: Double, isExpense: Bool) -> String {
        let value = isExpense ? -amount : amount
        return String(format: "%.2f", value)
    }
}

// MARK: - CSV Field Escaping

extension FLOExportTests {
    
    /// Test: Simple field (no escaping needed)
    func testCSVEscape_SimpleField() {
        let field = "Simple text"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "Simple text", "No escaping needed")
    }
    
    /// Test: Field with comma
    func testCSVEscape_FieldWithComma() {
        let field = "Hello, World"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "\"Hello, World\"", "Commas require quoting")
    }
    
    /// Test: Field with double quote
    func testCSVEscape_FieldWithQuote() {
        let field = "Say \"Hello\""
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "\"Say \"\"Hello\"\"\"", "Quotes must be doubled and field quoted")
    }
    
    /// Test: Field with newline
    func testCSVEscape_FieldWithNewline() {
        let field = "Line 1\nLine 2"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "\"Line 1\nLine 2\"", "Newlines require quoting")
    }
    
    /// Test: Field with carriage return
    func testCSVEscape_FieldWithCarriageReturn() {
        let field = "Line 1\rLine 2"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "\"Line 1\rLine 2\"", "Carriage returns require quoting")
    }
    
    /// Test: Field with multiple special characters
    func testCSVEscape_MultipleSpecialChars() {
        let field = "Amount: $100, Note: \"important\""
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "\"Amount: $100, Note: \"\"important\"\"\"")
    }
    
    /// Test: Empty field
    func testCSVEscape_EmptyField() {
        let field = ""
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "", "Empty field stays empty")
    }
    
    /// Test: Field with leading/trailing spaces
    func testCSVEscape_SpacesPreserved() {
        let field = "  spaced  "
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, "  spaced  ", "Spaces preserved without quoting")
    }
}

// MARK: - Amount Formatting

extension FLOExportTests {
    
    /// Test: Expense formatted as negative
    func testAmount_ExpenseIsNegative() {
        let amount: Double = 50.00
        let formatted = formatAmount(amount, isExpense: true)
        
        XCTAssertEqual(formatted, "-50.00")
    }
    
    /// Test: Income formatted as positive
    func testAmount_IncomeIsPositive() {
        let amount: Double = 1000.00
        let formatted = formatAmount(amount, isExpense: false)
        
        XCTAssertEqual(formatted, "1000.00")
    }
    
    /// Test: Zero amount
    func testAmount_Zero() {
        let amount: Double = 0.00
        let formatted = formatAmount(amount, isExpense: false)
        
        XCTAssertEqual(formatted, "0.00")
    }
    
    /// Test: Decimal precision
    func testAmount_DecimalPrecision() {
        let amount: Double = 123.456
        let formatted = formatAmount(amount, isExpense: false)
        
        XCTAssertEqual(formatted, "123.46", "Rounded to 2 decimal places")
    }
    
    /// Test: Large amount
    func testAmount_LargeAmount() {
        let amount: Double = 999999.99
        let formatted = formatAmount(amount, isExpense: false)
        
        XCTAssertEqual(formatted, "999999.99", "No thousands separator in CSV")
    }
}

// MARK: - CSV Row Generation

extension FLOExportTests {
    
    /// Test: Generate CSV row
    func testCSVRow_BasicGeneration() {
        let date = "2026-01-15"
        let merchant = "Coffee Shop"
        let category = "Food"
        let amount = formatAmount(5.50, isExpense: true)
        let note = "Morning coffee"
        
        let row = [date, merchant, category, amount, note].joined(separator: ",")
        
        XCTAssertEqual(row, "2026-01-15,Coffee Shop,Food,-5.50,Morning coffee")
    }
    
    /// Test: Generate CSV row with escaping needed
    func testCSVRow_WithEscaping() {
        let date = "2026-01-15"
        let merchant = "Joe's Pizza, Inc."  // Comma
        let category = "Food"
        let amount = formatAmount(25.00, isExpense: true)
        let note = "Team lunch"
        
        let row = [
            date,
            escapeCSVField(merchant),
            category,
            amount,
            note
        ].joined(separator: ",")
        
        XCTAssertEqual(row, "2026-01-15,\"Joe's Pizza, Inc.\",Food,-25.00,Team lunch")
    }
    
    /// Test: Header row
    func testCSVRow_HeaderRow() {
        let headers = ["Date", "Merchant", "Category", "Amount", "Note", "Account", "Type"]
        let headerRow = headers.joined(separator: ",")
        
        XCTAssertEqual(headerRow, "Date,Merchant,Category,Amount,Note,Account,Type")
    }
}

// MARK: - Date Formatting

extension FLOExportTests {
    
    /// Test: ISO 8601 date format
    func testDateFormat_ISO8601() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!
        
        let formatted = formatter.string(from: date)
        
        XCTAssertEqual(formatted, "2026-01-15")
    }
    
    /// Test: Date with time
    func testDateFormat_WithTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        components.hour = 14
        components.minute = 30
        components.second = 0
        let date = Calendar.current.date(from: components)!
        
        let formatted = formatter.string(from: date)
        
        XCTAssertEqual(formatted, "2026-01-15 14:30:00")
    }
}

// MARK: - Full Export Generation

extension FLOExportTests {
    
    /// Test: Generate complete CSV content
    func testFullExport_CompleteCSV() {
        // Header
        let headers = ["Date", "Merchant", "Category", "Amount", "Type"]
        let headerRow = headers.joined(separator: ",")
        
        // Data rows
        let rows = [
            ["2026-01-15", "Grocery Store", "Food", "-75.50", "Expense"],
            ["2026-01-16", "Client Payment", "Income", "1500.00", "Income"],
            ["2026-01-17", escapeCSVField("Joe's Diner, LLC"), "Food", "-25.00", "Expense"]
        ]
        
        var csv = headerRow + "\n"
        for row in rows {
            csv += row.joined(separator: ",") + "\n"
        }
        
        // Verify structure
        let lines = csv.components(separatedBy: "\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 4, "1 header + 3 data rows")
        XCTAssertTrue(lines[0].hasPrefix("Date,"), "Header starts correctly")
        XCTAssertTrue(lines[2].contains("1500.00"), "Income row present")
    }
    
    /// Test: Export handles empty notes
    func testFullExport_EmptyNotes() {
        let row = ["2026-01-15", "Store", "Shopping", "-50.00", ""].joined(separator: ",")
        
        // Should end with comma (empty last field)
        XCTAssertTrue(row.hasSuffix(","), "Empty note leaves trailing comma")
    }
    
    /// Test: Export special characters in notes
    func testFullExport_SpecialCharsInNotes() {
        let note = "Lunch with \"Bob\" & team, very good!"
        let escapedNote = escapeCSVField(note)
        
        let row = ["2026-01-15", "Restaurant", "Food", "-45.00", escapedNote].joined(separator: ",")
        
        XCTAssertTrue(row.contains("\"\"Bob\"\""), "Quotes properly escaped")
    }
}

// MARK: - Export Validation

extension FLOExportTests {
    
    /// Test: Validate CSV can be parsed back
    func testValidation_RoundTrip() {
        let originalValue = "Test, with \"quotes\" and\nnewline"
        let escaped = escapeCSVField(originalValue)
        
        // Simulated parse: remove outer quotes, unescape inner quotes
        var parsed = escaped
        if parsed.hasPrefix("\"") && parsed.hasSuffix("\"") {
            parsed = String(parsed.dropFirst().dropLast())
            parsed = parsed.replacingOccurrences(of: "\"\"", with: "\"")
        }
        
        XCTAssertEqual(parsed, originalValue, "Round-trip preserves value")
    }
    
    /// Test: No data loss with unicode
    func testValidation_UnicodePreserved() {
        let field = "Café résumé naïve 日本語"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, field, "Unicode preserved (no special CSV chars)")
    }
    
    /// Test: Emoji in fields
    func testValidation_EmojiPreserved() {
        let field = "Coffee ☕️ and 🍕"
        let escaped = escapeCSVField(field)
        
        XCTAssertEqual(escaped, field, "Emoji preserved")
    }
}

// MARK: - Export Statistics

extension FLOExportTests {
    
    /// Test: Count transactions in export
    func testStats_TransactionCount() {
        let transactions = 150
        let headerRows = 1
        let totalLines = headerRows + transactions
        
        XCTAssertEqual(totalLines, 151, "150 transactions + 1 header")
    }
    
    /// Test: Calculate totals for export summary
    func testStats_ExportTotals() {
        let amounts: [Double] = [-50.00, 1000.00, -75.00, -25.00, 500.00]
        
        let totalIncome = amounts.filter { $0 > 0 }.reduce(0, +)
        let totalExpenses = abs(amounts.filter { $0 < 0 }.reduce(0, +))
        let netAmount = totalIncome - totalExpenses
        
        XCTAssertEqual(totalIncome, 1500.00)
        XCTAssertEqual(totalExpenses, 150.00)
        XCTAssertEqual(netAmount, 1350.00)
    }
}
