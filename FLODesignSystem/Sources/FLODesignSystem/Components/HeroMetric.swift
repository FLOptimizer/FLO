//  HeroMetric.swift
//  FLODesignSystem
//
//  Large financial number display for dashboard and account hero areas.
//  36pt heavy weight, monospaced digits, with subtitle label below.
//  Inspired by Robinhood's bold hero metrics.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Large financial number display for dashboard hero sections.
///
/// Usage:
/// ```swift
/// HeroMetric(amount: 12847.32, subtitle: "Net Cash Flow")
/// HeroMetric(amount: -340.00, subtitle: "This Month", style: .delta)
/// HeroMetric(amount: 52400.00, subtitle: "Net Worth", style: .neutral)
/// ```
public struct HeroMetric: View {
    let amount: Double
    let subtitle: String
    let style: MetricStyle
    let currencySymbol: String

    public enum MetricStyle {
        case auto       // Green for positive, red for negative
        case neutral    // Always primary text color
        case delta      // Shows +/- prefix, colored
        case branded    // Always teal
    }

    public init(
        amount: Double,
        subtitle: String,
        style: MetricStyle = .auto,
        currencySymbol: String = "$"
    ) {
        self.amount = amount
        self.subtitle = subtitle
        self.style = style
        self.currencySymbol = currencySymbol
    }

    private var formattedAmount: String {
        let absAmount = abs(amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: absAmount)) ?? "0.00"

        switch style {
        case .delta:
            let prefix = amount >= 0 ? "+" : "-"
            return "\(prefix)\(currencySymbol)\(formatted)"
        case .auto, .neutral, .branded:
            let prefix = amount < 0 ? "-" : ""
            return "\(prefix)\(currencySymbol)\(formatted)"
        }
    }

    private var amountColor: Color {
        switch style {
        case .auto:
            return amount >= 0 ? FLOSemanticColors.income : FLOSemanticColors.expense
        case .neutral:
            return FLOCanvasColors.textPrimary
        case .delta:
            return amount >= 0 ? FLOSemanticColors.income : FLOSemanticColors.expense
        case .branded:
            return FLOSemanticColors.teal
        }
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(formattedAmount)
                .font(FLOTypography.hero)
                .tracking(-1.5)
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(subtitle)
                .font(FLOTypography.heroSubtitle)
                .foregroundStyle(FLOCanvasColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(subtitle): \(formattedAmount)")
    }
}

#if DEBUG
#Preview("Hero Metrics") {
    VStack(spacing: 24) {
        HeroMetric(amount: 12847.32, subtitle: "Net Cash Flow")
        HeroMetric(amount: -340.00, subtitle: "This Month", style: .delta)
        HeroMetric(amount: 52400.00, subtitle: "Net Worth", style: .neutral)
        HeroMetric(amount: 8750.00, subtitle: "Monthly Revenue", style: .branded)
    }
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
