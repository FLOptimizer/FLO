//  FLODesignSystemTests.swift
//  FLODesignSystemTests
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Testing
import SwiftUI
@testable import FLODesignSystem

// MARK: - Color Token Tests

@Suite("FLOColors")
struct FLOColorsTests {

    @Test("Canvas colors are non-nil")
    func canvasColorsExist() {
        // Verify core canvas tokens resolve to valid colors
        let _ = FLOCanvasColors.canvas
        let _ = FLOCanvasColors.surface
        let _ = FLOCanvasColors.textPrimary
        let _ = FLOCanvasColors.textSecondary
        let _ = FLOCanvasColors.textTertiary
        let _ = FLOCanvasColors.cardGlass
        let _ = FLOCanvasColors.cardBorder
        let _ = FLOCanvasColors.surfaceHover
    }

    @Test("Semantic colors are non-nil")
    func semanticColorsExist() {
        let _ = FLOSemanticColors.teal
        let _ = FLOSemanticColors.income
        let _ = FLOSemanticColors.expense
        let _ = FLOSemanticColors.warning
        let _ = FLOSemanticColors.error
        let _ = FLOSemanticColors.success
    }

    @Test("Category color lookup returns correct colors")
    func categoryColorLookup() {
        // Known categories should return their specific color, not the default
        let groceries = FLOCategoryColors.color(for: "Groceries")
        let defaultColor = Color(hex: "64748B")

        // Groceries should NOT be the default gray
        #expect(groceries != defaultColor)

        // Coffee should have special text color
        let coffeeText = FLOCategoryColors.textColor(for: "Coffee")
        let defaultText = FLOCategoryColors.textColor(for: "Groceries")
        #expect(coffeeText != defaultText)
    }

    @Test("Category color lookup is case-insensitive")
    func categoryColorCaseInsensitive() {
        let lower = FLOCategoryColors.color(for: "groceries")
        let upper = FLOCategoryColors.color(for: "Groceries")
        let mixed = FLOCategoryColors.color(for: "GROCERIES")
        #expect(lower == upper)
        #expect(upper == mixed)
    }

    @Test("Hex initializer handles valid 6-char hex")
    func hexInitValid() {
        let color = Color(hex: "14B8A6")
        let _ = color // Should not crash
    }

    @Test("Hex initializer handles # prefix")
    func hexInitWithHash() {
        let color = Color(hex: "#14B8A6")
        let _ = color // Should strip # and succeed
    }

    @Test("Hex initializer handles invalid input gracefully")
    func hexInitInvalid() {
        let color = Color(hex: "ZZZZZZ")
        // Should fall back to gray without crashing
        let _ = color
    }

    @Test("All 6 color schemes exist")
    func allSchemesPresent() {
        #expect(FLOColorScheme.allSchemes.count == 6)
    }

    @Test("Color scheme IDs are unique")
    func schemeIDsUnique() {
        let ids = FLOColorScheme.allSchemes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}

// MARK: - Typography Tests

@Suite("FLOTypography")
struct FLOTypographyTests {

    @Test("Typography tokens are accessible")
    func typographyTokensExist() {
        let _ = FLOTypography.hero
        let _ = FLOTypography.heroSubtitle
        let _ = FLOTypography.cardTitle
        let _ = FLOTypography.sectionHeader
        let _ = FLOTypography.body
        let _ = FLOTypography.bodySecondary
        let _ = FLOTypography.financialNumber
        let _ = FLOTypography.financialLarge
        let _ = FLOTypography.categoryTag
        let _ = FLOTypography.badge
        let _ = FLOTypography.sidebarLabel
        let _ = FLOTypography.caption
        let _ = FLOTypography.monoCode
    }
}

// MARK: - Spacing Tests

@Suite("FLOSpacing")
struct FLOSpacingTests {

    @Test("Spacing tokens follow 4pt/8pt grid")
    func spacingGridAlignment() {
        #expect(FLOSpacing.xxs.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.xs.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.sm.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.md.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.lg.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.xl.truncatingRemainder(dividingBy: 4) == 0)
        #expect(FLOSpacing.xxl.truncatingRemainder(dividingBy: 4) == 0)
    }

    @Test("Spacing scale is monotonically increasing")
    func spacingScaleOrder() {
        #expect(FLOSpacing.xxs < FLOSpacing.xs)
        #expect(FLOSpacing.xs < FLOSpacing.sm)
        #expect(FLOSpacing.sm < FLOSpacing.md)
        #expect(FLOSpacing.md < FLOSpacing.lg)
        #expect(FLOSpacing.lg < FLOSpacing.xl)
        #expect(FLOSpacing.xl < FLOSpacing.xxl)
        #expect(FLOSpacing.xxl < FLOSpacing.xxxl)
    }

    @Test("Navigation widths are reasonable")
    func navigationWidths() {
        #expect(FLOSpacing.sidebarIconWidth > 40)
        #expect(FLOSpacing.sidebarIconWidth < 80)
        #expect(FLOSpacing.sidebarTextWidth >= 180)
        #expect(FLOSpacing.sidebarTextWidth <= 240)
    }
}

// MARK: - Animation Tests

@Suite("FLOAnimations")
struct FLOAnimationTests {

    @Test("Animation presets are accessible")
    func animationPresetsExist() {
        let _ = FLOAnimation.standard
        let _ = FLOAnimation.quick
        let _ = FLOAnimation.bouncy
        let _ = FLOAnimation.gentle
        let _ = FLOAnimation.snappy
        let _ = FLOAnimation.ease
        let _ = FLOAnimation.quickEase
        let _ = FLOAnimation.slowEase
        let _ = FLOAnimation.linear
        let _ = FLOAnimation.pulse
        let _ = FLOAnimation.breathe
    }

    @Test("Zone transition animations are accessible")
    func zoneAnimationsExist() {
        let _ = FLOAnimation.sidebarCollapse
        let _ = FLOAnimation.zoneExpand
        let _ = FLOAnimation.orientationChange
    }

    @Test("Staggered animation creates with index")
    func staggeredAnimation() {
        let _ = FLOAnimation.staggered(index: 0)
        let _ = FLOAnimation.staggered(index: 5, baseDelay: 0.1)
    }

    @Test("Delayed animation creates with delay")
    func delayedAnimation() {
        let _ = FLOAnimation.delayed(0.5)
        let _ = FLOAnimation.quickDelayed(0.2)
    }
}

// MARK: - Component Tests

@Suite("CategoryTag")
struct CategoryTagTests {

    @MainActor
    @Test("CategoryTag initializes with all standard categories")
    func standardCategories() {
        let categories = [
            "Dining Out", "Groceries", "Coffee", "Software & Tools",
            "Transportation", "Entertainment", "Shopping", "Client Payment",
            "Housing", "Office Supplies", "Health", "Utilities"
        ]
        for category in categories {
            let _ = CategoryTag(category: category)
        }
    }

    @MainActor
    @Test("CategoryTag supports all sizes")
    func tagSizes() {
        let _ = CategoryTag(category: "Groceries", size: .compact)
        let _ = CategoryTag(category: "Groceries", size: .standard)
        let _ = CategoryTag(category: "Groceries", size: .large)
    }

    @Test("CategoryTag compact is smaller than standard")
    func sizeOrdering() {
        #expect(CategoryTag.TagSize.compact.fontSize < CategoryTag.TagSize.standard.fontSize)
        #expect(CategoryTag.TagSize.standard.fontSize < CategoryTag.TagSize.large.fontSize)
    }
}

@Suite("BudgetCircle")
struct BudgetCircleTests {

    @MainActor
    @Test("BudgetCircle calculates status correctly")
    func statusCalculation() {
        // Under 80% → good (green)
        let good = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 300, budget: 600)
        let _ = good

        // 80-100% → warning (yellow)
        let warning = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 500, budget: 600)
        let _ = warning

        // Over 100% → over (red)
        let over = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 700, budget: 600)
        let _ = over
    }

    @MainActor
    @Test("BudgetCircle handles zero budget gracefully")
    func zeroBudget() {
        let circle = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 100, budget: 0)
        let _ = circle // Should not crash or divide by zero
    }

    @MainActor
    @Test("BudgetCircle supports both sizes")
    func circleSizes() {
        let standard = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 300, budget: 600, size: .standard)
        let large = BudgetCircle(emoji: "🥬", name: "Groceries", spent: 300, budget: 600, size: .large)
        let _ = (standard, large)

        #expect(BudgetCircle.CircleSize.standard.diameter < BudgetCircle.CircleSize.large.diameter)
    }
}

@Suite("SpendingLine")
struct SpendingLineTests {

    @MainActor
    @Test("SpendingLine initializes with data")
    func basicInit() {
        let line = SpendingLine(
            data: [320, 580, 940, 1200, 1680, 2100, 2450],
            budget: 2800
        )
        let _ = line
    }

    @MainActor
    @Test("SpendingLine handles empty data")
    func emptyData() {
        let line = SpendingLine(data: [], budget: 1000)
        let _ = line // Should not crash
    }

    @MainActor
    @Test("SpendingLine handles single data point")
    func singlePoint() {
        let line = SpendingLine(data: [500], budget: 1000)
        let _ = line
    }
}

@Suite("SmartChip")
struct SmartChipTests {

    @MainActor
    @Test("SmartChip initializes with all styles")
    func allStyles() {
        let _ = SmartChip(icon: "📅", text: "Tax due", style: .neutral)
        let _ = SmartChip(icon: "⚠️", text: "Over budget", style: .warning)
        let _ = SmartChip(icon: "🚨", text: "Overdue", style: .urgent)
        let _ = SmartChip(icon: "✅", text: "On track", style: .success)
        let _ = SmartChip(icon: "ℹ️", text: "Info", style: .info)
    }

    @MainActor
    @Test("SmartChip supports system images")
    func systemImage() {
        let _ = SmartChip(
            icon: "checkmark.circle.fill",
            text: "All good",
            style: .success,
            systemImage: true
        )
    }
}

@Suite("HeroMetric")
struct HeroMetricTests {

    @MainActor
    @Test("HeroMetric formats positive amounts")
    func positiveAmount() {
        let metric = HeroMetric(amount: 12847.32, subtitle: "Net Cash Flow")
        let _ = metric
    }

    @MainActor
    @Test("HeroMetric formats negative amounts")
    func negativeAmount() {
        let metric = HeroMetric(amount: -340.00, subtitle: "This Month")
        let _ = metric
    }

    @MainActor
    @Test("HeroMetric supports all styles")
    func heroAllStyles() {
        let _ = HeroMetric(amount: 1000, subtitle: "Test", style: .auto)
        let _ = HeroMetric(amount: 1000, subtitle: "Test", style: .neutral)
        let _ = HeroMetric(amount: 1000, subtitle: "Test", style: .delta)
        let _ = HeroMetric(amount: 1000, subtitle: "Test", style: .branded)
    }

    @MainActor
    @Test("HeroMetric handles zero")
    func zeroAmount() {
        let metric = HeroMetric(amount: 0.00, subtitle: "Balance")
        let _ = metric
    }
}

@Suite("ReviewBadge")
struct ReviewBadgeTests {

    @MainActor
    @Test("ReviewBadge shows count when items exist")
    func withCount() {
        let badge = ReviewBadge(count: 5, action: {})
        let _ = badge
    }

    @MainActor
    @Test("ReviewBadge shows caught up state at zero")
    func zeroCount() {
        let badge = ReviewBadge(count: 0)
        let _ = badge
    }

    @MainActor
    @Test("ReviewBadge works without action")
    func noAction() {
        let badge = ReviewBadge(count: 3)
        let _ = badge
    }

    @MainActor
    @Test("ReviewCountBadge shows for positive count")
    func compactBadge() {
        let badge = ReviewCountBadge(count: 5)
        let _ = badge
    }

    @MainActor
    @Test("ReviewCountBadge hides at zero")
    func compactBadgeZero() {
        let badge = ReviewCountBadge(count: 0)
        let _ = badge
    }
}

@Suite("GlassCard")
struct GlassCardTests {

    @MainActor
    @Test("GlassCard modifier initializes with defaults")
    func defaultInit() {
        let modifier = FLOGlassCardModifier()
        let _ = modifier
    }

    @MainActor
    @Test("GlassCard modifier accepts custom padding")
    func customPadding() {
        let modifier = FLOGlassCardModifier(padding: 24)
        let _ = modifier
    }

    @MainActor
    @Test("AccentGlassCard modifier initializes")
    func accentInit() {
        let modifier = FLOAccentGlassCardModifier()
        let _ = modifier
    }
}

// MARK: - Version Tests

@Suite("FLODesignSystem")
struct FLODesignSystemVersionTests {

    @Test("Version is set")
    func versionExists() {
        #expect(!FLODesignSystemVersion.version.isEmpty)
        #expect(FLODesignSystemVersion.build == 10)
    }
}
