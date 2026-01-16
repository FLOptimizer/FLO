//  NotificationPermissionHelper.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - User-friendly notification permission priming
//  Copyright © 2025 Finch & Poppy LLC. All rights reserved.
//
//  Shows custom alerts before requesting notification authorization
//

import SwiftUI
import UserNotifications

/// Helper for requesting notification permissions with user-friendly explanations
@MainActor
struct NotificationPermissionHelper {
    
    /// Show explanation alert before requesting notification permission
    /// - Parameters:
    ///   - context: The context for why notifications are needed (tax, invoices, etc.)
    ///   - completion: Callback with permission result
    static func requestWithExplanation(
        context: NotificationContext,
        completion: @escaping (Bool) -> Void
    ) {
        // Check current status first
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized:
                    completion(true)
                    return
                    
                case .denied:
                    // Show settings prompt
                    showSettingsAlert(context: context)
                    completion(false)
                    return
                    
                case .notDetermined:
                    // Show explanation, then request
                    showExplanationAlert(context: context, completion: completion)
                    
                case .provisional, .ephemeral:
                    // Request full authorization
                    showExplanationAlert(context: context, completion: completion)
                    
                @unknown default:
                    showExplanationAlert(context: context, completion: completion)
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private static func showExplanationAlert(
        context: NotificationContext,
        completion: @escaping (Bool) -> Void
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            // Fallback: request directly without alert
            requestAuthorization(completion: completion)
            return
        }
        
        let alert = UIAlertController(
            title: context.title,
            message: context.message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Enable Notifications", style: .default) { _ in
            requestAuthorization(completion: completion)
        })
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel) { _ in
            completion(false)
        })
        
        rootViewController.present(alert, animated: true)
    }
    
    private static func showSettingsAlert(context: NotificationContext) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Notifications Disabled",
            message: "Enable notifications in Settings to receive \(context.shortDescription).",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootViewController.present(alert, animated: true)
    }
    
    private static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
}

// MARK: - Notification Context

enum NotificationContext {
    case taxReminders
    case invoiceAlerts
    case mileageTracking
    case budgetAlerts
    
    var title: String {
        switch self {
        case .taxReminders:
            return "Stay on Top of Tax Deadlines"
        case .invoiceAlerts:
            return "Never Miss a Payment"
        case .mileageTracking:
            return "Track Your Miles"
        case .budgetAlerts:
            return "Budget Notifications"
        }
    }
    
    var message: String {
        switch self {
        case .taxReminders:
            return "FLO will send timely reminders before quarterly tax deadlines so you never miss a payment. Stay organized and avoid penalties."
        case .invoiceAlerts:
            return "Get notified when invoices are overdue or coming due soon, helping you maintain steady cash flow and client relationships."
        case .mileageTracking:
            return "Receive notifications when trips complete or if location tracking stops, ensuring accurate mileage records for tax deductions."
        case .budgetAlerts:
            return "Stay informed when you're approaching budget limits, helping you maintain financial discipline."
        }
    }
    
    var shortDescription: String {
        switch self {
        case .taxReminders:
            return "tax reminders"
        case .invoiceAlerts:
            return "invoice alerts"
        case .mileageTracking:
            return "mileage tracking updates"
        case .budgetAlerts:
            return "budget alerts"
        }
    }
}
