// SubscriptionTier.swift
// FLO - Finance Ledger Optimizer
//
// Version 1.1 - Added account management and Plaid integration features
// Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
// Defines subscription tiers and feature access control
//
// CHANGES v1.1:
// ✅ Added account management features (hasMultipleAccounts, accountLimit)
// ✅ Added Plaid integration feature (hasPlaidIntegration, hasBankSync)
// ✅ Added account filtering feature (hasAccountFiltering)
// ✅ Added multi-account reporting feature (hasMultiAccountReports)
// ✅ Updated feature lists for all tiers
// ✅ Added new Feature enum cases
// ✅ Maintained all v1.0 functionality
//

import Foundation

// MARK: - Subscription Period

enum SubscriptionPeriod {
    case monthly
    case yearly
}

// MARK: - Subscription Tier

enum SubscriptionTier: Int, Codable, Comparable {
  case free = 0
  case premium = 1
  case pro = 2
  
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Premium"
        case .pro:
            return "Pro"
        }
    }
    
    var tagline: String {
        switch self {
        case .free:
            return "Essential tracking"
        case .premium:
            return "For serious freelancers"
        case .pro:
            return "Complete business suite"
        }
    }
    
    var monthlyPrice: String {
        switch self {
        case .free:
            return "$0"
        case .premium:
            return "$12.99"
        case .pro:
            return "$19.99"
        }
    }
    
    var yearlyPrice: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "$129.99"
        case .pro:
            return "$199.99"
        }
    }
    
    var yearlySavings: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "Save $25.89/year"
        case .pro:
            return "Save $39.89/year"
        }
    }
    
    // MARK: - Feature Access Control
    
    /// Tax estimate features (quarterly calculations, IRS rates)
    var hasTaxEstimates: Bool {
        self >= .premium
    }
    
    /// Automated GPS mileage tracking
    var hasAutomatedMileage: Bool {
        self >= .premium
    }
    
    /// Professional invoice creation
    var hasInvoicing: Bool {
        self >= .premium
    }
    
    /// Advanced budget features with rollover
    var hasAdvancedBudgets: Bool {
        self >= .premium
    }
    
    /// Recurring transaction automation
    var hasRecurringTransactions: Bool {
        self >= .premium
    }
    
    // MARK: - Account Features (NEW in v1.1)
    
    /// Multiple account support
    var hasMultipleAccounts: Bool {
        self >= .premium
    }
    
    /// Account-based transaction filtering
    var hasAccountFiltering: Bool {
        self >= .premium
    }
    
    /// Multi-account reporting and analytics
    var hasMultiAccountReports: Bool {
        self >= .premium
    }
    
    /// Balance tracking across accounts
    var hasBalanceTracking: Bool {
        self >= .premium
    }
    
    /// Plaid integration for automatic bank sync (Pro only)
    var hasPlaidIntegration: Bool {
        self == .pro
    }
    
    /// Automatic bank transaction sync (Pro only)
    var hasBankSync: Bool {
        self == .pro
    }
    
    /// Account reconciliation tools (Pro only)
    var hasAccountReconciliation: Bool {
        self == .pro
    }
    
    // MARK: - Pro-Only Features
    
    /// Advanced tax deduction flagging with ML
    var hasAdvancedDeductions: Bool {
        self == .pro
    }
    
    /// Client management (unlimited clients)
    var hasClientManagement: Bool {
        self == .pro
    }
    
    /// Custom invoice branding (logo, colors)
    var hasCustomBranding: Bool {
        self == .pro
    }
    
    /// Export to CSV/PDF for accountants
    var hasAdvancedExports: Bool {
        self == .pro
    }
    
    /// Priority customer support
    var hasPrioritySupport: Bool {
        self == .pro
    }
    
    // MARK: - Limits
    
    /// Transaction limit per month
    var transactionLimit: Int? {
        switch self {
        case .free:
            return 50 // Free users get 50 transactions per month
        case .premium, .pro:
            return nil // Unlimited
        }
    }
    
    /// Receipt storage limit
    var receiptStorageLimit: Int? {
        switch self {
        case .free:
            return 20 // Free users get 20 receipts
        case .premium:
            return 100 // Premium users get 100 receipts
        case .pro:
            return nil // Pro users get unlimited
        }
    }
    
    /// Invoice limit per month
    var invoiceLimit: Int? {
        switch self {
        case .free:
            return 0 // No invoices in free tier
        case .premium:
            return 25 // Premium users get 25 invoices per month
        case .pro:
            return nil // Unlimited invoices
        }
    }
    
    /// Client limit
    var clientLimit: Int? {
        switch self {
        case .free, .premium:
            return 0 // No client management
        case .pro:
            return nil // Unlimited clients
        }
    }
    
    /// Account limit (NEW in v1.1)
    var accountLimit: Int? {
        switch self {
        case .free:
            return 1 // Free users get 1 account
        case .premium:
            return 5 // Premium users get 5 accounts
        case .pro:
            return nil // Unlimited accounts
        }
    }
    
    /// Linked bank account limit (Plaid) (NEW in v1.1)
    var linkedAccountLimit: Int? {
        switch self {
        case .free, .premium:
            return 0 // No Plaid linking
        case .pro:
            return nil // Unlimited linked accounts
        }
    }
    
    // MARK: - Feature Lists
    
    /// Complete feature list for this tier
    var features: [String] {
        switch self {
        case .free:
            return [
                "Up to 50 transactions per month",
                "1 manual account",
                "Manual transaction entry",
                "Basic expense tracking",
                "Simple budgeting tools",
                "20 receipt storage",
                "Business/Personal separation"
            ]
        case .premium:
            return [
                "Everything in Free",
                "Unlimited transactions",
                "Up to 5 accounts with balance tracking",
                "Account-based filtering & reports",
                "Real-time quarterly tax estimates",
                "Automated GPS mileage tracking",
                "Professional invoice creation (25/month)",
                "Receipt scanning with OCR",
                "100 receipt storage",
                "Advanced budgets with rollover",
                "Recurring transaction automation",
                "Dashboard widgets"
            ]
        case .pro:
            return [
                "Everything in Premium",
                "Unlimited accounts",
                "Account reconciliation tools",
                "Unlimited invoices",
                "Advanced tax deduction flagging",
                "Unlimited client management",
                "Custom invoice branding",
                "Export to CSV/PDF",
                "Unlimited receipt storage",
                "Priority support",
                "Advanced reporting",
                "Early access to new features"
            ]
        }
    }
    
    /// Key features for marketing (shorter list)
    var keyFeatures: [String] {
        switch self {
        case .free:
            return [
                "Basic expense tracking",
                "1 account",
                "50 transactions/month"
            ]
        case .premium:
            return [
                "5 accounts with balance tracking",
                "Tax estimates & mileage tracking",
                "Professional invoicing",
                "Unlimited transactions"
            ]
        case .pro:
            return [
                "Unlimited accounts + Bank sync",
                "Client management",
                "Custom branding",
                "Priority support"
            ]
        }
    }
    
    // MARK: - Product IDs
    
    /// App Store product identifier for monthly subscription
    var productID: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "com.finchandpoppy.flo.premium.monthly"
        case .pro:
            return "com.finchandpoppy.flo.pro.monthly"
        }
    }
    
    /// App Store product identifier for yearly subscription
    var yearlyProductID: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "com.finchandpoppy.flo.premium.yearly"
        case .pro:
            return "com.finchandpoppy.flo.pro.yearly"
        }
    }
    
    // MARK: - Comparable
    
    static func < (lhs: SubscriptionTier, rhs: SubscriptionTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - SubscriptionTier Extension for Product IDs

extension SubscriptionTier {
    func getProductID(for period: SubscriptionPeriod) -> String? {
        switch period {
        case .monthly:
            return productID
        case .yearly:
            return yearlyProductID
        }
    }
}

// MARK: - Feature Check Extension

extension SubscriptionTier {
    
    /// Check if this tier can access a specific feature
    func canAccess(_ feature: Feature) -> Bool {
        switch feature {
        case .taxEstimates:
            return hasTaxEstimates
        case .automatedMileage:
            return hasAutomatedMileage
        case .invoicing:
            return hasInvoicing
        case .advancedBudgets:
            return hasAdvancedBudgets
        case .recurringTransactions:
            return hasRecurringTransactions
        case .advancedDeductions:
            return hasAdvancedDeductions
        case .clientManagement:
            return hasClientManagement
        case .customBranding:
            return hasCustomBranding
        case .advancedExports:
            return hasAdvancedExports
        case .prioritySupport:
            return hasPrioritySupport
        // NEW in v1.1
        case .multipleAccounts:
            return hasMultipleAccounts
        case .accountFiltering:
            return hasAccountFiltering
        case .balanceTracking:
            return hasBalanceTracking
        case .plaidIntegration:
            return hasPlaidIntegration
        case .bankSync:
            return hasBankSync
        case .accountReconciliation:
            return hasAccountReconciliation
        case .multiAccountReports:
            return hasMultiAccountReports
        }
    }
    
    /// Get descriptive message for locked feature
    func lockMessage(for feature: Feature) -> String {
        let requiredTier = feature.requiredTier
        return "Upgrade to \(requiredTier.displayName) to unlock \(feature.displayName)"
    }
    
    /// Check if user can add more of a limited resource
    func canAddMore(current: Int, limitType: LimitType) -> Bool {
        let limit: Int?
        switch limitType {
        case .transactions:
            limit = transactionLimit
        case .receipts:
            limit = receiptStorageLimit
        case .invoices:
            limit = invoiceLimit
        case .clients:
            limit = clientLimit
        case .accounts:
            limit = accountLimit
        case .linkedAccounts:
            limit = linkedAccountLimit
        }
        
        guard let maxLimit = limit else { return true } // nil = unlimited
        return current < maxLimit
    }
    
    /// Get remaining count for a limited resource
    func remainingCount(current: Int, limitType: LimitType) -> Int? {
        let limit: Int?
        switch limitType {
        case .transactions:
            limit = transactionLimit
        case .receipts:
            limit = receiptStorageLimit
        case .invoices:
            limit = invoiceLimit
        case .clients:
            limit = clientLimit
        case .accounts:
            limit = accountLimit
        case .linkedAccounts:
            limit = linkedAccountLimit
        }
        
        guard let maxLimit = limit else { return nil } // nil = unlimited
        return max(0, maxLimit - current)
    }
}

// MARK: - Limit Types

enum LimitType {
    case transactions
    case receipts
    case invoices
    case clients
    case accounts
    case linkedAccounts
    
    var displayName: String {
        switch self {
        case .transactions: return "transactions"
        case .receipts: return "receipts"
        case .invoices: return "invoices"
        case .clients: return "clients"
        case .accounts: return "accounts"
        case .linkedAccounts: return "linked bank accounts"
        }
    }
}

// MARK: - Feature Enum

enum Feature {
    // Premium features
    case taxEstimates
    case automatedMileage
    case invoicing
    case advancedBudgets
    case recurringTransactions
    
    // Premium account features (NEW in v1.1)
    case multipleAccounts
    case accountFiltering
    case balanceTracking
    case multiAccountReports
    
    // Pro features
    case advancedDeductions
    case clientManagement
    case customBranding
    case advancedExports
    case prioritySupport
    
    // Pro account features (NEW in v1.1)
    case plaidIntegration
    case bankSync
    case accountReconciliation
    
    var displayName: String {
        switch self {
        case .taxEstimates:
            return "Tax Estimates"
        case .automatedMileage:
            return "Automated Mileage"
        case .invoicing:
            return "Professional Invoicing"
        case .advancedBudgets:
            return "Advanced Budgets"
        case .recurringTransactions:
            return "Recurring Transactions"
        case .advancedDeductions:
            return "Advanced Deductions"
        case .clientManagement:
            return "Client Management"
        case .customBranding:
            return "Custom Branding"
        case .advancedExports:
            return "Advanced Exports"
        case .prioritySupport:
            return "Priority Support"
        // NEW in v1.1
        case .multipleAccounts:
            return "Multiple Accounts"
        case .accountFiltering:
            return "Account Filtering"
        case .balanceTracking:
            return "Balance Tracking"
        case .plaidIntegration:
            return "Bank Integration"
        case .bankSync:
            return "Auto Bank Sync"
        case .accountReconciliation:
            return "Account Reconciliation"
        case .multiAccountReports:
            return "Multi-Account Reports"
        }
    }
    
    var requiredTier: SubscriptionTier {
        switch self {
        // Premium features
        case .taxEstimates, .automatedMileage, .invoicing, .advancedBudgets, .recurringTransactions,
             .multipleAccounts, .accountFiltering, .balanceTracking, .multiAccountReports:
            return .premium
        // Pro features
        case .advancedDeductions, .clientManagement, .customBranding, .advancedExports, .prioritySupport,
             .plaidIntegration, .bankSync, .accountReconciliation:
            return .pro
        }
    }
    
    var icon: String {
        switch self {
        case .taxEstimates:
            return "chart.bar.fill"
        case .automatedMileage:
            return "location.fill"
        case .invoicing:
            return "doc.text.fill"
        case .advancedBudgets:
            return "wallet.pass.fill"
        case .recurringTransactions:
            return "arrow.triangle.2.circlepath"
        case .advancedDeductions:
            return "sparkles"
        case .clientManagement:
            return "person.2.fill"
        case .customBranding:
            return "paintbrush.fill"
        case .advancedExports:
            return "square.and.arrow.up.fill"
        case .prioritySupport:
            return "bubble.left.and.bubble.right.fill"
        // NEW in v1.1
        case .multipleAccounts:
            return "building.columns.fill"
        case .accountFiltering:
            return "line.3.horizontal.decrease.circle.fill"
        case .balanceTracking:
            return "dollarsign.circle.fill"
        case .plaidIntegration:
            return "link.circle.fill"
        case .bankSync:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .accountReconciliation:
            return "checkmark.circle.fill"
        case .multiAccountReports:
            return "chart.pie.fill"
        }
    }
    
    var description: String {
        switch self {
        case .taxEstimates:
            return "Real-time quarterly tax estimates using IRS brackets"
        case .automatedMileage:
            return "GPS-based automatic mileage tracking for tax deductions"
        case .invoicing:
            return "Create and send professional invoices to clients"
        case .advancedBudgets:
            return "Envelope budgeting with rollover and category tracking"
        case .recurringTransactions:
            return "Automate regular income and expenses"
        case .advancedDeductions:
            return "Smart detection of potential tax deductions"
        case .clientManagement:
            return "Track client details, payment history, and reliability"
        case .customBranding:
            return "Add your logo and colors to invoices"
        case .advancedExports:
            return "Export data for your accountant in CSV/PDF format"
        case .prioritySupport:
            return "Get faster responses from our support team"
        // NEW in v1.1
        case .multipleAccounts:
            return "Track multiple bank accounts and credit cards"
        case .accountFiltering:
            return "Filter transactions and reports by account"
        case .balanceTracking:
            return "Monitor balances across all your accounts"
        case .plaidIntegration:
            return "Connect your bank for automatic transaction import"
        case .bankSync:
            return "Automatically sync transactions from your bank"
        case .accountReconciliation:
            return "Match and reconcile bank transactions"
        case .multiAccountReports:
            return "See consolidated reports across all accounts"
        }
    }
}

// MARK: - Upgrade Prompt Helper

extension SubscriptionTier {
    /// Get upgrade prompt for a specific feature
    func upgradePrompt(for feature: Feature) -> UpgradePrompt {
        UpgradePrompt(
            title: "Unlock \(feature.displayName)",
            message: feature.description,
            requiredTier: feature.requiredTier,
            icon: feature.icon
        )
    }
    
    /// Get upgrade prompt for hitting a limit
    func limitPrompt(for limitType: LimitType) -> UpgradePrompt {
        let nextTier: SubscriptionTier = self == .free ? .premium : .pro
        
        return UpgradePrompt(
            title: "\(limitType.displayName.capitalized) Limit Reached",
            message: "Upgrade to \(nextTier.displayName) for more \(limitType.displayName)",
            requiredTier: nextTier,
            icon: "exclamationmark.triangle.fill"
        )
    }
}

/// Upgrade prompt data structure
struct UpgradePrompt {
    let title: String
    let message: String
    let requiredTier: SubscriptionTier
    let icon: String
    
    var ctaText: String {
        "Upgrade to \(requiredTier.displayName)"
    }
}
