//  FLOWatchApp.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Apple Watch App Entry Point
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target — has @main)
//
//  ARCHITECTURE:
//  The Watch app is a thin client that displays data from WatchSnapshot.
//  All data comes from the iPhone via WatchConnectivity.
//  The Watch never accesses SwiftData directly.
//
//  NAVIGATION:
//  Tab-based layout with 3-4 tabs depending on subscription tier:
//  1. Summary (all tiers) — today's spending, recent transactions
//  2. Add Expense (all tiers) — quick expense entry
//  3. Mileage (Premium+) — trip control
//  4. Tax (Premium+) — quarterly estimate
//

import SwiftUI

@main
struct FLOWatchApp: App {
    
    @StateObject private var sessionManager = WatchSessionManager.shared
    
    init() {
        // Activate WatchConnectivity on launch
        WatchSessionManager.shared.activateSession()
    }
    
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(sessionManager)
        }
    }
}
