//  DebtPaymentReminderService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Debt Accelerator Phase 1
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Schedules local notifications for upcoming debt payments based on
//  the active DebtAcceleratorPlan's schedule and reminder preferences.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
final class DebtPaymentReminderService {
    static let shared = DebtPaymentReminderService()
    private init() {}

    private let categoryIdentifier = "DEBT_PAYMENT_REMINDER"

    // MARK: - Notification Category

    func configureNotificationCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DEBT_PLAN",
            title: "View Plan",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_DEBT_REMINDER",
            title: "Dismiss",
            options: [.destructive]
        )

        return UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - Schedule Reminders

    /// Schedule payment reminders for all debt accounts in the active plan.
    /// Called after plan creation/edit and on app launch.
    func scheduleReminders(for plan: DebtAcceleratorPlan, accounts: [Account]) async {
        guard plan.paymentRemindersEnabled else {
            await cancelAllReminders()
            return
        }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        // Cancel existing debt reminders before rescheduling
        await cancelAllReminders()

        let calendar = Calendar.current
        let now = Date()
        var scheduledCount = 0

        // Schedule reminders for each included debt account
        let includedAccounts = accounts.filter { plan.includedAccountIDs.contains($0.id) && $0.isDebtAccount }

        for account in includedAccounts {
            guard let dueDay = account.paymentDueDay else { continue }

            // Schedule for the next 3 months
            for monthOffset in 0..<3 {
                guard let baseDate = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }

                var components = calendar.dateComponents([.year, .month], from: baseDate)
                components.day = min(dueDay, 28)  // Cap at 28 for safety

                guard let dueDate = calendar.date(from: components),
                      dueDate > now else { continue }

                // Reminder X days before due date
                guard let reminderDate = calendar.date(byAdding: .day, value: -plan.reminderDaysBefore, to: dueDate),
                      reminderDate > now else { continue }

                // Dedup key
                let monthKey = "\(components.year!)-\(String(format: "%02d", components.month!))"
                let dedupKey = "debt.reminder.\(account.id.uuidString).\(monthKey)"

                guard !UserDefaults.standard.bool(forKey: dedupKey) else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Payment Due Soon"
                content.body = "\(account.name) payment of \(account.minimumPaymentDue?.formatted(.currency(code: "USD")) ?? "minimum") is due in \(plan.reminderDaysBefore) days"
                content.sound = .default
                content.categoryIdentifier = categoryIdentifier
                content.userInfo = [
                    "type": "debt_payment_reminder",
                    "accountId": account.id.uuidString,
                    "accountName": account.name
                ]

                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour], from: reminderDate)
                var trigger = triggerComponents
                trigger.hour = 9  // 9 AM reminder

                let request = UNNotificationRequest(
                    identifier: "debt_reminder_\(account.id.uuidString)_\(monthKey)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: false)
                )

                do {
                    try await UNUserNotificationCenter.current().add(request)
                    scheduledCount += 1
                } catch {
                    #if DEBUG
                    print("❌ Debt reminder error: \(error)")
                    #endif
                }
            }
        }

        #if DEBUG
        print("🔔 Scheduled \(scheduledCount) debt payment reminders")
        #endif
    }

    // MARK: - Cancel

    func cancelAllReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let debtIdentifiers = pending
            .filter { $0.identifier.hasPrefix("debt_reminder_") }
            .map(\.identifier)

        if !debtIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: debtIdentifiers)
            #if DEBUG
            print("🔕 Cancelled \(debtIdentifiers.count) debt reminders")
            #endif
        }
    }
}
