//  AccountRowEnhanced.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Extracted from AccountsView.swift + Accessibility Audit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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
                    
                    if account.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    if !account.showOnDashboard {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if account.isLinked {
                        Image(systemName: "link.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.plaidStatus.color))
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: account.financeType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(account.financeType == .business ? Color.businessColor : Color.personalColor)
                    
                    if let digits = account.lastFourDigits, !digits.isEmpty {
                        Text("**** \(digits)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(account.accountType.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Credit card utilization indicator
                if account.accountType == .creditCard, let utilization = account.creditUtilization {
                    HStack(spacing: 4) {
                        ProgressView(value: min(utilization / 100, 1.0))
                            .tint(Color(hex: account.utilizationStatus.color))
                            .frame(width: 60)
                        
                        Text("\(Int(utilization))% used")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.utilizationStatus.color))
                    }
                    // v1.0: Utilization accessible
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Credit utilization: \(Int(utilization)) percent")
                }
            }
            
            Spacer()
            
            // Balance
            if subscriptionManager.currentTier.hasBalanceTracking {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(account.currentBalance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(balanceColor)
                    
                    if account.accountType == .creditCard && account.currentBalance < 0 {
                        if account.isPaymentOverdue {
                            Text("OVERDUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(4)
                        } else if account.isPaymentDueSoon, let days = account.daysUntilPaymentDue {
                            Text("Due in \(days)d")
                                .font(.caption2)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
