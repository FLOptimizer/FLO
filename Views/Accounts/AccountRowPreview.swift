//  AccountRowPreview.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Extracted from AccountsView.swift + Accessibility Audit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ EXTRACTED: From AccountsView.swift for better architecture
//  ✅ ADDED: Combined VoiceOver label for preview row
//  ✅ ADDED: Decorative icons hidden from VoiceOver
//

import SwiftUI

struct AccountRowPreview: View {
    let name: String
    let accountType: AccountType
    let financeType: Transaction.FinanceType
    let isPrimary: Bool
    let showOnDashboard: Bool
    let balance: Double
    let lastFourDigits: String?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: accountType.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: accountType.icon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: accountType.color))
            }
            // v1.0: Decorative
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(name == "Account Name" ? .secondary : .primary)
                    
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    
                    if !showOnDashboard {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: financeType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(financeType == .business ? Color.businessColor : Color.personalColor)
                    
                    if let digits = lastFourDigits {
                        Text("**** \(digits)")
                    } else {
                        Text(accountType.displayName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if balance != 0 {
                Text(formatCurrency(balance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(balance >= 0 ? .green : .red)
            }
        }
        // v1.0: Combined preview label
        .accessibilityElement(children: .combine)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}
