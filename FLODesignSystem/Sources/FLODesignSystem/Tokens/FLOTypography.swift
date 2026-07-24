//  FLOTypography.swift
//  FLODesignSystem
//
//  Type scale definitions for FLO across all platforms.
//  Based on best-of-breed analysis: Robinhood hero numbers, Mercury tabular figures,
//  Copilot section headers, Monarch whitespace discipline.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Type Scale

/// Centralized typography tokens for FLO.
/// All financial numbers use `.monospacedDigit()` for tabular alignment.
public enum FLOTypography {

    // MARK: - Hero (Dashboard main numbers)

    /// Giant hero number — 36pt heavy, monospaced digits.
    /// Use for: dashboard balance, account total, net worth.
    public static let hero: Font = .system(size: 36, weight: .heavy, design: .default)
        .monospacedDigit()

    /// Hero subtitle — 12pt regular.
    /// Use for: label below hero number ("Net Cash Flow", "This Month").
    public static let heroSubtitle: Font = .system(size: 12, weight: .regular)

    // MARK: - Headings

    /// Card/panel title — 16pt semibold.
    /// Use for: zone 3 headers, card titles, section titles in detail views.
    public static let cardTitle: Font = .system(size: 16, weight: .semibold)

    /// Section header — 13pt semibold, designed for uppercase + tracking.
    /// Apply `.textCase(.uppercase)` and `.tracking(0.8)` at the call site.
    public static let sectionHeader: Font = .system(size: 13, weight: .semibold)

    // MARK: - Body

    /// Primary body text — 13pt medium.
    /// Use for: transaction merchant names, list item titles, client names.
    public static let body: Font = .system(size: 13, weight: .medium)

    /// Secondary body text — 11pt regular.
    /// Use for: dates, metadata, category labels below titles.
    public static let bodySecondary: Font = .system(size: 11, weight: .regular)

    // MARK: - Financial Numbers

    /// Transaction amount — 13pt semibold, monospaced digits.
    /// Use for: all financial amounts in lists and tables.
    public static let financialNumber: Font = .system(size: 13, weight: .semibold)
        .monospacedDigit()

    /// Large financial number — 24pt bold, monospaced digits.
    /// Use for: card totals, section summaries, budget totals.
    public static let financialLarge: Font = .system(size: 24, weight: .bold)
        .monospacedDigit()

    // MARK: - Tags & Badges

    /// Category tag label — 9pt bold.
    /// Apply `.textCase(.uppercase)` and `.tracking(0.5)` at the call site.
    public static let categoryTag: Font = .system(size: 9, weight: .bold)

    /// Badge text — 11pt semibold.
    /// Use for: status badges ("Under Budget"), review counts.
    public static let badge: Font = .system(size: 11, weight: .semibold)

    // MARK: - Navigation

    /// Sidebar label — 8pt semibold.
    /// Apply `.textCase(.uppercase)` and `.tracking(0.5)` at the call site.
    /// Use for: icon labels in landscape sidebar.
    public static let sidebarLabel: Font = .system(size: 8, weight: .semibold)

    /// macOS sidebar item — 13pt regular.
    /// Use for: text labels in macOS sidebar.
    public static let sidebarItem: Font = .system(size: 13, weight: .regular)

    // MARK: - Small / Utility

    /// Caption — 10pt regular.
    /// Use for: timestamps, helper text, footnotes.
    public static let caption: Font = .system(size: 10, weight: .regular)

    /// Monospaced code — caption size, monospaced design.
    /// Use for: invoice IDs, transaction IDs, reference numbers.
    public static let monoCode: Font = .system(size: 10, weight: .regular, design: .monospaced)
}

// MARK: - View Modifiers for Typography

extension View {

    /// Hero number style (36pt heavy, monospaced).
    public func floHeroNumber() -> some View {
        self
            .font(FLOTypography.hero)
            .tracking(-1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    /// Section header style (uppercase, secondary color, tracked).
    public func floSectionHeader() -> some View {
        self
            .font(FLOTypography.sectionHeader)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    /// Financial number style (monospaced tabular figures).
    public func floFinancialNumber() -> some View {
        self
            .font(FLOTypography.financialNumber)
            .monospacedDigit()
    }

    /// Category tag text style (small, bold, uppercase).
    public func floCategoryTagText() -> some View {
        self
            .font(FLOTypography.categoryTag)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    /// Currency display — colored by positive/negative.
    public func floCurrency(isPositive: Bool) -> some View {
        self
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(isPositive ? Color.incomeGreen : Color.expenseRed)
    }

    /// Neutral currency display.
    public func floCurrencyNeutral() -> some View {
        self
            .font(.title2.weight(.bold).monospacedDigit())
            .foregroundStyle(.primary)
    }

    /// Monospaced code style for IDs and reference numbers.
    public func floMonoCode() -> some View {
        self
            .font(FLOTypography.monoCode)
            .foregroundStyle(.secondary)
    }
}
