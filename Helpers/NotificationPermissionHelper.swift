//  NotificationPermissionHelper.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1.1 - Apple Guideline 5.1.1 Compliance + Backward Compatibility
//  Copyright © 2026 Finch & Poppy LLC. All rights reserved.
//
//  CHANGES v1.1.1:
//  ✅ ADDED: requestWithExplanation(context:completion:) for backward compatibility
//  ✅ MileageTrackingService and other callers don't need changes
//
//  CHANGES v1.1:
//  ✅ REMOVED: Pre-permission explanation alert with "Not Now" escape
//  ✅ CHANGED: Now requests permission directly when contextually needed
//  ✅ ADDED: Graceful handling of denied state with Settings redirect
//  ✅ Apple 5.1.1 compliant - no escape routes before permission request
//
//  PREVIOUS (v1.0):
//  - Showed custom alerts before requesting notification authorization
//  - Had "Not Now" option that let users skip permission (violation)
//

import SwiftUI
import UserNotifications

/// Helper for requesting notification permissions contextually
///
/// Apple Guideline 5.1.1 Compliance:
/// - No pre-permission screens with escape buttons
/// - Permission is requested directly when the feature needs it
/// - If denied, user is directed to Settings
@MainActor
struct NotificationPermissionHelper {
    
    // MARK: - Permission Status
    
    enum PermissionStatus {
        case authorized
        case denied
        case notDetermined
        case provisional
    }
    
    /// Check current notification permission status
    static func checkStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        switch settings.authorizationStatus {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .provisional:
            return .provisional
        case .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    // MARK: - Request Permission
    
    /// Request notification permission directly
    /// Returns true if permission was granted (or was already granted)
    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            return granted
        } catch {
            print("❌ Notification permission error: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Request permission and handle result appropriately
    /// - Parameter context: The context for why notifications are needed (for logging/analytics)
    /// - Returns: Whether permission was granted
    static func requestWithContext(_ context: NotificationContext) async -> Bool {
        let status = await checkStatus()
        
        switch status {
        case .authorized:
            // Already have permission
            return true
            
        case .notDetermined, .provisional:
            // Request permission - iOS will show the system dialog
            let granted = await requestPermission()
            
            #if DEBUG
            print("📱 Notification permission for \(context.shortDescription): \(granted ? "granted" : "denied")")
            #endif
            
            return granted
            
        case .denied:
            // Permission was denied - caller should show Settings alert
            return false
        }
    }
    
    // MARK: - Settings Redirect
    
    /// Open device Settings app to FLO's notification settings
    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    /// Show alert directing user to Settings when notification access is denied
    /// Call this when requestWithContext returns false AND status is .denied
    static func showSettingsAlert(context: NotificationContext) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        // Find the topmost presented controller
        var topVC = rootViewController
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        let alert = UIAlertController(
            title: "Notifications Disabled",
            message: "Enable notifications in Settings to receive \(context.shortDescription).",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            openSettings()
        })
        
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        
        topVC.present(alert, animated: true)
    }
    
    // MARK: - Convenience Method
    
    /// Complete flow: check status, request if needed, show settings if denied
    /// Returns true if notifications are enabled
    static func ensurePermission(for context: NotificationContext) async -> Bool {
        let status = await checkStatus()
        
        switch status {
        case .authorized:
            return true
            
        case .notDetermined, .provisional:
            return await requestPermission()
            
        case .denied:
            // Show settings alert on main thread
            await MainActor.run {
                showSettingsAlert(context: context)
            }
            return false
        }
    }
    
    // MARK: - Backward Compatibility (v1.0 API)
    
    /// Legacy method for backward compatibility with existing code
    /// Requests permission directly (no pre-explanation in v1.1+)
    /// - Parameters:
    ///   - context: The context for why notifications are needed
    ///   - completion: Called with whether permission was granted
    static func requestWithExplanation(context: NotificationContext, completion: @escaping (Bool) -> Void) {
        Task {
            let status = await checkStatus()
            
            switch status {
            case .authorized:
                await MainActor.run {
                    completion(true)
                }
                
            case .notDetermined, .provisional:
                let granted = await requestPermission()
                await MainActor.run {
                    completion(granted)
                }
                
            case .denied:
                await MainActor.run {
                    showSettingsAlert(context: context)
                    completion(false)
                }
            }
        }
    }
}

// MARK: - Notification Context

/// Describes the context for why notifications are being requested
/// Used for logging and Settings alert messaging
enum NotificationContext {
    case taxReminders
    case invoiceAlerts
    case mileageTracking
    case budgetAlerts
    case general
    
    var title: String {
        switch self {
        case .taxReminders:
            return "Tax Deadline Reminders"
        case .invoiceAlerts:
            return "Invoice Payment Alerts"
        case .mileageTracking:
            return "Mileage Tracking Updates"
        case .budgetAlerts:
            return "Budget Notifications"
        case .general:
            return "FLO Notifications"
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
        case .general:
            return "important updates"
        }
    }
}

// MARK: - SwiftUI View Modifier

/// View modifier for handling notification permission requests
struct NotificationPermissionModifier: ViewModifier {
    let context: NotificationContext
    @Binding var shouldRequest: Bool
    @Binding var isGranted: Bool
    @State private var showingSettingsAlert = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: shouldRequest) { _, newValue in
                if newValue {
                    Task {
                        await handlePermissionRequest()
                    }
                }
            }
            .alert("Notifications Disabled", isPresented: $showingSettingsAlert) {
                Button("Open Settings") {
                    NotificationPermissionHelper.openSettings()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Enable notifications in Settings to receive \(context.shortDescription).")
            }
    }
    
    private func handlePermissionRequest() async {
        shouldRequest = false
        
        let status = await NotificationPermissionHelper.checkStatus()
        
        switch status {
        case .authorized:
            isGranted = true
            
        case .notDetermined, .provisional:
            let granted = await NotificationPermissionHelper.requestPermission()
            isGranted = granted
            
        case .denied:
            isGranted = false
            showingSettingsAlert = true
        }
    }
}

// MARK: - View Extension

extension View {
    /// Handles notification permission requests
    /// - Parameters:
    ///   - context: The context for why notifications are needed
    ///   - shouldRequest: Binding that triggers the permission request when set to true
    ///   - isGranted: Binding that reflects whether permission was granted
    func notificationPermission(
        context: NotificationContext,
        shouldRequest: Binding<Bool>,
        isGranted: Binding<Bool>
    ) -> some View {
        modifier(NotificationPermissionModifier(
            context: context,
            shouldRequest: shouldRequest,
            isGranted: isGranted
        ))
    }
}
