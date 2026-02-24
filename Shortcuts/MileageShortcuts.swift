//  MileageShortcuts.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Broadened: mileage + core financial shortcuts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  MILEAGE SHORTCUTS:
//  ✅ "Hey Siri, pause mileage tracking in FLO"
//  ✅ "Hey Siri, resume mileage tracking in FLO"
//  ✅ "Hey Siri, check mileage status in FLO"
//
//  CORE SHORTCUTS (defined in FLOCoreShortcuts.swift):
//  ✅ "Hey Siri, add an expense in FLO"
//  ✅ "Hey Siri, add income in FLO"
//  ✅ "Hey Siri, scan a receipt in FLO"
//  ✅ "Hey Siri, what's my tax estimate in FLO"
//
//  9 total shortcuts covering mileage, transactions, receipts, and tax
//
//  SETUP:
//  - Add this file to the main app target
//  - Siri will automatically discover the shortcuts
//  - Users can also find them in Settings → FLO → Siri & Shortcuts
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - Pause Mileage Intent

/// Siri intent to pause/stop mileage tracking
@available(iOS 16.0, *)
struct PauseMileageIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Pause Mileage Tracking"
    static var description = IntentDescription("Stop automatically tracking your trips")
    
    /// Show in Shortcuts app and Siri suggestions
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trackingService = MileageTrackingService.shared
        
        guard trackingService.isTracking else {
            return .result(dialog: "Mileage tracking is already paused.")
        }
        
        trackingService.stopTracking()
        UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
        
        // Update quick action shortcuts
        QuickActionService.shared.updateShortcuts()
        
        return .result(dialog: "Mileage tracking paused. Your trips won't be recorded until you resume.")
    }
}

// MARK: - Resume Mileage Intent

/// Siri intent to resume/start mileage tracking
@available(iOS 16.0, *)
struct ResumeMileageIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Resume Mileage Tracking"
    static var description = IntentDescription("Start automatically tracking your trips")
    
    /// Show in Shortcuts app and Siri suggestions
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trackingService = MileageTrackingService.shared
        
        // Check if already tracking
        guard !trackingService.isTracking else {
            return .result(dialog: "Mileage tracking is already running.")
        }
        
        // Check permission
        guard trackingService.trackingPermissionStatus == .authorizedAlways else {
            return .result(dialog: "I can't start tracking because FLO doesn't have location permission. Please open the app to grant access.")
        }
        
        // Check setup complete
        guard UserDefaults.standard.bool(forKey: "mileageSetupCompleted") else {
            return .result(dialog: "Mileage tracking hasn't been set up yet. Please open FLO to complete setup first.")
        }
        
        // Ensure ModelContext is injected
        if !trackingService.isContextInjected {
            do {
                let container = try ModelContainer.shared()
                trackingService.inject(modelContext: container.mainContext)
            } catch {
                return .result(dialog: "I couldn't start tracking due to a database error. Please try opening the app.")
            }
        }
        
        trackingService.startTracking()
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        
        // Update quick action shortcuts
        QuickActionService.shared.updateShortcuts()
        
        return .result(dialog: "Mileage tracking started. I'll automatically record your trips.")
    }
}

// MARK: - Check Mileage Status Intent

/// Siri intent to check current mileage tracking status
@available(iOS 16.0, *)
struct CheckMileageStatusIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Check Mileage Status"
    static var description = IntentDescription("Check if mileage tracking is currently active")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trackingService = MileageTrackingService.shared
        
        if trackingService.isTracking {
            if let currentTrip = trackingService.currentTrip {
                let miles = String(format: "%.1f", currentTrip.distanceMiles)
                return .result(dialog: "Mileage tracking is active. You're currently on a trip with \(miles) miles recorded.")
            } else {
                return .result(dialog: "Mileage tracking is active and waiting to detect a trip.")
            }
        } else {
            let setupComplete = UserDefaults.standard.bool(forKey: "mileageSetupCompleted")
            if !setupComplete {
                return .result(dialog: "Mileage tracking hasn't been set up yet. Open FLO to get started.")
            } else {
                return .result(dialog: "Mileage tracking is paused. Say 'Resume mileage tracking' to start.")
            }
        }
    }
}

// MARK: - Toggle Mileage Intent

/// Siri intent to toggle mileage tracking on/off
@available(iOS 16.0, *)
struct ToggleMileageIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Toggle Mileage Tracking"
    static var description = IntentDescription("Turn mileage tracking on or off")
    
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trackingService = MileageTrackingService.shared
        
        if trackingService.isTracking {
            // Currently on, turn off
            trackingService.stopTracking()
            UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
            QuickActionService.shared.updateShortcuts()
            return .result(dialog: "Mileage tracking paused.")
        } else {
            // Currently off, turn on
            guard trackingService.trackingPermissionStatus == .authorizedAlways else {
                return .result(dialog: "I can't start tracking because FLO doesn't have location permission.")
            }
            
            guard UserDefaults.standard.bool(forKey: "mileageSetupCompleted") else {
                return .result(dialog: "Mileage tracking hasn't been set up yet. Please open FLO first.")
            }
            
            if !trackingService.isContextInjected {
                do {
                    let container = try ModelContainer.shared()
                    trackingService.inject(modelContext: container.mainContext)
                } catch {
                    return .result(dialog: "I couldn't start tracking due to a database error.")
                }
            }
            
            trackingService.startTracking()
            UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
            QuickActionService.shared.updateShortcuts()
            return .result(dialog: "Mileage tracking started.")
        }
    }
}

// MARK: - App Shortcuts Provider

/// Registers shortcuts with Siri and the Shortcuts app
@available(iOS 16.0, *)
struct FLOShortcutsProvider: AppShortcutsProvider {
    
    /// Define the shortcuts that appear in Siri and Shortcuts app
    static var appShortcuts: [AppShortcut] {
        
        // Pause Mileage Tracking
        AppShortcut(
            intent: PauseMileageIntent(),
            phrases: [
                "Pause mileage tracking in \(.applicationName)",
                "Pause mileage in \(.applicationName)",
                "Stop mileage tracking in \(.applicationName)",
                "Stop tracking mileage in \(.applicationName)",
                "Stop tracking my trips in \(.applicationName)",
                "Pause \(.applicationName) mileage",
                "Turn off mileage in \(.applicationName)"
            ],
            shortTitle: "Pause Mileage",
            systemImageName: "pause.circle.fill"
        )
        
        // Resume Mileage Tracking
        AppShortcut(
            intent: ResumeMileageIntent(),
            phrases: [
                "Resume mileage tracking in \(.applicationName)",
                "Resume mileage in \(.applicationName)",
                "Start mileage tracking in \(.applicationName)",
                "Start tracking mileage in \(.applicationName)",
                "Start tracking my trips in \(.applicationName)",
                "Track my trip in \(.applicationName)",
                "Turn on mileage in \(.applicationName)"
            ],
            shortTitle: "Resume Mileage",
            systemImageName: "play.circle.fill"
        )
        
        // Check Mileage Status
        AppShortcut(
            intent: CheckMileageStatusIntent(),
            phrases: [
                "Check mileage status in \(.applicationName)",
                "Is mileage tracking on in \(.applicationName)",
                "Am I tracking mileage in \(.applicationName)",
                "Mileage status in \(.applicationName)",
                "What's my mileage in \(.applicationName)"
            ],
            shortTitle: "Check Mileage",
            systemImageName: "location.circle.fill"
        )
        
        // Toggle Mileage
        AppShortcut(
            intent: ToggleMileageIntent(),
            phrases: [
                "Toggle mileage tracking in \(.applicationName)",
                "Toggle mileage in \(.applicationName)",
                "Switch mileage tracking in \(.applicationName)"
            ],
            shortTitle: "Toggle Mileage",
            systemImageName: "arrow.triangle.2.circlepath.circle.fill"
        )
        
        // MARK: - Core Financial Shortcuts (intents in FLOCoreShortcuts.swift)
        
        // Add Expense
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add an expense in \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Record an expense in \(.applicationName)",
                "New expense in \(.applicationName)",
                "Add a transaction in \(.applicationName)"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
        
        // Add Income
        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Add income in \(.applicationName)",
                "Log income in \(.applicationName)",
                "Record a payment in \(.applicationName)",
                "I got paid in \(.applicationName)",
                "New income in \(.applicationName)"
            ],
            shortTitle: "Add Income",
            systemImageName: "dollarsign.circle.fill"
        )
        
        // Scan Receipt
        AppShortcut(
            intent: ScanReceiptIntent(),
            phrases: [
                "Scan a receipt in \(.applicationName)",
                "Log a receipt in \(.applicationName)",
                "Capture a receipt in \(.applicationName)",
                "Take a receipt photo in \(.applicationName)",
                "Save a receipt in \(.applicationName)"
            ],
            shortTitle: "Scan Receipt",
            systemImageName: "doc.text.viewfinder"
        )
        
        // Check Tax Estimate
        AppShortcut(
            intent: CheckTaxEstimateIntent(),
            phrases: [
                "What's my tax estimate in \(.applicationName)",
                "Check my tax estimate in \(.applicationName)",
                "How much do I owe in taxes in \(.applicationName)",
                "Quarterly tax in \(.applicationName)",
                "Tax estimate in \(.applicationName)"
            ],
            shortTitle: "Tax Estimate",
            systemImageName: "chart.bar.doc.horizontal.fill"
        )
    }
}

// MARK: - Intent Errors

@available(iOS 16.0, *)
enum MileageIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSetUp
    case noPermission
    case alreadyTracking
    case notTracking
    case databaseError
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSetUp:
            return "Mileage tracking hasn't been set up yet."
        case .noPermission:
            return "Location permission is required for mileage tracking."
        case .alreadyTracking:
            return "Mileage tracking is already active."
        case .notTracking:
            return "Mileage tracking is not currently active."
        case .databaseError:
            return "Could not access the database."
        }
    }
}

// MARK: - Preview & Debug

#if DEBUG
@available(iOS 16.0, *)
extension PauseMileageIntent {
    static var preview: PauseMileageIntent {
        PauseMileageIntent()
    }
}

@available(iOS 16.0, *)
extension ResumeMileageIntent {
    static var preview: ResumeMileageIntent {
        ResumeMileageIntent()
    }
}
#endif
