//  SummaryComponents.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Shared components for Zone 3 summary panels.
//  Lightweight inline versions of design system components
//  until FLODesignSystem is linked as a target dependency.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Summary Hero Metric

/// Large financial number display for summary panels.
struct SummaryHeroMetric: View {
    let amount: Double
    let subtitle: String
    var style: MetricStyle = .auto

    enum MetricStyle {
        case auto       // Green for positive, red for negative
        case neutral    // Primary text color
        case delta      // Shows +/- prefix, colored
        case branded    // Always teal
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(formattedAmount)
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .tracking(-1.5)
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subtitle): \(formattedAmount)")
    }

    private var formattedAmount: String {
        let formatted = abs(amount).formatted(.currency(code: "USD").precision(.fractionLength(2)))
        switch style {
        case .delta:
            return amount >= 0 ? "+\(formatted)" : "-\(formatted)"
        default:
            return amount < 0 ? "-\(formatted)" : formatted
        }
    }

    private var amountColor: Color {
        switch style {
        case .auto:
            return amount >= 0 ? Color.incomeGreen : Color.expenseRed
        case .neutral:
            return .primary
        case .delta:
            return amount >= 0 ? Color.incomeGreen : Color.expenseRed
        case .branded:
            return Color.brandPrimary
        }
    }
}

// MARK: - Summary Chip

/// Small pill-shaped alert indicator for summary panels.
struct SummaryChip: View {
    let icon: String
    let text: String
    var style: ChipStyle = .neutral

    enum ChipStyle {
        case neutral, warning, urgent, success, info
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }

    private var foregroundColor: Color {
        switch style {
        case .neutral: return .secondary
        case .warning: return Color.brandWarning
        case .urgent: return Color.expenseRed
        case .success: return Color.incomeGreen
        case .info: return Color.brandPrimary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

