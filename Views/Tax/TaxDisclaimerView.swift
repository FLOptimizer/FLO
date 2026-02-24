//  TaxDisclaimerView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: "Important Disclaimer" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Please read carefully" subhead missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DisclaimerSection titles missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Your Responsibilities" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Limitation of Liability" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "We Recommend Working With:" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ProfessionalRecommendation titles missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ProfessionalRecommendation descriptions missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "View Full Disclaimer Online" link text missing lineLimit + minimumScaleFactor
//  ℹ️ NOTE: Long-form disclaimer body text left without lineLimit per legal text policy
//
//  CHANGES v1.1:
//  ✅ Added hidden debug menu access (DEBUG builds only)
//  ✅ Triple-tap on version info reveals debug menu
//  ✅ Counter resets after 2 seconds of inactivity
//
//  Displays comprehensive tax and financial disclaimers within the app
//  Provides link to full online version

import SwiftUI

struct TaxDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Debug menu access (triple-tap on version)
    #if DEBUG
    @State private var tapCount = 0
    @State private var showingDebugMenu = false
    @State private var lastTapTime = Date()
    #endif
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text("Important Disclaimer")
                                .font(.title2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            
                            Text("Please read carefully")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    Text("FLO is a financial tracking tool, not a substitute for professional tax, accounting, or legal advice.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Main Disclaimers
                DisclaimerSection(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Tax Estimates",
                    color: .blue,
                    content: """
                    Tax estimates provided by FLO are for informational and planning purposes only. These estimates:
                    
                    • Are based on generalized federal and state tax rates
                    • May not reflect your specific tax situation
                    • Do not account for all possible deductions or credits
                    • May become outdated as tax laws change
                    • Should NEVER be used as the basis for official tax filings
                    
                    Always consult with a qualified tax professional (CPA, EA, or tax attorney) before filing taxes or making financial decisions.
                    """
                )
                
                DisclaimerSection(
                    icon: "dollarsign.circle",
                    title: "Financial Calculations",
                    color: .green,
                    content: """
                    FLO uses standard double-precision floating-point arithmetic for calculations. While suitable for general tracking and planning:
                    
                    • Minor rounding differences may occur
                    • All invoice amounts should be verified before sending
                    • Tax calculations should be confirmed by professionals
                    • Not suitable for mission-critical accounting systems
                    
                    For production accounting, migrate to decimal-based systems.
                    """
                )
                
                DisclaimerSection(
                    icon: "map",
                    title: "Mileage Tracking",
                    color: .purple,
                    content: """
                    GPS-based mileage tracking has limitations:
                    
                    • GPS accuracy varies based on signal and conditions
                    • You must verify all mileage calculations
                    • IRS requires contemporaneous records and business purpose documentation
                    • GPS logs alone may not satisfy IRS requirements
                    
                    Review trips promptly and maintain proper documentation.
                    """
                )
                
                DisclaimerSection(
                    icon: "doc.text.image",
                    title: "Receipt Scanning",
                    color: .orange,
                    content: """
                    OCR (Optical Character Recognition) technology has limitations:
                    
                    • Accuracy depends on image quality and receipt legibility
                    • You must review and verify all extracted data
                    • Original receipts should be retained as required by tax law
                    • IRS may require original documentation for certain purchases
                    
                    Never rely on OCR data without verification.
                    """
                )
                
                DisclaimerSection(
                    icon: "doc.plaintext",
                    title: "Invoice Generation",
                    color: .teal,
                    content: """
                    Invoice features are provided for convenience:
                    
                    • You are responsible for invoice accuracy and legal compliance
                    • Some jurisdictions require specific invoice elements
                    • Payment tracking is for your records only
                    • We are not responsible for client disputes or non-payment
                    
                    Consult legal or accounting professionals about invoice requirements in your jurisdiction.
                    """
                )
                
                // Your Responsibility Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Responsibilities")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                        // v1.2: Header trait
                        .accessibilityAddTraits(.isHeader)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ResponsibilityItem(text: "Verify all calculations with qualified professionals before filing taxes")
                        ResponsibilityItem(text: "Ensure compliance with current IRS regulations and state/local tax laws")
                        ResponsibilityItem(text: "Maintain accurate financial records as required by law")
                        ResponsibilityItem(text: "Keep original receipts and documentation")
                        ResponsibilityItem(text: "Consult CPAs, EAs, or tax attorneys for official tax preparation")
                        ResponsibilityItem(text: "Understand that tax laws change frequently")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Limitation of Liability
                VStack(alignment: .leading, spacing: 12) {
                    Text("Limitation of Liability")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.red)
                        // v1.2: Header trait
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Finch & Poppy Co LLC and FLO explicitly disclaim all liability for tax calculation errors, missed deadlines, IRS audits, financial decisions based on app outputs, or any financial losses resulting from use of the app. Our total liability shall not exceed the amount you paid for the app (or $50 if free).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Professional Recommendations
                VStack(alignment: .leading, spacing: 12) {
                    Text("We Recommend Working With:")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                        // v1.2: Header trait
                        .accessibilityAddTraits(.isHeader)
                    
                    ProfessionalRecommendation(
                        icon: "briefcase.fill",
                        title: "Certified Public Accountants (CPAs)",
                        description: "For comprehensive tax preparation, planning, and financial advice"
                    )
                    
                    ProfessionalRecommendation(
                        icon: "person.text.rectangle",
                        title: "Enrolled Agents (EAs)",
                        description: "Federally-licensed tax practitioners who can represent you before the IRS"
                    )
                    
                    ProfessionalRecommendation(
                        icon: "scale.3d",
                        title: "Tax Attorneys",
                        description: "For complex legal tax matters, audits, or disputes"
                    )
                    
                    ProfessionalRecommendation(
                        icon: "chart.bar.fill",
                        title: "Certified Financial Planners (CFPs)",
                        description: "For investment management and retirement planning"
                    )
                }
                
                // Online Disclaimer Link
                Link(destination: AppConstants.disclaimerURL) {
                    HStack {
                        Image(systemName: "safari")
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                        Text("View Full Disclaimer Online")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            // v1.2: Decorative
                            .accessibilityHidden(true)
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                // v1.2: VoiceOver
                .accessibilityLabel("View full disclaimer online")
                .accessibilityHint("Double tap to open in Safari")
                
                // Version Info - Hidden Debug Access
                versionInfoView
            }
            .padding()
        }
        .navigationTitle("Tax & Legal Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // v1.2: Announce screen
            AccessibilityAnnouncement.screenChanged("Tax and Legal Disclaimer")
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView()
        }
        #endif
    }
    
    // MARK: - Version Info View (with hidden debug access)
    
    private var versionInfoView: some View {
        #if DEBUG
        // Debug build - tappable version info
        Text("FLO v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .contentShape(Rectangle())
            .onTapGesture {
                handleDebugTap()
            }
        #else
        // Release build - static version info
        Text("FLO v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
        #endif
    }
    
    // MARK: - Debug Tap Handler
    
    #if DEBUG
    private func handleDebugTap() {
        let now = Date()
        
        // Reset counter if more than 2 seconds since last tap
        if now.timeIntervalSince(lastTapTime) > 2.0 {
            tapCount = 0
        }
        
        lastTapTime = now
        tapCount += 1
        
        // Provide subtle haptic feedback
        if tapCount < 3 {
            HapticService.play(.light)
        }
        
        // Show debug menu on triple-tap
        if tapCount >= 3 {
            HapticService.play(.success)
            tapCount = 0
            showingDebugMenu = true
        }
    }
    #endif
}

// MARK: - Supporting Views

struct DisclaimerSection: View {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

struct ResponsibilityItem: View {
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

struct ProfessionalRecommendation: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
                // v1.2: Decorative
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                
                Text(description)
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TaxDisclaimerView()
    }
}
