//  CardModifiers.swift
//  FLODesignSystem
//
//  Card style modifiers extracted from FLO/Extensions/View+Modifiers.swift.
//  Phase 2 of the FLODesignSystem migration (Build 10).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Card Styles

extension View {

    /// Standard FLO card with dark-mode-aware shadow.
    /// Use for dashboard cards, list items, content containers.
    public func floCard() -> some View {
        self
            .padding()
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .floCardShadow()
    }

    /// Colored card with custom background.
    /// Use for highlighted content, category cards.
    public func floCard(background: Color) -> some View {
        self
            .padding()
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Outline card (no shadow, border only).
    /// Use for selection states, secondary content.
    public func floOutlineCard(borderColor: Color = .secondary.opacity(0.3)) -> some View {
        self
            .padding()
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    /// Grouped card for list sections.
    /// Use inside grouped lists, settings sections.
    public func floGroupedCard() -> some View {
        self
            .padding()
            #if canImport(UIKit)
            .background(Color(.secondarySystemGroupedBackground))
            #else
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Accent-bordered card (brand primary border).
    /// Use for active/selected states, premium features.
    public func floAccentCard() -> some View {
        self
            .padding()
            #if canImport(UIKit)
            .background(Color(.systemBackground))
            #else
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.brandPrimary, lineWidth: 2)
            )
            .floCardShadow()
    }

    /// Dark-mode-aware card shadow.
    /// Light mode: standard black drop shadow.
    /// Dark mode: subtle teal glow + thin border for card separation.
    public func floCardShadow(radius: CGFloat = 8, y: CGFloat = 2) -> some View {
        modifier(FLOCardShadowModifier(radius: radius, y: y))
    }

    /// Liquid Glass effect for small interactive elements (chips, pills, badges).
    /// On iOS/macOS 26+, applies system glass. On older OS, uses material fallback.
    public func floLiquidGlass(in shape: some Shape = Capsule()) -> some View {
        self.modifier(FLOLiquidGlassModifier(shape: AnyShape(shape)))
    }
}

// MARK: - Dark Mode Card Shadow Modifier

/// Dark-mode-aware card shadow modifier.
/// Light mode: standard black shadow for depth and card lift.
/// Dark mode: semantic teal glow + glass border for premium dark canvas feel.
public struct FLOCardShadowModifier: ViewModifier {
    public var radius: CGFloat
    public var y: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    public init(radius: CGFloat = 8, y: CGFloat = 2) {
        self.radius = radius
        self.y = y
    }

    public func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(FLOCanvasColors.cardBorder, lineWidth: 0.5)
                )
                .shadow(color: FLOCanvasColors.semanticGlow, radius: radius, y: 0)
        } else {
            content
                .shadow(color: Color.black.opacity(0.06), radius: radius, y: y)
        }
    }
}

// MARK: - Liquid Glass Modifier (iOS 26+ / macOS 26+)

/// Liquid Glass modifier for small interactive elements (chips, pills).
public struct FLOLiquidGlassModifier: ViewModifier {
    public let shape: AnyShape

    public init(shape: AnyShape) {
        self.shape = shape
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(shape)
        }
    }
}
