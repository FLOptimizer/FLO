//  MileageDashboardCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.4.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing mileage tracking summary and current trip status
//
//  CHANGES v3.3:
//  ✅ FIXED: Free tier no longer sees GPS tracking features
//  ✅ FIXED: Free tier card shows manual-only stats with upgrade prompt
//  ✅ FIXED: trackingService only accessed for Premium+ users
//  ✅ FIXED: "Enable Tracking" button hidden for Free tier
//  ✅ Free tier shows "Upgrade for GPS Tracking" instead
//
//  SUBSCRIPTION BEHAVIOR:
//  - Free: Shows trip stats, "Add Manual Trip" hint, upgrade prompt
//  - Premium/Pro: Full GPS tracking controls, current trip display
//
//  CHANGES v3.2:
//  - Added VoiceOver labels for tracking status indicator
//  - Current trip card fully accessible with distance updates
//
//  CHANGES v3.1:
//  - Single bounce on appear (not on every touch)
//  - Teal color for car icon (Color.brandPrimary)
//

import SwiftUI
import SwiftData
import FLODesignSystem

struct MileageDashboardCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var currentMonthTrips: [MileageTrip]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    // CRITICAL v3.3: Only access tracking service for Premium+ users
    // This prevents location manager initialization for Free tier
    private var trackingService: MileageTrackingService? {
        subscriptionManager.currentTier.hasAutomatedMileage ? MileageTrackingService.shared : nil
    }
    
    @State private var showTripList = false
    @State private var showSubscriptionView = false
    @State private var showManualEntry = false
    
    // Animation States
    @State private var cardVisible = false
    @State private var statsVisible = false
    @State private var trackingPulse = false
    @State private var enableButtonScale: CGFloat = 1.0
    
    // Check if user has GPS tracking access
    private var hasGPSAccess: Bool {
        subscriptionManager.currentTier.hasAutomatedMileage
    }
    
    // Filtered Query for current month
    init() {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        
        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let predicate = #Predicate<MileageTrip> { trip in
            trip.startDate >= startOfMonth && trip.startDate < endOfMonth
        }
        
        _currentMonthTrips = Query(
            FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        )
    }
    
    private var businessTrips: [MileageTrip] {
        currentMonthTrips.filter { $0.isBusinessTrip }
    }
    
    private var totalBusinessMiles: Double {
        businessTrips.reduce(0) { $0 + $1.distanceMiles }
    }
    
    private var totalDeduction: Double {
        businessTrips.reduce(0) { $0 + $1.deductionAmount }
    }
    
    private var totalTrips: Int {
        currentMonthTrips.count
    }
    
    private var enableTrackingButtonText: String {
        guard let service = trackingService else { return "Upgrade for GPS" }
        
        switch service.trackingPermissionStatus {
        case .notDetermined:
            return "Enable Tracking"
        #if !os(macOS)
        case .authorizedWhenInUse:
            return "Start Tracking"
        #endif
        case .authorizedAlways:
            return "Start Tracking"
        default:
            return "Enable in Settings"
        }
    }
    
    // MARK: - Accessibility Labels
    
    private var cardAccessibilityLabel: String {
        var label = "Mileage tracking"
        
        if hasGPSAccess, let service = trackingService, service.isTracking {
            label += ", currently tracking"
            if let trip = service.currentTrip {
                label += ", \(String(format: "%.1f", service.currentDistanceMiles)) miles from \(trip.startAddress)"
            }
        }
        
        if totalTrips > 0 {
            label += ". This month: \(String(format: "%.1f", totalBusinessMiles)) business miles, \(totalDeduction.accessibilityCurrency) tax deduction, \(totalTrips) total trips"
        } else {
            label += ". No trips recorded this month"
        }
        
        if !hasGPSAccess {
            label += ". Upgrade to Premium for automatic GPS tracking"
        }
        
        return label
    }
    
    var body: some View {
        Button {
            handleTap()
        } label: {
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider()
                    .accessibilityHidden(true)
                
                // Current trip (Premium+ only, when tracking)
                if hasGPSAccess, let service = trackingService, let currentTrip = service.currentTrip {
                    CurrentTripCard(
                        trip: currentTrip,
                        distance: service.currentDistanceMiles
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    
                    Divider()
                        .accessibilityHidden(true)
                }
                
                // Stats or Empty
                if totalTrips > 0 {
                    statsContent
                } else {
                    emptyStateContent
                }
            }
        }
        .buttonStyle(AnimatedCardButtonStyle())
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow(radius: 6, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double tap to view all trips")
        .onAppear {
            animateEntrance()
            
            // Only inject context for Premium+ users
            if hasGPSAccess {
                trackingService?.inject(modelContext: modelContext)
            }
        }
        .onChange(of: trackingService?.isTracking) { _, isTracking in
            if isTracking == true {
                startTrackingPulse()
            } else {
                trackingPulse = false
            }
        }
        .onChange(of: trackingService?.trackingPermissionStatus) { oldStatus, newStatus in
            guard hasGPSAccess, let service = trackingService else { return }
            
            if oldStatus == .notDetermined &&
               ({
                    #if os(macOS)
                    return newStatus == .authorized || newStatus == .authorizedAlways
                    #else
                    return newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways
                    #endif
                }()) {
                if !service.isTracking {
                    service.startTracking()
                }
            }
        }
        .sheet(isPresented: $showTripList) {
            NavigationStack {
                MileageTripListView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                HapticService.play(.light)
                                showTripList = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView()
        }
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                ManualTripEntryView()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            FLOBrandedIcon(icon: .mileage, size: .medium, color: .brandPrimary)
            
            Text("Mileage")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // Tracking status (Premium+ only)
            if hasGPSAccess, let service = trackingService, service.isTracking {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(trackingPulse ? 1.3 : 1.0)
                        .opacity(trackingPulse ? 0.7 : 1.0)
                        .accessibilityHidden(true)
                    
                    Text("Tracking")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mileage tracking active")
            }
            
            // Free tier indicator
            if !hasGPSAccess {
                Text("Manual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(4)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .opacity(cardVisible ? 1 : 0.001)
    }
    
    // MARK: - Stats Content
    
    private var statsContent: some View {
        VStack(spacing: 12) {
            MileageStatRow(
                icon: "car.fill",
                label: "Business Miles",
                value: String(format: "%.1f mi", totalBusinessMiles),
                color: Color.brandPrimary,
                delay: 0,
                isVisible: statsVisible
            )
            
            MileageStatRow(
                icon: "dollarsign.circle.fill",
                label: "Tax Deduction",
                value: String(format: "$%.2f", totalDeduction),
                color: .green,
                delay: 0.05,
                isVisible: statsVisible
            )
            
            MileageStatRow(
                icon: "list.bullet",
                label: "Total Trips",
                value: "\(totalTrips) trips",
                color: .blue,
                delay: 0.1,
                isVisible: statsVisible
            )
            
            HStack {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                
                let currentYear = Calendar.current.component(.year, from: Date())
                let rate = MileageTrip.irsRateForYear(currentYear)
                Text("IRS rate: \(String(format: "%.1f¢", rate * 100))/mi")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .opacity(statsVisible ? 1 : 0.001)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: statsVisible)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current IRS mileage rate: \(String(format: "%.1f", MileageTrip.irsRateForYear(Calendar.current.component(.year, from: Date())) * 100)) cents per mile")
        }
        .padding()
    }
    
    // MARK: - Empty State Content
    
    private var emptyStateContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "car")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("No trips this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if hasGPSAccess {
                // Premium+ users: Show enable tracking button
                if let service = trackingService, !service.isTracking {
                    Button {
                        enableTracking()
                    } label: {
                        Text(enableTrackingButtonText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.brandPrimary)
                            .cornerRadius(8)
                            .scaleEffect(enableButtonScale)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(enableTrackingButtonText)
                    .accessibilityHint("Double tap to start automatic mileage tracking")
                }
            } else {
                // Free tier: Show upgrade and manual entry options
                VStack(spacing: 12) {
                    Button {
                        HapticService.play(.medium)
                        showManualEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .accessibilityHidden(true)
                            Text("Add Manual Trip")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.brandPrimary)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Add manual trip")
                    .accessibilityHint("Double tap to manually log a business trip")
                    
                    Button {
                        HapticService.play(.light)
                        showSubscriptionView = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Try GPS Tracking Free for 7 Days")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.brandPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Upgrade for GPS tracking")
                    .accessibilityHint("Double tap to view Premium subscription options")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .opacity(cardVisible ? 1 : 0.001)
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            statsVisible = true
        }
        
        // Start tracking pulse if already tracking (Premium+ only)
        if hasGPSAccess, let service = trackingService, service.isTracking {
            startTrackingPulse()
        }
    }
    
    private func startTrackingPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            trackingPulse = true
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        HapticService.play(.light)
        showTripList = true
    }
    
    private func enableTracking() {
        // Only for Premium+ users
        guard hasGPSAccess, let service = trackingService else {
            showSubscriptionView = true
            return
        }
        
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            enableButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                enableButtonScale = 1.0
            }
        }
        
        let status = service.trackingPermissionStatus
        
        if status == .notDetermined {
            service.requestLocationPermission()
        } else if ({
            #if os(macOS)
            return status == .authorized || status == .authorizedAlways
            #else
            return status == .authorizedWhenInUse || status == .authorizedAlways
            #endif
        }()) {
            if !service.isTracking {
                service.startTracking()
            }
        }
    }
}

// MARK: - Current Trip Card

private struct CurrentTripCard: View {
    let trip: TripInProgress
    let distance: Double
    
    @State private var locationPulse = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
                    .scaleEffect(locationPulse ? 1.2 : 1.0)
                    .accessibilityHidden(true)
                
                Text("Trip in Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f mi", distance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                     .foregroundStyle(Color.brandPrimary)
                    .contentTransition(.numericText())
            }
            
            Text("From: \(trip.startAddress)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                locationPulse = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip in progress. Distance: \(String(format: "%.1f", distance)) miles. Starting from: \(trip.startAddress)")
        .accessibilityValue("\(String(format: "%.1f", distance)) miles")
    }
}

// MARK: - Mileage Stat Row

private struct MileageStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -10)
        .animation(.easeOut(duration: 0.3).delay(delay), value: isVisible)
    }
}


// MARK: - Preview

#Preview {
    MileageDashboardCard()
        .modelContainer(ModelContainer.preview())
        .padding()
}
