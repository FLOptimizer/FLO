//  TermsOfServiceView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Invoice Limit Correction
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3:
//  ✅ FIXED: Premium tier invoice limit corrected from 10 to 25 (matches SubscriptionTier.swift)
//
//  CHANGES v1.2:
//  ✅ Screen change announcement on appear
//  ✅ Header decorative icon hidden from VoiceOver
//  ✅ TermsSection icon hidden, title as header trait
//  ✅ Free trial icon hidden
//  ✅ Email link labeled with hint
//  ✅ Online link labeled with hint
//  ✅ Acknowledgment section accessible
//
//  CHANGES v1.1:
//  - Section entrance animations, icon symbol effects
//  - Link haptic feedback, smooth scroll appearance

import SwiftUI
import FLODesignSystem

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false
    
    // Haptic Generators
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.teal)
                            .symbolEffect(.bounce, value: viewAppeared)
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text("Terms of Service")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Effective: January 1, 2025")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Text("By using FLO, you agree to these terms. Please read them carefully before using the app.")
                        .font(.callout)
                        .foregroundStyle(.teal)
                        .padding()
                        .background(Color.teal.opacity(0.1))
                        .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Acceptance of Terms
                TermsSection(
                    icon: "hand.thumbsup.fill",
                    title: "Acceptance of Terms",
                    color: .blue,
                    content: """
                    By downloading, installing, or using FLO, you agree to be bound by these Terms of Service. If you do not agree, do not use the app.
                    
                    These terms constitute a legal agreement between you and Finch & Poppy Co LLC.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // License to Use
                TermsSection(
                    icon: "key.fill",
                    title: "License to Use FLO",
                    color: .green,
                    content: """
                    Subject to your compliance with these Terms, we grant you a limited, non-exclusive, non-transferable, revocable license to:
                    
                    • Download and install FLO on devices you own or control
                    • Use FLO for personal or business financial tracking
                    • Access features based on your subscription tier
                    
                    You may NOT:
                    • Reverse engineer, decompile, or disassemble the app
                    • Rent, lease, sublicense, or transfer the app to third parties
                    • Remove copyright or proprietary notices
                    • Use the app for illegal activities or to violate tax laws
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                // Subscription Terms
                TermsSection(
                    icon: "creditcard.fill",
                    title: "Subscription & Payment",
                    color: .purple,
                    content: """
                    FLO offers Free, Premium, and Pro subscription tiers:
                    
                    Free Tier:
                    • Basic transaction tracking and budgeting
                    • Limited features as specified in-app
                    
                    Premium ($12.99/month):
                    • Tax estimates, mileage tracking
                    • Up to 25 invoices per month
                    • Limited client management
                    
                    Pro ($19.99/month):
                    • Unlimited invoices and clients
                    • All premium features
                    • Priority support
                    
                    Payment & Renewal:
                    • Subscriptions are billed monthly via Apple's App Store
                    • Auto-renews unless cancelled 24+ hours before period end
                    • Manage subscriptions in iOS Settings
                    • No refunds for partial months
                    • Prices subject to change with 30 days notice
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                // Free Trial
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundStyle(.orange)
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                        Text("Free Trial Policy")
                            .font(.headline)
                    }
                    
                    Text("If offered, free trials automatically convert to paid subscriptions unless cancelled before trial end. You will be charged immediately after the trial period expires.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // User Responsibilities
                TermsSection(
                    icon: "person.fill.checkmark",
                    title: "Your Responsibilities",
                    color: .blue,
                    content: """
                    You are responsible for:
                    
                    • Providing accurate information in the app
                    • Maintaining security of your device and account
                    • Complying with all applicable tax laws and regulations
                    • Verifying all calculations before filing taxes
                    • Keeping backups of your financial data
                    • Using the app in accordance with these Terms
                    
                    You agree NOT to:
                    • Share your account with unauthorized users
                    • Use the app to store illegal or fraudulent data
                    • Attempt to gain unauthorized access to our systems
                    • Use automated tools to access the app
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Data Accuracy
                TermsSection(
                    icon: "exclamationmark.triangle.fill",
                    title: "Data Accuracy & Tax Compliance",
                    color: .red,
                    content: """
                    IMPORTANT: FLO is a financial tracking tool, not professional tax advice.
                    
                    • Tax estimates are approximations only
                    • You are solely responsible for tax filing accuracy
                    • We are not liable for tax calculation errors
                    • Always consult qualified tax professionals
                    • The IRS holds YOU responsible for accurate filing
                    
                    See our separate Tax & Legal Disclaimer for complete details.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Intellectual Property
                TermsSection(
                    icon: "c.circle.fill",
                    title: "Intellectual Property",
                    color: .indigo,
                    content: """
                    All content in FLO (design, code, text, graphics, logos) is owned by Finch & Poppy Co LLC and protected by copyright, trademark, and other intellectual property laws.
                    
                    You retain ownership of your financial data entered into the app. By using FLO, you grant us no rights to your data except as necessary to provide the service.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                // Contact Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.headline)
                    
                    Text("Questions about these Terms?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Link(destination: URL(string: "mailto:flo.financeapp@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                // v1.2: Decorative
                                .accessibilityHidden(true)
                            Text("flo.financeapp@gmail.com")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticService.play(.light)
                    })
                    // v1.2: VoiceOver
                    .accessibilityLabel("Email support at flo.financeapp@gmail.com")
                    .accessibilityHint("Double tap to open email")
                    
                    Text("Finch & Poppy Co LLC")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                
                // Online Terms Link
                Link(destination: AppConstants.termsOfServiceURL) {
                    HStack {
                        Image(systemName: "safari")
                            .accessibilityHidden(true)
                        Text("View Full Terms Online")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .accessibilityHidden(true)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.teal)
                    .cornerRadius(10)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticService.play(.light)
                })
                // v1.2: VoiceOver
                .accessibilityLabel("View full Terms of Service online")
                .accessibilityHint("Double tap to open in Safari")
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                
                // Acknowledgment
                VStack(alignment: .leading, spacing: 8) {
                    Text("By using FLO, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .padding()
                        .background(Color.teal.opacity(0.1))
                        .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
                
                // Version Info
                Text("Last Updated: January 1, 2025 • FLO v\(AppConstants.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            // v1.2: Announce screen
            AccessibilityAnnouncement.screenChanged("Terms of Service")
        }
    }
}

// MARK: - Supporting Views

struct TermsSection: View {
    let icon: String
    let title: String
    let color: Color
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 30)
                    // v1.2: Decorative
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.headline)
                    // v1.2: Header trait
                    .accessibilityAddTraits(.isHeader)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TermsOfServiceView()
    }
}
