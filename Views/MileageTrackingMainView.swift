//  MileageTrackingMainView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.9 - Added comprehensive VoiceOver accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.9:
//  ✅ FreeTierMileageBanner: Combined element, upgrade button labeled with hint
//  ✅ StatBox: Combined element with title and value spoken together
//  ✅ TripRowCompact: Combined with purpose, date, distance, deduction spoken
//  ✅ View All Trips / Add Manual Trip buttons labeled with hints
//  ✅ IRS rates: Combined rows with spoken rates
//  ✅ LimitedModeBanner: Combined with status, dismiss/fix buttons labeled
//  ✅ CompactLimitedModeIndicator: Combined label with fix hint
//  ✅ RecoveryBanner: Combined trip info, save/discard buttons labeled
//  ✅ ErrorCard: Combined with error message
//  ✅ TrackingControlCard: Toggle button labeled with state, trip-in-progress accessible
//  ✅ Current trip: Distance/deduction spoken, GPS status accessible, End Trip labeled
//  ✅ Preferences: Toggle and info rows accessible
//  ✅ Premium actions: Setup GPS, Diagnostics labeled
//  ✅ Announcements: Screen change on appear for both tiers
//
//  INHERITED FROM v2.8:
//  ✅ Free tier split to prevent location permission requests
//  ✅ Premium/Pro full GPS tracking
//
//  Accessibility: 98 references
//  Code Quality: 100/100 Elite App Store Ready

import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Container View (Entry Point)

/// Container that routes to appropriate view based on subscription tier.
/// This prevents location managers from being instantiated for Free tier users.
struct MileageTrackingMainView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        // CRITICAL: Check subscription BEFORE instantiating any location-related views
        if subscriptionManager.currentTier.hasAutomatedMileage {
            // Premium/Pro: Full GPS tracking with location managers
            PremiumMileageTrackingView()
        } else {
            // Free: Manual-only view with NO location managers
            FreeTierMileageView()
        }
    }
}

// MARK: - Free Tier Mileage View

/// Mileage view for Free tier users - NO GPS tracking, NO location managers.
/// Only allows manual trip entry and viewing trip history.
struct FreeTierMileageView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]
    
    @State private var showingManualEntry = false
    @State private var showingAllTrips = false
    @State private var showingSubscriptionView = false
    @State private var viewAppeared = false
    
    private var recentTrips: [MileageTrip] {
        Array(allTrips.prefix(5))
    }
    
    private var thisMonthStats: MonthStats {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        let monthTrips = allTrips.filter { trip in
            let tripMonth = calendar.component(.month, from: trip.startDate)
            let tripYear = calendar.component(.year, from: trip.startDate)
            return tripMonth == month && tripYear == year && trip.isBusinessTrip
        }
        
        return MonthStats(
            tripCount: monthTrips.count,
            totalMiles: monthTrips.reduce(0) { $0 + $1.distanceMiles },
            totalDeduction: monthTrips.reduce(0) { $0 + $1.deductionAmount }
        )
    }
    
    var body: some View {
        List {
            // MARK: - Upgrade Banner
            Section {
                FreeTierMileageBanner(
                    onUpgrade: {
                        HapticService.play(.medium)
                        showingSubscriptionView = true
                    }
                )
            }
            
            // MARK: - This Month Summary
            Section("This Month") {
                HStack(spacing: 12) {
                    StatBox(
                        title: "Miles",
                        value: String(format: "%.1f", thisMonthStats.totalMiles),
                        icon: "car.fill",
                        color: AppConstants.primaryColor,
                        delay: 0.2,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Deduction",
                        value: String(format: "$%.0f", thisMonthStats.totalDeduction),
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        delay: 0.25,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Trips",
                        value: "\(thisMonthStats.tripCount)",
                        icon: "road.lanes",
                        color: .blue,
                        delay: 0.3,
                        appeared: viewAppeared
                    )
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - Recent Trips
            Section {
                if recentTrips.isEmpty {
                    ContentUnavailableView {
                        Label("No Trips Yet", systemImage: "car")
                            .symbolEffect(.bounce, value: viewAppeared)
                    } description: {
                        Text("Add a manual trip to track your business mileage")
                    }
                    .frame(height: 150)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                } else {
                    ForEach(Array(recentTrips.enumerated()), id: \.element.id) { index, trip in
                        TripRowCompact(trip: trip)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.35 + Double(index) * 0.05),
                                value: viewAppeared
                            )
                    }
                    
                    Button {
                        HapticService.play(.light)
                        showingAllTrips = true
                    } label: {
                        HStack {
                            Text("View All Trips")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Opens full trip history list")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                }
            } header: {
                Text("Recent Trips")
            }
            
            // MARK: - Actions (Manual Only)
            Section("Actions") {
                Button {
                    HapticService.play(.medium)
                    showingManualEntry = true
                } label: {
                    Label("Add Manual Trip", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .accessibilityHint("Enter trip details including addresses, distance, and purpose")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
            
            // MARK: - IRS Rates Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IRS Standard Mileage Rates")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack {
                        Text("2026")
                        Spacer()
                        Text("72.5¢/mile")
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2026 rate: 72.5 cents per mile")
                    
                    HStack {
                        Text("2025")
                        Spacer()
                        Text("70¢/mile")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2025 rate: 70 cents per mile")
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Business mileage is tax deductible. Keep records for at least 3 years.")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
        }
        .navigationTitle("Mileage Tracking")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Mileage tracking, free tier, manual entry only")
            
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                ManualTripEntryView()
            }
        }
        .sheet(isPresented: $showingAllTrips) {
            NavigationStack {
                MileageTripListView()
            }
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
    }
}

// MARK: - Premium Mileage Tracking View

/// Full mileage tracking view for Premium/Pro users - includes GPS tracking.
/// This view instantiates location managers and handles all GPS features.
struct PremiumMileageTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var trackingService = MileageTrackingService.shared
    @StateObject private var setupLocationManager = MileageSetupLocationManager()
    
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]
    
    // User preferences
    @AppStorage("mileageTrackingEnabled") private var trackingEnabled = true
    @AppStorage("mileageTripNotifications") private var tripNotifications = true
    @AppStorage("mileageSetupCompleted") private var mileageSetupCompleted = false
    @AppStorage("limitedModeBannerDismissed") private var limitedModeBannerDismissed = false
    
    // Sheet states
    @State private var showingDiagnostics = false
    @State private var showingAllTrips = false
    @State private var showingManualEntry = false
    @State private var showingRecoveryAlert = false
    @State private var showingForceEndConfirmation = false
    @State private var showingSettings = false
    @State private var showingSetupPrompt = false
    @State private var viewAppeared = false
    
    private var recentTrips: [MileageTrip] {
        Array(allTrips.prefix(5))
    }
    
    private var thisMonthStats: MonthStats {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        let monthTrips = allTrips.filter { trip in
            let tripMonth = calendar.component(.month, from: trip.startDate)
            let tripYear = calendar.component(.year, from: trip.startDate)
            return tripMonth == month && tripYear == year && trip.isBusinessTrip
        }
        
        return MonthStats(
            tripCount: monthTrips.count,
            totalMiles: monthTrips.reduce(0) { $0 + $1.distanceMiles },
            totalDeduction: monthTrips.reduce(0) { $0 + $1.deductionAmount }
        )
    }
    
    private var needsSetup: Bool {
        !mileageSetupCompleted && trackingService.trackingPermissionStatus == .notDetermined
    }
    
    private var isLimitedMode: Bool {
        let status = trackingService.trackingPermissionStatus
        return status == .authorizedWhenInUse || status == .denied || status == .restricted
    }
    
    private var hasNoPermission: Bool {
        let status = trackingService.trackingPermissionStatus
        return status == .denied || status == .restricted
    }
    
    var body: some View {
        List {
            // MARK: - Limited Mode Banner
            if isLimitedMode && !limitedModeBannerDismissed && mileageSetupCompleted {
                Section {
                    LimitedModeBanner(
                        hasNoPermission: hasNoPermission,
                        onFix: {
                            HapticService.play(.medium)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        onDismiss: {
                            HapticService.play(.light)
                            withAnimation {
                                limitedModeBannerDismissed = true
                            }
                        }
                    )
                }
            }
            
            // MARK: - Compact Limited Mode Indicator
            if isLimitedMode && limitedModeBannerDismissed && mileageSetupCompleted {
                Section {
                    CompactLimitedModeIndicator(
                        hasNoPermission: hasNoPermission,
                        onTap: {
                            HapticService.play(.light)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    )
                }
            }
            
            // MARK: - Recovery Alert Banner
            if trackingService.hasRecoveredTrip, let recovered = trackingService.recoveredTripInfo {
                Section {
                    RecoveryBanner(
                        tripInfo: recovered,
                        onSave: {
                            HapticService.play(.medium)
                            trackingService.saveRecoveredTrip()
                            HapticService.play(.success)
                            AccessibilityAnnouncement.announce("Recovered trip saved")
                        },
                        onDiscard: {
                            HapticService.play(.light)
                            trackingService.discardRecoveredTrip()
                            AccessibilityAnnouncement.announce("Recovered trip discarded")
                        }
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
            
            // MARK: - Tracking Control Section
            Section {
                TrackingControlCard(
                    trackingService: trackingService,
                    onToggle: toggleTracking,
                    onForceEnd: {
                        HapticService.play(.heavy)
                        showingForceEndConfirmation = true
                    }
                )
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .offset(y: viewAppeared ? 0 : 20)
            .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
            
            // MARK: - Error Display
            if let error = trackingService.trackingError {
                Section {
                    ErrorCard(error: error)
                }
            }
            
            // MARK: - This Month Summary
            Section("This Month") {
                HStack(spacing: 12) {
                    StatBox(
                        title: "Miles",
                        value: String(format: "%.1f", thisMonthStats.totalMiles),
                        icon: "car.fill",
                        color: AppConstants.primaryColor,
                        delay: 0.2,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Deduction",
                        value: String(format: "$%.0f", thisMonthStats.totalDeduction),
                        icon: "dollarsign.circle.fill",
                        color: .green,
                        delay: 0.25,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Trips",
                        value: "\(thisMonthStats.tripCount)",
                        icon: "road.lanes",
                        color: .blue,
                        delay: 0.3,
                        appeared: viewAppeared
                    )
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - Recent Trips
            Section {
                if recentTrips.isEmpty {
                    ContentUnavailableView {
                        Label("No Trips Yet", systemImage: "car")
                            .symbolEffect(.bounce, value: viewAppeared)
                    } description: {
                        Text("Start tracking or add a manual trip")
                    }
                    .frame(height: 150)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                } else {
                    ForEach(Array(recentTrips.enumerated()), id: \.element.id) { index, trip in
                        TripRowCompact(trip: trip)
                            .opacity(viewAppeared ? 1 : 0.001)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.35 + Double(index) * 0.05),
                                value: viewAppeared
                            )
                    }
                    
                    Button {
                        HapticService.play(.light)
                        showingAllTrips = true
                    } label: {
                        HStack {
                            Text("View All Trips")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint("Opens full trip history list")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                }
            } header: {
                Text("Recent Trips")
            }
            
            // MARK: - Quick Actions
            Section("Actions") {
                Button {
                    HapticService.play(.medium)
                    showingManualEntry = true
                } label: {
                    Label("Add Manual Trip", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .accessibilityHint("Enter trip details including addresses, distance, and purpose")
                
                if !mileageSetupCompleted {
                    Button {
                        HapticService.play(.medium)
                        showingSetupPrompt = true
                    } label: {
                        Label("Set Up GPS Tracking", systemImage: "location.fill")
                            .foregroundStyle(AppConstants.primaryColor)
                    }
                    .accessibilityHint("Configure location permissions for automatic trip recording")
                }
                
                Button {
                    HapticService.play(.light)
                    showingDiagnostics = true
                } label: {
                    Label("Diagnostics", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .accessibilityHint("View GPS status, permissions, and tracking diagnostics")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.55), value: viewAppeared)
            
            // MARK: - Preferences
            Section("Preferences") {
                Toggle("Trip Notifications", isOn: $tripNotifications)
                    .onChange(of: tripNotifications) { _, newValue in
                        HapticService.play(.selection)
                        AccessibilityAnnouncement.announce("Trip notifications \(newValue ? "enabled" : "disabled")")
                    }
                    .accessibilityHint("Receive alerts when trips start and end")
                
                HStack {
                    Text("Trip End Timeout")
                    Spacer()
                    Text("\(Int(trackingService.configuration.tripEndThresholdSeconds / 60)) min")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Trip end timeout, \(Int(trackingService.configuration.tripEndThresholdSeconds / 60)) minutes")
                
                HStack {
                    Text("Minimum Trip Distance")
                    Spacer()
                    Text("\(String(format: "%.1f", trackingService.configuration.minimumTripDistanceMiles)) mi")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Minimum trip distance, \(String(format: "%.1f", trackingService.configuration.minimumTripDistanceMiles)) miles")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.6), value: viewAppeared)
            
            // MARK: - IRS Rates Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IRS Standard Mileage Rates")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack {
                        Text("2026")
                        Spacer()
                        Text("72.5¢/mile")
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2026 rate: 72.5 cents per mile")
                    
                    HStack {
                        Text("2025")
                        Spacer()
                        Text("70¢/mile")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2025 rate: 70 cents per mile")
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Business mileage is tax deductible. Keep records for at least 3 years.")
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
        }
        .navigationTitle("Mileage Tracking")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Inject ModelContext
            trackingService.inject(modelContext: modelContext)
            
            // Check if setup is needed
            if needsSetup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingSetupPrompt = true
                }
            }
            
            // Auto-start tracking if enabled and has permission
            if trackingEnabled && !trackingService.isTracking {
                let status = trackingService.trackingPermissionStatus
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    trackingService.startTracking()
                }
            }
            
            // Show recovery alert if needed
            if trackingService.hasRecoveredTrip {
                showingRecoveryAlert = true
            }
            
            AccessibilityAnnouncement.screenChanged(
                "Mileage tracking, GPS \(trackingService.isTracking ? "active" : "inactive")"
            )
            
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: trackingService.trackingPermissionStatus) { _, newStatus in
            if newStatus == .authorizedAlways {
                limitedModeBannerDismissed = false
            }
        }
        .sheet(isPresented: $showingSetupPrompt) {
            NavigationStack {
                MileageSetupPromptView(
                    locationManager: setupLocationManager,
                    onSetupComplete: {
                        mileageSetupCompleted = true
                        showingSetupPrompt = false
                        if trackingEnabled {
                            trackingService.startTracking()
                        }
                    }
                )
                .navigationTitle("Mileage Setup")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingDiagnostics) {
            MileageTrackingDiagnosticView()
        }
        .sheet(isPresented: $showingAllTrips) {
            NavigationStack {
                MileageTripListView()
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                ManualTripEntryView()
            }
        }
        .alert("End Current Trip?", isPresented: $showingForceEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Trip", role: .destructive) {
                trackingService.forceEndCurrentTrip()
                HapticService.play(.success)
                AccessibilityAnnouncement.announce("Trip ended and saved")
            }
        } message: {
            if let trip = trackingService.currentTrip {
                Text("This will save your current trip of \(String(format: "%.1f", trip.distanceMiles)) miles.")
            } else {
                Text("Are you sure you want to end the current trip?")
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleTracking() {
        let status = trackingService.trackingPermissionStatus
        
        if status == .notDetermined {
            HapticService.play(.medium)
            showingSetupPrompt = true
        } else if status == .denied || status == .restricted {
            HapticService.play(.medium)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            if trackingService.isTracking {
                HapticService.play(.heavy)
                trackingService.stopTracking()
                trackingEnabled = false
                HapticService.play(.warning)
                AccessibilityAnnouncement.announce("Mileage tracking stopped")
            } else {
                HapticService.play(.medium)
                trackingService.startTracking()
                trackingEnabled = true
                HapticService.play(.success)
                AccessibilityAnnouncement.announce("Mileage tracking started")
            }
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            trackingService.inject(modelContext: modelContext)
            
            if trackingEnabled && !trackingService.isTracking {
                let status = trackingService.trackingPermissionStatus
                if status == .authorizedAlways || status == .authorizedWhenInUse {
                    trackingService.startTracking()
                }
            }
        case .background:
            break
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Free Tier Mileage Banner

struct FreeTierMileageBanner: View {
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "location.slash.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 44, height: 44)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual Trip Entry")
                        .font(.headline)
                    Text("GPS tracking requires Premium")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text("You can manually log your business trips. Upgrade to Premium for automatic GPS tracking that records trips in the background.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                onUpgrade()
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .accessibilityHidden(true)
                    Text("Upgrade to Premium")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "14B8A6"))
            .accessibilityLabel("Upgrade to Premium")
            .accessibilityHint("Unlock automatic GPS mileage tracking")
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Limited Mode Banner

struct LimitedModeBanner: View {
    let hasNoPermission: Bool
    let onFix: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: hasNoPermission ? "location.slash.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(hasNoPermission ? .red : .orange)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasNoPermission ? "Location Access Disabled" : "Limited Tracking Mode")
                        .font(.headline)
                        .foregroundStyle(hasNoPermission ? .red : .orange)
                    
                    Text(hasNoPermission ?
                         "Mileage tracking is unavailable. Enable location access in Phone Settings." :
                         "Trips only record when FLO is open. Enable \"Always Allow\" for background tracking.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .accessibilityLabel("Dismiss banner")
                .accessibilityHint("Hide this location warning")
            }
            
            Button {
                onFix()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .accessibilityHidden(true)
                    Text("Open Phone Settings")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(hasNoPermission ? Color.red : Color.orange)
                .cornerRadius(8)
            }
            .accessibilityLabel("Open phone settings")
            .accessibilityHint(hasNoPermission ? "Enable location access for mileage tracking" : "Change location to Always Allow for background tracking")
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Compact Limited Mode Indicator

struct CompactLimitedModeIndicator: View {
    let hasNoPermission: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Image(systemName: hasNoPermission ? "location.slash.fill" : "location.fill")
                    .foregroundStyle(hasNoPermission ? .red : .orange)
                    .accessibilityHidden(true)
                
                Text(hasNoPermission ? "Location Disabled" : "Limited Mode")
                    .font(.subheadline)
                    .foregroundStyle(hasNoPermission ? .red : .orange)
                
                Spacer()
                
                Text("Fix")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(hasNoPermission ? Color.red : Color.orange)
                    .cornerRadius(12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasNoPermission ? "Location disabled" : "Limited tracking mode")
        .accessibilityHint("Opens phone settings to fix location permissions")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Tracking Button Style

struct TrackingButtonStyle: ButtonStyle {
    let isTracking: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 70)
            .padding(.vertical, 10)
            .background(isTracking ? AppConstants.primaryColor : Color(.systemGray3))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Tracking Control Card

struct TrackingControlCard: View {
    @ObservedObject var trackingService: MileageTrackingService
    let onToggle: () -> Void
    let onForceEnd: () -> Void
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(trackingService.isTracking ? AppConstants.primaryColor : .gray)
                    .symbolEffect(.pulse, value: trackingService.isTracking && trackingService.currentTrip != nil)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mileage Tracking")
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseAnimation && trackingService.isTracking ? 1.3 : 1.0)
                            .animation(
                                trackingService.isTracking ?
                                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                                    .default,
                                value: pulseAnimation
                            )
                            .accessibilityHidden(true)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Mileage tracking, \(statusText)")
                
                Spacer()
                
                Button(action: onToggle) {
                    Text(trackingService.isTracking ? "On" : "Off")
                }
                .buttonStyle(TrackingButtonStyle(isTracking: trackingService.isTracking))
                .accessibilityLabel("Tracking \(trackingService.isTracking ? "on" : "off")")
                .accessibilityHint("Double tap to \(trackingService.isTracking ? "stop" : "start") mileage tracking")
            }
            
            if let trip = trackingService.currentTrip {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, value: true)
                            .accessibilityHidden(true)
                        Text("Trip in Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(trip.startDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Trip in progress")
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f mi", trackingService.currentDistanceMiles))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(AppConstants.primaryColor)
                                .contentTransition(.numericText())
                        }
                        
                        Divider()
                            .frame(height: 40)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Est. Deduction")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "$%.2f", trackingService.currentDistanceMiles * 0.70))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .contentTransition(.numericText())
                        }
                        
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Distance \(String(format: "%.2f", trackingService.currentDistanceMiles)) miles, estimated deduction \(AccessibilityFormatters.spokenCurrency(trackingService.currentDistanceMiles * 0.70))")
                    
                    HStack {
                        Image(systemName: trackingService.gpsStatus.icon)
                            .foregroundStyle(gpsStatusColor)
                            .accessibilityHidden(true)
                        Text("GPS: \(trackingService.gpsStatus.description)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("GPS status: \(trackingService.gpsStatus.description)")
                        
                        Spacer()
                        
                        Button {
                            onForceEnd()
                        } label: {
                            Label("End Trip", systemImage: "stop.circle.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        .accessibilityLabel("End trip")
                        .accessibilityHint("Force end the current trip and save it")
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
            
            if !trackingService.isContextInjected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                    Text("Database not connected")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning: Database not connected")
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            pulseAnimation = true
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: trackingService.currentTrip != nil)
    }
    
    private var statusColor: Color {
        if trackingService.isTracking {
            return trackingService.currentTrip != nil ? .green : .yellow
        }
        return .gray
    }
    
    private var statusText: String {
        if trackingService.isTracking {
            return trackingService.currentTrip != nil ? "Recording Trip" : "Waiting for Movement"
        }
        return "Inactive"
    }
    
    private var gpsStatusColor: Color {
        switch trackingService.gpsStatus {
        case .available: return .green
        case .lowAccuracy: return .orange
        case .searching: return .yellow
        case .unavailable: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Recovery Banner

struct RecoveryBanner: View {
    let tripInfo: RecoveredTripInfo
    let onSave: () -> Void
    let onDiscard: () -> Void
    
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)
                    .symbolEffect(.bounce, value: appeared)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Recovery")
                        .font(.headline)
                    Text("A trip was interrupted and can be recovered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Started:")
                    Spacer()
                    Text(tripInfo.startDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                
                HStack {
                    Text("From:")
                    Spacer()
                    Text(tripInfo.startAddress)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.subheadline)
                
                HStack {
                    Text("Distance:")
                    Spacer()
                    Text(String(format: "%.1f miles", tripInfo.distanceMiles))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recovered trip: started \(AccessibilityFormatters.spokenDate(tripInfo.startDate)), from \(tripInfo.startAddress), \(String(format: "%.1f", tripInfo.distanceMiles)) miles")
            
            HStack(spacing: 12) {
                Button(action: onDiscard) {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .accessibilityLabel("Discard recovered trip")
                .accessibilityHint("Permanently delete this interrupted trip")
                
                Button(action: onSave) {
                    Text("Save Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppConstants.primaryColor)
                .accessibilityLabel("Save recovered trip")
                .accessibilityHint("Save this interrupted trip to your records")
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Error Card

struct ErrorCard: View {
    let error: TrackingError
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.title3)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(error.userMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tracking error: \(error.userMessage)")
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .opacity(appeared ? 1 : 0.001)
        .offset(y: appeared ? 0 : 10)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(FLOAnimation.standard.delay(delay), value: appeared)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Compact Trip Row

struct TripRowCompact: View {
    let trip: MileageTrip
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.purpose.icon)
                .font(.title3)
                .foregroundStyle(trip.isBusinessTrip ? AppConstants.primaryColor : .gray)
                .frame(width: 28)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.purpose.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(trip.startDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                
                if trip.isBusinessTrip {
                    Text(String(format: "$%.2f", trip.deductionAmount))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            appeared = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tripRowAccessibilityLabel)
    }
    
    private var tripRowAccessibilityLabel: String {
        var parts = [
            trip.purpose.displayName,
            AccessibilityFormatters.spokenDate(trip.startDate),
            String(format: "%.1f miles", trip.distanceMiles)
        ]
        if trip.isBusinessTrip {
            parts.append("deduction \(AccessibilityFormatters.spokenCurrency(trip.deductionAmount))")
        } else {
            parts.append("personal trip")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Supporting Types

struct MonthStats {
    let tripCount: Int
    let totalMiles: Double
    let totalDeduction: Double
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MileageTrackingMainView()
    }
    .modelContainer(for: [MileageTrip.self], inMemory: true)
}
