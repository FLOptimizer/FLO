//  GenericSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 fallback summary for tabs without a dedicated panel.
//  Shows the tab icon and a contextual message.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct GenericSummaryPanel: View {
    let tab: AppTab

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: tab.icon)
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(Color.brandPrimary.opacity(0.6))

            VStack(spacing: 6) {
                Text(tab.title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text(contextualMessage)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(tab.title) — \(contextualMessage)")
    }

    private var contextualMessage: String {
        switch tab {
        case .mileage:
            return "Track your business miles and calculate deductions automatically."
        case .receipts:
            return "Scan, store, and match receipts to transactions."
        case .reports:
            return "Generate financial reports and visualize trends."
        case .tax:
            return "Review tax deductions, estimates, and year-end preparation."
        case .settings:
            return "Manage categories, accounts, security, and app preferences."
        case .clients:
            return "View client details, invoices, and payment history."
        default:
            return "Select an item from the list to view details here."
        }
    }
}

#if DEBUG
#Preview("Generic - Mileage") {
    GenericSummaryPanel(tab: .mileage)
}
#Preview("Generic - Reports") {
    GenericSummaryPanel(tab: .reports)
}
#endif
