//  AssistantSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 summary panel for My Assistant tab.
//  Shows quick help and feature description when no conversation is active.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct AssistantSummaryPanel: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandPrimary)
                    Text("My Assistant")
                        .font(.title2.bold())
                }
                .padding(.top)

                Text("On-device AI financial guidance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                // Capabilities
                VStack(alignment: .leading, spacing: 16) {
                    Text("What I Can Help With")
                        .font(.headline)

                    capabilityRow(icon: "dollarsign.circle", title: "Income & Expenses", description: "View totals, trends, and breakdowns")
                    capabilityRow(icon: "building.columns", title: "Tax Estimates", description: "SE tax, deductions, Schedule C overview")
                    capabilityRow(icon: "car", title: "Mileage", description: "Trip summaries and IRS deductions")
                    capabilityRow(icon: "chart.bar", title: "Budgets", description: "Spending vs planned amounts")
                    capabilityRow(icon: "folder", title: "Categories", description: "Business vs personal breakdowns")
                    capabilityRow(icon: "banknote", title: "Accounts", description: "Current balances across all accounts")
                }

                Divider()

                // Disclaimer
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("My Assistant provides data summaries from your FLO records. It is not a tax professional. Always consult a qualified CPA for tax decisions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .cornerRadius(10)
            }
            .padding()
        }
    }

    private func capabilityRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
