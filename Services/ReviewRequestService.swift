//  ReviewRequestService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Smart App Store review prompting
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Requests an App Store rating only after the user has had repeated genuine
//  wins, never in the first session, and at most once per app version.
//  Call `recordSuccessMoment()` from flows where something just went right
//  (receipt scanned, trip classified, invoice paid). The actual prompt is
//  presented by the root view via the SwiftUI `requestReview` environment
//  action, driven by `shouldRequestReview`.
//

import Foundation
import SwiftUI
import StoreKit

@MainActor
final class ReviewRequestService: ObservableObject {

    static let shared = ReviewRequestService()

    /// Set to true when guardrails pass; the root view observes this,
    /// presents the system prompt, then calls `promptShown()`.
    @Published var shouldRequestReview = false

    // MARK: - Tuning

    /// Success moments required before we consider prompting
    private let minimumSuccessMoments = 3
    /// Never prompt within this many days of first launch
    private let minimumDaysSinceFirstLaunch = 2
    /// Minimum days between prompts (Apple also enforces 3/year)
    private let minimumDaysBetweenPrompts = 60

    // MARK: - Persistence keys

    private enum Key {
        static let firstLaunchDate = "review.firstLaunchDate"
        static let successMomentCount = "review.successMomentCount"
        static let lastPromptDate = "review.lastPromptDate"
        static let lastPromptedVersion = "review.lastPromptedVersion"
    }

    private let defaults = UserDefaults.standard

    private init() {
        if defaults.object(forKey: Key.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: Key.firstLaunchDate)
        }
    }

    // MARK: - API

    /// Record that the user just had a genuine win. Cheap; call freely from
    /// success paths. May flip `shouldRequestReview` when guardrails pass.
    func recordSuccessMoment() {
        let count = defaults.integer(forKey: Key.successMomentCount) + 1
        defaults.set(count, forKey: Key.successMomentCount)

        guard count >= minimumSuccessMoments else { return }
        guard daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch else { return }
        guard currentVersion != defaults.string(forKey: Key.lastPromptedVersion) else { return }
        if let last = defaults.object(forKey: Key.lastPromptDate) as? Date,
           daysBetween(last, Date()) < minimumDaysBetweenPrompts {
            return
        }

        shouldRequestReview = true
    }

    /// Call after the system prompt was requested so we don't ask again
    /// for this version.
    func promptShown() {
        shouldRequestReview = false
        defaults.set(Date(), forKey: Key.lastPromptDate)
        defaults.set(currentVersion, forKey: Key.lastPromptedVersion)
        defaults.set(0, forKey: Key.successMomentCount)
    }

    // MARK: - Helpers

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var daysSinceFirstLaunch: Int {
        guard let first = defaults.object(forKey: Key.firstLaunchDate) as? Date else { return 0 }
        return daysBetween(first, Date())
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int {
        Calendar.current.dateComponents([.day], from: a, to: b).day ?? 0
    }
}

// MARK: - Root-view trigger

/// Attach once at the app root. Presents the system rating prompt when
/// ReviewRequestService decides the moment is right.
struct ReviewRequestModifier: ViewModifier {
    @Environment(\.requestReview) private var requestReview
    @ObservedObject private var service = ReviewRequestService.shared

    func body(content: Content) -> some View {
        content
            .onChange(of: service.shouldRequestReview) { _, shouldRequest in
                guard shouldRequest else { return }
                // Small delay so the prompt lands after the success animation,
                // not on top of it
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    requestReview()
                    service.promptShown()
                }
            }
    }
}

extension View {
    /// Enables smart App Store review prompting for this view hierarchy.
    func reviewRequestPrompting() -> some View {
        modifier(ReviewRequestModifier())
    }
}
