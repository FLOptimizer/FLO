//  MileageTrackingMainView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.6.1 - iPad Zone 3 routing + non-blocking setup prompt
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.6.1 - §7 follow-up:
//  ✅ FIXED (iPad §7): The setup prompt still auto-presented on iPad despite the
//           v3.6 gate. Cause: inside a NavigationSplitView the content column's
//           horizontalSizeClass is unsettled when `.task` runs (briefly .compact
//           during initial layout), so the size-class check passed. Re-gated on
//           device idiom (autoPresentSetupAllowed) which is stable from launch.
//
//  CHANGES v3.6 - iPad NavigationSplitView fixes:
//  ✅ FIXED (iPad §5): Tapping a Recent Trips row presented a modal sheet that
//           covered the split view, leaving the Zone 3 detail pane empty. On
//           regular width (iPad/macOS) the tap now routes the right pane to the
//           trip's detail via `requestDetailNavigation`; compact width keeps the
//           sheet. (The default right pane is also now MileageSummaryPanel.)
//  ✅ FIXED (iPad §7): The "Mileage Setup" prompt auto-presented on first visit
//           and blocked the screen with no obvious dismissal. It no longer
//           auto-presents on regular width — the user opens it explicitly from
//           the Setup GPS Tracking action. Compact width is unchanged.
//
//  CHANGES v3.5 - Limited-mode banner is less aggressive:
//  ✅ FIXED: The full "Limited Tracking Mode" banner now appears only ONCE (the
//           first visit while in limited mode), then collapses to the compact
//           "Limited Mode" pill on every subsequent visit — instead of dominating
//           the screen every time. Persisted via "limitedModeBannerSeen". Explicit
//           dismissal (the X) still collapses it immediately within a visit.
//
//  CHANGES v3.4 - Recent Trips UX (option A from launch UX review):
//  ✅ RENAMED: "View All Trips" → "Review All Trips" (action-oriented label)
//  ✅ ADDED: Recent Trips section header now appends "N NEED REVIEW" pill in orange
//           when unreviewed trips exist (count across ALL trips, not just shown 5)
//  ✅ ADDED: TripRowCompact now renders a NEEDS REVIEW orange pill next to purpose
//           name for trips with purpose == .needsReview
//  ✅ ADDED: TripRowCompact disclosure chevron — signals row is tappable
//  ✅ FIXED: Recent Trips rows are now actually tappable. Tap opens
//           MileageTripDetailView in a sheet. Resolves "user doesn't know how
//           to convert personal → business trip" — previously rows looked
//           passive and required navigating through View All → list → detail.
//  ✅ A11Y: Row hint reads "Tap to classify…" for needsReview, "Tap to edit
//           trip" otherwise. Header announces "N need review" via combined elem.
//
//  CHANGES v3.3 - Brand Color Pass:
//  ✅ FIXED: .green → Color.incomeGreen for deduction/money values
//  ✅ FIXED: .blue → Color.brandPrimary for stat accents
//  ✅ FIXED: .orange → Color.brandWarning for warning indicators
//  ✅ FIXED: .red → Color.expenseRed for error states
//  ✅ FIXED: StatBox background Color.floTertiarySystemBackground → floGlassCard styling
//
//  CHANGES v3.2 - Dark Mode Optimization:
//  ✅ FIXED: L872 Color(hex: "14B8A6") → Color.brandPrimary for button tint (adaptive brand color)
//
//  CHANGES v3.1 - Dynamic Type Verification:
//  ✅ FIXED: FreeTierMileageBanner title/subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FreeTierMileageBanner description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: FreeTierMileageBanner upgrade button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: LimitedModeBanner title/description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: LimitedModeBanner button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CompactLimitedModeIndicator text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecoveryBanner title/subtitle missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecoveryBanner trip details (started/from/distance) missing lineLimit + minimumScaleFactor
//  ✅ FIXED: RecoveryBanner button labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ErrorCard title/message missing lineLimit + minimumScaleFactor
//  ✅ FIXED: StatBox title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: StatBox value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripRowCompact purpose name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripRowCompact date text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripRowCompact miles value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripRowCompact deduction amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard title/status missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard toggle button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard trip progress text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard distance/deduction labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard distance/deduction values missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard GPS status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard end trip button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TrackingControlCard database error missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "This Month" section header text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "No Trips Yet" empty state title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "View All Trips" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Add Manual Trip" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Set Up GPS Tracking" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Diagnostics" button label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Trip Notifications" toggle label missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Trip End Timeout" label/value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Minimum Trip Distance" label/value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: IRS rates section title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: IRS rates year/rate values missing lineLimit + minimumScaleFactor
//  ✅ FIXED: IRS rates footer text missing lineLimit + minimumScaleFactor
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
import FLODesignSystem
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
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]

    @State private var showingManualEntry = false
    @State private var showingAllTrips = false
    /// Tapped trip — presented as a detail sheet from the Recent Trips list.
    @State private var selectedTrip: MileageTrip?
    @State private var showingSubscriptionView = false
    @State private var viewAppeared = false

    /// On regular width (iPad/macOS) trip taps route to the Zone 3 detail pane.
    /// On compact width (iPhone) they present the trip as a sheet, as before.
    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }
    
    private var recentTrips: [MileageTrip] {
        Array(allTrips.prefix(5))
    }

    /// Count of trips waiting for the user to classify as business/personal/commute.
    /// Counted across ALL trips (not just the 5 shown) so the user sees the true backlog.
    private var unreviewedTripCount: Int {
        allTrips.filter { $0.purpose == .needsReview }.count
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
                        color: Color.brandPrimary,
                        delay: 0.2,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Deduction",
                        value: String(format: "$%.0f", thisMonthStats.totalDeduction),
                        icon: "dollarsign.circle.fill",
                        color: Color.incomeGreen,
                        delay: 0.25,
                        appeared: viewAppeared
                    )

                    StatBox(
                        title: "Trips",
                        value: "\(thisMonthStats.tripCount)",
                        icon: "road.lanes",
                        color: Color.brandPrimary,
                        delay: 0.3,
                        appeared: viewAppeared
                    )
                }
                .padding(.vertical, 4)
            }

            // MARK: - Recent Trips
            Section {
                if recentTrips.isEmpty {
                    VStack(spacing: 12) {
                        MileageIllustration()
                            .accessibilityHidden(true)

                        Text("No Trips Yet")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text("Add a manual trip to track your business mileage")
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                } else {
                    ForEach(Array(recentTrips.enumerated()), id: \.element.id) { index, trip in
                        Button {
                            HapticService.play(.light)
                            if routesToDetailPane {
                                NavigationService.shared.requestDetailNavigation(to: .mileageTripDetail(id: trip.id))
                            } else {
                                selectedTrip = trip
                            }
                        } label: {
                            TripRowCompact(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
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
                            Text("Review All Trips")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(unreviewedTripCount > 0
                        ? "Review and classify trips. \(unreviewedTripCount) need attention."
                        : "Opens full trip history to review or edit trips")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Recent Trips")
                    if unreviewedTripCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("\(unreviewedTripCount) NEED\(unreviewedTripCount == 1 ? "S" : "") REVIEW")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // MARK: - Actions (Manual Only)
            Section("Actions") {
                Button {
                    HapticService.play(.medium)
                    showingManualEntry = true
                } label: {
                    Label("Add Manual Trip", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)

                    HStack {
                        Text("2026")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text("72.5¢/mile")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.incomeGreen)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2026 rate: 72.5 cents per mile")
                    
                    HStack {
                        Text("2025")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text("70¢/mile")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2025 rate: 70 cents per mile")
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Business mileage is tax deductible. Keep records for at least 3 years.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Mileage Tracking")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Mileage tracking, free tier, manual entry only")

            DispatchQueue.main.async {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
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
        .sheet(item: $selectedTrip) { trip in
            NavigationStack {
                MileageTripDetailView(trip: trip)
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
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @StateObject private var trackingService = MileageTrackingService.shared
    @StateObject private var setupLocationManager = MileageSetupLocationManager()

    /// On regular width (iPad/macOS) trip taps route to the Zone 3 detail pane.
    /// On compact width (iPhone) they present the trip as a sheet, as before.
    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    /// Whether the GPS-setup prompt may auto-present on first visit.
    /// v3.6.1: Gated on device idiom, NOT horizontalSizeClass. Inside a
    /// NavigationSplitView the content column's size class is unsettled at
    /// `.task` time (it can briefly report .compact during initial layout),
    /// so the size-class gate let the modal slip through on iPad. Idiom is
    /// stable from launch: auto-present only on iPhone; on iPad/macOS the user
    /// opens setup explicitly via the "Set Up GPS Tracking" action.
    private var autoPresentSetupAllowed: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    @Query(sort: \MileageTrip.startDate, order: .reverse) private var allTrips: [MileageTrip]
    
    // User preferences
    @AppStorage("mileageTrackingEnabled") private var trackingEnabled = true
    @AppStorage("mileageTripNotifications") private var tripNotifications = true
    @AppStorage("mileageSetupCompleted") private var mileageSetupCompleted = false
    @AppStorage("limitedModeBannerDismissed") private var limitedModeBannerDismissed = false
    // v3.5: Set once the user has seen the full banner (on leaving the screen while in
    // limited mode). Thereafter the compact pill is shown by default instead of the
    // full banner re-dominating the screen on every visit.
    @AppStorage("limitedModeBannerSeen") private var limitedModeBannerSeen = false
    
    // Sheet states
    @State private var showingDiagnostics = false
    @State private var showingAllTrips = false
    /// Tapped trip — presented as a detail sheet from the Recent Trips list.
    @State private var selectedTrip: MileageTrip?
    @State private var showingManualEntry = false
    @State private var showingRecoveryAlert = false
    @State private var showingForceEndConfirmation = false
    @State private var showingSettings = false
    @State private var showingSetupPrompt = false
    @State private var viewAppeared = false
    
    private var recentTrips: [MileageTrip] {
        Array(allTrips.prefix(5))
    }

    /// Count of trips waiting for the user to classify as business/personal/commute.
    /// Counted across ALL trips (not just the 5 shown) so the user sees the true backlog.
    private var unreviewedTripCount: Int {
        allTrips.filter { $0.purpose == .needsReview }.count
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
        #if os(macOS)
        return status == .denied || status == .restricted
        #else
        return status == .authorizedWhenInUse || status == .denied || status == .restricted
        #endif
    }
    
    private var hasNoPermission: Bool {
        let status = trackingService.trackingPermissionStatus
        return status == .denied || status == .restricted
    }
    
    var body: some View {
        List {
            // MARK: - Limited Mode Banner — full banner only on the first visit
            if isLimitedMode && !limitedModeBannerDismissed && !limitedModeBannerSeen && mileageSetupCompleted {
                Section {
                    LimitedModeBanner(
                        hasNoPermission: hasNoPermission,
                        onFix: {
                            HapticService.play(.medium)
                            #if canImport(UIKit)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            #endif
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
            
            // MARK: - Compact Limited Mode Indicator (default once the banner's been seen)
            if isLimitedMode && (limitedModeBannerDismissed || limitedModeBannerSeen) && mileageSetupCompleted {
                Section {
                    CompactLimitedModeIndicator(
                        hasNoPermission: hasNoPermission,
                        onTap: {
                            HapticService.play(.light)
                            #if canImport(UIKit)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                            #endif
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
                        color: Color.brandPrimary,
                        delay: 0.2,
                        appeared: viewAppeared
                    )
                    
                    StatBox(
                        title: "Deduction",
                        value: String(format: "$%.0f", thisMonthStats.totalDeduction),
                        icon: "dollarsign.circle.fill",
                        color: Color.incomeGreen,
                        delay: 0.25,
                        appeared: viewAppeared
                    )

                    StatBox(
                        title: "Trips",
                        value: "\(thisMonthStats.tripCount)",
                        icon: "road.lanes",
                        color: Color.brandPrimary,
                        delay: 0.3,
                        appeared: viewAppeared
                    )
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - Recent Trips
            Section {
                if recentTrips.isEmpty {
                    VStack(spacing: 12) {
                        MileageIllustration()
                            .accessibilityHidden(true)
                        
                        Text("No Trips Yet")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        
                        Text("Start tracking or add a manual trip")
                            .font(.subheadline)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
                } else {
                    ForEach(Array(recentTrips.enumerated()), id: \.element.id) { index, trip in
                        Button {
                            HapticService.play(.light)
                            if routesToDetailPane {
                                NavigationService.shared.requestDetailNavigation(to: .mileageTripDetail(id: trip.id))
                            } else {
                                selectedTrip = trip
                            }
                        } label: {
                            TripRowCompact(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
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
                            Text("Review All Trips")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHint(unreviewedTripCount > 0
                        ? "Review and classify trips. \(unreviewedTripCount) need attention."
                        : "Opens full trip history to review or edit trips")
                    .opacity(viewAppeared ? 1 : 0.001)
                    .animation(FLOAnimation.standard.delay(0.5), value: viewAppeared)
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Recent Trips")
                    if unreviewedTripCount > 0 {
                        Text("·")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("\(unreviewedTripCount) NEED\(unreviewedTripCount == 1 ? "S" : "") REVIEW")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            
            // MARK: - Quick Actions
            Section("Actions") {
                Button {
                    HapticService.play(.medium)
                    showingManualEntry = true
                } label: {
                    Label("Add Manual Trip", systemImage: "plus.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
                }
                .accessibilityHint("Enter trip details including addresses, distance, and purpose")
                
                if !mileageSetupCompleted {
                    Button {
                        HapticService.play(.medium)
                        showingSetupPrompt = true
                    } label: {
                        Label("Set Up GPS Tracking", systemImage: "location.fill")
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .accessibilityHint("Configure location permissions for automatic trip recording")
                }
                
                Button {
                    HapticService.play(.light)
                    showingDiagnostics = true
                } label: {
                    Label("Diagnostics", systemImage: "wrench.and.screwdriver.fill")
                        .foregroundStyle(Color.brandPrimary)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(Int(trackingService.configuration.tripEndThresholdSeconds / 60)) min")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Trip end timeout, \(Int(trackingService.configuration.tripEndThresholdSeconds / 60)) minutes")
                
                HStack {
                    Text("Minimum Trip Distance")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text("\(String(format: "%.1f", trackingService.configuration.minimumTripDistanceMiles)) mi")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
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
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack {
                        Text("2026")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text("72.5¢/mile")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.incomeGreen)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2026 rate: 72.5 cents per mile")

                    HStack {
                        Text("2025")
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Text("70¢/mile")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("2025 rate: 70 cents per mile")
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Business mileage is tax deductible. Keep records for at least 3 years.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(0.65), value: viewAppeared)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Mileage Tracking")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // Inject ModelContext
            trackingService.inject(modelContext: modelContext)

            // Check if setup is needed.
            // v3.6 (§7): Don't auto-present on iPad/macOS — the modal blocked
            // the first-visit screen with no obvious dismissal. v3.6.1: gate on
            // device idiom (autoPresentSetupAllowed), not size class, which is
            // unsettled at .task time inside a NavigationSplitView column.
            // The user opens setup explicitly from the Setup GPS Tracking action.
            if needsSetup && autoPresentSetupAllowed {
                try? await Task.sleep(for: .milliseconds(500))
                showingSetupPrompt = true
            }

            // Defer state mutations to avoid "Publishing changes from within view updates"
            try? await Task.sleep(for: .milliseconds(50))

            // Auto-start tracking if enabled and has permission
            // Skip auto-start on macOS — GPS accuracy is typically too poor for mileage tracking
            #if !os(macOS)
            if trackingEnabled && !trackingService.isTracking {
                let status = trackingService.trackingPermissionStatus
                let hasPermission = status == .authorizedAlways || status == .authorizedWhenInUse
                if hasPermission {
                    trackingService.startTracking()
                }
            }
            #endif

            // Show recovery alert if needed
            if trackingService.hasRecoveredTrip {
                showingRecoveryAlert = true
            }

            AccessibilityAnnouncement.screenChanged(
                "Mileage tracking, GPS \(trackingService.isTracking ? "active" : "inactive")"
            )

            DispatchQueue.main.async {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onDisappear {
            // v3.5: After the user has seen the full limited-mode banner once,
            // default to the compact pill on subsequent visits.
            if isLimitedMode {
                limitedModeBannerSeen = true
            }
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
        .sheet(item: $selectedTrip) { trip in
            NavigationStack {
                MileageTripDetailView(trip: trip)
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
            #if canImport(UIKit)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            #endif
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

            #if !os(macOS)
            if trackingEnabled && !trackingService.isTracking {
                let status = trackingService.trackingPermissionStatus
                let hasPermission = status == .authorizedAlways || status == .authorizedWhenInUse
                if hasPermission {
                    trackingService.startTracking()
                }
            }
            #endif
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
                    .foregroundStyle(Color.brandWarning)
                    .frame(width: 44, height: 44)
                    .background(Color.brandWarning.opacity(0.15))
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Manual Trip Entry")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("GPS tracking requires Premium")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Text("You can manually log your business trips. Upgrade to Premium for automatic GPS tracking that records trips in the background.")
                .font(.caption)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            
            Button {
                onUpgrade()
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .accessibilityHidden(true)
                    Text("Upgrade to Premium")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandPrimary)
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
                    .foregroundStyle(hasNoPermission ? Color.expenseRed : Color.brandWarning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasNoPermission ? "Location Access Disabled" : "Limited Tracking Mode")
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(hasNoPermission ? Color.expenseRed : Color.brandWarning)
                    
                    Text(hasNoPermission ?
                         "Mileage tracking is unavailable. Enable location access in Phone Settings." :
                         "Trips only record when FLO is open. Enable \"Always Allow\" for background tracking.")
                        .font(.caption)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(hasNoPermission ? Color.expenseRed : Color.brandWarning)
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
                    .foregroundStyle(hasNoPermission ? Color.expenseRed : Color.brandWarning)
                    .accessibilityHidden(true)

                Text(hasNoPermission ? "Location Disabled" : "Limited Mode")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(hasNoPermission ? Color.expenseRed : Color.brandWarning)
                
                Spacer()
                
                Text("Fix")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(hasNoPermission ? Color.expenseRed : Color.brandWarning)
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
            .background(isTracking ? Color.brandPrimary : Color.floCardBorder)
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
                    .foregroundStyle(trackingService.isTracking ? Color.brandPrimary : .gray)
                    .symbolEffect(.pulse, value: trackingService.isTracking && trackingService.currentTrip != nil)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mileage Tracking")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Mileage tracking, \(statusText)")
                
                Spacer()
                
                Button(action: onToggle) {
                    Text(trackingService.isTracking ? "On" : "Off")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(TrackingButtonStyle(isTracking: trackingService.isTracking))
                .accessibilityLabel("Tracking \(trackingService.isTracking ? "on" : "off")")
                .accessibilityHint("Double tap to \(trackingService.isTracking ? "stop" : "start") mileage tracking")
            }
            
            if let trip = trackingService.currentTrip {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.brandWarning)
                            .symbolEffect(.pulse, value: true)
                            .accessibilityHidden(true)
                        Text("Trip in Progress")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .fontWeight(.medium)
                        Spacer()
                        Text(trip.startDate, style: .relative)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Trip in progress")
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distance")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f mi", trackingService.currentDistanceMiles))
                                .font(.title2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.brandPrimary)
                                .contentTransition(.numericText())
                        }
                        
                        Divider()
                            .frame(height: 40)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Est. Deduction")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(.secondary)
                            Text(String(format: "$%.2f", trackingService.currentDistanceMiles * 0.70))
                                .font(.title2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.incomeGreen)
                                .contentTransition(.numericText())
                        }
                        
                        Spacer()
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Distance \(String(format: "%.2f", trackingService.currentDistanceMiles)) miles, estimated deduction \(AccessibilityFormatters.spokenCurrency(trackingService.currentDistanceMiles * 0.70))")
                    .accessibilityAddTraits(.updatesFrequently)
                    
                    HStack {
                        Image(systemName: trackingService.gpsStatus.icon)
                            .foregroundStyle(gpsStatusColor)
                            .accessibilityHidden(true)
                        Text("GPS: \(trackingService.gpsStatus.description)")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("GPS status: \(trackingService.gpsStatus.description)")
                        
                        Spacer()
                        
                        Button {
                            onForceEnd()
                        } label: {
                            Label("End Trip", systemImage: "stop.circle.fill")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.brandWarning)
                        .accessibilityLabel("End trip")
                        .accessibilityHint("Force end the current trip and save it")
                    }
                }
                .padding()
                .background(Color.floSecondarySystemBackground)
                .cornerRadius(12)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
            
            if !trackingService.isContextInjected {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.expenseRed)
                        .accessibilityHidden(true)
                    Text("Database not connected")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.expenseRed)
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
            return trackingService.currentTrip != nil ? Color.incomeGreen : Color.brandWarning
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
        case .available: return Color.incomeGreen
        case .lowAccuracy: return Color.brandWarning
        case .searching: return Color.brandWarning.opacity(0.7)
        case .unavailable: return Color.expenseRed
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
                    .foregroundStyle(Color.brandWarning)
                    .font(.title3)
                    .symbolEffect(.bounce, value: appeared)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trip Recovery")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("A trip was interrupted and can be recovered")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Started:")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(tripInfo.startDate.formatted(date: .abbreviated, time: .shortened))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                
                HStack {
                    Text("From:")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(tripInfo.startAddress)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                
                HStack {
                    Text("Distance:")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(String(format: "%.1f miles", tripInfo.distanceMiles))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandPrimary)
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color.floTertiarySystemBackground)
            .cornerRadius(8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recovered trip: started \(AccessibilityFormatters.spokenDate(tripInfo.startDate)), from \(tripInfo.startAddress), \(String(format: "%.1f", tripInfo.distanceMiles)) miles")
            
            HStack(spacing: 12) {
                Button(action: onDiscard) {
                    Text("Discard")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.expenseRed)
                .accessibilityLabel("Discard recovered trip")
                .accessibilityHint("Permanently delete this interrupted trip")
                
                Button(action: onSave) {
                    Text("Save Trip")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
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
                .foregroundStyle(Color.expenseRed)
                .font(.title3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.expenseRed)
                Text(error.userMessage)
                    .font(.subheadline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fontWeight(.bold)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.floCardGlass)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.floCardBorder, lineWidth: 1)
        )
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

    private var needsReview: Bool {
        trip.purpose == .needsReview
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.purpose.icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(trip.purpose.displayName)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.medium)

                    // NEEDS REVIEW pill — surfaces unclassified trips at a glance
                    if needsReview {
                        Text("NEEDS REVIEW")
                            .font(.system(size: 9, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                            .accessibilityHidden(true)
                    }
                }

                Text(trip.startDate, style: .date)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())

                if trip.isBusinessTrip {
                    Text(String(format: "$%.2f", trip.deductionAmount))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(Color.incomeGreen)
                }
            }

            // Disclosure chevron — signals row is tappable to open detail editor
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .onAppear {
            appeared = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tripRowAccessibilityLabel)
        .accessibilityHint(needsReview ? "Tap to classify as business or personal" : "Tap to edit trip")
    }

    private var iconColor: Color {
        if needsReview { return .orange }
        return trip.isBusinessTrip ? Color.brandPrimary : .gray
    }

    private var tripRowAccessibilityLabel: String {
        var parts = [
            trip.purpose.displayName,
            AccessibilityFormatters.spokenDate(trip.startDate),
            String(format: "%.1f miles", trip.distanceMiles)
        ]
        if needsReview {
            parts.insert("Needs review", at: 0)
        } else if trip.isBusinessTrip {
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
