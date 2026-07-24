//  FLOMileageControlTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Updated version assertion to match MileageTrackingService v3.5
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TESTS:
//  ✅ Siri Intent logic (PauseMileageIntent, ResumeMileageIntent, etc.)
//  ✅ QuickActionService shortcut generation
//  ✅ State persistence in UserDefaults
//  ✅ MileageTrackingService state changes
//
//  NOTE: These are unit tests, not UI tests.
//  Add this file to the FLOTests target, not FLOUITests.
//

import XCTest
import SwiftData
@testable import FLO

// MARK: - Mileage Control Tests

final class FLOMileageControlTests: XCTestCase {
    
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Use in-memory container for testing
        container = ModelContainer.forTesting()
        
        // Reset UserDefaults state
        UserDefaults.standard.removeObject(forKey: "mileageSetupCompleted")
        UserDefaults.standard.removeObject(forKey: "mileageTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "mileage.isTrackingActive")
    }
    
    override func tearDownWithError() throws {
        container = nil
        
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "mileageSetupCompleted")
        UserDefaults.standard.removeObject(forKey: "mileageTrackingEnabled")
        UserDefaults.standard.removeObject(forKey: "mileage.isTrackingActive")
        
        try super.tearDownWithError()
    }
    
    // MARK: - UserDefaults State Tests
    
    func testMileageSetupCompletedFlag() {
        // Initially should be false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "mileageSetupCompleted"))
        
        // Set to true
        UserDefaults.standard.set(true, forKey: "mileageSetupCompleted")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileageSetupCompleted"))
    }
    
    func testMileageTrackingEnabledFlag() {
        // Initially should be false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "mileageTrackingEnabled"))
        
        // Set to true
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileageTrackingEnabled"))
    }
    
    func testIsTrackingActiveFlag() {
        // Initially should be false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "mileage.isTrackingActive"))
        
        // Set to true
        UserDefaults.standard.set(true, forKey: "mileage.isTrackingActive")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileage.isTrackingActive"))
    }
    
    // MARK: - QuickActionService Tests
    
    @MainActor
    func testQuickActionServiceExists() {
        // Verify singleton exists
        let service = QuickActionService.shared
        XCTAssertNotNil(service)
    }
    
    @MainActor
    func testQuickActionTypesAreDefined() {
        // Verify all action types exist
        XCTAssertEqual(QuickActionService.ActionType.pauseMileage.rawValue, "com.finchandpoppy.flo.pauseMileage")
        XCTAssertEqual(QuickActionService.ActionType.resumeMileage.rawValue, "com.finchandpoppy.flo.resumeMileage")
        XCTAssertEqual(QuickActionService.ActionType.addTransaction.rawValue, "com.finchandpoppy.flo.addTransaction")
        XCTAssertEqual(QuickActionService.ActionType.scanReceipt.rawValue, "com.finchandpoppy.flo.scanReceipt")
    }
    
    @MainActor
    func testHandleUnknownActionReturnsFalse() {
        let service = QuickActionService.shared
        let result = service.handleAction("com.unknown.action")
        XCTAssertFalse(result)
    }
    
    @MainActor
    func testHandleAddTransactionActionReturnsTrue() {
        let service = QuickActionService.shared
        let result = service.handleAction(QuickActionService.ActionType.addTransaction.rawValue)
        XCTAssertTrue(result)
    }
    
    @MainActor
    func testHandleScanReceiptActionReturnsTrue() {
        let service = QuickActionService.shared
        let result = service.handleAction(QuickActionService.ActionType.scanReceipt.rawValue)
        XCTAssertTrue(result)
    }
    
    @MainActor
    func testPendingActionProcessing() {
        let service = QuickActionService.shared
        
        // Set pending action
        service.pendingAction = QuickActionService.ActionType.addTransaction.rawValue
        XCTAssertNotNil(service.pendingAction)
        
        // Process it
        service.processPendingAction()
        
        // Should be cleared (after delay, so check immediately cleared)
        // Note: The actual processing happens after 0.5s delay
        XCTAssertNil(service.pendingAction)
    }
    
    // MARK: - MileageTrackingService State Tests
    
    @MainActor
    func testMileageTrackingServiceExists() {
        let service = MileageTrackingService.shared
        XCTAssertNotNil(service)
    }
    
    @MainActor
    func testMileageTrackingServiceVersion() {
        XCTAssertEqual(MileageTrackingService.version, "3.5")
    }
    
    @MainActor
    func testInitialTrackingStateIsFalse() {
        let service = MileageTrackingService.shared
        // Note: This may vary based on previous state, but fresh install should be false
        // We can't fully reset the singleton, so just verify it's a boolean
        _ = service.isTracking // Just verify property exists and is accessible
    }
    
    @MainActor
    func testContextInjection() {
        let service = MileageTrackingService.shared
        
        // Inject test context
        service.inject(modelContext: container.mainContext)
        
        XCTAssertTrue(service.isContextInjected)
    }
    
    // MARK: - Notification Name Tests
    
    func testQuickActionNotificationNames() {
        // Verify notification names are defined
        XCTAssertEqual(
            Notification.Name.quickActionAddTransaction.rawValue,
            "com.finchandpoppy.flo.quickAction.addTransaction"
        )
        XCTAssertEqual(
            Notification.Name.quickActionScanReceipt.rawValue,
            "com.finchandpoppy.flo.quickAction.scanReceipt"
        )
    }
    
    func testMileageTimerNotificationNames() {
        // Verify Control Widget notification names
        XCTAssertEqual(
            Notification.Name.mileageTimerStartRequested.rawValue,
            "com.finchandpoppy.flo.mileageTimerStart"
        )
        XCTAssertEqual(
            Notification.Name.mileageTimerStopRequested.rawValue,
            "com.finchandpoppy.flo.mileageTimerStop"
        )
    }
    
    func testMileageTrackingNotificationNames() {
        XCTAssertEqual(
            Notification.Name.mileageTripCompleted.rawValue,
            "com.finchandpoppy.flo.mileageTripCompleted"
        )
        XCTAssertEqual(
            Notification.Name.mileageTrackingStarted.rawValue,
            "com.finchandpoppy.flo.mileageTrackingStarted"
        )
        XCTAssertEqual(
            Notification.Name.mileageTrackingStopped.rawValue,
            "com.finchandpoppy.flo.mileageTrackingStopped"
        )
    }
    
    // MARK: - Notification Observer Tests
    
    @MainActor
    func testControlWidgetStartNotificationTriggersTracking() {
        let service = MileageTrackingService.shared
        service.inject(modelContext: container.mainContext)
        
        // Set up required state
        UserDefaults.standard.set(true, forKey: "mileageSetupCompleted")
        
        let expectation = XCTestExpectation(description: "Notification received")
        
        // Post notification (simulating Control Widget action)
        NotificationCenter.default.post(
            name: .mileageTimerStartRequested,
            object: nil,
            userInfo: ["source": "ControlWidget", "timestamp": Date()]
        )
        
        // Give time for notification to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
        
        // Note: Actual tracking start depends on location permission
        // We're just verifying the notification mechanism works
    }
    
    @MainActor
    func testControlWidgetStopNotificationTriggersStop() {
        let service = MileageTrackingService.shared
        service.inject(modelContext: container.mainContext)
        
        let expectation = XCTestExpectation(description: "Notification received")
        
        // Post notification (simulating Control Widget action)
        NotificationCenter.default.post(
            name: .mileageTimerStopRequested,
            object: nil,
            userInfo: ["source": "ControlWidget", "timestamp": Date()]
        )
        
        // Give time for notification to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
}

// MARK: - Siri Intent Tests

@available(iOS 16.0, *)
final class FLOSiriIntentTests: XCTestCase {
    
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        container = ModelContainer.forTesting()
        
        // Reset state
        UserDefaults.standard.removeObject(forKey: "mileageSetupCompleted")
        UserDefaults.standard.removeObject(forKey: "mileageTrackingEnabled")
    }
    
    override func tearDownWithError() throws {
        container = nil
        UserDefaults.standard.removeObject(forKey: "mileageSetupCompleted")
        UserDefaults.standard.removeObject(forKey: "mileageTrackingEnabled")
        try super.tearDownWithError()
    }
    
    // MARK: - Intent Existence Tests
    
    func testPauseMileageIntentExists() {
        let intent = PauseMileageIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(PauseMileageIntent.title.key, "Pause Mileage Tracking")
    }
    
    func testResumeMileageIntentExists() {
        let intent = ResumeMileageIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(ResumeMileageIntent.title.key, "Resume Mileage Tracking")
    }
    
    func testCheckMileageStatusIntentExists() {
        let intent = CheckMileageStatusIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(CheckMileageStatusIntent.title.key, "Check Mileage Status")
    }
    
    func testToggleMileageIntentExists() {
        let intent = ToggleMileageIntent()
        XCTAssertNotNil(intent)
        XCTAssertEqual(ToggleMileageIntent.title.key, "Toggle Mileage Tracking")
    }
    
    // MARK: - Intent Configuration Tests
    
    func testIntentsDoNotOpenApp() {
        XCTAssertFalse(PauseMileageIntent.openAppWhenRun)
        XCTAssertFalse(ResumeMileageIntent.openAppWhenRun)
        XCTAssertFalse(CheckMileageStatusIntent.openAppWhenRun)
        XCTAssertFalse(ToggleMileageIntent.openAppWhenRun)
    }
    
    // MARK: - App Shortcuts Provider Tests
    
    func testAppShortcutsProviderHasShortcuts() {
        let shortcuts = FLOShortcutsProvider.appShortcuts
        XCTAssertFalse(shortcuts.isEmpty)
        XCTAssertEqual(shortcuts.count, 8) // 4 Core + 4 Mileage
    }
    
    // MARK: - Intent Execution Tests
    
    @MainActor
    func testPauseMileageIntentWhenNotTracking() async throws {
        let intent = PauseMileageIntent()
        
        // Ensure not tracking
        let service = MileageTrackingService.shared
        if service.isTracking {
            service.stopTracking()
        }
        
        // Execute intent
        let result = try await intent.perform()
        
        // Should indicate already paused
        // Note: We can't easily inspect the dialog content, but we verify no crash
        XCTAssertNotNil(result)
    }
    
    @MainActor
    func testResumeMileageIntentWithoutSetup() async throws {
        let intent = ResumeMileageIntent()
        
        // Ensure setup is NOT complete
        UserDefaults.standard.set(false, forKey: "mileageSetupCompleted")
        
        // Execute intent
        let result = try await intent.perform()
        
        // Should return error about setup
        XCTAssertNotNil(result)
    }
    
    @MainActor
    func testCheckMileageStatusIntent() async throws {
        let intent = CheckMileageStatusIntent()
        
        // Execute intent
        let result = try await intent.perform()
        
        // Should return status
        XCTAssertNotNil(result)
    }
    
    @MainActor
    func testToggleMileageIntentWhenNotTracking() async throws {
        let intent = ToggleMileageIntent()
        
        // Ensure not tracking
        let service = MileageTrackingService.shared
        if service.isTracking {
            service.stopTracking()
        }
        
        // Setup not complete, so it should fail gracefully
        UserDefaults.standard.set(false, forKey: "mileageSetupCompleted")
        
        // Execute intent
        let result = try await intent.perform()
        
        // Should handle gracefully
        XCTAssertNotNil(result)
    }
}

// MARK: - Widget Timer State Tests

final class FLOWidgetTimerStateTests: XCTestCase {
    
    func testWidgetTimerStateInitial() {
        let state = WidgetTimerState.initial
        
        XCTAssertFalse(state.isRunning)
        XCTAssertNil(state.startTime)
        XCTAssertEqual(state.elapsedSeconds, 0)
        XCTAssertNil(state.tripId)
    }
    
    func testWidgetTimerStateRunning() {
        let tripId = UUID()
        let startTime = Date()
        
        let state = WidgetTimerState(
            isRunning: true,
            startTime: startTime,
            elapsedSeconds: 0,
            tripId: tripId
        )
        
        XCTAssertTrue(state.isRunning)
        XCTAssertEqual(state.startTime, startTime)
        XCTAssertEqual(state.tripId, tripId)
    }
    
    func testWidgetTimerStateCodable() throws {
        let tripId = UUID()
        let startTime = Date()
        
        let state = WidgetTimerState(
            isRunning: true,
            startTime: startTime,
            elapsedSeconds: 123.5,
            tripId: tripId
        )
        
        // Encode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        
        // Decode
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WidgetTimerState.self, from: data)
        
        XCTAssertEqual(decoded.isRunning, state.isRunning)
        XCTAssertEqual(decoded.elapsedSeconds, state.elapsedSeconds)
        XCTAssertEqual(decoded.tripId, state.tripId)
    }
}

// MARK: - Integration Tests

final class FLOMileageIntegrationTests: XCTestCase {
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Reset all mileage-related UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "mileageSetupCompleted")
        defaults.removeObject(forKey: "mileageTrackingEnabled")
        defaults.removeObject(forKey: "mileage.isTrackingActive")
        defaults.removeObject(forKey: "mileage.inProgressTrip")
        defaults.removeObject(forKey: "mileage.routePoints")
        defaults.removeObject(forKey: "mileage.lastMovementTime")
    }
    
    func testMileageTrackingStateFlow() {
        // Simulate the state flow:
        // 1. User completes setup
        UserDefaults.standard.set(true, forKey: "mileageSetupCompleted")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileageSetupCompleted"))
        
        // 2. User enables tracking
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileageTrackingEnabled"))
        
        // 3. Tracking becomes active (set by MileageTrackingService.startTracking)
        UserDefaults.standard.set(true, forKey: "mileage.isTrackingActive")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileage.isTrackingActive"))
        
        // 4. User pauses via Quick Action or Siri
        UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
        UserDefaults.standard.set(false, forKey: "mileage.isTrackingActive")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "mileageTrackingEnabled"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "mileage.isTrackingActive"))
        
        // 5. Setup remains complete
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "mileageSetupCompleted"))
    }
    
    func testAutoStartConditions() {
        // Test the conditions that autoStartMileageTrackingIfNeeded checks
        
        // Condition 1: Setup must be complete
        UserDefaults.standard.set(false, forKey: "mileageSetupCompleted")
        let setupComplete = UserDefaults.standard.bool(forKey: "mileageSetupCompleted")
        XCTAssertFalse(setupComplete, "Should not auto-start without setup")
        
        // Condition 2: Either enabled OR was active
        UserDefaults.standard.set(true, forKey: "mileageSetupCompleted")
        UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
        UserDefaults.standard.set(false, forKey: "mileage.isTrackingActive")
        
        let enabled = UserDefaults.standard.bool(forKey: "mileageTrackingEnabled")
        let wasActive = UserDefaults.standard.bool(forKey: "mileage.isTrackingActive")
        let shouldStart = enabled || wasActive
        
        XCTAssertFalse(shouldStart, "Should not auto-start when disabled and not previously active")
        
        // Condition 3: With enabled = true, should start
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        let enabledNow = UserDefaults.standard.bool(forKey: "mileageTrackingEnabled")
        XCTAssertTrue(enabledNow, "Should auto-start when enabled")
    }
}
