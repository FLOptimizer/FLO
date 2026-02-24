//  DashboardEmptyStateCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1 - Dynamic Type Verification:
//  ✅ FIXED: Title text already had lineLimit + minimumScaleFactor (verified)
//  ✅ FIXED: Message text missing lineLimit + minimumScaleFactor
//
//  FEATURES:
//  ✅ Mode-aware empty state messaging
//  ✅ Custom SwiftUI vector illustration
//  ✅ Animated entrance with reduce motion support
//  ✅ Clean, encouraging design
//

import SwiftUI

struct DashboardEmptyStateCard: View {
    let financeMode: FinanceMode
    
    var body: some View {
        VStack(spacing: 16) {
            DashboardIllustration()
            
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(message)
                .font(.subheadline)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        // v1.1: Card accessible
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
    }
    
    private var title: String {
        switch financeMode {
        case .business: return "No Business Transactions"
        case .personal: return "No Personal Transactions"
        case .all: return "No Transactions Yet"
        }
    }
    
    private var message: String {
        switch financeMode {
        case .business: return "Start tracking your business expenses for tax deductions"
        case .personal: return "Add your first personal transaction to track your spending"
        case .all: return "Add your first transaction to get started"
        }
    }
}

// MARK: - Preview

#Preview("Business Empty") {
    DashboardEmptyStateCard(financeMode: .business)
        .padding()
}

#Preview("Personal Empty") {
    DashboardEmptyStateCard(financeMode: .personal)
        .padding()
}

#Preview("All Empty") {
    DashboardEmptyStateCard(financeMode: .all)
        .padding()
}
