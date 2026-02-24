//  AccountRowPreview.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - VoiceOver Audit: Decorative status icons hidden
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - VoiceOver Audit:
//  ✅ ADDED: Star icon (isPrimary) hidden from VoiceOver (decorative status indicator)
//  ✅ ADDED: Eye slash icon (showOnDashboard) hidden from VoiceOver (decorative status indicator)
//  ✅ ADDED: Finance type icon (briefcase/person) hidden from VoiceOver (decorative, text describes type)
//  ✅ VERIFIED: Main account icon already hidden
//  ✅ VERIFIED: Row already combines children into single VoiceOver element
//
//  CHANGES v1.1 - Dynamic Type Verification:
//  ✅ FIXED: Account name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Last four digits text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Account type text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Balance amount text missing lineLimit + minimumScaleFactor
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(name == "Account Name" ? .secondary : .primary)
                    
                    if isPrimary {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                    
                    if !showOnDashboard {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: financeType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(financeType == .business ? Color.businessColor : Color.personalColor)
                        .accessibilityHidden(true)
                    
                    if let digits = lastFourDigits {
                        Text("**** \(digits)")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(accountType.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if balance != 0 {
                Text(formatCurrency(balance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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
