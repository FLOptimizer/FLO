//  FLOWidgetBundle.swift
//  FLO - Finance Ledger OptimizerWidget
//
//  Version 1.1 - Control Widget Enabled
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CURRENT WIDGETS:
//  - FLOWidget: Home screen widget (small, medium, large sizes)
//  - FLOMileageControl: iOS 18+ Control Center toggle (ENABLED)
//
//  INTEGRATION STATUS:
//  ✅ FLOWidget - Implemented and working
//  ✅ FLOMileageControl - ControlWidget ENABLED
//  🚧 FLOWidgetLiveActivity - Live Activity (implement when needed)
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
        
        // ✅ WHEN READY: Add Live Activity
        // Uncomment when FLOWidgetLiveActivity is implemented
        /*
        FLOWidgetLiveActivity()
        */
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
 
 1. Create FLOWidgetLiveActivity.swift
 2. Define ActivityAttributes and ActivityConfiguration
 3. Add to FLOWidget target
 4. Uncomment the FLOWidgetLiveActivity() line above
 5. Build and run
 
 EXAMPLE STRUCTURE:
 ```swift
 struct FLOWidgetLiveActivity: Widget {
     var body: some WidgetConfiguration {
         ActivityConfiguration(for: FLOAttributes.self) { context in
             // Live Activity lock screen view
         } dynamicIsland: { context in
             // Dynamic Island compact/expanded views
         }
     }
 }
 ```
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
    - ActivityConfiguration: Live Activities with Dynamic Island
 
 3. TARGET MEMBERSHIP:
    - All widget files must be in FLOWidget target
    - Shared code (WidgetDataService) in both app and widget targets
    - Models used by widgets need to be in widget target
 
 4. TROUBLESHOOTING "NOT IN SCOPE":
    - Check file's target membership in File Inspector
    - Verify file is actually in Xcode project navigator
    - Clean build folder (⇧⌘K) and rebuild (⌘B)
    - Check for typos in struct names
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
