//  EULAView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification: lineLimit + minimumScaleFactor on headers/labels
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: "End User License Agreement" header title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Last updated" label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Opening disclaimer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EULASection title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Critical Disclaimer" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Disclaimer banner text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Key Points Summary" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: EULAKeyPoint text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Contact Us" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Contact section labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Email link text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Company name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Related Documents" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RelatedDocumentLink title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "View Full EULA Online" button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Version info text missing lineLimit + minimumScaleFactor
//  ✅ VERIFIED: Body paragraph text (EULASection content) left without lineLimit per legal text guidelines
//
//  CHANGES v1.1:
//  ✅ Screen change announcement on appear
//  ✅ Header decorative icon hidden from VoiceOver
//  ✅ EULASection icon hidden, title as header trait
//  ✅ EULAKeyPoint checkmark hidden
//  ✅ Disclaimer banner icon hidden
//  ✅ RelatedDocumentLink icons hidden
//  ✅ Email link labeled with hint
//  ✅ Online EULA link labeled with hint
//
//  PREVIOUS (v1.0):
//  - In-app EULA with key sections

import SwiftUI

struct EULAView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewAppeared = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.brandPrimary)
                            // v1.1: Decorative
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text("End User License Agreement")
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                            
                            Text("Last updated: January 2026")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Text("By downloading, installing, or using FLO, you agree to be bound by this EULA. If you do not agree, do not use the software.")
                        .font(.callout)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                
                // Description of Software
                EULASection(
                    icon: "apps.iphone",
                    title: "About FLO",
                    color: .blue,
                    content: """
                    FLO is a financial management application for iOS devices, designed for freelancers, gig workers, and small business owners. Features include:
                    
                    • Transaction tracking and categorization
                    • Budget creation and monitoring
                    • Invoice generation and payment tracking
                    • Receipt scanning and storage
                    • Business mileage tracking
                    • Tax estimate calculations
                    • Financial reports and analytics
                    
                    These features are provided as software tools. They are NOT professional financial, tax, accounting, or legal advice.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // License Grant
                EULASection(
                    icon: "checkmark.seal.fill",
                    title: "License Grant",
                    color: .green,
                    content: """
                    FINCH & POPPY CO. LLC grants you a non-transferable license to use FLO on Apple-branded products that you own or control, as permitted by the App Store Usage Rules.
                    
                    This license covers:
                    • The application and any updates
                    • Content and services within the app
                    • Materials accessible through the app
                    
                    You may not distribute or make the app available over a network for simultaneous use by multiple devices.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                
                // License Restrictions
                EULASection(
                    icon: "xmark.shield.fill",
                    title: "License Restrictions",
                    color: .red,
                    content: """
                    You agree NOT to:
                    
                    • Copy, modify, or create derivative works
                    • Reverse engineer, decompile, or disassemble
                    • Rent, lease, lend, sell, or sublicense
                    • Remove copyright or proprietary notices
                    • Use for illegal purposes
                    • Access source code or underlying algorithms
                    • Develop competing products
                    • Use automated systems to extract data
                    
                    Violation may result in immediate license termination.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                
                // Data & Privacy
                EULASection(
                    icon: "lock.shield.fill",
                    title: "Data & Privacy",
                    color: .purple,
                    content: """
                    FLO is designed with privacy as a core principle:
                    
                    • Your financial data is stored locally on your device
                    • We do not collect or transmit your financial data to servers
                    • You retain ownership of all data you enter
                    • Technical data may be collected to improve services
                    • You are responsible for backing up your data
                    
                    For complete details, see our Privacy Policy.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
                
                // Third-Party Services
                EULASection(
                    icon: "link.circle.fill",
                    title: "Third-Party Services",
                    color: .indigo,
                    content: """
                    FLO may include third-party components and services:
                    
                    • Open-source libraries under their respective licenses
                    • Apple iOS terms and conditions apply
                    • Future optional bank linking via Plaid (secure platform)
                    
                    Third-party services are provided "as is" and we are not responsible for their content, accuracy, or availability.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
                
                // Disclaimer Banner
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            // v1.1: Decorative
                            .accessibilityHidden(true)
                        Text("Critical Disclaimer")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.red)
                            // v1.1: Header trait
                            .accessibilityAddTraits(.isHeader)
                    }
                    
                    Text("THE SOFTWARE IS PROVIDED \"AS IS\" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. IT IS NOT PROFESSIONAL FINANCIAL, TAX, ACCOUNTING, OR LEGAL ADVICE.")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.red.opacity(0.9))
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                
                // Limitation of Liability
                EULASection(
                    icon: "dollarsign.arrow.circlepath",
                    title: "Limitation of Liability",
                    color: .orange,
                    content: """
                    To the maximum extent permitted by law:
                    
                    • We are not liable for personal injury or any incidental, special, indirect, or consequential damages
                    • This includes loss of profits, loss of data, or business interruption
                    • Our total liability shall not exceed $50.00
                    • Some jurisdictions may not allow these limitations
                    
                    You use the software at your own risk.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
                
                // Termination
                EULASection(
                    icon: "power.circle.fill",
                    title: "Termination",
                    color: .gray,
                    content: """
                    This license is effective until terminated:
                    
                    • You may terminate by deleting the app
                    • We may terminate if you violate this EULA
                    • Rights terminate automatically upon breach
                    • Upon termination, you must delete the software
                    
                    Sections regarding disclaimers, limitations of liability, and indemnification survive termination.
                    """
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.45), value: viewAppeared)
                
                // Key Points Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Points Summary")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        EULAKeyPoint(text: "You must be 18+ to use FLO")
                        EULAKeyPoint(text: "FLO is a tool, not professional advice")
                        EULAKeyPoint(text: "Your data stays on your device")
                        EULAKeyPoint(text: "No warranties are provided")
                        EULAKeyPoint(text: "Consult professionals for tax/financial decisions")
                        EULAKeyPoint(text: "Governed by Kentucky state law")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                
                // Contact Information
                VStack(alignment: .leading, spacing: 8) {
                    Text("Contact Us")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("Questions about this EULA?")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                    
                    Link(destination: URL(string: "mailto:flo.financeapp@gmail.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                // v1.1: Decorative
                                .accessibilityHidden(true)
                            Text("flo.financeapp@gmail.com")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        HapticService.play(.light)
                    })
                    // v1.1: VoiceOver
                    .accessibilityLabel("Email support at flo.financeapp@gmail.com")
                    .accessibilityHint("Double tap to open email")
                    
                    Text("Finch & Poppy Co LLC")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
                
                // Related Documents
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Documents")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    RelatedDocumentLink(
                        icon: "hand.raised.fill",
                        title: "Privacy Policy",
                        url: AppConstants.privacyPolicyURL,
                        color: .blue
                    )
                    
                    RelatedDocumentLink(
                        icon: "doc.text.fill",
                        title: "Terms of Service",
                        url: AppConstants.termsOfServiceURL,
                        color: .green
                    )
                    
                    RelatedDocumentLink(
                        icon: "exclamationmark.triangle.fill",
                        title: "Tax & Legal Disclaimer",
                        url: AppConstants.disclaimerURL,
                        color: .orange
                    )
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
                
                // Online EULA Link
                Link(destination: AppConstants.eulaURL) {
                    HStack {
                        Image(systemName: "safari")
                            // v1.1: Decorative
                            .accessibilityHidden(true)
                        Text("View Full EULA Online")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            // v1.1: Decorative
                            .accessibilityHidden(true)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(10)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    HapticService.play(.light)
                })
                // v1.1: VoiceOver
                .accessibilityLabel("View full End User License Agreement online")
                .accessibilityHint("Double tap to open in Safari")
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 20)
                .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
                
                // Version Info
                Text("FLO v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("EULA")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            // v1.1: Announce screen
            AccessibilityAnnouncement.screenChanged("End User License Agreement")
        }
    }
}

// MARK: - Supporting Views

struct EULASection: View {
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
                    // v1.1: Decorative
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    // v1.1: Header trait
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

struct EULAKeyPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.brandPrimary)
                .padding(.top, 2)
                // v1.1: Decorative
                .accessibilityHidden(true)
            
            Text(text)
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
    }
}

struct RelatedDocumentLink: View {
    let icon: String
    let title: String
    let url: URL
    let color: Color
    
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                    // v1.1: Decorative
                    .accessibilityHidden(true)
                
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // v1.1: Decorative
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
        }
        .simultaneousGesture(TapGesture().onEnded {
            HapticService.play(.light)
        })
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        EULAView()
    }
}
