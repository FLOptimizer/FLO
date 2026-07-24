//  ButtonModifiers.swift
//  FLODesignSystem
//
//  Button style modifiers extracted from FLO/Extensions/View+Modifiers.swift.
//  Phase 2 of the FLODesignSystem migration (Build 10).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Button Styles

extension View {

    /// Primary action button (brand primary background).
    /// Use for main CTAs: Save, Continue, Add.
    public func floPrimaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Secondary action button (brand tint, no fill).
    /// Use for secondary actions: Cancel, Edit, View All.
    public func floSecondaryButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.brandPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Destructive button (red).
    /// Use for delete, remove, cancel subscription.
    public func floDestructiveButton() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Small pill button.
    /// Use for tags, filters, quick actions.
    public func floPillButton(color: Color = .brandPrimary) -> some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color)
            .clipShape(Capsule())
    }

    /// Outline pill button.
    /// Use for filter chips, toggleable options.
    public func floOutlinePillButton(color: Color = .brandPrimary, isSelected: Bool = false) -> some View {
        self
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color, lineWidth: 1.5)
            )
    }

    /// Icon button with circle background.
    /// Use for toolbar actions, floating buttons.
    public func floIconButton(color: Color = .brandPrimary, size: CGFloat = 44) -> some View {
        self
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}
