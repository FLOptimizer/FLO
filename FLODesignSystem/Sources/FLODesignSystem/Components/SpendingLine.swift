//  SpendingLine.swift
//  FLODesignSystem
//
//  Gradient trend line chart for the dashboard hero area.
//  Shows spending trajectory with a dashed budget threshold
//  and an under/over budget badge.
//  Inspired by Copilot Money's spending trend visualization.
//
//  Version 1.1 — Fix squashed-flat trend line when budget >> spending.
//  ✅ FIXED: maxValue now scales to the DATA, not max(data, budget). When the budget
//           threshold dwarfed actual spending (e.g. the per-day budget on the
//           "This Month" hero chart) the trend line collapsed onto the bottom edge
//           and the chart looked empty. The budget line is now clamped into view.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Gradient trend line chart showing spending over time with a budget threshold.
///
/// Usage:
/// ```swift
/// SpendingLine(
///     data: [320, 580, 940, 1200, 1680, 2100, 2450],
///     budget: 2800,
///     periodLabel: "This Month"
/// )
/// ```
public struct SpendingLine: View {
    let data: [Double]
    let budget: Double
    let periodLabel: String

    public init(data: [Double], budget: Double, periodLabel: String = "This Month") {
        self.data = data
        self.budget = budget
        self.periodLabel = periodLabel
    }

    private var currentSpend: Double {
        data.last ?? 0
    }

    private var isUnderBudget: Bool {
        currentSpend <= budget
    }

    private var difference: Double {
        abs(budget - currentSpend)
    }

    private var maxValue: Double {
        // Scale to the DATA so the spend trend is always visible. Previously this was
        // max(dataMax, budget) — when the budget threshold dwarfed actual spending
        // (e.g. the per-day budget on the "This Month" hero chart) the trend line got
        // squashed flat against the bottom and the chart looked empty. The budget
        // line is clamped into view separately in chartView.
        max(data.max() ?? 0, 1) * 1.15 // 15% headroom
    }

    public var body: some View {
        VStack(spacing: FLOSpacing.xs) {
            // Chart area
            chartView
                .frame(height: 120)
                .clipped()

            // Under/over badge
            budgetBadge
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending trend for \(periodLabel)")
        .accessibilityValue(badgeText)
    }

    // MARK: - Chart

    private var chartView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .topLeading) {
                // Budget threshold line (dashed)
                if budget > 0 && maxValue > 0 {
                    // Clamp into view: when the budget exceeds peak spending the line
                    // pins to the top edge instead of disappearing above the chart.
                    let budgetY = min(height, max(0, height - (budget / maxValue) * height))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: budgetY))
                        path.addLine(to: CGPoint(x: width, y: budgetY))
                    }
                    .stroke(
                        FLOCanvasColors.textTertiary,
                        style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                    )
                }

                // Gradient fill under line
                if data.count >= 2 {
                    gradientFill(in: geometry)
                    trendLine(in: geometry)
                }

                // Data points
                if data.count >= 2 {
                    dataPoints(in: geometry)
                }
            }
        }
    }

    private func trendLine(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        return Path { path in
            for (index, value) in data.enumerated() {
                let x = data.count > 1 ? width * CGFloat(index) / CGFloat(data.count - 1) : 0
                let y = maxValue > 0 ? height - (value / maxValue) * height : height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    // Smooth curve using quadratic bezier
                    let prevIndex = index - 1
                    let prevX = width * CGFloat(prevIndex) / CGFloat(data.count - 1)
                    let prevY = maxValue > 0 ? height - (data[prevIndex] / maxValue) * height : height
                    let midX = (prevX + x) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: midX, y: prevY),
                        control2: CGPoint(x: midX, y: y)
                    )
                }
            }
        }
        .stroke(
            FLOSemanticColors.teal,
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
    }

    private func gradientFill(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        return Path { path in
            // Start from bottom-left
            path.move(to: CGPoint(x: 0, y: height))

            // Draw up to the line
            for (index, value) in data.enumerated() {
                let x = data.count > 1 ? width * CGFloat(index) / CGFloat(data.count - 1) : 0
                let y = maxValue > 0 ? height - (value / maxValue) * height : height
                if index == 0 {
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    let prevIndex = index - 1
                    let prevX = width * CGFloat(prevIndex) / CGFloat(data.count - 1)
                    let prevY = maxValue > 0 ? height - (data[prevIndex] / maxValue) * height : height
                    let midX = (prevX + x) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: midX, y: prevY),
                        control2: CGPoint(x: midX, y: y)
                    )
                }
            }

            // Close back to bottom-right, then bottom-left
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(
                colors: [
                    FLOSemanticColors.teal.opacity(0.3),
                    FLOSemanticColors.teal.opacity(0.05),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func dataPoints(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width
        let height = geometry.size.height

        return ZStack {
            // Only show the last (current) data point
            if let lastValue = data.last {
                let lastIndex = data.count - 1
                let x = data.count > 1 ? width * CGFloat(lastIndex) / CGFloat(data.count - 1) : 0
                let y = maxValue > 0 ? height - (lastValue / maxValue) * height : height

                Circle()
                    .fill(FLOSemanticColors.teal)
                    .frame(width: 8, height: 8)
                    .shadow(color: FLOSemanticColors.teal.opacity(0.5), radius: 4)
                    .position(x: x, y: y)
            }
        }
    }

    // MARK: - Badge

    private var budgetBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: isUnderBudget ? "arrow.down" : "arrow.up")
                .font(.system(size: 10, weight: .bold))

            Text(badgeText)
                .font(FLOTypography.badge)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(badgeBackgroundColor)
        .foregroundStyle(badgeForegroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var badgeText: String {
        let formatted = "$\(Int(difference))"
        return isUnderBudget ? "\(formatted) under budget" : "\(formatted) over budget"
    }

    private var badgeBackgroundColor: Color {
        isUnderBudget
            ? FLOSemanticColors.income.opacity(0.15)
            : FLOSemanticColors.expense.opacity(0.15)
    }

    private var badgeForegroundColor: Color {
        isUnderBudget ? FLOSemanticColors.income : FLOSemanticColors.expense
    }
}

#if DEBUG
#Preview("Spending Line — Under Budget") {
    SpendingLine(
        data: [320, 580, 940, 1200, 1680, 2100, 2450],
        budget: 2800,
        periodLabel: "March 2026"
    )
    .padding()
    .background(Color(hex: "07070D"))
}

#Preview("Spending Line — Over Budget") {
    SpendingLine(
        data: [400, 900, 1500, 2200, 2900, 3400, 3800],
        budget: 3200,
        periodLabel: "March 2026"
    )
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
