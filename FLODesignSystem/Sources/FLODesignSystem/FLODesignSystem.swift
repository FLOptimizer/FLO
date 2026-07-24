//  FLODesignSystem.swift
//  FLODesignSystem
//
//  Public API surface for the FLO Design System package.
//  Import this module to access all design tokens and components.
//
//  Usage:
//    import FLODesignSystem
//
//  This gives you access to:
//  - FLOCanvasColors      (canvas, surface, text colors)
//  - FLOSemanticColors    (teal, income, expense, warning, etc.)
//  - FLOCategoryColors    (12 category tag colors + lookup)
//  - FLOColorScheme       (6 predefined schemes)
//  - ColorSchemeManager   (singleton + environment key)
//  - Color extensions     (hex init, brand colors, utilities)
//  - FLOTypography        (type scale: hero, body, financial, tags)
//  - FLOSpacing           (8pt grid, component sizes, zone widths)
//  - FLOAnimation         (spring presets, transitions, zone animations)
//  - AnyTransition        (floSlide, floScale, floSheet, floZoneDetail, etc.)
//  - View modifiers       (floEntrance, floShimmer, floPulse, floButtonStyle, etc.)
//  - FLOButtonStyle       (press feedback button style)
//
//  Components:
//  - CategoryTag          (colored pill for expense/income categories)
//  - BudgetCircle         (circular progress with emoji center)
//  - SpendingLine         (gradient trend chart with budget threshold)
//  - SmartChip            (contextual info pill — tax dates, payday, budget warnings)
//  - HeroMetric           (large financial number display)
//  - ReviewBadge          ("N to review" action badge + compact count badge)
//  - GlassCard            (.floGlassCard() modifier with macOS hover)
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

// All public types are exported automatically via their respective files.
// This file exists as the package's primary entry point and documentation.

/// FLO Design System version.
public enum FLODesignSystemVersion {
    public static let version = "1.0.0"
    public static let build = 10
    public static let codename = "Visual Redesign"
}
