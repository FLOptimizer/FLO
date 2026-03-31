//  CurrencyInputField.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Penny-Up Shift Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ CREATED: Reusable penny-up shift-entry currency input component
//  ✅ ADDED: Digits accumulate from the right ($0.01 → $0.15 → $1.50 → $15.00)
//  ✅ ADDED: Backspace removes last digit and shifts right ($15.00 → $1.50)
//  ✅ ADDED: Internal integer cents storage avoids floating-point rounding
//  ✅ ADDED: Pre-populated values from external Double binding
//  ✅ ADDED: Max value guard at $999,999.99
//  ✅ ADDED: Full VoiceOver support with spoken currency values
//  ✅ ADDED: Dynamic Type support via configurable font
//  ✅ ADDED: Done toolbar button for numberPad dismissal
//  ✅ ADDED: Programmatic amount updates (e.g., receipt auto-fill)
//  ✅ ADDED: NumberFormatter with locale-aware currency formatting
//

import SwiftUI

/// A penny-up shift-entry currency input field.
///
/// Digits accumulate from the right as the user types:
/// - Tap 1 → $0.01
/// - Tap 5 → $0.15
/// - Tap 0 → $1.50
/// - Tap 0 → $15.00
///
/// Backspace removes the last digit and shifts right:
/// - $15.00 → $1.50 → $0.15 → $0.01 → $0.00
///
/// The underlying value is stored as integer cents to avoid floating-point rounding.
/// The parent view receives a `Double` via the `amount` binding.
struct CurrencyInputField: View {

    // MARK: - External Binding

    /// The dollar amount (read/write). Parent binds to this.
    @Binding var amount: Double

    // MARK: - Configuration

    /// Placeholder shown when amount is zero
    var placeholder: String = "$0.00"

    /// Font for the displayed amount
    var font: Font = .title2

    /// Font weight for the displayed amount
    var fontWeight: Font.Weight = .semibold

    /// Text color when amount > 0
    var color: Color = .primary

    /// Accessibility label override (default: "Amount")
    var accessibilityLabelText: String = "Amount"

    /// Whether to show the Done toolbar button (default: false).
    /// Parent forms should add a single ToolbarItemGroup(placement: .keyboard)
    /// instead, to avoid duplicate Done buttons when multiple CurrencyInputFields exist.
    var showDoneButton: Bool = false

    // MARK: - Internal State

    /// Integer cents value — the source of truth for input
    @State private var centsValue: Int = 0

    /// The raw digit string captured by the hidden text field
    @State private var rawDigits: String = ""

    /// Tracks whether we've initialized from the external binding
    @State private var hasInitialized: Bool = false

    /// Suppresses syncing back to the binding during programmatic updates
    @State private var isSyncingFromExternal: Bool = false

    @FocusState private var isFocused: Bool

    // MARK: - Constants

    /// Maximum value in cents ($999,999.99)
    private static let maxCents: Int = 99_999_999

    // MARK: - Computed Properties

    /// Formatted currency display string from cents
    private var displayText: String {
        Self.formatCents(centsValue)
    }

    /// Static formatter for currency display (with comma grouping)
    private static func formatCents(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return NumberFormatter.appCurrency.string(from: NSNumber(value: dollars)) ?? "$0.00"
    }

    /// Spoken currency value for VoiceOver
    private var spokenValue: String {
        let dollars = centsValue / 100
        let cents = centsValue % 100
        if centsValue == 0 {
            return "zero dollars"
        } else if cents == 0 {
            return "\(dollars) dollar\(dollars == 1 ? "" : "s")"
        } else {
            return "\(dollars) dollar\(dollars == 1 ? "" : "s") and \(cents) cent\(cents == 1 ? "" : "s")"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            // Hidden text field that captures keyboard input
            TextField("", text: $rawDigits)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0.011)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onChange(of: rawDigits) { _, newValue in
                    processInput(newValue)
                }
                .toolbar {
                    if showDoneButton {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isFocused = false
                            }
                        }
                    }
                }

            // Visible formatted display
            Text(centsValue == 0 ? placeholder : displayText)
                .font(font)
                .fontWeight(fontWeight)
                .foregroundStyle(centsValue == 0 ? .secondary : color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    isFocused = true
                }
        }
        .onAppear {
            initializeFromBinding()
        }
        .onChange(of: amount) { _, newAmount in
            syncFromExternalBinding(newAmount)
        }
        .onChange(of: centsValue) { _, newCents in
            guard !isSyncingFromExternal else { return }
            amount = Double(newCents) / 100.0
        }
        // Accessibility
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(centsValue == 0 ? "zero dollars" : spokenValue)
        .accessibilityHint("Tap to enter amount using number keys. Digits shift left as you type.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Input Processing

    /// Processes the raw text field input, extracting only digits
    private func processInput(_ text: String) {
        let digits = text.filter { $0.isNumber }

        if digits.isEmpty {
            centsValue = 0
            return
        }

        // Parse the digit string as an integer (cents)
        if let value = Int(digits) {
            if value <= Self.maxCents {
                centsValue = value
            } else {
                // Exceeded max — revert rawDigits to current centsValue
                rawDigits = centsValue > 0 ? String(centsValue) : ""
            }
        }
    }

    // MARK: - External Sync

    /// Initialize centsValue from the external binding on first appear
    private func initializeFromBinding() {
        guard !hasInitialized else { return }
        hasInitialized = true

        let cents = Int(round(amount * 100))
        if cents > 0 && cents <= Self.maxCents {
            isSyncingFromExternal = true
            centsValue = cents
            rawDigits = String(cents)
            isSyncingFromExternal = false
        }
    }

    /// Sync from external binding changes (e.g., receipt auto-fill)
    private func syncFromExternalBinding(_ newAmount: Double) {
        let newCents = Int(round(newAmount * 100))

        // Avoid feedback loops — only sync if the value actually changed externally
        guard newCents != centsValue else { return }
        guard newCents >= 0 && newCents <= Self.maxCents else { return }

        isSyncingFromExternal = true
        centsValue = newCents
        rawDigits = newCents > 0 ? String(newCents) : ""
        isSyncingFromExternal = false
    }
}

// MARK: - Preview

#Preview("Currency Input - Empty") {
    struct PreviewWrapper: View {
        @State private var amount: Double = 0
        var body: some View {
            Form {
                Section("Amount") {
                    CurrencyInputField(amount: $amount)
                }
                Section("Debug") {
                    Text("Raw Double: \(amount, specifier: "%.2f")")
                }
            }
        }
    }
    return PreviewWrapper()
}

#Preview("Currency Input - Pre-filled") {
    struct PreviewWrapper: View {
        @State private var amount: Double = 47.50
        var body: some View {
            Form {
                Section("Amount") {
                    CurrencyInputField(amount: $amount, color: .red)
                }
                Section("Debug") {
                    Text("Raw Double: \(amount, specifier: "%.2f")")
                }
            }
        }
    }
    return PreviewWrapper()
}
