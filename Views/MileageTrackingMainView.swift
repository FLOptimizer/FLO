//  MileageTrackingMainView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Simplified Tracking Controls
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.4:
//  ✅ Removed confusing "Auto-Start Tracking" toggle
//  ✅ Renamed Start/Stop button to On/Off
//  ✅ Tracking defaults to ON once permission is granted
//  ✅ Persisted On/Off state - stays off if user manually turns off
//  ✅ Auto-starts tracking on first visit after permission granted
//
//  PREVIOUS (v2.3):
//  - Added fallback setup prompt for users who skipped onboarding
//  - Improved "Limited Mode" banner with clear messaging
//
//  PREVIOUS (v2.2):
//  - Fixed iPad Start button responsiveness

import SwiftUI
import SwiftData
import CoreLocation

struct MileageTrackingMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var trackingService = MileageTrackingService.shared
    @StateObject private var setupLocationManager = MileageSetupLocationManager()
    
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]
    
    // User preferences
    @AppStorage("mileageTrackingEnabled") private var trackingEnabled = true // Default ON
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
    @State private var showingLimitedModeSheet = false
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Computed properties
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
            // MARK: - Limited Mode Banner (Persistent)
            if isLimitedMode && !limitedModeBannerDismissed && mileageSetupCompleted {
                Section {
                    LimitedModeBanner(
                        hasNoPermission: hasNoPermission,
                        onFix: {
                            impactMedium.impactOccurred()
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        },
                        onDismiss: {
                            impactLight.impactOccurred()
                            withAnimation {
                                limitedModeBannerDismissed = true
                            }
                        }
                    )
                }
            }
            
            // MARK: - Compact Limited Mode Indicator (After Banner Dismissed)
            if isLimitedMode && limitedModeBannerDismissed && mileageSetupCompleted {
                Section {
                    CompactLimitedModeIndicator(
                        hasNoPermission: hasNoPermission,
                        onTap: {
                            impactLight.impactOccurred()
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
                            impactMedium.impactOccurred()
                            trackingService.saveRecoveredTrip()
                            notificationFeedback.notificationOccurred(.success)
                        },
                        onDiscard: {
                            impactLight.impactOccurred()
                            trackingService.discardRecoveredTrip()
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
                        impactHeavy.impactOccurred()
                        showingForceEndConfirmation = true
                    }
                )
            }
            .opacity(viewAppeared ? 1 : 0)
            .offset(y: viewAppeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
            
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
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35), value: viewAppeared)
                } else {
                    ForEach(Array(recentTrips.enumerated()), id: \.element.id) { index, trip in
                        TripRowCompact(trip: trip)
                            .opacity(viewAppeared ? 1 : 0)
                            .offset(x: viewAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.35 + Double(index) * 0.05),
                                value: viewAppeared
                            )
                    }
                    
                    Button {
                        impactLight.impactOccurred()
                        showingAllTrips = true
                    } label: {
                        HStack {
                            Text("View All Trips")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(viewAppeared ? 1 : 0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: viewAppeared)
                }
            } header: {
                Text("Recent Trips")
            }
            
            // MARK: - Quick Actions
            Section("Actions") {
                Button {
                    impactMedium.impactOccurred()
                    showingManualEntry = true
                } label: {
                    Label("Add Manual Trip", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppConstants.primaryColor)
                }
                
                Button {
                    impactLight.impactOccurred()
                    showingDiagnostics = true
                } label: {
                    Label("Diagnostics", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundStyle(AppConstants.primaryColor)
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55), value: viewAppeared)
            
            // MARK: - Preferences
            Section("Preferences") {
                Toggle("Trip Notifications", isOn: $tripNotifications)
                    .onChange(of: tripNotifications) { _, _ in
                        selectionFeedback.selectionChanged()
                    }
                
                HStack {
                    Text("Trip End Timeout")
                    Spacer()
                    Text("\(Int(trackingService.configuration.tripEndThresholdSeconds / 60)) min")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Minimum Trip Distance")
                    Spacer()
                    Text("\(String(format: "%.1f", trackingService.configuration.minimumTripDistanceMiles)) mi")
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(viewAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.6), value: viewAppeared)
            
            // MARK: - IRS Rates Info
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("IRS Standard Mileage Rates")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text("2026")
                        Spacer()
                        Text("72.5¢/mile")
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Text("2025")
                        Spacer()
                        Text("70¢/mile")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Business mileage is tax deductible. Keep records for at least 3 years.")
            }
            .opacity(viewAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.65), value: viewAppeared)
        }
        .navigationTitle("Mileage Tracking")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            prepareHaptics()
            
            // Inject ModelContext
            trackingService.inject(modelContext: modelContext)
            
            // Check if setup is needed (fallback for skipped onboarding)
            if needsSetup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingSetupPrompt = true
                }
            }
            
            // Auto-start tracking if enabled and has permission
            // This ensures tracking is ON by default once user grants permission
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
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onChange(of: trackingService.trackingPermissionStatus) { _, newStatus in
            // Reset dismissed banner if permission changes to Always
            if newStatus == .authorizedAlways {
                limitedModeBannerDismissed = false
            }
        }
        .sheet(isPresented: $showingSetupPrompt) {
            NavigationStack {
                MileageSetupPromptView(
                    locationManager: setupLocationManager,
                    showingLimitedModeSheet: $showingLimitedModeSheet,
                    onSetupComplete: {
                        mileageSetupCompleted = true
                        showingSetupPrompt = false
                        // Auto-start tracking after setup
                        if trackingEnabled {
                            trackingService.startTracking()
                        }
                    },
                    onSkipForNow: {
                        showingSetupPrompt = false
                    }
                )
                .navigationTitle("Mileage Setup")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            showingSetupPrompt = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingLimitedModeSheet) {
            LimitedModeExplanationView(
                onOpenSettings: {
                    showingLimitedModeSheet = false
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                onContinue: {
                    showingLimitedModeSheet = false
                    mileageSetupCompleted = true
                    showingSetupPrompt = false
                    // Auto-start tracking after setup (limited mode)
                    if trackingEnabled {
                        trackingService.startTracking()
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
                notificationFeedback.notificationOccurred(.success)
            }
        } message: {
            if let trip = trackingService.currentTrip {
                Text("This will save your current trip of \(String(format: "%.1f", trip.distanceMiles)) miles.")
            } else {
                Text("Are you sure you want to end the current trip?")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Actions
    
    private func toggleTracking() {
        let status = trackingService.trackingPermissionStatus
        
        if status == .notDetermined {
            // Show setup prompt instead
            impactMedium.impactOccurred()
            showingSetupPrompt = true
        } else if status == .denied || status == .restricted {
            // Direct to settings
            impactMedium.impactOccurred()
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        } else {
            // Has permission - toggle tracking
            if trackingService.isTracking {
                impactHeavy.impactOccurred()
                trackingService.stopTracking()
                trackingEnabled = false // Persist OFF state
                notificationFeedback.notificationOccurred(.warning)
            } else {
                impactMedium.impactOccurred()
                trackingService.startTracking()
                trackingEnabled = true // Persist ON state
                notificationFeedback.notificationOccurred(.success)
            }
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            trackingService.inject(modelContext: modelContext)
            
            // Resume tracking if it was enabled and we have permission
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
            }
            
            Button {
                onFix()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Open Phone Settings")
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(hasNoPermission ? Color.red : Color.orange)
                .cornerRadius(8)
            }
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
    }
}

// MARK: - Tracking Button Style (iPad-Compatible)

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
            // Header Row
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(trackingService.isTracking ? AppConstants.primaryColor : .gray)
                    .symbolEffect(.pulse, value: trackingService.isTracking && trackingService.currentTrip != nil)
                
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
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Main Toggle Button - On/Off
                Button(action: onToggle) {
                    Text(trackingService.isTracking ? "On" : "Off")
                }
                .buttonStyle(TrackingButtonStyle(isTracking: trackingService.isTracking))
            }
            
            // Active Trip Display
            if let trip = trackingService.currentTrip {
                VStack(spacing: 12) {
                    // Trip Progress
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, value: true)
                        Text("Trip in Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(trip.startDate, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Stats Row
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
                    
                    // GPS Status
                    HStack {
                        Image(systemName: trackingService.gpsStatus.icon)
                            .foregroundStyle(gpsStatusColor)
                        Text("GPS: \(trackingService.gpsStatus.description)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Force End Button
                        Button {
                            onForceEnd()
                        } label: {
                            Label("End Trip", systemImage: "stop.circle.fill")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
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
            
            // Context Status (debug info when needed)
            if !trackingService.isContextInjected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Database not connected")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Recovery")
                        .font(.headline)
                    Text("A trip was interrupted and can be recovered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Trip Details
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
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onDiscard) {
                    Text("Discard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Button(action: onSave) {
                    Text("Save Trip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppConstants.primaryColor)
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
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
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
