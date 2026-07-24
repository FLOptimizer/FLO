//  AccessibilityModifiers.swift
//  FLODesignSystem
//
//  Accessibility helper modifiers extracted from FLO/Extensions/View+Modifiers.swift.
//  Phase 2 of the FLODesignSystem migration (Build 10).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Accessibility Helpers

extension View {

    /// Ensures button meets minimum tap target (44×44 pts).
    /// Use for small interactive elements.
    public func floAccessibleButton() -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Accessible card with combined VoiceOver label.
    /// Groups child elements into a single accessibility element.
    public func floAccessibleCard(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    /// Hides decorative elements from VoiceOver.
    public func floAccessibilityHidden() -> some View {
        self.accessibilityHidden(true)
    }
}
