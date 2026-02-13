//  DashboardEmptyStateCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Mode-aware empty state messaging
//  ✅ Animated icon bounce effect
//  ✅ Clean, encouraging design
//

import SwiftUI

struct DashboardEmptyStateCard: View {
    let financeMode: FinanceMode
    
    @State private var iconBounce = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .symbolEffect(.bounce, value: iconBounce)
                // v1.1: Decorative
                .accessibilityHidden(true)
            
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        // v1.1: Card accessible
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                iconBounce = true
            }
        }
    }
    
    private var icon: String {
        switch financeMode {
        case .business: return "briefcase"
        case .personal: return "person"
        case .all: return "tray"
        }
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
