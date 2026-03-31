//  AccessibilityHelpers.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1.1 - Added scalableText() and accessibleField() modifiers
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Provides reusable accessibility modifiers and helpers for VoiceOver,
//  Dynamic Type, and other accessibility features. Apple requires excellent
//  accessibility for App Store featuring consideration.
//
//  USAGE:
//  - Use .accessibleCard() for card containers
//  - Use .accessibleButton() for custom buttons
//  - Use .accessibleCurrency() for money values
//  - Use .accessiblePercentage() for percentages
//
//  WCAG AA REQUIREMENTS:
//  - Minimum touch target: 44x44 points
//  - Color contrast ratio: 4.5:1 for normal text, 3:1 for large text
//  - All interactive elements must have labels
//  - All images must have descriptions or be decorative
//

import SwiftUI

// MARK: - Accessibility View Modifiers

extension View {
    
    // MARK: - Card Accessibility
    
    /// Makes a card accessible as a single grouped element
    /// - Parameters:
    ///   - label: The primary label for VoiceOver
    ///   - hint: Additional context about the card's purpose
    ///   - value: Current value/state of the card (optional)
    func accessibleCard(
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
    }
    
    /// Makes a tappable card accessible with button trait
    func accessibleTappableCard(
        label: String,
        hint: String? = nil,
        value: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Button Accessibility
    
    /// Ensures button has proper accessibility with minimum touch target
    func accessibleButton(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .frame(minWidth: 44, minHeight: 44)
    }
    
    /// For icon-only buttons that need labels
    func accessibleIconButton(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityRemoveTraits(.isImage)
            .frame(minWidth: 44, minHeight: 44)
    }
    
    /// Ensures minimum 44x44pt touch target for accessibility compliance
    /// Use on small icons or buttons that might not meet the minimum
    func minimumTouchTarget() -> some View {
        self
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
    
    // MARK: - Financial Value Accessibility
    
    /// Formats currency for VoiceOver reading
    /// Reads "$1,234.56" as "one thousand two hundred thirty four dollars and fifty six cents"
    func accessibleCurrency(_ amount: Double, label: String? = nil) -> some View {
        let spokenAmount = AccessibilityFormatters.spokenCurrency(amount)
        let fullLabel = label.map { "\($0): \(spokenAmount)" } ?? spokenAmount
        
        return self
            .accessibilityLabel(fullLabel)
            .accessibilityValue("")
    }
    
    /// Formats percentage for VoiceOver reading
    func accessiblePercentage(_ value: Double, label: String? = nil) -> some View {
        let spokenValue = AccessibilityFormatters.spokenPercentage(value)
        let fullLabel = label.map { "\($0): \(spokenValue)" } ?? spokenValue
        
        return self
            .accessibilityLabel(fullLabel)
    }
    
    // MARK: - Header Accessibility
    
    /// Marks as a header for VoiceOver navigation
    func accessibleHeader(_ label: String? = nil) -> some View {
        self
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(label ?? "")
    }
    
    /// Section header with proper semantics
    func accessibleSectionHeader(_ title: String) -> some View {
        self
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("\(title) section")
    }
    
    // MARK: - List Item Accessibility
    
    /// Makes list row accessible with combined children
    func accessibleListRow(
        label: String,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to view details")
    }
    
    // MARK: - Toggle/Selection Accessibility
    
    /// For custom toggle controls
    func accessibleToggle(
        label: String,
        isOn: Bool,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "Double tap to toggle")
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
    
    /// For segmented controls and pickers
    func accessibleSegment(
        label: String,
        isSelected: Bool,
        hint: String? = nil
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to select")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
    
    // MARK: - Image Accessibility
    
    /// Decorative image that VoiceOver should skip
    func accessibleDecorativeImage() -> some View {
        self
            .accessibilityHidden(true)
    }
    
    /// Informative image with description
    func accessibleImage(_ description: String) -> some View {
        self
            .accessibilityLabel(description)
            .accessibilityAddTraits(.isImage)
    }
    
    // MARK: - Status/Badge Accessibility
    
    /// For status indicators (badges, alerts, etc.)
    func accessibleStatus(_ status: String) -> some View {
        self
            .accessibilityLabel(status)
            .accessibilityAddTraits(.isStaticText)
    }
    
    /// For live updating values
    func accessibleLiveRegion(_ label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
    

    // MARK: - Scalable Text Protection
    
    /// Prevents text clipping at large Dynamic Type sizes.
    /// Apply to card titles and currency values that might overflow.
    func scalableText(lines: Int = 1, minScale: CGFloat = 0.7) -> some View {
        self
            .lineLimit(lines)
            .minimumScaleFactor(minScale)
            .truncationMode(.tail)
    }
    
    // MARK: - Form Field Accessibility
    
    /// Adds accessibility context to form text fields
    func accessibleField(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }

    // MARK: - Dynamic Type Support
    
    /// Ensures text scales with Dynamic Type up to a maximum
    func dynamicTypeSize(maximum: DynamicTypeSize) -> some View {
        self.dynamicTypeSize(...maximum)
    }
}

// MARK: - Accessibility Formatters

/// Formatters for VoiceOver-friendly text
enum AccessibilityFormatters {
    
    /// Formats currency for natural speech
    /// "$1,234.56" becomes "1,234 dollars and 56 cents"
    static func spokenCurrency(_ amount: Double) -> String {
        let isNegative = amount < 0
        let absAmount = abs(amount)
        let dollars = Int(absAmount)
        let cents = Int((absAmount - Double(dollars)) * 100)
        
        var result = ""
        
        if isNegative {
            result += "negative "
        }
        
        if dollars == 0 && cents == 0 {
            return "zero dollars"
        }
        
        if dollars > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .spellOut
            result += "\(formatter.string(from: NSNumber(value: dollars)) ?? "\(dollars)") dollar\(dollars == 1 ? "" : "s")"
        }
        
        if cents > 0 {
            if dollars > 0 {
                result += " and "
            }
            result += "\(cents) cent\(cents == 1 ? "" : "s")"
        }
        
        return result
    }
    
    /// Formats percentage for natural speech
    static func spokenPercentage(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) percent"
        }
        return "\(rounded) percent"
    }
    
    /// Formats date for natural speech
    static func spokenDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Formats relative date for natural speech
    static func spokenRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Accessibility Labels for Common FLO Elements

/// Pre-defined accessibility labels for consistency
enum FLOAccessibilityLabels {
    
    // MARK: - Dashboard
    static let dashboardTitle = "Dashboard"
    static let financeModeSelector = "Finance mode selector"
    static let timeframeSelector = "Time period selector"
    
    static func balanceSummary(income: Double, expenses: Double, net: Double) -> String {
        let incomeStr = AccessibilityFormatters.spokenCurrency(income)
        let expenseStr = AccessibilityFormatters.spokenCurrency(expenses)
        let netStr = AccessibilityFormatters.spokenCurrency(net)
        return "Balance summary: Income \(incomeStr), Expenses \(expenseStr), Net \(netStr)"
    }
    
    // MARK: - Quick Actions
    static let addTransaction = "Add new transaction"
    static let scanReceipt = "Scan receipt"
    static let createInvoice = "Create invoice"
    static let trackMileage = "Track mileage"
    
    // MARK: - Transactions
    static func transaction(
        type: String,
        amount: Double,
        category: String,
        date: Date
    ) -> String {
        let amountStr = AccessibilityFormatters.spokenCurrency(amount)
        let dateStr = AccessibilityFormatters.spokenRelativeDate(date)
        return "\(type) of \(amountStr) for \(category), \(dateStr)"
    }
    
    // MARK: - Budgets
    static func budget(name: String, spent: Double, limit: Double) -> String {
        let spentStr = AccessibilityFormatters.spokenCurrency(spent)
        let limitStr = AccessibilityFormatters.spokenCurrency(limit)
        let remaining = limit - spent
        let remainingStr = AccessibilityFormatters.spokenCurrency(remaining)
        return "\(name) budget: \(spentStr) spent of \(limitStr), \(remainingStr) remaining"
    }
    
    // MARK: - Invoices
    static func invoice(
        client: String,
        amount: Double,
        status: String
    ) -> String {
        let amountStr = AccessibilityFormatters.spokenCurrency(amount)
        return "Invoice for \(client), \(amountStr), status: \(status)"
    }
    
    // MARK: - Mileage
    static func mileageTrip(
        distance: Double,
        purpose: String,
        date: Date
    ) -> String {
        let dateStr = AccessibilityFormatters.spokenDate(date)
        return "\(String(format: "%.1f", distance)) mile trip for \(purpose) on \(dateStr)"
    }
    
    // MARK: - Tax
    static func taxEstimate(amount: Double, quarter: String) -> String {
        let amountStr = AccessibilityFormatters.spokenCurrency(amount)
        return "\(quarter) estimated tax payment: \(amountStr)"
    }
    
    // MARK: - Accounts
    static func account(name: String, balance: Double, type: String) -> String {
        let balanceStr = AccessibilityFormatters.spokenCurrency(balance)
        return "\(name) \(type) account, balance: \(balanceStr)"
    }
}

// MARK: - Accessibility Announcement Helper

/// Helper for making VoiceOver announcements
@MainActor
enum AccessibilityAnnouncement {

    /// Announces a message to VoiceOver users
    static func announce(_ message: String, delay: TimeInterval = 0.1) {
        #if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: message])
        }
        #endif
    }

    /// Announces screen change
    static func screenChanged(_ newScreen: String) {
        #if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIAccessibility.post(notification: .screenChanged, argument: newScreen)
        }
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [.announcement: newScreen])
        }
        #endif
    }

    /// Announces layout change
    static func layoutChanged(_ element: Any? = nil) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .layoutChanged, argument: element)
        #else
        NSAccessibility.post(element: NSApp as Any, notification: .layoutChanged)
        #endif
    }
}

// MARK: - Previews

#Preview("Accessibility Helpers Demo") {
    VStack(spacing: 20) {
        // Card example
        VStack {
            Text("Balance Summary")
                .font(.headline)
            Text("$1,234.56")
                .font(.title)
        }
        .padding()
        .background(Color.floSystemBackground)
        .cornerRadius(12)
        .accessibleCard(
            label: FLOAccessibilityLabels.balanceSummary(
                income: 5000,
                expenses: 3765.44,
                net: 1234.56
            )
        )
        
        // Button example
        Button(action: {}) {
            Image(systemName: "plus")
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .accessibleIconButton(
            label: FLOAccessibilityLabels.addTransaction,
            hint: "Opens form to add a new transaction"
        )
        
        // Currency example
        Text("$1,234.56")
            .font(.largeTitle)
            .accessibleCurrency(1234.56, label: "Total balance")
    }
    .padding()
}
