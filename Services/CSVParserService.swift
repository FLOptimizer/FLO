//  CSVParserService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Added TST * (with space) prefix for Toast POS
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.0:
//  ✅ ADDED: dynamicColumnMapping() — resolves columns by header name instead of hardcoded index
//  ✅ ADDED: Handles alternate CSV export formats (e.g., Chase 16-column vs 4-column)
//  ✅ ADDED: bankCategory field extraction from CSV Category column
//  ✅ ADDED: DEBIT-DC prefix stripping in cleanMerchantName()
//  ✅ FIXED: Description/Category columns now found dynamically even when bank profile matches
//
//  CHANGES v1.1:
//  - Added allBankProfiles public property for UI access
//
//  Handles CSV file reading, RFC 4180 parsing, bank profile detection,
//  and conversion to CSVParsedTransaction objects.
//

import Foundation
import SwiftData
import os.log

@MainActor
final class CSVParserService {
    
    static let shared = CSVParserService()
    
    private init() {}
    
    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CSVParserService"
    )
    
    // MARK: - Public Properties
    
    /// All available bank profiles for user selection
    var allBankProfiles: [CSVBankProfile] {
        return CSVBankProfile.builtInProfiles
    }
    
    // MARK: - File Reading & Parsing
    
    /// Reads a CSV file and parses it into raw rows
    /// - Parameters:
    ///   - url: File URL to read
    ///   - encoding: Optional encoding override (default: auto-detect UTF-8 → Latin-1)
    /// - Returns: Result containing array of CSVRawRow or error
    func parseCSVFile(
        url: URL,
        encoding: String.Encoding? = nil
    ) -> Result<[CSVRawRow], CSVImportError> {
        
        // Try to read file with specified or auto-detected encoding
        guard let fileContents = readFile(url: url, encoding: encoding) else {
            Self.logger.error("Failed to read CSV file at \(url.path)")
            return .failure(.fileReadFailed)
        }
        
        if fileContents.isEmpty {
            Self.logger.warning("CSV file is empty")
            return .failure(.emptyFile)
        }
        
        // Parse CSV respecting RFC 4180 quoting rules
        let rows = parseCSVString(fileContents)
        
        if rows.isEmpty {
            Self.logger.warning("No rows parsed from CSV file")
            return .failure(.emptyFile)
        }
        
        Self.logger.info("Successfully parsed \(rows.count) rows from CSV file")
        return .success(rows)
    }
    
    /// Reads file with encoding fallback (UTF-8 → Latin-1)
    private func readFile(url: URL, encoding: String.Encoding?) -> String? {
        if let encoding = encoding {
            return try? String(contentsOf: url, encoding: encoding)
        }
        
        // Try UTF-8 first
        if let contents = try? String(contentsOf: url, encoding: .utf8) {
            Self.logger.debug("Read file with UTF-8 encoding")
            return contents
        }
        
        // Fallback to Latin-1 (ISO-8859-1)
        if let contents = try? String(contentsOf: url, encoding: .isoLatin1) {
            Self.logger.debug("Read file with Latin-1 encoding (fallback)")
            return contents
        }
        
        Self.logger.error("Unable to read file with any supported encoding")
        return nil
    }
    
    /// Parses CSV string into raw rows respecting RFC 4180 quoting
    /// Handles: quoted fields with commas, doubled quotes, newlines in quoted fields
    private func parseCSVString(_ csvString: String) -> [CSVRawRow] {
        var rows: [CSVRawRow] = []
        var currentFields: [String] = []
        var currentField = ""
        var insideQuotes = false
        var lineNumber = 1
        
        let characters = Array(csvString)
        var i = 0
        
        while i < characters.count {
            let char = characters[i]
            
            switch char {
            case "\"":
                if insideQuotes {
                    // Check for doubled quote (escaped quote)
                    if i + 1 < characters.count && characters[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 1  // Skip next quote
                    } else {
                        // End of quoted field
                        insideQuotes = false
                    }
                } else {
                    // Start of quoted field (only if at field start)
                    if currentField.isEmpty {
                        insideQuotes = true
                    } else {
                        // Quote in middle of unquoted field - just include it
                        currentField.append(char)
                    }
                }
                
            case ",":
                if insideQuotes {
                    currentField.append(char)
                } else {
                    // End of field
                    currentFields.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                }
                
            case "\n", "\r":
                if insideQuotes {
                    currentField.append(char)
                } else {
                    // End of row
                    currentFields.append(currentField.trimmingCharacters(in: .whitespaces))
                    
                    if !currentFields.isEmpty && !(currentFields.count == 1 && currentFields[0].isEmpty) {
                        rows.append(CSVRawRow(lineNumber: lineNumber, fields: currentFields))
                    }
                    
                    currentFields = []
                    currentField = ""
                    lineNumber += 1
                    
                    // Skip \r\n pairs
                    if char == "\r" && i + 1 < characters.count && characters[i + 1] == "\n" {
                        i += 1
                    }
                }
                
            default:
                currentField.append(char)
            }
            
            i += 1
        }
        
        // Handle last field and row
        currentFields.append(currentField.trimmingCharacters(in: .whitespaces))
        if !currentFields.isEmpty && !(currentFields.count == 1 && currentFields[0].isEmpty) {
            rows.append(CSVRawRow(lineNumber: lineNumber, fields: currentFields))
        }
        
        return rows
    }
    
    // MARK: - Bank Profile Detection
    
    /// Detects bank profile based on header row
    /// - Parameters:
    ///   - headers: Header row column names
    ///   - sampleRows: Sample data rows for additional validation
    /// - Returns: Detected CSVBankProfile or nil if no match
    func detectBankProfile(
        headers: [String],
        sampleRows: [CSVRawRow]
    ) -> CSVBankProfile? {
        
        let normalizedHeaders = headers.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        Self.logger.debug("Attempting bank detection with headers: \(normalizedHeaders.joined(separator: ", "))")
        
        for profile in CSVBankProfile.builtInProfiles where profile.id != "generic" {
            let matchCount = profile.headerKeywords.filter { keyword in
                normalizedHeaders.contains { header in
                    header.contains(keyword.lowercased())
                }
            }.count
            
            // Require at least 3 keyword matches for positive detection
            if matchCount >= 3 {
                Self.logger.info("Detected bank profile: \(profile.displayName) (matched \(matchCount) keywords)")
                return profile
            }
        }
        
        Self.logger.info("No bank profile detected - user will need to manually map columns")
        return nil
    }
    
    // MARK: - Dynamic Column Mapping
    
    /// Resolves column indices by matching header names instead of relying on hardcoded indices.
    /// This handles alternate CSV export formats from the same bank (e.g., Chase 4-col vs 16-col).
    /// Falls back to the profile's hardcoded mapping if header-based detection fails.
    func dynamicColumnMapping(
        headers: [String],
        profile: CSVBankProfile
    ) -> CSVColumnMapping {
        
        let normalizedHeaders = headers.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // If the CSV has the same number of columns the profile expects, trust the hardcoded mapping
        let expectedColumnCount = max(
            profile.columnMapping.dateColumn,
            profile.columnMapping.descriptionColumn,
            profile.columnMapping.amountColumn,
            profile.columnMapping.creditColumn ?? 0,
            profile.columnMapping.debitColumn ?? 0,
            profile.columnMapping.categoryColumn ?? 0,
            profile.columnMapping.balanceColumn ?? 0
        ) + 1
        
        if normalizedHeaders.count <= expectedColumnCount + 1 {
            Self.logger.debug("Column count matches profile expectation — using hardcoded mapping")
            return profile.columnMapping
        }
        
        Self.logger.info("CSV has \(normalizedHeaders.count) columns vs expected ~\(expectedColumnCount) — using dynamic header mapping")
        
        // Dynamic lookup by common header names
        let dateColumn = findColumn(in: normalizedHeaders, candidates: [
            "transaction date", "trans. date", "trans date", "posting date", "date"
        ]) ?? profile.columnMapping.dateColumn
        
        let descriptionColumn = findColumn(in: normalizedHeaders, candidates: [
            "description", "memo", "name", "payee", "merchant", "details", "transaction description"
        ]) ?? profile.columnMapping.descriptionColumn
        
        let amountColumn = findColumn(in: normalizedHeaders, candidates: [
            "amount", "transaction amount"
        ]) ?? profile.columnMapping.amountColumn
        
        let categoryColumn = findColumn(in: normalizedHeaders, candidates: [
            "category", "transaction category"
        ])
        
        let debitColumn: Int? = profile.columnMapping.usesSplitColumns
            ? (findColumn(in: normalizedHeaders, candidates: ["debit", "withdrawal"]) ?? profile.columnMapping.debitColumn)
            : nil
        
        let creditColumn: Int? = profile.columnMapping.usesSplitColumns
            ? (findColumn(in: normalizedHeaders, candidates: ["credit", "deposit"]) ?? profile.columnMapping.creditColumn)
            : nil
        
        let balanceColumn = findColumn(in: normalizedHeaders, candidates: [
            "balance", "running balance", "running bal.", "running bal", "available balance"
        ])
        
        let checkNumberColumn = findColumn(in: normalizedHeaders, candidates: [
            "check number", "check serial number", "check #", "check no"
        ])
        
        // Detect credit/debit indicator column (e.g., "Credit Debit Indicator")
        let indicatorColumn = findColumn(in: normalizedHeaders, candidates: [
            "credit debit indicator", "cr/dr", "debit/credit"
        ])
        
        let mapping = CSVColumnMapping(
            dateColumn: dateColumn,
            descriptionColumn: descriptionColumn,
            amountColumn: amountColumn,
            creditColumn: creditColumn,
            debitColumn: debitColumn,
            categoryColumn: categoryColumn,
            checkNumberColumn: checkNumberColumn,
            balanceColumn: balanceColumn,
            indicatorColumn: indicatorColumn
        )
        
        Self.logger.info("Dynamic mapping: date=\(dateColumn), desc=\(descriptionColumn), amount=\(amountColumn), category=\(categoryColumn ?? -1), indicator=\(indicatorColumn ?? -1)")
        
        return mapping
    }
    
    /// Finds the first matching column index from a list of candidate header names
    private func findColumn(in headers: [String], candidates: [String]) -> Int? {
        for candidate in candidates {
            if let index = headers.firstIndex(where: { $0 == candidate }) {
                return index
            }
        }
        // Partial match fallback
        for candidate in candidates {
            if let index = headers.firstIndex(where: { $0.contains(candidate) }) {
                return index
            }
        }
        return nil
    }
    
    // MARK: - Transaction Parsing
    
    /// Converts raw CSV rows into parsed transaction objects
    /// - Parameters:
    ///   - rows: Raw CSV rows
    ///   - mapping: Column mapping configuration
    ///   - profile: Bank profile with date format and amount convention
    ///   - categories: Available categories for auto-categorization
    ///   - merchantMappings: Learned merchant-to-category mappings
    /// - Returns: CSVImportResult with parsed transactions and metadata
    func parseTransactions(
        rows: [CSVRawRow],
        mapping: CSVColumnMapping,
        profile: CSVBankProfile,
        categories: [Category],
        merchantMappings: [MerchantCategoryMapping]
    ) -> CSVImportResult {
        
        var transactions: [CSVParsedTransaction] = []
        var skippedRows: [(lineNumber: Int, reason: String)] = []
        
        // Skip header row if present
        let dataRows = profile.hasHeader ? Array(rows.dropFirst()) : rows
        
        for row in dataRows {
            // Validate row has enough columns
            let requiredColumns = [
                mapping.dateColumn,
                mapping.descriptionColumn,
                mapping.usesSplitColumns ? (mapping.debitColumn ?? 0) : mapping.amountColumn,
                mapping.usesSplitColumns ? (mapping.creditColumn ?? 0) : -1
            ].filter { $0 >= 0 }
            
            let maxColumn = requiredColumns.max() ?? 0
            guard row.fields.count > maxColumn else {
                skippedRows.append((row.lineNumber, "Insufficient columns (expected \(maxColumn + 1), got \(row.fields.count))"))
                continue
            }
            
            // Parse date
            guard let date = parseDate(row.fields[mapping.dateColumn], format: profile.dateFormat) else {
                skippedRows.append((row.lineNumber, "Invalid date format"))
                continue
            }
            
            // Parse amount and determine income/expense
            let amountResult: (amount: Double, isIncome: Bool)?
            
            if mapping.usesSplitColumns {
                amountResult = parseAmountFromSplitColumns(
                    debit: mapping.debitColumn.flatMap { row.fields[safe: $0] } ?? "",
                    credit: mapping.creditColumn.flatMap { row.fields[safe: $0] } ?? ""
                )
            } else if mapping.usesIndicatorColumn,
                      let indicatorIdx = mapping.indicatorColumn,
                      let rawAmount = parseAmount(row.fields[mapping.amountColumn]) {
                // Handle "Credit Debit Indicator" style CSVs (amount always positive)
                let indicator = row.fields[safe: indicatorIdx]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let isCredit = indicator.contains("credit") || indicator.hasPrefix("cr")
                amountResult = (abs(rawAmount), isCredit)
            } else {
                amountResult = parseAmountFromSingleColumn(
                    row.fields[mapping.amountColumn],
                    convention: profile.amountConvention
                )
            }
            
            guard let (amount, isIncome) = amountResult else {
                skippedRows.append((row.lineNumber, "Invalid amount format"))
                continue
            }
            
            // Extract description and clean merchant name
            let rawDescription = row.fields[mapping.descriptionColumn]
            let merchantName = cleanMerchantName(rawDescription)
            
            // Extract bank-provided category if available
            let bankCategory: String? = mapping.categoryColumn.flatMap { column in
                guard let value = row.fields[safe: column],
                      !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Auto-categorize using merchant mappings
            let suggestedCategory = findMatchingCategory(
                merchantName: merchantName,
                merchantMappings: merchantMappings,
                categories: categories
            )
            
            // Extract optional fields
            let checkNumber = mapping.checkNumberColumn.flatMap { row.fields[safe: $0] }
            let runningBalance = mapping.balanceColumn.flatMap { column in
                row.fields[safe: column].flatMap { parseAmount($0) }
            }
            
            // Create parsed transaction
            let transaction = CSVParsedTransaction(
                rawLineNumber: row.lineNumber,
                date: date,
                description: rawDescription,
                amount: amount,
                isIncome: isIncome,
                merchantName: merchantName,
                suggestedCategory: suggestedCategory,
                suggestedFinanceType: .personal,
                checkNumber: checkNumber,
                runningBalance: runningBalance,
                bankCategory: bankCategory
            )
            
            transactions.append(transaction)
        }
        
        Self.logger.info("Parsed \(transactions.count) transactions, skipped \(skippedRows.count) rows")
        
        // Calculate date range
        let dateRange: ClosedRange<Date>? = {
            guard let minDate = transactions.map({ $0.date }).min(),
                  let maxDate = transactions.map({ $0.date }).max() else {
                return nil
            }
            return minDate...maxDate
        }()
        
        return CSVImportResult(
            transactions: transactions,
            skippedRows: skippedRows,
            detectedProfile: profile.id != "generic" ? profile : nil,
            totalRows: rows.count,
            dateRange: dateRange
        )
    }
    
    // MARK: - Merchant Name Cleaning
    
    /// Cleans raw bank descriptions into readable merchant names
    /// Strips common prefixes/suffixes: POS, DEBIT, PURCHASE, etc.
    func cleanMerchantName(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common bank transaction prefixes to strip (case-insensitive)
        let prefixes = [
            "POS DEBIT",
            "POS PURCHASE",
            "POS",
            "DEBIT CARD PURCHASE",
            "DEBIT CARD",
            "DEBIT-DC \\d{4}",    // Chase format: "DEBIT-DC 4875 MERCHANT"
            "DEBIT",
            "PURCHASE AUTHORIZED ON",
            "PURCHASE",
            "CHECKCARD",
            "CHECK CARD",
            "VISA CHECKCARD",
            "VISA CHECK CARD",
            "VISA DEBIT",
            "MASTERCARD DEBIT",
            "MC DEBIT",
            "ELECTRONIC WITHDRAWAL",
            "ELECTRONIC PMT",
            "ACH DEBIT",
            "ACH WITHDRAWAL",
            "SQ *",
            "TST*",
            "TST *",
            "PAYPAL *",
            "VENMO *",
            "ZELLE PAYMENT FROM",
            "ZELLE PAYMENT TO",
        ]
        
        for prefix in prefixes {
            // Handle regex-based prefixes (contain \d)
            if prefix.contains("\\d") {
                if let range = cleaned.range(of: "^(?i)\(prefix)\\s*", options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } else if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Strip trailing transaction numbers and dates
        // Pattern: digits, hashes, dates at end
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+#?\d{4,}\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+\d{2}/\d{2}(/\d{2,4})?\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        // Strip trailing location codes (e.g., "OH", "CA 94103")
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+[A-Z]{2}(\s+\d{5})?\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        // Final trim and title-case
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Title case the result
        cleaned = cleaned.localizedCapitalized
        
        return cleaned.isEmpty ? raw : cleaned
    }
    
    // MARK: - Date Parsing
    
    /// Parses date string using multiple format attempts
    private func parseDate(_ dateString: String, format: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try primary format
        if let date = parseDate(trimmed, withFormat: format) {
            return date
        }
        
        // Try common fallback formats
        let fallbackFormats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "MM/dd/yy",
            "M/d/yy",
            "dd/MM/yyyy",
            "dd/MM/yy",
            "yyyy/MM/dd"
        ]
        
        for fallbackFormat in fallbackFormats where fallbackFormat != format {
            if let date = parseDate(trimmed, withFormat: fallbackFormat) {
                Self.logger.debug("Date parsed using fallback format: \(fallbackFormat)")
                return date
            }
        }
        
        Self.logger.warning("Failed to parse date: '\(dateString)' with format '\(format)'")
        return nil
    }
    
    /// Helper to parse date with specific format
    private func parseDate(_ string: String, withFormat format: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)
    }
    
    // MARK: - Amount Parsing
    
    /// Parses amount from split debit/credit columns
    private func parseAmountFromSplitColumns(debit: String, credit: String) -> (amount: Double, isIncome: Bool)? {
        let debitAmount = parseAmount(debit)
        let creditAmount = parseAmount(credit)
        
        // Exactly one should have a value
        if let debit = debitAmount, creditAmount == nil {
            return (abs(debit), false)  // Debit = expense
        } else if let credit = creditAmount, debitAmount == nil {
            return (abs(credit), true)  // Credit = income
        } else if let debit = debitAmount, let credit = creditAmount {
            // Both have values - use the non-zero one
            if debit != 0 && credit == 0 {
                return (abs(debit), false)
            } else if credit != 0 && debit == 0 {
                return (abs(credit), true)
            }
        }
        
        Self.logger.warning("Invalid split columns: debit='\(debit)', credit='\(credit)'")
        return nil
    }
    
    /// Parses amount from single column based on convention
    private func parseAmountFromSingleColumn(
        _ amountString: String,
        convention: CSVBankProfile.AmountConvention
    ) -> (amount: Double, isIncome: Bool)? {
        
        guard let rawAmount = parseAmount(amountString) else {
            return nil
        }
        
        switch convention {
        case .signedSingleColumn:
            // Negative = expense, Positive = income
            return (abs(rawAmount), rawAmount >= 0)
            
        case .positiveExpense:
            // Positive = expense (Discover convention)
            return (abs(rawAmount), rawAmount < 0)
            
        case .splitDebitCredit:
            // Should not reach here
            Self.logger.error("Split debit/credit convention used with single column")
            return nil
        }
    }
    
    /// Core amount parser - handles currency symbols, commas, parentheses
    private func parseAmount(_ amountString: String) -> Double? {
        var cleaned = amountString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty string
        if cleaned.isEmpty {
            return nil
        }
        
        // Remove currency symbols
        cleaned = cleaned.replacingOccurrences(of: "$", with: "")
        cleaned = cleaned.replacingOccurrences(of: "€", with: "")
        cleaned = cleaned.replacingOccurrences(of: "£", with: "")
        
        // Remove thousands separators (commas)
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        
        // Handle parentheses as negative (accounting format)
        let hasParentheses = cleaned.hasPrefix("(") && cleaned.hasSuffix(")")
        if hasParentheses {
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        }
        
        // Parse to Double
        guard let amount = Double(cleaned.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        
        return hasParentheses ? -amount : amount
    }
    
    // MARK: - Auto-Categorization
    
    /// Finds matching category for merchant using learned mappings
    private func findMatchingCategory(
        merchantName: String,
        merchantMappings: [MerchantCategoryMapping],
        categories: [Category]
    ) -> Category? {
        
        // Try to find a matching merchant mapping
        for mapping in merchantMappings {
            if mapping.matches(merchantName) {
                // Find the category by ID or name
                if let categoryID = mapping.categoryID,
                   let category = categories.first(where: { $0.id == categoryID }) {
                    return category
                } else if let categoryName = mapping.categoryName,
                          let category = categories.first(where: { $0.name == categoryName }) {
                    return category
                }
            }
        }
        
        return nil
    }
}

// MARK: - Array Safe Subscript Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
