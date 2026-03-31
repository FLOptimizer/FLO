//  AnimationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Fixed Animation.none compile error
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Added OSLog logging for debugging (consistency with HapticService)
//  ✅ Shimmer respects Reduce Transparency accessibility setting
//  ✅ Added note about HapticService integration
//  ✅ Minor documentation improvements
//
//  PURPOSE:
//  Provides consistent animation presets across the app
//  Automatically respects "Reduce Motion" accessibility setting
//  Simplifies animation usage with reusable view modifiers
//
//  ACCESSIBILITY:
//  All animations automatically check UIAccessibility.isReduceMotionEnabled
//  When Reduce Motion is ON, animations are replaced with instant transitions
//  or subtle opacity fades (per Apple HIG recommendations)
//  Shimmer effect respects Reduce Transparency setting
//
//  HAPTIC INTEGRATION:
//  For tactile feedback, use HapticService separately:
//  ```swift
//  Button("Save") {
//      HapticService.play(.success)
//      withAnimation(FLOAnimation.bouncy) {
//          showConfirmation = true
//      }
//  }
//  ```
//

import SwiftUI
import OSLog

// MARK: - Logger

private extension Logger {
    static let animations = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
        category: "AnimationService"
    )
}

// MARK: - FLO Animation Presets

/// Centralized animation definitions for consistency
/// All animations automatically respect Reduce Motion accessibility setting
struct FLOAnimation {
    
    // MARK: - Configuration
    
    #if DEBUG
    private static let enableLogging = false  // Set to true for verbose logging
    #else
    private static let enableLogging = false
    #endif
    
    // MARK: - Environment Check
    
    /// Cross-platform Reduce Motion check
    static var isReduceMotionEnabled: Bool {
        reduceMotion
    }

    /// Returns true if Reduce Motion is enabled in system settings
    private static var reduceMotion: Bool {
        #if canImport(UIKit)
        FLOAnimation.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    /// Returns true if Reduce Transparency is enabled
    private static var reduceTransparency: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceTransparencyEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        #endif
    }
    
    // MARK: - Logging
    
    private static func log(_ message: String) {
        guard enableLogging else { return }
        Logger.animations.debug("\(message)")
    }
    
    // MARK: - Spring Animations
    
    /// Standard spring for most UI interactions
    /// Use for: Card transitions, sheet presentations, general UI
    static var standard: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): standard")
            return .linear(duration: 0)
        }
        return .spring(response: 0.5, dampingFraction: 0.8)
    }
    
    /// Quick spring for snappy interactions
    /// Use for: Button presses, quick toggles, tab switches
    static var quick: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): quick")
            return .linear(duration: 0)
        }
        return .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Bouncy spring for playful elements
    /// Use for: Success states, celebrations, attention-grabbing
    static var bouncy: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): bouncy")
            return .linear(duration: 0)
        }
        return .spring(response: 0.5, dampingFraction: 0.6)
    }
    
    /// Gentle spring for subtle movements
    /// Use for: Background elements, secondary UI, gentle reveals
    static var gentle: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): gentle")
            return .linear(duration: 0)
        }
        return .spring(response: 0.6, dampingFraction: 0.9)
    }
    
    /// Snappy spring for immediate feedback
    /// Use for: Interactive elements, drag-and-drop, sliders
    static var snappy: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): snappy")
            return .linear(duration: 0)
        }
        return .spring(response: 0.25, dampingFraction: 0.8)
    }
    
    // MARK: - Ease Animations
    
    /// Standard ease for general transitions
    /// Use for: Opacity changes, color transitions
    static var ease: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): ease")
            return .linear(duration: 0)
        }
        return .easeInOut(duration: 0.3)
    }
    
    /// Quick ease for fast transitions
    /// Use for: Hover states, micro-interactions
    static var quickEase: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): quickEase")
            return .linear(duration: 0)
        }
        return .easeOut(duration: 0.2)
    }
    
    /// Slow ease for dramatic reveals
    /// Use for: Hero animations, important reveals
    static var slowEase: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): slowEase")
            return .linear(duration: 0)
        }
        return .easeInOut(duration: 0.5)
    }
    
    // MARK: - Linear Animations
    
    /// Linear for continuous animations
    /// Use for: Progress indicators, loading states
    static var linear: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): linear")
            return .linear(duration: 0)
        }
        return .linear(duration: 0.3)
    }
    
    /// Slow linear for smooth continuous motion
    static var slowLinear: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): slowLinear")
            return .linear(duration: 0)
        }
        return .linear(duration: 1.0)
    }
    
    // MARK: - Staggered Animations
    
    /// Creates staggered animation with delay based on index
    /// Use for: List items, grid cells, sequential reveals
    static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): staggered[\(index)]")
            return .linear(duration: 0)
        }
        return .spring(response: 0.5, dampingFraction: 0.8)
            .delay(Double(index) * baseDelay)
    }
    
    /// Creates staggered animation with custom base animation
    static func staggered(
        index: Int,
        baseDelay: Double = 0.05,
        animation: Animation
    ) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): staggered[\(index)]")
            return .linear(duration: 0)
        }
        return animation.delay(Double(index) * baseDelay)
    }
    
    /// Creates reverse staggered animation (for exit)
    static func reverseStaggered(
        index: Int,
        totalCount: Int,
        baseDelay: Double = 0.03
    ) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): reverseStaggered[\(index)]")
            return .linear(duration: 0)
        }
        return .spring(response: 0.4, dampingFraction: 0.8)
            .delay(Double(totalCount - index) * baseDelay)
    }
    
    // MARK: - Delayed Animations
    
    /// Standard animation with custom delay
    static func delayed(_ delay: Double) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): delayed(\(delay))")
            return .linear(duration: 0)
        }
        return standard.delay(delay)
    }
    
    /// Quick animation with custom delay
    static func quickDelayed(_ delay: Double) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): quickDelayed(\(delay))")
            return .linear(duration: 0)
        }
        return quick.delay(delay)
    }
    
    // MARK: - Repeating Animations
    
    /// Pulse animation for attention indicators
    static var pulse: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): pulse")
            return .linear(duration: 0)
        }
        return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }
    
    /// Gentle breathing animation
    static var breathe: Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): breathe")
            return .linear(duration: 0)
        }
        return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
    
    // MARK: - Utility
    
    /// Returns animation only if motion is allowed
    /// Use for: Custom animations that should respect accessibility
    static func ifAllowed(_ animation: Animation) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): custom")
            return .linear(duration: 0)
        }
        return animation
    }
    
    /// Returns the given animation or .none based on reduce motion
    static func conditional(_ animation: Animation) -> Animation {
        if reduceMotion {
            log("Animation skipped (Reduce Motion): conditional")
            return .linear(duration: 0)
        }
        return animation
    }
    
    // MARK: - Accessibility Helpers
    
    /// Check if shimmer effects should be shown
    /// Returns false if Reduce Motion OR Reduce Transparency is enabled
    static var shouldShowShimmer: Bool {
        !reduceMotion && !reduceTransparency
    }
}

// MARK: - Transition Presets

extension AnyTransition {
    
    /// Standard slide and fade transition
    /// Use for: Navigation, card reveals
    static var floSlide: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
    }
    
    /// Scale and fade transition for modals
    /// Use for: Popups, alerts, tooltips
    static var floScale: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .scale(scale: 0.9).combined(with: .opacity)
    }
    
    /// Bottom sheet transition
    /// Use for: Sheets, action menus
    static var floSheet: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity)
    }
    
    /// Top reveal transition
    /// Use for: Banners, notifications
    static var floTopReveal: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .move(edge: .top).combined(with: .opacity)
    }
    
    /// Scale up from center
    /// Use for: Emphasis, celebrations
    static var floGrow: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .scale(scale: 0.5).combined(with: .opacity)
    }
    
    /// Slide from leading
    static var floSlideFromLeading: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .move(edge: .leading).combined(with: .opacity)
    }
    
    /// Slide from trailing
    static var floSlideFromTrailing: AnyTransition {
        FLOAnimation.isReduceMotionEnabled
            ? .opacity
            : .move(edge: .trailing).combined(with: .opacity)
    }
}

// MARK: - View Modifiers

extension View {
    
    /// Applies entrance animation that respects Reduce Motion
    /// Use for: View appear animations
    func floEntrance(
        delay: Double = 0,
        offset: CGFloat = 20
    ) -> some View {
        modifier(EntranceAnimationModifier(delay: delay, offset: offset))
    }
    
    /// Applies staggered entrance animation for lists
    /// Use for: List items, grid cells
    func floStaggeredEntrance(
        index: Int,
        baseDelay: Double = 0.05,
        offset: CGFloat = 10
    ) -> some View {
        modifier(StaggeredEntranceModifier(
            index: index,
            baseDelay: baseDelay,
            offset: offset
        ))
    }
    
    /// Applies scale animation for interactive cards
    /// Use for: Tappable cards, buttons with press state
    func floCardScale(isPressed: Bool) -> some View {
        modifier(CardScaleModifier(isPressed: isPressed))
    }
    
    /// Applies fade animation
    /// Use for: Conditional visibility
    func floFade(isVisible: Bool, duration: Double = 0.3) -> some View {
        modifier(FadeModifier(isVisible: isVisible, duration: duration))
    }
    
    /// Applies slide animation
    /// Use for: Sliding panels, drawers
    func floSlide(isVisible: Bool, edge: Edge = .trailing) -> some View {
        modifier(SlideModifier(isVisible: isVisible, edge: edge))
    }
    
    /// Applies shimmer loading effect
    /// Respects both Reduce Motion AND Reduce Transparency settings
    /// Use for: Skeleton loading states
    func floShimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
    
    /// Applies pulse animation to draw attention
    /// Use for: New features, important indicators
    func floPulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Animation Modifier Implementations

struct EntranceAnimationModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isVisible ? 1 : 0.001))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : offset))
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(FLOAnimation.standard.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct StaggeredEntranceModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    let offset: CGFloat
    
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isVisible ? 1 : 0.001))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : offset))
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(FLOAnimation.staggered(index: index, baseDelay: baseDelay)) {
                        isVisible = true
                    }
                }
            }
    }
}

struct CardScaleModifier: ViewModifier {
    let isPressed: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.97 : 1.0))
            .animation(reduceMotion ? .none : FLOAnimation.quick, value: isPressed)
    }
}

struct FadeModifier: ViewModifier {
    let isVisible: Bool
    let duration: Double
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.001)
            .animation(
                reduceMotion ? .none : .easeInOut(duration: duration),
                value: isVisible
            )
    }
}

struct SlideModifier: ViewModifier {
    let isVisible: Bool
    let edge: Edge
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var offsetValue: CGFloat {
        switch edge {
        case .leading: return -100
        case .trailing: return 100
        case .top: return -100
        case .bottom: return 100
        }
    }
    
    private var xOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return (edge == .leading || edge == .trailing) ? (isVisible ? 0 : offsetValue) : 0
    }
    
    private var yOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return (edge == .top || edge == .bottom) ? (isVisible ? 0 : offsetValue) : 0
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.001)
            .offset(x: xOffset, y: yOffset)
            .animation(FLOAnimation.standard, value: isVisible)
    }
}

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    /// Shimmer should only show if active AND accessibility allows
    private var shouldAnimate: Bool {
        isActive && !reduceMotion && !reduceTransparency
    }
    
    func body(content: Content) -> some View {
        if shouldAnimate {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 2)
                        .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

struct PulseModifier: ViewModifier {
    let isActive: Bool
    
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isActive && isPulsing ? 1.05 : 1.0))
            .opacity(reduceMotion ? 1.0 : (isActive && isPulsing ? 0.9 : 1.0))
            .onAppear {
                guard isActive && !reduceMotion else { return }
                withAnimation(FLOAnimation.pulse) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Button Style with Animation

/// Button style that provides press feedback with animations
struct FLOButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : 1.0))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? .none : FLOAnimation.quick, value: configuration.isPressed)
    }
}

extension View {
    /// Applies FLO button style
    func floButtonStyle() -> some View {
        self.buttonStyle(FLOButtonStyle())
    }
}

// MARK: - Migration Guide
/*
 
 MIGRATION FROM HARDCODED ANIMATIONS:
 
 BEFORE:
 ```swift
 .animation(.spring(response: 0.5, dampingFraction: 0.8), value: someValue)
 ```
 
 AFTER:
 ```swift
 .animation(FLOAnimation.standard, value: someValue)
 ```
 
 COMMON REPLACEMENTS:
 - .spring(response: 0.5, dampingFraction: 0.8) → FLOAnimation.standard
 - .spring(response: 0.3, dampingFraction: 0.7) → FLOAnimation.quick
 - .easeInOut(duration: 0.3) → FLOAnimation.ease
 
 FOR STAGGERED ANIMATIONS:
 
 BEFORE:
 ```swift
 @State private var viewAppeared = false
 
 ForEach(items.indices, id: \.self) { index in
     ItemView(item: items[index])
         .opacity(viewAppeared ? 1 : 0.001)
         .offset(y: viewAppeared ? 0 : 10)
         .animation(
             .spring(response: 0.5, dampingFraction: 0.8)
             .delay(Double(index) * 0.05),
             value: viewAppeared
         )
 }
 .onAppear { viewAppeared = true }
 ```
 
 AFTER:
 ```swift
 ForEach(items.indices, id: \.self) { index in
     ItemView(item: items[index])
         .floStaggeredEntrance(index: index)
 }
 ```
 
 COMBINING WITH HAPTICS:
 Use HapticService separately for tactile feedback:
 
 ```swift
 Button("Save") {
     HapticService.play(.success)
     withAnimation(FLOAnimation.bouncy) {
         showConfirmation = true
     }
 }
 ```
 
 */
