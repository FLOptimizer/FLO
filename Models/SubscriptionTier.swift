// SubscriptionTier.swift
// FLO - Finance Ledger Optimizer
//
// Version 1.5 - CSV Bank Statement Import Feature
// Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
// Defines subscription tiers and feature access control
//
//  CHANGES v1.5:
//  ✅ ADDED: hasCSVImport (Premium+) - CSV bank statement import
//  ✅ ADDED: Feature.csvImport case
//  ✅ Updated canAccess() for CSV import feature
//  ✅ Updated Premium feature list to include CSV import
//
//  CHANGES v1.4:
//  ✅ ADDED: hasDebtCalculator (Premium+)
//  ✅ ADDED: hasPersonalizedTips (Premium+)
//  ✅ ADDED: hasDebtInsights (Premium+)
//
// CHANGES v1.3:
// ✅ REMOVED: hasCustomBranding (not used in app)
// ✅ REMOVED: hasPrioritySupport (not used in app)
// ✅ REMOVED: Feature.customBranding and Feature.prioritySupport
// ✅ ADDED: hasProfitLossReports (Pro only)
// ✅ ADDED: hasYearEndTaxPackage (Pro only)
// ✅ ADDED: hasSmartReceiptScanning (Premium+)
// ✅ ADDED: Feature.profitLossReports and Feature.yearEndTaxPackage
// ✅ Updated canAccess() for new features
// ✅ Updated feature lists to match actual app features
//
// CHANGES v1.2:
// ✅ Added shortDisplayName for compact table headers (fixes "Pre-m" wrap)
// ✅ Changed hasClientManagement from Pro-only to Premium+ (invoicing requires clients!)
// ✅ Updated clientLimit: Free=0, Premium/Pro=unlimited
// ✅ Updated Feature.clientManagement requiredTier to .premium
// ✅ Updated feature lists to reflect client management in Premium
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
    
    /// Short display name for compact spaces like table headers
    /// v1.2: Fixes "Pre-m" word wrapping in Feature Comparison table
    var shortDisplayName: String {
        switch self {
        case .free:
            return "Free"
        case .premium:
            return "Prem"
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
    
    /// Smart receipt scanning with AI parsing (Premium+)
    /// v1.3: Added for tier-aware receipt routing
    var hasSmartReceiptScanning: Bool {
        self >= .premium
    }
    
    /// CSV bank statement import (Premium+)
    /// v1.5: Added for CSV import feature
    var hasCSVImport: Bool {
        self >= .premium
    }
    
    // MARK: - Debt & Financial Tips Features

    /// Access to the Debt Payoff Calculator (Premium+)
    var hasDebtCalculator: Bool {
        self >= .premium
    }

    /// Access to personalized Money Moves tips (Premium+)
    var hasPersonalizedTips: Bool {
        self >= .premium
    }

    /// Access to debt strategy insights on dashboard (Premium+)
    var hasDebtInsights: Bool {
        self >= .premium
    }
    
    // MARK: - Account Features (v1.1)
    
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
    
    /// Client management for invoicing
    /// v1.2: Changed from Pro-only to Premium+ (invoicing requires clients!)
    var hasClientManagement: Bool {
        self >= .premium
    }
    
    /// Export to CSV/PDF for accountants
    var hasAdvancedExports: Bool {
        self == .pro
    }
    
    /// Professional Profit & Loss reports (Pro only)
    /// v1.3: Added for Pro tier gating
    var hasProfitLossReports: Bool {
        self == .pro
    }
    
    /// Year-End Tax Package with personalized checklist (Pro only)
    /// v1.3: Added for Pro tier gating
    var hasYearEndTaxPackage: Bool {
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
    /// v1.2: Updated - Premium now has client management (required for invoicing)
    var clientLimit: Int? {
        switch self {
        case .free:
            return 0 // No client management
        case .premium, .pro:
            return nil // Unlimited clients (invoice limit is the constraint for Premium)
        }
    }
    
    /// Account limit (v1.1)
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
    
    /// Linked bank account limit (Plaid) (v1.1)
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
                "Business/Personal separation",
                "Basic receipt scanning"
            ]
        case .premium:
            return [
                "Everything in Free",
                "Unlimited transactions",
                "Up to 5 accounts with balance tracking",
                "Account-based filtering & reports",
                "Real-time quarterly tax estimates",
                "Automated GPS mileage tracking",
                "Professional invoicing (25/month)",
                "Client management",
                "Smart Receipt Scanning with AI",
                "CSV Bank Statement Import",
                "100 receipt storage",
                "Advanced budgets with rollover",
                "Recurring transaction automation",
                "Dashboard widgets",
                "Debt Payoff Calculator",
                "Personalized Financial Tips"
            ]
        case .pro:
            return [
                "Everything in Premium",
                "Unlimited accounts",
                "Bank sync (coming soon)",
                "Account reconciliation tools",
                "Unlimited invoices",
                "Advanced tax deduction flagging",
                "Profit & Loss Reports",
                "Year-End Tax Package",
                "Export to CSV/PDF",
                "Unlimited receipt storage",
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
                "Tax estimates & GPS mileage",
                "Professional invoicing + clients",
                "Unlimited transactions"
            ]
        case .pro:
            return [
                "Unlimited accounts + Bank sync",
                "Unlimited invoices & clients",
                "Profit & Loss Reports",
                "Year-End Tax Package"
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
        case .advancedExports:
            return hasAdvancedExports
        case .smartReceiptScanning:
            return hasSmartReceiptScanning
        case .csvImport:
            return hasCSVImport
        // v1.4: New debt/financial tools features
        case .debtCalculator:
            return hasDebtCalculator
        case .personalizedTips:
            return hasPersonalizedTips
        case .debtInsights:
            return hasDebtInsights
        // v1.3: Pro features
        case .profitLossReports:
            return hasProfitLossReports
        case .yearEndTaxPackage:
            return hasYearEndTaxPackage
        // Account features (v1.1)
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
// v1.5: Added csvImport
// v1.4: Added debtCalculator, personalizedTips, debtInsights

enum Feature {
    // Premium features
    case taxEstimates
    case automatedMileage
    case invoicing
    case advancedBudgets
    case recurringTransactions
    case clientManagement
    case smartReceiptScanning
    case csvImport              // v1.5: CSV bank statement import
    case debtCalculator          // v1.4: Debt Payoff Calculator
    case personalizedTips        // v1.4: Personalized Money Moves tips
    case debtInsights            // v1.4: Debt optimization insights
    
    // Premium account features (v1.1)
    case multipleAccounts
    case accountFiltering
    case balanceTracking
    case multiAccountReports
    
    // Pro features
    case advancedDeductions
    case advancedExports
    case profitLossReports
    case yearEndTaxPackage
    
    // Pro account features (v1.1)
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
        case .advancedExports:
            return "Advanced Exports"
        case .smartReceiptScanning:
            return "Smart Receipt Scanning"
        case .csvImport:
            return "CSV Bank Statement Import"
        case .debtCalculator:
            return "Debt Payoff Calculator"
        case .personalizedTips:
            return "Personalized Financial Tips"
        case .debtInsights:
            return "Debt Optimization Insights"
        case .profitLossReports:
            return "Profit & Loss Reports"
        case .yearEndTaxPackage:
            return "Year-End Tax Package"
        // Account features (v1.1)
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
             .clientManagement, .smartReceiptScanning, .csvImport, .debtCalculator, .personalizedTips, .debtInsights,
             .multipleAccounts, .accountFiltering, .balanceTracking, .multiAccountReports:
            return .premium
        // Pro features
        case .advancedDeductions, .advancedExports, .profitLossReports, .yearEndTaxPackage,
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
        case .advancedExports:
            return "square.and.arrow.up.fill"
        case .smartReceiptScanning:
            return "doc.text.viewfinder"
        case .csvImport:
            return "doc.badge.arrow.up"
        case .debtCalculator:
            return "function"
        case .personalizedTips:
            return "sparkles"
        case .debtInsights:
            return "lightbulb.fill"
        case .profitLossReports:
            return "doc.text.magnifyingglass"
        case .yearEndTaxPackage:
            return "checklist"
        // Account features (v1.1)
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
        case .advancedExports:
            return "Export data for your accountant in CSV/PDF format"
        case .smartReceiptScanning:
            return "AI-powered receipt parsing with automatic data extraction"
        case .csvImport:
            return "Import bank statement CSV files for automatic transaction creation"
        case .debtCalculator:
            return "Interactive calculator showing payoff strategies and interest savings"
        case .personalizedTips:
            return "Financial tips personalized to your spending and debt"
        case .debtInsights:
            return "Proactive insights to optimize your debt payments"
        case .profitLossReports:
            return "Professional P&L statements for your business"
        case .yearEndTaxPackage:
            return "Personalized tax prep checklist with savings estimates"
        // Account features (v1.1)
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
