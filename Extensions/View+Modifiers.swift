//  View_Modifiers.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2 — Catalyst floMacSheetFrame parity (Build 10 Phase 2)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.1 - Design System Phase 2:
//  ✅ MOVED to FLODesignSystem: floCard*, floOutlineCard, floGroupedCard, floAccentCard
//  ✅ MOVED to FLODesignSystem: floCardShadow, FLOCardShadowModifier
//  ✅ MOVED to FLODesignSystem: floLiquidGlass, FLOLiquidGlassModifier
//  ✅ MOVED to FLODesignSystem: floPrimaryButton, floSecondaryButton, floDestructiveButton
//  ✅ MOVED to FLODesignSystem: floPillButton, floOutlinePillButton, floIconButton
//  ✅ MOVED to FLODesignSystem: floFullWidth, floCentered, floSafeArea
//  ✅ MOVED to FLODesignSystem: floHorizontalPadding, floVerticalSpacing
//  ✅ MOVED to FLODesignSystem: floDisabled, floLoading, floPressable, floEmptyState
//  ✅ MOVED to FLODesignSystem: floAccessibleButton, floAccessibleCard, floAccessibilityHidden
//  ✅ KEPT: floCanvasBackground, floColumnBackground (reference app-only Color.floCanvas)
//  ✅ KEPT: floLargeTitle, floCaption, floBadge, floStatusDot
//  ✅ KEPT: floIf, floIfLet, legacy modifiers, macOS compatibility stubs
//
//  PURPOSE:
//  App-specific modifiers and cross-platform compatibility shims.
//  General-purpose modifiers live in FLODesignSystem package.
//
//  NOTE: General-purpose modifiers (cards, buttons, layout, states, accessibility)
//  are now in FLODesignSystem — import FLODesignSystem to use them.
//

import SwiftUI

// MARK: - App-Specific Canvas Backgrounds

extension View {

    /// Premium canvas background for full-screen views.
    /// Dark mode: deep #07070D canvas. Light mode: system background.
    func floCanvasBackground() -> some View {
        self.background(Color.floCanvas)
    }

    /// Unified column background for Zone 2 (content) and Zone 3 (detail) columns.
    /// Ensures both columns share the same canvas background regardless of content.
    func floColumnBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.floCanvas)
    }
}

// MARK: - Text Styles

extension View {

    /// Large title style.
    /// Use for screen titles, hero text.
    func floLargeTitle() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.bold)
    }

    /// Caption/helper text.
    /// Use for descriptions, timestamps, hints.
    func floCaption() -> some View {
        self
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Badge Modifiers

extension View {

    /// Notification badge overlay.
    /// Use for unread counts, alerts.
    func floBadge(_ count: Int, color: Color = .red) -> some View {
        self.overlay(alignment: .topTrailing) {
            if count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color)
                    .clipShape(Capsule())
                    .offset(x: 8, y: -8)
            }
        }
    }

    /// Status dot indicator.
    /// Use for online/offline, sync status.
    func floStatusDot(color: Color, size: CGFloat = 8) -> some View {
        self.overlay(alignment: .topTrailing) {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .offset(x: 2, y: -2)
        }
    }
}

// MARK: - Conditional Modifiers

extension View {

    /// Apply modifier conditionally.
    @ViewBuilder
    func floIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Apply modifier based on optional value.
    @ViewBuilder
    func floIfLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Legacy Modifiers (Backward Compatibility)

extension View {
    /// Legacy card modifier - use floCard() from FLODesignSystem for new code
    func appCard() -> some View {
        self
            .padding()
            .background(Color.floSystemBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    /// Legacy section header - use floSectionHeader() for new code
    func sectionHeader() -> some View {
        self
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    /// Legacy large button - use floPrimaryButton() from FLODesignSystem for new code
    func largeButton() -> some View {
        self
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Sheet Sizing

extension View {
    /// Applies a sensible default frame for sheets presented on macOS, where sheets
    /// don't auto-size to their content like they do on iOS. Without this, Form-based
    /// sheets render in a too-small frame causing labels to right-align in empty space
    /// and inputs to collapse to zero width. No-op on iOS.
    func floMacSheetFrame(minWidth: CGFloat = 560, minHeight: CGFloat = 640) -> some View {
        // Catalyst sheets share the macOS "no auto-size to content" behavior, so
        // they need the same minimum frame. Without it, Form-based sheets render
        // too small (labels right-align in empty space). No-op on iPhone/iPad.
        #if os(macOS) || targetEnvironment(macCatalyst)
        return self.frame(minWidth: minWidth, minHeight: minHeight)
        #else
        return self
        #endif
    }
}

// MARK: - Cross-Platform Compatibility Modifiers

#if os(macOS)
/// Stub enum matching UIKit's NavigationBarItem.TitleDisplayMode for cross-platform compilation
enum NavigationBarTitleDisplayMode {
    case automatic, inline, large
}

/// Stub enum matching UIKit's UIKeyboardType for cross-platform compilation
enum UIKeyboardType: Int {
    case `default` = 0, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad
}

/// Stub enum matching UIKit's TextInputAutocapitalization for cross-platform compilation
enum TextInputAutocapitalization {
    case never, words, sentences, characters
}

/// Stub enum matching UIKit's UITextAutocapitalizationType for cross-platform compilation
enum UITextAutocapitalizationType: Int {
    case none = 0, words, sentences, allCharacters
}

extension View {
    /// No-op on macOS where navigationBarTitleDisplayMode is unavailable
    func navigationBarTitleDisplayMode(_ mode: NavigationBarTitleDisplayMode) -> some View {
        self
    }

    /// No-op on macOS where keyboardType is unavailable
    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    /// No-op on macOS where textInputAutocapitalization is unavailable
    func textInputAutocapitalization(_ style: TextInputAutocapitalization?) -> some View {
        self
    }

    /// No-op on macOS where autocapitalization is unavailable (UIKit legacy)
    func autocapitalization(_ style: UITextAutocapitalizationType) -> some View {
        self
    }
}

extension ToolbarItemPlacement {
    /// macOS equivalent for topBarTrailing
    static var topBarTrailing: ToolbarItemPlacement { .automatic }
    /// macOS equivalent for topBarLeading
    static var topBarLeading: ToolbarItemPlacement { .automatic }
    /// macOS equivalent for navigationBarTrailing
    static var navigationBarTrailing: ToolbarItemPlacement { .automatic }
    /// macOS equivalent for navigationBarLeading
    static var navigationBarLeading: ToolbarItemPlacement { .automatic }
}

import SwiftUI
#endif
