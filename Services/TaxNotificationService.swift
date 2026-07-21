//  TaxNotificationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 — Use adjustedQuarterlyPayment in notification body
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Handles quarterly tax reminder notifications
//
//  CHANGES IN v1.3:
//  ✅ FIXED: scheduleQuarterlyReminders now reads estimate.adjustedQuarterlyPayment
//            instead of estimate.quarterlyPayment — notifications now quote the
//            after-withholding amount that the user actually needs to pay, not the
//            gross quarterly figure before W-2 withholding credits are applied.
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
    private let genericIdentifierPrefix = "quarterly_tax_generic_"

    // MARK: - Permission Handling

    /// Check if notification permission is currently granted.
    /// Does NOT request permission — use requestPermissionWithExplanation() first.
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

    /// Request permission with user-friendly explanation.
    /// Shows a custom alert explaining why we need notifications before the system prompt.
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

    /// Schedule all quarterly tax reminder notifications.
    /// Uses 2025 deadlines from TaxSettings v2.1: Apr 15, Jun 16, Sep 15, Jan 15.
    ///
    /// v1.3: Uses estimate.adjustedQuarterlyPayment — the after-withholding amount —
    /// so notifications quote what the user actually owes, not gross quarterly tax ÷ 4.
    ///
    /// Important: Caller should use requestPermissionWithExplanation() or
    /// NotificationPermissionHelper before calling this method.
    /// Schedules generic quarterly-deadline reminders for users with business
    /// activity who haven't configured personalized estimates (especially Free
    /// tier — the deadline reminder is free, the estimate itself is Premium).
    /// No amounts, just the deadline. Silently no-ops when notification
    /// permission hasn't been granted; never prompts.
    /// Idempotent — safe to call on every launch.
    func scheduleGenericDeadlineRemindersIfNeeded() async {
        guard await checkPermissionGranted() else { return }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        // Personalized reminders already cover the deadlines — don't double-notify
        let personalizedIds = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        if pending.contains(where: { personalizedIds.contains($0.identifier) }) { return }

        // Refresh: clear old generic reminders, then schedule the remaining ones
        let staleGenericIds = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(genericIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: staleGenericIds)

        let deadlines = TaxSettings.quarterlyDeadlines()
        let calendar = Calendar.current

        for (index, deadline) in deadlines.enumerated() where deadline > Date() {
            for daysBefore in [7, 1] {
                guard let fireDate = calendar.date(byAdding: .day, value: -daysBefore, to: deadline),
                      fireDate > Date() else { continue }

                var components = calendar.dateComponents([.year, .month, .day], from: fireDate)
                components.hour = 9

                let content = UNMutableNotificationContent()
                content.title = daysBefore == 1
                    ? "Estimated taxes due tomorrow"
                    : "Estimated taxes due in one week"
                content.body = "Q\(index + 1) federal estimated taxes are due \(deadline.formatted(date: .abbreviated, time: .omitted)). Open FLO to see where your business stands."
                content.sound = .default
                content.categoryIdentifier = notificationCategory
                content.userInfo = [
                    "type": "quarterly_tax",
                    "quarter": index + 1,
                    "deadline": deadline.timeIntervalSince1970
                ]

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(genericIdentifierPrefix)q\(index + 1)_\(daysBefore)d",
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    func scheduleQuarterlyReminders(
        settings: TaxSettings,
        estimate: TaxCalculationService.TaxEstimate
    ) async {
        await cancelAllQuarterlyReminders()

        guard settings.enableQuarterlyReminders else {
            print("⏸️ Quarterly reminders disabled")
            return
        }

        // v1.2: Check permission status — caller already requested if needed
        let granted = await checkPermissionGranted()
        guard granted else {
            print("❌ Cannot schedule reminders - permission not granted")
            return
        }

        let center      = UNUserNotificationCenter.current()
        // Use the current tax year's deadlines (was hardcoded to 2025, which
        // silently scheduled nothing once those dates passed)
        let deadlines   = TaxSettings.quarterlyDeadlines()
        let identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]

        // v1.3: Use adjustedQuarterlyPayment — after W-2 withholding credit — so
        //       the user sees what they actually need to send to the IRS this quarter,
        //       not the gross figure before employer withholding is credited.
        let quarterlyAmount = estimate.adjustedQuarterlyPayment

        for (index, deadline) in deadlines.enumerated() {
            guard index < identifiers.count else { continue }

            let identifier  = identifiers[index]
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
            content.body  = "Q\(index + 1) estimated tax payment of \(quarterlyAmount.asCurrency) is due on \(deadline.formatted(date: .abbreviated, time: .omitted))"
            content.sound = .default
            content.categoryIdentifier = notificationCategory
            content.userInfo = [
                "type":     "quarterly_tax",
                "quarter":  index + 1,
                "amount":   quarterlyAmount,
                "deadline": deadline.timeIntervalSince1970
            ]

            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: identifier,
                content:    content,
                trigger:    trigger
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
        let center      = UNUserNotificationCenter.current()
        var identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        // Also clear generic deadline reminders — personalized ones replace them
        let pending = await center.pendingNotificationRequests()
        identifiers += pending
            .map(\.identifier)
            .filter { $0.hasPrefix(genericIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🗑️ Cancelled all quarterly tax reminders")
    }

    /// Cancel a specific quarter's notification
    func cancelQuarterlyReminder(quarter: Int) {
        guard quarter >= 1 && quarter <= 4 else { return }
        let identifiers = [q1Identifier, q2Identifier, q3Identifier, q4Identifier]
        let identifier  = identifiers[quarter - 1]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ Cancelled Q\(quarter) tax reminder")
    }

    // MARK: - Check Notification Status

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let center   = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func getPendingQuarterlyReminders() async -> [UNNotificationRequest] {
        let center  = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        return pending.filter { $0.identifier.starts(with: "quarterly_tax") }
    }

    // MARK: - One-Time Reminder

    /// Schedule a one-time reminder X days before next deadline.
    /// Important: Caller should ensure notification permission is granted first.
    func scheduleOneTimeReminder(
        daysBeforeDeadline: Int,
        amount: Double,
        deadline: Date
    ) async {
        let center = UNUserNotificationCenter.current()

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
        content.body  = "Don't forget: Estimated tax payment of \(amount.asCurrency) is due in \(daysBeforeDeadline) day\(daysBeforeDeadline == 1 ? "" : "s")"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "one_time_tax_reminder_\(UUID().uuidString)",
            content:    content,
            trigger:    trigger
        )

        do {
            try await center.add(request)
            print("📅 Scheduled one-time reminder for \(reminderDate.formatted())")
        } catch {
            print("❌ Error scheduling one-time reminder: \(error)")
        }
    }

    // MARK: - Test Notification

    @MainActor
    func sendTestNotification() async {
        let center  = UNUserNotificationCenter.current()
        let granted = await requestPermissionWithExplanation()
        guard granted else {
            print("❌ Cannot send test notification - permission denied")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "FLO Tax Reminder"
        content.body  = "This is a test notification. Your quarterly reminders are working!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: "test_notification",
            content:    content,
            trigger:    trigger
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

    func configureNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )

        let paidAction = UNNotificationAction(
            identifier: "MARK_PAID",
            title: "Mark as Paid",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind Tomorrow",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: notificationCategory,
            actions: [viewAction, paidAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([category])
        print("✅ Notification categories configured")
    }

    func handleNotificationAction(_ identifier: String, for notification: UNNotification) {
        switch identifier {
        case "VIEW_DETAILS":
            print("📱 User tapped 'View Details'")

        case "MARK_PAID":
            print("✅ User marked tax payment as paid")

        case "SNOOZE":
            print("⏰ User snoozed reminder")
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
 Version 1.3:
 - FIXED: scheduleQuarterlyReminders uses estimate.adjustedQuarterlyPayment
   instead of estimate.quarterlyPayment — notifications now quote the
   after-withholding amount the user actually owes, not gross tax ÷ 4.

 Version 1.2:
 - Uses NotificationPermissionHelper for user-friendly permission requests
 - Renamed requestPermission() to checkPermissionGranted()
 - Added requestPermissionWithExplanation() for proper UX flow
 - Methods now check status instead of re-requesting

 Version 1.1:
 - Added version tracking
 - Confirmed compatibility with TaxSettings v2.1 (2025 deadlines)

 Version 1.0:
 - Initial implementation
 - Quarterly reminder scheduling
 - Notification actions (view, mark paid, snooze)
 */
