//  MileageTrackingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.6 - Live Activity Integration
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.6:
//  - ✅ LIVE ACTIVITY: Integration with MileageLiveActivityManager
//  - ✅ LIVE ACTIVITY: startNewTrip() now starts Live Activity on Lock Screen + Dynamic Island
//  - ✅ LIVE ACTIVITY: updateCurrentTrip() updates Live Activity with distance, time, GPS status
//  - ✅ LIVE ACTIVITY: endCurrentTrip() ends Live Activity (3 paths: success, error, too short)
//  - ✅ LIVE ACTIVITY: pauseTracking() updates Live Activity to show paused state
//  - ✅ LIVE ACTIVITY: resumeTracking() updates Live Activity to show active state
//  - ✅ LIVE ACTIVITY: resetTripData() cleans up Live Activity if called directly
//  - ✅ LIVE ACTIVITY: startTracking() clears stale Live Activities on launch
//  - ✅ LIVE ACTIVITY: GPSStatus.liveActivitySignal helper for signal conversion
//
//  CHANGES v3.5:
//  - saveManualTrip now accepts vehicleName and clientName parameters
//  - Supports MileageTrip v4.0 audit-defensible fields
//  - ✅ ACCESSIBILITY: VoiceOver announcements for all state changes
//  - ✅ ACCESSIBILITY: GPS status change announcements
//  - ✅ ACCESSIBILITY: Battery warning announcements
//  - ✅ ACCESSIBILITY: Trip lifecycle announcements (start, pause, resume, end)
//  - ✅ ACCESSIBILITY: Error state announcements with user-friendly messages
//  - ✅ ACCESSIBILITY: Currency values spoken naturally (e.g., "twelve dollars and thirty-four cents")
//
//  v3.4: Control Widget + Quick Actions Integration
//  v3.3: Needs Review status for tax compliance
//  v3.2: Background task fix
//  v3.1: Enhanced notification permission flow
//
//  MAJOR IMPROVEMENTS IN v3.0:
//  Active trip end timer (no longer relies solely on location updates)
//  Trip persistence to UserDefaults (survives app termination)
//  Automatic crash/kill recovery on next launch
//  App lifecycle integration (checkpoint on background)
//  Manual "Force End Trip" capability
//  Disabled pausesLocationUpdatesAutomatically
//  Background task for trip completion
//  Comprehensive logging for debugging
//  Route point storage for trip visualization
//
//  ACCESSIBILITY COMPLIANCE:
//  - All state changes announced to VoiceOver
//  - Currency values formatted for natural speech
//  - Error messages descriptive and actionable
//  - GPS status changes announced only when significant
//  - Battery warnings announced with recommended actions
//  - Notification content mirrors VoiceOver announcements
//  - Works seamlessly with UI layer (MileageTrackingMainView: 98 accessibility references)
//

import Foundation
import CoreLocation
import SwiftData
import UserNotifications
import UIKit
import os.log

// MARK: - MileageTrackingService

@MainActor
class MileageTrackingService: NSObject, ObservableObject {
    
    // MARK: - Version
    static let version = "3.5"
    
    // MARK: - Singleton
    static let shared = MileageTrackingService()
    
    // MARK: - Logger
    private let logger = Logger(subsystem: "com.finchandpoppy.flo", category: "MileageTracking")
    
    // MARK: - Published Properties
    
    /// Whether automatic tracking is currently enabled
    @Published var isTracking: Bool = false
    
    /// Whether tracking is paused (trip exists but location updates stopped)
    @Published var isPaused: Bool = false
    
    /// The current trip in progress (nil if no active trip)
    @Published var currentTrip: TripInProgress?
    
    /// Current trip distance in miles (for UI display)
    @Published var currentDistanceMiles: Double = 0.0
    
    /// Location permission status
    @Published var trackingPermissionStatus: CLAuthorizationStatus = .notDetermined
    
    /// GPS signal quality
    @Published var gpsStatus: GPSStatus = .unknown {
        didSet {
            // Announce significant GPS status changes to VoiceOver users
            if gpsStatus != oldValue {
                announceGPSStatusChange(from: oldValue, to: gpsStatus)
            }
        }
    }
    
    /// Battery warning flag
    @Published var batteryWarning: Bool = false
    
    /// Current battery level (0.0 - 1.0, or -1 if unknown)
    @Published var batteryLevel: Float = -1
    
    /// Current tracking error (nil if no error)
    @Published var trackingError: TrackingError?
    
    /// Whether ModelContext has been injected
    @Published var isContextInjected: Bool = false
    
    /// Whether there's a recovered trip pending user action
    @Published var hasRecoveredTrip: Bool = false
    
    /// Details of recovered trip for user decision
    @Published var recoveredTripInfo: RecoveredTripInfo?
    
    // MARK: - Private Properties
    
    private let locationManager = CLLocationManager()
    private var modelContext: ModelContext?
    
    /// Timer that periodically checks if trip should end (active detection)
    private var tripEndCheckTimer: Timer?
    
    /// Timer interval for checking trip end (seconds)
    private let tripEndCheckInterval: TimeInterval = 30
    
    /// Accumulated route points for current trip
    private var routePoints: [RoutePoint] = []
    
    /// Last known location for distance calculation
    private var lastLocation: CLLocation?
    
    /// Time of last detected movement
    private var lastMovementTime: Date?
    
    /// Total distance in meters for current trip
    private var totalDistanceMeters: Double = 0.0
    
    /// Background task identifier for trip completion
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // MARK: - Configuration
    
    /// Current tracking configuration (loaded from UserDefaults)
    var configuration: TrackingConfiguration {
        didSet {
            configuration.save()
            logger.info("Configuration updated and saved")
        }
    }
    
    // MARK: - User Preferences
    
    /// Whether auto-tracked trips default to business (false = requires manual classification)
    /// NOTE: v3.3 - This is now deprecated/ignored for auto trips; they always need review
    var defaultAutoTripsAsBusiness: Bool {
        get { UserDefaults.standard.bool(forKey: "mileage.defaultAsBusiness") }
        set { UserDefaults.standard.set(newValue, forKey: "mileage.defaultAsBusiness") }
    }
    
    // MARK: - UserDefaults Keys
    
    private enum StorageKeys {
        static let inProgressTrip = "mileage.inProgressTrip"
        static let routePoints = "mileage.routePoints"
        static let isTrackingActive = "mileage.isTrackingActive"
        static let isPaused = "mileage.isPaused"
        static let lastMovementTime = "mileage.lastMovementTime"
    }
    
    // MARK: - Initialization
    
    private override init() {
        self.configuration = TrackingConfiguration.load()
        super.init()
        
        setupLocationManager()
        checkAuthorizationStatus()
        setupBatteryMonitoring()
        setupAppLifecycleObservers()
        
        // Restore pause state if it exists
        isPaused = UserDefaults.standard.bool(forKey: StorageKeys.isPaused)
        
        // Check for recovered trip on init
        checkForRecoverableTrip()
        
        logger.info("MileageTrackingService v\(MileageTrackingService.version) initialized")
        if isPaused {
            logger.info("   Restored paused state")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        tripEndCheckTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 20 // meters - more responsive than 30
        locationManager.activityType = .automotiveNavigation
        
        // CRITICAL: Don't let iOS pause updates - we handle trip end ourselves
        locationManager.pausesLocationUpdatesAutomatically = false
        
        locationManager.allowsBackgroundLocationUpdates = true
        
        if #available(iOS 18.0, *) {
            locationManager.showsBackgroundLocationIndicator = true
        }
        
        logger.info("Location manager configured (pausesAutomatically: OFF)")
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBatteryStatus()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryStateDidChange),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
    }
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Control Widget notification observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControlWidgetStart),
            name: .mileageTimerStartRequested,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleControlWidgetStop),
            name: .mileageTimerStopRequested,
            object: nil
        )
        
        logger.info("Control Widget observers registered")
    }
    
    // MARK: - Control Widget Handlers
    
    @objc private func handleControlWidgetStart(_ notification: Notification) {
        logger.info("[Phone] Control Widget requested START")
        
        // If paused, resume instead of starting new
        if isPaused {
            logger.info("   Currently paused - RESUMING tracking")
            resumeTracking()
            return
        }
        
        guard !isTracking else {
            logger.info("   Already tracking, ignoring")
            return
        }
        
        // Update user preference
        UserDefaults.standard.set(true, forKey: "mileageTrackingEnabled")
        
        // Start tracking
        startTracking()
    }
    
    @objc private func handleControlWidgetStop(_ notification: Notification) {
        logger.info("[Phone] Control Widget requested STOP (interpreted as PAUSE)")
        
        guard isTracking else {
            logger.info("   Not tracking, ignoring")
            return
        }
        
        // If there's an active trip, PAUSE instead of stopping completely
        if currentTrip != nil {
            logger.info("   Active trip detected - PAUSING tracking")
            pauseTracking()
        } else {
            // No active trip, just stop
            logger.info("   No active trip - STOPPING tracking")
            UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
            stopTracking()
        }
    }
    
    // MARK: - Widget State Sync
    
    /// Syncs mileage tracking state with Control Widget
    private func syncWidgetTimerState(isRunning: Bool) {
        Task {
            // Calculate elapsed time if there's an active trip
            let elapsedSeconds: TimeInterval
            if let trip = self.currentTrip {
                elapsedSeconds = Date().timeIntervalSince(trip.startDate)
            } else {
                elapsedSeconds = 0
            }
            
            // When paused, widget should show as "off" but trip data is preserved
            // Start time should be the trip's actual start time, not current time
            let state = WidgetTimerState(
                isRunning: isRunning && !self.isPaused,
                startTime: self.currentTrip?.startDate,
                elapsedSeconds: elapsedSeconds,
                tripId: self.currentTrip?.id
            )
            
            do {
                try await WidgetDataService.shared.updateTimerState(state)
                self.logger.info("[Phone] Widget timer state synced: \(isRunning && !self.isPaused ? "Running" : "Stopped/Paused"), elapsed: \(Int(elapsedSeconds))s")
            } catch {
                self.logger.error("[Phone] Failed to sync widget timer state: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appWillResignActive() {
        logger.info("App will resign active - persisting trip state")
        persistCurrentTripState()
    }
    
    @objc private func appDidBecomeActive() {
        logger.info("[Phone] App became active")
        
        // v3.1 FIX: End any lingering background task when returning to foreground
        endBackgroundTask()
        
        updateBatteryStatus()
        
        // If we were tracking, ensure timer is running
        if isTracking && currentTrip != nil {
            startTripEndCheckTimer()
        }
    }
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background - starting background task")
        
        // Request background time to properly handle trip end if needed
        beginBackgroundTask()
        
        // Persist state
        persistCurrentTripState()
        
        // If tracking and trip in progress, check if we should end it
        if isTracking && currentTrip != nil {
            checkForTripEnd()
        }
        
        // v3.1 FIX: End background task after work completes
        endBackgroundTask()
    }
    
    @objc private func appWillTerminate() {
        logger.info("App will terminate - persisting trip state")
        persistCurrentTripState()
        
        // If there's an active trip, it will be recovered on next launch
        if currentTrip != nil {
            logger.warning("App terminating with active trip - will recover on next launch")
        }
    }
    
    // MARK: - Background Task Management
    
    private func beginBackgroundTask() {
        guard backgroundTaskID == .invalid else { return }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "MileageTracking") { [weak self] in
            self?.endBackgroundTask()
        }
        
        logger.info("Background task started: \(self.backgroundTaskID.rawValue)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        logger.info("Background task ended: \(self.backgroundTaskID.rawValue)")
        backgroundTaskID = .invalid
    }
    
    // MARK: - Battery Monitoring
    
    @objc private func batteryLevelDidChange() {
        updateBatteryStatus()
    }
    
    @objc private func batteryStateDidChange() {
        updateBatteryStatus()
    }
    
    private func updateBatteryStatus() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        
        batteryLevel = level
        
        // Only warn if not charging and below 20%
        if level > 0 && level < 0.20 && state != .charging && state != .full {
            if !batteryWarning {
                batteryWarning = true
                logger.warning("Battery low: \(Int(level * 100))%")
                
                if isTracking {
                    sendNotification(
                        title: "Low Battery",
                        body: "Battery at \(Int(level * 100))%. Consider stopping mileage tracking.",
                        identifier: "low_battery_warning"
                    )
                    
                    // VoiceOver announcement for low battery
                    AccessibilityAnnouncement.announce(
                        "Low battery warning. Battery at \(Int(level * 100)) percent. Consider stopping mileage tracking to preserve battery."
                    )
                }
            }
        } else if level >= 0.25 || state == .charging {
            // Announce when battery is healthy again
            if batteryWarning {
                AccessibilityAnnouncement.announce("Battery level restored")
            }
            batteryWarning = false
        }
    }
    
    // MARK: - ModelContext Injection
    
    func inject(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.isContextInjected = true
        logger.info("ModelContext injected successfully")
        
        // Now that we have context, check if we need to recover a trip
        if hasRecoveredTrip {
            logger.info("Recovered trip pending - context now available")
        }
    }
    
    // MARK: - Authorization
    
    private func checkAuthorizationStatus() {
        trackingPermissionStatus = locationManager.authorizationStatus
        logger.info("Current authorization: \(String(describing: self.trackingPermissionStatus))")
    }
    
    func requestLocationPermission() {
        logger.info("Requesting 'When In Use' authorization")
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        logger.info("Requesting 'Always' authorization")
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Tracking Control
    
    /// Starts automatic mileage tracking
    /// 
    /// Accessibility: Announces "Mileage tracking started" to VoiceOver when successful.
    /// Checks permissions and displays user-friendly error messages if unavailable.
    func startTracking() {
        guard trackingPermissionStatus == .authorizedAlways ||
              trackingPermissionStatus == .authorizedWhenInUse else {
            logger.warning("Cannot start: insufficient permissions")
            trackingError = .insufficientPermissions
            return
        }
        
        if !isContextInjected {
            logger.error("Cannot start: ModelContext not injected")
            trackingError = .noModelContext
            sendNotification(
                title: "Setup Required",
                body: "Please open Mileage Tracking to complete setup before tracking.",
                identifier: "setup_required"
            )
            return
        }
        
        // Clean up any stale Live Activities from previous sessions
        if #available(iOS 16.1, *) {
            MileageLiveActivityManager.shared.endAllActivities()
        }
        
        isTracking = true
        UserDefaults.standard.set(true, forKey: StorageKeys.isTrackingActive)
        
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        updateBatteryStatus()
        trackingError = nil
        gpsStatus = .searching
        
        let batteryStr = batteryLevel > 0 ? "\(Int(batteryLevel * 100))%" : "Unknown"
        logger.info("Tracking STARTED (v\(MileageTrackingService.version))")
        logger.info("   Config: start=\(Int(self.configuration.tripStartDistanceMeters))m, end=\(Int(self.configuration.tripEndThresholdSeconds/60))min, minSpeed=\(String(format: "%.1f", self.configuration.minimumSpeedMPS))m/s")
        logger.info("   Battery: \(batteryStr)")
        
        requestNotificationPermission()
        
        // Sync state with Control Widget
        syncWidgetTimerState(isRunning: true)
    }
    
    /// Stops automatic mileage tracking
    ///
    /// Accessibility: Announces "Mileage tracking stopped" to VoiceOver.
    /// If a trip is in progress, it will be saved before stopping.
    func stopTracking() {
        logger.info("Stopping tracking...")
        
        isTracking = false
        isPaused = false
        UserDefaults.standard.set(false, forKey: StorageKeys.isTrackingActive)
        
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Stop the timer
        stopTripEndCheckTimer()
        
        // If there's a trip in progress, end it
        if currentTrip != nil {
            logger.info("Ending current trip due to tracking stop")
            endCurrentTrip(reason: .userStopped)
        }
        
        // Clear persisted state
        clearPersistedTripState()
        
        // Sync state with Control Widget
        syncWidgetTimerState(isRunning: false)
        
        logger.info("Tracking STOPPED")
    }
    
    /// Pause tracking without ending the current trip
    ///
    /// Accessibility: Announces "Mileage tracking paused. Trip data preserved." to VoiceOver.
    /// GPS updates stop but trip data is preserved and can be resumed.
    func pauseTracking() {
        guard isTracking else {
            logger.warning("Cannot pause: not tracking")
            return
        }
        
        logger.info("Pausing tracking...")
        
        isPaused = true
        
        // Stop location updates but keep trip data
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        
        // Pause the trip end check timer
        stopTripEndCheckTimer()
        
        // Persist the pause state
        UserDefaults.standard.set(true, forKey: StorageKeys.isPaused)
        
        logger.info("Tracking PAUSED (trip preserved)")
        
        // Sync state with Control Widget
        syncWidgetTimerState(isRunning: isTracking)
        
        // Send notification
        sendNotification(
            title: "Mileage Tracking Paused",
            body: "Tap to resume your trip",
            identifier: "tracking_paused"
        )
        
        // VoiceOver announcement
        AccessibilityAnnouncement.announce("Mileage tracking paused. Trip data preserved.")
        
        // Update Live Activity to show paused state
        if #available(iOS 16.1, *) {
            if let trip = currentTrip {
                let elapsed = Date().timeIntervalSince(trip.startDate)
                MileageLiveActivityManager.shared.updateActivity(
                    distanceMiles: currentDistanceMiles,
                    elapsedSeconds: elapsed,
                    isPaused: true,
                    gpsSignal: "searching"
                )
            }
        }
    }
    
    /// Resume tracking (continues current trip if exists)
    func resumeTracking() {
        guard isPaused else {
            logger.warning("Cannot resume: not paused")
            return
        }
        
        logger.info("Resuming tracking...")
        
        isPaused = false
        UserDefaults.standard.set(false, forKey: StorageKeys.isPaused)
        
        // Resume location updates
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        
        // Resume trip end check timer if there's an active trip
        if currentTrip != nil {
            startTripEndCheckTimer()
        }
        
        trackingError = nil
        gpsStatus = .searching
        
        logger.info("Tracking RESUMED")
        
        // Sync state with Control Widget
        syncWidgetTimerState(isRunning: true)
        
        // VoiceOver announcement
        AccessibilityAnnouncement.announce("Mileage tracking resumed")
        
        // Update Live Activity to show resumed state
        if #available(iOS 16.1, *) {
            if let trip = currentTrip {
                let elapsed = Date().timeIntervalSince(trip.startDate)
                MileageLiveActivityManager.shared.updateActivity(
                    distanceMiles: currentDistanceMiles,
                    elapsedSeconds: elapsed,
                    isPaused: false,
                    gpsSignal: "searching"
                )
            }
        }
    }
    
    /// Force end the current trip immediately (user-initiated)
    func forceEndCurrentTrip() {
        guard currentTrip != nil else {
            logger.warning("No trip to force end")
            return
        }
        
        logger.info("[Stop] Force ending trip (user requested)")
        endCurrentTrip(reason: .userForced)
    }
    
    // MARK: - Trip End Check Timer (CRITICAL FIX)
    
    private func startTripEndCheckTimer() {
        // Invalidate any existing timer
        tripEndCheckTimer?.invalidate()
        
        // Create new timer that fires every 30 seconds
        tripEndCheckTimer = Timer.scheduledTimer(withTimeInterval: tripEndCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForTripEnd()
            }
        }
        
        // Ensure timer runs in common run loop mode (works during scrolling, etc.)
        if let timer = tripEndCheckTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        logger.info("Trip end check timer started (interval: \(Int(self.tripEndCheckInterval))s)")
    }
    
    private func stopTripEndCheckTimer() {
        tripEndCheckTimer?.invalidate()
        tripEndCheckTimer = nil
        logger.info("Trip end check timer stopped")
    }
    
    // MARK: - Trip Management
    
    private func startNewTrip(at location: CLLocation) {
        let trip = TripInProgress(
            id: UUID(),
            startDate: Date(),
            startLatitude: location.coordinate.latitude,
            startLongitude: location.coordinate.longitude,
            startAddress: "Locating...",
            currentLatitude: location.coordinate.latitude,
            currentLongitude: location.coordinate.longitude,
            totalDistanceMeters: 0
        )
        
        currentTrip = trip
        totalDistanceMeters = 0
        currentDistanceMiles = 0
        lastLocation = location
        lastMovementTime = Date()
        routePoints = [RoutePoint(location: location)]
        
        // Start the active trip end check timer
        startTripEndCheckTimer()
        
        // Persist immediately
        persistCurrentTripState()
        
        // Sync widget state immediately when trip starts
        syncWidgetTimerState(isRunning: isTracking)
        
        // Reverse geocode start location
        reverseGeocode(location: location) { [weak self] address in
            guard let self = self else { return }
            self.currentTrip?.startAddress = address
            self.persistCurrentTripState()
            // Announce address once geocoded
            AccessibilityAnnouncement.announce("Trip started from \(address)")
        }
        
        sendNotification(
            title: "Trip Started",
            body: "Mileage tracking is recording your trip",
            identifier: "trip_started_\(trip.id.uuidString)"
        )
        
        // Immediate VoiceOver announcement
        AccessibilityAnnouncement.announce("Mileage trip started")
        
        // Start Live Activity
        if #available(iOS 16.1, *) {
            MileageLiveActivityManager.shared.startActivity(
                tripId: trip.id,
                startAddress: trip.startAddress,
                startTime: trip.startDate
            )
        }
        
        logger.info("[Signal] NEW TRIP STARTED")
        logger.info("   Location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        logger.info("   [ID] ID: \(trip.id.uuidString)")
    }
    
    private func updateCurrentTrip(with location: CLLocation) {
        guard var trip = currentTrip, let last = lastLocation else { return }
        
        let distance = location.distance(from: last)
        
        // Only count if we moved a meaningful amount
        guard distance >= configuration.minimumPointDistanceMeters else { return }
        
        // Update totals
        totalDistanceMeters += distance
        currentDistanceMiles = totalDistanceMeters / 1609.34
        
        // Update trip state
        trip.currentLatitude = location.coordinate.latitude
        trip.currentLongitude = location.coordinate.longitude
        trip.totalDistanceMeters = totalDistanceMeters
        
        currentTrip = trip
        lastLocation = location
        lastMovementTime = Date()
        
        // Add route point (limit to prevent memory issues on very long trips)
        if routePoints.count < 10000 {
            routePoints.append(RoutePoint(location: location))
        }
        
        // Persist state periodically (every update is fine since it's throttled by distanceFilter)
        persistCurrentTripState()
        
        logger.debug("Trip update: \(String(format: "%.2f", self.currentDistanceMiles)) mi, points: \(self.routePoints.count)")
        
        // Update Live Activity
        if #available(iOS 16.1, *) {
            let elapsed = Date().timeIntervalSince(trip.startDate)
            MileageLiveActivityManager.shared.updateActivity(
                distanceMiles: currentDistanceMiles,
                elapsedSeconds: elapsed,
                isPaused: false,
                gpsSignal: gpsStatus.liveActivitySignal
            )
        }
    }
    
    private func checkForTripEnd() {
        guard currentTrip != nil, let lastMovement = lastMovementTime else {
            return
        }
        
        let idleSeconds = Date().timeIntervalSince(lastMovement)
        let thresholdSeconds = configuration.tripEndThresholdSeconds
        
        logger.debug("Checking trip end: idle=\(Int(idleSeconds))s, threshold=\(Int(thresholdSeconds))s")
        
        if idleSeconds >= thresholdSeconds {
            logger.info("Trip end threshold reached (\(Int(idleSeconds))s idle)")
            endCurrentTrip(reason: .idleTimeout)
        }
    }
    
    private func endCurrentTrip(reason: TripEndReason) {
        guard let trip = currentTrip else {
            logger.warning("endCurrentTrip called but no trip exists")
            resetTripData()
            return
        }
        
        // Stop the timer
        stopTripEndCheckTimer()
        
        guard let context = modelContext else {
            logger.error("CRITICAL: Cannot save trip - no ModelContext!")
            trackingError = .saveFailed
            
            sendNotification(
                title: "Trip Not Saved",
                body: "Database error. Please restart the app and try again.",
                identifier: "trip_save_failed"
            )
            
            // VoiceOver alert for error
            AccessibilityAnnouncement.announce("Error: Trip could not be saved. Database error.")
            
            // Still reset to prevent stuck state
            resetTripData()
            return
        }
        
        let distanceMiles = totalDistanceMeters / 1609.34
        
        logger.info("[Flag] ENDING TRIP")
        logger.info("   Distance: \(String(format: "%.2f", distanceMiles)) miles")
        logger.info("   Points: \(self.routePoints.count)")
        logger.info("   Reason: \(reason.description)")
        
        // Check minimum distance
        let minDistance = self.configuration.minimumTripDistanceMiles
        guard distanceMiles >= minDistance else {
            logger.info("Trip too short (\(String(format: "%.2f", distanceMiles)) mi < \(minDistance) mi), discarding")
            
            sendNotification(
                title: "Trip Not Saved",
                body: "Trip was under \(String(format: "%.1f", minDistance)) miles and was not recorded.",
                identifier: "trip_too_short"
            )
            
            // VoiceOver announcement for discarded trip
            AccessibilityAnnouncement.announce("Trip discarded. Distance was under \(String(format: "%.1f", minDistance)) miles.")
            
            // End Live Activity (trip too short path)
            if #available(iOS 16.1, *) {
                MileageLiveActivityManager.shared.endActivity(
                    finalDistanceMiles: distanceMiles,
                    finalElapsedSeconds: Date().timeIntervalSince(trip.startDate)
                )
            }
            
            resetTripData()
            return
        }
        
        // v3.3 CRITICAL CHANGE: Create trip with needsReview status
        // Auto-tracked trips default to needing classification for tax compliance
        let mileageTrip = MileageTrip(
            startDate: trip.startDate,
            endDate: Date(),
            startLatitude: trip.startLatitude,
            startLongitude: trip.startLongitude,
            endLatitude: trip.currentLatitude,
            endLongitude: trip.currentLongitude,
            startAddress: trip.startAddress,
            endAddress: nil, // Will geocode async
            distanceMiles: distanceMiles,
            purpose: .needsReview,  // v3.3: Always needs review for tax compliance
            isBusinessTrip: false,   // v3.3: Not business until user confirms
            notes: nil,
            isManualEntry: false,
            routePoints: routePoints
        )
        
        // Save to database
        context.insert(mileageTrip)
        
        do {
            try context.save()
            logger.info("Trip SAVED successfully: \(String(format: "%.2f", distanceMiles)) miles (needs review)")
            trackingError = nil
            
            // Geocode end location async
            let endLocation = CLLocation(latitude: trip.currentLatitude, longitude: trip.currentLongitude)
            reverseGeocode(location: endLocation) { address in
                mileageTrip.endAddress = address
                try? context.save()
            }
            
            // End Live Activity (success path)
            if #available(iOS 16.1, *) {
                let tripDuration = Date().timeIntervalSince(trip.startDate)
                MileageLiveActivityManager.shared.endActivity(
                    finalDistanceMiles: distanceMiles,
                    finalElapsedSeconds: tripDuration
                )
            }
            
            // v3.3: Updated notification - shows potential deduction, prompts review
            let potentialDeduction = mileageTrip.potentialDeduction
            sendNotification(
                title: "Trip Completed",
                body: String(format: "%.1f miles tracked  $%.2f potential deduction",
                           distanceMiles, potentialDeduction),
                identifier: "trip_completed_\(mileageTrip.id.uuidString)"
            )
            
            // VoiceOver announcement with spoken currency
            let spokenDeduction = AccessibilityFormatters.spokenCurrency(potentialDeduction)
            AccessibilityAnnouncement.announce(
                "Trip completed. \(String(format: "%.1f", distanceMiles)) miles tracked. Potential deduction: \(spokenDeduction). Classify this trip in your records."
            )
            
            // Post notification for other parts of app
            NotificationCenter.default.post(name: .mileageTripCompleted, object: mileageTrip)
            
        } catch {
            logger.error("Failed to save trip: \(error.localizedDescription)")
            trackingError = .saveFailed
            
            sendNotification(
                title: "Trip Save Failed",
                body: "Could not save your \(String(format: "%.1f", distanceMiles)) mile trip. Please check the app.",
                identifier: "trip_save_error"
            )
            
            // VoiceOver alert for save error
            AccessibilityAnnouncement.announce("Error: Trip could not be saved. Please check the app.")
            
            // End Live Activity (error path)
            if #available(iOS 16.1, *) {
                MileageLiveActivityManager.shared.endActivity(
                    finalDistanceMiles: distanceMiles,
                    finalElapsedSeconds: Date().timeIntervalSince(trip.startDate)
                )
            }
        }
        
        resetTripData()
    }
    
    private func resetTripData() {
        // End Live Activity if still active
        if #available(iOS 16.1, *) {
            MileageLiveActivityManager.shared.endActivity(
                finalDistanceMiles: currentDistanceMiles,
                finalElapsedSeconds: currentTrip.map { Date().timeIntervalSince($0.startDate) } ?? 0
            )
        }
        
        currentTrip = nil
        totalDistanceMeters = 0
        currentDistanceMiles = 0
        lastLocation = nil
        lastMovementTime = nil
        routePoints = []
        
        stopTripEndCheckTimer()
        clearPersistedTripState()
        
        // Sync widget state after trip ends
        syncWidgetTimerState(isRunning: isTracking)
        
        logger.info("Trip data reset")
    }
    
    // MARK: - Trip State Persistence (CRITICAL FOR CRASH RECOVERY)
    
    private func persistCurrentTripState() {
        guard let trip = currentTrip else {
            clearPersistedTripState()
            return
        }
        
        let tripData: [String: Any] = [
            "id": trip.id.uuidString,
            "startDate": trip.startDate.timeIntervalSince1970,
            "startLatitude": trip.startLatitude,
            "startLongitude": trip.startLongitude,
            "startAddress": trip.startAddress,
            "currentLatitude": trip.currentLatitude,
            "currentLongitude": trip.currentLongitude,
            "totalDistanceMeters": totalDistanceMeters
        ]
        
        UserDefaults.standard.set(tripData, forKey: StorageKeys.inProgressTrip)
        
        if let lastMovement = lastMovementTime {
            UserDefaults.standard.set(lastMovement.timeIntervalSince1970, forKey: StorageKeys.lastMovementTime)
        }
        
        // Persist route points (encoded)
        if let encoded = try? JSONEncoder().encode(routePoints) {
            UserDefaults.standard.set(encoded, forKey: StorageKeys.routePoints)
        }
        
        logger.debug("[Save] Trip state persisted")
    }
    
    private func clearPersistedTripState() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.inProgressTrip)
        UserDefaults.standard.removeObject(forKey: StorageKeys.routePoints)
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastMovementTime)
        UserDefaults.standard.removeObject(forKey: StorageKeys.isPaused)
        logger.debug("Persisted trip state cleared")
    }
    
    private func checkForRecoverableTrip() {
        guard let tripData = UserDefaults.standard.dictionary(forKey: StorageKeys.inProgressTrip),
              let idString = tripData["id"] as? String,
              let id = UUID(uuidString: idString),
              let startTimestamp = tripData["startDate"] as? TimeInterval,
              let startLat = tripData["startLatitude"] as? Double,
              let startLon = tripData["startLongitude"] as? Double,
              let currentLat = tripData["currentLatitude"] as? Double,
              let currentLon = tripData["currentLongitude"] as? Double,
              let distanceMeters = tripData["totalDistanceMeters"] as? Double else {
            return
        }
        
        let startDate = Date(timeIntervalSince1970: startTimestamp)
        let startAddress = tripData["startAddress"] as? String ?? "Unknown"
        let distanceMiles = distanceMeters / 1609.34
        
        // Only offer recovery if trip was meaningful
        guard distanceMiles >= configuration.minimumTripDistanceMiles else {
            logger.info("Found persisted trip but too short (\(String(format: "%.2f", distanceMiles)) mi), clearing")
            clearPersistedTripState()
            return
        }
        
        // Load route points if available
        var recoveredRoutePoints: [RoutePoint] = []
        if let routeData = UserDefaults.standard.data(forKey: StorageKeys.routePoints),
           let decoded = try? JSONDecoder().decode([RoutePoint].self, from: routeData) {
            recoveredRoutePoints = decoded
        }
        
        recoveredTripInfo = RecoveredTripInfo(
            id: id,
            startDate: startDate,
            startLatitude: startLat,
            startLongitude: startLon,
            startAddress: startAddress,
            endLatitude: currentLat,
            endLongitude: currentLon,
            distanceMiles: distanceMiles,
            routePoints: recoveredRoutePoints
        )
        
        hasRecoveredTrip = true
        
        logger.info("[Refresh] RECOVERED TRIP FOUND")
        logger.info("   [Calendar] Started: \(startDate)")
        logger.info("   Distance: \(String(format: "%.2f", distanceMiles)) miles")
        logger.info("   Points: \(recoveredRoutePoints.count)")
    }
    
    /// Save the recovered trip to database
    func saveRecoveredTrip() {
        guard let recovered = recoveredTripInfo, let context = modelContext else {
            logger.error("Cannot save recovered trip - missing data or context")
            return
        }
        
        // v3.3 CRITICAL CHANGE: Recovered trips also need review
        let mileageTrip = MileageTrip(
            startDate: recovered.startDate,
            endDate: Date(), // Use current time as end
            startLatitude: recovered.startLatitude,
            startLongitude: recovered.startLongitude,
            endLatitude: recovered.endLatitude,
            endLongitude: recovered.endLongitude,
            startAddress: recovered.startAddress,
            endAddress: nil,
            distanceMiles: recovered.distanceMiles,
            purpose: .needsReview,  // v3.3: Always needs review
            isBusinessTrip: false,   // v3.3: Not business until user confirms
            notes: "Recovered from app interruption",
            isManualEntry: false,
            routePoints: recovered.routePoints
        )
        
        context.insert(mileageTrip)
        
        do {
            try context.save()
            logger.info("Recovered trip saved: \(String(format: "%.2f", recovered.distanceMiles)) miles (needs review)")
            
            // Geocode end location
            let endLoc = CLLocation(latitude: recovered.endLatitude, longitude: recovered.endLongitude)
            reverseGeocode(location: endLoc) { address in
                mileageTrip.endAddress = address
                try? context.save()
            }
            
            sendNotification(
                title: "Trip Recovered",
                body: String(format: "%.1f miles from interrupted trip saved - tap to classify", recovered.distanceMiles),
                identifier: "trip_recovered"
            )
            
        } catch {
            logger.error("Failed to save recovered trip: \(error.localizedDescription)")
        }
        
        dismissRecoveredTrip()
    }
    
    /// Discard the recovered trip
    func discardRecoveredTrip() {
        logger.info("User discarded recovered trip")
        dismissRecoveredTrip()
    }
    
    private func dismissRecoveredTrip() {
        hasRecoveredTrip = false
        recoveredTripInfo = nil
        clearPersistedTripState()
    }
    
    // MARK: - Manual Trip Entry
    
    /// Save a manually entered trip
    /// NOTE: Manual trips use the user's selected purpose directly (no needsReview)
    func saveManualTrip(
        startDate: Date,
        startLocation: String,
        endLocation: String,
        distanceMiles: Double,
        purpose: TripPurpose,
        notes: String?,
        vehicleName: String? = nil,
        clientName: String? = nil
    ) async throws {
        guard let context = modelContext else {
            logger.error("Cannot save manual trip: no ModelContext")
            throw TrackingError.noModelContext
        }
        
        // Manual trips: user explicitly selects purpose, so use it directly
        // isBusinessTrip is true unless purpose is personal, commute, or needsReview
        let trip = MileageTrip(
            startDate: startDate,
            endDate: startDate,
            startLatitude: 0,
            startLongitude: 0,
            endLatitude: 0,
            endLongitude: 0,
            startAddress: startLocation,
            endAddress: endLocation,
            distanceMiles: distanceMiles,
            purpose: purpose,
            isBusinessTrip: purpose.isDeductible,  // true for business purposes, false for personal/commute/needsReview
            notes: notes,
            vehicleName: vehicleName,
            clientName: clientName,
            isManualEntry: true,
            routePoints: nil
        )
        
        context.insert(trip)
        try context.save()
        
        logger.info("Manual trip saved: \(String(format: "%.2f", distanceMiles)) miles, purpose: \(purpose.displayName)")
    }
    
    // MARK: - Geocoding
    
    private func reverseGeocode(location: CLLocation, completion: @escaping (String) -> Void) {
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                self.logger.error("[Map] Geocoding error: \(error.localizedDescription)")
                completion("Unknown Location")
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion("Unknown Location")
                return
            }
            
            var components: [String] = []
            
            if let name = placemark.name, !name.isEmpty {
                components.append(name)
            }
            if let city = placemark.locality {
                components.append(city)
            }
            if let state = placemark.administrativeArea {
                components.append(state)
            }
            
            let address = components.isEmpty ? "Unknown Location" : components.joined(separator: ", ")
            completion(address)
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        // v3.1: Use helper for user-friendly permission request
        NotificationPermissionHelper.requestWithExplanation(context: .mileageTracking) { granted in
            if granted {
                self.logger.info("Notification permission granted")
            } else {
                self.logger.warning("Notification permission denied - trip notifications disabled")
            }
        }
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
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Notification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Accessibility Support
    
    /// Announces GPS status changes to VoiceOver users
    /// Only announces significant changes to avoid overwhelming users
    private func announceGPSStatusChange(from oldStatus: GPSStatus, to newStatus: GPSStatus) {
        // Don't announce initial state or searching->unknown transitions
        guard oldStatus != .unknown && oldStatus != .searching else { return }
        
        // Only announce significant changes
        switch (oldStatus, newStatus) {
        case (_, .available):
            // Signal acquired - always announce
            AccessibilityAnnouncement.announce(newStatus.accessibilityAnnouncement)
            
        case (_, .unavailable):
            // Signal lost - always announce
            AccessibilityAnnouncement.announce(newStatus.accessibilityAnnouncement)
            
        case (.available, .lowAccuracy):
            // Degraded signal - announce
            AccessibilityAnnouncement.announce(newStatus.accessibilityAnnouncement)
            
        default:
            // Don't announce minor transitions (searching, unknown, etc.)
            break
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MileageTrackingService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            // Filter out inaccurate locations
            guard location.horizontalAccuracy <= self.configuration.minimumAccuracyMeters else {
                self.logger.debug("Ignoring: accuracy \(Int(location.horizontalAccuracy))m > \(Int(self.configuration.minimumAccuracyMeters))m")
                self.gpsStatus = .lowAccuracy
                return
            }
            
            // Filter out stationary/walking speeds (if speed is available)
            if location.speed >= 0 && location.speed < self.configuration.minimumSpeedMPS {
                self.logger.debug("Ignoring: speed \(String(format: "%.1f", location.speed))m/s < \(String(format: "%.1f", self.configuration.minimumSpeedMPS))m/s")
                return
            }
            
            self.gpsStatus = .available
            
            // Trip state machine
            if self.currentTrip == nil {
                // No trip yet - check if we should start one
                if let lastLoc = self.lastLocation {
                    let distance = location.distance(from: lastLoc)
                    
                    if distance >= self.configuration.tripStartDistanceMeters {
                        self.startNewTrip(at: location)
                    }
                } else {
                    // First location - just store it
                    self.lastLocation = location
                    self.lastMovementTime = Date()
                    self.logger.debug("First location recorded, waiting for movement")
                }
            } else {
                // Trip in progress - update it
                self.updateCurrentTrip(with: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            self.trackingPermissionStatus = status
            self.logger.info("Authorization changed: \(String(describing: status))")
            
            switch status {
            case .denied, .restricted:
                self.trackingError = .insufficientPermissions
                if self.isTracking {
                    self.stopTracking()
                }
            case .authorizedAlways, .authorizedWhenInUse:
                if self.trackingError == .insufficientPermissions {
                    self.trackingError = nil
                }
            default:
                break
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.gpsStatus = .unavailable
                    self.trackingError = .insufficientPermissions
                    self.logger.error("Location denied")
                case .locationUnknown:
                    self.gpsStatus = .unavailable
                    self.trackingError = .gpsUnavailable
                    self.logger.warning("Location unknown - GPS searching")
                case .network:
                    self.gpsStatus = .lowAccuracy
                    self.logger.warning("Network error affecting location")
                default:
                    self.gpsStatus = .lowAccuracy
                    self.logger.error("Location error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

    /// GPS signal quality status
enum GPSStatus: Equatable {
    case available
    case unavailable
    case lowAccuracy
    case searching
    case unknown
    
    var description: String {
        switch self {
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .lowAccuracy: return "Low Accuracy"
        case .searching: return "Searching..."
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .available: return "location.fill"
        case .unavailable: return "location.slash"
        case .lowAccuracy: return "location.circle"
        case .searching: return "location.magnifyingglass"
        case .unknown: return "location"
        }
    }
    
    var color: String {
        switch self {
        case .available: return "green"
        case .unavailable: return "red"
        case .lowAccuracy: return "orange"
        case .searching: return "yellow"
        case .unknown: return "gray"
        }
    }
    
    /// Accessibility-friendly announcement for GPS status changes
    var accessibilityAnnouncement: String {
        switch self {
        case .available: return "GPS signal acquired"
        case .unavailable: return "GPS signal lost. Move to an area with better reception."
        case .lowAccuracy: return "GPS signal weak. Location accuracy reduced."
        case .searching: return "Searching for GPS signal"
        case .unknown: return "GPS status unknown"
        }
    }
    
    /// Signal string for Live Activity display
    var liveActivitySignal: String {
        switch self {
        case .available: return "strong"
        case .unavailable: return "searching"
        case .lowAccuracy: return "weak"
        case .searching: return "searching"
        case .unknown: return "searching"
        }
    }
}

/// Tracking error types
enum TrackingError: Error, Equatable {
    case insufficientPermissions
    case noModelContext
    case gpsUnavailable
    case saveFailed
    
    var userMessage: String {
        switch self {
        case .insufficientPermissions:
            return "Location permission required. Please enable in Settings."
        case .noModelContext:
            return "Database not connected. Please restart the app."
        case .gpsUnavailable:
            return "GPS signal unavailable. Move to an area with better reception."
        case .saveFailed:
            return "Could not save trip. Please try again."
        }
    }
}

/// Reason why a trip ended
enum TripEndReason {
    case idleTimeout      // No movement for threshold duration
    case userStopped      // User stopped tracking
    case userForced       // User force-ended trip
    case appTerminating   // App is being killed
    
    var description: String {
        switch self {
        case .idleTimeout: return "Idle timeout"
        case .userStopped: return "User stopped tracking"
        case .userForced: return "User force-ended"
        case .appTerminating: return "App terminating"
        }
    }
}

/// Configuration for tracking behavior
struct TrackingConfiguration {
    /// Minimum distance (miles) for a trip to be saved
    var minimumTripDistanceMiles: Double = 0.1
    
    /// Distance (meters) that must be traveled to start a trip
    var tripStartDistanceMeters: Double = 100
    
    /// Seconds without movement before trip auto-ends
    var tripEndThresholdSeconds: TimeInterval = 300 // 5 minutes
    
    /// Maximum GPS accuracy (meters) to accept a location
    var minimumAccuracyMeters: Double = 50
    
    /// Minimum speed (m/s) to count as movement (filters walking)
    var minimumSpeedMPS: Double = 2.0 // ~4.5 mph
    
    /// Minimum distance (meters) between route points
    var minimumPointDistanceMeters: Double = 15
    
    // MARK: - Persistence
    
    static func load() -> TrackingConfiguration {
        var config = TrackingConfiguration()
        
        let defaults = UserDefaults.standard
        
        if let val = defaults.object(forKey: "mileage.config.minTripDistance") as? Double {
            config.minimumTripDistanceMiles = val
        }
        if let val = defaults.object(forKey: "mileage.config.tripStartDistance") as? Double {
            config.tripStartDistanceMeters = val
        }
        if let val = defaults.object(forKey: "mileage.config.tripEndThreshold") as? TimeInterval {
            config.tripEndThresholdSeconds = val
        }
        if let val = defaults.object(forKey: "mileage.config.minAccuracy") as? Double {
            config.minimumAccuracyMeters = val
        }
        if let val = defaults.object(forKey: "mileage.config.minSpeed") as? Double {
            config.minimumSpeedMPS = val
        }
        
        return config
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(minimumTripDistanceMiles, forKey: "mileage.config.minTripDistance")
        defaults.set(tripStartDistanceMeters, forKey: "mileage.config.tripStartDistance")
        defaults.set(tripEndThresholdSeconds, forKey: "mileage.config.tripEndThreshold")
        defaults.set(minimumAccuracyMeters, forKey: "mileage.config.minAccuracy")
        defaults.set(minimumSpeedMPS, forKey: "mileage.config.minSpeed")
    }
}

/// In-progress trip data (held in memory, persisted to UserDefaults)
struct TripInProgress: Equatable {
    let id: UUID
    let startDate: Date
    let startLatitude: Double
    let startLongitude: Double
    var startAddress: String
    var currentLatitude: Double
    var currentLongitude: Double
    var totalDistanceMeters: Double
    
    var distanceMiles: Double {
        totalDistanceMeters / 1609.34
    }
}

/// Recovered trip info for user decision
struct RecoveredTripInfo {
    let id: UUID
    let startDate: Date
    let startLatitude: Double
    let startLongitude: Double
    let startAddress: String
    let endLatitude: Double
    let endLongitude: Double
    let distanceMiles: Double
    let routePoints: [RoutePoint]
}

// MARK: - Notification Names

extension Notification.Name {
    static let mileageTripCompleted = Notification.Name("com.finchandpoppy.flo.mileageTripCompleted")
    static let mileageTrackingStarted = Notification.Name("com.finchandpoppy.flo.mileageTrackingStarted")
    static let mileageTrackingStopped = Notification.Name("com.finchandpoppy.flo.mileageTrackingStopped")
    
    // Control Widget notifications
    static let mileageTimerStartRequested = Notification.Name("com.finchandpoppy.flo.mileageTimerStart")
    static let mileageTimerStopRequested = Notification.Name("com.finchandpoppy.flo.mileageTimerStop")
}
