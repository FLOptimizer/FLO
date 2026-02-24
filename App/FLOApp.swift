//  FLOApp.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.5 - UTF-8 mojibake fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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

// MARK: - AppDelegate

/// AppDelegate for handling notifications, background launches, and Universal Links
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        
        // Configure notification categories
        TaxNotificationService.shared.configureNotificationCategories()
        
        // Set delegate for handling notifications
        UNUserNotificationCenter.current().delegate = self
        
        print("✅ Notification categories configured")
        print("✅ Tax notification service configured")
        
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
        
        guard (wasTrackingActive || mileageTrackingEnabled) && mileageSetupCompleted else {
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
    
    // MARK: - Notification Handling
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        TaxNotificationService.shared.handleNotificationAction(
            response.actionIdentifier,
            for: response.notification
        )
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

// MARK: - FLOApp

@main
struct FLOApp: App {
    // MARK: - Properties (ALL declared BEFORE init)
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let container: ModelContainer
    @StateObject private var authService = BiometricAuthService.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    // MARK: - Initialization
    
    init() {
            // CRITICAL: Purge any legacy Core Data store first
            Self.purgeLegacyCoreDataStoreIfNeeded()
            
            // In UI testing / demo mode, use in-memory container to avoid App Group issues
            let isTestingMode = ProcessInfo.processInfo.arguments.contains("UI_TESTING") ||
                                ProcessInfo.processInfo.arguments.contains("DEMO_MODE")
            
            if isTestingMode {
                container = ModelContainer.preview()
                print("🎬 Using in-memory ModelContainer for testing/demo mode")
                return
            }
            
            do {
                container = try ModelContainer.shared()
                print("✅ ModelContainer created with custom store URL")
                print("✅ Using: FLOSwiftData.store (NOT default.store)")
            } catch {
                print("❌ CRITICAL: Failed to create ModelContainer: \(error)")
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(authService)
                .environmentObject(subscriptionManager)
                .fullScreenCover(isPresented: Binding(
                    get: { !hasCompletedOnboarding },
                    set: { hasCompletedOnboarding = !$0 }
                )) {
                    OnboardingView()
                }
                .task {
                    await subscriptionManager.initialize()
                }
                .onAppear {
                    setupApp()
                    
                    // Inject ModelContext into MileageTrackingService
                    let trackingService = MileageTrackingService.shared
                    trackingService.inject(modelContext: container.mainContext)
                    print("✅ ModelContext injected into MileageTrackingService")
                    
                    // Auto-start mileage tracking if conditions are met (includes subscription check)
                    autoStartMileageTrackingIfNeeded(trackingService: trackingService)
                    
                    // Update home screen quick actions
                    QuickActionService.shared.updateShortcuts()
                    
                    // Index entities for Spotlight search
                    SpotlightIndexingService.shared.reindexAll(modelContext: container.mainContext)
                }
                .onChange(of: authService.isAuthenticated) { oldValue, newValue in
                    if newValue {
                        updateWidgetData()
                    }
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
    
    // MARK: - App Setup
    
    private func setupApp() {
        let context = ModelContext(container)
        
        // NEW: Demo mode configuration (video recording)
        if DemoConfiguration.isDemoMode {
            Task { @MainActor in
                await DemoConfiguration.configure(context: context)
            }
            return  // Skip normal setup when in demo mode
        }
        
        // Seed default categories
        let seedResult = SeedData.seedDefaultCategories(in: context)
        switch seedResult {
        case .success(let count):
            if count > 0 {
                print("✅ Seeded \(count) default categories")
            }
        case .failure(let error):
            print("❌ Seed failed: \(error.localizedDescription)")
        }
        
        // Migrate existing categories (fixes invalid icons, etc.)
        SeedData.migrateCategories(in: context)
        
        // Create any missed recurring transactions - safe & fast on every launch
        Task { @MainActor in
            await RecurringTransactionService.shared.createPendingInstances(in: container)
        }
        
        // Refresh widgets with latest data
        updateWidgetData()
    }
    
    private func updateWidgetData() {
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
        
        // Either currently enabled OR was active before = should start
        guard mileageTrackingEnabled || wasTrackingActive else {
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
}
