//  MileageLiveActivityManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed #endif syntax errors
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLO (main app target ONLY — not widget extension)
//
//  CHANGES v1.1:
//  ✅ FIXED: #endif syntax — added // comment prefix before canImport(ActivityKit)
//
//  CHANGES v1.0:
//  ✅ ADDED: startActivity() - Begins Live Activity when trip starts
//  ✅ ADDED: updateActivity() - Updates distance, time, pause state, GPS signal
//  ✅ ADDED: endActivity() - Ends Live Activity with 5-minute dismissal delay
//  ✅ ADDED: endAllActivities() - Cleanup for stale activities on app launch
//  ✅ ADDED: IRS rate calculation (0.725 for 2026 = 72.5¢/mile)
//  ✅ ADDED: Comprehensive logging for debugging
//  ✅ ADDED: Authorization check before starting activity

#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation
import os

@available(iOS 16.1, *)
@MainActor
final class MileageLiveActivityManager {
    
    static let shared = MileageLiveActivityManager()
    private init() {}
    
    private let logger = Logger(subsystem: "com.finchandpoppy.flo", category: "LiveActivity")
    
    #if canImport(ActivityKit)
    /// The currently active Live Activity (nil if none)
    private var currentActivity: Activity<MileageLiveActivityAttributes>?
    #endif
    
    // MARK: - Start Live Activity
    
    /// Called from MileageTrackingService.startNewTrip(at:)
    /// Begins a new Live Activity to show trip progress on Lock Screen and Dynamic Island
    func startActivity(tripId: UUID, startAddress: String, startTime: Date) {
        #if canImport(ActivityKit)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning("Live Activities not enabled by user")
            return
        }
        
        let attributes = MileageLiveActivityAttributes(
            tripId: tripId,
            startAddress: startAddress,
            startTime: startTime
        )
        
        let initialState = MileageLiveActivityAttributes.ContentState(
            distanceMiles: 0.0,
            elapsedSeconds: 0,
            estimatedDeduction: 0.0,
            isPaused: false,
            gpsSignal: "searching"
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil  // No push updates, local only
            )
            currentActivity = activity
            logger.info("✅ Live Activity started: \(activity.id)")
        } catch {
            logger.error("❌ Failed to start Live Activity: \(error.localizedDescription)")
        }
        #endif // canImport(ActivityKit)
    }
    
    // MARK: - Update Live Activity
    
    /// Called from MileageTrackingService.updateCurrentTrip(with:)
    /// Updates the Live Activity with current trip progress (distance, time, GPS status)
    func updateActivity(
        distanceMiles: Double,
        elapsedSeconds: TimeInterval,
        isPaused: Bool,
        gpsSignal: String
    ) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else {
            logger.debug("No active Live Activity to update")
            return
        }
        
        let irsRate = 0.725  // 2026 IRS rate (72.5¢/mile)
        let state = MileageLiveActivityAttributes.ContentState(
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsedSeconds,
            estimatedDeduction: distanceMiles * irsRate,
            isPaused: isPaused,
            gpsSignal: gpsSignal
        )
        
        Task {
            await activity.update(
                ActivityContent(state: state, staleDate: nil)
            )
            logger.debug("Live Activity updated: \(String(format: "%.1f mi", distanceMiles)), paused: \(isPaused)")
        }
        #endif // canImport(ActivityKit)
    }
    
    // MARK: - End Live Activity
    
    /// Called from MileageTrackingService.endCurrentTrip(reason:)
    /// Ends the Live Activity, keeping it visible for 5 minutes to show final stats
    func endActivity(finalDistanceMiles: Double, finalElapsedSeconds: TimeInterval) {
        #if canImport(ActivityKit)
        guard let activity = currentActivity else {
            logger.debug("No active Live Activity to end")
            return
        }
        
        let irsRate = 0.725  // 2026 IRS rate (72.5¢/mile)
        let finalState = MileageLiveActivityAttributes.ContentState(
            distanceMiles: finalDistanceMiles,
            elapsedSeconds: finalElapsedSeconds,
            estimatedDeduction: finalDistanceMiles * irsRate,
            isPaused: false,
            gpsSignal: "strong"
        )
        
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(.now + 300)  // Stay on lock screen 5 min after trip ends
            )
            currentActivity = nil
            logger.info("✅ Live Activity ended: \(String(format: "%.1f mi", finalDistanceMiles))")
        }
        #endif // canImport(ActivityKit)
    }
    
    // MARK: - End All Activities (cleanup)
    
    /// Ends any stale activities on app launch
    /// Call this from MileageTrackingService.startTracking() to clean up orphaned activities
    func endAllActivities() {
        #if canImport(ActivityKit)
        Task {
            let activities = Activity<MileageLiveActivityAttributes>.activities
            guard !activities.isEmpty else {
                logger.debug("No stale Live Activities to clear")
                return
            }
            
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
            logger.info("🧹 All stale Live Activities cleared (\(activities.count) removed)")
        }
        #endif // canImport(ActivityKit)
    }
}
