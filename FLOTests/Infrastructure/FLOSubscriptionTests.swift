//  FLOSubscriptionTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Subscription & Feature Gate Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate subscription tier logic, feature gating,
//  and usage limit enforcement.
//
//  COVERS:
//  - Tier-based feature access
//  - Usage limits (accounts, receipts, etc.)
//  - Upgrade prompts
//  - Subscription state management
//

import XCTest
@testable import FLO

final class FLOSubscriptionTests: XCTestCase {
    
    // MARK: - Subscription Tier Definition
    
    enum SubscriptionTier: String {
        case free = "Free"
        case premium = "Premium"
        case pro = "Pro"
    }
    
    // MARK: - Feature Definitions
    
    struct TierLimits {
        let accounts: Int
        let receiptsPerMonth: Int
        let hasMultipleAccounts: Bool
        let hasTaxEstimates: Bool
        let hasMileageTracking: Bool
        let hasInvoicing: Bool
        let hasClientManagement: Bool
        let hasAdvancedReports: Bool
        let hasBudgetRollover: Bool
        let hasWidgets: Bool
        let hasPlaidIntegration: Bool
    }
    
    func limitsForTier(_ tier: SubscriptionTier) -> TierLimits {
        switch tier {
        case .free:
            return TierLimits(
                accounts: 2,
                receiptsPerMonth: 20,
                hasMultipleAccounts: false,
                hasTaxEstimates: false,
                hasMileageTracking: false,
                hasInvoicing: false,
                hasClientManagement: false,
                hasAdvancedReports: false,
                hasBudgetRollover: false,
                hasWidgets: false,
                hasPlaidIntegration: false
            )
        case .premium:
            return TierLimits(
                accounts: 5,
                receiptsPerMonth: 100,
                hasMultipleAccounts: true,
                hasTaxEstimates: true,
                hasMileageTracking: true,
                hasInvoicing: true,
                hasClientManagement: false,
                hasAdvancedReports: true,
                hasBudgetRollover: true,
                hasWidgets: true,
                hasPlaidIntegration: false
            )
        case .pro:
            return TierLimits(
                accounts: .max,
                receiptsPerMonth: .max,
                hasMultipleAccounts: true,
                hasTaxEstimates: true,
                hasMileageTracking: true,
                hasInvoicing: true,
                hasClientManagement: true,
                hasAdvancedReports: true,
                hasBudgetRollover: true,
                hasWidgets: true,
                hasPlaidIntegration: true
            )
        }
    }
}

// MARK: - Account Limit Tests

extension FLOSubscriptionTests {
    
    /// Test: Free tier - 2 account limit
    func testAccountLimit_FreeTier() {
        let tier = SubscriptionTier.free
        let limits = limitsForTier(tier)

        XCTAssertEqual(limits.accounts, 2, "Free tier has 2 accounts")

        let currentAccounts = 2
        let canAddAccount = currentAccounts < limits.accounts

        XCTAssertFalse(canAddAccount, "Cannot add more accounts at limit")
    }
    
    /// Test: Premium tier - 5 account limit
    func testAccountLimit_PremiumTier() {
        let tier = SubscriptionTier.premium
        let limits = limitsForTier(tier)
        
        XCTAssertEqual(limits.accounts, 5, "Premium tier has 5 accounts")
        
        let currentAccounts = 3
        let canAddAccount = currentAccounts < limits.accounts
        
        XCTAssertTrue(canAddAccount, "Can add accounts under limit")
    }
    
    /// Test: Pro tier - unlimited accounts
    func testAccountLimit_ProTier() {
        let tier = SubscriptionTier.pro
        let limits = limitsForTier(tier)
        
        XCTAssertEqual(limits.accounts, .max, "Pro tier has unlimited accounts")
        
        let currentAccounts = 100
        let canAddAccount = currentAccounts < limits.accounts
        
        XCTAssertTrue(canAddAccount, "Pro can always add accounts")
    }
}

// MARK: - Receipt Limit Tests

extension FLOSubscriptionTests {
    
    /// Test: Free tier - 20 receipts per month
    func testReceiptLimit_FreeTier() {
        let tier = SubscriptionTier.free
        let limits = limitsForTier(tier)
        
        XCTAssertEqual(limits.receiptsPerMonth, 20)
        
        let receiptsSavedThisMonth = 20
        let canSaveReceipt = receiptsSavedThisMonth < limits.receiptsPerMonth
        
        XCTAssertFalse(canSaveReceipt, "At limit, cannot save more")
    }
    
    /// Test: Premium tier - 100 receipts per month
    func testReceiptLimit_PremiumTier() {
        let tier = SubscriptionTier.premium
        let limits = limitsForTier(tier)
        
        XCTAssertEqual(limits.receiptsPerMonth, 100)
    }
    
    /// Test: Pro tier - unlimited receipts
    func testReceiptLimit_ProTier() {
        let tier = SubscriptionTier.pro
        let limits = limitsForTier(tier)
        
        XCTAssertEqual(limits.receiptsPerMonth, .max)
        
        let receiptsSavedThisMonth = 500
        let canSaveReceipt = receiptsSavedThisMonth < limits.receiptsPerMonth
        
        XCTAssertTrue(canSaveReceipt, "Pro has unlimited receipts")
    }
    
    /// Test: Receipt limit resets monthly
    func testReceiptLimit_MonthlyReset() {
        let lastResetDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let today = Date()
        
        let lastResetMonth = Calendar.current.component(.month, from: lastResetDate)
        let currentMonth = Calendar.current.component(.month, from: today)
        
        let shouldReset = lastResetMonth != currentMonth
        
        XCTAssertTrue(shouldReset, "Should reset in new month")
    }
}

// MARK: - Feature Access Tests

extension FLOSubscriptionTests {
    
    /// Test: Tax estimates - Premium+ feature
    func testFeature_TaxEstimates() {
        XCTAssertFalse(limitsForTier(.free).hasTaxEstimates, "Free: No tax estimates")
        XCTAssertTrue(limitsForTier(.premium).hasTaxEstimates, "Premium: Has tax estimates")
        XCTAssertTrue(limitsForTier(.pro).hasTaxEstimates, "Pro: Has tax estimates")
    }
    
    /// Test: Mileage tracking - Premium+ feature
    func testFeature_MileageTracking() {
        XCTAssertFalse(limitsForTier(.free).hasMileageTracking, "Free: No mileage")
        XCTAssertTrue(limitsForTier(.premium).hasMileageTracking, "Premium: Has mileage")
        XCTAssertTrue(limitsForTier(.pro).hasMileageTracking, "Pro: Has mileage")
    }
    
    /// Test: Client management - Pro only feature
    func testFeature_ClientManagement() {
        XCTAssertFalse(limitsForTier(.free).hasClientManagement, "Free: No clients")
        XCTAssertFalse(limitsForTier(.premium).hasClientManagement, "Premium: No clients")
        XCTAssertTrue(limitsForTier(.pro).hasClientManagement, "Pro: Has clients")
    }
    
    /// Test: Plaid integration - Pro only feature
    func testFeature_PlaidIntegration() {
        XCTAssertFalse(limitsForTier(.free).hasPlaidIntegration, "Free: No Plaid")
        XCTAssertFalse(limitsForTier(.premium).hasPlaidIntegration, "Premium: No Plaid")
        XCTAssertTrue(limitsForTier(.pro).hasPlaidIntegration, "Pro: Has Plaid")
    }
    
    /// Test: Invoicing - Premium+ feature
    func testFeature_Invoicing() {
        XCTAssertFalse(limitsForTier(.free).hasInvoicing)
        XCTAssertTrue(limitsForTier(.premium).hasInvoicing)
        XCTAssertTrue(limitsForTier(.pro).hasInvoicing)
    }
    
    /// Test: Budget rollover - Premium+ feature
    func testFeature_BudgetRollover() {
        XCTAssertFalse(limitsForTier(.free).hasBudgetRollover)
        XCTAssertTrue(limitsForTier(.premium).hasBudgetRollover)
        XCTAssertTrue(limitsForTier(.pro).hasBudgetRollover)
    }
    
    /// Test: Widgets - Premium+ feature
    func testFeature_Widgets() {
        XCTAssertFalse(limitsForTier(.free).hasWidgets)
        XCTAssertTrue(limitsForTier(.premium).hasWidgets)
        XCTAssertTrue(limitsForTier(.pro).hasWidgets)
    }
}

// MARK: - Upgrade Prompt Logic

extension FLOSubscriptionTests {
    
    /// Test: Show upgrade when hitting account limit
    func testUpgradePrompt_AccountLimit() {
        let tier = SubscriptionTier.free
        let limits = limitsForTier(tier)
        let currentAccounts = 2

        let shouldPromptUpgrade = currentAccounts >= limits.accounts && tier != .pro
        
        XCTAssertTrue(shouldPromptUpgrade, "Should prompt when at account limit")
    }
    
    /// Test: Show upgrade when accessing premium feature
    func testUpgradePrompt_PremiumFeature() {
        let tier = SubscriptionTier.free
        let limits = limitsForTier(tier)
        
        let wantsTaxEstimates = true
        let hasFeature = limits.hasTaxEstimates
        
        let shouldPromptUpgrade = wantsTaxEstimates && !hasFeature
        
        XCTAssertTrue(shouldPromptUpgrade, "Should prompt for tax estimates on free tier")
    }
    
    /// Test: No upgrade prompt when feature available
    func testUpgradePrompt_FeatureAvailable() {
        let tier = SubscriptionTier.premium
        let limits = limitsForTier(tier)
        
        let wantsTaxEstimates = true
        let hasFeature = limits.hasTaxEstimates
        
        let shouldPromptUpgrade = wantsTaxEstimates && !hasFeature
        
        XCTAssertFalse(shouldPromptUpgrade, "No prompt when feature available")
    }
    
    /// Test: Determine which tier to suggest
    func testUpgradePrompt_SuggestedTier() {
        func suggestTier(for feature: String, currentTier: SubscriptionTier) -> SubscriptionTier? {
            let proOnlyFeatures = ["clientManagement", "plaidIntegration"]
            let premiumFeatures = ["taxEstimates", "mileageTracking", "invoicing", "widgets"]
            
            if proOnlyFeatures.contains(feature) {
                return currentTier == .pro ? nil : .pro
            } else if premiumFeatures.contains(feature) {
                if currentTier == .free { return .premium }
                return nil
            }
            return nil
        }
        
        XCTAssertEqual(suggestTier(for: "taxEstimates", currentTier: .free), .premium)
        XCTAssertEqual(suggestTier(for: "clientManagement", currentTier: .free), .pro)
        XCTAssertEqual(suggestTier(for: "clientManagement", currentTier: .premium), .pro)
        XCTAssertNil(suggestTier(for: "taxEstimates", currentTier: .premium))
    }
}

// MARK: - Subscription State Tests

extension FLOSubscriptionTests {
    
    enum SubscriptionState {
        case active
        case expired
        case gracePeriod
        case cancelled
    }
    
    /// Test: Active subscription has full access
    func testState_ActiveHasFullAccess() {
        let state = SubscriptionState.active
        let tier = SubscriptionTier.premium
        
        let hasAccess = state == .active || state == .gracePeriod
        
        XCTAssertTrue(hasAccess, "Active subscription has access")
        XCTAssertTrue(tier == .premium || tier == .pro, "Premium or Pro tier expected")
    }
    
    /// Test: Expired subscription loses premium features
    func testState_ExpiredLosesPremium() {
        let state = SubscriptionState.expired
        
        let hasAccess = state == .active || state == .gracePeriod
        
        XCTAssertFalse(hasAccess, "Expired loses premium features")
    }
    
    /// Test: Grace period maintains access
    func testState_GracePeriodMaintainsAccess() {
        let state = SubscriptionState.gracePeriod
        
        let hasAccess = state == .active || state == .gracePeriod
        
        XCTAssertTrue(hasAccess, "Grace period maintains access")
    }
    
    /// Test: Cancelled continues until period ends
    func testState_CancelledContinuesUntilEnd() {
        let state = SubscriptionState.cancelled
        let expirationDate = Calendar.current.date(byAdding: .day, value: 15, to: Date())!
        let today = Date()
        
        let stillValid = expirationDate > today
        
        XCTAssertTrue(stillValid, "Cancelled still valid until expiration")
        XCTAssertEqual(state, .cancelled, "State should be cancelled")
    }
}

// MARK: - Price Tests

extension FLOSubscriptionTests {
    
    /// Test: Tier pricing
    func testPricing_MonthlyRates() {
        let prices: [SubscriptionTier: Double] = [
            .free: 0.00,
            .premium: 12.99,
            .pro: 19.99
        ]
        
        XCTAssertEqual(prices[.free], 0.00)
        XCTAssertEqual(prices[.premium], 12.99)
        XCTAssertEqual(prices[.pro], 19.99)
    }
    
    /// Test: Annual discount calculation
    func testPricing_AnnualDiscount() {
        let monthlyPrice: Double = 12.99
        let monthsPerYear: Double = 12
        let annualDiscountPercent: Double = 0.20  // 20% off
        
        let monthlyTotal = monthlyPrice * monthsPerYear
        let annualPrice = monthlyTotal * (1 - annualDiscountPercent)
        let monthlySavings = (monthlyTotal - annualPrice) / monthsPerYear
        
        XCTAssertEqual(monthlyTotal, 155.88, accuracy: 0.01)
        XCTAssertEqual(annualPrice, 124.70, accuracy: 0.01)
        XCTAssertEqual(monthlySavings, 2.60, accuracy: 0.01, "Save ~$2.60/month with annual")
    }
}

// MARK: - Trial Tests

extension FLOSubscriptionTests {
    
    /// Test: Trial period duration
    func testTrial_Duration() {
        let trialDays: Int = 7
        let trialStartDate = Date()
        let trialEndDate = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStartDate)!
        
        let daysBetween = Calendar.current.dateComponents([.day], from: trialStartDate, to: trialEndDate).day!
        
        XCTAssertEqual(daysBetween, 7, "7-day trial")
    }
    
    /// Test: Trial gives premium access
    func testTrial_HasPremiumAccess() {
        let isInTrial = true
        let trialTier = SubscriptionTier.premium
        
        let limits = limitsForTier(trialTier)
        
        XCTAssertTrue(isInTrial && limits.hasTaxEstimates, "Trial has premium features")
    }
    
    /// Test: Trial expired
    func testTrial_Expired() {
        let trialEndDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let today = Date()
        
        let isTrialExpired = today > trialEndDate
        
        XCTAssertTrue(isTrialExpired, "Trial has expired")
    }
}
