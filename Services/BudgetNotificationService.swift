//  BudgetNotificationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Budget Threshold Local Notifications
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Fires local notifications when budget thresholds are crossed.
//  Called after transaction sync completes (either manual or via push).
//  Budget data lives in SwiftData (not server-side), so these are
//  always local notifications — never remote push.
//
//  NOTIFICATION TYPES:
//  - Budget Warning: spending >= user's warning threshold (default 80%)
//  - Budget Exceeded: spending > 100% of budget
//
//  DEDUP: Each budget only triggers one notification per month,
//  tracked via UserDefaults key "budget.notified.{budgetId}.{yyyy-MM}"

import Foundation
import UserNotifications
import SwiftData

// MARK: - Budget Notification Service

@MainActor
final class BudgetNotificationService {

    // MARK: - Singleton

    static let shared = BudgetNotificationService()
    private init() {}

    // MARK: - Notification Identifiers

    private let warningCategoryIdentifier = "BUDGET_ALERT"
    private let exceededCategoryIdentifier = "BUDGET_EXCEEDED"

    // MARK: - Category Registration

    /// Register notification categories for budget alerts.
    /// Call from AppDelegate.didFinishLaunchingWithOptions alongside tax categories.
    func configureNotificationCategories() -> [UNNotificationCategory] {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_BUDGET",
            title: "View Budget",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_BUDGET",
            title: "Dismiss",
            options: [.destructive]
        )

        let warningCategory = UNNotificationCategory(
            identifier: warningCategoryIdentifier,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        let exceededCategory = UNNotificationCategory(
            identifier: exceededCategoryIdentifier,
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        return [warningCategory, exceededCategory]
    }

    // MARK: - Threshold Checking

    /// Check all active budgets for threshold breaches and fire notifications.
    /// Call this after transaction sync completes.
    ///
    /// - Parameter modelContext: SwiftData model context for fetching budgets & transactions
    func checkAllBudgetThresholds(modelContext: ModelContext) async {
        // Check user preferences
        let budgetAlertsEnabled = UserDefaults.standard.bool(forKey: "budgetAlertEnabled")
        guard budgetAlertsEnabled else {
            #if DEBUG
            print("📊 Budget alerts disabled, skipping threshold check")
            #endif
            return
        }

        // Check notification permission
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            #if DEBUG
            print("📊 Notifications not authorized, skipping budget check")
            #endif
            return
        }

        // Get warning threshold (default 80%)
        let warningThreshold = Double(UserDefaults.standard.integer(forKey: "warningThresholdPercent"))
        let effectiveThreshold = warningThreshold > 0 ? warningThreshold : 80.0

        // Get current month start
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return
        }
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        // Month key for dedup tracking
        let monthKey = Self.monthKey(for: now)

        // Fetch current month budgets
        do {
            let budgetDescriptor = FetchDescriptor<Budget>()
            let allBudgets = try modelContext.fetch(budgetDescriptor)

            let currentMonthBudgets = allBudgets.filter { budget in
                let budgetMonth = calendar.dateComponents([.year, .month], from: budget.month)
                let currentMonth = calendar.dateComponents([.year, .month], from: now)
                return budgetMonth.year == currentMonth.year && budgetMonth.month == currentMonth.month
            }

            guard !currentMonthBudgets.isEmpty else {
                #if DEBUG
                print("📊 No budgets for current month, skipping")
                #endif
                return
            }

            // Fetch current month transactions (expenses only)
            let transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { transaction in
                    transaction.date >= monthStart && transaction.date <= monthEnd &&
                    transaction.isIncome == false
                }
            )
            let monthTransactions = try modelContext.fetch(transactionDescriptor)

            var notificationCount = 0

            for budget in currentMonthBudgets {
                guard budget.totalAvailable > 0 else { continue }
                guard let categoryName = budget.category?.name else { continue }

                // Calculate spent for this budget
                let spent = calculateSpent(
                    for: budget,
                    transactions: monthTransactions
                )

                let percentUsed = budget.percentageUsed(spent: spent)
                let isOverBudget = budget.isOverBudget(spent: spent)

                // Check if already notified this month for this budget
                let notifiedKey = "budget.notified.\(budget.id.uuidString).\(monthKey)"
                let alreadyNotified = UserDefaults.standard.bool(forKey: notifiedKey)

                if alreadyNotified { continue }

                if isOverBudget {
                    // Budget exceeded notification
                    await sendBudgetExceededNotification(
                        budgetId: budget.id,
                        categoryName: categoryName,
                        spent: spent,
                        budgeted: budget.totalAvailable
                    )
                    UserDefaults.standard.set(true, forKey: notifiedKey)
                    notificationCount += 1
                } else if percentUsed >= effectiveThreshold {
                    // Budget warning notification
                    await sendBudgetWarningNotification(
                        budgetId: budget.id,
                        categoryName: categoryName,
                        percentUsed: percentUsed,
                        spent: spent,
                        budgeted: budget.totalAvailable
                    )
                    UserDefaults.standard.set(true, forKey: notifiedKey)
                    notificationCount += 1
                }

                // Cap at 3 notifications per sync to avoid spamming
                if notificationCount >= 3 { break }
            }

            #if DEBUG
            if notificationCount > 0 {
                print("📊 Sent \(notificationCount) budget alert(s)")
            } else {
                print("📊 No budget thresholds crossed")
            }
            #endif

        } catch {
            #if DEBUG
            print("❌ Budget threshold check error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Notification Sending

    /// Send a budget warning notification (at or above threshold but not exceeded)
    private func sendBudgetWarningNotification(
        budgetId: UUID,
        categoryName: String,
        percentUsed: Double,
        spent: Double,
        budgeted: Double
    ) async {
        let content = UNMutableNotificationContent()
        content.title = "Budget Warning"
        content.body = "\(Int(percentUsed))% of your \(categoryName) budget spent (\(spent.asCurrency) of \(budgeted.asCurrency))"
        content.sound = .default
        content.categoryIdentifier = warningCategoryIdentifier
        content.userInfo = [
            "type": "budget_warning",
            "budgetId": budgetId.uuidString,
            "categoryName": categoryName,
            "percentUsed": percentUsed
        ]

        let identifier = "budget_warning_\(budgetId.uuidString)_\(Self.monthKey(for: Date()))"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("📊 Budget warning sent: \(categoryName) at \(Int(percentUsed))%")
            #endif
        } catch {
            #if DEBUG
            print("❌ Budget warning notification error: \(error)")
            #endif
        }
    }

    /// Send a budget exceeded notification (over 100%)
    private func sendBudgetExceededNotification(
        budgetId: UUID,
        categoryName: String,
        spent: Double,
        budgeted: Double
    ) async {
        let overAmount = spent - budgeted

        let content = UNMutableNotificationContent()
        content.title = "Budget Exceeded"
        content.body = "Your \(categoryName) budget is over by \(overAmount.asCurrency) (\(spent.asCurrency) of \(budgeted.asCurrency))"
        content.sound = .default
        content.categoryIdentifier = exceededCategoryIdentifier
        content.userInfo = [
            "type": "budget_exceeded",
            "budgetId": budgetId.uuidString,
            "categoryName": categoryName,
            "overAmount": overAmount
        ]

        let identifier = "budget_exceeded_\(budgetId.uuidString)_\(Self.monthKey(for: Date()))"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Immediate delivery
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            #if DEBUG
            print("📊 Budget EXCEEDED: \(categoryName) over by \(overAmount.asCurrency)")
            #endif
        } catch {
            #if DEBUG
            print("❌ Budget exceeded notification error: \(error)")
            #endif
        }
    }

    // MARK: - Notification Action Handling

    /// Handle notification tap actions
    func handleNotificationAction(_ identifier: String, for notification: UNNotification) {
        switch identifier {
        case "VIEW_BUDGET":
            #if DEBUG
            print("📊 User tapped 'View Budget'")
            #endif
            // Post notification for navigation
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToBudgets"),
                object: nil,
                userInfo: notification.request.content.userInfo
            )

        case "DISMISS_BUDGET":
            #if DEBUG
            print("📊 User dismissed budget alert")
            #endif

        default:
            #if DEBUG
            print("❓ Unknown budget notification action: \(identifier)")
            #endif
        }
    }

    // MARK: - Helpers

    /// Calculate spent for a specific budget from a set of transactions
    /// Mirrors BudgetListView.calculateSpent(for:in:) pattern
    private func calculateSpent(for budget: Budget, transactions: [Transaction]) -> Double {
        let relevantTransactions = transactions.filter { transaction in
            guard !transaction.isIncome else { return false }
            guard transaction.financeType == budget.financeType else { return false }

            if let budgetCategory = budget.category {
                return transaction.category?.id == budgetCategory.id
            }
            return true
        }

        return abs(relevantTransactions.reduce(0) { $0 + $1.amount })
    }

    /// Generate a month key string (yyyy-MM) for dedup tracking
    private static func monthKey(for date: Date) -> String {
        return DateFormatter.yearMonth.string(from: date)
    }

    /// Reset monthly notification tracking (call at start of new month if needed)
    func resetMonthlyTracking(for budgetIds: [UUID]) {
        let currentMonthKey = Self.monthKey(for: Date())
        for budgetId in budgetIds {
            let key = "budget.notified.\(budgetId.uuidString).\(currentMonthKey)"
            UserDefaults.standard.removeObject(forKey: key)
        }

        #if DEBUG
        print("📊 Reset budget notification tracking for \(budgetIds.count) budget(s)")
        #endif
    }
}
