//  CelebrationOverlayView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed duplicate extension conflicts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ FIXED: Removed duplicate Color.init(hex:) - uses FLO's Color extensions
//  ✅ FIXED: Removed duplicate AccessibilityFormatters - uses FLO's existing one
//  ✅ FIXED: Uses Color.brandPrimary, Color.incomeGreen, Color.brandWarning
//
//  PURPOSE:
//  Unified celebration overlay for success moments in FLO.
//  Combines confetti, animated checkmark, and messaging.
//
//  STYLES:
//  - invoicePaid: Full celebration with confetti (major milestone)
//  - incomeReceived: Subtle pulse celebration (frequent action)
//  - goalReached: Confetti with milestone badge
//  - budgetUnderLimit: Green glow with approval
//  - mileageSaved: Car icon with distance saved
//
//  ACCESSIBILITY:
//  - Respects Reduce Motion: Simplified animations
//  - Respects user preference: Can be disabled in Appearance settings
//  - VoiceOver: Announces success message
//  - Auto-dismisses: Does not block user interaction
//
//  USAGE:
//  .celebrationOverlay(
//      isPresented: $showCelebration,
//      style: .invoicePaid,
//      amount: 5000.00,
//      message: "Invoice Paid!"
//  )
//

import SwiftUI

// MARK: - Celebration Style

enum CelebrationStyle: Equatable {
    /// Full celebration with confetti - for invoice payments (major milestone)
    case invoicePaid
    
    /// Subtle pulse - for income transactions (frequent action)
    case incomeReceived
    
    /// Confetti with milestone badge - for reaching goals
    case goalReached
    
    /// Green glow with approval - for staying under budget
    case budgetUnderLimit
    
    /// Car icon animation - for mileage tracking saves
    case mileageSaved
    
    /// Custom style with specified components
    case custom(showConfetti: Bool, icon: String, iconColor: Color)
    
    var showsConfetti: Bool {
        switch self {
        case .invoicePaid, .goalReached:
            return true
        case .incomeReceived, .budgetUnderLimit, .mileageSaved:
            return false
        case .custom(let showConfetti, _, _):
            return showConfetti
        }
    }
    
    var icon: String {
        switch self {
        case .invoicePaid:
            return "checkmark.circle.fill"
        case .incomeReceived:
            return "arrow.down.circle.fill"
        case .goalReached:
            return "trophy.fill"
        case .budgetUnderLimit:
            return "hand.thumbsup.fill"
        case .mileageSaved:
            return "car.fill"
        case .custom(_, let icon, _):
            return icon
        }
    }
    
    var iconColor: Color {
        switch self {
        case .invoicePaid, .incomeReceived, .budgetUnderLimit:
            return Color.incomeGreen
        case .goalReached:
            return Color.brandWarning
        case .mileageSaved:
            return Color.brandPrimary
        case .custom(_, _, let color):
            return color
        }
    }
    
    var defaultMessage: String {
        switch self {
        case .invoicePaid:
            return "Payment Received!"
        case .incomeReceived:
            return "Income Added"
        case .goalReached:
            return "Goal Reached!"
        case .budgetUnderLimit:
            return "Under Budget!"
        case .mileageSaved:
            return "Trip Saved"
        case .custom:
            return "Success!"
        }
    }
    
    var autoDismissDelay: Double {
        switch self {
        case .invoicePaid, .goalReached:
            return 2.5  // Longer for major celebrations
        case .incomeReceived, .budgetUnderLimit, .mileageSaved:
            return 1.5  // Shorter for frequent actions
        case .custom:
            return 2.0
        }
    }
    
    // Equatable conformance for custom case
    static func == (lhs: CelebrationStyle, rhs: CelebrationStyle) -> Bool {
        switch (lhs, rhs) {
        case (.invoicePaid, .invoicePaid),
             (.incomeReceived, .incomeReceived),
             (.goalReached, .goalReached),
             (.budgetUnderLimit, .budgetUnderLimit),
             (.mileageSaved, .mileageSaved):
            return true
        case (.custom(let lhsConfetti, let lhsIcon, _), .custom(let rhsConfetti, let rhsIcon, _)):
            return lhsConfetti == rhsConfetti && lhsIcon == rhsIcon
        default:
            return false
        }
    }
}

// MARK: - Celebration Overlay View

struct CelebrationOverlayView: View {
    @Binding var isPresented: Bool
    
    let style: CelebrationStyle
    var amount: Double?
    var message: String?
    var onDismiss: (() -> Void)?
    
    @State private var showCheckmark = false
    @State private var showConfetti = false
    @State private var showMessage = false
    @State private var showAmount = false
    @State private var backgroundOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.5
    @State private var amountScale: CGFloat = 0.8
    @State private var dismissWorkItem: DispatchWorkItem?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    
    private var displayMessage: String {
        message ?? style.defaultMessage
    }
    
    private var formattedAmount: String? {
        guard let amount = amount else { return nil }
        return amount.formatted(.currency(code: "USD"))
    }
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black
                .opacity(backgroundOpacity * 0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Confetti layer
            if style.showsConfetti {
                ConfettiView(isActive: $showConfetti)
            }
            
            // Center content
            VStack(spacing: 20) {
                // Icon or Checkmark
                ZStack {
                    if style == .invoicePaid {
                        // Animated checkmark for invoice paid
                        SuccessCheckmarkView(
                            isAnimating: $showCheckmark,
                            size: 80,
                            circleColor: Color.brandPrimary,
                            checkColor: Color.incomeGreen
                        )
                    } else {
                        // SF Symbol for other styles
                        Image(systemName: style.icon)
                            .font(.system(size: 60, weight: .medium))
                            .foregroundStyle(style.iconColor)
                            .scaleEffect(iconScale)
                    }
                }
                .frame(height: 100)
                
                // Message
                if showMessage {
                    Text(displayMessage)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                
                // Amount (if provided)
                if let formattedAmount = formattedAmount, showAmount {
                    Text(formattedAmount)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(style.iconColor)
                        .scaleEffect(amountScale)
                        .shadow(color: style.iconColor.opacity(0.5), radius: 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .padding(40)
        }
        .opacity(isPresented && celebrationsEnabled ? 1 : 0)
        .onChange(of: isPresented) { _, newValue in
            if newValue && celebrationsEnabled {
                startCelebration()
            } else if newValue && !celebrationsEnabled {
                // Celebrations disabled - dismiss immediately
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPresented = false
                    onDismiss?()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityMessage)
        .accessibilityAddTraits(.isStaticText)
    }
    
    // MARK: - Accessibility
    
    private var accessibilityMessage: String {
        var parts = [displayMessage]
        if let amount = amount {
            parts.append(AccessibilityFormatters.spokenCurrency(amount))
        }
        return parts.joined(separator: ". ")
    }
    
    // MARK: - Animation Sequence
    
    private func startCelebration() {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()
        
        // Haptic feedback
        HapticService.shared.celebration()
        
        if reduceMotion {
            // Simplified animation for reduced motion
            withAnimation(.easeOut(duration: 0.2)) {
                backgroundOpacity = 1
                showCheckmark = true
                iconScale = 1.0
                showMessage = true
                showAmount = true
                amountScale = 1.0
            }
            
            if style.showsConfetti {
                showConfetti = true
            }
        } else {
            // Full animation sequence
            
            // 1. Background fades in
            withAnimation(.easeOut(duration: 0.2)) {
                backgroundOpacity = 1
            }
            
            // 2. Icon/Checkmark appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if style == .invoicePaid {
                    showCheckmark = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        iconScale = 1.0
                    }
                    
                    // Bounce
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            iconScale = 1.15
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                                iconScale = 1.0
                            }
                        }
                    }
                }
            }
            
            // 3. Confetti starts
            if style.showsConfetti {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }
            
            // 4. Message appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showMessage = true
                }
            }
            
            // 5. Amount appears with pulse
            if amount != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showAmount = true
                        amountScale = 1.1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            amountScale = 1.0
                        }
                    }
                }
            }
        }
        
        // Schedule auto-dismiss
        let workItem = DispatchWorkItem { [self] in
            dismiss()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + style.autoDismissDelay, execute: workItem)
        
        // Announce for VoiceOver
        AccessibilityAnnouncement.announce(accessibilityMessage)
    }
    
    private func dismiss() {
        dismissWorkItem?.cancel()
        
        withAnimation(.easeOut(duration: 0.25)) {
            backgroundOpacity = 0
            showMessage = false
            showAmount = false
            iconScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPresented = false
            showCheckmark = false
            showConfetti = false
            onDismiss?()
        }
    }
}

// MARK: - View Modifier

struct CelebrationOverlayModifier: ViewModifier {
    @Binding var isPresented: Bool
    let style: CelebrationStyle
    var amount: Double?
    var message: String?
    var onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                CelebrationOverlayView(
                    isPresented: $isPresented,
                    style: style,
                    amount: amount,
                    message: message,
                    onDismiss: onDismiss
                )
            }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a celebration overlay to the view.
    ///
    /// Usage:
    /// ```swift
    /// .celebrationOverlay(
    ///     isPresented: $showCelebration,
    ///     style: .invoicePaid,
    ///     amount: 5000.00,
    ///     message: "Invoice Paid in Full!"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control overlay visibility
    ///   - style: The celebration style (affects animation intensity)
    ///   - amount: Optional amount to display (currency formatted)
    ///   - message: Optional custom message (defaults to style message)
    ///   - onDismiss: Optional closure called when overlay dismisses
    func celebrationOverlay(
        isPresented: Binding<Bool>,
        style: CelebrationStyle,
        amount: Double? = nil,
        message: String? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(CelebrationOverlayModifier(
            isPresented: isPresented,
            style: style,
            amount: amount,
            message: message,
            onDismiss: onDismiss
        ))
    }
}

// MARK: - Previews

#Preview("Invoice Paid") {
    struct PreviewWrapper: View {
        @State private var show = false
        
        var body: some View {
            ZStack {
                Color.gray.opacity(0.2).ignoresSafeArea()
                
                VStack {
                    Text("Invoice Details")
                        .font(.title)
                    
                    Button("Mark as Paid") {
                        show = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .celebrationOverlay(
                isPresented: $show,
                style: .invoicePaid,
                amount: 5000.00,
                message: "Paid in Full!"
            )
        }
    }
    
    return PreviewWrapper()
}

#Preview("Income Received") {
    struct PreviewWrapper: View {
        @State private var show = false
        
        var body: some View {
            Button("Add Income") {
                show = true
            }
            .buttonStyle(.borderedProminent)
            .celebrationOverlay(
                isPresented: $show,
                style: .incomeReceived,
                amount: 1250.00
            )
        }
    }
    
    return PreviewWrapper()
}

#Preview("Goal Reached") {
    struct PreviewWrapper: View {
        @State private var show = false
        
        var body: some View {
            Button("Reach Goal") {
                show = true
            }
            .buttonStyle(.borderedProminent)
            .celebrationOverlay(
                isPresented: $show,
                style: .goalReached,
                message: "Savings Goal Reached!"
            )
        }
    }
    
    return PreviewWrapper()
}

#Preview("All Styles") {
    struct PreviewWrapper: View {
        @State private var currentStyle: CelebrationStyle?
        
        var body: some View {
            VStack(spacing: 16) {
                Button("Invoice Paid") { currentStyle = .invoicePaid }
                Button("Income Received") { currentStyle = .incomeReceived }
                Button("Goal Reached") { currentStyle = .goalReached }
                Button("Under Budget") { currentStyle = .budgetUnderLimit }
                Button("Mileage Saved") { currentStyle = .mileageSaved }
            }
            .buttonStyle(.bordered)
            .celebrationOverlay(
                isPresented: Binding(
                    get: { currentStyle != nil },
                    set: { if !$0 { currentStyle = nil } }
                ),
                style: currentStyle ?? .invoicePaid,
                amount: 2500.00
            )
        }
    }
    
    return PreviewWrapper()
}
