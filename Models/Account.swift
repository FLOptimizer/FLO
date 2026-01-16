//  Account.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1.2 - Added missing methods for AccountsView
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1.2:
//  ✅ ADDED: touch() method to update modifiedDate
//  ✅ ADDED: lastSyncDescription computed property
//  ✅ ADDED: disconnectPlaid() method (alias for unlinkFromPlaid)
//
//  CHANGES v2.1.1:
//  ✅ FIXED: SwiftData requires fully qualified enum defaults
//     - Transaction.FinanceType.personal (not .personal)
//     - PlaidConnectionStatus.notConnected (not .notConnected)
//
//  CHANGES v2.1:
//  ✅ FIXED: Use Transaction.FinanceType instead of separate Account.FinanceType
//  ✅ This allows direct comparison between account and transaction finance types
//
//  FEATURES v2.0:
//  ✅ Balance tracking with manual and automatic updates
//  ✅ Business/Personal classification (financeType)
//  ✅ Bank identification (last 4 digits, institution name)
//  ✅ Plaid integration fields for Pro tier
//  ✅ Transaction relationship for filtering
//  ✅ Account statistics and computed properties
//  ✅ Premium/Pro tier feature support
//

import Foundation
import SwiftData

@Model
final class Account {
    
    // MARK: - Identifiers
    
    @Attribute(.unique) private(set) var id: UUID
    
    // MARK: - Core Properties
    
    /// Account display name
    var name: String
    
    /// Type of account (checking, savings, credit card, etc.)
    var accountType: AccountType
    
    /// Whether this is the primary/default account
    var isPrimary: Bool
    
    /// Whether the account is active
    var isActive: Bool
    
    /// Optional notes about the account
    var notes: String
    
    // MARK: - Balance Tracking
    
    /// Current account balance (positive for assets, negative for liabilities)
    var currentBalance: Double = 0.0
    
    /// When the balance was last updated
    var lastBalanceUpdate: Date = Date()
    
    /// Starting balance when account was created
    var startingBalance: Double = 0.0
    
    // MARK: - Classification
    
    /// Business vs Personal classification - Uses Transaction.FinanceType for compatibility
    var financeType: Transaction.FinanceType = Transaction.FinanceType.personal
    
    // MARK: - Bank Identification
    
    /// Last 4 digits of account number (for identification)
    var lastFourDigits: String?
    
    /// Financial institution name
    var institutionName: String?
    
    /// Custom color for the account (hex string)
    var colorHex: String?
    
    // MARK: - Plaid Integration (Pro tier)
    
    /// Plaid account ID (for linked accounts)
    var plaidAccountId: String?
    
    /// Plaid item ID (groups accounts from same institution)
    var plaidItemId: String?
    
    /// Whether this account is linked to Plaid
    var isLinked: Bool = false
    
    /// Plaid connection status
    var plaidStatus: PlaidConnectionStatus = PlaidConnectionStatus.notConnected
    
    /// Last successful Plaid sync
    var lastPlaidSync: Date?
    
    // MARK: - Metadata
    
    /// When the account was created
    var createdDate: Date
    
    /// When the account was last modified
    var modifiedDate: Date
    
    // MARK: - Relationships
    
    /// Transactions associated with this account
    @Relationship(deleteRule: .nullify)
    var transactions: [Transaction]?
    
    /// Budgets associated with this account
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?
    
    // MARK: - Initialization
    
    init(
        name: String,
        accountType: AccountType = .checking,
        isPrimary: Bool = false,
        isActive: Bool = true,
        notes: String = "",
        currentBalance: Double = 0.0,
        startingBalance: Double = 0.0,
        financeType: Transaction.FinanceType = .personal,
        lastFourDigits: String? = nil,
        institutionName: String? = nil,
        colorHex: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.accountType = accountType
        self.isPrimary = isPrimary
        self.isActive = isActive
        self.notes = notes
        self.currentBalance = currentBalance
        self.startingBalance = startingBalance
        self.lastBalanceUpdate = Date()
        self.financeType = financeType
        self.lastFourDigits = lastFourDigits
        self.institutionName = institutionName
        self.colorHex = colorHex
        self.isLinked = false
        self.plaidStatus = .notConnected
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Account icon based on type
    var icon: String {
        accountType.icon
    }
    
    /// Account color (custom or default based on type)
    var color: String {
        colorHex ?? accountType.color
    }
    
    /// Display name with last 4 digits if available
    var displayNameWithDigits: String {
        if let digits = lastFourDigits, !digits.isEmpty {
            return "\(name) •••• \(digits)"
        }
        return name
    }
    
    /// Full display name with institution
    var fullDisplayName: String {
        if let institution = institutionName, !institution.isEmpty {
            return "\(name) (\(institution))"
        }
        return name
    }
    
    /// Whether this is a liability account
    var isLiability: Bool {
        !accountType.isAsset
    }
    
    /// Whether this is an asset account
    var isAsset: Bool {
        accountType.isAsset
    }
    
    /// Formatted balance string
    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: currentBalance)) ?? "$0.00"
    }
    
    /// Balance status indicator
    var balanceStatus: BalanceStatus {
        if isLiability {
            // For credit cards/loans, closer to zero is better
            if currentBalance >= 0 {
                return .positive
            } else if currentBalance > -1000 {
                return .neutral
            } else {
                return .negative
            }
        } else {
            // For assets, higher is better
            if currentBalance > 1000 {
                return .positive
            } else if currentBalance >= 0 {
                return .neutral
            } else {
                return .negative
            }
        }
    }
    
    // MARK: - Transaction Statistics
    
    /// Total income into this account
    var totalIncome: Double {
        transactions?.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } ?? 0
    }
    
    /// Total expenses from this account
    var totalExpenses: Double {
        transactions?.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } ?? 0
    }
    
    /// Net change from transactions
    var netChange: Double {
        totalIncome - totalExpenses
    }
    
    /// Number of transactions
    var transactionCount: Int {
        transactions?.count ?? 0
    }
    
    /// Calculated balance based on starting balance + transactions
    var calculatedBalance: Double {
        startingBalance + netChange
    }
    
    /// Whether calculated balance matches current balance
    var isBalanceReconciled: Bool {
        abs(calculatedBalance - currentBalance) < 0.01
    }
    
    // MARK: - Plaid Properties
    
    /// Whether account needs re-authentication
    var needsReauth: Bool {
        plaidStatus == .needsReauth
    }
    
    /// Whether account is syncing
    var isSyncing: Bool {
        plaidStatus == .syncing
    }
    
    /// Time since last sync
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastPlaidSync else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    // MARK: - Methods
    
    /// Update the account balance
    func updateBalance(_ newBalance: Double) {
        currentBalance = newBalance
        lastBalanceUpdate = Date()
        modifiedDate = Date()
    }
    
    /// Mark as primary account
    func markAsPrimary() {
        isPrimary = true
        modifiedDate = Date()
    }
    
    /// Deactivate the account
    func deactivate() {
        isActive = false
        modifiedDate = Date()
    }
    
    /// Activate the account
    func activate() {
        isActive = true
        modifiedDate = Date()
    }
    
    /// Link to Plaid
    func linkToPlaid(accountId: String, itemId: String) {
        plaidAccountId = accountId
        plaidItemId = itemId
        isLinked = true
        plaidStatus = .connected
        lastPlaidSync = Date()
        modifiedDate = Date()
    }
    
    /// Unlink from Plaid
    func unlinkFromPlaid() {
        plaidAccountId = nil
        plaidItemId = nil
        isLinked = false
        plaidStatus = .notConnected
        modifiedDate = Date()
    }
    
    /// Disconnect Plaid (alias for unlinkFromPlaid)
    func disconnectPlaid() {
        unlinkFromPlaid()
    }
    
    /// Update modified date (touch)
    func touch() {
        modifiedDate = Date()
    }
    
    /// Human-readable description of last sync time
    var lastSyncDescription: String {
        guard let lastSync = lastPlaidSync else {
            return "Never synced"
        }
        
        let interval = Date().timeIntervalSince(lastSync)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Account Type

enum AccountType: String, Codable, CaseIterable {
    case checking = "checking"
    case savings = "savings"
    case creditCard = "creditCard"
    case cash = "cash"
    case paypal = "paypal"
    case venmo = "venmo"
    case zelle = "zelle"
    case investment = "investment"
    case loan = "loan"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .checking: return "Checking"
        case .savings: return "Savings"
        case .creditCard: return "Credit Card"
        case .cash: return "Cash"
        case .paypal: return "PayPal"
        case .venmo: return "Venmo"
        case .zelle: return "Zelle"
        case .investment: return "Investment"
        case .loan: return "Loan"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .checking: return "building.columns.fill"
        case .savings: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .cash: return "dollarsign.circle.fill"
        case .paypal: return "p.circle.fill"
        case .venmo: return "v.circle.fill"
        case .zelle: return "z.circle.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .loan: return "arrow.left.arrow.right"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .checking: return "#14B8A6"    // Teal
        case .savings: return "#10B981"     // Green
        case .creditCard: return "#F59E0B"  // Amber
        case .cash: return "#22C55E"        // Cash green
        case .paypal: return "#0070BA"      // PayPal blue
        case .venmo: return "#3D95CE"       // Venmo blue
        case .zelle: return "#6D1ED4"       // Zelle purple
        case .investment: return "#8B5CF6"  // Purple
        case .loan: return "#EF4444"        // Red
        case .other: return "#6B7280"       // Gray
        }
    }
    
    /// Whether this account type is an asset (vs liability)
    var isAsset: Bool {
        switch self {
        case .checking, .savings, .cash, .paypal, .venmo, .zelle, .investment:
            return true
        case .creditCard, .loan:
            return false
        case .other:
            return true // Default to asset
        }
    }
    
    /// Whether this account type supports Plaid linking
    var supportsPlaid: Bool {
        switch self {
        case .checking, .savings, .creditCard, .investment, .loan:
            return true
        case .cash, .paypal, .venmo, .zelle, .other:
            return false
        }
    }
    
    /// Account types that are typically business accounts
    static var businessTypes: [AccountType] {
        [.checking, .savings, .creditCard, .paypal]
    }
    
    /// Digital wallet types
    static var digitalWallets: [AccountType] {
        [.paypal, .venmo, .zelle]
    }
}

// MARK: - Plaid Connection Status

enum PlaidConnectionStatus: String, Codable {
    case notConnected = "notConnected"
    case connected = "connected"
    case syncing = "syncing"
    case needsReauth = "needsReauth"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .notConnected: return "Not Connected"
        case .connected: return "Connected"
        case .syncing: return "Syncing..."
        case .needsReauth: return "Needs Re-authentication"
        case .error: return "Connection Error"
        }
    }
    
    var icon: String {
        switch self {
        case .notConnected: return "link.badge.plus"
        case .connected: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .needsReauth: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .notConnected: return "#6B7280"  // Gray
        case .connected: return "#10B981"     // Green
        case .syncing: return "#3B82F6"       // Blue
        case .needsReauth: return "#F59E0B"   // Amber
        case .error: return "#EF4444"         // Red
        }
    }
}

// MARK: - Balance Status

enum BalanceStatus {
    case positive
    case neutral
    case negative
    
    var color: String {
        switch self {
        case .positive: return "#10B981"  // Green
        case .neutral: return "#6B7280"   // Gray
        case .negative: return "#EF4444"  // Red
        }
    }
    
    var icon: String {
        switch self {
        case .positive: return "arrow.up.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .negative: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Protocol Conformances

extension Account: Identifiable {}

extension Account: Equatable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        lhs.id == rhs.id
    }
}

extension Account: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension Account {
    @MainActor static var previewChecking: Account {
        Account(
            name: "Main Checking",
            accountType: .checking,
            isPrimary: true,
            currentBalance: 5432.10,
            startingBalance: 1000.00,
            financeType: .personal,
            lastFourDigits: "4521",
            institutionName: "Chase"
        )
    }
    
    @MainActor static var previewSavings: Account {
        Account(
            name: "Emergency Fund",
            accountType: .savings,
            currentBalance: 15000.00,
            startingBalance: 10000.00,
            financeType: .personal,
            lastFourDigits: "7890",
            institutionName: "Ally Bank"
        )
    }
    
    @MainActor static var previewCreditCard: Account {
        Account(
            name: "Rewards Card",
            accountType: .creditCard,
            currentBalance: -1250.00,
            financeType: .personal,
            lastFourDigits: "1234",
            institutionName: "Capital One"
        )
    }
    
    @MainActor static var previewBusiness: Account {
        Account(
            name: "Business Checking",
            accountType: .checking,
            currentBalance: 12500.00,
            startingBalance: 5000.00,
            financeType: .business,
            lastFourDigits: "9876",
            institutionName: "Bank of America"
        )
    }
    
    @MainActor static var previewCash: Account {
        Account(
            name: "Cash on Hand",
            accountType: .cash,
            currentBalance: 350.00,
            financeType: .personal
        )
    }
}
#endif
