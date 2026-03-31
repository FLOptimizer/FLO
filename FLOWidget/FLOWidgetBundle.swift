//  FLOWidgetBundle.swift
//  FLO - Finance Ledger OptimizerWidget
//
//  Version 1.2 - Live Activity Enabled
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  - ✅ ENABLED: FLOWidgetLiveActivity for Mileage tracking
//  - ✅ ADDED: Live Activity appears on Lock Screen and Dynamic Island
//  - ✅ UPDATED: Integration documentation for Live Activities
//
//  CURRENT WIDGETS:
//  - FLOWidget: Home screen widget (small, medium, large sizes)
//  - FLOMileageControl: iOS 18+ Control Center toggle (ENABLED)
//  - FLOWidgetLiveActivity: Mileage Live Activity (ENABLED)
//
//  INTEGRATION STATUS:
//  ✅ FLOWidget - Implemented and working
//  ✅ FLOMileageControl - ControlWidget ENABLED
//  ✅ FLOWidgetLiveActivity - Mileage Live Activity ENABLED
//

import WidgetKit
import SwiftUI

@main
struct FLOWidgetBundle: WidgetBundle {
    var body: some Widget {
        FLOWidget()
        
        // ✅ iOS 18 Control Widget - ENABLED
        if #available(iOS 18.0, *) {
            FLOMileageControl()
        }
        
        // ✅ Live Activity - ENABLED (iOS only, ActivityKit unavailable on macOS)
        #if os(iOS)
        FLOWidgetLiveActivity()
        #endif
    }
}

// MARK: - Integration Guide

/*
 HOW TO ADD CONTROL WIDGET (iOS 18):
 
 1. Ensure FLOWidgetControl.swift is in your widget target
 2. Ensure WidgetDataService.swift is in BOTH main app and widget targets
 3. The FLOMileageControl() line above is now uncommented
 4. Build and run
 
 WHY IT MIGHT NOT BE IN SCOPE:
 - File not added to FLOWidget target (check target membership)
 - File is in a different target entirely
 - Naming mismatch (struct should be FLOMileageControl)
 */

/*
 HOW TO ADD LIVE ACTIVITY:
 
 ✅ COMPLETED - FLOWidgetLiveActivity is now ENABLED
 
 1. ✅ Created FLOWidgetLiveActivity.swift with MileageLiveActivityAttributes
 2. ✅ Defined ActivityConfiguration with Lock Screen and Dynamic Island UI
 3. ✅ Added to FLOWidget target (and main app target for attributes)
 4. ✅ Uncommented the FLOWidgetLiveActivity() line in bundle
 5. ⚠️  REQUIRED: Add NSSupportsLiveActivities to Info.plist (see below)
 
 LIVE ACTIVITY FEATURES:
 - Lock Screen banner with distance, time, estimated deduction
 - Dynamic Island expanded view with full trip details
 - Dynamic Island compact view with car icon + distance
 - GPS signal indicator (strong/weak/searching)
 - Paused state indicator
 - Deep linking to flo://mileage
 
 TARGET MEMBERSHIP REQUIREMENTS:
 - FLOWidgetLiveActivity.swift → BOTH main app AND FLOWidget targets
   (Main app needs MileageLiveActivityAttributes for manager)
 - MileageLiveActivityManager.swift → Main app target ONLY
 - FLOWidgetBundle.swift → FLOWidget target ONLY
 */

// MARK: - Architecture Notes

/*
 WIDGET BUNDLE BEST PRACTICES:
 
 1. ONE @main PER TARGET
    - This file has @main for FLOWidget target
    - Do NOT add @main in widget implementation files
 
 2. WIDGET TYPES SUPPORTED:
    - Widget (home screen): .systemSmall, .systemMedium, .systemLarge
    - ControlWidget (iOS 18): Control Center toggles/buttons
    - ActivityConfiguration: Live Activities with Dynamic Island ✅ ENABLED
 
 3. TARGET MEMBERSHIP:
    - All widget files must be in FLOWidget target
    - Shared code (WidgetDataService) in both app and widget targets
    - Models used by widgets need to be in widget target
    - ⚠️  SPECIAL: FLOWidgetLiveActivity.swift must be in BOTH targets
      (Main app needs MileageLiveActivityAttributes for the manager)
 
 4. TROUBLESHOOTING "NOT IN SCOPE":
    - Check file's target membership in File Inspector
    - Verify file is actually in Xcode project navigator
    - Clean build folder (⇧⌘K) and rebuild (⌘B)
    - Check for typos in struct names
 
 5. LIVE ACTIVITY SETUP (IMPORTANT):
    - ⚠️  REQUIRED: Add NSSupportsLiveActivities to main app's Info.plist
    - See setup instructions below
 */

// MARK: - Live Activity Setup Instructions

/*
 ⚠️  REQUIRED SETUP: Info.plist Configuration
 
 The main app's Info.plist MUST include:
 
    <key>NSSupportsLiveActivities</key>
    <true/>
 
 HOW TO ADD IN XCODE:
 
 1. Select the FLO target (main app, not widget extension)
 2. Go to the "Info" tab
 3. Look for "Custom iOS Target Properties"
 4. Click the "+" button to add a new row
 5. Type "Supports Live Activities" (or paste NSSupportsLiveActivities)
 6. Set the value to "YES" (boolean)
 7. Build and run
 
 VERIFICATION:
 - If you see the key in Info.plist, Live Activities are enabled
 - If missing, Live Activities will silently fail to start
 - Check MileageLiveActivityManager logs for authorization warnings
 
 TARGET MEMBERSHIP CHECKLIST:
 
 ✅ FLOWidget target (widget extension):
    - FLOWidgetLiveActivity.swift ✅
    - FLOWidgetBundle.swift ✅
    - FLOWidget.swift ✅
    - FLOWidgetControl.swift ✅
    - WidgetDataService.swift ✅
 
 ✅ Main App target (FLO):
    - MileageLiveActivityManager.swift ✅
    - MileageTrackingService.swift ✅
    - FLOWidgetLiveActivity.swift ⚠️  MUST BE IN BOTH TARGETS
    - WidgetDataService.swift ✅
 
 WHY BOTH TARGETS?
 - FLOWidgetLiveActivity.swift contains MileageLiveActivityAttributes
 - The main app's MileageLiveActivityManager imports this struct
 - The widget extension uses it for UI rendering
 - Both need access to the same struct definition
 
 ALTERNATIVE APPROACH:
 If having the file in both targets causes build issues (duplicate widget
 registration), you can extract JUST the MileageLiveActivityAttributes
 struct into a separate file:
 
    - Create: MileageLiveActivityAttributes.swift
    - Contains: Only the ActivityAttributes struct
    - Add to: BOTH main app AND widget targets
    - Keep: FLOWidgetLiveActivity.swift in widget target only
 */

// MARK: - Future Widget Ideas

/*
 ADDITIONAL WIDGETS TO CONSIDER:
 
 1. Balance Widget (Small/Medium):
    - Current net balance with trend indicator
    - Quick income vs expenses comparison
    - Color-coded profit/loss
 
 2. Quick Add Widget (Medium):
    - Button to quickly add transaction
    - Shows last 3 transactions
    - Opens app to specific screen
 
 3. Invoice Widget (Medium/Large):
    - Pending invoices count and total
    - Overdue invoice warnings
    - Next payment deadline
 
 4. Tax Deadline Widget (Small):
    - Days until next quarterly deadline
    - Estimated tax owed
    - Red warning when <7 days
 
 5. Mileage Widget (Small):
    - Current trip mileage
    - This week's total miles
    - Estimated deduction amount
 */
