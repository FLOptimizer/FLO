//  TaxEstimateView.swift (Watch)
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Tax Estimate for Apple Watch
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  FEATURE GATING:
//  Premium+ required. Free tier sees upgrade prompt.
//
//  Shows current quarterly estimate, days until deadline,
//  and YTD income/deduction summary. Read-only — all
//  calculation happens on iPhone.
//

import SwiftUI

struct TaxEstimateView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    
    private var tier: WatchSubscriptionTier {
        session.currentTier
    }
    
    private var tax: WatchTaxEstimate? {
        session.snapshot?.taxEstimate
    }
    
    var body: some View {
        if tier.hasTaxEstimate {
            taxContent
        } else {
            WatchUpgradePrompt(
                featureName: "Tax Estimates",
                icon: "building.columns.fill"
            )
        }
    }
    
    // MARK: - Tax Content
    
    private var taxContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(.blue)
                    Text("Taxes")
                        .font(.headline)
                }
                
                if let tax = tax {
                    // Quarterly payment (hero number)
                    VStack(spacing: 2) {
                        Text("Quarterly Estimate")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(tax.formattedQuarterlyPayment)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                    }
                    
                    // Deadline countdown
                    if let days = tax.daysUntilDeadline, let deadline = tax.nextDeadline {
                        deadlineView(days: days, deadline: deadline)
                    }
                    
                    Divider().padding(.horizontal, 8)
                    
                    // YTD stats
                    VStack(spacing: 6) {
                        statRow(label: "YTD Income", value: formatCurrency(tax.ytdIncome), color: .green)
                        statRow(label: "YTD Deductions", value: formatCurrency(tax.ytdDeductions), color: .orange)
                        statRow(label: "Effective Rate", value: String(format: "%.1f%%", tax.effectiveTaxRate * 100), color: .secondary)
                    }
                    
                    // Withholding note
                    if tax.quarterlyPayment != tax.adjustedQuarterlyPayment {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 9))
                            Text("Adjusted for W-2 withholding")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    }
                    
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("No tax data yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Add income transactions\non your iPhone")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Deadline View
    
    private func deadlineView(days: Int, deadline: Date) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: days <= 7 ? "exclamationmark.triangle.fill" : "calendar")
                    .font(.caption2)
                    .foregroundColor(deadlineColor(days: days))
                
                Text(deadlineText(days: days))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(deadlineColor(days: days))
            }
            
            Text(deadline, style: .date)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(deadlineColor(days: days).opacity(0.1))
        .cornerRadius(8)
    }
    
    private func deadlineText(days: Int) -> String {
        if days <= 0 {
            return "Due Today!"
        } else if days == 1 {
            return "Due Tomorrow"
        } else {
            return "\(days) Days Left"
        }
    }
    
    private func deadlineColor(days: Int) -> Color {
        if days <= 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 14 { return .yellow }
        return .green
    }
    
    // MARK: - Stat Row
    
    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Formatter
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

#Preview {
    TaxEstimateView()
        .environmentObject(WatchSessionManager.shared)
}
