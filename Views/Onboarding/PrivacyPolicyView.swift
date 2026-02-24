//  PrivacyPolicyView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Accessibility Audit: Full VoiceOver support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Section entrance animations
//  ✅ Icon symbol effects
//  ✅ Link haptic feedback
//  ✅ Smooth scroll appearance
//
//  PREVIOUS (v1.0):
//  - Basic in-app privacy policy

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false
    
    // Haptic Generators
        
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "hand.raised.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: viewAppeared)
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text("Privacy Policy")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Effective: January 1, 2025")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Text("Your privacy is important to us. FLO is designed with privacy at its core - your financial data stays on your device.")
                        .font(.callout)
                        .foregroundStyle(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Key Privacy Principles
                VStack(alignment: .leading, spacing: 12) {
                    Text("Our Privacy Principles")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PrivacyPrinciple(
                            icon: "lock.shield.fill",
                            text: "Local-First: Your financial data is stored on your device, not our servers",
                            color: .green
                        )
                        PrivacyPrinciple(
                            icon: "eye.slash.fill",
                            text: "We Don't Sell Data: We never sell, rent, or share your personal information",
                            color: .blue
                        )
                        PrivacyPrinciple(
                            icon: "shield.checkered",
                            text: "Minimal Collection: We only collect what's necessary to provide the service",
                            color: .purple
                        )
                        PrivacyPrinciple(
                            icon: "arrow.up.right.circle.fill",
                            text: "Your Control: You can export or delete your data at any time",
                            color: .orange
                        )
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // What We Collect
                PrivacySection(
                    icon: "doc.text.fill",
                    title: "Information You Provide",
                    color: .blue,
                    content: """
                    When you use FLO, you may provide:
                    
                    • Financial transactions (income, expenses, receipts)
                    • Business profile information (name, email, address)
                    • Client information (names, contact details)
                    • Invoice data and payment records
                    • Budget and category preferences
                    • Tax settings and filing status
                    
                    All this data is stored locally on your device using iOS's secure storage systems.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                // Automatic Collection
                PrivacySection(
                    icon: "cpu.fill",
                    title: "Information We Collect Automatically",
                    color: .purple,
                    content: """
                    For app functionality and improvement:
                    
                    • Device type and iOS version (for compatibility)
                    • App usage analytics (crashes, feature usage)
                    • Location data (only when using mileage tracking, with permission)
                    • Photo library access (only for receipt scanning, with permission)
                    • Camera access (only for receipt photos, with permission)
                    
                    We use Apple's privacy-focused analytics and never see personally identifiable information.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                // How We Use Data
                PrivacySection(
                    icon: "gearshape.fill",
                    title: "How We Use Your Information",
                    color: .green,
                    content: """
                    We use the information you provide to:
                    
                    • Provide financial tracking and tax estimation services
                    • Generate invoices and reports
                    • Calculate mileage deductions
                    • Scan and process receipt data (locally on device)
                    • Sync across your devices via iCloud (if you enable it)
                    • Improve app performance and fix bugs
                    • Provide customer support
                    
                    Your financial data never leaves your device unless you explicitly export it.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Data Storage
                PrivacySection(
                    icon: "externaldrive.fill",
                    title: "Data Storage & Security",
                    color: .orange,
                    content: """
                    Your data security is paramount:
                    
                    • All data stored using iOS's encrypted storage (SwiftData)
                    • Receipt photos stored in secure app container
                    • Optional Face ID/Touch ID protection
                    • Optional passcode lock for app access
                    • Data stays on device (local-first architecture)
                    • iCloud sync available (encrypted, optional)
                    • No unencrypted cloud backups
                    
                    We use industry-standard encryption and security practices.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Your Rights
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Privacy Rights")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        PrivacyRight(text: "Access: View all your data within the app at any time")
                        PrivacyRight(text: "Export: Download your data in CSV format")
                        PrivacyRight(text: "Delete: Remove all data by deleting the app")
                        PrivacyRight(text: "Opt-Out: Disable analytics in iOS Settings → Privacy")
                        PrivacyRight(text: "Portability: Export and transfer your data to other services")
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Contact Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.headline)
                    
                    Text("Questions about privacy?")
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
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                // Online Privacy Policy Link
                Link(destination: AppConstants.privacyPolicyURL) {
                    HStack {
                        Image(systemName: "safari")
                            .accessibilityHidden(true)
                        Text("View Full Privacy Policy Online")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .accessibilityHidden(true)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticService.play(.light)
                })
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                
                // Version Info
                Text("Last Updated: January 1, 2025 • FLO v\(AppConstants.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            // v1.2: Announce screen
            AccessibilityAnnouncement.screenChanged("Privacy Policy")
        }
    }
}

// MARK: - Supporting Views

struct PrivacySection: View {
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

struct PrivacyPrinciple: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
                // v1.2: Decorative
                .accessibilityHidden(true)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

struct PrivacyRight: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 2)
                // v1.2: Decorative
                .accessibilityHidden(true)
            
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
