//  AnimationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  NOTE: Animation tokens, transitions, and view modifiers have moved to FLODesignSystem.
//  This file contains only app-level animation helpers that are not part of the design system.
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

// MARK: - App-Only Animation Helpers

/// Cross-platform Reduce Motion check for app-level use
var isReduceMotionEnabled: Bool {
    #if canImport(UIKit)
    UIAccessibility.isReduceMotionEnabled
    #else
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    #endif
}

/// Returns the given animation or .none based on reduce motion setting.
/// App-level convenience for one-off custom animations that should respect accessibility.
func conditionalAnimation(_ animation: Animation) -> Animation {
    if isReduceMotionEnabled {
        return .linear(duration: 0)
    }
    return animation
}
