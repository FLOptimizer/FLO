//  TaxNotificationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - User-friendly notification permission flow
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Handles quarterly tax reminder notifications
//
//  CHANGES IN v1.2:
//  ✅ FIXED: Now uses NotificationPermissionHelper for user-friendly explanations
//  ✅ Renamed requestPermission() to checkPermissionGranted() - just checks status
//  ✅ Added requestPermissionWithExplanation() for proper permission flow
//  ✅ Callers should use requestPermissionWithExplanation() before scheduling
//
//  CHANGES IN v1.1:
//  - Added version tracking
//  - Confirmed 2025 quarterly deadlines compatibility (uses TaxSettings v2.1)
//

import Foundation
import UserNotifications
import SwiftData

class TaxNotificationService {
    
    // MARK: - Singleton
    static let shared = TaxNotificationService()
    private init() {}
    
    // Notification identifiers
    private let notificationCategory = "TAX_REMINDER"
    private let q1Identifier = "quarterly_tax_q1"
    private let q2Identifier = "quarterly_tax_q2"
    private let q3Identifier = "quarterly_tax_q3"
    private let q4Identifier = "quarterly_tax_q4"
    
    // MARK: - Permission Handling
    
    /// Check if notification permission is currently granted
    /// Does NOT request permission - use requestPermissionWithExplanation() first
    func checkPermissionGranted() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        let granted = settings.authorizationStatus == .authorized
        
        #if DEBUG
        print(granted ? "✅ Notification permission is granted" : "⚠️ Notification permission not granted")
        #endif
        
        return granted
    }
    
    /// Get current authorization status
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Request permission with user-friendly explanation
    /// Shows a custom alert explaining why we need notifications before the system prompt
    @MainActor
    func requestPermissionWithExplanation() async -> Bool {
        return await withCheckedContinuation { continuation in
            NotificationPermissionHelper.requestWithExplanation(context: .taxReminders) { granted in
                if granted {
                    print("✅ Tax notification permission granted")
                } else {
                    print("⚠️ Tax notification permission denied")
                }
                continuation.resume(returning: granted)
            }
        }
    }
    
    // MARK: - Schedule Quarterly Notifications
    
    /// Schedule all quarterly tax reminder notifications
    /// Uses 2025 deadlines from TaxSettings v2.1: Apr 15, Jun 16, Sep 15, Jan 15
    ///
    /// Important: Caller should use requestPermissionWithExplanation() or
    /// NotificationPermissionHelper before calling this method
    func scheduleQuarterlyReminders(
        settings: TaxSettings,
        estimate: TaxCalculationService.TaxEstimate
    ) async {
        // Cancel existing notifications first
        await cancelAllQuarterlyReminders()
        
        guard settings.enableQuarterlyReminders else {
            print("⏸️ Quarterly reminders disabled")
            return
        }
        
        // v1.2: Check permission status instead of requesting again
        // The caller should have already used NotificationPermissionHelper
        let granted = await checkPermissionGranted()
        guard granted else {
            print("❌ Cannot schedule reminders - permission not granted")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        let deadlines = TaxSettings.quarterlyDeadlines2025
        let identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        
        let quarterlyAmount = estimate.quarterlyPayment
        
        for (index, deadline) in deadlines.enumerated() {
            guard index < identifiers.count else { continue }
            
            let identifier = identifiers[index]
            let reminderDate = Calendar.current.date(
                byAdding: .day,
                value: -settings.reminderDaysBefore,
                to: deadline
            )
            
            guard let reminderDate = reminderDate, reminderDate > Date() else {
                // Skip past deadlines
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Quarterly Tax Payment Due Soon"
            content.body = "Q\(index + 1) estimated tax payment of \(quarterlyAmount.asCurrency) is due on \(deadline.formatted(date: .abbreviated, time: .omitted))"
            content.sound = .default
            content.categoryIdentifier = notificationCategory
            content.userInfo = [
                "type": "quarterly_tax",
                "quarter": index + 1,
                "amount": quarterlyAmount,
                "deadline": deadline.timeIntervalSince1970
            ]
            
            // Create trigger
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            // Create request
            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            
            do {
                try await center.add(request)
                print("📅 Scheduled Q\(index + 1) reminder for \(reminderDate.formatted())")
            } catch {
                print("❌ Error scheduling Q\(index + 1) notification: \(error)")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel all quarterly tax reminder notifications
    func cancelAllQuarterlyReminders() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled all quarterly tax reminders")
    }
    
    /// Cancel a specific quarter's notification
    func cancelQuarterlyReminder(quarter: Int) {
        guard quarter >= 1 && quarter <= 4 else { return }
        
        let identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        let identifier = identifiers[quarter - 1]
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled Q\(quarter) tax reminder")
    }
    
    // MARK: - Check Notification Status
    
    /// Check current notification permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    /// Get list of pending quarterly notifications
    /// Useful for debugging and showing user what's scheduled
    func getPendingQuarterlyReminders() async -> [UNNotificationRequest] {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.starts(with: "quarterly_tax") }
    }
    
    // MARK: - One-Time Reminder
    
    /// Schedule a one-time reminder X days before next deadline
    /// Useful for custom reminder timing
    ///
    /// Important: Caller should ensure notification permission is granted first
    func scheduleOneTimeReminder(
        daysBeforeDeadline: Int,
        amount: Double,
        deadline: Date
    ) async {
        let center = UNUserNotificationCenter.current()
        
        // v1.2: Just check status - don't request again
        let granted = await checkPermissionGranted()
        guard granted else {
            print("❌ Cannot schedule reminder - permission not granted")
            return
        }
        
        guard let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBeforeDeadline,
            to: deadline
        ), reminderDate > Date() else {
            print("❌ Invalid reminder date")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Tax Payment Reminder"
        content.body = "Don't forget: Estimated tax payment of \(amount.asCurrency) is due in \(daysBeforeDeadline) day\(daysBeforeDeadline == 1 ? "" : "s")"
        content.sound = .default
        
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "one_time_tax_reminder_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("📅 Scheduled one-time reminder for \(reminderDate.formatted())")
        } catch {
            print("❌ Error scheduling one-time reminder: \(error)")
        }
    }
    
    // MARK: - Test Notification
    
    /// Send a test notification immediately (for testing purposes)
    /// Useful for verifying notification permissions work
    @MainActor
    func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        
        // v1.2: Request with explanation for test notifications
        let granted = await requestPermissionWithExplanation()
        guard granted else {
            print("❌ Cannot send test notification - permission denied")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "FLO Tax Reminder"
        content.body = "This is a test notification. Your quarterly reminders are working!"
        content.sound = .default
        
        // Trigger in 5 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("🧪 Test notification scheduled for 5 seconds from now")
        } catch {
            print("❌ Error sending test notification: \(error)")
        }
    }
}

// MARK: - Notification Actions

extension TaxNotificationService {
    
    /// Configure notification actions (swipe actions, etc.)
    /// Called during app launch in AppDelegate
    func configureNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // View Details action
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )
        
        // Mark as Paid action
        let paidAction = UNNotificationAction(
            identifier: "MARK_PAID",
            title: "Mark as Paid",
            options: []
        )
        
        // Snooze action
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind Tomorrow",
            options: []
        )
        
        // Create category
        let category = UNNotificationCategory(
            identifier: notificationCategory,
            actions: [viewAction, paidAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([category])
        print("✅ Notification categories configured")
    }
    
    /// Handle notification action response
    /// Called when user interacts with notification
    func handleNotificationAction(_ identifier: String, for notification: UNNotification) {
        switch identifier {
        case "VIEW_DETAILS":
            print("📱 User tapped 'View Details'")
            // App will handle opening to tax details view
            
        case "MARK_PAID":
            print("✅ User marked tax payment as paid")
            // Could create a transaction automatically here
            
        case "SNOOZE":
            print("⏰ User snoozed reminder")
            // Reschedule for tomorrow
            if let amount = notification.request.content.userInfo["amount"] as? Double,
               let deadlineInterval = notification.request.content.userInfo["deadline"] as? TimeInterval {
                let deadline = Date(timeIntervalSince1970: deadlineInterval)
                Task {
                    await scheduleOneTimeReminder(
                        daysBeforeDeadline: 1,
                        amount: amount,
                        deadline: deadline
                    )
                }
            }
            
        default:
            print("❓ Unknown notification action: \(identifier)")
        }
    }
}

// MARK: - Version History
/*
 Version 1.2 (Current):
 - Uses NotificationPermissionHelper for user-friendly permission requests
 - Renamed requestPermission() to checkPermissionGranted()
 - Added requestPermissionWithExplanation() for proper UX flow
 - Methods now check status instead of re-requesting
 
 Version 1.1:
 - Added version tracking
 - Confirmed compatibility with TaxSettings v2.1 (2025 deadlines)
 - Ready for December 2025 launch
 
 Version 1.0:
 - Initial implementation
 - Quarterly reminder scheduling
 - Notification actions (view, mark paid, snooze)
 */
