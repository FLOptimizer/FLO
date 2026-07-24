//  StateModifiers.swift
//  FLODesignSystem
//
//  Interactive state modifiers extracted from FLO/Extensions/View+Modifiers.swift.
//  Phase 2 of the FLODesignSystem migration (Build 10).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Interactive States

extension View {

    /// Disabled state styling.
    /// Use for buttons/controls that are temporarily unavailable.
    public func floDisabled(_ isDisabled: Bool) -> some View {
        self
            .opacity(isDisabled ? 0.5 : 1.0)
            .allowsHitTesting(!isDisabled)
    }

    /// Loading overlay.
    /// Use while waiting for async operations.
    public func floLoading(_ isLoading: Bool, message: String? = nil) -> some View {
        self
            .overlay {
                if isLoading {
                    ZStack {
                        #if canImport(UIKit)
                        Color(.systemBackground).opacity(0.8)
                        #else
                        Color(nsColor: .windowBackgroundColor).opacity(0.8)
                        #endif
                        VStack(spacing: 12) {
                            ProgressView()
                            if let message = message {
                                Text(message)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(!isLoading)
    }

    /// Press state for interactive elements.
    /// Use for custom buttons, cards.
    public func floPressable(isPressed: Bool, scale: CGFloat = 0.97) -> some View {
        self
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Empty State

extension View {

    /// Empty state overlay.
    /// Use when lists/collections are empty.
    public func floEmptyState(
        isEmpty: Bool,
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        self.overlay {
            if isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: icon)
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    Text(message)
                        .font(.subheadline)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let actionTitle = actionTitle, let action = action {
                        Button(action: action) {
                            Text(actionTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .floPillButton()
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(32)
            }
        }
    }
}
