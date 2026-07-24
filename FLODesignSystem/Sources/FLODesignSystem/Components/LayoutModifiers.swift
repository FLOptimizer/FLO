//  LayoutModifiers.swift
//  FLODesignSystem
//
//  Layout helper modifiers extracted from FLO/Extensions/View+Modifiers.swift.
//  Phase 2 of the FLODesignSystem migration (Build 10).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Layout Helpers

extension View {

    /// Centers content both horizontally and vertically.
    /// Use for empty states, loading views.
    public func floCentered() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }

    /// Safe area padding for bottom content.
    /// Use to avoid home indicator overlap.
    public func floSafeArea() -> some View {
        self
            .padding(.horizontal)
            .padding(.bottom, 20)
    }

    /// Standard horizontal padding.
    public func floHorizontalPadding(_ padding: CGFloat = 16) -> some View {
        self.padding(.horizontal, padding)
    }

    /// Standard vertical spacing.
    public func floVerticalSpacing(_ spacing: CGFloat = 12) -> some View {
        self.padding(.vertical, spacing)
    }
}
