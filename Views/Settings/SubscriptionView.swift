//  SubscriptionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.8 - Fix paywall bouncing back for already-subscribed users
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.8 - Auto-dismiss only on genuine upgrade:
//  ✅ FIXED: When a Pro/Premium user (or DEMO_PRO_TIER user) opened
//           SubscriptionView, loadProducts() emitted a @Published change on
//           appear, the .onChange(of: manager.currentTier) handler saw
//           newValue != .free, and called dismiss() — bouncing the user out
//           before the view rendered. This made the paywall unreachable for
//           subscribers (and broke screenshot capture in demo mode).
//  ✅ ADDED: tierOnAppear @State snapshot taken in .onAppear.
//  ✅ CHANGED: .onChange guard now requires (tierOnAppear == .free && newValue != .free)
//           so the auto-dismiss only fires on a true free → paid transition
//           triggered by a successful purchase in this session. Subscribers
//           navigating here see the "Current" badge on their plan and can
//           inspect upgrade/downgrade options without being bounced.
//
//  CHANGES v3.7 - Premium Annual Intro Launch Pricing:
//  ✅ CHANGED: Billing toggle label "Yearly (Save ~17%)" → "Yearly (Best Value)"
//             (stale: with Premium yearly at $59.99 the savings is now ~62%, not 17%)
//  ✅ ADDED: "LIMITED-TIME LAUNCH PRICING" pill next to Premium yearly savings badge
//             (only renders for tier == .premium in yearly mode)
//  ✅ NOTE: Actual price change lives in SubscriptionTier.swift v1.7 and must be
//           mirrored in App Store Connect for product com.finchandpoppy.flo.premium.yearly
//
//  CHANGES v3.6 - Trial Tier Switch (Premium):
//  ✅ CHANGED: Moved isRecommended ("MOST POPULAR") from Pro to Premium
//  ✅ REASON: 7-day free trial moves to Premium tier in App Store Connect
//  ✅ REASON: Protects against Plaid API fees from non-converting trial users
//  ✅ REASON: Creates natural upgrade path: Trial → Premium → Pro
//
//  CHANGES v3.5 - Dark Mode Optimization:
//  ✅ FIXED: L688 Color.gray → Color.gray.opacity(0.3) for tier badge background (adapts to dark mode)
//
//  CHANGES v3.4 - Dynamic Type Verification:
//  ✅ FIXED: Hero section "Unlock FLO Premium" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Hero section description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Billing toggle label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Unable to load subscription options" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Feature Comparison header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Feature table header labels (Feature/Free/Prem/Pro) missing minimumScaleFactor
//  ✅ FIXED: Feature row title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Legal text auto-renew disclosure missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Legal link labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Usage section header "Your Current Usage" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Usage section tier badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: UsageProgressRow label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: UsageProgressRow sublabel missing lineLimit + minimumScaleFactor
//  ✅ FIXED: UsageProgressRow count text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: UsageProgressRow "Not available" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: UsageProgressRow "Unlimited" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Already purchased?" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Restore Purchases" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Have an offer code?" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Redeem Offer Code" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet tier name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet price missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet period label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet trial badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet "What you'll get:" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet feature text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet "+ X more features" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet CTA button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet "Maybe Later" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: PurchaseConfirmationSheet legal text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FeatureValueIcon limit text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FeatureValueIcon "Soon" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FeatureValueIcon infinity symbol missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard tier name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard "Current" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard tagline missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard price missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard period label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard yearly savings badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SubscriptionOptionCard trial text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "MOST POPULAR" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toolbar "Restore" button missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Toolbar "Cancel" button missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Retry" button label missing lineLimit + minimumScaleFactor
//  ✅ ADDED: @ScaledMetric for feature table column widths (44pt → scales with Dynamic Type)
//  ✅ ADDED: @ScaledMetric for usage progress row icon width (20pt → scales with Dynamic Type)
//  ✅ ADDED: @Environment(\.dynamicTypeSize) for adaptive layout (future use)
//  ✅ NOTE: 53 text elements verified, 6 fixed-width frames replaced with @ScaledMetric
//
//  CHANGES v3.1:
//  - Replaced 23 instances of Color(hex: "14B8A6") with Color.brandPrimary
//  - Replaced 2 instances of Color(hex: "0D9488") with Color.brandPrimaryDark
//  - SubscriptionView now respects user's selected color scheme
//  - All colors adapt properly in dark mode
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
import FLODesignSystem
import StoreKit
import SwiftData

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var manager = SubscriptionManager.shared
    
    @State private var showingError = false
    @State private var isRestoring = false
    @State private var isRedeemingCode = false
    @State private var viewAppeared = false
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    
    // v2.8: Purchase confirmation sheet state
    @State private var showingPurchaseSheet = false
    @State private var selectedTierForPurchase: (product: Product, tier: SubscriptionTier)?

    // v3.8: Snapshot the tier when the view appears so we can distinguish a
    // genuine purchase transition (free → non-free) from a user who simply
    // navigated here while already subscribed. Without this, loadProducts()
    // emits a @Published change on appear, the onChange handler reads currentTier
    // as non-free (via DEMO_*_TIER override or real entitlement), and the view
    // auto-dismisses before it can render.
    @State private var tierOnAppear: SubscriptionTier?
    
    // MARK: - Usage Tracking (v2.7)
    @State private var usageLimitService: UsageLimitService?
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // MARK: - Dynamic Type Scaled Metrics
    @ScaledMetric(relativeTo: .caption) private var featureColumnWidth: CGFloat = 44
    
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
            .background(Color.floSystemGroupedBackground)
            .navigationTitle("Choose Your Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
            // v3.8: Only auto-dismiss on a genuine UPGRADE transition (free → paid).
            // Without the tierOnAppear guard, this would fire on first render when
            // @Published _currentTier emits via loadProducts() and bounce the user
            // out before they ever see the paywall.
            guard tierOnAppear == .free, newValue != .free else { return }
            HapticService.play(.success)
            showingPurchaseSheet = false
            dismiss()
        }
        .onAppear {
            // v3.8: Snapshot the tier we entered with. Used to gate the auto-
            // dismiss above so navigating here while already subscribed shows
            // the "manage your plan" view instead of bouncing.
            tierOnAppear = manager.currentTier

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
            #if canImport(UIKit)
            if #available(iOS 16.0, *) {
                await manager.presentOfferCodeRedeemSheet()
            }
            #endif
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
                .font(.largeTitle)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandPrimaryDark],
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
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            
            Text("Professional financial management built for freelancers")
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
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
                Text(selectedPeriod == .monthly ? "Monthly" : "Yearly (Best Value)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.brandPrimary))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.floSecondarySystemGroupedBackground)
            .cornerRadius(20)
            Spacer()
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.18), value: viewAppeared)
    }
    
    // MARK: - Subscription Options (v2.8 - Tap to Open Sheet)

    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            // Premium Option (Recommended — trial tier)
            let premiumProduct = manager.product(for: .premium, period: selectedPeriod)
            if let premiumProduct = premiumProduct {
                SubscriptionOptionCard(
                    product: premiumProduct,
                    tier: .premium,
                    isCurrentTier: manager.currentTier == .premium,
                    isYearly: selectedPeriod == .yearly,
                    isRecommended: true
                ) {
                    HapticService.play(.medium)
                    selectedTierForPurchase = (premiumProduct, .premium)
                    showingPurchaseSheet = true
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 30)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            }
            
            // Pro Option
            let proProduct = manager.product(for: .pro, period: selectedPeriod)
            if let proProduct = proProduct {
                SubscriptionOptionCard(
                    product: proProduct,
                    tier: .pro,
                    isCurrentTier: manager.currentTier == .pro,
                    isYearly: selectedPeriod == .yearly
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("Please check your internet connection and try again")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        HapticService.play(.medium)
                        Task {
                            await manager.loadProducts()
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.bottom, 4)
                .accessibilityAddTraits(.isHeader)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Header Row
            HStack {
                Text("Feature")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 8) {
                    Text("Free")
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: featureColumnWidth)
                    Text("Prem")
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: featureColumnWidth)
                    Text("Pro")
                        .font(.caption.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: featureColumnWidth)
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
            
            // Row 12: Bank Sync (Pro only)
            FeatureRowWithLimits(
                title: "Bank Sync",
                freeValue: .disabled,
                premiumValue: .disabled,
                proValue: .enabled,
                delay: 0.62, appeared: viewAppeared
            )
        }
        .padding(20)
        .background(Color.floSecondarySystemGroupedBackground)
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
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Legal document links - Apple Guideline 3.1.2 compliance
            HStack(spacing: 12) {
                Link("Terms", destination: URL(string: "https://floptimizer.github.io/FLO/terms.html")!)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                Link("EULA", destination: URL(string: "https://floptimizer.github.io/FLO/eula.html")!)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text("\u{2022}")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                Link("Privacy", destination: URL(string: "https://floptimizer.github.io/FLO/privacy.html")!)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                Text("Your Current Usage")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(manager.currentTier.displayName)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(manager.currentTier == .free ? Color.gray.opacity(0.3) : Color.brandPrimary)
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
        .background(Color.floSecondarySystemGroupedBackground)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.brandPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandPrimary, lineWidth: 1.5)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.brandPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandPrimary, lineWidth: 1.5)
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
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(
                            colors: tier == .pro ? [.purple, .indigo] : [Color.brandPrimary, Color.brandPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityHidden(true)
                
                Text(tier.displayName)
                    .font(.title.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.brandPrimary)
                    Text(isYearly ? "/year" : "/month")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .accessibleCurrency(
                    NSDecimalNumber(decimal: product.price).doubleValue,
                    label: isYearly ? "Yearly price" : "Monthly price"
                )
                
                // Trial badge
                if let subscription = product.subscription,
                   subscription.introductoryOffer != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "gift.fill")
                            .font(.subheadline)
                        Text("Includes 7-day free trial")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.brandPrimary)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                
                ForEach(tier.features.prefix(5), id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)
                        Text(feature)
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                }
                
                if tier.features.count > 5 {
                    Text("+ \(tier.features.count - 5) more features")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                .disabled(isLoading)
                
                Button {
                    onCancel()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .accessibleCurrency(
                        NSDecimalNumber(decimal: product.price).doubleValue,
                        label: isYearly ? "Auto-renews at \(AccessibilityFormatters.spokenCurrency(NSDecimalNumber(decimal: product.price).doubleValue)) per year after trial" : "Auto-renews at \(AccessibilityFormatters.spokenCurrency(NSDecimalNumber(decimal: product.price).doubleValue)) per month after trial"
                    )
                
                Text("Cancel anytime in Settings > Subscriptions.")
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
    
    @ScaledMetric(relativeTo: .caption) private var iconWidth: CGFloat = 20
    
    private var percentage: Double {
        guard let limit = limit, limit > 0 else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private var barColor: Color {
        if limit == 0 { return .red }
        let pct = percentage
        if pct >= 1.0 { return .red }
        if pct >= 0.8 { return .orange }
        return Color.brandPrimary
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(barColor)
                    .frame(width: iconWidth)
                
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                if let limit = limit {
                    if limit == 0 {
                        Text("Not available")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.red)
                    } else {
                        Text("\(current) / \(limit)")
                            .font(.subheadline.monospacedDigit())
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(barColor)
                        
                        Text(sublabel)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Unlimited")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.brandPrimary)
                }
            }
            
            // Progress bar (only for limited resources with limit > 0)
            if let limit = limit, limit > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor)
                            .frame(width: max(0, geometry.size.width * percentage), height: 6)
                    }
                }
                .frame(height: 6)
                .accessibilityLabel("\(label) usage progress")
                .accessibilityValue("\(Int(percentage * 100))% used, \(current) of \(limit) \(sublabel)")
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
    
    @ScaledMetric(relativeTo: .caption) private var columnWidth: CGFloat = 44
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                FeatureValueIcon(value: freeValue, columnWidth: columnWidth)
                FeatureValueIcon(value: premiumValue, columnWidth: columnWidth)
                FeatureValueIcon(value: proValue, columnWidth: columnWidth)
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
    var columnWidth: CGFloat = 44
    
    var body: some View {
        Group {
            switch value {
            case .enabled:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.brandPrimary)
                
            case .disabled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.gray.opacity(0.3))
                
            case .limit(let text):
                Text(text)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(Color.brandPrimary)
                
            case .unlimited:
                Text("\u{221E}")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(Color.brandPrimary)
                
            case .comingSoon:
                Text("Soon")
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .cornerRadius(4)
            }
        }
        .frame(width: columnWidth)
    }
}

// MARK: - Subscription Card Button Style (v2.8 - Simplified)

/// Custom button style that provides press animation
struct SubscriptionCardButtonStyle: ButtonStyle {
    let isCurrentTier: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.floSecondarySystemGroupedBackground)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.brandPrimary)
                        #if canImport(UIKit)
                        .cornerRadius(12, corners: [.topLeft, .topRight])
                        #else
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
                        #endif
                }
                
                // Card Content
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(tier.displayName)
                                .font(.title2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            if isCurrentTier {
                                Text("Current")
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(tier.tagline)
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                        
                        // Price
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(product.displayPrice)
                                .font(.title.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(isYearly ? "/year" : "/month")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        .accessibleCurrency(
                            NSDecimalNumber(decimal: product.price).doubleValue,
                            label: isYearly ? "Yearly price" : "Monthly price"
                        )
                        
                        // Yearly Savings Badge
                        if isYearly, let savings = tier.yearlySavings {
                            HStack(spacing: 6) {
                                Text(savings)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(4)

                                // Premium intro launch badge (v3.7)
                                if tier == .premium {
                                    Text("LIMITED-TIME LAUNCH PRICING")
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundColor(Color.brandPrimary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.brandPrimary.opacity(0.12))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        // Trial info
                        if let subscription = product.subscription,
                           subscription.introductoryOffer != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .font(.caption)
                                Text("7-day free trial")
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .foregroundColor(Color.brandPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    // v2.8: Chevron indicator
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.brandPrimary)
                        .accessibilityHidden(true)
                }
                .padding(20)
            }
        }
        .buttonStyle(SubscriptionCardButtonStyle(isCurrentTier: isCurrentTier))
        .disabled(isCurrentTier)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let spokenPrice = AccessibilityFormatters.spokenCurrency(NSDecimalNumber(decimal: product.price).doubleValue)
            var label = "\(tier.displayName), \(spokenPrice) per \(isYearly ? "year" : "month")"
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
            .foregroundColor(enabled ? Color.brandPrimary : Color.gray.opacity(0.3))
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

#if canImport(UIKit)
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
#endif

// MARK: - Preview

#Preview {
    SubscriptionView()
}
