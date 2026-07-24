//  FLOSpacing.swift
//  FLODesignSystem
//
//  8-point grid spacing system for consistent layout across all platforms.
//  Inspired by Monarch's whitespace discipline and Apple HIG spacing.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Spacing Tokens

/// 8pt grid system for consistent spacing across all FLO platforms.
public enum FLOSpacing {

    // MARK: - Base Grid

    /// 4pt — hairline spacing (tag padding, icon gaps)
    public static let xxs: CGFloat = 4

    /// 8pt — tight spacing (within components, between icon and label)
    public static let xs: CGFloat = 8

    /// 12pt — compact spacing (between related items, card internal gaps)
    public static let sm: CGFloat = 12

    /// 16pt — standard spacing (card padding, section gaps, screen edges)
    public static let md: CGFloat = 16

    /// 20pt — comfortable spacing (between cards)
    public static let lg: CGFloat = 20

    /// 24pt — generous spacing (section separators, hero area padding)
    public static let xl: CGFloat = 24

    /// 32pt — large spacing (screen top/bottom breathing room)
    public static let xxl: CGFloat = 32

    /// 48pt — extra large (empty state vertical centering)
    public static let xxxl: CGFloat = 48

    // MARK: - Component-Specific

    /// Card internal padding
    public static let cardPadding: CGFloat = 16

    /// Card corner radius
    public static let cardRadius: CGFloat = 14

    /// Small card corner radius (tags, badges)
    public static let tagRadius: CGFloat = 4

    /// Button corner radius
    public static let buttonRadius: CGFloat = 12

    /// Standard screen horizontal inset
    public static let screenInset: CGFloat = 16

    // MARK: - Navigation

    /// Landscape sidebar width (iPhone)
    public static let sidebarIconWidth: CGFloat = 54

    /// macOS sidebar width
    public static let sidebarTextWidth: CGFloat = 200

    /// Zone 2 minimum width
    public static let contentMinWidth: CGFloat = 280

    /// Zone 2 ideal width (narrowed state)
    public static let contentNarrowWidth: CGFloat = 340

    // MARK: - Category Tag

    /// Horizontal padding inside category tag pill
    public static let tagHorizontalPadding: CGFloat = 8

    /// Vertical padding inside category tag pill
    public static let tagVerticalPadding: CGFloat = 2

    // MARK: - Budget Circle

    /// Standard budget circle diameter
    public static let budgetCircleSize: CGFloat = 60

    /// Large budget circle (detail view)
    public static let budgetCircleLarge: CGFloat = 120

    /// Circle stroke width
    public static let budgetCircleStroke: CGFloat = 6
}

// MARK: - View Modifiers for Spacing

extension View {

    /// Standard card padding using FLO spacing token.
    public func floCardPadding() -> some View {
        self.padding(FLOSpacing.cardPadding)
    }

    /// Standard screen-edge horizontal padding.
    public func floScreenInset() -> some View {
        self.padding(.horizontal, FLOSpacing.screenInset)
    }

    /// Full-width with standard horizontal padding.
    public func floFullWidth() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.horizontal, FLOSpacing.screenInset)
    }

    /// Section spacing (generous vertical breathing room).
    public func floSectionSpacing() -> some View {
        self.padding(.vertical, FLOSpacing.xl)
    }
}
