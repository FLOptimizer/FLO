//  Account.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.4
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.4:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (multiplication symbols)
//
//  CHANGES v3.3:
//  - Fixed UTF-8 encoding in displayNameWithDigits (garbled bullet characters)
//
//  CHANGES v3.2:
//  - Fixed creditUtilization to return 0 for overpaid cards (positive balance)
//  - Added statementCloseDay parameter to convenience initializer
//  - Added validation for creditLimit > 0 (prevents divide-by-zero)
//
//  CHANGES v3.1:
//  - Added validateCreditCardFields() method for input validation
//  - Added creditUtilizationClamped for UI progress bars (0-100)
//  - Added convenience static method for creating credit card accounts
//  - Updated lastSyncDescription to use RelativeDateTimeFormatter for localization
//  - Added detailed documentation for minimumPaymentDue calculation
//  - Added payoffMonthsAtMinimum computed property for debt projection
//
//  CHANGES v3.0:
//  - Added showOnDashboard toggle for dashboard visibility control
//  - Added credit card specific fields (APR, credit limit, payment dates)
//  - Added computed properties for interest calculations
//  - Added minimum payment calculations
//  - Fixed UTF-8 encoding issues
//
//  FEATURES:
//  - Balance tracking with manual and automatic updates
//  - Business/Personal classification (financeType)
//  - Bank identification (last 4 digits, institution name)
//  - Plaid integration fields for Pro tier
//  - Transaction relationship for filtering
//  - Account statistics and computed properties
//  - Premium/Pro tier feature support
//  - Credit card interest and payment tracking
//  - Input validation for credit card fields
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
    
    // MARK: - Dashboard Display
    
    /// Whether to show this account on the dashboard summary card
    /// Allows users to track accounts without cluttering the dashboard
    var showOnDashboard: Bool = true
    
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
    
    // MARK: - Credit Card Specific Fields
    
    /// Credit limit (for credit cards)
    var creditLimit: Double?
    
    /// Annual Percentage Rate (APR) for interest calculations
    /// Stored as percentage (e.g., 24.99 for 24.99%)
    var apr: Double?
    
    /// Minimum payment percentage of balance (e.g., 2.0 for 2%)
    var minimumPaymentPercent: Double?
    
    /// Minimum payment floor amount (e.g., $25 minimum regardless of percentage)
    var minimumPaymentFloor: Double?
    
    /// Day of month when statement closes (1-31)
    var statementCloseDay: Int?
    
    /// Day of month when payment is due (1-31)
    var paymentDueDay: Int?
    
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
        showOnDashboard: Bool = true,
        currentBalance: Double = 0.0,
        startingBalance: Double = 0.0,
        financeType: Transaction.FinanceType = .personal,
        lastFourDigits: String? = nil,
        institutionName: String? = nil,
        colorHex: String? = nil,
        creditLimit: Double? = nil,
        apr: Double? = nil,
        minimumPaymentPercent: Double? = nil,
        minimumPaymentFloor: Double? = nil,
        statementCloseDay: Int? = nil,
        paymentDueDay: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.accountType = accountType
        self.isPrimary = isPrimary
        self.isActive = isActive
        self.notes = notes
        self.showOnDashboard = showOnDashboard
        self.currentBalance = currentBalance
        self.startingBalance = startingBalance
        self.lastBalanceUpdate = Date()
        self.financeType = financeType
        self.lastFourDigits = lastFourDigits
        self.institutionName = institutionName
        self.colorHex = colorHex
        self.creditLimit = creditLimit
        self.apr = apr
        self.minimumPaymentPercent = minimumPaymentPercent
        self.minimumPaymentFloor = minimumPaymentFloor
        self.statementCloseDay = statementCloseDay
        self.paymentDueDay = paymentDueDay
        self.isLinked = false
        self.plaidStatus = .notConnected
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Convenience Initializers
    
    /// Convenience initializer for credit card accounts with common defaults
    /// - Parameters:
    ///   - name: Display name for the card
    ///   - institutionName: Card issuer (e.g., "Chase", "Capital One")
    ///   - lastFourDigits: Last 4 digits of card number
    ///   - creditLimit: Total credit limit
    ///   - apr: Annual Percentage Rate (as percentage, e.g., 24.99)
    ///   - statementCloseDay: Day of month statement closes (1-31), optional
    ///   - paymentDueDay: Day of month payment is due (1-31)
    ///   - financeType: Business or Personal classification
    ///   - currentBalance: Current balance (negative for amount owed)
    /// - Returns: Configured Account instance for a credit card
    static func creditCard(
        name: String,
        institutionName: String,
        lastFourDigits: String,
        creditLimit: Double,
        apr: Double,
        statementCloseDay: Int? = nil,
        paymentDueDay: Int,
        financeType: Transaction.FinanceType = .personal,
        currentBalance: Double = 0.0
    ) -> Account {
        Account(
            name: name,
            accountType: .creditCard,
            currentBalance: currentBalance,
            financeType: financeType,
            lastFourDigits: lastFourDigits,
            institutionName: institutionName,
            creditLimit: creditLimit,
            apr: apr,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0,
            statementCloseDay: statementCloseDay,
            paymentDueDay: paymentDueDay
        )
    }
    
    // MARK: - Validation
    
    /// Validates credit card specific fields
    /// - Returns: Array of validation error messages (empty if valid)
    func validateCreditCardFields() -> [String] {
        var errors: [String] = []
        
        if let apr = apr {
            if apr < 0 {
                errors.append("APR cannot be negative")
            } else if apr > 100 {
                errors.append("APR seems unusually high (over 100%)")
            }
        }
        
        if let day = paymentDueDay {
            if day < 1 || day > 31 {
                errors.append("Payment due day must be between 1 and 31")
            }
        }
        
        if let day = statementCloseDay {
            if day < 1 || day > 31 {
                errors.append("Statement close day must be between 1 and 31")
            }
        }
        
        if let limit = creditLimit {
            if limit < 0 {
                errors.append("Credit limit cannot be negative")
            } else if limit == 0 {
                errors.append("Credit limit must be greater than zero")
            }
        }
        
        if let percent = minimumPaymentPercent {
            if percent < 0 {
                errors.append("Minimum payment percentage cannot be negative")
            } else if percent > 100 {
                errors.append("Minimum payment percentage cannot exceed 100%")
            }
        }
        
        if let floor = minimumPaymentFloor {
            if floor < 0 {
                errors.append("Minimum payment floor cannot be negative")
            }
        }
        
        return errors
    }
    
    /// Whether credit card fields are valid
    var areCreditCardFieldsValid: Bool {
        validateCreditCardFields().isEmpty
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
            return "\(name) **** \(digits)"
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
    
    // MARK: - Credit Card Computed Properties
    
    /// Whether this account is a credit card with balance
    var isCreditCardWithBalance: Bool {
        accountType == .creditCard && currentBalance < 0
    }
    
    /// Estimated monthly interest charge based on APR
    /// Formula: balance × (APR / 12 / 100)
    /// Returns nil if not a credit card or no APR set
    var estimatedMonthlyInterest: Double? {
        guard accountType == .creditCard,
              let apr = apr,
              apr > 0,
              currentBalance < 0 else { return nil }
        // Monthly interest = Balance × (APR / 12 / 100)
        return abs(currentBalance) * (apr / 100.0 / 12.0)
    }
    
    /// Daily interest rate based on APR
    /// Formula: APR / 100 / 365
    var dailyInterestRate: Double? {
        guard let apr = apr, apr > 0 else { return nil }
        return apr / 100.0 / 365.0
    }
    
    /// Estimated daily interest charge
    var estimatedDailyInterest: Double? {
        guard let dailyRate = dailyInterestRate,
              currentBalance < 0 else { return nil }
        return abs(currentBalance) * dailyRate
    }
    
    /// Minimum payment due based on percentage and floor
    ///
    /// Formula: max(balance × percent, min(floor, balance))
    ///
    /// This calculation ensures:
    /// 1. At least the percentage of balance is paid (e.g., 2%)
    /// 2. At least the floor amount is paid (e.g., $25)
    /// 3. But never more than the total balance for small balances
    ///
    /// Example scenarios:
    /// - $1,000 balance, 2%, $25 floor → max($20, min($25, $1000)) = max($20, $25) = $25
    /// - $2,000 balance, 2%, $25 floor → max($40, min($25, $2000)) = max($40, $25) = $40
    /// - $15 balance, 2%, $25 floor → max($0.30, min($25, $15)) = max($0.30, $15) = $15
    var minimumPaymentDue: Double? {
        guard accountType == .creditCard,
              currentBalance < 0 else { return nil }
        
        let balance = abs(currentBalance)
        let percent = minimumPaymentPercent ?? 2.0  // Default 2%
        let floor = minimumPaymentFloor ?? 25.0     // Default $25
        
        let percentPayment = balance * (percent / 100.0)
        return max(percentPayment, min(floor, balance))
    }
    
    /// Credit utilization percentage (can exceed 100% for over-limit accounts)
    /// Formula: (balance / limit) × 100
    /// Returns 0 for overpaid cards (positive balance) since utilization doesn't apply
    var creditUtilization: Double? {
        guard accountType == .creditCard,
              let limit = creditLimit,
              limit > 0 else { return nil }
        
        // Overpaid card (positive balance or zero) = 0% utilization
        guard currentBalance < 0 else { return 0 }
        
        return (abs(currentBalance) / limit) * 100.0
    }
    
    /// Credit utilization clamped to 0-100 for UI progress bars
    var creditUtilizationClamped: Double? {
        guard let utilization = creditUtilization else { return nil }
        return min(max(utilization, 0), 100)
    }
    
    /// Available credit remaining
    var availableCredit: Double? {
        guard accountType == .creditCard,
              let limit = creditLimit else { return nil }
        return max(0, limit - abs(currentBalance))
    }
    
    /// Credit utilization status for UI
    var utilizationStatus: CreditUtilizationStatus {
        guard let utilization = creditUtilization else { return .unknown }
        if utilization <= 30 {
            return .excellent
        } else if utilization <= 50 {
            return .good
        } else if utilization <= 75 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// Estimated months to pay off balance paying only minimum payments
    /// This is a simplified calculation assuming fixed interest and payments
    /// Returns nil if balance is paid off or no APR set
    var payoffMonthsAtMinimum: Int? {
        guard accountType == .creditCard,
              currentBalance < 0,
              let apr = apr,
              apr > 0,
              let minPayment = minimumPaymentDue,
              minPayment > 0 else { return nil }
        
        let monthlyRate = apr / 100.0 / 12.0
        var balance = abs(currentBalance)
        var months = 0
        let maxMonths = 600 // 50 year cap to prevent infinite loops
        
        while balance > 0.01 && months < maxMonths {
            let interest = balance * monthlyRate
            let payment = max(minPayment, min(minimumPaymentFloor ?? 25, balance + interest))
            balance = balance + interest - payment
            months += 1
        }
        
        return months < maxMonths ? months : nil
    }
    
    /// Next payment due date based on paymentDueDay
    var nextPaymentDueDate: Date? {
        guard let dueDay = paymentDueDay,
              dueDay >= 1 && dueDay <= 31 else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = dueDay
        
        // If we're past the due day this month, get next month's date
        if currentDay >= dueDay {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) {
                components = calendar.dateComponents([.year, .month], from: nextMonth)
                // Handle months with fewer days (e.g., Feb 31 → Feb 28)
                components.day = min(dueDay, calendar.range(of: .day, in: .month, for: nextMonth)?.count ?? 28)
            }
        }
        
        return calendar.date(from: components)
    }
    
    /// Days until next payment is due
    var daysUntilPaymentDue: Int? {
        guard let dueDate = nextPaymentDueDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: dueDate)
        return components.day
    }
    
    /// Whether payment is due soon (within 7 days)
    var isPaymentDueSoon: Bool {
        guard let days = daysUntilPaymentDue else { return false }
        return days <= 7 && days >= 0
    }
    
    /// Whether payment is overdue
    var isPaymentOverdue: Bool {
        guard let days = daysUntilPaymentDue else { return false }
        return days < 0
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
    
    /// Record a transaction on this account
    func recordTransaction(amount: Double, isIncome: Bool) {
        if isIncome {
            currentBalance += amount
        } else {
            currentBalance -= amount
        }
        lastBalanceUpdate = Date()
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
    
    /// Human-readable description of last sync time (localized)
    var lastSyncDescription: String {
        guard let lastSync = lastPlaidSync else {
            return "Never synced"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
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
    
    /// Whether this account type has credit card specific fields
    var hasCreditCardFields: Bool {
        self == .creditCard
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

// MARK: - Credit Utilization Status

enum CreditUtilizationStatus {
    case excellent  // 0-30%
    case good       // 31-50%
    case fair       // 51-75%
    case poor       // 76-100%+
    case unknown
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "High"
        case .unknown: return "Unknown"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "#10B981"  // Green
        case .good: return "#14B8A6"       // Teal
        case .fair: return "#F59E0B"       // Amber
        case .poor: return "#EF4444"       // Red
        case .unknown: return "#6B7280"    // Gray
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "exclamationmark.circle.fill"
        case .poor: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    var recommendation: String {
        switch self {
        case .excellent:
            return "Great job! Your credit utilization is optimal."
        case .good:
            return "Your utilization is good. Try to keep it under 30% for best results."
        case .fair:
            return "Consider paying down your balance to improve your credit score."
        case .poor:
            return "High utilization may negatively impact your credit score. Prioritize paying this down."
        case .unknown:
            return "Set a credit limit to track your utilization."
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
            institutionName: "Capital One",
            creditLimit: 5000.00,
            apr: 24.99,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0,
            statementCloseDay: 15,
            paymentDueDay: 10
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
    
    @MainActor static var previewBusinessCard: Account {
        Account(
            name: "Business Card",
            accountType: .creditCard,
            showOnDashboard: false,
            currentBalance: -3200.00,
            financeType: .business,
            lastFourDigits: "5555",
            institutionName: "Chase Ink",
            creditLimit: 15000.00,
            apr: 21.99,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 35.0,
            paymentDueDay: 25
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
    
    /// Preview using convenience initializer
    @MainActor static var previewConvenienceCard: Account {
        Account.creditCard(
            name: "Travel Rewards",
            institutionName: "Amex",
            lastFourDigits: "9999",
            creditLimit: 10000.00,
            apr: 19.99,
            statementCloseDay: 5,
            paymentDueDay: 15,
            financeType: .personal,
            currentBalance: -2500.00
        )
    }
    
    /// Preview for overpaid card (tests 0% utilization fix)
    @MainActor static var previewOverpaidCard: Account {
        Account(
            name: "Overpaid Card",
            accountType: .creditCard,
            currentBalance: 150.00,  // Positive = credit on account
            financeType: .personal,
            lastFourDigits: "0000",
            institutionName: "Discover",
            creditLimit: 3000.00,
            apr: 22.99,
            paymentDueDay: 20
        )
    }
}
#endif
