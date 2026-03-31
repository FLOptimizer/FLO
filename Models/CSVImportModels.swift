//  CSVImportModels.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Transfer Detection Support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ ADDED: isTransfer flag to CSVParsedTransaction — user-confirmed transfer status
//  ✅ ADDED: detectedAsTransfer flag — auto-detection result from keyword matching
//  ✅ ADDED: transferConfidence — how confident we are this is a transfer (0.0-1.0)
//  ✅ Transfers are excluded from P&L, tax estimates, and spending insights when committed
//
//  CHANGES v1.1:
//  ✅ ADDED: indicatorColumn in CSVColumnMapping — for "Credit Debit Indicator" style CSVs
//  ✅ ADDED: bankCategory in CSVParsedTransaction — captures bank-provided category for review
//
//  Intermediate data structures used during CSV import pipeline
//  These are NOT SwiftData models - they are plain Swift types used
//  between parsing and committing to the database.
//

import Foundation
import SwiftData

// MARK: - CSV Raw Row

/// A single row from the CSV file with line number for error reporting
struct CSVRawRow {
    let lineNumber: Int
    let fields: [String]
}

// MARK: - CSV Column Mapping

/// Defines which CSV column index maps to which transaction field
struct CSVColumnMapping {
    var dateColumn: Int
    var descriptionColumn: Int
    var amountColumn: Int
    var creditColumn: Int?    // Some banks split debit/credit
    var debitColumn: Int?     // into separate columns
    var categoryColumn: Int?
    var checkNumberColumn: Int?
    var balanceColumn: Int?   // Running balance (informational)
    var indicatorColumn: Int? // "Credit Debit Indicator" column (Debit/Credit text)
    
    /// Whether this bank uses split debit/credit columns
    var usesSplitColumns: Bool {
        creditColumn != nil && debitColumn != nil
    }
    
    /// Whether this bank uses a separate indicator column for debit/credit direction
    var usesIndicatorColumn: Bool {
        indicatorColumn != nil
    }
}

// MARK: - CSV Parsed Transaction

/// Intermediate parsed transaction before it becomes a SwiftData Transaction
/// This is the handoff model between parsing and review/commit
struct CSVParsedTransaction: Identifiable {
    let id: UUID = UUID()
    let rawLineNumber: Int
    var date: Date
    var description: String
    var amount: Double         // Always positive
    var isIncome: Bool
    var merchantName: String   // Cleaned from description
    var suggestedCategory: Category?
    var suggestedFinanceType: Transaction.FinanceType
    var checkNumber: String?
    var runningBalance: Double?
    var bankCategory: String?  // Bank-provided category (e.g., "Restaurants/Dining")
    
    // Import control flags
    var isSelected: Bool = true      // User can deselect
    var isDuplicate: Bool = false     // Detected as existing
    var duplicateMatchScore: Double = 0.0
    var duplicateMatchID: UUID?       // ID of matched Transaction
    
    // MARK: - Transfer Detection (NEW in v1.2)
    
    /// Whether this transaction should be treated as a transfer.
    /// When true, the committed Transaction will have isTransfer = true,
    /// excluding it from P&L, tax estimates, and spending insights.
    /// This is the user-confirmed value (can override auto-detection).
    var isTransfer: Bool = false
    
    /// Whether the system auto-detected this as a likely transfer.
    /// Based on keyword matching in merchant name, description, or bank category.
    /// User can override this via the UI toggle.
    var detectedAsTransfer: Bool = false
    
    /// Confidence score for transfer detection (0.0 to 1.0).
    /// Higher values indicate stronger keyword matches.
    /// - 1.0: Exact match (e.g., "TRANSFER TO SAVINGS")
    /// - 0.8: Strong indicator (e.g., "ZELLE TO JOHN DOE")
    /// - 0.6: Moderate indicator (e.g., "ACH CREDIT")
    /// - 0.0: No transfer indicators detected
    var transferConfidence: Double = 0.0
}

// MARK: - CSV Bank Profile

/// Pre-configured profiles for common bank CSV formats
struct CSVBankProfile: Identifiable {
    let id: String                  // e.g., "chase_checking"
    let displayName: String         // e.g., "Chase Bank"
    let icon: String                // SF Symbol
    let dateFormat: String          // e.g., "MM/dd/yyyy"
    let columnMapping: CSVColumnMapping
    let hasHeader: Bool
    let headerKeywords: [String]    // Used for auto-detection (case-insensitive)
    let amountConvention: AmountConvention
    
    enum AmountConvention {
        case signedSingleColumn     // Negative = expense
        case splitDebitCredit        // Separate columns
        case positiveExpense         // Positive = expense (inverted)
    }
}

// MARK: - CSV Import Result

/// The result type returned after parsing is complete
struct CSVImportResult {
    let transactions: [CSVParsedTransaction]
    let skippedRows: [(lineNumber: Int, reason: String)]
    let detectedProfile: CSVBankProfile?
    let totalRows: Int
    let dateRange: ClosedRange<Date>?
}

// MARK: - CSV Import Error

/// Errors that can occur during CSV import
enum CSVImportError: LocalizedError {
    case fileReadFailed
    case emptyFile
    case noValidRows
    case dateParsingFailed(row: Int)
    case amountParsingFailed(row: Int)
    case missingRequiredColumn(String)
    case unsupportedEncoding
    
    var errorDescription: String? {
        switch self {
        case .fileReadFailed:
            return "Unable to read the CSV file. Please check the file and try again."
        case .emptyFile:
            return "The CSV file is empty or contains no data."
        case .noValidRows:
            return "No valid transaction rows were found in the file."
        case .dateParsingFailed(let row):
            return "Unable to parse date on line \(row). Please check the date format."
        case .amountParsingFailed(let row):
            return "Unable to parse amount on line \(row). Please check the amount format."
        case .missingRequiredColumn(let column):
            return "Missing required column: \(column). Please check your column mapping."
        case .unsupportedEncoding:
            return "Unable to read file encoding. Please ensure the file is UTF-8 or Latin-1."
        }
    }
}

// MARK: - Built-in Bank Profiles

extension CSVBankProfile {
    
    /// All supported bank profiles
    static let builtInProfiles: [CSVBankProfile] = [
        .chase,
        .bankOfAmerica,
        .wellsFargo,
        .capitalOne,
        .discover,
        .citi,
        .usBank,
        .generic
    ]
    
    // MARK: - Chase Bank
    
    static let chase = CSVBankProfile(
        id: "chase_checking",
        displayName: "Chase Bank",
        icon: "building.columns.fill",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Posting Date"
            descriptionColumn: 1, // "Description"
            amountColumn: 2,    // "Amount"
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: 3    // "Balance"
        ),
        hasHeader: true,
        headerKeywords: ["posting date", "description", "amount", "balance"],
        amountConvention: .signedSingleColumn
    )
    
    // MARK: - Bank of America
    
    static let bankOfAmerica = CSVBankProfile(
        id: "bankofamerica",
        displayName: "Bank of America",
        icon: "building.columns.fill",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Date"
            descriptionColumn: 1, // "Description"
            amountColumn: 2,    // "Amount"
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: 3    // "Running Bal."
        ),
        hasHeader: true,
        headerKeywords: ["date", "description", "amount", "running bal"],
        amountConvention: .signedSingleColumn
    )
    
    // MARK: - Wells Fargo
    
    static let wellsFargo = CSVBankProfile(
        id: "wellsfargo",
        displayName: "Wells Fargo",
        icon: "building.columns.fill",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Date"
            descriptionColumn: 2, // "Description" (column 1 is often check number)
            amountColumn: 1,    // "Amount"
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: ["date", "amount", "description"],
        amountConvention: .signedSingleColumn
    )
    
    // MARK: - Capital One
    
    static let capitalOne = CSVBankProfile(
        id: "capitalone",
        displayName: "Capital One",
        icon: "building.columns.fill",
        dateFormat: "yyyy-MM-dd",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Transaction Date"
            descriptionColumn: 3, // "Description"
            amountColumn: -1,   // Not used (split columns)
            creditColumn: 5,    // "Credit"
            debitColumn: 4,     // "Debit"
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: ["transaction date", "debit", "credit", "description"],
        amountConvention: .splitDebitCredit
    )
    
    // MARK: - Discover
    
    static let discover = CSVBankProfile(
        id: "discover",
        displayName: "Discover",
        icon: "building.columns.fill",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Trans. Date"
            descriptionColumn: 2, // "Description"
            amountColumn: 3,    // "Amount"
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: 4,  // "Category"
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: ["trans. date", "description", "amount", "category"],
        amountConvention: .positiveExpense
    )
    
    // MARK: - Citi
    
    static let citi = CSVBankProfile(
        id: "citi",
        displayName: "Citi",
        icon: "building.columns.fill",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Date"
            descriptionColumn: 1, // "Description"
            amountColumn: -1,   // Not used (split columns)
            creditColumn: 3,    // "Credit"
            debitColumn: 2,     // "Debit"
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: ["date", "description", "debit", "credit"],
        amountConvention: .splitDebitCredit
    )
    
    // MARK: - US Bank
    
    static let usBank = CSVBankProfile(
        id: "usbank",
        displayName: "US Bank",
        icon: "building.columns.fill",
        dateFormat: "yyyy-MM-dd",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,      // "Date"
            descriptionColumn: 1, // "Name"
            amountColumn: 2,    // "Amount"
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: ["date", "name", "amount"],
        amountConvention: .signedSingleColumn
    )
    
    // MARK: - Generic / Manual Mapping
    
    static let generic = CSVBankProfile(
        id: "generic",
        displayName: "Other / Manual Mapping",
        icon: "doc.text",
        dateFormat: "MM/dd/yyyy",
        columnMapping: CSVColumnMapping(
            dateColumn: 0,
            descriptionColumn: 1,
            amountColumn: 2,
            creditColumn: nil,
            debitColumn: nil,
            categoryColumn: nil,
            checkNumberColumn: nil,
            balanceColumn: nil
        ),
        hasHeader: true,
        headerKeywords: [],
        amountConvention: .signedSingleColumn
    )
}
