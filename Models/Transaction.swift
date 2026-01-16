//  Transaction.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Added Account relationship for multi-account support
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Elite Transaction model with Business/Personal classification
//
//  CHANGES FROM v2.2:
//  ✅ Added account relationship for multi-account tracking
//  ✅ Added accountName computed property for display
//  ✅ Added filtering helpers for account-based queries
//  ✅ Maintained all v2.2 functionality
//
//  CHANGES FROM v2.1:
//  - Added validation methods (isValid, validateAmount, validateDate)
//  - Added auto-update of updatedAt in property setters
//  - Enhanced documentation and examples
//  - Improved computed properties
//  - FIXED: Restored recurringParent relationship (was missing)
//
//  CHANGES FROM v2.0:
//  - Replaced 'merchant' with 'merchantName' for clarity
//  - Added 'financeType' enum for Business/Personal classification
//  - Replaced 'type' with 'isIncome' boolean for simplicity
//  - Added backward compatibility via computed properties
//
//  BACKWARD COMPATIBILITY:
//  - transaction.merchant (deprecated) → transaction.merchantName (preferred)
//  - transaction.type (deprecated) → transaction.isIncome (preferred)

import Foundation
import SwiftData

@Model
final class Transaction {
    
    // MARK: - Core Properties
    
    /// Unique identifier
    var id: UUID
    
    /// Transaction amount (always positive, use isIncome to determine direction)
    var amount: Double {
        didSet {
            if amount != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Transaction date
    var date: Date {
        didSet {
            if date != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Optional note/description
    var note: String {
        didSet {
            if note != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Whether this is income (true) or expense (false)
    var isIncome: Bool {
        didSet {
            if isIncome != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Merchant or payee name
    var merchantName: String {
        didSet {
            if merchantName != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Business vs Personal classification
    var financeType: FinanceType {
        didSet {
            if financeType != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    // MARK: - Relationships
    
    /// Associated category (optional)
    var category: Category? {
        didSet {
            if category?.id != oldValue?.id {
                updatedAt = Date()
            }
        }
    }
    
    /// Associated budget (optional, for envelope budgeting)
    var budget: Budget?
    
    /// CRITICAL: Relationship to RecurringTransaction parent (if this is a generated transaction)
    /// NOTE: Do NOT add inverse parameter here - RecurringTransaction defines the inverse
    @Relationship(deleteRule: .nullify)
    var recurringParent: RecurringTransaction?
    
    /// Associated account (NEW in v2.3 - Premium feature)
    /// NOTE: The inverse is defined on Account.transactions
    @Relationship(deleteRule: .nullify)
    var account: Account? {
        didSet {
            if account?.id != oldValue?.id {
                updatedAt = Date()
            }
        }
    }
    
    // MARK: - Receipt Properties
    
    /// Path to stored receipt image
    var receiptImagePath: String? {
        didSet {
            if receiptImagePath != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Receipt identifier for tracking
    var receiptID: String?
    
    /// Whether transaction has an attached receipt
    var hasReceipt: Bool {
        didSet {
            if hasReceipt != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    // MARK: - Metadata
    
    /// When transaction was created
    var createdAt: Date
    
    /// When transaction was last modified
    var updatedAt: Date
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        note: String = "",
        isIncome: Bool = false,
        merchantName: String = "",
        category: Category? = nil,
        budget: Budget? = nil,
        financeType: FinanceType = .personal,
        recurringParent: RecurringTransaction? = nil,
        account: Account? = nil,
        receiptImagePath: String? = nil,
        receiptID: String? = nil,
        hasReceipt: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.isIncome = isIncome
        self.merchantName = merchantName
        self.category = category
        self.budget = budget
        self.financeType = financeType
        self.recurringParent = recurringParent
        self.account = account
        self.receiptImagePath = receiptImagePath
        self.receiptID = receiptID
        self.hasReceipt = hasReceipt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Finance Type Enum
    
    /// Classification for Business vs Personal expenses
    enum FinanceType: String, Codable, CaseIterable {
        case business
        case personal
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var icon: String {
            switch self {
            case .business:
                return "briefcase.fill"
            case .personal:
                return "person.fill"
            }
        }
    }
    
    // MARK: - Backward Compatibility (Deprecated)
    
    /// Legacy transaction type enum (DEPRECATED - use isIncome instead)
    @available(*, deprecated, message: "Use isIncome property instead")
    enum TransactionType: String, Codable {
        case income
        case expense
    }
    
    /// Legacy computed property for transaction type (DEPRECATED)
    @available(*, deprecated, message: "Use isIncome property instead")
    var type: TransactionType {
        get { isIncome ? .income : .expense }
        set { isIncome = (newValue == .income) }
    }
    
    /// Legacy computed property for merchant (DEPRECATED)
    @available(*, deprecated, message: "Use merchantName property instead")
    var merchant: String {
        get { merchantName }
        set { merchantName = newValue }
    }
    
    // MARK: - Computed Properties
    
    /// Display name for the transaction (merchant or note)
    var displayName: String {
        if !merchantName.isEmpty {
            return merchantName
        } else if !note.isEmpty {
            return note
        } else {
            return isIncome ? "Income" : "Expense"
        }
    }
    
    /// Formatted currency amount
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let sign = isIncome ? "+" : "-"
        return sign + (formatter.string(from: NSNumber(value: abs(amount))) ?? "$\(abs(amount))")
    }
    
    /// Formatted currency amount without sign
    var formattedAmountNoSign: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    /// Whether this transaction is tax deductible (business expenses only)
    var isTaxDeductible: Bool {
        financeType == .business && !isIncome
    }
    
    /// Month key for grouping transactions (YYYY-MM format)
    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    /// Whether this is a recurring transaction instance
    var isRecurring: Bool {
        recurringParent != nil
    }
    
    // MARK: - Account Properties (NEW in v2.3)
    
    /// Account name for display (or "No Account" if unassigned)
    var accountName: String {
        account?.name ?? "No Account"
    }
    
    /// Account display with last 4 digits
    var accountDisplayName: String {
        account?.displayNameWithDigits ?? "No Account"
    }
    
    /// Whether transaction has an assigned account
    var hasAccount: Bool {
        account != nil
    }
    
    /// Account type icon (or default)
    var accountIcon: String {
        account?.icon ?? "questionmark.circle"
    }
    
    /// Account color (or default gray)
    var accountColor: String {
        account?.color ?? "#6B7280"
    }
    
    // MARK: - Validation Methods
    
    /// Validates all transaction properties
    /// - Returns: Tuple of (isValid, error message)
    func validate() -> (isValid: Bool, error: String?) {
        // Validate amount
        if let amountError = validateAmount() {
            return (false, amountError)
        }
        
        // Validate date
        if let dateError = validateDate() {
            return (false, dateError)
        }
        
        // All validations passed
        return (true, nil)
    }
    
    /// Validates transaction amount
    /// - Returns: Error message if invalid, nil if valid
    func validateAmount() -> String? {
        if amount <= 0 {
            return "Amount must be greater than zero"
        }
        
        if amount > 1_000_000 {
            return "Amount exceeds maximum limit ($1,000,000)"
        }
        
        return nil
    }
    
    /// Validates transaction date
    /// - Returns: Error message if invalid, nil if valid
    func validateDate() -> String? {
        // Check if date is too far in the past (more than 10 years)
        let tenYearsAgo = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        if date < tenYearsAgo {
            return "Date cannot be more than 10 years in the past"
        }
        
        // Check if date is too far in the future (more than 1 year)
        let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        if date > oneYearFromNow {
            return "Date cannot be more than 1 year in the future"
        }
        
        return nil
    }
    
    /// Quick validation check (doesn't return error message)
    var isValid: Bool {
        amount > 0 &&
        amount <= 1_000_000 &&
        validateDate() == nil
    }
    
    // MARK: - Helper Methods
    
    /// Updates the updatedAt timestamp to now
    func touch() {
        updatedAt = Date()
    }
    
    /// Creates a copy of this transaction
    func duplicate() -> Transaction {
        Transaction(
            amount: amount,
            date: date,
            note: note + " (copy)",
            isIncome: isIncome,
            merchantName: merchantName,
            category: category,
            budget: budget,
            financeType: financeType,
            recurringParent: nil, // Don't copy recurring parent
            account: account,
            receiptImagePath: receiptImagePath,
            receiptID: receiptID,
            hasReceipt: hasReceipt
        )
    }
    
    /// Assign to a different account
    func assignToAccount(_ newAccount: Account?) {
        account = newAccount
        touch()
    }
}

// MARK: - Hashable & Equatable Conformance

extension Transaction: Hashable {
    static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Filtering Extensions

extension Transaction {
    /// Filter predicate for account-based queries
    static func accountPredicate(accountId: UUID) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.account?.id == accountId
        }
    }
    
    /// Filter predicate for finance type
    static func financeTypePredicate(_ type: FinanceType) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.financeType == type
        }
    }
    
    /// Filter predicate for date range
    static func dateRangePredicate(from startDate: Date, to endDate: Date) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.date >= startDate && transaction.date <= endDate
        }
    }
}

// MARK: - Usage Examples (Documentation)

/*
 // Creating a new business expense with account
 let transaction = Transaction(
     amount: 125.50,
     date: Date(),
     note: "Office supplies",
     isIncome: false,
     merchantName: "Staples",
     financeType: .business,
     account: businessCheckingAccount,
     hasReceipt: true
 )
 
 // Validate before saving
 let validation = transaction.validate()
 if validation.isValid {
     context.insert(transaction)
     try? context.save()
 } else {
     print("Validation error: \(validation.error ?? "Unknown error")")
 }
 
 // Creating income transaction with account
 let income = Transaction(
     amount: 5000,
     date: Date(),
     note: "Client payment",
     isIncome: true,
     merchantName: "Acme Corp",
     financeType: .business,
     account: businessCheckingAccount
 )
 
 // Check account info
 print(transaction.accountName)        // "Chase Business Checking"
 print(transaction.accountDisplayName) // "Chase Business Checking •••• 4521"
 
 // Assign to different account
 transaction.assignToAccount(personalAccount)
 
 // Query transactions by account
 let descriptor = FetchDescriptor<Transaction>(
     predicate: Transaction.accountPredicate(accountId: account.id)
 )
 let accountTransactions = try context.fetch(descriptor)
 */
