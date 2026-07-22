//  FLOApp.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.13 - Mac Catalyst menu bar
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.13 - Mac Catalyst menu bar:
//  ✅ FIXED: The curated menu commands (Cmd+N, Cmd+, Settings, Navigate menu
//           with Cmd+1–9) were behind `#if os(macOS)`, which is false on Mac
//           Catalyst — the shipping Mac app showed only auto-generated menus.
//           The `.commands` block now also builds for targetEnvironment(macCatalyst).
//           `.defaultSize` and `MenuBarExtra` remain macOS-only (not on Catalyst).
//
//  CHANGES v3.12 - Performance Monitoring:
//  ✅ Added os_signpost instrumentation for Instruments profiling (all builds)
//  ✅ Added MetricKit registration for 24-hour aggregate metrics
//  ✅ Added memory monitoring after launch completes
//  ✅ Signpost intervals: ColdStart, ModelContainer, ContentViewAppear, CriticalPathComplete
//  ✅ Existing LaunchTimer preserved for debug console output
//
//  CHANGES v3.11 - Liability Balance Migration:
//  ✅ Added one-time migration to fix liability accounts with positive balances
//  ✅ Negates currentBalance and startingBalance for affected credit cards/loans
//  ✅ Uses UserDefaults tracking to prevent duplicate migrations
//  ✅ See LiabilityBalanceMigrationService.swift for full migration logic
//
//  CHANGES v3.10 - Transfer Migration:
//  ✅ Added one-time migration of isTransfer=true transactions to Transfer records
//  ✅ Runs automatically on first launch after Transfer model is added
//  ✅ Safely converts legacy transfers with intelligent type detection
//  ✅ Uses UserDefaults tracking to prevent duplicate migrations
//  ✅ See TransferMigrationService.swift for full migration logic
//
//  CHANGES v3.9 - Recurring Transfers:
//  ✅ Added recurring transfer generation on app launch
//  ✅ Follows same pattern as RecurringTransactionService
//  ✅ Runs after recurring transactions in critical path setup
//  ✅ Generates any due transfers from RecurringTransfer schedules
//  ✅ Logs count of generated transfers for debugging
//
//  CHANGES v3.8 - Transfer Models:
//  ✅ Updated ModelContainer to include Transfer and RecurringTransfer models
//  ✅ Supports new "Move Money" feature with double-entry accounting
//  ✅ See ModelContainer_Shared.swift v4.6 for model registration details
//
//  CHANGES v3.7 - Launch Optimization:
//  ✅ Added launch timing instrumentation (debug builds)
//  ✅ Deferred WatchConnectivity activation by 1 second
//  ✅ Deferred Spotlight indexing by 2 seconds
//  ✅ Deferred haptic generator preparation
//  ✅ Consolidated widget update calls
//  ✅ Removed duplicate notification category configuration
//
//  CHANGES v3.6:
//  - Apple Watch connectivity integration
//
//  CHANGES v3.5:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters
//
// VERSION HISTORY:
// v3.4: Spotlight indexing on app launch
// v3.3: ✅ FIXED: Mileage tracking auto-start now checks subscription tier
//       ✅ FIXED: QuickActionService now checks subscription for mileage actions
//       - Free tier users won't have GPS tracking enabled
//       - Free tier can still manually add trips
// v3.2: Added SeedData.migrateCategories() call on app launch
// v3.1: Fixed Swift 6 actor isolation errors
// v3.0: Home Screen Quick Actions
// v2.9: Auto-start mileage tracking on app launch
// v2.8: Removed duplicate LockView - ContentView handles all security UI
// v2.7: Added onboarding flow + fixed property declaration order
// v2.6: FORCED custom SwiftData store URL (FLOSwiftData.store)
//
// SECURITY NOTE:
// ContentView handles all authentication UI including:
// - LockView display when not authenticated
// - Biometric and passcode checks
// - Smooth unlock transitions
// FLOApp should NOT duplicate this logic.

import SwiftUI
import SwiftData
import UserNotifications
import os
import MetricKit

#if canImport(UIKit)
import WatchConnectivity
#endif

// MARK: - Launch Timing (Debug Only)

#if DEBUG
/// Tracks cold start timing for performance optimization (console output)
/// See also: PerformanceMonitor for os_signpost instrumentation (Instruments-visible, all builds)
enum LaunchTimer {
    static let launchStart = CFAbsoluteTimeGetCurrent()

    static func checkpoint(_ name: String) {
        let elapsed = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
        print("⏱️ [\(String(format: "%6.1f", elapsed))ms] \(name)")
    }

    static func complete() {
        let total = (CFAbsoluteTimeGetCurrent() - launchStart) * 1000
        let status = total < 1000 ? "✅" : "⚠️"
        print("\(status) 📱 Cold start complete: \(String(format: "%.0f", total))ms")
        if total >= 1000 {
            print("   ⚠️ Target is <1000ms - optimization needed")
        }
    }
}
#endif

#if canImport(UIKit)
// MARK: - AppDelegate (iOS)

/// AppDelegate for handling notifications, background launches, and Universal Links
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        #if DEBUG
        LaunchTimer.checkpoint("AppDelegate.didFinishLaunching")
        #endif

        // Register MetricKit for 24-hour aggregate performance data
        Task { @MainActor in
            PerformanceMonitor.shared.registerMetricKit()
        }

        // Configure notification categories (tax + budget + debt alerts)
        let budgetCategories = BudgetNotificationService.shared.configureNotificationCategories()
        TaxNotificationService.shared.configureNotificationCategories()
        let debtCategory = DebtPaymentReminderService.shared.configureNotificationCategory()
        // Merge all categories
        UNUserNotificationCenter.current().getNotificationCategories { existingCategories in
            var merged = existingCategories.union(Set(budgetCategories))
            merged.insert(debtCategory)
            UNUserNotificationCenter.current().setNotificationCategories(merged)
        }
        
        // Set delegate for handling notifications
        UNUserNotificationCenter.current().delegate = self
        
        #if DEBUG
        LaunchTimer.checkpoint("Notifications configured")
        #endif
        
        // CRITICAL: Handle background location launch
        // When iOS launches the app in the background for a location event,
        // we need to restart the location manager immediately
        if let _ = launchOptions?[.location] {
            print("🚗 App launched in BACKGROUND for location event")
            handleBackgroundLocationLaunch()
        }
        
        return true
    }
    
    /// Handle app launch triggered by background location event
    /// This is called when iOS wakes the app due to significant location change
    /// or geofence events while the app was terminated
    private func handleBackgroundLocationLaunch() {
        print("🚗 Handling background location launch...")
        
        // Check if tracking was supposed to be active
        let wasTrackingActive = UserDefaults.standard.bool(forKey: "mileage.isTrackingActive")
        let mileageSetupCompleted = UserDefaults.standard.bool(forKey: "mileageSetupCompleted")
        let mileageTrackingEnabled = UserDefaults.standard.bool(forKey: "mileageTrackingEnabled")
        
        guard mileageTrackingEnabled && mileageSetupCompleted else {
            // Clear stale active flag if user disabled tracking
            if wasTrackingActive && !mileageTrackingEnabled {
                UserDefaults.standard.set(false, forKey: "mileage.isTrackingActive")
            }
            print("   - Tracking not enabled or setup incomplete, ignoring")
            return
        }
        
        print("   - Tracking was active, attempting to restart...")
        
        // Get or create the shared ModelContainer
        do {
            let container = try ModelContainer.shared()
            
            // Must access MainActor-isolated MileageTrackingService on main actor
            Task { @MainActor in
                // CHECK SUBSCRIPTION TIER (NEW in v3.3)
                let subscriptionManager = SubscriptionManager.shared
                guard subscriptionManager.currentTier.hasAutomatedMileage else {
                    print("   - Free tier: GPS tracking not available")
                    return
                }
                
                let trackingService = MileageTrackingService.shared
                
                // Inject ModelContext so the service can save trips
                trackingService.inject(modelContext: container.mainContext)
                print("   - ModelContext injected in background")
                
                // Check permission and start tracking
                if trackingService.trackingPermissionStatus == .authorizedAlways {
                    if !trackingService.isTracking {
                        trackingService.startTracking()
                        print("✅ Mileage tracking RESTARTED from background launch")
                    } else {
                        print("   - Tracking already running")
                    }
                } else {
                    print("   - No 'Always' permission, cannot track in background")
                }
            }
            
        } catch {
            print("❌ Failed to create ModelContainer in background: \(error)")
        }
    }
    
    // MARK: - Universal Links (Plaid OAuth)
    
    /// Handle Universal Links for Plaid OAuth redirect
    /// This is called when the app is opened via a Universal Link
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        
        print("🔗 Universal Link received: \(url)")
        
        // Handle Plaid OAuth redirect
        if url.absoluteString.contains("plaid-oauth") {
            print("✅ Plaid OAuth redirect received")
            // Plaid Link SDK handles this automatically when properly configured
            // Post notification for any custom handling needed
            NotificationCenter.default.post(
                name: Notification.Name("PlaidOAuthRedirect"),
                object: nil,
                userInfo: ["url": url]
            )
            return true
        }

        // Handle invoice universal links: https://floptimizer.github.io/FLO/invoice/<uuid>
        // (same paths the AASA declares for the App Clip; in the full app they
        // open the invoice directly)
        let components = url.pathComponents
        if let invoiceIndex = components.firstIndex(of: "invoice"),
           components.indices.contains(invoiceIndex + 1),
           let invoiceId = UUID(uuidString: components[invoiceIndex + 1]) {
            Task { @MainActor in
                NavigationService.shared.openInvoice(id: invoiceId)
            }
            return true
        }

        // Unrecognized link (e.g. an invoice URL without a valid id): open the
        // Invoices tab rather than bouncing the user back to Safari
        if components.contains("invoice") {
            Task { @MainActor in
                NavigationService.shared.navigateTo(.invoices)
            }
            return true
        }

        return false
    }
    
    // MARK: - Quick Actions (3D Touch / Haptic Touch)
    
    /// Handle quick action when app launches from terminated state
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if launched from quick action
        if let shortcutItem = options.shortcutItem {
            // Store pending action - access on main actor
            Task { @MainActor in
                QuickActionService.shared.pendingAction = shortcutItem.type
            }
        }
        
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
    
    // MARK: - Remote Notification Registration

    /// Called when iOS successfully registers for remote notifications
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleNewToken(deviceToken)
        }
    }

    /// Called when remote notification registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleRegistrationError(error)
        }
    }

    // MARK: - Background Remote Notification

    /// Handle silent push notifications for background sync
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let notificationType = userInfo["type"] as? String

        #if DEBUG
        print("📱 Remote notification received: \(notificationType ?? "unknown")")
        #endif

        switch notificationType {
        case "new_transactions":
            // Silent push: sync transactions in background, then check budgets
            Task { @MainActor in
                do {
                    let container = try ModelContainer.shared()
                    let result = try await PlaidService.shared.syncAllTransactions(
                        modelContext: container.mainContext
                    )

                    // Refresh balances alongside transactions (non-blocking —
                    // stale balances shouldn't fail the whole background sync)
                    try? await PlaidService.shared.updateAccountBalances(
                        modelContext: container.mainContext
                    )

                    // After sync, check budget thresholds
                    await BudgetNotificationService.shared.checkAllBudgetThresholds(
                        modelContext: container.mainContext
                    )

                    let total = result.added + result.updated + result.removed
                    completionHandler(total > 0 ? .newData : .noData)

                    #if DEBUG
                    print("✅ Background sync complete: \(result.added) added, \(result.updated) updated")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Background sync failed: \(error)")
                    #endif
                    completionHandler(.failed)
                }
            }

        case "connection_error", "connection_expiring":
            // Show local notification about bank connection issue
            let title = notificationType == "connection_error"
                ? "Bank Connection Issue"
                : "Bank Connection Expiring"
            let body = userInfo["message"] as? String
                ?? "There's an issue with your bank connection. Tap to fix."

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = "PLAID_ERROR"
            content.userInfo = userInfo as! [String: Any]

            let request = UNNotificationRequest(
                identifier: "plaid_error_\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request)
            completionHandler(.newData)

        default:
            #if DEBUG
            print("📱 Unhandled remote notification type: \(notificationType ?? "nil")")
            #endif
            completionHandler(.noData)
        }
    }

    // MARK: - Notification Handling

    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap — routes to appropriate service
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier

        switch categoryId {
        case "BUDGET_ALERT", "BUDGET_EXCEEDED":
            BudgetNotificationService.shared.handleNotificationAction(
                actionId, for: response.notification
            )

        case "PLAID_SYNC", "PLAID_ERROR":
            // Navigate to Accounts tab
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToAccounts"),
                object: nil,
                userInfo: response.notification.request.content.userInfo
            )

        case "DEBT_PAYMENT_REMINDER":
            NavigationService.shared.navigateTo(.debtAccelerator)

        default:
            // Tax reminders and other notifications
            TaxNotificationService.shared.handleNotificationAction(
                actionId, for: response.notification
            )
        }

        completionHandler()
    }
}

// MARK: - Scene Delegate for Quick Actions

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Handle quick action when app is already running
        Task { @MainActor in
            let handled = QuickActionService.shared.handleAction(shortcutItem.type)
            completionHandler(handled)
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Process any pending action from cold launch
        Task { @MainActor in
            QuickActionService.shared.processPendingAction()
            
            // Update shortcuts based on current state
            QuickActionService.shared.updateShortcuts()
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Update shortcuts when leaving app so they're correct next time
        Task { @MainActor in
            QuickActionService.shared.updateShortcuts()
        }
    }
}

// MARK: - Quick Action Service

/// Manages Home Screen Quick Actions (3D Touch / Haptic Touch menu)
/// Must be @MainActor because it accesses MileageTrackingService which is @MainActor
@MainActor
class QuickActionService {
    static let shared = QuickActionService()
    
    // Action type identifiers
    enum ActionType: String {
        case pauseMileage = "com.finchandpoppy.flo.pauseMileage"
        case resumeMileage = "com.finchandpoppy.flo.resumeMileage"
        case addTransaction = "com.finchandpoppy.flo.addTransaction"
        case scanReceipt = "com.finchandpoppy.flo.scanReceipt"
    }
    
    /// Pending action from cold launch (processed once app is ready)
    var pendingAction: String?
    
    private init() {}
    
    /// Update home screen shortcuts based on current tracking state
    func updateShortcuts() {
        let trackingService = MileageTrackingService.shared
        let subscriptionManager = SubscriptionManager.shared
        
        let isTracking = trackingService.isTracking
        let hasPermission = trackingService.trackingPermissionStatus == .authorizedAlways
        let setupComplete = UserDefaults.standard.bool(forKey: "mileageSetupCompleted")
        
        // NEW in v3.3: Check subscription tier for mileage features
        let hasAutomatedMileage = subscriptionManager.currentTier.hasAutomatedMileage
        
        var shortcuts: [UIApplicationShortcutItem] = []
        
        // Mileage tracking toggle (only if Premium+ AND setup complete AND has permission)
        if hasAutomatedMileage && setupComplete && hasPermission {
            if isTracking {
                shortcuts.append(UIApplicationShortcutItem(
                    type: ActionType.pauseMileage.rawValue,
                    localizedTitle: "Pause Mileage",
                    localizedSubtitle: "Stop tracking trips",
                    icon: UIApplicationShortcutIcon(systemImageName: "pause.circle.fill"),
                    userInfo: nil
                ))
            } else {
                shortcuts.append(UIApplicationShortcutItem(
                    type: ActionType.resumeMileage.rawValue,
                    localizedTitle: "Resume Mileage",
                    localizedSubtitle: "Start tracking trips",
                    icon: UIApplicationShortcutIcon(systemImageName: "play.circle.fill"),
                    userInfo: nil
                ))
            }
        }
        
        // Always show these actions
        shortcuts.append(UIApplicationShortcutItem(
            type: ActionType.addTransaction.rawValue,
            localizedTitle: "Add Transaction",
            localizedSubtitle: "Log income or expense",
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
            userInfo: nil
        ))
        
        shortcuts.append(UIApplicationShortcutItem(
            type: ActionType.scanReceipt.rawValue,
            localizedTitle: "Scan Receipt",
            localizedSubtitle: "Capture with camera",
            icon: UIApplicationShortcutIcon(systemImageName: "camera.fill"),
            userInfo: nil
        ))
        
        UIApplication.shared.shortcutItems = shortcuts
        print("📱 Quick actions updated: \(shortcuts.map { $0.localizedTitle })")
    }
    
    /// Handle a quick action
    @discardableResult
    func handleAction(_ actionType: String) -> Bool {
        guard let action = ActionType(rawValue: actionType) else {
            print("⚠️ Unknown quick action: \(actionType)")
            return false
        }
        
        print("🚀 Handling quick action: \(action)")
        
        switch action {
        case .pauseMileage:
            pauseMileageTracking()
            return true
            
        case .resumeMileage:
            resumeMileageTracking()
            return true
            
        case .addTransaction:
            // Post notification to navigate to add transaction
            NotificationCenter.default.post(name: .quickActionAddTransaction, object: nil)
            return true
            
        case .scanReceipt:
            // Post notification to open receipt scanner
            NotificationCenter.default.post(name: .quickActionScanReceipt, object: nil)
            return true
        }
    }
    
    /// Process any pending action from cold launch
    func processPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        
        // Small delay to ensure app is fully initialized
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.handleAction(action)
        }
    }
    
    // MARK: - Mileage Actions
    
    private func pauseMileageTracking() {
        let trackingService = MileageTrackingService.shared
        let subscriptionManager = SubscriptionManager.shared
        
        // CHECK SUBSCRIPTION (NEW in v3.3)
        guard subscriptionManager.currentTier.hasAutomatedMileage else {
            print("⚠️ Mileage tracking requires Premium or Pro")
            return
        }
        
        guard trackingService.isTracking else {
            print("⚠️ Mileage tracking not running, nothing to pause")
            return
        }
        
        trackingService.stopTracking()
        UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
        
        // Update shortcuts to show "Resume" option
        updateShortcuts()
        
        // Send confirmation notification
        sendNotification(
            title: "Mileage Paused",
            body: "Tracking stopped. Long-press FLO to resume.",
            identifier: "mileage_paused"
        )
        
        print("⏸️ Mileage tracking PAUSED via quick action")
    }
    
    private func resumeMileageTracking() {
        let trackingService = MileageTrackingService.shared
        let subscriptionManager = SubscriptionManager.shared
        
        // CHECK SUBSCRIPTION (NEW in v3.3)
        guard subscriptionManager.currentTier.hasAutomatedMileage else {
            print("⚠️ Mileage tracking requires Premium or Pro")
            sendNotification(
                title: "Premium Feature",
                body: "Upgrade to Premium to use GPS mileage tracking.",
                identifier: "mileage_premium_required"
            )
            return
        }
        
        guard !trackingService.isTracking else {
            print("⚠️ Mileage tracking already running")
            return
        }
        
        guard trackingService.trackingPermissionStatus == .authorizedAlways else {
            print("⚠️ Cannot resume - no Always permission")
            sendNotification(
                title: "Permission Required",
                body: "Open FLO to grant location permission for mileage tracking.",
                identifier: "mileage_permission_needed"
            )
            return
        }
        
        // Ensure ModelContext is injected
        if !trackingService.isContextInjected {
            do {
                let container = try ModelContainer.shared()
                trackingService.inject(modelContext: container.mainContext)
            } catch {
                print("❌ Failed to inject ModelContext: \(error)")
                return
            }
        }
        
        trackingService.startTracking()
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        
        // Update shortcuts to show "Pause" option
        updateShortcuts()
        
        // Send confirmation notification
        sendNotification(
            title: "Mileage Resumed",
            body: "Now tracking your trips automatically.",
            identifier: "mileage_resumed"
        )
        
        print("▶️ Mileage tracking RESUMED via quick action")
    }
    
    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - Quick Action Notification Names

extension Notification.Name {
    static let quickActionAddTransaction = Notification.Name("com.finchandpoppy.flo.quickAction.addTransaction")
    static let quickActionScanReceipt = Notification.Name("com.finchandpoppy.flo.quickAction.scanReceipt")
}
#endif // canImport(UIKit)

// MARK: - Explore Tour Notification

extension Notification.Name {
    /// Posted by onboarding when the user wants to preview FLO with sample
    /// data. Handled by FLOApp, which swaps in a seeded in-memory container.
    static let enterExploreTour = Notification.Name("com.finchandpoppy.flo.enterExploreTour")
}

// MARK: - FLOApp

@main
struct FLOApp: App {
    // MARK: - Properties (ALL declared BEFORE init)

    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var container: ModelContainer?
    // Explore tour: a seeded, in-memory, CloudKit-free container shown instead
    // of the real store so prospects can preview a full app. Never persisted.
    @State private var exploreContainer: ModelContainer?
    @StateObject private var authService = BiometricAuthService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var isExploringSampleData: Bool { exploreContainer != nil }
    
    // MARK: - Initialization
    
    init() {
            // Performance: Start launch signpost (visible in Instruments, all builds)
            PerformanceMonitor.shared.beginLaunch()

            #if DEBUG
            LaunchTimer.checkpoint("FLOApp.init() started")
            #endif

            // CRITICAL: Purge any legacy Core Data store first
            Self.purgeLegacyCoreDataStoreIfNeeded()
            
            // In UI testing / demo mode, use in-memory container to avoid App Group issues
            let isTestingMode = ProcessInfo.processInfo.arguments.contains("UI_TESTING") ||
                                ProcessInfo.processInfo.arguments.contains("DEMO_MODE")
            
            if isTestingMode {
                _container = State(initialValue: ModelContainer.preview())
                print("🎬 Using in-memory ModelContainer for testing/demo mode")
                return
            }

            // ModelContainer creation deferred to background thread for faster launch
            // CloudKit schema init (~2.5s) now happens off main thread while splash shows
            _container = State(initialValue: nil)

            #if DEBUG
            LaunchTimer.checkpoint("FLOApp.init() complete (container deferred to background)")
            #endif
        }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            if let container {
                // Real app content — only shown after ModelContainer is ready.
                // During the explore tour, a seeded in-memory container is
                // swapped in; .id forces a full rebuild so every @Query and
                // context picks up the swap.
                ContentView()
                    .modelContainer(exploreContainer ?? container)
                    .id(isExploringSampleData)
                    .environmentObject(authService)
                    .environmentObject(subscriptionManager)
                    .safeAreaInset(edge: .top) {
                        if isExploringSampleData {
                            exploreTourBanner
                        }
                    }
                    #if os(iOS)
                    .fullScreenCover(isPresented: Binding(
                        get: { !hasCompletedOnboarding && !isExploringSampleData },
                        set: { newValue in
                            // Entering the tour dismisses this cover; that
                            // programmatic dismissal must NOT mark onboarding
                            // complete, or it never reappears after the tour
                            guard !isExploringSampleData else { return }
                            hasCompletedOnboarding = !newValue
                        }
                    )) {
                        OnboardingView()
                    }
                    #endif
                    .task {
                        await subscriptionManager.initialize()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .enterExploreTour)) { _ in
                        enterExploreTour()
                    }
                    #if DEBUG
                    // Verification hook: `simctl launch ... EXPLORE_TOUR_TEST`
                    // drives the tour without UI automation
                    .task {
                        if ProcessInfo.processInfo.arguments.contains("EXPLORE_TOUR_TEST") {
                            enterExploreTour()
                        }
                    }
                    #endif
                    .onAppear {
                        // Tour rebuilds skip app setup — services stay bound to
                        // the real store, and the tour container needs none of it
                        guard !isExploringSampleData else { return }

                        PerformanceMonitor.shared.launchCheckpoint("ContentViewAppear")
                        #if DEBUG
                        LaunchTimer.checkpoint("ContentView.onAppear")
                        #endif

                        // CRITICAL PATH: Only essential setup here
                        setupAppCritical(container: container)

                        #if os(iOS)
                        // Inject ModelContext into MileageTrackingService
                        let trackingService = MileageTrackingService.shared
                        trackingService.inject(modelContext: container.mainContext)

                        // Auto-start mileage tracking if conditions are met
                        autoStartMileageTrackingIfNeeded(trackingService: trackingService)
                        #endif

                        // Performance: End launch signpost + start ongoing monitoring
                        PerformanceMonitor.shared.launchCheckpoint("CriticalPathComplete")
                        PerformanceMonitor.shared.endLaunch()
                        PerformanceMonitor.shared.startMemoryMonitoring()

                        #if DEBUG
                        LaunchTimer.checkpoint("Critical path complete")
                        LaunchTimer.complete()
                        PerformanceMonitor.shared.logMemorySnapshot("PostLaunch")
                        #endif

                        // DEFERRED: Non-critical services after UI is visible
                        scheduleDeferredSetup(container: container)
                    }
                    .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                        // Never let sample tour data reach the shared widget store
                        if newValue && !isExploringSampleData {
                            updateWidgetData(container: container)
                        }
                    }
            } else {
                // Lightweight splash while ModelContainer + CloudKit init runs off main thread
                // Seamlessly extends LaunchScreen appearance. On slow cold starts
                // (CloudKit schema init can take ~2.5s on device) a spinner fades in
                // after a beat so the app reads as loading, not hung; fast launches
                // never see it.
                LaunchSplashView()
                    .task {
                        await loadContainerAsync()
                    }
            }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
        // Build 10 (Mac Catalyst menu-bar fix): this curated command set was
        // gated `#if os(macOS)`, which is FALSE under Mac Catalyst — so the
        // shipping Mac app fell back to auto-generated menus with no Cmd+N,
        // Cmd+, or Navigate shortcuts. Catalyst fully supports SwiftUI
        // `.commands`, so include it for Catalyst too. (MenuBarExtra below
        // stays macOS-only — it's an AppKit menu-bar Scene unavailable on
        // Catalyst.)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .commands {
            // Build 10: Replace new item with context-aware Cmd+N
            CommandGroup(replacing: .newItem) {
                Button("New Item") {
                    switch NavigationService.shared.selectedTab {
                    case .transactions: NavigationService.shared.showAddTransaction()
                    case .invoices:     NavigationService.shared.showCreateInvoice()
                    case .budgets:      NavigationService.shared.showCreateBudget()
                    default:            NavigationService.shared.showAddTransaction()
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Build 10: Cmd+, opens Settings (standard macOS pattern)
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    NavigationService.shared.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("Navigate") {
                ForEach(AppTab.allCases) { tab in
                    if let shortcut = tab.keyboardShortcut {
                        Button(tab.title) {
                            NavigationService.shared.navigateTo(tab)
                        }
                        .keyboardShortcut(shortcut, modifiers: .command)
                    }
                }

                Divider()

                // Build 10: Cmd+0 for tab 10 (settings), Shift+Cmd+0 for tab 11
                Button("Settings") {
                    NavigationService.shared.navigateTo(.settings)
                }
                .keyboardShortcut("0", modifiers: .command)

                Button("Tax") {
                    NavigationService.shared.navigateTo(.tax)
                }
                .keyboardShortcut("0", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        MenuBarExtra("FLO", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarWidgetView()
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    // MARK: - Async Container Loading

    /// Creates the ModelContainer on a background thread to avoid blocking the main thread.
    /// CloudKit schema initialization (~2.5s) happens off-screen while the splash view shows.
    // MARK: - Explore Tour

    /// Banner pinned above the tour so sample data can never be mistaken for
    /// real finances, with the exit affordance always in reach.
    private var exploreTourBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
            Text("Sample data tour")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("Start Fresh") {
                HapticService.play(.medium)
                exitExploreTour()
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(Color.brandPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You are viewing sample data. Double tap Start Fresh to exit the tour and set up your own finances.")
    }

    /// Seeds a fresh in-memory container (CloudKit disabled) with the demo
    /// dataset and swaps it in. The real store is never touched.
    private func enterExploreTour() {
        guard exploreContainer == nil else { return }
        let tourContainer = ModelContainer.preview()
        Task { @MainActor in
            await SeedDataService.shared.seedAllData(context: tourContainer.mainContext)
            exploreContainer = tourContainer
        }
    }

    /// Discards the tour container. Onboarding reappears (it was never
    /// completed) so the user can start their real setup.
    private func exitExploreTour() {
        exploreContainer = nil
    }

    private func loadContainerAsync() async {
        // When running under XCTest, the App Group container may not be available
        // and CloudKit schema validation can fail in the test runner environment.
        // Use an in-memory container so the host app can launch and tests can run.
        if NSClassFromString("XCTestCase") != nil {
            self.container = ModelContainer.preview()
            return
        }
        do {
            let newContainer = try await Task.detached(priority: .userInitiated) {
                try ModelContainer.shared()
            }.value

            PerformanceMonitor.shared.launchCheckpoint("ModelContainer")
            #if DEBUG
            LaunchTimer.checkpoint("ModelContainer created (async, off main thread)")
            #endif

            self.container = newContainer
        } catch {
            print("❌ CRITICAL: Failed to create ModelContainer: \(error)")
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Critical Path Setup (Blocks UI)
    
    /// Only the absolute essentials needed before UI renders
    private func setupAppCritical(container: ModelContainer) {
        let context = ModelContext(container)
        
        // Demo mode check
        if DemoConfiguration.isDemoMode {
            Task { @MainActor in
                await DemoConfiguration.configure(context: context)
            }
            return
        }
        
        // Seed default categories (fast - checks existing first)
        let seedResult = SeedData.seedDefaultCategories(in: context)
        if case .success(let count) = seedResult, count > 0 {
            print("✅ Seeded \(count) default categories")
        }
        
        // Migrate existing categories (fast - only touches changed items)
        SeedData.migrateCategories(in: context)

        // Multi-business migration (v2.0 - links existing accounts/invoices to primary business)
        BusinessMigrationService.shared.migrateIfNeeded(context: context)
        
        // NOTE: Migrations and recurring generation moved to scheduleDeferredSetup() +0.3s
        // to improve cold start time (was blocking UI for ~500ms)
    }
    
    // MARK: - Recurring Transfer Generation
    
    /// Generates any due transfers from recurring schedules.
    /// Called once on app launch to catch up on any missed transfers.
    private func generateDueRecurringTransfers(context: ModelContext) async {
        // Use TransferService to generate due transfers
        let generatedTransfers = TransferService.shared.generateDueRecurringTransfers(context: context)

        if !generatedTransfers.isEmpty {
            print("✅ Generated \(generatedTransfers.count) recurring transfer(s)")

            #if DEBUG
            for transfer in generatedTransfers {
                print("   💸 \(transfer.transferType.displayName): \(transfer.formattedAmount)")
            }
            #endif
        } else {
            #if DEBUG
            print("ℹ️ No recurring transfers due")
            #endif
        }
    }
    
    // MARK: - Deferred Setup (After UI Visible)
    
    /// Non-critical services deferred to improve cold start time
    private func scheduleDeferredSetup(container: ModelContainer) {
        // DEFER 0.3s: Migrations & recurring generation (moved from setupAppCritical for faster cold start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            let context = ModelContext(container)

            // ONE-TIME: Migrate transfer-flagged transactions to Transfer records
            if TransferMigrationService.shouldRunMigration() {
                Task { @MainActor in
                    let result = await TransferMigrationService.shared.migrateTransferTransactions(context: context)
                    if result.successCount > 0 {
                        print("🎯 Migrated \(result.successCount) transfer transaction(s)")
                    }
                }
            }

            // ONE-TIME: Fix liability accounts with positive balances (polarity bug)
            if LiabilityBalanceMigrationService.shouldRunMigration() {
                let result = LiabilityBalanceMigrationService.shared.migrateLiabilityBalances(context: context)
                if result.accountsFixed > 0 {
                    print("🔧 Fixed \(result.accountsFixed) liability account balance(s)")
                }
            }

            #if DEBUG
            print("⏱️ [Deferred +300ms] Migrations complete")
            #endif
        }

        // DEFER 2.0s: Recurring transaction + transfer generation.
        //
        // Previously ran at +0.3s alongside migrations. That was earlier than
        // SwiftData+CloudKit's initial remote import could finish, creating a
        // race where Device B would materialize today's recurring instance
        // before receiving Device A's already-created copy. Duplicates stuck
        // around because the scrubber only ran once per install.
        //
        // Pushing to +2s gives CloudKit a window to import "already done"
        // records so the lastCreated flag + relationship dedup in
        // RecurringTransaction.createNextInstance see the remote copy and
        // correctly skip generation. The always-on scrubber at +5s handles
        // any that still slip through.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
            let context = ModelContext(container)
            Task { @MainActor in
                await RecurringTransactionService.shared.createPendingInstances(in: container)
            }
            Task { @MainActor in
                await self.generateDueRecurringTransfers(context: context)
            }

            #if DEBUG
            print("⏱️ [Deferred +2s] Recurring generation complete")
            #endif
        }

        // DEFER 5.0s: Always-on duplicate scrubber.
        //
        // Pre-v3.13 this was gated by `duplicatesScrubbed_v1` in UserDefaults
        // and ran exactly once per install. That left the CloudKit sync-race
        // hole open: new duplicates created AFTER the first scrub were
        // permanent. Now runs every launch, after recurring generation at +2s
        // so same-launch dupes also get caught, and after CloudKit has had
        // time to import remote records so cross-device dupes are visible.
        //
        // The scrubber keeps the earliest-created row in each duplicate group
        // and only acts when ALL rows share the same amount + category — user
        // edits to one copy are left alone for manual resolution.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            Task { @MainActor in
                let result = await RecurringTransactionService.shared.scrubDuplicateRecurringTransactions(in: container)
                #if DEBUG
                if result.transactionsDeleted > 0 {
                    print("🧹 Duplicate scrubber: removed \(result.transactionsDeleted) tx across \(result.duplicateGroups) group(s); rebalanced \(result.accountsRebalanced) account(s)")
                }
                #endif
            }
        }

        #if os(iOS)
        // DEFER 0.5s: Quick actions & haptic preparation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            QuickActionService.shared.updateShortcuts()
            HapticService.prepareAll()
            #if DEBUG
            print("⏱️ [Deferred +500ms] Quick actions & haptics prepared")
            #endif
        }

        // DEFER 1.0s: Watch connectivity
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            WatchConnectivityService.shared.activateSession()
            #if DEBUG
            print("⏱️ [Deferred +1000ms] WatchConnectivity activated")
            #endif
        }
        #endif
        #endif
        
        // DEFER 1.5s: Widget data refresh + iCloud Sync monitoring
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.updateWidgetData(container: container)
            CloudSyncService.shared.initialize()

            // Verify Apple Sign In credential state
            Task {
                await AppleAuthService.shared.checkCredentialState()
                #if DEBUG
                print("🍎 [Deferred +1500ms] Apple Sign In: \(AppleAuthService.shared.isSignedIn ? "signed in" : "not signed in")")
                #endif
            }

            #if DEBUG
            print("⏱️ [Deferred +1500ms] Widget data refreshed + CloudSync initialized")
            #endif
        }
        
        // DEFER 2.0s: Spotlight indexing (heaviest operation)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            SpotlightIndexingService.shared.reindexAll(modelContext: container.mainContext)
            #if DEBUG
            print("⏱️ [Deferred +2000ms] Spotlight indexing complete")
            #endif
        }

        // DEFER 2.5s: Push notification registration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            Task { @MainActor in
                let status = await NotificationPermissionHelper.checkStatus()
                if status == .authorized || status == .provisional {
                    PushNotificationService.shared.registerForPushNotifications()
                }
                #if DEBUG
                print("⏱️ [Deferred +2500ms] Push notification registration (\(status))")
                #endif
            }
        }

        // DEFER 3.0s: Auto-Recurring Detection (Build 8, Premium+)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            Task { @MainActor in
                let tier = SubscriptionManager.shared.currentTier
                if tier.hasRecurringTransactions {
                    await RecurringDetectionService.shared.analyzeTransactions(in: container)
                }
                #if DEBUG
                print("⏱️ [Deferred +3000ms] Recurring detection (\(tier.displayName))")
                #endif
            }
        }

        // DEFER 3.5s: Debt Accelerator payment reminders (Premium+)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            Task { @MainActor in
                let tier = SubscriptionManager.shared.currentTier
                if tier.canAccess(.debtCalculator) {
                    let context = container.mainContext
                    let planDescriptor = FetchDescriptor<DebtAcceleratorPlan>()
                    if let plans = try? context.fetch(planDescriptor),
                       let activePlan = plans.first(where: { $0.isActive }) {
                        let accountDescriptor = FetchDescriptor<Account>()
                        let accounts = (try? context.fetch(accountDescriptor)) ?? []
                        await DebtPaymentReminderService.shared.scheduleReminders(
                            for: activePlan,
                            accounts: accounts
                        )
                    }
                }
                #if DEBUG
                print("⏱️ [Deferred +3500ms] Debt payment reminders scheduled (\(tier.displayName))")
                #endif
            }
        }

        // DEFER 4.0s: Cash Flow Forecast (Build 8, Premium+)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            Task { @MainActor in
                let tier = SubscriptionManager.shared.currentTier
                if tier.hasRecurringTransactions {
                    _ = await CashFlowForecastService.shared.generateForecast(in: container)
                }
                #if DEBUG
                print("⏱️ [Deferred +3500ms] Cash flow forecast (\(tier.displayName))")
                #endif
            }
        }

        // DEFER 4.0s: Household loading (Build 8, Pro only)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            Task { @MainActor in
                let tier = SubscriptionManager.shared.currentTier
                if tier.hasHouseholdSharing {
                    await HouseholdService.shared.loadCurrentHousehold(in: container)
                }
                #if DEBUG
                print("⏱️ [Deferred +4000ms] Household loading (\(tier.displayName))")
                #endif
            }
        }
    }

    // MARK: - Legacy Core Data Store Cleanup
    
    /// Removes legacy Core Data store from App Group to enable clean SwiftData migration
    /// This is a ONE-TIME operation that runs only if the legacy store exists
    private static func purgeLegacyCoreDataStoreIfNeeded() {
        // Check UserDefaults to see if we've already done this
        let hasCleanedLegacyStore = UserDefaults.standard.bool(forKey: "FLO.HasCleanedLegacyStore")
        
        if hasCleanedLegacyStore {
            // Already cleaned, skip
            return
        }
        
        print("🔍 Checking for legacy Core Data store...")
        
        // Get App Group container URL
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.finchandpoppy.flo"
        ) else {
            print("⚠️ Could not access App Group container")
            return
        }
        
        let legacyStoreDirectory = groupURL.appendingPathComponent("Library/Application Support")
        let legacyStoreFile = legacyStoreDirectory.appendingPathComponent("default.store")
        
        // Check if legacy store exists
        if FileManager.default.fileExists(atPath: legacyStoreFile.path) {
            print("🧹 Found legacy Core Data store, removing...")
            
            do {
                // Delete the entire Application Support directory in App Group
                // This removes default.store, default.store-shm, default.store-wal, etc.
                try FileManager.default.removeItem(at: legacyStoreDirectory)
                print("✅ Legacy Core Data store removed successfully")
            } catch {
                print("⚠️ Could not remove legacy store: \(error)")
                // Continue anyway - ModelContainer might be able to work around it
            }
        } else {
            print("✅ No legacy Core Data store found - clean SwiftData environment")
        }
        
        // Mark as cleaned so we never do this again
        UserDefaults.standard.set(true, forKey: "FLO.HasCleanedLegacyStore")
        print("✅ Legacy store cleanup complete")
    }
    
    // MARK: - Widget Data Update

    // Static debounce: prevents double-updates when both onChange(isAuthenticated) and the
    // 1.5s deferred setup fire within a short window on launch.
    private static var lastWidgetUpdateTime: Date = .distantPast

    private func updateWidgetData(container: ModelContainer) {
        let now = Date()
        let elapsed = now.timeIntervalSince(Self.lastWidgetUpdateTime)
        guard elapsed > 2.0 else {
            #if DEBUG
            print("⏭️ [Widget] Skipped duplicate update (within 2s debounce, elapsed=\(String(format: "%.1f", elapsed))s)")
            #endif
            return
        }
        Self.lastWidgetUpdateTime = now
        Task { @MainActor in
            let context = ModelContext(container)
            
            do {
                // Fetch all data needed for widget
                let transactions = try context.fetch(FetchDescriptor<Transaction>())
                let invoices = try context.fetch(FetchDescriptor<Invoice>())
                
                // Call the widget service with the fetched data
                // WidgetDataService.updateWidgetData is nonisolated and handles thread safety
                try await WidgetDataService.shared.updateWidgetData(
                    transactions: transactions,
                    invoices: invoices
                )
                
                print("✅ Widget data updated: \(transactions.count) transactions, \(invoices.count) invoices")
                
            } catch {
                print("❌ Widget update failed: \(error.localizedDescription)")
            }
        }
    }
    
    #if os(iOS)
    // MARK: - Mileage Tracking Auto-Start

    /// Automatically starts mileage tracking if all conditions are met.
    /// This is critical for background location tracking to work properly.
    /// Without this, tracking only starts when user visits the Mileage Tracking view.
    ///
    /// UPDATED v3.3: Now checks subscription tier - Free users can't auto-start GPS tracking
    private func autoStartMileageTrackingIfNeeded(trackingService: MileageTrackingService) {
        // NEW in v3.3: CHECK SUBSCRIPTION TIER FIRST
        // Free tier users don't get automated GPS mileage tracking
        guard subscriptionManager.currentTier.hasAutomatedMileage else {
            print("⏭️ Mileage tracking: Free tier - GPS tracking not available")
            print("   ℹ️ Manual trip entry is available for all tiers")
            return
        }
        
        // Check if mileage setup has been completed
        let mileageSetupCompleted = UserDefaults.standard.bool(forKey: "mileageSetupCompleted")
        guard mileageSetupCompleted else {
            print("⏭️ Mileage tracking: Setup not completed - skipping auto-start")
            return
        }
        
        // Check if user has enabled tracking (default is true after setup)
        let mileageTrackingEnabled = UserDefaults.standard.bool(forKey: "mileageTrackingEnabled")
        
        // Check if tracking was active before app was killed (restoration)
        let wasTrackingActive = UserDefaults.standard.bool(forKey: "mileage.isTrackingActive")
        
        // User's explicit preference is the primary gate.
        // wasTrackingActive is only used to restore after an app kill
        // when the user hasn't explicitly disabled tracking.
        guard mileageTrackingEnabled else {
            // If user disabled tracking, clear the stale wasActive flag
            if wasTrackingActive {
                UserDefaults.standard.set(false, forKey: "mileage.isTrackingActive")
                print("⏭️ Mileage tracking: Disabled by user - cleared stale active flag")
            }
            print("⏭️ Mileage tracking: Disabled by user - skipping auto-start")
            return
        }
        
        // CRITICAL: Check for "Always Allow" permission
        // Background tracking REQUIRES Always permission
        let permissionStatus = trackingService.trackingPermissionStatus
        guard permissionStatus == .authorizedAlways else {
            if permissionStatus == .authorizedWhenInUse {
                print("⚠️ Mileage tracking: Only 'When In Use' permission - limited mode")
                // Could start in limited mode, but it won't work in background
                // For now, don't auto-start to avoid user confusion
            } else {
                print("⏭️ Mileage tracking: No location permission - skipping auto-start")
            }
            return
        }
        
        // All conditions met - start tracking!
        if !trackingService.isTracking {
            trackingService.startTracking()
            print("✅ Mileage tracking AUTO-STARTED on app launch")
            print("   - Subscription: \(subscriptionManager.currentTier.displayName) ✔")
            print("   - Setup completed: ✔")
            print("   - User enabled: \(mileageTrackingEnabled)")
            print("   - Was active: \(wasTrackingActive)")
            print("   - Permission: Always Allow ✔")
        } else {
            print("ℹ️ Mileage tracking: Already running")
        }
    }
    #endif // os(iOS)
}

// MARK: - Launch Splash

/// Shown while the ModelContainer (and CloudKit schema, on cold starts) is
/// created off the main thread. Extends the LaunchScreen background; after a
/// short delay a spinner fades in so long cold starts read as loading rather
/// than frozen. Fast launches never see the spinner.
private struct LaunchSplashView: View {
    @State private var showSpinner = false

    var body: some View {
        ZStack {
            Color.floSystemBackground
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
                .opacity(showSpinner ? 1 : 0)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeIn(duration: 0.3)) {
                showSpinner = true
            }
        }
        .accessibilityLabel("FLO is loading")
    }
}
