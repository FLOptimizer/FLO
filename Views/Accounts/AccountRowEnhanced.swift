//  AccountRowEnhanced.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - VoiceOver Audit: Decorative status icons hidden
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - VoiceOver Audit:
//  ✅ ADDED: Star icon (isPrimary) hidden from VoiceOver (accessibilityLabel already says "Primary")
//  ✅ ADDED: Eye slash icon (hidden from dashboard) hidden from VoiceOver (label already says "Hidden from dashboard")
//  ✅ ADDED: Link icon (isLinked) hidden from VoiceOver (label already says "Bank linked")
//  ✅ ADDED: Finance type icon (briefcase/person) hidden from VoiceOver (label already says "Business" or "Personal")
//  ✅ VERIFIED: Main account icon already hidden
//  ✅ VERIFIED: Row already combines children with spoken currency format
//
//  CHANGES v1.1 - Dynamic Type Verification:
//  ✅ FIXED: Account name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Last four digits text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account type text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Credit utilization text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Balance amount text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment status "OVERDUE" badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Payment due "Due in Xd" text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.0:
//  ✅ EXTRACTED: From AccountsView.swift for better architecture
//  ✅ ADDED: Combined VoiceOver label (name, type, balance, status)
//  ✅ ADDED: Credit card utilization spoken for VoiceOver
//  ✅ ADDED: Payment status badges accessible (overdue, due soon)
//  ✅ ADDED: Decorative icons hidden from VoiceOver
//  ✅ ADDED: accessibilityHint for edit/swipe actions
//

import SwiftUI
import SwiftData

struct AccountRowEnhanced: View {
    let account: Account
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Account Icon
            ZStack {
                Circle()
                    .fill(Color(hex: account.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: account.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: account.color))
            }
            // v1.0: Decorative icon hidden
            .accessibilityHidden(true)
            
            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    if account.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    
                    if !account.showOnDashboard {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    
                    if account.isLinked {
                        Image(systemName: "link.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.plaidStatus.color))
                            .accessibilityHidden(true)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: account.financeType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(account.financeType == .business ? Color.businessColor : Color.personalColor)
                        .accessibilityHidden(true)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("**** \(digits)")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(account.accountType.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Credit card utilization gauge
                if account.accountType == .creditCard, let utilization = account.creditUtilization {
                    VStack(alignment: .leading, spacing: 3) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 3)
                                    .fill(utilizationBarColor(utilization))
                                    .frame(width: max(4, geo.size.width * min(utilization / 100, 1.0)), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack(spacing: 0) {
                            Text("\(Int(utilization))% used")
                                .font(.caption2)
                                .foregroundStyle(utilizationBarColor(utilization))
                            Spacer()
                            if let available = account.availableCredit {
                                Text("\(formatCompactBalance(available)) available")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Credit utilization: \(Int(utilization)) percent\(account.availableCredit.map { ", \(formatCompactBalance($0)) available" } ?? "")")
                }
            }
            
            Spacer()
            
            // Balance
            if subscriptionManager.currentTier.hasBalanceTracking {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(account.currentBalance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(balanceColor)
                    
                    if account.accountType == .creditCard && account.currentBalance < 0 {
                        if account.isPaymentOverdue {
                            Text("OVERDUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(4)
                        } else if account.isPaymentDueSoon, let days = account.daysUntilPaymentDue {
                            Text("Due in \(days)d")
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        // v1.0: Combined accessible label for entire row
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accountAccessibilityLabel)
        .accessibilityHint("Double tap to edit. Swipe for more actions.")
    }
    
    // MARK: - Accessibility Label
    
    /// v1.0: Comprehensive VoiceOver label combining all account attributes
    private var accountAccessibilityLabel: String {
        var parts: [String] = [account.name]
        
        parts.append(account.financeType == .business ? "Business" : "Personal")
        parts.append(account.accountType.displayName)
        
        if account.isPrimary { parts.append("Primary") }
        if !account.showOnDashboard { parts.append("Hidden from dashboard") }
        if account.isLinked { parts.append("Bank linked") }
        
        if let digits = account.lastFourDigits, !digits.isEmpty {
            parts.append("ending in \(digits)")
        }
        
        if subscriptionManager.currentTier.hasBalanceTracking {
            parts.append("Balance: \(AccessibilityFormatters.spokenCurrency(account.currentBalance))")
        }
        
        if account.accountType == .creditCard {
            if let utilization = account.creditUtilization {
                parts.append("\(Int(utilization)) percent utilized")
            }
            if account.isPaymentOverdue {
                parts.append("Payment overdue")
            } else if account.isPaymentDueSoon, let days = account.daysUntilPaymentDue {
                parts.append("Payment due in \(days) days")
            }
        }
        
        if !account.isActive { parts.append("Inactive") }
        
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Helpers
    
    private var balanceColor: Color {
        if account.isLiability {
            return account.currentBalance < 0 ? .red : .green
        } else {
            return account.currentBalance >= 0 ? (account.currentBalance > 0 ? .green : .primary) : .red
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    /// Brand-colored utilization bar: teal (low), amber (medium), red (high)
    private func utilizationBarColor(_ utilization: Double) -> Color {
        if utilization <= 30 { return Color.brandPrimary }   // #14B8A6
        if utilization <= 60 { return Color.brandWarning }   // #FBBF24
        return Color.expenseRed                              // #F87171
    }

    private func formatCompactBalance(_ value: Double) -> String {
        if value >= 1000 {
            return "$\(String(format: "%.1f", value / 1000))k"
        }
        return "$\(Int(value))"
    }
}
