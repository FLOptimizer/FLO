//  BudgetCircle.swift
//  FLODesignSystem
//
//  Circular progress indicator replacing horizontal budget bars.
//  Shows category emoji in center, spent/budget below.
//  Inspired by Copilot Money's budget circles.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Circular progress indicator for budget tracking.
///
/// Usage:
/// ```swift
/// BudgetCircle(
///     emoji: "🥬",
///     name: "Groceries",
///     spent: 487,
///     budget: 600
/// )
/// ```
public struct BudgetCircle: View {
    let emoji: String
    let sfSymbol: String?
    let name: String
    let spent: Double
    let budget: Double
    let size: CircleSize

    public enum CircleSize {
        case standard   // 60pt — grid view
        case large      // 120pt — detail view

        var diameter: CGFloat {
            switch self {
            case .standard: return FLOSpacing.budgetCircleSize
            case .large:    return FLOSpacing.budgetCircleLarge
            }
        }

        var strokeWidth: CGFloat {
            switch self {
            case .standard: return FLOSpacing.budgetCircleStroke
            case .large:    return 10
            }
        }

        var emojiSize: CGFloat {
            switch self {
            case .standard: return 24
            case .large:    return 40
            }
        }
    }

    public init(
        emoji: String = "",
        sfSymbol: String? = nil,
        name: String,
        spent: Double,
        budget: Double,
        size: CircleSize = .standard
    ) {
        self.emoji = emoji
        self.sfSymbol = sfSymbol
        self.name = name
        self.spent = spent
        self.budget = budget
        self.size = size
    }

    private var progress: Double {
        guard budget > 0 else { return 0 }
        return min(spent / budget, 1.5) // Cap at 150% for visual
    }

    private var status: BudgetStatus {
        BudgetStatus.from(spent: spent, budget: budget)
    }

    private var ringColor: Color {
        status.color
    }

    public var body: some View {
        VStack(spacing: size == .large ? 12 : 6) {
            ZStack {
                // Background track
                Circle()
                    .stroke(
                        FLOCanvasColors.cardBorder,
                        lineWidth: size.strokeWidth
                    )

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(
                        ringColor,
                        style: StrokeStyle(
                            lineWidth: size.strokeWidth,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(FLOAnimation.standard, value: progress)

                // Over-budget overlay (subtle red ring beyond 100%)
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0, to: progress - 1.0)
                        .stroke(
                            FLOSemanticColors.expense.opacity(0.5),
                            style: StrokeStyle(
                                lineWidth: size.strokeWidth * 0.6,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                }

                // Center icon
                if let sfSymbol, !sfSymbol.isEmpty {
                    Image(systemName: sfSymbol)
                        .font(.system(size: size.emojiSize * 0.85, weight: .medium))
                        .foregroundStyle(ringColor)
                } else {
                    Text(emoji)
                        .font(.system(size: size.emojiSize))
                }
            }
            .frame(width: size.diameter, height: size.diameter)
            .overlay(alignment: .topTrailing) {
                if status == .onTarget {
                    onTargetBadge
                }
            }

            // Labels below
            VStack(spacing: 2) {
                Text(name)
                    .font(size == .large ? FLOTypography.body : FLOTypography.bodySecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(FLOCanvasColors.textSecondary)
                    .lineLimit(1)

                Text(amountText)
                    .font(size == .large ? FLOTypography.financialNumber : .system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(FLOCanvasColors.textPrimary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) budget")
        .accessibilityValue("\(formattedSpent) of \(formattedBudget) spent, \(statusDescription)")
    }

    private var amountText: String {
        "$\(Int(spent)) / $\(Int(budget))"
    }

    private var formattedSpent: String {
        "$\(Int(spent))"
    }

    private var formattedBudget: String {
        "$\(Int(budget))"
    }

    private var statusDescription: String {
        let percentage = budget > 0 ? Int((spent / budget) * 100) : 0
        switch status {
        case .good:     return "\(percentage)% used"
        case .moderate: return "\(percentage)% used, over halfway"
        case .warning:  return "\(percentage)% used, approaching limit"
        case .onTarget: return "exactly on budget"
        case .over:     return "\(percentage)% used, over budget"
        }
    }

    /// Small checkmark badge nested at the top-right of the ring when a
    /// budget is exactly on target. Punches through the ring with a canvas-
    /// colored background so it reads as an award pinned to the circle.
    private var onTargetBadge: some View {
        let badgeDiameter = size.diameter * 0.34
        let cutoutDiameter = badgeDiameter + 4
        return ZStack {
            Circle()
                .fill(FLOCanvasColors.canvas)
                .frame(width: cutoutDiameter, height: cutoutDiameter)
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(.white, FLOSemanticColors.tealDark)
                .frame(width: badgeDiameter, height: badgeDiameter)
        }
        .offset(x: badgeDiameter * 0.25, y: -badgeDiameter * 0.25)
        .accessibilityHidden(true)
    }
}

/// 5-tier traffic-light system for budget health.
///
/// | Tier        | Range          | Color        | Signal                              |
/// |-------------|----------------|--------------|-------------------------------------|
/// | `.good`     | 0–59 %         | Green        | On track, positive reinforcement    |
/// | `.moderate` | 60–79 %        | Gold / Amber | Gentle heads-up                     |
/// | `.warning`  | 80–<100 %      | Orange       | Caution — approaching limit         |
/// | `.onTarget` | exactly 100 %  | Deep teal    | Goal hit — spent the planned amount |
/// | `.over`     | >100 %         | Red          | Action needed                       |
///
/// `.onTarget` treats being penny-exact as a *win*, not a failure. Use
/// `from(spent:budget:)` at rendering sites so the "at target" window is
/// measured in cents (±$0.005), not percentage points — a $0.01 overrun on a
/// $10,000 budget rounds to 100.0 % but is still clearly over.
public enum BudgetStatus: Sendable {
    case good       // 0–59%
    case moderate   // 60–79%
    case warning    // 80–<100%
    case onTarget   // exactly 100% (within half-penny tolerance)
    case over       // >100%

    /// Penny-precise factory. Preferred at rendering sites that have both
    /// spent and budget available — the onTarget window is cent-level, not
    /// percentage-level, so it stays accurate across tiny and huge budgets.
    public static func from(spent: Double, budget: Double) -> BudgetStatus {
        guard budget > 0 else { return .good }
        let epsilon = 0.005  // half-penny — guards against floating-point drift
        if spent > budget + epsilon { return .over }
        if spent >= budget - epsilon { return .onTarget }
        return from(percentage: (spent / budget) * 100)
    }

    /// Percentage-based factory. Kept for callers that only have a pre-computed
    /// percentage on hand. Treats anything in [99.995, 100.005] as onTarget so
    /// the edge still lines up with `from(spent:budget:)` when both paths exist.
    public static func from(percentage: Double) -> BudgetStatus {
        switch percentage {
        case ..<60:    return .good
        case ..<80:    return .moderate
        case ..<99.995: return .warning
        case ...100.005: return .onTarget
        default:       return .over
        }
    }

    /// Semantic color for this status tier.
    public var color: Color {
        switch self {
        case .good:     return FLOSemanticColors.income      // Green
        case .moderate: return FLOSemanticColors.warning     // Gold / Amber
        case .warning:  return Color(hex: "F97316")          // Orange
        case .onTarget: return FLOSemanticColors.tealDark    // Deep teal — "goal hit"
        case .over:     return FLOSemanticColors.expense     // Red
        }
    }
}

#if DEBUG
#Preview("Budget Circles") {
    HStack(spacing: 20) {
        BudgetCircle(emoji: "🥬", name: "Groceries", spent: 340, budget: 600)
        BudgetCircle(emoji: "🍽️", name: "Dining", spent: 480, budget: 500)
        BudgetCircle(emoji: "☕", name: "Coffee", spent: 65, budget: 50)
        BudgetCircle(emoji: "🎮", name: "Fun", spent: 120, budget: 300)
    }
    .padding()
    .background(Color(hex: "07070D"))
}

#Preview("Large Budget Circle") {
    BudgetCircle(emoji: "🥬", name: "Groceries", spent: 487, budget: 600, size: .large)
        .padding()
        .background(Color(hex: "07070D"))
}
#endif
