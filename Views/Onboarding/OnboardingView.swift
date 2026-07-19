//  OnboardingView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.2 - Dynamic Type verification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.0:
//  ✅ REMOVED: Tax Setup page (moved to Getting Started card)
//  ✅ ADDED: FLO in Action page (app preview carousel)
//  ✅ ADDED: Value Proposition page (3 key benefits)
//  ✅ IMPROVED: More engaging, visual-first onboarding
//  ✅ Flow: Welcome → FLO in Action → Built for You → Get Started
//
//  CHANGES v3.0:
//  - Apple 5.1.1 compliance (removed permissions page)
//  - Added Tax Setup page (now removed in v4.0)
//

import SwiftUI
import SwiftData
import CoreLocation
import FLODesignSystem

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var currentPage = 0
    
    private let totalPages = 4  // Welcome, FLO in Action, Built for You, Get Started
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.brandPrimary.opacity(0.1),
                    Color.brandPrimaryDark.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button (not shown on final page)
                if currentPage < totalPages - 1 {
                    HStack {
                        Spacer()
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                 .foregroundStyle(Color.brandPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding()
                } else {
                    Color.clear.frame(height: 52)
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePageView()
                        .tag(0)
                    
                    FLOInActionPageView()
                        .tag(1)
                    
                    ValuePropositionPageView()
                        .tag(2)
                    
                    GetStartedPageView(completeAction: completeOnboarding)
                        .tag(3)
                }
                #if !os(macOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                #endif
                
                // Navigation buttons
                HStack(spacing: 20) {
                    // Back button
                    if currentPage > 0 {
                        Button {
                            HapticService.play(.light)
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                    .accessibilityHidden(true)
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Next button (not shown on final page - it has its own button)
                    if currentPage < totalPages - 1 {
                        Button {
                            HapticService.play(.light)
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                                    .accessibilityHidden(true)
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandPrimary)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func completeOnboarding() {
        HapticService.play(.success)
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Welcome Page

struct WelcomePageView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Animated app icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.brandPrimary.opacity(0.3), radius: 20)
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text("Welcome to FLO")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Finance Ledger Optimizer")
                    .font(.title3)
                     .foregroundStyle(Color.brandPrimary)
            }
            .opacity(textOpacity)
            
            VStack(spacing: 16) {
                Text("Take control of your business finances")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text("Track expenses, estimate taxes, manage invoices, and stay organized—all from your iPhone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 30)
            }
            .opacity(textOpacity)
            
            Spacer()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to FLO, Finance Ledger Optimizer. Take control of your business finances. Track expenses, estimate taxes, manage invoices, and stay organized.")
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                textOpacity = 1.0
            }
        }
    }
}

// MARK: - FLO in Action Page (NEW in v4.0)

struct FLOInActionPageView: View {
    @State private var currentPreview = 0
    @State private var appeared = false
    
    private let previews: [(icon: String, title: String, description: String, color: Color)] = [
        ("chart.bar.doc.horizontal", "Smart Dashboard", "Your finances at a glance—income, expenses, and tax estimates all in one place.", .blue),
        ("camera.viewfinder", "Receipt Scanning", "Snap a photo, and FLO extracts the details automatically.", .green),
        ("percent", "Tax Estimates", "Real-time quarterly estimates with 2026 IRS rates. No surprises at tax time.", .orange),
        ("car.fill", "Mileage Tracking", "Automatic GPS tracking turns your drives into deductions.", .purple)
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("FLO in Action")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .opacity(appeared ? 1 : 0.001)
                .offset(y: appeared ? 0 : 20)
                .accessibilityAddTraits(.isHeader)
            
            // Feature preview carousel
            TabView(selection: $currentPreview) {
                ForEach(0..<previews.count, id: \.self) { index in
                    FeaturePreviewCard(
                        icon: previews[index].icon,
                        title: previews[index].title,
                        description: previews[index].description,
                        color: previews[index].color
                    )
                    .tag(index)
                }
            }
            #if !os(macOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif
            .frame(height: 340)
            .opacity(appeared ? 1 : 0.001)
            .offset(y: appeared ? 0 : 30)
            .accessibilityLabel("Feature preview, showing \(previews[currentPreview].title)")
            .accessibilityHint("Swipe left or right to see other features")
            
            // Swipe hint
            HStack(spacing: 4) {
                Image(systemName: "hand.draw")
                    .font(.caption)
                Text("Swipe to explore")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .opacity(appeared ? 0.7 : 0)
            .accessibilityHidden(true)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}

// MARK: - Feature Preview Card

struct FeaturePreviewCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon with background
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(color.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.floSystemBackground)
                .shadow(color: .black.opacity(0.08), radius: 15, y: 5)
        )
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

// MARK: - Value Proposition Page (NEW in v4.0)

struct ValuePropositionPageView: View {
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            VStack(spacing: 12) {
                Text("Built for Freelancers")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("By freelancers, for freelancers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0.001)
            .offset(y: appeared ? 0 : 20)
            
            VStack(spacing: 16) {
                ValuePropRow(
                    icon: "checkmark.seal.fill",
                    title: "Know What You Owe",
                    description: "Real-time tax estimates so quarterly payments are never a surprise",
                    delay: 0.1
                )
                
                ValuePropRow(
                    icon: "bolt.fill",
                    title: "Save Hours Every Month",
                    description: "Receipt scanning and automatic categorization do the work for you",
                    delay: 0.2
                )
                
                ValuePropRow(
                    icon: "dollarsign.circle.fill",
                    title: "Maximize Deductions",
                    description: "Mileage tracking and expense categorization help you keep more",
                    delay: 0.3
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

// MARK: - Value Prop Row

struct ValuePropRow: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.floSystemBackground)
        .cornerRadius(12)
        .floCardShadow(radius: 5)
        .opacity(appeared ? 1 : 0.001)
        .offset(x: appeared ? 0 : -20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Get Started Page

struct GetStartedPageView: View {
    let completeAction: () -> Void
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var contentOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success icon with animation
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .shadow(color: Color.brandPrimary.opacity(0.3), radius: 20)
            .scaleEffect(checkmarkScale)
            .accessibilityHidden(true)
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Your dashboard is ready.\nWe'll guide you through the rest.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .opacity(contentOpacity)
            
            // Quick tips
            VStack(spacing: 12) {
                QuickTipRow(
                    icon: "hand.tap.fill",
                    text: "Look for the Getting Started card on your dashboard"
                )
                
                QuickTipRow(
                    icon: "plus.circle.fill",
                    text: "Tap + to add your first transaction"
                )
                
                QuickTipRow(
                    icon: "questionmark.circle.fill",
                    text: "Need help? Visit Settings → Support"
                )
            }
            .padding(.horizontal, 30)
            .opacity(contentOpacity)
            
            Spacer()
            
            // Get Started button
            Button {
                completeAction()
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
            .opacity(contentOpacity)
            .accessibilityLabel("Let's Go!")
            .accessibilityHint("Double tap to complete setup and go to your dashboard")
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkmarkScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                contentOpacity = 1.0
            }
        }
    }
}

// MARK: - Quick Tip Row

struct QuickTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: \(text)")
    }
}

// MARK: - Mileage Setup Location Manager
// Used by MileageSetupPromptView and MileageTrackingMainView

class MileageSetupLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Limited Mode Views (kept for MileageSetupPromptView)

struct LimitedModeExplanationView: View {
    let onOpenSettings: () -> Void
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)
                
                Text("Limited Tracking Mode")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text("Without \"Always Allow\", FLO can only track trips while the app is open on your screen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 24)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What this means:")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                
                LimitedModeRow(icon: "xmark.circle.fill", iconColor: .red, text: "No automatic trip detection")
                LimitedModeRow(icon: "xmark.circle.fill", iconColor: .red, text: "Tracking stops when app is backgrounded")
                LimitedModeRow(icon: "checkmark.circle.fill", iconColor: .green, text: "Manual trip entry still works")
            }
            .padding()
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                Button {
                    onOpenSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .accessibilityHidden(true)
                        Text("Open Phone Settings")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(10)
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue with Limited Mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

struct LimitedModeRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
