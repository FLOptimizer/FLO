//  QuickActionsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6 - Dynamic Type Verification:
//  ✅ FIXED: Header "Quick Actions" text already had lineLimit + minimumScaleFactor (verified)
//  ✅ FIXED: Header "1-tap shortcuts" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Button title text already had lineLimit + minimumScaleFactor (verified)
//
//  CHANGES v1.5:
//  ✅ Added Move Money button (Premium+ - requires multiple accounts)
//  ✅ Shows between Invoice and Trip buttons
//
//  CHANGES v1.3:
//  ✅ Receipt button: Free tier → Basic OCR capture (ReceiptImageView)
//  ✅ Receipt button: Premium/Pro → Smart Receipt Scanner (AI parsing)
//  ✅ Added hasSmartReceiptScanning tier check
//  ✅ Updated accessibility hints for tier-appropriate actions
//
//  CHANGES v1.2:
//  ✅ Invoice button hidden for Free tier (requires Premium+)
//  ✅ Added SubscriptionManager to check tier
//  ✅ Only shows 3 buttons for Free, 4 for Premium+
//
//  CHANGES v1.1:
//  ✅ Enhanced accessibility hints with clearer action descriptions
//  ✅ Card header accessible with section label
//  ✅ Each button has descriptive accessibility label
//  ✅ Accessibility traits properly set for buttons
//
//  FEATURES v1.0:
//  ✅ 4 quick action buttons: Expense, Invoice, Trip, Receipt
//  ✅ Staggered entrance animations
//  ✅ Press scale animations with haptic feedback
//  ✅ HapticService integration
//  ✅ FLOAnimation presets
//

import SwiftUI

struct QuickActionsView: View {
    @Binding var showingAddExpense: Bool
    @Binding var showingCreateInvoice: Bool
    @Binding var showingReceiptScanner: Bool
    @Binding var showingMileageTracking: Bool
    @Binding var showingMoveMoney: Bool
    
    // v1.3: Add binding for basic receipt capture (Free tier)
    @Binding var showingBasicReceiptCapture: Bool
    
    let financeMode: FinanceMode
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var buttonsAppeared = false
    
    // v1.2: Check if user has invoicing access
    private var hasInvoicing: Bool {
        subscriptionManager.currentTier.hasInvoicing
    }
    
    // v1.3: Check if user has smart receipt scanning (Premium+)
    private var hasSmartReceiptScanning: Bool {
        subscriptionManager.currentTier.hasSmartReceiptScanning
    }
    
    // v1.5: Check if user has multiple accounts (Premium+)
    private var hasMultipleAccounts: Bool {
        subscriptionManager.currentTier.hasMultipleAccounts
    }
    
    /// Animation delay counter based on visible button count
    private var delayStep: Double { 0.05 }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
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
            
            // Quick Action Buttons - v1.5: Added Move Money
            HStack(spacing: 8) {
                // 1. Add Expense (All tiers)
                QuickActionButton(
                    icon: "minus.circle.fill",
                    title: "Expense",
                    color: .red,
                    delay: 0.0,
                    accessibilityHintText: "Opens form to add a new expense transaction"
                ) {
                    HapticService.play(.medium)
                    showingAddExpense = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)
                
                // 2. New Invoice (Premium+ only)
                if hasInvoicing {
                    QuickActionButton(
                        icon: "doc.badge.plus",
                        title: "Invoice",
                        color: Color.brandPrimary,
                        delay: delayStep,
                        accessibilityHintText: "Opens form to create a new client invoice"
                    ) {
                        HapticService.play(.medium)
                        showingCreateInvoice = true
                    }
                    .opacity(buttonsAppeared ? 1 : 0.001)
                    .offset(y: buttonsAppeared ? 0 : 10)
                }
                
                // 3. Move Money (Premium+ only - requires multiple accounts)
                if hasMultipleAccounts {
                    QuickActionButton(
                        icon: "arrow.left.arrow.right.circle.fill",
                        title: "Move",
                        color: .purple,
                        delay: hasInvoicing ? delayStep * 2 : delayStep,
                        accessibilityHintText: "Opens form to transfer money between accounts"
                    ) {
                        HapticService.play(.medium)
                        showingMoveMoney = true
                    }
                    .opacity(buttonsAppeared ? 1 : 0.001)
                    .offset(y: buttonsAppeared ? 0 : 10)
                }
                
                // 4. Start Trip (All tiers - manual entry for Free, GPS for Premium+)
                QuickActionButton(
                    icon: "car.fill",
                    title: "Trip",
                    color: .orange,
                    delay: buttonDelay(position: 3),
                    accessibilityHintText: "Opens mileage tracking to log a business trip"
                ) {
                    HapticService.play(.medium)
                    showingMileageTracking = true
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)
                
                // 5. Scan Receipt (v1.3: Tier-aware routing)
                // Free: Basic OCR capture
                // Premium/Pro: Smart Receipt Scanner with AI parsing
                QuickActionButton(
                    icon: "doc.text.viewfinder",
                    title: "Receipt",
                    color: .blue,
                    delay: buttonDelay(position: 4),
                    accessibilityHintText: hasSmartReceiptScanning
                        ? "Opens smart scanner to capture and parse receipt with AI"
                        : "Opens camera to capture receipt image"
                ) {
                    HapticService.play(.medium)
                    // v1.3: Route based on tier
                    if hasSmartReceiptScanning {
                        showingReceiptScanner = true
                    } else {
                        showingBasicReceiptCapture = true
                    }
                }
                .opacity(buttonsAppeared ? 1 : 0.001)
                .offset(y: buttonsAppeared ? 0 : 10)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                buttonsAppeared = true
            }
        }
        .accessibilityElement(children: .contain)
    }
    
    /// Calculate animation delay based on how many conditional buttons are visible before this position
    private func buttonDelay(position: Int) -> Double {
        var visibleBefore = 1 // Expense is always first
        if hasInvoicing { visibleBefore += 1 }
        if hasMultipleAccounts { visibleBefore += 1 }
        // For position 3 (Trip), delay = visibleBefore * step
        // For position 4 (Receipt), delay = (visibleBefore + 1) * step
        let offset = position - 2 // Trip = 1 after conditional buttons, Receipt = 2
        return Double(visibleBefore + offset - 1) * delayStep
    }
}

// MARK: - Quick Action Button Component

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let delay: Double
    let accessibilityHintText: String
    let action: () -> Void
    
    @State private var isPressed = false
    
    // Full accessibility label based on title
    private var fullAccessibilityLabel: String {
        switch title {
        case "Expense":
            return "Add new expense"
        case "Invoice":
            return "Create new invoice"
        case "Trip":
            return "Log mileage trip"
        case "Receipt":
            return "Scan receipt"
        case "Move":
            return "Move money between accounts"
        default:
            return title
        }
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                .accessibilityHidden(true)
                
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

// MARK: - Preview

#Preview("Quick Actions - Free Tier") {
    QuickActionsView(
        showingAddExpense: .constant(false),
        showingCreateInvoice: .constant(false),
        showingReceiptScanner: .constant(false),
        showingMileageTracking: .constant(false),
        showingMoveMoney: .constant(false),
        showingBasicReceiptCapture: .constant(false),
        financeMode: .all
    )
    .padding()
}
