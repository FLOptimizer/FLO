//  FLOAnimations.swift
//  FLODesignSystem
//
//  Centralized animation presets extracted from AnimationService.swift (FLO 2.1).
//  All animations automatically respect Reduce Motion accessibility setting.
//
//  New in 3.0: Landscape transition animations, zone collapse/expand,
//  sidebar slide animations for three-zone navigation.
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Animation Presets

/// Centralized animation definitions for consistency across all platforms.
/// All animations respect the Reduce Motion accessibility setting.
public struct FLOAnimation {

    // MARK: - Reduce Motion Check

    private static var reduceMotion: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
    }

    #if canImport(UIKit)
    private static var reduceTransparency: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
    #else
    private static var reduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }
    #endif

    // MARK: - Spring Animations

    /// Standard spring (0.5s, 0.8 damping) — most UI interactions.
    public static var standard: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.8)
    }

    /// Quick spring (0.3s, 0.7 damping) — button presses, tab switches.
    public static var quick: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.3, dampingFraction: 0.7)
    }

    /// Bouncy spring (0.5s, 0.6 damping) — celebrations, success states.
    public static var bouncy: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.6)
    }

    /// Gentle spring (0.6s, 0.9 damping) — subtle reveals, background elements.
    public static var gentle: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.6, dampingFraction: 0.9)
    }

    /// Snappy spring (0.25s, 0.8 damping) — drag-and-drop, sliders.
    public static var snappy: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.25, dampingFraction: 0.8)
    }

    // MARK: - Ease Animations

    /// Standard ease (0.3s) — opacity changes, color transitions.
    public static var ease: Animation {
        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.3)
    }

    /// Quick ease (0.2s) — hover states, micro-interactions.
    public static var quickEase: Animation {
        reduceMotion ? .linear(duration: 0) : .easeOut(duration: 0.2)
    }

    /// Slow ease (0.5s) — hero animations, important reveals.
    public static var slowEase: Animation {
        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 0.5)
    }

    // MARK: - Linear Animations

    /// Linear (0.3s) — progress indicators, loading.
    public static var linear: Animation {
        reduceMotion ? .linear(duration: 0) : .linear(duration: 0.3)
    }

    /// Slow linear (1.0s) — smooth continuous motion.
    public static var slowLinear: Animation {
        reduceMotion ? .linear(duration: 0) : .linear(duration: 1.0)
    }

    // MARK: - Staggered Animations

    /// Staggered animation with delay based on index.
    public static func staggered(index: Int, baseDelay: Double = 0.05) -> Animation {
        reduceMotion ? .linear(duration: 0) :
            .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * baseDelay)
    }

    /// Staggered with custom base animation.
    public static func staggered(index: Int, baseDelay: Double = 0.05, animation: Animation) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation.delay(Double(index) * baseDelay)
    }

    /// Reverse staggered (for exit animations).
    public static func reverseStaggered(index: Int, totalCount: Int, baseDelay: Double = 0.03) -> Animation {
        reduceMotion ? .linear(duration: 0) :
            .spring(response: 0.4, dampingFraction: 0.8).delay(Double(totalCount - index) * baseDelay)
    }

    // MARK: - Delayed

    /// Standard animation with custom delay.
    public static func delayed(_ delay: Double) -> Animation {
        reduceMotion ? .linear(duration: 0) : standard.delay(delay)
    }

    /// Quick animation with custom delay.
    public static func quickDelayed(_ delay: Double) -> Animation {
        reduceMotion ? .linear(duration: 0) : quick.delay(delay)
    }

    // MARK: - Repeating

    /// Pulse — attention indicators.
    public static var pulse: Animation {
        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }

    /// Breathe — gentle continuous.
    public static var breathe: Animation {
        reduceMotion ? .linear(duration: 0) : .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }

    // MARK: - Landscape / Zone Transitions (NEW in 3.0)

    /// Sidebar collapse animation — used when zone 3 opens on iPhone landscape.
    public static var sidebarCollapse: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.35, dampingFraction: 0.85)
    }

    /// Zone expand animation — zone 3 sliding in from trailing edge.
    public static var zoneExpand: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.4, dampingFraction: 0.82)
    }

    /// Orientation change — portrait to landscape transition.
    public static var orientationChange: Animation {
        reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.88)
    }

    // MARK: - Utility

    /// Returns animation only if motion is allowed.
    public static func ifAllowed(_ animation: Animation) -> Animation {
        reduceMotion ? .linear(duration: 0) : animation
    }

    /// Whether shimmer effects should display.
    public static var shouldShowShimmer: Bool {
        !reduceMotion && !reduceTransparency
    }
}

// MARK: - Transition Presets

extension AnyTransition {

    /// Standard slide + fade (navigation, card reveals).
    public static var floSlide: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Scale + fade (modals, popups, tooltips).
    public static var floScale: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .scale(scale: 0.9).combined(with: .opacity)
    }

    /// Bottom sheet transition.
    public static var floSheet: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// Top reveal (banners, notifications).
    public static var floTopReveal: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    /// Scale up from center (emphasis, celebrations).
    public static var floGrow: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .scale(scale: 0.5).combined(with: .opacity)
    }

    /// Slide from leading edge.
    public static var floSlideFromLeading: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .move(edge: .leading).combined(with: .opacity)
    }

    /// Slide from trailing edge.
    public static var floSlideFromTrailing: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .move(edge: .trailing).combined(with: .opacity)
    }

    // NEW in 3.0: Zone transitions

    /// Zone 3 detail panel sliding in from trailing.
    public static var floZoneDetail: AnyTransition {
        #if canImport(UIKit)
        let reduced = UIAccessibility.isReduceMotionEnabled
        #else
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #endif
        return reduced ? .opacity : .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }
}

// MARK: - View Modifiers

extension View {

    /// Entrance animation (fade + slide up).
    public func floEntrance(delay: Double = 0, offset: CGFloat = 20) -> some View {
        modifier(FLOEntranceModifier(delay: delay, offset: offset))
    }

    /// Staggered entrance for list items.
    public func floStaggeredEntrance(index: Int, baseDelay: Double = 0.05, offset: CGFloat = 10) -> some View {
        modifier(FLOStaggeredEntranceModifier(index: index, baseDelay: baseDelay, offset: offset))
    }

    /// Scale feedback for pressed cards/buttons.
    public func floCardScale(isPressed: Bool) -> some View {
        modifier(FLOCardScaleModifier(isPressed: isPressed))
    }

    /// Fade in/out.
    public func floFade(isVisible: Bool, duration: Double = 0.3) -> some View {
        modifier(FLOFadeModifier(isVisible: isVisible, duration: duration))
    }

    /// Slide in/out from edge.
    public func floSlide(isVisible: Bool, edge: Edge = .trailing) -> some View {
        modifier(FLOSlideModifier(isVisible: isVisible, edge: edge))
    }

    /// Shimmer loading effect (respects Reduce Motion + Reduce Transparency).
    public func floShimmer(isActive: Bool = true) -> some View {
        modifier(FLOShimmerModifier(isActive: isActive))
    }

    /// Pulse animation for attention.
    public func floPulse(isActive: Bool = true) -> some View {
        modifier(FLOPulseModifier(isActive: isActive))
    }

    /// FLO button press feedback style.
    public func floButtonStyle() -> some View {
        self.buttonStyle(FLOButtonStyle())
    }
}

// MARK: - Modifier Implementations

struct FLOEntranceModifier: ViewModifier {
    let delay: Double
    let offset: CGFloat
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isVisible ? 1 : 0.001))
            .offset(y: reduceMotion ? 0 : (isVisible ? 0 : offset))
            .onAppear {
                if reduceMotion { isVisible = true }
                else { withAnimation(FLOAnimation.standard.delay(delay)) { isVisible = true } }
            }
    }
}

struct FLOStaggeredEntranceModifier: ViewModifier {
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
                if reduceMotion { isVisible = true }
                else { withAnimation(FLOAnimation.staggered(index: index, baseDelay: baseDelay)) { isVisible = true } }
            }
    }
}

struct FLOCardScaleModifier: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.97 : 1.0))
            .animation(reduceMotion ? .none : FLOAnimation.quick, value: isPressed)
    }
}

struct FLOFadeModifier: ViewModifier {
    let isVisible: Bool
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.001)
            .animation(reduceMotion ? .none : .easeInOut(duration: duration), value: isVisible)
    }
}

struct FLOSlideModifier: ViewModifier {
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

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0.001)
            .offset(
                x: reduceMotion ? 0 : ((edge == .leading || edge == .trailing) ? (isVisible ? 0 : offsetValue) : 0),
                y: reduceMotion ? 0 : ((edge == .top || edge == .bottom) ? (isVisible ? 0 : offsetValue) : 0)
            )
            .animation(FLOAnimation.standard, value: isVisible)
    }
}

struct FLOShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldAnimate: Bool {
        isActive && !reduceMotion
    }

    func body(content: Content) -> some View {
        if shouldAnimate {
            content
                .overlay(
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.4), .clear],
                            startPoint: .leading, endPoint: .trailing
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

struct FLOPulseModifier: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isActive && isPulsing ? 1.05 : 1.0))
            .opacity(reduceMotion ? 1.0 : (isActive && isPulsing ? 0.9 : 1.0))
            .onAppear {
                guard isActive && !reduceMotion else { return }
                withAnimation(FLOAnimation.pulse) { isPulsing = true }
            }
    }
}

// MARK: - Button Style

/// Button style with press feedback animation.
public struct FLOButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.96 : 1.0))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(reduceMotion ? .none : FLOAnimation.quick, value: configuration.isPressed)
    }
}
