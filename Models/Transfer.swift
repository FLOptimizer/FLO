//  Transfer.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Debt Payment Split
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Transfer model for tracking money movement between accounts.
//  Transfers are distinct from Transactions — they are NOT income or expenses.
//
//  FEATURES:
//  ✅ True double-entry: affects both fromAccount and toAccount balances
//  ✅ TransferType classification: Internal, Owner's Draw, Capital Contribution, etc.
//  ✅ Linked transaction support: matches bank withdrawals to deposits
//  ✅ Reconciliation tracking for bank statement matching
//  ✅ Full audit trail with timestamps
//
//  ACCOUNTING RULES:
//  • Internal transfers: No P&L impact, no tax impact
//  • Owner's Draw (Business → Personal): Tracked for equity, NOT a business expense
//  • Capital Contribution (Personal → Business): Tracked for basis, NOT business income
//  • Debt Payment (Any → Credit Card): Reduces liability, NOT an expense
//  • Tax Payment (Business → IRS): Special tracking for quarterly estimates
//

import Foundation
import SwiftData

// MARK: - Transfer Type Enum

/// Classifies the tax and accounting treatment of a transfer
enum TransferType: String, Codable, CaseIterable, Identifiable {
    
    /// Movement within same finance type (Personal↔Personal or Business↔Business)
    /// No tax impact, no P&L impact
    case `internal` = "internal"
    
    /// Business account → Personal account
    /// Tracked for owner's equity. NOT a business expense.
    /// The business income was already taxed as pass-through.
    case ownersDraw = "ownersDraw"
    
    /// Personal account → Business account
    /// Tracked for owner's basis/equity. NOT business income.
    case capitalContribution = "capitalContribution"
    
    /// Any account → Credit Card or Loan account
    /// Reduces liability balance. NOT an expense (the charge was the expense).
    case debtPayment = "debtPayment"
    
    /// Business account → Tax authority (IRS, State)
    /// Special tracking for quarterly estimated tax payments.
    case taxPayment = "taxPayment"
    
    /// Refund from a prior transfer (e.g., returned deposit, reversed draw)
    case refund = "refund"
    
    var id: String { rawValue }
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .internal:             return "Internal Transfer"
        case .ownersDraw:           return "Owner's Draw"
        case .capitalContribution:  return "Capital Contribution"
        case .debtPayment:          return "Debt Payment"
        case .taxPayment:           return "Tax Payment"
        case .refund:               return "Refund"
        }
    }
    
    var shortName: String {
        switch self {
        case .internal:             return "Internal"
        case .ownersDraw:           return "Draw"
        case .capitalContribution:  return "Contribution"
        case .debtPayment:          return "Payment"
        case .taxPayment:           return "Tax"
        case .refund:               return "Refund"
        }
    }
    
    var icon: String {
        switch self {
        case .internal:             return "arrow.left.arrow.right.circle.fill"
        case .ownersDraw:           return "arrow.up.right.circle.fill"
        case .capitalContribution:  return "arrow.down.left.circle.fill"
        case .debtPayment:          return "creditcard.fill"
        case .taxPayment:           return "building.columns.fill"
        case .refund:               return "arrow.uturn.backward.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .internal:             return "#6366F1"  // Indigo
        case .ownersDraw:           return "#8B5CF6"  // Purple
        case .capitalContribution:  return "#14B8A6"  // Teal
        case .debtPayment:          return "#3B82F6"  // Blue
        case .taxPayment:           return "#EF4444"  // Red
        case .refund:               return "#F59E0B"  // Amber
        }
    }
    
    var description: String {
        switch self {
        case .internal:
            return "Movement between accounts of the same type. No tax or P&L impact."
        case .ownersDraw:
            return "Taking money from your business for personal use. Tracked for equity — not a business expense."
        case .capitalContribution:
            return "Adding personal funds to your business. Tracked for basis — not business income."
        case .debtPayment:
            return "Paying down a credit card or loan. Reduces your liability balance."
        case .taxPayment:
            return "Quarterly estimated tax payment to IRS or state. Tracked separately for tax planning."
        case .refund:
            return "Reversal of a prior transfer."
        }
    }
    
    /// Whether this transfer type affects owner's equity tracking
    var affectsEquity: Bool {
        switch self {
        case .ownersDraw, .capitalContribution:
            return true
        default:
            return false
        }
    }
    
    /// Whether this transfer type should appear in tax reports
    var taxRelevant: Bool {
        switch self {
        case .ownersDraw, .capitalContribution, .taxPayment:
            return true
        default:
            return false
        }
    }
}

// MARK: - Transfer Status Enum

/// Tracks the reconciliation state of a transfer
enum TransferStatus: String, Codable, CaseIterable {
    case pending = "pending"           // Created but not yet confirmed
    case completed = "completed"       // Both sides confirmed
    case partiallyMatched = "partial"  // One side matched from bank import
    case reconciled = "reconciled"     // Matched to bank statement
    case failed = "failed"             // Transfer didn't go through
    
    var displayName: String {
        switch self {
        case .pending:          return "Pending"
        case .completed:        return "Completed"
        case .partiallyMatched: return "Partially Matched"
        case .reconciled:       return "Reconciled"
        case .failed:           return "Failed"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:          return "clock.fill"
        case .completed:        return "checkmark.circle.fill"
        case .partiallyMatched: return "circle.lefthalf.filled"
        case .reconciled:       return "checkmark.seal.fill"
        case .failed:           return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending:          return "#F59E0B"  // Amber
        case .completed:        return "#10B981"  // Green
        case .partiallyMatched: return "#6366F1"  // Indigo
        case .reconciled:       return "#14B8A6"  // Teal
        case .failed:           return "#EF4444"  // Red
        }
    }
}

// MARK: - Transfer Model

@Model
final class Transfer {
    
    // MARK: - Identifiers

    private(set) var id: UUID = UUID()

    // MARK: - Core Properties

    /// Date the transfer occurred or is scheduled
    var date: Date = Date()

    /// Amount being transferred (always positive)
    var amount: Double = 0.0

    /// Type of transfer (determines accounting treatment)
    var transferTypeRaw: String = TransferType.internal.rawValue

    /// Current status of the transfer
    var statusRaw: String = TransferStatus.completed.rawValue

    // MARK: - Account References

    /// Source account (money leaves this account)
    @Relationship(deleteRule: .nullify)
    var fromAccount: Account?

    /// Destination account (money enters this account)
    @Relationship(deleteRule: .nullify)
    var toAccount: Account?

    // MARK: - Linked Transactions (for CSV import matching)

    /// Transaction ID from the source account (withdrawal side)
    var linkedWithdrawalID: UUID?

    /// Transaction ID from the destination account (deposit side)
    var linkedDepositID: UUID?

    // MARK: - Metadata

    /// User notes about this transfer
    var notes: String?

    /// Reference number (check #, confirmation #, etc.)
    var reference: String?

    /// For tax payments: which quarter (1-4)
    var taxQuarter: Int?

    /// For tax payments: which tax year
    var taxYear: Int?

    /// For tax payments: federal, state, or local
    var taxAuthorityRaw: String?

    // MARK: - Debt Payment Split (v1.1)

    /// Interest portion of a debt payment (e.g., $200 of an $850 loan payment goes to interest)
    var interestPortion: Double?

    /// Principal portion of a debt payment (e.g., $650 of an $850 loan payment goes to principal)
    var principalPortion: Double?

    /// Groups linked records from a single debt payment submission
    /// The transfer (principal) and expense transaction (interest) share this ID
    var paymentGroupId: UUID?

    // MARK: - Recurring Link

    /// If generated from a recurring transfer, link to the source
    @Relationship(deleteRule: .nullify)
    var recurringTransfer: RecurringTransfer?

    // MARK: - Audit Trail

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Initialization
    
    init(
        date: Date = Date(),
        amount: Double,
        transferType: TransferType = .internal,
        status: TransferStatus = .completed,
        fromAccount: Account? = nil,
        toAccount: Account? = nil,
        notes: String? = nil,
        reference: String? = nil,
        taxQuarter: Int? = nil,
        taxYear: Int? = nil,
        taxAuthority: TaxAuthority? = nil,
        recurringTransfer: RecurringTransfer? = nil,
        interestPortion: Double? = nil,
        principalPortion: Double? = nil,
        paymentGroupId: UUID? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.amount = abs(amount)  // Always store positive
        self.transferTypeRaw = transferType.rawValue
        self.statusRaw = status.rawValue
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.notes = notes
        self.reference = reference
        self.taxQuarter = taxQuarter
        self.taxYear = taxYear
        self.taxAuthorityRaw = taxAuthority?.rawValue
        self.recurringTransfer = recurringTransfer
        self.interestPortion = interestPortion
        self.principalPortion = principalPortion
        self.paymentGroupId = paymentGroupId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Typed Accessors
    
    var transferType: TransferType {
        get { TransferType(rawValue: transferTypeRaw) ?? .internal }
        set { transferTypeRaw = newValue.rawValue }
    }
    
    var status: TransferStatus {
        get { TransferStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }
    
    var taxAuthority: TaxAuthority? {
        get { taxAuthorityRaw.flatMap { TaxAuthority(rawValue: $0) } }
        set { taxAuthorityRaw = newValue?.rawValue }
    }
    
    // MARK: - Computed Properties
    
    /// Display-friendly description of the transfer
    var displayDescription: String {
        let from = fromAccount?.name ?? "Unknown"
        let to = toAccount?.name ?? "Unknown"
        return "\(from) → \(to)"
    }
    
    /// Whether both accounts are set
    var isComplete: Bool {
        fromAccount != nil && toAccount != nil
    }
    
    /// Whether this is a cross-finance-type transfer (business ↔ personal)
    var isCrossFinanceType: Bool {
        guard let from = fromAccount, let to = toAccount else { return false }
        return from.financeType != to.financeType
    }
    
    /// Infer the transfer type based on account finance types
    var inferredTransferType: TransferType {
        guard let from = fromAccount, let to = toAccount else { return .internal }
        
        // Check for debt payment first
        if to.accountType == .creditCard || to.accountType == .loan {
            return .debtPayment
        }
        
        // Check for cross-finance-type transfers
        if from.financeType == .business && to.financeType == .personal {
            return .ownersDraw
        }
        if from.financeType == .personal && to.financeType == .business {
            return .capitalContribution
        }
        
        // Same finance type = internal
        return .internal
    }
    
    /// Whether this debt payment has a principal/interest breakdown
    var hasPaymentSplit: Bool {
        interestPortion != nil && principalPortion != nil
    }

    /// Whether this is a debt payment (to a credit card or loan account)
    var isDebtPayment: Bool {
        transferType == .debtPayment ||
        (toAccount?.accountType == .creditCard || toAccount?.accountType == .loan)
    }

    /// Calculates the interest portion using the destination account's APR and balance
    /// Uses the standard formula: balance * (APR / 12 / 100)
    func autoCalculatedInterest() -> Double? {
        guard let account = toAccount,
              let apr = account.apr, apr > 0,
              account.currentBalance < 0 else { return nil }
        let monthlyRate = apr / 12.0 / 100.0
        return abs(account.currentBalance) * monthlyRate
    }

    /// Formatted amount for display
    var formattedAmount: String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    /// Whether this transfer has linked bank transactions
    var hasLinkedTransactions: Bool {
        linkedWithdrawalID != nil || linkedDepositID != nil
    }
    
    /// Whether this transfer is from a recurring schedule
    var isFromRecurring: Bool {
        recurringTransfer != nil
    }
}

// MARK: - Tax Authority Enum

/// For tax payment transfers
enum TaxAuthority: String, Codable, CaseIterable {
    case federalIRS = "federal"
    case state = "state"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .federalIRS: return "Federal (IRS)"
        case .state:      return "State"
        case .local:      return "Local"
        }
    }
    
    var icon: String {
        switch self {
        case .federalIRS: return "building.columns.fill"
        case .state:      return "flag.fill"
        case .local:      return "mappin.circle.fill"
        }
    }
}

// MARK: - Protocol Conformances

extension Transfer: Identifiable { }

extension Transfer: Equatable {
    static func == (lhs: Transfer, rhs: Transfer) -> Bool {
        lhs.id == rhs.id
    }
}

extension Transfer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension Transfer {
    
    @MainActor static var previewOwnersDraw: Transfer {
        Transfer(
            date: Date(),
            amount: 2500.00,
            transferType: .ownersDraw,
            notes: "Monthly draw for living expenses"
        )
    }
    
    @MainActor static var previewDebtPayment: Transfer {
        Transfer(
            date: Date(),
            amount: 1245.67,
            transferType: .debtPayment,
            notes: "Credit card payment"
        )
    }
    
    @MainActor static var previewTaxPayment: Transfer {
        Transfer(
            date: Date(),
            amount: 3500.00,
            transferType: .taxPayment,
            notes: "Q1 2026 estimated tax",
            taxQuarter: 1,
            taxYear: 2026,
            taxAuthority: .federalIRS
        )
    }
    
    @MainActor static var previewInternal: Transfer {
        Transfer(
            date: Date(),
            amount: 5000.00,
            transferType: .internal,
            notes: "Move to savings"
        )
    }
}
#endif
