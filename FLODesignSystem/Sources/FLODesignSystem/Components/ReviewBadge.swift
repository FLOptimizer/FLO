//  ReviewBadge.swift
//  FLODesignSystem
//
//  "N to review" action badge for the transaction review flow.
//  Displays a count of unreviewed transactions with a tap-to-review CTA.
//  Inspired by YNAB's daily engagement prompts.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Badge showing the count of items needing review, with an action button.
///
/// Usage:
/// ```swift
/// ReviewBadge(count: 5, action: { /* navigate to review */ })
/// ReviewBadge(count: 0) // Shows "All caught up" state
/// ```
public struct ReviewBadge: View {
    let count: Int
    let action: (() -> Void)?

    public init(count: Int, action: (() -> Void)? = nil) {
        self.count = count
        self.action = action
    }

    private var isAllCaughtUp: Bool {
        count <= 0
    }

    public var body: some View {
        if let action {
            Button(action: action) {
                badgeContent
            }
            .buttonStyle(FLOButtonStyle())
        } else {
            badgeContent
        }
    }

    private var badgeContent: some View {
        HStack(spacing: 8) {
            // Count circle or checkmark
            if isAllCaughtUp {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FLOSemanticColors.income)
            } else {
                Text("\(count)")
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(FLOSemanticColors.teal)
                    .clipShape(Circle())
            }

            // Label text
            VStack(alignment: .leading, spacing: 1) {
                Text(isAllCaughtUp ? "All caught up" : "Mark \(count) as reviewed")
                    .font(FLOTypography.body)
                    .foregroundStyle(FLOCanvasColors.textPrimary)

                if !isAllCaughtUp {
                    Text("Tap to review transactions")
                        .font(FLOTypography.bodySecondary)
                        .foregroundStyle(FLOCanvasColors.textTertiary)
                }
            }

            Spacer()

            // Chevron (only when actionable)
            if !isAllCaughtUp && action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FLOCanvasColors.textTertiary)
            }
        }
        .padding(.horizontal, FLOSpacing.md)
        .padding(.vertical, FLOSpacing.sm)
        .background(
            isAllCaughtUp
                ? FLOSemanticColors.income.opacity(0.08)
                : FLOSemanticColors.teal.opacity(0.08)
        )
        .clipShape(RoundedRectangle(cornerRadius: FLOSpacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FLOSpacing.cardRadius)
                .strokeBorder(
                    isAllCaughtUp
                        ? FLOSemanticColors.income.opacity(0.2)
                        : FLOSemanticColors.teal.opacity(0.2),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isAllCaughtUp ? "All transactions reviewed" : "\(count) transactions to review")
        .accessibilityHint(isAllCaughtUp ? "" : "Double tap to review")
        .accessibilityAddTraits(action != nil && !isAllCaughtUp ? .isButton : [])
    }
}

/// Compact inline badge showing just the count (for use in list rows, headers).
///
/// Usage:
/// ```swift
/// HStack {
///     Text("Transactions")
///     ReviewCountBadge(count: 5)
/// }
/// ```
public struct ReviewCountBadge: View {
    let count: Int

    public init(count: Int) {
        self.count = count
    }

    public var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(FLOSemanticColors.teal)
                .clipShape(Capsule())
                .accessibilityLabel("\(count) to review")
        }
    }
}

#if DEBUG
#Preview("Review Badges") {
    VStack(spacing: 16) {
        ReviewBadge(count: 5, action: {})
        ReviewBadge(count: 1, action: {})
        ReviewBadge(count: 0)

        HStack {
            Text("Transactions")
                .foregroundStyle(.white)
            ReviewCountBadge(count: 5)
        }
    }
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
