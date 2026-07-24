//  SmartChip.swift
//  FLODesignSystem
//
//  Contextual information pill showing time-sensitive data.
//  Appears on dashboard and transaction detail.
//  Inspired by Rocket Money's contextual smart chips.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Contextual information pill showing time-sensitive data.
///
/// Usage:
/// ```swift
/// SmartChip(icon: "📅", text: "Q1 taxes due in 12 days")
/// SmartChip(icon: "💰", text: "Payday in 3 days")
/// SmartChip(icon: "⚠️", text: "Dining Out 104% of budget", style: .warning)
/// SmartChip(icon: "checkmark.circle.fill", systemImage: true, text: "All caught up", style: .success)
/// ```
public struct SmartChip: View {
    let icon: String
    let text: String
    let style: ChipStyle
    let systemImage: Bool

    public enum ChipStyle {
        case neutral    // Default — glass background
        case warning    // Yellow tint — budget warnings
        case urgent     // Red tint — overdue, over budget
        case success    // Green tint — positive states
        case info       // Teal tint — informational

        var tintColor: Color {
            switch self {
            case .neutral: return FLOCanvasColors.textSecondary
            case .warning: return FLOSemanticColors.warning
            case .urgent:  return FLOSemanticColors.expense
            case .success: return FLOSemanticColors.income
            case .info:    return FLOSemanticColors.teal
            }
        }

        var backgroundColor: Color {
            switch self {
            case .neutral: return FLOCanvasColors.cardGlass
            case .warning: return FLOSemanticColors.warning.opacity(0.12)
            case .urgent:  return FLOSemanticColors.expense.opacity(0.12)
            case .success: return FLOSemanticColors.income.opacity(0.12)
            case .info:    return FLOSemanticColors.teal.opacity(0.12)
            }
        }

        var borderColor: Color {
            switch self {
            case .neutral: return FLOCanvasColors.cardBorder
            case .warning: return FLOSemanticColors.warning.opacity(0.25)
            case .urgent:  return FLOSemanticColors.expense.opacity(0.25)
            case .success: return FLOSemanticColors.income.opacity(0.25)
            case .info:    return FLOSemanticColors.teal.opacity(0.25)
            }
        }
    }

    public init(
        icon: String,
        text: String,
        style: ChipStyle = .neutral,
        systemImage: Bool = false
    ) {
        self.icon = icon
        self.text = text
        self.style = style
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 6) {
            if systemImage {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.tintColor)
            } else {
                Text(icon)
                    .font(.system(size: 14))
            }

            Text(text)
                .font(FLOTypography.bodySecondary)
                .fontWeight(.medium)
                .foregroundStyle(style == .neutral ? FLOCanvasColors.textPrimary : style.tintColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(style.backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(style.borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#if DEBUG
#Preview("Smart Chips") {
    VStack(alignment: .leading, spacing: 10) {
        SmartChip(icon: "📅", text: "Q1 taxes due in 12 days")
        SmartChip(icon: "💰", text: "Payday in 3 days", style: .info)
        SmartChip(icon: "⚠️", text: "Dining Out 104% of budget", style: .warning)
        SmartChip(icon: "🚨", text: "Invoice #1042 overdue", style: .urgent)
        SmartChip(icon: "checkmark.circle.fill", text: "All budgets on track", style: .success, systemImage: true)
    }
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
