//  QuickActionsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 — Streamlined quick actions.
//  Core: Expense, Income, Receipt, Trip (all modes)
//  Business mode adds: Invoice
//  Removed: Move Money (low frequency, handled by Transfer Summary card)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import FLODesignSystem

struct QuickActionsView: View {
    @Binding var showingAddExpense: Bool
    @Binding var showingAddIncome: Bool
    @Binding var showingCreateInvoice: Bool
    @Binding var showingReceiptScanner: Bool
    @Binding var showingMileageTracking: Bool
    let financeMode: FinanceMode

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var buttonsAppeared = false

    private var hasInvoicing: Bool {
        subscriptionManager.currentTier.hasInvoicing
    }

    /// Show Invoice button only in Business or All mode (and only if tier allows)
    private var showInvoice: Bool {
        hasInvoicing && financeMode != .personal
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                FLOBrandedIcon(icon: .quickAction, size: .medium, color: .brandPrimary)

                Text("Quick Actions")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text("1-tap shortcuts")
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Quick Actions. One tap shortcuts for common tasks.")

            Divider()
                .accessibilityHidden(true)

            // Buttons
            HStack(spacing: 8) {
                // 1. Add Income — money in first
                QuickActionButton(
                    floIcon: .income,
                    title: "Income",
                    color: Color.incomeGreen,
                    delay: 0.0,
                    accessibilityHintText: "Opens form to add a new income transaction"
                ) {
                    HapticService.play(.medium)
                    showingAddIncome = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)

                // 2. Add Expense — money out second
                QuickActionButton(
                    floIcon: .expense,
                    title: "Expense",
                    color: Color.expenseRed,
                    delay: 0.05,
                    accessibilityHintText: "Opens form to add a new expense transaction"
                ) {
                    HapticService.play(.medium)
                    showingAddExpense = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)

                // 3. Scan — opens smart scanner directly
                QuickActionButton(
                    floIcon: .receipt,
                    title: "Scan",
                    color: .blue,
                    delay: 0.10,
                    accessibilityHintText: "Opens scanner to scan a receipt or bill"
                ) {
                    HapticService.play(.medium)
                    showingReceiptScanner = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)

                // 4. Log Trip
                QuickActionButton(
                    floIcon: .mileage,
                    title: "Trip",
                    color: .orange,
                    delay: 0.15,
                    accessibilityHintText: "Opens mileage tracking to log a business trip"
                ) {
                    HapticService.play(.medium)
                    showingMileageTracking = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)

                // 5. Create Invoice (Business/All mode + Premium+ only)
                if showInvoice {
                    QuickActionButton(
                        floIcon: .invoices,
                        title: "Invoice",
                        color: Color.brandPrimary,
                        delay: 0.20,
                        accessibilityHintText: "Opens form to create a new client invoice"
                    ) {
                        HapticService.play(.medium)
                        showingCreateInvoice = true
                    }
                    .opacity(buttonsAppeared ? 1 : 0.001)
                    .offset(y: buttonsAppeared ? 0 : 10)
                }
            }
            .padding()
        }
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                buttonsAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Quick Action Button Component

struct QuickActionButton: View {
    let floIcon: FLOIcon
    let title: String
    let color: Color
    let delay: Double
    let accessibilityHintText: String
    let action: () -> Void

    @State private var isPressed = false

    private var fullAccessibilityLabel: String {
        switch title {
        case "Expense": return "Add new expense"
        case "Income": return "Add new income"
        case "Invoice": return "Create new invoice"
        case "Trip": return "Log mileage trip"
        case "Scan": return "Scan receipt or bill"
        default: return title
        }
    }

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                FLOBrandedIcon(icon: floIcon, size: .large, color: color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(FLOAnimation.snappy, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        HapticService.play(.light)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .animation(FLOAnimation.standard.delay(delay), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fullAccessibilityLabel)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Quick Actions - All Mode") {
    QuickActionsView(
        showingAddExpense: .constant(false),
        showingAddIncome: .constant(false),
        showingCreateInvoice: .constant(false),
        showingReceiptScanner: .constant(false),
        showingMileageTracking: .constant(false),
        financeMode: .all
    )
    .padding()
}
