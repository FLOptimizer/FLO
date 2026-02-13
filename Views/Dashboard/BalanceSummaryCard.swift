//  BalanceSummaryCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Fixed Business mode: "Net Income" instead of "Business Profit"
//  ✅ Fixed Business mode: "Expenses" instead of "Deductions"
//  ✅ Mode-specific header icons for visual clarity
//
//  FEATURES:
//  ✅ Animated value transitions with contentTransition
//  ✅ Mode-aware color theming
//  ✅ FLOAnimation presets for smooth animations
//  ✅ Full accessibility support
//
//  CHANGES v1.2 - Accessibility Audit:
//  ✅ Header icon hidden from VoiceOver
//  ✅ Header text marked with isHeader trait
//  ✅ Card-level summary element trait
//  ✅ Income/expense direction icons hidden
//  ✅ Mode and timeframe spoken in card context
//  ✅ Net income value uses spoken currency
//

import SwiftUI

struct BalanceSummaryCard: View {
    let income: Double
    let expenses: Double
    let net: Double
    let timeframe: Timeframe
    let financeMode: FinanceMode
    var animated: Bool = true
    
    @State private var displayedNet: Double = 0
    @State private var displayedIncome: Double = 0
    @State private var displayedExpenses: Double = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with mode indicator
            HStack {
                Image(systemName: headerIcon)
                    .font(.title2)
                    .foregroundStyle(modeColor)
                    .accessibilityHidden(true)
                
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(financeMode.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(modeColor)
                    
                    Text(timeframe.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Net Income (Large) with animated value
            VStack(spacing: 4) {
                Text(netLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(displayedNet, format: .currency(code: "USD"))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(displayedNet >= 0 ? Color.incomeGreen : Color.expenseRed)
                    .contentTransition(.numericText(value: displayedNet))
                    .accessibilityLabel("\(netLabel): \(displayedNet, format: .currency(code: "USD"))")
            }
            .padding(.vertical, 8)
            
            // Income & Expenses with animated values
            HStack(spacing: 20) {
                // Income
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.incomeGreen)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(incomeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(displayedIncome, format: .currency(code: "USD"))
                        .font(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.semibold)
                        .contentTransition(.numericText(value: displayedIncome))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(incomeLabel): \(displayedIncome, format: .currency(code: "USD"))")
                
                Divider()
                    .frame(height: 40)
                
                // Expenses
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(Color.expenseRed)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text(expenseLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(displayedExpenses, format: .currency(code: "USD"))
                        .font(.title3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.semibold)
                        .contentTransition(.numericText(value: displayedExpenses))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(expenseLabel): \(displayedExpenses, format: .currency(code: "USD"))")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isSummaryElement)
        .onAppear {
            if animated {
                animateValues()
            } else {
                displayedNet = net
                displayedIncome = income
                displayedExpenses = expenses
            }
        }
        .onChange(of: net) { oldValue, newValue in
            animateValues()
        }
        .onChange(of: animated) { oldValue, newValue in
            if newValue {
                animateValues()
            }
        }
    }
    
    private func animateValues() {
        withAnimation(FLOAnimation.gentle) {
            displayedNet = net
            displayedIncome = income
            displayedExpenses = expenses
        }
    }
    
    private var modeColor: Color {
        financeMode.color
    }
    
    // MARK: - Dynamic Labels (v1.1 Fixed)
    
    private var headerIcon: String {
        switch financeMode {
        case .business: return "briefcase.fill"
        case .personal: return "person.fill"
        case .all: return "chart.bar.fill"
        }
    }
    
    private var headerTitle: String {
        switch financeMode {
        case .business: return "Business Summary"
        case .personal: return "Personal Summary"
        case .all: return "Summary"
        }
    }
    
    private var netLabel: String {
        // v1.1: Always "Net Income" - clearer than "Business Profit"
        "Net Income"
    }
    
    private var incomeLabel: String {
        financeMode == .business ? "Revenue" : "Income"
    }
    
    private var expenseLabel: String {
        // v1.1: Always "Expenses" - "Deductions" was confusing
        // Tax deductions are shown separately on TaxEstimateCard
        "Expenses"
    }
}

// MARK: - Preview

#Preview("Positive Balance") {
    BalanceSummaryCard(
        income: 5000,
        expenses: 1250,
        net: 3750,
        timeframe: .thisMonth,
        financeMode: .all
    )
    .padding()
}

#Preview("Negative Balance") {
    BalanceSummaryCard(
        income: 1000,
        expenses: 2500,
        net: -1500,
        timeframe: .thisMonth,
        financeMode: .personal
    )
    .padding()
}

#Preview("Business Mode") {
    BalanceSummaryCard(
        income: 10000,
        expenses: 3500,
        net: 6500,
        timeframe: .thisYear,
        financeMode: .business
    )
    .padding()
}
