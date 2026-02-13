//  SubscriptionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Accessibility audit (Sprint 6b)
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.0:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ Hero section decorative icon hidden
//  ✅ Feature Comparison header trait + rows combined with spoken values
//  ✅ SubscriptionOptionCard combined with spoken tier, price, trial, chevron hidden
//  ✅ UsageProgressRow combined with spoken usage and limits
//  ✅ PurchaseConfirmationSheet header combined, feature checkmarks hidden
//  ✅ Legal text bullet separators hidden
//
//  CHANGES v2.9:
//  - Added "Redeem Offer Code" button below Restore Purchases
//  - Uses AppStore.presentOfferCodeRedeemSheet (iOS 16+)
//  - Styled consistently with existing Restore Purchases button
//  - Added redeemOfferCode() action method
//  - Added isRedeemingCode state property
//
//  CHANGES v2.8:
//  - NEW: Tapping a tier card opens a confirmation half-sheet (Option B UX)
//  - NEW: PurchaseConfirmationSheet with tier details, features, and CTA
//  - REMOVED: Old "selectedProduct" selection pattern requiring scroll to CTA
//  - REMOVED: Floating "Start 7-Day Free Trial" button at bottom of options
//  - Cards now have cleaner look without selection state
//  - Cleaner, more intuitive one-tap-to-confirm purchase flow
//  - Sheet includes trial info, price, key features, and legal text
//
//  CHANGES v2.7:
//  - Added "Your Current Usage" section showing live usage stats
//  - Added UsageProgressRow component with progress bars
//  - Shows transactions, receipts, accounts, invoices with limits
//  - Color-coded: teal (normal), orange (80%+), red (100%)
//  - Only shown for Free/Premium tiers (Pro has unlimited)
//  - Integrated UsageLimitService for real-time counts
//
//  CHANGES v2.6:
//  - Updated Feature Comparison with 12 accurate features
//  - Added limit display (50/mo, 25/mo, 5, infinity) instead of just checkmarks
//
//  CHANGES v2.5:
//  - Added EULA link in legal text section (Apple Guideline 3.1.2)
//

import SwiftUI
import StoreKit
import SwiftData

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var manager = SubscriptionManager.shared
    
    @State private var showingError = false
    @State private var isRestoring = false
    @State private var isRedeemingCode = false
    @State private var viewAppeared = false
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    
    // v2.8: Purchase confirmation sheet state
    @State private var showingPurchaseSheet = false
    @State private var selectedTierForPurchase: (product: Product, tier: SubscriptionTier)?
    
    // MARK: - Usage Tracking (v2.7)
    @State private var usageLimitService: UsageLimitService?
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // Check if yearly products are available
    private var yearlyProductsAvailable: Bool {
        manager.product(for: .premium, period: .yearly) != nil ||
        manager.product(for: .pro, period: .yearly) != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    heroSection
                    
                    // Current Usage (v2.7) - Only show for limited tiers
                    if manager.currentTier != .pro {
                        currentUsageSection
                    }
                    
                    // Billing Cycle Toggle (only show if yearly products available)
                    if yearlyProductsAvailable {
                        billingToggle
                    }
                    
                    // Subscription Options
                    if manager.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(40)
                    } else {
                        subscriptionOptions
                    }
                    
                    // Feature Comparison
                    featureComparison
                    
                    // Legal Text
                    legalText
                    
                    // Prominent Restore Purchases button per Apple guideline 3.1.1
                    restorePurchasesButton
                    
                    // v2.9: Redeem Offer Code button
                    redeemOfferCodeButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        restorePurchases()
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("Restore")
                                .font(.subheadline)
                        }
                    }
                    .disabled(isRestoring)
                }
            }
            .alert("Purchase Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = manager.purchaseError {
                    Text(error.localizedDescription)
                }
            }
            // v2.8: Purchase confirmation sheet
            .sheet(isPresented: $showingPurchaseSheet) {
                if let selection = selectedTierForPurchase {
                    PurchaseConfirmationSheet(
                        product: selection.product,
                        tier: selection.tier,
                        isYearly: selectedPeriod == .yearly,
                        isLoading: manager.isLoading,
                        onPurchase: {
                            Task {
                                do {
                                    try await manager.purchase(selection.product)
                                    HapticService.play(.success)
                                    showingPurchaseSheet = false
                                } catch {
                                    HapticService.play(.error)
                                }
                            }
                        },
                        onCancel: {
                            showingPurchaseSheet = false
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
        .task {
            await manager.loadProducts()
        }
        .onChange(of: manager.purchaseError) { oldValue, newValue in
            showingError = newValue != nil
            if newValue != nil {
                HapticService.play(.error)
            }
        }
        .onChange(of: manager.currentTier) { oldValue, newValue in
            if newValue != .free {
                HapticService.play(.success)
                showingPurchaseSheet = false
                dismiss()
            }
        }
        .onAppear {
            // Setup usage limit service (v2.7)
            if usageLimitService == nil {
                usageLimitService = UsageLimitService(modelContext: modelContext)
            } else {
                usageLimitService?.refreshCounts()
            }
            
            // Delay entrance animation until sheet is fully presented
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
            AccessibilityAnnouncement.screenChanged("Choose your plan")
        }
    }
    
    // MARK: - Restore Purchases Action
    
    /// Centralized restore purchases logic - used by both toolbar and main button
    private func restorePurchases() {
        HapticService.play(.medium)
        Task {
            isRestoring = true
            await manager.restorePurchases()
            isRestoring = false
            if manager.currentTier != .free {
                HapticService.play(.success)
            }
        }
    }
    
    // MARK: - Redeem Offer Code Action (v2.9)
    
    /// Present the offer code redemption sheet
    private func redeemOfferCode() {
        HapticService.play(.medium)
        Task {
            isRedeemingCode = true
            if #available(iOS 16.0, *) {
                await manager.presentOfferCodeRedeemSheet()
            }
            isRedeemingCode = false
            if manager.currentTier != .free {
                HapticService.play(.success)
            }
        }
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Icon with animation
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "14B8A6"), Color(hex: "0D9488")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .symbolEffect(.pulse, value: viewAppeared)
                .scaleEffect(viewAppeared ? 1 : 0.5)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: viewAppeared)
                .accessibilityHidden(true)
            
            Text("Unlock FLO Premium")
                .font(.system(size: 28, weight: .bold))
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            
            Text("Professional financial management built for freelancers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
        }
        .padding(.top, 24)
        .padding(.horizontal)
    }
    
    // MARK: - Billing Cycle Toggle
    
    private var billingToggle: some View {
        HStack {
            Spacer()
            Toggle(isOn: Binding(
                get: { selectedPeriod == .yearly },
                set: { newValue in
                    HapticService.play(.light)
                    withAnimation(FLOAnimation.quick) {
                        selectedPeriod = newValue ? .yearly : .monthly
                    }
                }
            )) {
                Text(selectedPeriod == .monthly ? "Monthly" : "Yearly (Save ~17%)")
                    .font(.subheadline.bold())
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "14B8A6")))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
            Spacer()
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.18), value: viewAppeared)
    }
    
    // MARK: - Subscription Options (v2.8 - Tap to Open Sheet)

    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            // Premium Option
            let premiumProduct = manager.product(for: .premium, period: selectedPeriod)
            if let premiumProduct = premiumProduct {
                SubscriptionOptionCard(
                    product: premiumProduct,
                    tier: .premium,
                    isCurrentTier: manager.currentTier == .premium,
                    isYearly: selectedPeriod == .yearly
                ) {
                    HapticService.play(.medium)
                    selectedTierForPurchase = (premiumProduct, .premium)
                    showingPurchaseSheet = true
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 30)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            }
            
            // Pro Option (Recommended)
            let proProduct = manager.product(for: .pro, period: selectedPeriod)
            if let proProduct = proProduct {
                SubscriptionOptionCard(
                    product: proProduct,
                    tier: .pro,
                    isCurrentTier: manager.currentTier == .pro,
                    isYearly: selectedPeriod == .yearly,
                    isRecommended: true
                ) {
                    HapticService.play(.medium)
                    selectedTierForPurchase = (proProduct, .pro)
                    showingPurchaseSheet = true
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 30)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            }
            
            // No products loaded state
            if manager.availableProducts.isEmpty && !manager.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Unable to load subscription options")
                        .font(.headline)
                    Text("Please check your internet connection and try again")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        HapticService.play(.medium)
                        Task {
                            await manager.loadProducts()
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "14B8A6"))
                }
                .padding(32)
            }
            
            // v2.8: Removed the floating "Start 7-Day Free Trial" button
            // Purchase is now triggered directly from card tap -> confirmation sheet
        }
    }
    
    // MARK: - Feature Comparison
    // v2.6: Comprehensive 12-row feature list with limits display
    
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Comparison")
                .font(.headline)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Header Row
            HStack {
                Text("Feature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Text("Free")
                        .font(.caption.bold())
                        .frame(width: 44)
                    Text("Prem")
                        .font(.caption.bold())
                        .frame(width: 44)
                    Text("Pro")
                        .font(.caption.bold())
                        .frame(width: 44)
                }
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.38), value: viewAppeared)
            
            Divider()
            
            // v2.6: Updated feature rows with accurate representation
            // Row 1: Transactions with limits
            FeatureRowWithLimits(
                title: "Transactions",
                freeValue: .limit("50/mo"),
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.40, appeared: viewAppeared
            )
            
            // Row 2: Accounts with limits
            FeatureRowWithLimits(
                title: "Accounts",
                freeValue: .limit("1"),
                premiumValue: .limit("5"),
                proValue: .unlimited,
                delay: 0.42, appeared: viewAppeared
            )
            
            // Row 3: Tax Estimates
            FeatureRowWithLimits(
                title: "Tax Estimates",
                freeValue: .disabled,
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.44, appeared: viewAppeared
            )
            
            // Row 4: GPS Mileage Tracking
            FeatureRowWithLimits(
                title: "GPS Mileage Tracking",
                freeValue: .disabled,
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.46, appeared: viewAppeared
            )
            
            // Row 5: Invoicing with limits
            FeatureRowWithLimits(
                title: "Invoicing",
                freeValue: .disabled,
                premiumValue: .limit("25/mo"),
                proValue: .unlimited,
                delay: 0.48, appeared: viewAppeared
            )
            
            // Row 6: Client Management (Premium+ per v2.6 bundling fix)
            FeatureRowWithLimits(
                title: "Client Management",
                freeValue: .disabled,
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.50, appeared: viewAppeared
            )
            
            // Row 7: Smart Receipt Scanning (renamed from Receipt OCR)
            FeatureRowWithLimits(
                title: "Smart Receipt Scanning",
                freeValue: .disabled,
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.52, appeared: viewAppeared
            )
            
            // Row 8: Recurring Transactions
            FeatureRowWithLimits(
                title: "Recurring Transactions",
                freeValue: .disabled,
                premiumValue: .enabled,
                proValue: .enabled,
                delay: 0.54, appeared: viewAppeared
            )
            
            // Row 9: Profit & Loss Reports (Pro only)
            FeatureRowWithLimits(
                title: "Profit & Loss Reports",
                freeValue: .disabled,
                premiumValue: .disabled,
                proValue: .enabled,
                delay: 0.56, appeared: viewAppeared
            )
            
            // Row 10: Year-End Tax Package (Pro only)
            FeatureRowWithLimits(
                title: "Year-End Tax Package",
                freeValue: .disabled,
                premiumValue: .disabled,
                proValue: .enabled,
                delay: 0.58, appeared: viewAppeared
            )
            
            // Row 11: Advanced Exports (Pro only)
            FeatureRowWithLimits(
                title: "Advanced Exports",
                freeValue: .disabled,
                premiumValue: .disabled,
                proValue: .enabled,
                delay: 0.60, appeared: viewAppeared
            )
            
            // Row 12: Bank Sync with "Soon" badge (Pro only)
            FeatureRowWithLimits(
                title: "Bank Sync",
                freeValue: .disabled,
                premiumValue: .disabled,
                proValue: .comingSoon,
                delay: 0.62, appeared: viewAppeared
            )
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Legal Text
    
    /// Legal disclosure and links per Apple Guideline 3.1.2
    /// Includes: Terms of Service, EULA, and Privacy Policy
    private var legalText: some View {
        VStack(spacing: 8) {
            Text(selectedPeriod == .monthly ?
                 "Subscriptions auto-renew monthly until cancelled. Cancel anytime in Settings > Subscriptions." :
                 "Subscriptions auto-renew yearly until cancelled. Cancel anytime in Settings > Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Legal document links - Apple Guideline 3.1.2 compliance
            HStack(spacing: 12) {
                Link("Terms", destination: URL(string: "https://floptimizer.github.io/FLO/terms.html")!)
                
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                Link("EULA", destination: URL(string: "https://floptimizer.github.io/FLO/eula.html")!)
                
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                Link("Privacy", destination: URL(string: "https://floptimizer.github.io/FLO/privacy.html")!)
            }
            .font(.caption2)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
    }
    
    // MARK: - Current Usage Section (v2.7)
    
    private var currentUsageSection: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color(hex: "14B8A6"))
                    .accessibilityHidden(true)
                Text("Your Current Usage")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(manager.currentTier.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(manager.currentTier == .free ? Color.gray : Color(hex: "14B8A6"))
                    .clipShape(Capsule())
            }
            
            // Usage Rows
            VStack(spacing: 12) {
                // Transactions (monthly)
                if let service = usageLimitService {
                    UsageProgressRow(
                        label: "Transactions",
                        sublabel: "this month",
                        current: service.currentMonthTransactionCount,
                        limit: manager.currentTier.transactionLimit,
                        icon: "arrow.left.arrow.right"
                    )
                }
                
                // Receipts (total)
                if let service = usageLimitService {
                    UsageProgressRow(
                        label: "Receipts",
                        sublabel: "total",
                        current: service.totalReceiptCount,
                        limit: manager.currentTier.receiptStorageLimit,
                        icon: "doc.text.viewfinder"
                    )
                }
                
                // Accounts
                UsageProgressRow(
                    label: "Accounts",
                    sublabel: "total",
                    current: accounts.count,
                    limit: manager.currentTier.accountLimit,
                    icon: "building.columns"
                )
                
                // Invoices (monthly)
                if let service = usageLimitService {
                    UsageProgressRow(
                        label: "Invoices",
                        sublabel: "this month",
                        current: service.currentMonthInvoiceCount,
                        limit: manager.currentTier.invoiceLimit,
                        icon: "doc.text"
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
    }
    
    // MARK: - Restore Purchases Button
    
    /// Distinct "Restore Purchases" button per Apple guideline 3.1.1
    private var restorePurchasesButton: some View {
        VStack(spacing: 12) {
            Text("Already purchased?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                restorePurchases()
            } label: {
                HStack(spacing: 8) {
                    if isRestoring {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Restore Purchases")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "14B8A6"))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "14B8A6"), lineWidth: 1.5)
                )
            }
            .disabled(isRestoring)
        }
        .padding(.top, 8)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.7), value: viewAppeared)
    }
    
    // MARK: - Redeem Offer Code Button (v2.9)
    
    /// Button to present Apple's offer code redemption sheet within the app
    private var redeemOfferCodeButton: some View {
        VStack(spacing: 12) {
            Text("Have an offer code?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                redeemOfferCode()
            } label: {
                HStack(spacing: 8) {
                    if isRedeemingCode {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "gift")
                    }
                    Text("Redeem Offer Code")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "14B8A6"))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "14B8A6"), lineWidth: 1.5)
                )
            }
            .disabled(isRedeemingCode)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.75), value: viewAppeared)
    }
}

// MARK: - Purchase Confirmation Sheet (v2.8)

/// Half-sheet confirmation when user taps a tier card
struct PurchaseConfirmationSheet: View {
    let product: Product
    let tier: SubscriptionTier
    let isYearly: Bool
    let isLoading: Bool
    let onPurchase: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                // Tier icon
                Image(systemName: tier == .pro ? "crown.fill" : "star.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: tier == .pro ? [.purple, .indigo] : [Color(hex: "14B8A6"), Color(hex: "0D9488")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityHidden(true)
                
                Text(tier.displayName)
                    .font(.title.bold())
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title2.bold())
                        .foregroundStyle(Color(hex: "14B8A6"))
                    Text(isYearly ? "/year" : "/month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Trial badge
                if let subscription = product.subscription,
                   subscription.introductoryOffer != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.subheadline)
                        Text("Includes 7-day free trial")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "14B8A6"))
                    .cornerRadius(20)
                }
            }
            .padding(.top, 24)
            
            Divider()
                .padding(.horizontal)
            
            // Key Features
            VStack(alignment: .leading, spacing: 12) {
                Text("What you'll get:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                ForEach(tier.features.prefix(5), id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color(hex: "14B8A6"))
                            .accessibilityHidden(true)
                        Text(feature)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
                
                if tier.features.count > 5 {
                    Text("+ \(tier.features.count - 5) more features")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 32)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // CTA Buttons
            VStack(spacing: 12) {
                Button {
                    onPurchase()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Start Free Trial")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "14B8A6"))
                .disabled(isLoading)
                
                Button {
                    onCancel()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            
            // Legal fine print
            VStack(spacing: 4) {
                Text(isYearly ?
                     "Auto-renews at \(product.displayPrice)/year after trial." :
                     "Auto-renews at \(product.displayPrice)/month after trial.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Text("Cancel anytime in Settings > Subscriptions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Usage Progress Row (v2.7)
// Compact row with label, count, and progress bar for subscription usage display

struct UsageProgressRow: View {
    let label: String
    let sublabel: String
    let current: Int
    let limit: Int?
    let icon: String
    
    private var percentage: Double {
        guard let limit = limit, limit > 0 else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private var barColor: Color {
        if limit == 0 { return .red }
        let pct = percentage
        if pct >= 1.0 { return .red }
        if pct >= 0.8 { return .orange }
        return Color(hex: "14B8A6")
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(barColor)
                    .frame(width: 20)
                
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                if let limit = limit {
                    if limit == 0 {
                        Text("Not available")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("\(current) / \(limit)")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundStyle(barColor)
                        
                        Text(sublabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unlimited")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "14B8A6"))
                }
            }
            
            // Progress bar (only for limited resources with limit > 0)
            if let limit = limit, limit > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: max(0, geometry.size.width * percentage), height: 6)
                    }
                }
                .frame(height: 6)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            if let limit = limit {
                if limit == 0 {
                    return "\(label), not available on current plan"
                } else {
                    return "\(label), \(current) of \(limit) \(sublabel), \(Int(percentage * 100)) percent used"
                }
            } else {
                return "\(label), unlimited"
            }
        }())
    }
}

// MARK: - Feature Value Type
// v2.6: New enum to represent different feature states

enum FeatureValue {
    case enabled           // checkmark
    case disabled          // x-mark
    case limit(String)     // Custom text like "50/mo", "5"
    case unlimited         // infinity symbol
    case comingSoon        // "Soon" badge
}

// MARK: - Feature Row With Limits
// v2.6: New component that supports text values, not just checkmarks

struct FeatureRowWithLimits: View {
    let title: String
    let freeValue: FeatureValue
    let premiumValue: FeatureValue
    let proValue: FeatureValue
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            HStack(spacing: 8) {
                FeatureValueIcon(value: freeValue)
                FeatureValueIcon(value: premiumValue)
                FeatureValueIcon(value: proValue)
            }
        }
        .opacity(appeared ? 1 : 0.001)
        .offset(x: appeared ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: appeared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): Free \(spokenValue(freeValue)), Premium \(spokenValue(premiumValue)), Pro \(spokenValue(proValue))")
    }
    
    private func spokenValue(_ value: FeatureValue) -> String {
        switch value {
        case .enabled: return "included"
        case .disabled: return "not included"
        case .limit(let text): return text
        case .unlimited: return "unlimited"
        case .comingSoon: return "coming soon"
        }
    }
}

// MARK: - Feature Value Icon
// v2.6: Renders different feature value types

struct FeatureValueIcon: View {
    let value: FeatureValue
    
    var body: some View {
        Group {
            switch value {
            case .enabled:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: "14B8A6"))
                
            case .disabled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(.systemGray4))
                
            case .limit(let text):
                Text(text)
                    .font(.caption2.bold())
                    .foregroundColor(Color(hex: "14B8A6"))
                
            case .unlimited:
                Text("\u{221E}")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(hex: "14B8A6"))
                
            case .comingSoon:
                Text("Soon")
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
            }
        }
        .frame(width: 44)
    }
}

// MARK: - Subscription Card Button Style (v2.8 - Simplified)

/// Custom button style that provides press animation
struct SubscriptionCardButtonStyle: ButtonStyle {
    let isCurrentTier: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isCurrentTier ? 0.6 : 1.0)
    }
}

// MARK: - Subscription Option Card (v2.8 - Simplified)

struct SubscriptionOptionCard: View {
    let product: Product
    let tier: SubscriptionTier
    let isCurrentTier: Bool
    var isYearly: Bool = false
    var isRecommended: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Recommended Badge
                if isRecommended {
                    Text("MOST POPULAR")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "14B8A6"))
                        .cornerRadius(12, corners: [.topLeft, .topRight])
                }
                
                // Card Content
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tier.displayName)
                                .font(.title2.bold())
                            
                            if isCurrentTier {
                                Text("Current")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(tier.tagline)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        // Price
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(product.displayPrice)
                                .font(.title.bold())
                            Text(isYearly ? "/year" : "/month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Yearly Savings Badge
                        if isYearly, let savings = tier.yearlySavings {
                            Text(savings)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                        
                        // Trial info
                        if let subscription = product.subscription,
                           subscription.introductoryOffer != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .font(.caption)
                                Text("7-day free trial")
                                    .font(.caption.bold())
                            }
                            .foregroundColor(Color(hex: "14B8A6"))
                        }
                    }
                    
                    Spacer()
                    
                    // v2.8: Chevron indicator
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "14B8A6"))
                        .accessibilityHidden(true)
                }
                .padding(20)
            }
        }
        .buttonStyle(SubscriptionCardButtonStyle(isCurrentTier: isCurrentTier))
        .disabled(isCurrentTier)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            var label = "\(tier.displayName), \(product.displayPrice) per \(isYearly ? "year" : "month")"
            if isCurrentTier { label += ", current plan" }
            if isRecommended { label += ", most popular" }
            if let subscription = product.subscription,
               subscription.introductoryOffer != nil {
                label += ", includes 7 day free trial"
            }
            return label
        }())
        .accessibilityHint(isCurrentTier ? "This is your current plan" : "Opens purchase confirmation")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Legacy Feature Comparison Row (kept for compatibility)

struct FeatureComparisonRow: View {
    let title: String
    let free: Bool
    let premium: Bool
    let pro: Bool
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                CheckmarkIcon(enabled: free)
                CheckmarkIcon(enabled: premium)
                CheckmarkIcon(enabled: pro)
            }
        }
        .opacity(appeared ? 1 : 0.001)
        .offset(x: appeared ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

struct CheckmarkIcon: View {
    let enabled: Bool
    
    var body: some View {
        Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(enabled ? Color(hex: "14B8A6") : Color(.systemGray4))
            .frame(width: 44)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Extension for Rounded Corners

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
}
