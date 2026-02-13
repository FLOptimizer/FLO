//  SubscriptionManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Added offer code redemption sheet support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4:
//  - Added presentOfferCodeRedeemSheet() for in-app offer code redemption
//  - Uses AppStore.presentOfferCodeRedeemSheet(in:) (iOS 16+)
//  - Automatically refreshes subscription status after redemption
//
//  CHANGES v1.3:
//  - Fixed debug tier buttons to actually change currentTier
//  - Debug mode respects saved tier override from UserDefaults
//  - Added debugSetTier() method that properly updates currentTier
//  - Debug tier persists across app launches (in DEBUG only)
//  - Production builds unaffected - still use real StoreKit
//
//  CHANGES v1.2:
//  - Added yearly product IDs to match App Store Connect
//  - Updated tierForProductID to handle yearly subscriptions
//
//  CHANGES v1.1:
//  - Fixed UTF-8 encoding issues
//
//  Manages StoreKit 2 subscriptions with async/await
//

import Foundation
import StoreKit

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // MARK: - Published State
    
    /// Current subscription tier
    /// - DEBUG: Defaults to Pro but can be overridden via debug menu
    /// - RELEASE: Determined by StoreKit entitlements
    @Published private(set) var currentTier: SubscriptionTier = .free
    
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: PurchaseError?
    @Published private(set) var activeSubscription: Product?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrialPeriod = false
    
    // MARK: - Debug Mode
    
    #if DEBUG
    /// Key for storing debug tier override
    private static let debugTierKey = "debug_subscription_tier_override"
    
    /// Whether we're using a debug tier override
    private var isUsingDebugOverride: Bool {
        UserDefaults.standard.object(forKey: Self.debugTierKey) != nil
    }
    #endif
    
    // MARK: - Permanent Pro Unlock
    
    /// Check if Pro was unlocked via secret code
    var isProUnlocked: Bool {
        get {
            UserDefaults.standard.bool(forKey: "FLO_ProUnlockedPermanently")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "FLO_ProUnlockedPermanently")
            if newValue {
                currentTier = .pro
                print("🔓 Pro tier permanently unlocked!")
            }
        }
    }
    
    /// Reset unlock (for testing)
    func resetProUnlock() {
        UserDefaults.standard.removeObject(forKey: "FLO_ProUnlockedPermanently")
        #if DEBUG
        // In debug, revert to debug tier or default
        loadDebugTier()
        #else
        currentTier = .free
        #endif
        print("🔒 Pro unlock reset")
    }
    
    // MARK: - Private Properties
    
    private var updateListenerTask: Task<Void, Error>?
    private var productsLoaded = false
    
    // Product IDs must match App Store Connect EXACTLY
    // Includes both monthly AND yearly subscriptions
    private let productIDs: Set<String> = [
        // Monthly subscriptions
        "com.finchandpoppy.flo.premium.monthly",
        "com.finchandpoppy.flo.pro.monthly",
        // Yearly subscriptions
        "com.finchandpoppy.flo.premium.yearly",
        "com.finchandpoppy.flo.pro.yearly"
    ]
    
    // MARK: - Initialization
    
    private init() {
        // Set initial tier based on build configuration
        #if DEBUG
        loadDebugTier()
        #else
        // Production: Check for permanent unlock
        let unlocked = UserDefaults.standard.bool(forKey: "FLO_ProUnlockedPermanently")
        currentTier = unlocked ? .pro : .free
        #endif
        
        // Start listening for transaction updates
        startTransactionListener()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Debug Tier Management
    
    #if DEBUG
    /// Load saved debug tier or default to Pro
    private func loadDebugTier() {
        if let savedTierRaw = UserDefaults.standard.object(forKey: Self.debugTierKey) as? Int,
           let savedTier = SubscriptionTier(rawValue: savedTierRaw) {
            currentTier = savedTier
            print("🔧 DEBUG: Loaded saved tier override: \(savedTier.displayName)")
        } else {
            // Default to Pro in debug for convenience
            currentTier = .pro
            print("🔧 DEBUG: Using default Pro tier (no override set)")
        }
    }
    
    /// Set debug tier override - actually changes currentTier
    /// Call this from the debug menu to test different tiers
    func debugSetTier(_ tier: SubscriptionTier) {
        UserDefaults.standard.set(tier.rawValue, forKey: Self.debugTierKey)
        currentTier = tier
        print("🔧 DEBUG: Tier changed to \(tier.displayName)")
    }
    
    /// Clear debug tier override and revert to default (Pro)
    func debugClearTierOverride() {
        UserDefaults.standard.removeObject(forKey: Self.debugTierKey)
        currentTier = .pro
        print("🔧 DEBUG: Tier override cleared, reverted to Pro")
    }
    
    /// Get the current debug tier for display
    var debugCurrentTierInfo: String {
        if isUsingDebugOverride {
            return "\(currentTier.displayName) (debug override)"
        } else {
            return "\(currentTier.displayName) (default)"
        }
    }
    #endif
    
    // MARK: - Public Methods
    
    /// Initialize subscription system - call on app launch
    func initialize() async {
        #if DEBUG
        // In debug, still load products so SubscriptionView works
        // but don't update tier from StoreKit (use debug override instead)
        await loadProducts()
        print("🔧 DEBUG: Products loaded, tier remains: \(currentTier.displayName)")
        #else
        // Production: Full StoreKit initialization
        await loadProducts()
        await updateSubscriptionStatus()
        #endif
    }
    
    /// Load available products from App Store
    func loadProducts() async {
        guard !productsLoaded else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let products = try await Product.products(for: productIDs)
            self.availableProducts = products.sorted { $0.price < $1.price }
            self.productsLoaded = true
            
            print("✅ Loaded \(products.count) subscription products")
            for product in products {
                print("   • \(product.displayName): \(product.displayPrice)")
            }
            
            // Warn if not all products loaded (helps debug App Store Connect issues)
            if products.count < productIDs.count {
                print("⚠️ Warning: Only \(products.count) of \(productIDs.count) products loaded")
                print("   Missing products may not be approved or have missing metadata in App Store Connect")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            self.purchaseError = .productLoadFailed
        }
    }
    
    /// Force reload products (useful after App Store Connect changes)
    func reloadProducts() async {
        productsLoaded = false
        availableProducts = []
        await loadProducts()
    }
    
    /// Purchase a subscription
    func purchase(_ product: Product) async throws {
        isLoading = true
        purchaseError = nil
        
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Verify the transaction
                let transaction = try Self.checkVerified(verification)
                
                // Update subscription status
                await updateSubscriptionStatus()
                
                // Finish the transaction
                await transaction.finish()
                
                print("✅ Purchase successful: \(product.displayName)")
                
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                
            case .pending:
                print("⏳ Purchase pending (requires parental approval)")
                purchaseError = .purchasePending
                
            @unknown default:
                print("⚠️ Unknown purchase result")
            }
            
        } catch StoreKitError.userCancelled {
            // User cancelled - not an error
            print("ℹ️ User cancelled during purchase flow")
            
        } catch {
            print("❌ Purchase failed: \(error)")
            purchaseError = .purchaseFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Restore purchases from App Store
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            print("✅ Purchases restored successfully")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            purchaseError = .restoreFailed
        }
    }
    
    /// Present the offer code redemption sheet (iOS 16+)
    /// Allows users to redeem subscription offer codes directly within the app
    @available(iOS 16.0, *)
    func presentOfferCodeRedeemSheet() async {
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: Self.currentWindowScene)
            // Refresh subscription status after redemption
            await updateSubscriptionStatus()
            print("\u{2705} Offer code redemption sheet presented successfully")
        } catch {
            print("\u{274C} Failed to present offer code sheet: \(error)")
            purchaseError = .offerCodeFailed
        }
    }
    
    /// Get the current window scene for presenting StoreKit sheets
    private static var currentWindowScene: UIWindowScene {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            // Fallback to any connected window scene
            return UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first!
        }
        return scene
    }
    
    /// Check if user can access a specific feature
    func canAccess(_ feature: Feature) -> Bool {
        currentTier.canAccess(feature)
    }
    
    /// Get product for a specific tier and billing period
    func product(for tier: SubscriptionTier, period: SubscriptionPeriod = .monthly) -> Product? {
        guard let productID = tier.getProductID(for: period) else { return nil }
        return availableProducts.first { $0.id == productID }
    }
    
    // MARK: - Private Methods
    
    /// Update current subscription status from App Store
    private func updateSubscriptionStatus() async {
        #if DEBUG
        // In debug mode, don't override the debug tier setting
        if isUsingDebugOverride {
            print("🔧 DEBUG: Skipping StoreKit status update (using debug override)")
            return
        }
        #endif
        
        var highestTier: SubscriptionTier = .free
        var highestProduct: Product?
        var latestExpirationDate: Date?
        var inTrial = false
        
        // Check for permanent unlock first
        if UserDefaults.standard.bool(forKey: "FLO_ProUnlockedPermanently") {
            self.currentTier = .pro
            print("✅ Pro tier active (permanent unlock)")
            return
        }
        
        // Check all current entitlements
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                
                // Determine tier from product ID
                if let tier = tierForProductID(transaction.productID) {
                    if tier > highestTier {
                        highestTier = tier
                        highestProduct = availableProducts.first { $0.id == transaction.productID }
                        
                        // Check if in trial period
                        if let status = await transaction.subscriptionStatus {
                            inTrial = status.state == .subscribed
                        }
                        
                        // Get expiration date
                        latestExpirationDate = transaction.expirationDate
                    }
                }
                
            } catch {
                print("⚠️ Failed to verify transaction: \(error)")
            }
        }
        
        // Update published state
        self.currentTier = highestTier
        self.activeSubscription = highestProduct
        self.expirationDate = latestExpirationDate
        self.isInTrialPeriod = inTrial
        
        print("✅ Subscription status updated: \(highestTier.displayName)")
        if inTrial {
            print("   ℹ️ User is in trial period")
        }
        if let expDate = latestExpirationDate {
            print("   ℹ️ Expires: \(expDate)")
        }
    }
    
    /// Listen for transaction updates in the background
    private func startTransactionListener() {
        updateListenerTask = Task.detached {
            for await result: StoreKit.VerificationResult<StoreKit.Transaction> in StoreKit.Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    
                    await self.updateSubscriptionStatus()
                    
                    // Always finish transactions
                    await transaction.finish()
                    
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// Verify transaction signature
    private nonisolated static func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    /// Map product ID to subscription tier
    /// Handles both monthly AND yearly subscriptions
    private func tierForProductID(_ productID: String) -> SubscriptionTier? {
        switch productID {
        // Premium tier (monthly or yearly)
        case "com.finchandpoppy.flo.premium.monthly",
             "com.finchandpoppy.flo.premium.yearly":
            return .premium
        // Pro tier (monthly or yearly)
        case "com.finchandpoppy.flo.pro.monthly",
             "com.finchandpoppy.flo.pro.yearly":
            return .pro
        default:
            return nil
        }
    }
}

// MARK: - Purchase Error

enum PurchaseError: LocalizedError, Equatable {
    case productLoadFailed
    case purchaseFailed(String)
    case purchasePending
    case verificationFailed
    case restoreFailed
    case offerCodeFailed
    
    var errorDescription: String? {
        switch self {
        case .productLoadFailed:
            return "Unable to load subscription options. Please check your internet connection and try again."
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .purchasePending:
            return "Purchase is pending approval. This usually happens for accounts with parental controls."
        case .verificationFailed:
            return "Unable to verify purchase. Please contact support if this persists."
        case .restoreFailed:
            return "Unable to restore purchases. Please try again later."
        case .offerCodeFailed:
            return "Unable to present offer code redemption. Please try redeeming in the App Store instead."
        }
    }
    
    static func == (lhs: PurchaseError, rhs: PurchaseError) -> Bool {
        switch (lhs, rhs) {
        case (.productLoadFailed, .productLoadFailed),
             (.purchasePending, .purchasePending),
             (.verificationFailed, .verificationFailed),
             (.restoreFailed, .restoreFailed):
            return true
        case (.purchaseFailed(let lhsMessage), .purchaseFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - Subscription Status Extension

extension Product.SubscriptionInfo.Status {
    var isSubscribed: Bool {
        switch state {
        case .subscribed:
            return true
        case .inGracePeriod:
            return true
        case .expired:
            return false
        case .revoked:
            return false
        case .inBillingRetryPeriod:
            return false
        default:
            return false
        }
    }
}
