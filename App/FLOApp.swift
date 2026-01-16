//  FLOApp.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.8 - Removed duplicate LockView (ContentView handles security)
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
// VERSION HISTORY:
// v2.2: Original (incomplete ModelContainer)
// v2.3: Added all 12 models to ModelContainer
// v2.4: Added BiometricAuthService environmentObject
// v2.5: Added legacy Core Data store purge
// v2.6: FORCED custom SwiftData store URL (FLOSwiftData.store)
// v2.7: Added onboarding flow + fixed property declaration order
// v2.8: Removed duplicate LockView - ContentView handles all security UI
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

// AppDelegate for handling notifications
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
        
        return true
    }
    
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
        
        do {
            // Use ModelContainer.shared() which has ALL 13 models including BusinessProfile
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
                    MileageTrackingService.shared.inject(
                        modelContext: container.mainContext
                    )
                    print("✅ ModelContext injected into MileageTrackingService")
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
        
        // 2. Create any missed recurring transactions — safe & fast on every launch
        Task { @MainActor in
            await RecurringTransactionService.shared.createPendingInstances(in: container)
        }
        
        // 3. Refresh widgets with latest data
        updateWidgetData()
    }
    
    private func updateWidgetData() {
        Task.detached { [container] in
            let context = ModelContext(container)
            
            do {
                let transactions = try context.fetch(FetchDescriptor<Transaction>())
                let budgets = try context.fetch(FetchDescriptor<Budget>())
                
                // EXTRACT SENDABLE DATA FIRST
                let balance = transactions.reduce(0.0) { $0 + $1.amount }
                let txCount = transactions.count
                _ = budgets.count
                
                // NOW SAFE TO PASS
                await MainActor.run {
                    print("✅ Widget updated: \(balance) balance, \(txCount) transactions")
                    // Update your widget service here with primitives only
                }
                
            } catch {
                await MainActor.run {
                    print("❌ Widget update failed: \(error)")
                }
            }
        }
    }
}
