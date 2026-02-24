//  DashboardBusinessCards.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  - Card grouped as accessible element with spoken currency
//  - Decorative icon and chevron hidden
//  - Fixed garbled UTF-8
//
//  NOTE: TaxEstimateCard, InvoiceDashboardCard, and MileageDashboardCard
//  are defined in their respective feature files.
//

import SwiftUI

// MARK: - Business Deductions Summary Card

struct BusinessDeductionsSummaryCard: View {
    let deductions: Double
    
    @State private var displayedDeductions: Double = 0
    @State private var appeared = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(Color.businessColor)
                    // v1.1: Decorative
                    .accessibilityHidden(true)
                
                Text("Tax Deductions")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
                
                NavigationLink {
                    ReportsView()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // v1.1: Decorative
                .accessibilityHidden(true)
            }
            
            VStack(spacing: 8) {
                Text("Total Deductions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(displayedDeductions, format: .currency(code: "USD"))
                    // v1.2: Replaced .system(size: 28) with .title2 for Dynamic Type scaling
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.businessColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: displayedDeductions))
                
                Text("Reducing taxable income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        // v1.1: Card accessible
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tax Deductions: \(AccessibilityFormatters.spokenCurrency(deductions)). Reducing taxable income.")
        .accessibilityAddTraits(.isSummaryElement)
        .onAppear {
            withAnimation(FLOAnimation.gentle.delay(0.2)) {
                displayedDeductions = deductions
                appeared = true
            }
        }
        .onChange(of: deductions) { oldValue, newValue in
            withAnimation(FLOAnimation.standard) {
                displayedDeductions = newValue
            }
        }
    }
}

// MARK: - Preview

#Preview("Business Deductions") {
    NavigationStack {
        BusinessDeductionsSummaryCard(deductions: 15750.00)
            .padding()
    }
}

#Preview("Zero Deductions") {
    NavigationStack {
        BusinessDeductionsSummaryCard(deductions: 0)
            .padding()
    }
}
