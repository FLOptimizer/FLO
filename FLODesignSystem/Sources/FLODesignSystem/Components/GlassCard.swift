//  GlassCard.swift
//  FLODesignSystem
//
//  Updated glass card modifier using FLO 3.0 design tokens.
//  Background: cardGlass, border: cardBorder, 14px radius, 20px blur.
//  Adds hover response for macOS and Mac Catalyst (v3.1: .onHover gated on
//  os(macOS) || targetEnvironment(macCatalyst) so cards highlight on Mac cursor).
//
//  Build 10 v3.0 launch: Adds @available(iOS 26.0, macOS 26.0, *) branch that
//  renders Apple's native Liquid Glass via `.glassEffect()`. Older OS keeps
//  the hand-rolled ultraThinMaterial + border treatment unchanged. Every
//  .floGlassCard() call site inherits this automatically (~105 sites).
//
//  Replaces the existing .floGlassCard() from View+Modifiers.swift.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

/// Glass morphism card modifier using FLO 3.0 design tokens.
///
/// Usage:
/// ```swift
/// VStack { content }
///     .floGlassCard()
///
/// VStack { content }
///     .floGlassCard(padding: 20, hoverable: true)
/// ```
public struct FLOGlassCardModifier: ViewModifier {
    let padding: CGFloat
    let hoverable: Bool

    #if os(macOS) || targetEnvironment(macCatalyst)
    @State private var isHovered = false
    #endif

    public init(padding: CGFloat = FLOSpacing.cardPadding, hoverable: Bool = true) {
        self.padding = padding
        self.hoverable = hoverable
    }

    public func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            liquidGlassBody(content: content)
        } else {
            legacyGlassBody(content: content)
        }
    }

    // MARK: - iOS 26 / macOS Tahoe Liquid Glass branch

    @available(iOS 26.0, macOS 26.0, *)
    @ViewBuilder
    private func liquidGlassBody(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: FLOSpacing.cardRadius)
        content
            .padding(padding)
            .glassEffect(in: shape)
            .overlay(
                shape.strokeBorder(borderColor.opacity(0.6), lineWidth: 0.5)
            )
            #if os(macOS) || targetEnvironment(macCatalyst)
            .onHover { hovering in
                guard hoverable else { return }
                withAnimation(FLOAnimation.quickEase) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isHovered && hoverable ? 1.005 : 1.0)
            #endif
    }

    // MARK: - Pre-iOS 26 hand-rolled fallback (unchanged from v3.0)

    @ViewBuilder
    private func legacyGlassBody(content: Content) -> some View {
        content
            .padding(padding)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: FLOSpacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FLOSpacing.cardRadius)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .overlay(
                // Top highlight edge (subtle glass refraction effect)
                RoundedRectangle(cornerRadius: FLOSpacing.cardRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.03),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            #if os(macOS) || targetEnvironment(macCatalyst)
            .onHover { hovering in
                guard hoverable else { return }
                withAnimation(FLOAnimation.quickEase) {
                    isHovered = hovering
                }
            }
            .scaleEffect(isHovered && hoverable ? 1.005 : 1.0)
            #endif
    }

    private var backgroundView: some View {
        #if os(macOS) || targetEnvironment(macCatalyst)
        let baseColor = isHovered && hoverable
            ? FLOCanvasColors.surfaceHover
            : FLOCanvasColors.cardGlass
        return baseColor
            .background(.ultraThinMaterial)
        #else
        return FLOCanvasColors.cardGlass
            .background(.ultraThinMaterial)
        #endif
    }

    private var borderColor: Color {
        #if os(macOS) || targetEnvironment(macCatalyst)
        return isHovered && hoverable
            ? FLOCanvasColors.cardBorder.opacity(1.5)
            : FLOCanvasColors.cardBorder
        #else
        return FLOCanvasColors.cardBorder
        #endif
    }
}

/// Accent-bordered glass card for selected/active states.
public struct FLOAccentGlassCardModifier: ViewModifier {
    let padding: CGFloat

    public init(padding: CGFloat = FLOSpacing.cardPadding) {
        self.padding = padding
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: FLOSpacing.cardRadius)
        if #available(iOS 26.0, macOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(.regular.tint(FLOSemanticColors.teal.opacity(0.18)), in: shape)
                .overlay(
                    shape.strokeBorder(FLOSemanticColors.teal.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: FLOSemanticColors.teal.opacity(0.1), radius: 8, y: 2)
        } else {
            content
                .padding(padding)
                .background(FLOSemanticColors.teal.opacity(0.06))
                .background(.ultraThinMaterial)
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(FLOSemanticColors.teal.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: FLOSemanticColors.teal.opacity(0.1), radius: 8, y: 2)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Apply the FLO glass card style with design system tokens.
    ///
    /// - Parameters:
    ///   - padding: Internal padding (default: FLOSpacing.cardPadding / 16pt)
    ///   - hoverable: Enable hover effect on macOS (default: true)
    public func floGlassCard(
        padding: CGFloat = FLOSpacing.cardPadding,
        hoverable: Bool = true
    ) -> some View {
        modifier(FLOGlassCardModifier(padding: padding, hoverable: hoverable))
    }

    /// Apply the FLO accent glass card style (teal border, selected state).
    public func floAccentGlassCard(padding: CGFloat = FLOSpacing.cardPadding) -> some View {
        modifier(FLOAccentGlassCardModifier(padding: padding))
    }
}

#if DEBUG
#Preview("Glass Cards") {
    VStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Standard Glass Card")
                .font(FLOTypography.cardTitle)
                .foregroundStyle(FLOCanvasColors.textPrimary)
            Text("This uses the default glass card styling with blur and border.")
                .font(FLOTypography.bodySecondary)
                .foregroundStyle(FLOCanvasColors.textSecondary)
        }
        .floGlassCard()

        VStack(alignment: .leading, spacing: 8) {
            Text("Accent Glass Card")
                .font(FLOTypography.cardTitle)
                .foregroundStyle(FLOCanvasColors.textPrimary)
            Text("Selected/active state with teal accent border.")
                .font(FLOTypography.bodySecondary)
                .foregroundStyle(FLOCanvasColors.textSecondary)
        }
        .floAccentGlassCard()

        VStack(alignment: .leading, spacing: 8) {
            Text("Compact Card")
                .font(FLOTypography.cardTitle)
                .foregroundStyle(FLOCanvasColors.textPrimary)
        }
        .floGlassCard(padding: 12)
    }
    .padding()
    .background(Color(hex: "07070D"))
}
#endif
