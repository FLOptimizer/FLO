//  SubscriptionManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Added yearly subscription support
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ Added yearly product IDs to match App Store Connect
//  ✅ Updated tierForProductID to handle yearly subscriptions
//  ✅ Both monthly and yearly plans now available
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
    
    @Published private(set) var currentTier: SubscriptionTier = {
        #if DEBUG
        // DEBUG builds: Always Pro
        return .pro
        #else
        // Production: Check for permanent unlock first
        let unlocked = UserDefaults.standard.bool(forKey: "FLO_ProUnlockedPermanently")
        return unlocked ? .pro : .free
        #endif
    }()
    
    @Published private(set) var availableProducts: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: PurchaseError?
    @Published private(set) var activeSubscription: Product?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isInTrialPeriod = false
    
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
        currentTier = .free
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
        // Start listening for transaction updates
        startTransactionListener()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Initialize subscription system - call on app launch
    func initialize() async {
        #if !DEBUG
        await loadProducts()
        await updateSubscriptionStatus()
        #else
        print("🔓 DEBUG MODE: Skipping subscription initialization, using Pro tier")
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
        var highestTier: SubscriptionTier = .free
        var highestProduct: Product?
        var latestExpirationDate: Date?
        var inTrial = false
        
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
