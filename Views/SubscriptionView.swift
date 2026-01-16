//  SubscriptionView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Fixed scroll blocking on subscription cards
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ Fixed scroll blocking when touching subscription cards
//  ✅ Replaced simultaneousGesture with proper ButtonStyle
//  ✅ Scrolling now works smoothly everywhere
//
//  PREVIOUS (v2.1):
//  - Restored yearly billing toggle (IAPs exist in App Store Connect)
//  - Fixed card press animation for better iPad compatibility
//  - Graceful fallback if yearly products not yet approved
//
//  PREVIOUS (v1.1):
//  - Haptic feedback on plan selection
//  - Haptic on purchase/restore actions
//  - Hero section entrance animation
//  - Plan cards staggered animation
//  - Feature comparison fade-in
//  - Icon pulse animation
//  - Selection scale effect
//  - Success haptic on purchase complete
//
//  Beautiful subscription paywall with feature comparison

import SwiftUI
import StoreKit

// MARK: - Subscription View

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = SubscriptionManager.shared
    
    @State private var selectedProduct: Product?
    @State private var showingError = false
    @State private var isRestoring = false
    @State private var viewAppeared = false
    @State private var selectedPeriod: SubscriptionPeriod = .monthly
    
    // Haptic Generators
                    
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
                        HapticService.play(.medium)
                        Task {
                            isRestoring = true
                            await manager.restorePurchases()
                            isRestoring = false
                            if manager.currentTier != .free {
                                HapticService.play(.success)
                            }
                        }
                    } label: {
                        if isRestoring {
                            ProgressView()
                        } else {
                            Text("Restore")
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
                dismiss()
            }
        }
        .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
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
                .opacity(viewAppeared ? 1 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 0.6), value: viewAppeared)
            
            Text("Unlock FLO Premium")
                .font(.system(size: 28, weight: .bold))
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            
            Text("Professional financial management built for freelancers")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(viewAppeared ? 1 : 0)
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
                        // Clear selection when switching periods
                        selectedProduct = nil
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
        .opacity(viewAppeared ? 1 : 0)
        .animation(FLOAnimation.standard.delay(0.18), value: viewAppeared)
    }
    
    // MARK: - Subscription Options

    private var subscriptionOptions: some View {
        VStack(spacing: 16) {
            // Premium Option
            let premiumProduct = manager.product(for: .premium, period: selectedPeriod)
            if let premiumProduct = premiumProduct {
                SubscriptionOptionCard(
                    product: premiumProduct,
                    tier: .premium,
                    isSelected: selectedProduct?.id == premiumProduct.id,
                    isCurrentTier: manager.currentTier == .premium,
                    isYearly: selectedPeriod == .yearly
                ) {
                    HapticService.play(.selection)
                    withAnimation(FLOAnimation.quick) {
                        selectedProduct = premiumProduct
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 30)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            }
            
            // Pro Option (Recommended)
            let proProduct = manager.product(for: .pro, period: selectedPeriod)
            if let proProduct = proProduct {
                SubscriptionOptionCard(
                    product: proProduct,
                    tier: .pro,
                    isSelected: selectedProduct?.id == proProduct.id,
                    isCurrentTier: manager.currentTier == .pro,
                    isYearly: selectedPeriod == .yearly,
                    isRecommended: true
                ) {
                    HapticService.play(.selection)
                    withAnimation(FLOAnimation.quick) {
                        selectedProduct = proProduct
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
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
            
            // Subscribe Button
            if let product = selectedProduct {
                Button {
                    HapticService.play(.medium)
                    Task {
                        do {
                            try await manager.purchase(product)
                            HapticService.play(.success)
                        } catch {
                            HapticService.play(.error)
                        }
                    }
                } label: {
                    HStack {
                        if manager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Start 7-Day Free Trial")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "14B8A6"))
                .disabled(manager.isLoading)
                .padding(.top, 8)
                .opacity(viewAppeared ? 1 : 0)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
            }
        }
    }
    
    // MARK: - Feature Comparison
    
    private var featureComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Feature Comparison")
                .font(.headline)
                .padding(.bottom, 4)
                .opacity(viewAppeared ? 1 : 0)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
            
            // Header Row
            HStack {
                Text("Feature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 20) {
                    Text("Free")
                        .font(.caption.bold())
                        .frame(width: 30)
                    Text("Prem")
                        .font(.caption.bold())
                        .frame(width: 30)
                    Text("Pro")
                        .font(.caption.bold())
                        .frame(width: 30)
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .animation(FLOAnimation.standard.delay(0.38), value: viewAppeared)
            
            Divider()
            
            // Feature rows
            FeatureComparisonRow(title: "Transactions", free: true, premium: true, pro: true, delay: 0.4, appeared: viewAppeared)
            FeatureComparisonRow(title: "Multiple Accounts", free: false, premium: true, pro: true, delay: 0.42, appeared: viewAppeared)
            FeatureComparisonRow(title: "Tax Estimates", free: false, premium: true, pro: true, delay: 0.44, appeared: viewAppeared)
            FeatureComparisonRow(title: "Mileage Tracking", free: false, premium: true, pro: true, delay: 0.46, appeared: viewAppeared)
            FeatureComparisonRow(title: "Invoicing", free: false, premium: true, pro: true, delay: 0.48, appeared: viewAppeared)
            FeatureComparisonRow(title: "Client Management", free: false, premium: false, pro: true, delay: 0.5, appeared: viewAppeared)
            FeatureComparisonRow(title: "Custom Branding", free: false, premium: false, pro: true, delay: 0.52, appeared: viewAppeared)
            FeatureComparisonRow(title: "Advanced Exports", free: false, premium: false, pro: true, delay: 0.54, appeared: viewAppeared)
            FeatureComparisonRow(title: "Priority Support", free: false, premium: false, pro: true, delay: 0.56, appeared: viewAppeared)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Legal Text
    
    private var legalText: some View {
        VStack(spacing: 8) {
            Text(selectedPeriod == .monthly ?
                 "Subscriptions auto-renew monthly until cancelled. Cancel anytime in Settings > Subscriptions." :
                 "Subscriptions auto-renew yearly until cancelled. Cancel anytime in Settings > Subscriptions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Link("Terms of Service", destination: URL(string: "https://finchandpoppy.com/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://finchandpoppy.com/privacy")!)
            }
            .font(.caption2)
        }
        .opacity(viewAppeared ? 1 : 0)
        .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
    }
}

// MARK: - Subscription Card Button Style

/// Custom button style that provides press animation without blocking scroll gestures
struct SubscriptionCardButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isCurrentTier: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "14B8A6") : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(isCurrentTier ? 0.6 : 1.0)
    }
}

// MARK: - Subscription Option Card

struct SubscriptionOptionCard: View {
    let product: Product
    let tier: SubscriptionTier
    let isSelected: Bool
    let isCurrentTier: Bool
    var isYearly: Bool = false
    var isRecommended: Bool = false
    let action: () -> Void
    
    init(product: Product, tier: SubscriptionTier, isSelected: Bool, isCurrentTier: Bool, isYearly: Bool = false, isRecommended: Bool = false, action: @escaping () -> Void) {
        self.product = product
        self.tier = tier
        self.isSelected = isSelected
        self.isCurrentTier = isCurrentTier
        self.isYearly = isYearly
        self.isRecommended = isRecommended
        self.action = action
    }
    
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
                HStack(alignment: .top, spacing: 16) {
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
                        
                        // Key features
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(tier.features.prefix(3), id: \.self) { feature in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "14B8A6"))
                                    Text(feature)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if tier.features.count > 3 {
                                Text("+ \(tier.features.count - 3) more features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "14B8A6"))
                }
                .padding(20)
            }
        }
        .buttonStyle(SubscriptionCardButtonStyle(isSelected: isSelected, isCurrentTier: isCurrentTier))
        .disabled(isCurrentTier)
    }
}

// MARK: - Feature Comparison Row

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
            
            HStack(spacing: 20) {
                CheckmarkIcon(enabled: free)
                CheckmarkIcon(enabled: premium)
                CheckmarkIcon(enabled: pro)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: appeared)
    }
}

struct CheckmarkIcon: View {
    let enabled: Bool
    
    var body: some View {
        Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(enabled ? Color(hex: "14B8A6") : Color(.systemGray4))
            .frame(width: 30)
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
