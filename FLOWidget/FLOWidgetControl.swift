//  FLOWidgetControl.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Elite iOS 18 Control Widget (Final)
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.5:
//  - REMOVED: @main bundle declaration
//  - This ControlWidget is registered in FLOWidgetBundle.swift
//  - Prevents "multiple @main" compilation error
//  - Must be added to FLOWidget target membership
//

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Custom Errors

enum MileageTimerError: Error, LocalizedError {
    case stateFetchFailed
    case updateFailed
    case notificationPostFailed
    
    var errorDescription: String? {
        switch self {
        case .stateFetchFailed:
            return NSLocalizedString("mileage.error.fetch", comment: "Failed to fetch timer state")
        case .updateFailed:
            return NSLocalizedString("mileage.error.update", comment: "Failed to update timer state")
        case .notificationPostFailed:
            return NSLocalizedString("mileage.error.notification", comment: "Failed to notify app")
        }
    }
}

// MARK: - Control Widget Configuration

@available(iOS 18.0, *)
struct FLOMileageControl: ControlWidget {
    
    static let kind: String = "com.finchandpoppy.flo.MileageControl"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: Self.kind,
            provider: MileageTimerProvider()
        ) { isRunning in
            ControlWidgetToggle(
                isOn: isRunning,
                action: ToggleMileageTimerIntent()
            ) {
                Label {
                    Text(
                        isRunning ? "mileage.timer.running" : "mileage.timer.stopped",
                        bundle: .main,
                        comment: "Mileage timer status"
                    )
                } icon: {
                    Image(systemName: isRunning ? "car.fill" : "car")
                        .foregroundStyle(isRunning ? Color.green : Color.gray)
                }
                .accessibilityHint(
                    Text(
                        isRunning ? "mileage.timer.running.hint" : "mileage.timer.stopped.hint",
                        bundle: .main,
                        comment: "Hint for timer toggle"
                    )
                )
            }
        }
        .displayName("Mileage Timer")
        .description("Start or stop tracking mileage")
    }
}

// MARK: - Control Value Provider

@available(iOS 18.0, *)
struct MileageTimerProvider: ControlValueProvider {
    
    var previewValue: Bool {
        false
    }
    
    func currentValue() async throws -> Bool {
        do {
            let state = try await WidgetDataService.shared.fetchTimerState()
            return state.isRunning
        } catch {
            print("⚠️ Failed to fetch timer state: \(error.localizedDescription)")
            throw MileageTimerError.stateFetchFailed
        }
    }
}

// MARK: - Toggle Intent

@available(iOS 18.0, *)
struct ToggleMileageTimerIntent: SetValueIntent {
    
    static let title: LocalizedStringResource = "Toggle Mileage Timer"
    static let description: IntentDescription = "Start or stop mileage tracking"
    
    @Parameter(title: "Is Running")
    var value: Bool
    
    @MainActor
    func perform() async throws -> some IntentResult {
        do {
            let currentState = try await WidgetDataService.shared.fetchTimerState()
            let newState: WidgetTimerState
            
            if value {
                // Start timer
                newState = WidgetTimerState(
                    isRunning: true,
                    startTime: Date(),
                    elapsedSeconds: 0,
                    tripId: UUID()
                )
                print("▶️ Mileage timer started from Control Widget")
                await postTimerNotification(action: .start, tripId: newState.tripId)
                
            } else {
                // Stop timer
                let elapsed = currentState.startTime.map {
                    Date().timeIntervalSince($0) + currentState.elapsedSeconds
                } ?? currentState.elapsedSeconds
                
                newState = WidgetTimerState(
                    isRunning: false,
                    startTime: nil,
                    elapsedSeconds: elapsed,
                    tripId: currentState.tripId
                )
                print("⏹️ Mileage timer stopped from Control Widget")
                await postTimerNotification(action: .stop, tripId: currentState.tripId)
            }
            
            try await WidgetDataService.shared.updateTimerState(newState)
            
            return .result(
                value: value,
                dialog: IntentDialog(
                    stringLiteral: value
                        ? "Mileage tracking started"
                        : "Mileage tracking stopped"
                )
            )
            
        } catch let error as MileageTimerError {
            print("❌ Mileage timer error: \(error.localizedDescription)")
            return .result(
                value: !value,
                dialog: IntentDialog(stringLiteral: "Failed to update timer")
            )
        } catch {
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Posts notification to main app
    /// - Parameters:
    ///   - action: Timer action (start/stop)
    ///   - tripId: Optional trip identifier
    private nonisolated func postTimerNotification(action: TimerAction, tripId: UUID?) async {
        let notificationName: Notification.Name = action == .start
            ? .mileageTimerStartRequested
            : .mileageTimerStopRequested
        
        await MainActor.run {
            var userInfo: [AnyHashable: Any] = [
                "source": "ControlWidget",
                "timestamp": Date()
            ]
            
            if let tripId = tripId {
                userInfo["tripId"] = tripId.uuidString
            }
            
            NotificationCenter.default.post(
                name: notificationName,
                object: nil,
                userInfo: userInfo
            )
        }
    }
    
    enum TimerAction {
        case start
        case stop
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let mileageTimerStartRequested = Notification.Name("com.finchandpoppy.flo.mileageTimerStart")
    static let mileageTimerStopRequested = Notification.Name("com.finchandpoppy.flo.mileageTimerStop")
}

// MARK: - Registration

/*
 This ControlWidget is registered in FLOWidgetBundle.swift:
 
 ```swift
 @main
 struct FLOWidgetBundle: WidgetBundle {
     var body: some Widget {
         FLOWidget()
         
         if #available(iOS 18.0, *) {
             FLOMileageControl()  // ← Registered here
         }
     }
 }
 ```
 
 IMPORTANT:
 - This file must be in the FLOWidget target
 - Do NOT add @main to this file
 - Only ONE @main per target (in FLOWidgetBundle.swift)
 */

// MARK: - Testing

/*
 Control Widgets cannot be previewed in Xcode like regular widgets.
 
 To test:
 1. Build and run the widget extension on a device (iOS 18+)
 2. Go to Settings → Control Center
 3. Add "Mileage Timer" to Control Center
 4. Swipe down to open Control Center
 5. Test the toggle functionality
 
 The previewValue property in MileageTimerProvider is used by the system
 when displaying the control in Control Center settings.
 */

// MARK: - Localized Strings

// Add these to Localizable.strings:
/*
 "mileage.timer.running" = "Tracking";
 "mileage.timer.stopped" = "Mileage";
 "mileage.timer.running.hint" = "Double-tap to stop tracking mileage";
 "mileage.timer.stopped.hint" = "Double-tap to start tracking mileage";
 "mileage.error.fetch" = "Unable to retrieve current timer state";
 "mileage.error.update" = "Unable to save new timer state";
 "mileage.error.notification" = "Unable to notify the app";
 */
