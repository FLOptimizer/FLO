//  MileageDashboardCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing mileage tracking summary and current trip status
//
//  ENHANCEMENTS v3.0:
//  - Animated tracking indicator with pulse effect
//  - Staggered stat row entrance animations
//  - Current trip card with live distance counter
//  - Enable tracking button with press animation
//  - Empty state car icon bounce
//  - Haptic feedback on interactions
//

import SwiftUI
import SwiftData

struct MileageDashboardCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var currentMonthTrips: [MileageTrip]
    @ObservedObject private var trackingService = MileageTrackingService.shared
    
    @State private var showTripList = false
    
    // Animation States
    @State private var cardVisible = false
    @State private var statsVisible = false
    @State private var trackingPulse = false
    @State private var emptyCarBounce = false
    @State private var enableButtonScale: CGFloat = 1.0
    @State private var chevronHover = false
    
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
        switch trackingService.trackingPermissionStatus {
        case .notDetermined:
            return "Enable Tracking"
        case .authorizedWhenInUse:
            return "Start Tracking"
        case .authorizedAlways:
            return "Start Tracking"
        default:
            return "Enable in Settings"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(AppConstants.primaryColor)
                    .symbolEffect(.bounce, value: cardVisible)
                
                Text("Mileage")
                    .font(.headline)
                
                Spacer()
                
                if trackingService.isTracking {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .scaleEffect(trackingPulse ? 1.3 : 1.0)
                            .opacity(trackingPulse ? 0.7 : 1.0)
                        
                        Text("Tracking")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        chevronHover = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        chevronHover = false
                    }
                    
                    showTripList = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .scaleEffect(chevronHover ? 1.2 : 1.0)
                }
            }
            .padding()
            .opacity(cardVisible ? 1 : 0)
            
            Divider()
            
            // Current trip
            if let currentTrip = trackingService.currentTrip {
                CurrentTripCard(
                    trip: currentTrip,
                    distance: trackingService.currentDistanceMiles
                )
                .transition(AnyTransition.asymmetric(
                    insertion: AnyTransition.move(edge: .top).combined(with: AnyTransition.opacity),
                    removal: AnyTransition.opacity
                ))
                
                Divider()
            }
            
            // Stats or Empty
            if totalTrips > 0 {
                VStack(spacing: 12) {
                    AnimatedStatRow(
                        icon: "car.fill",
                        label: "Business Miles",
                        value: String(format: "%.1f mi", totalBusinessMiles),
                        color: AppConstants.primaryColor,
                        delay: 0,
                        isVisible: statsVisible
                    )
                    
                    AnimatedStatRow(
                        icon: "dollarsign.circle.fill",
                        label: "Tax Deduction",
                        value: String(format: "$%.2f", totalDeduction),
                        color: .green,
                        delay: 0.05,
                        isVisible: statsVisible
                    )
                    
                    AnimatedStatRow(
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
                        
                        let currentYear = Calendar.current.component(.year, from: Date())
                        let rate = MileageTrip.irsRateForYear(currentYear)
                        Text("IRS rate: \(String(format: "%.1f¢", rate * 100))/mi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                    .opacity(statsVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: statsVisible)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "car")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .offset(y: emptyCarBounce ? -5 : 0)
                    
                    Text("No trips this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if !trackingService.isTracking {
                        Button(enableTrackingButtonText) {
                            enableTracking()
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppConstants.primaryColor)
                        .cornerRadius(8)
                        .scaleEffect(enableButtonScale)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .opacity(cardVisible ? 1 : 0)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        .onAppear {
            animateEntrance()
            trackingService.inject(modelContext: modelContext)
        }
        .onChange(of: trackingService.isTracking) { _, isTracking in
            if isTracking {
                startTrackingPulse()
            } else {
                trackingPulse = false
            }
        }
        .onChange(of: trackingService.trackingPermissionStatus) { oldStatus, newStatus in
            if oldStatus == .notDetermined &&
               (newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways) {
                if !trackingService.isTracking {
                    trackingService.startTracking()
                }
            }
        }
        .sheet(isPresented: $showTripList) {
            NavigationStack {
                MileageTripListView()
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            statsVisible = true
        }
        
        // Empty state car bounce
        if totalTrips == 0 {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.5)) {
                emptyCarBounce = true
            }
        }
        
        // Start tracking pulse if already tracking
        if trackingService.isTracking {
            startTrackingPulse()
        }
    }
    
    private func startTrackingPulse() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            trackingPulse = true
        }
    }
    
    // MARK: - Actions
    
    private func enableTracking() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            enableButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                enableButtonScale = 1.0
            }
        }
        
        let status = trackingService.trackingPermissionStatus
        
        if status == .notDetermined {
            trackingService.requestLocationPermission()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            if !trackingService.isTracking {
                trackingService.startTracking()
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
                
                Text("Trip in Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f mi", distance))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConstants.primaryColor)
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
    }
}

// MARK: - Animated Stat Row

private struct AnimatedStatRow: View {
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
        .opacity(isVisible ? 1 : 0)
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
