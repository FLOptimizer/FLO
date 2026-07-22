//  Transaction.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2 - Tip Amount + Split Pay
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Elite Transaction model with Business/Personal classification
//
//  CHANGES FROM v3.1:
//  ✅ Added optional tipAmount (Double?) — restaurant/service tips, included in total
//  ✅ Added optional splitGroupId (UUID?) — links business/personal split transactions
//  ✅ Added isSplitTransaction computed convenience
//
//  CHANGES FROM v3.0:
//  ✅ Replaced per-access NumberFormatter/DateFormatter allocations with shared static formatters
//  ✅ formattedAmount/formattedAmountNoSign now use static sharedCurrencyFormatter
//  ✅ monthKey now uses static monthKeyFormatter (eliminates ~3,000 allocations per render)
//  ✅ Static formatters defined locally for Widget extension compatibility
//
//  CHANGES FROM v2.5:
//  ✅ Added Move Money / Transfer support
//  ✅ New isTransfer flag to distinguish transfers from income/expenses
//  ✅ New linkedTransferID to pair source/destination transactions
//  ✅ New TransferType enum: ownersDraw, ownerContribution, taxSetAside, reimbursement, internalTransfer
//  ✅ Added transferType stored property
//  ✅ Added isTransferPredicate for filtering transfers out of reports
//  ✅ Added computed properties: isOwnersDraw, isOwnerContribution, transferDescription
//
//  CHANGES FROM v2.4:
//  ✅ Fixed importSource default to use fully qualified type (SwiftData requirement)
//
//  CHANGES FROM v2.3:
//  ✅ Added Plaid integration fields (plaidTransactionId, plaidAccountId)
//  ✅ Added TransactionSource enum for import tracking
//  ✅ Added computed properties for Plaid status
//  ✅ Added helper methods for Plaid transactions
//  ✅ Maintained all v2.3 functionality
//
//  CHANGES FROM v2.2:
//  - Added account relationship for multi-account tracking
//  - Added accountName computed property for display
//  - Added filtering helpers for account-based queries
//  - Maintained all v2.2 functionality
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
    var id: UUID = UUID()
    
    /// Transaction amount (always positive, use isIncome to determine direction)
    var amount: Double = 0.0 {
        didSet {
            if amount != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Transaction date
    var date: Date = Date() {
        didSet {
            if date != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Optional note/description
    var note: String = "" {
        didSet {
            if note != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Whether this is income (true) or expense (false)
    var isIncome: Bool = false {
        didSet {
            if isIncome != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Merchant or payee name
    var merchantName: String = "" {
        didSet {
            if merchantName != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    /// Business vs Personal classification
    var financeType: FinanceType = FinanceType.personal {
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
    
    /// Payment log that created this transaction (if manually marked as sent)
    /// Inverse defined on RecurringPaymentLog.transaction
    @Relationship(deleteRule: .nullify)
    var paymentLog: RecurringPaymentLog?

    /// Associated account (NEW in v2.3 - Premium feature)
    /// Inverse defined on Account.transactions
    @Relationship(deleteRule: .nullify)
    var account: Account? {
        didSet {
            if account?.id != oldValue?.id {
                updatedAt = Date()
            }
        }
    }

    /// Spending event this transaction belongs to (e.g. a trip) — a second
    /// dimension of categorization alongside `category`.
    /// Inverse defined on SpendingEvent.transactions
    @Relationship(deleteRule: .nullify)
    var event: SpendingEvent? {
        didSet {
            if event?.id != oldValue?.id {
                updatedAt = Date()
            }
        }
    }

    /// Invoice payment linked to this transaction (inverse of InvoicePayment.linkedTransaction)
    @Relationship(deleteRule: .nullify, inverse: \InvoicePayment.linkedTransaction)
    var linkedPayment: InvoicePayment?

    /// Bill payment linked to this transaction (inverse of BillPayment.linkedTransaction) (v3.9)
    @Relationship(deleteRule: .nullify, inverse: \BillPayment.linkedTransaction)
    var linkedBillPayment: BillPayment?

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
    var hasReceipt: Bool = false {
        didSet {
            if hasReceipt != oldValue {
                updatedAt = Date()
            }
        }
    }
    
    // MARK: - Plaid Integration (Pro tier - NEW in v2.4)
    
    /// Plaid's unique transaction ID (for deduplication and updates)
    /// Format: Plaid transaction IDs are typically alphanumeric strings
    var plaidTransactionId: String?
    
    /// Plaid account ID this transaction belongs to
    /// Links to Account.plaidAccountId for cross-reference
    var plaidAccountId: String?
    
    /// How this transaction was created/imported
    /// Tracks provenance for auditing and sync logic
    var importSource: TransactionSource = Transaction.TransactionSource.manual
    
    /// Plaid's category hierarchy (e.g., ["Food and Drink", "Restaurants"])
    /// Stored as JSON-encoded string for flexibility
    var plaidCategoryHierarchy: String?
    
    /// Whether this transaction is pending in Plaid
    /// Pending transactions may be updated or removed
    var plaidPending: Bool = false
    
    /// Original Plaid merchant name (before user edits)
    /// Preserved for sync conflict resolution
    var plaidOriginalMerchant: String?
    
    /// When this transaction was last synced from Plaid
    var plaidLastSync: Date?
    
    // MARK: - Transfer / Move Money Properties (NEW in v3.0)
    
    /// Whether this transaction is part of a transfer between accounts.
    /// Transfer transactions are excluded from P&L, tax estimates, and spending insights.
    var isTransfer: Bool = false
    
    /// UUID of the paired transaction on the other side of the transfer.
    /// Source transaction links to destination, destination links back to source.
    var linkedTransferID: UUID?
    
    /// The type of transfer, stored as raw value for SwiftData compatibility.
    /// nil for non-transfer transactions.
    var transferTypeRaw: String?

    /// Groups this transaction with a related Transfer when it was auto-generated
    /// from a debt payment split (e.g., the interest portion of a loan payment).
    /// Mirrors Transfer.paymentGroupId on the principal side. nil for standalone transactions.
    var paymentGroupId: UUID?

    // MARK: - Household Sharing (Build 8)

    /// Whether this transaction is shared with household members.
    /// Default false — existing transactions remain private.
    var isShared: Bool = false

    /// The household ID this transaction belongs to (if shared).
    /// nil for private transactions.
    var householdId: UUID?

    // MARK: - Review Status (Build 10)

    /// Whether this transaction has been reviewed by the user.
    /// New transactions default to false. Review flow allows bulk marking.
    var isReviewed: Bool = false

    // MARK: - Tip + Split Pay (v3.2)

    /// Optional tip amount (e.g., restaurant tip, gratuity, service charge).
    /// IMPORTANT: `amount` already INCLUDES the tip — tipAmount is stored
    /// separately so it can be displayed/exported and analyzed, not added on top.
    var tipAmount: Double? {
        didSet {
            if tipAmount != oldValue {
                updatedAt = Date()
            }
        }
    }

    /// Links transactions that originated from the same split receipt.
    /// Both the business and personal portions share this UUID.
    /// nil for non-split transactions.
    var splitGroupId: UUID? {
        didSet {
            if splitGroupId != oldValue {
                updatedAt = Date()
            }
        }
    }

    // MARK: - Metadata

    /// When transaction was created
    var createdAt: Date = Date()

    /// When transaction was last modified
    var updatedAt: Date = Date()
    
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
        plaidTransactionId: String? = nil,
        plaidAccountId: String? = nil,
        importSource: TransactionSource = .manual,
        plaidCategoryHierarchy: String? = nil,
        plaidPending: Bool = false,
        plaidOriginalMerchant: String? = nil,
        plaidLastSync: Date? = nil,
        isTransfer: Bool = false,
        linkedTransferID: UUID? = nil,
        transferType: TransferType? = nil,
        paymentGroupId: UUID? = nil,
        isReviewed: Bool = false,
        tipAmount: Double? = nil,
        splitGroupId: UUID? = nil,
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
        self.plaidTransactionId = plaidTransactionId
        self.plaidAccountId = plaidAccountId
        self.importSource = importSource
        self.plaidCategoryHierarchy = plaidCategoryHierarchy
        self.plaidPending = plaidPending
        self.plaidOriginalMerchant = plaidOriginalMerchant
        self.plaidLastSync = plaidLastSync
        self.isTransfer = isTransfer
        self.linkedTransferID = linkedTransferID
        self.transferTypeRaw = transferType?.rawValue
        self.paymentGroupId = paymentGroupId
        self.isReviewed = isReviewed
        self.tipAmount = tipAmount
        self.splitGroupId = splitGroupId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Convenience: true if this transaction is one half of a split-receipt pair.
    var isSplitTransaction: Bool { splitGroupId != nil }
    
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
    
    // MARK: - Transaction Source Enum (NEW in v2.4)
    
    /// Tracks how the transaction was created/imported
    /// Used for sync logic, auditing, and UI differentiation
    enum TransactionSource: String, Codable, CaseIterable {
        /// Manually entered by user
        case manual = "manual"
        
        /// Imported from Plaid bank sync
        case plaid = "plaid"
        
        /// Created from receipt scan
        case receipt = "receipt"
        
        /// Generated from recurring transaction
        case recurring = "recurring"
        
        /// Imported from CSV/external file
        case csvImport = "csv_import"
        
        /// Created as part of a Move Money transfer (NEW in v3.0)
        case transfer = "transfer"

        /// Auto-generated as a side-effect of a transfer split (e.g., the interest
        /// portion expense created from a debt payment with interest/principal breakdown).
        /// Visually distinguishable so users know it can be reviewed/recategorized.
        case derivedFromTransfer = "derived_from_transfer"

        var displayName: String {
            switch self {
            case .manual: return "Manual Entry"
            case .plaid: return "Bank Sync"
            case .receipt: return "Receipt Scan"
            case .recurring: return "Recurring"
            case .csvImport: return "CSV Import"
            case .transfer: return "Transfer"
            case .derivedFromTransfer: return "Transfer Split"
            }
        }

        var icon: String {
            switch self {
            case .manual: return "pencil"
            case .plaid: return "building.columns"
            case .receipt: return "doc.text.viewfinder"
            case .recurring: return "repeat"
            case .csvImport: return "doc.badge.arrow.up"
            case .transfer: return "arrow.left.arrow.right"
            case .derivedFromTransfer: return "arrow.triangle.branch"
            }
        }

        /// Whether this source allows user editing of core fields
        var isEditable: Bool {
            switch self {
            case .manual, .receipt, .csvImport:
                return true
            case .plaid:
                // Plaid transactions can be edited but original values preserved
                return true
            case .recurring:
                // Recurring instances generally shouldn't be edited
                return false
            case .transfer:
                // Transfer transactions should be voided, not edited
                return false
            case .derivedFromTransfer:
                // Auto-generated from a transfer split — user may need to recategorize
                return true
            }
        }
        
        /// Whether this source requires sync consideration
        var requiresSync: Bool {
            self == .plaid
        }
    }
    
    // MARK: - Transfer Type Enum (NEW in v3.0)
    
    /// Classifies the purpose of a transfer between accounts.
    /// Auto-detected from source/destination account finance types.
    enum TransferType: String, Codable, CaseIterable {
        /// Business → Personal: Owner takes profit for personal use
        /// Not a business expense, not personal income. Reduces owner equity.
        case ownersDraw = "owners_draw"
        
        /// Personal → Business: Owner injects capital into the business
        /// Not business income, not personal expense. Increases owner equity.
        case ownerContribution = "owner_contribution"
        
        /// Any → Tax savings account: Setting aside money for quarterly taxes
        /// Not an expense. Tracked against quarterly estimate obligation.
        case taxSetAside = "tax_set_aside"
        
        /// Business → Personal: Reimbursing owner for business expense paid personally
        /// The expense was already logged; this just tracks the payback.
        case reimbursement = "reimbursement"
        
        /// Same type → Same type: Moving money between own accounts
        /// Zero tax impact, zero P&L impact. Pure balance sheet movement.
        case internalTransfer = "internal_transfer"
        
        var displayName: String {
            switch self {
            case .ownersDraw: return "Owner's Draw"
            case .ownerContribution: return "Owner's Contribution"
            case .taxSetAside: return "Tax Set-Aside"
            case .reimbursement: return "Reimbursement"
            case .internalTransfer: return "Transfer"
            }
        }
        
        var subtitle: String {
            switch self {
            case .ownersDraw: return "Taking profit for personal use"
            case .ownerContribution: return "Putting personal funds into business"
            case .taxSetAside: return "Setting aside for quarterly taxes"
            case .reimbursement: return "Paying back a personal expense"
            case .internalTransfer: return "Moving between your accounts"
            }
        }
        
        var icon: String {
            switch self {
            case .ownersDraw: return "arrow.right.circle.fill"
            case .ownerContribution: return "arrow.left.circle.fill"
            case .taxSetAside: return "building.columns.circle.fill"
            case .reimbursement: return "arrow.uturn.left.circle.fill"
            case .internalTransfer: return "arrow.left.arrow.right.circle.fill"
            }
        }
        
        var colorHex: String {
            switch self {
            case .ownersDraw: return "8B5CF6"       // Purple
            case .ownerContribution: return "3B82F6" // Blue
            case .taxSetAside: return "F59E0B"       // Amber
            case .reimbursement: return "10B981"      // Emerald
            case .internalTransfer: return "6B7280"   // Gray
            }
        }
        
        /// Auto-detect transfer type from source and destination account finance types
        static func detect(
            fromFinanceType: Transaction.FinanceType,
            toFinanceType: Transaction.FinanceType,
            isTaxAccount: Bool = false
        ) -> TransferType {
            if isTaxAccount {
                return .taxSetAside
            }
            
            switch (fromFinanceType, toFinanceType) {
            case (.business, .personal):
                return .ownersDraw
            case (.personal, .business):
                return .ownerContribution
            case (.business, .business), (.personal, .personal):
                return .internalTransfer
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
        if isTransfer, let type = transferType {
            return type.displayName
        } else if !merchantName.isEmpty {
            return merchantName
        } else if !note.isEmpty {
            return note
        } else {
            return isIncome ? "Income" : "Expense"
        }
    }
    
    /// Formatted currency amount (uses shared static formatter for performance)
    var formattedAmount: String {
        let sign = isIncome ? "+" : "-"
        return sign + (Transaction.sharedCurrencyFormatter.string(from: NSNumber(value: abs(amount))) ?? "$\(abs(amount))")
    }

    /// Formatted currency amount without sign (uses shared static formatter for performance)
    var formattedAmountNoSign: String {
        Transaction.sharedCurrencyFormatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    /// Whether this transaction is tax deductible (business expenses only, not transfers)
    var isTaxDeductible: Bool {
        financeType == .business && !isIncome && !isTransfer
    }
    
    // MARK: - Shared Formatters (Performance)

    /// Static currency formatter — reused across all transactions instead of allocating per-access.
    /// Defined here (not AppConstants) so it works in both main app and Widget extension targets.
    private static let sharedCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        return f
    }()

    /// Static month-key formatter — reused across all transactions instead of allocating per-access
    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    /// Month key for grouping transactions (YYYY-MM format)
    var monthKey: String {
        Transaction.monthKeyFormatter.string(from: date)
    }
    
    /// Whether this is a recurring transaction instance
    var isRecurring: Bool {
        recurringParent != nil
    }
    
    // MARK: - Transfer Properties (v3.0)
    
    /// Computed getter/setter for transferType using raw string storage
    var transferType: TransferType? {
        get { transferTypeRaw.flatMap { TransferType(rawValue: $0) } }
        set { transferTypeRaw = newValue?.rawValue }
    }
    
    /// Whether this is an owner's draw (business → personal profit withdrawal)
    var isOwnersDraw: Bool {
        isTransfer && transferType == .ownersDraw
    }
    
    /// Whether this is an owner's contribution (personal → business capital injection)
    var isOwnerContribution: Bool {
        isTransfer && transferType == .ownerContribution
    }
    
    /// Whether this is a tax set-aside transfer
    var isTaxSetAside: Bool {
        isTransfer && transferType == .taxSetAside
    }
    
    /// Human-readable description of the transfer type
    var transferDescription: String {
        guard isTransfer else { return "" }
        return transferType?.displayName ?? "Transfer"
    }
    
    /// The linked partner transaction (for display purposes)
    /// Requires external lookup since SwiftData can't do self-referencing relationships easily
    var hasLinkedTransfer: Bool {
        linkedTransferID != nil
    }
    
    // MARK: - Account Properties (v2.3)
    
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
    
    // MARK: - Plaid Computed Properties (NEW in v2.4)
    
    /// Whether this transaction was imported from Plaid
    var isFromPlaid: Bool {
        importSource == .plaid || plaidTransactionId != nil
    }
    
    /// Whether this transaction has been modified from Plaid original
    var hasPlaidModifications: Bool {
        guard isFromPlaid, let original = plaidOriginalMerchant else {
            return false
        }
        return merchantName != original
    }
    
    /// Plaid category as array (decoded from JSON string)
    var plaidCategories: [String] {
        guard let hierarchy = plaidCategoryHierarchy,
              let data = hierarchy.data(using: .utf8),
              let categories = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return categories
    }
    
    /// Primary Plaid category (first in hierarchy)
    var plaidPrimaryCategory: String? {
        plaidCategories.first
    }
    
    /// Whether this is a pending Plaid transaction that may change
    var isPendingPlaidTransaction: Bool {
        isFromPlaid && plaidPending
    }
    
    /// Source badge text for UI display
    var sourceBadge: String? {
        switch importSource {
        case .manual:
            return nil // Don't show badge for manual entries
        case .plaid:
            return plaidPending ? "Pending" : "Synced"
        case .receipt:
            return "Scanned"
        case .recurring:
            return "Recurring"
        case .csvImport:
            return "Imported"
        case .transfer:
            return "Transfer"
        case .derivedFromTransfer:
            return "Auto-Split"
        }
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
            hasReceipt: hasReceipt,
            // Don't copy Plaid fields - duplicates are manual entries
            plaidTransactionId: nil,
            plaidAccountId: nil,
            importSource: .manual,
            plaidCategoryHierarchy: nil,
            plaidPending: false,
            plaidOriginalMerchant: nil,
            plaidLastSync: nil
        )
    }
    
    /// Assign to a different account
    func assignToAccount(_ newAccount: Account?) {
        account = newAccount
        touch()
    }
    
    // MARK: - Plaid Helper Methods (NEW in v2.4)
    
    /// Updates transaction from Plaid sync data
    /// Preserves user modifications where appropriate
    func updateFromPlaid(
        amount: Double,
        date: Date,
        merchantName: String,
        pending: Bool,
        categoryHierarchy: [String]?
    ) {
        // Always update amount and date from Plaid (authoritative)
        self.amount = amount
        self.date = date
        self.plaidPending = pending
        self.plaidLastSync = Date()
        
        // Update merchant only if user hasn't modified it
        if !hasPlaidModifications {
            self.merchantName = merchantName
            self.plaidOriginalMerchant = merchantName
        }
        
        // Update category hierarchy
        if let categories = categoryHierarchy {
            if let data = try? JSONEncoder().encode(categories),
               let jsonString = String(data: data, encoding: .utf8) {
                self.plaidCategoryHierarchy = jsonString
            }
        }
        
        touch()
    }
    
    /// Resets merchant to original Plaid value
    func resetToPlaidMerchant() {
        if let original = plaidOriginalMerchant {
            merchantName = original
            touch()
        }
    }
    
    /// Sets Plaid category hierarchy from array
    func setPlaidCategories(_ categories: [String]) {
        if let data = try? JSONEncoder().encode(categories),
           let jsonString = String(data: data, encoding: .utf8) {
            plaidCategoryHierarchy = jsonString
        }
    }
    
    /// Creates a new transaction from Plaid data
    static func fromPlaid(
        plaidTransactionId: String,
        plaidAccountId: String,
        amount: Double,
        date: Date,
        merchantName: String,
        pending: Bool,
        categoryHierarchy: [String]?,
        account: Account? = nil
    ) -> Transaction {
        var categoryJson: String?
        if let categories = categoryHierarchy {
            if let data = try? JSONEncoder().encode(categories),
               let jsonString = String(data: data, encoding: .utf8) {
                categoryJson = jsonString
            }
        }
        
        return Transaction(
            amount: abs(amount), // Plaid amounts can be negative
            date: date,
            note: "",
            isIncome: amount < 0, // Plaid: positive = expense, negative = income
            merchantName: merchantName,
            financeType: .personal, // Default, user can change
            account: account,
            plaidTransactionId: plaidTransactionId,
            plaidAccountId: plaidAccountId,
            importSource: .plaid,
            plaidCategoryHierarchy: categoryJson,
            plaidPending: pending,
            plaidOriginalMerchant: merchantName,
            plaidLastSync: Date()
        )
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
    
    /// Filter predicate for Plaid transactions (NEW in v2.4)
    static func plaidTransactionsPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.plaidTransactionId != nil
        }
    }
    
    /// Filter predicate for import source (NEW in v2.4)
    static func importSourcePredicate(_ source: TransactionSource) -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.importSource == source
        }
    }
    
    /// Filter predicate for pending Plaid transactions (NEW in v2.4)
    static func pendingPlaidPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.plaidPending == true
        }
    }
    
    /// Filter predicate to exclude transfers from financial calculations (NEW in v3.0)
    /// Use this in tax estimates, P&L reports, spending insights, etc.
    static func nonTransferPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.isTransfer == false
        }
    }
    
    /// Filter predicate for transfer transactions only (NEW in v3.0)
    static func transferPredicate() -> Predicate<Transaction> {
        #Predicate<Transaction> { transaction in
            transaction.isTransfer == true
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
 
 // === NEW IN v2.4: Plaid Integration Examples ===
 
 // Creating a transaction from Plaid sync
 let plaidTransaction = Transaction.fromPlaid(
     plaidTransactionId: "plaid_txn_abc123",
     plaidAccountId: "plaid_acc_xyz789",
     amount: -45.67,  // Negative = expense in Plaid
     date: Date(),
     merchantName: "AMAZON.COM",
     pending: false,
     categoryHierarchy: ["Shopping", "Online Marketplaces"],
     account: linkedAccount
 )
 
 // Check if transaction is from Plaid
 if plaidTransaction.isFromPlaid {
     print("Source: \(plaidTransaction.importSource.displayName)")  // "Bank Sync"
     print("Plaid ID: \(plaidTransaction.plaidTransactionId ?? "none")")
 }
 
 // Check for user modifications
 if plaidTransaction.hasPlaidModifications {
     print("User changed merchant from: \(plaidTransaction.plaidOriginalMerchant ?? "unknown")")
 }
 
 // Query only Plaid transactions
 let plaidDescriptor = FetchDescriptor<Transaction>(
     predicate: Transaction.plaidTransactionsPredicate()
 )
 let plaidTransactions = try context.fetch(plaidDescriptor)
 
 // Query pending Plaid transactions
 let pendingDescriptor = FetchDescriptor<Transaction>(
     predicate: Transaction.pendingPlaidPredicate()
 )
 let pendingTransactions = try context.fetch(pendingDescriptor)
 
 // Update from Plaid sync (preserves user edits)
 existingTransaction.updateFromPlaid(
     amount: 46.00,  // Amount corrected by bank
     date: Date(),
     merchantName: "Amazon.com",
     pending: false,
     categoryHierarchy: ["Shopping", "Online"]
 )
 
 // Reset merchant to Plaid original
 transaction.resetToPlaidMerchant()
 */
