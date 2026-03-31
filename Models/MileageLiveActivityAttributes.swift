//  MileageLiveActivityAttributes.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Mileage Live Activity Data Model
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLO (main app target) — used by MileageLiveActivityManager
//  ✅ FLOWidgetExtension — used by FLOWidgetLiveActivity UI
//
//  This file MUST be in both targets. If you see "Cannot find type
//  'MileageLiveActivityAttributes' in scope", check target membership
//  in Xcode File Inspector (right panel → Target Membership).
//

#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import Foundation

struct MileageLiveActivityAttributes: ActivityAttributes {
    
    // MARK: - Fixed Properties (set at trip start, don't change)
    
    /// Unique trip identifier
    let tripId: UUID
    
    /// Starting address (geocoded)
    let startAddress: String
    
    /// Trip start time (used for elapsed timer)
    let startTime: Date
    
    // MARK: - Dynamic Properties (updated as trip progresses)
    
    struct ContentState: Codable, Hashable {
        /// Current trip distance in miles
        let distanceMiles: Double
        
        /// Elapsed time in seconds since trip start
        let elapsedSeconds: TimeInterval
        
        /// Estimated tax deduction (distance × IRS rate)
        let estimatedDeduction: Double
        
        /// Whether tracking is currently paused
        let isPaused: Bool
        
        /// GPS signal quality: "strong", "weak", or "searching"
        let gpsSignal: String
    }
}
#endif // canImport(ActivityKit) && !os(macOS)
