//  TaxDisclaimerView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - In-App Tax and Financial Disclaimer
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Displays comprehensive tax and financial disclaimers within the app
//  Provides link to full online version

import SwiftUI

struct TaxDisclaimerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Important Disclaimer")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Please read carefully")
                                .font(.subheadline)
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
                        .foregroundStyle(.primary)
                    
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
                        .foregroundStyle(.red)
                    
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
                        .foregroundStyle(.primary)
                    
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
                        Text("View Full Disclaimer Online")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                
                // Version Info
                Text("FLO v\(AppConstants.appVersion) (\(AppConstants.buildNumber))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Tax & Legal Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
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
                
                Text(title)
                    .font(.headline)
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
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
