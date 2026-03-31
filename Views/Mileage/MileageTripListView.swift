//  MileageTripListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.1 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.1 - Dynamic Type Verification:
//  ✅ FIXED: Empty state "No Trips" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Empty state description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow purpose name missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow address labels (start/end) missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow date text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow miles value missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow deduction amount missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TripListRow "Personal" badge missing lineLimit + minimumScaleFactor
//  ✅ FIXED: StatColumn value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: StatColumn title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Picker period tag text missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.4:
//  ✅ ADDED: Period picker VoiceOver label with current value
//  ✅ ADDED: Period change announces filtered count
//  ✅ ADDED: StatisticsCard accessible with combined summary label
//  ✅ ADDED: StatColumn accessible (icon hidden, value+title combined)
//  ✅ ADDED: TripListRow combined label (purpose, route, distance, deduction, date)
//  ✅ ADDED: TripListRow hint for navigation + swipe
//  ✅ ADDED: Empty state accessible
//  ✅ ADDED: Delete action announced
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Decorative icons hidden
//
//  CHANGES v2.3:
//  - Migrated to centralized HapticService
//

import SwiftUI
import SwiftData

struct MileageTripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \MileageTrip.startDate, order: .reverse)
    private var allTrips: [MileageTrip]
    
    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var showingDeleteConfirmation = false
    @State private var tripToDelete: MileageTrip?
    @State private var viewAppeared = false
    
    // Filtered trips based on selected period
    private var filteredTrips: [MileageTrip] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .thisMonth:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }
            return allTrips.filter { $0.isInRange(from: interval.start, to: interval.end) }
            
        case .lastMonth:
            guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                  let interval = calendar.dateInterval(of: .month, for: lastMonth) else { return [] }
            return allTrips.filter { $0.isInRange(from: interval.start, to: interval.end) }
            
        case .thisYear:
            let year = calendar.component(.year, from: now)
            return allTrips.filter { $0.isInYear(year) }
            
        case .all:
            return allTrips
        }
    }
    
    // Business trips only for statistics
    private var businessTrips: [MileageTrip] {
        filteredTrips.filter { $0.isBusinessTrip }
    }
    
    // Statistics for current filter
    private var statistics: TripStatistics {
        TripStatistics(
            totalTrips: filteredTrips.count,
            businessTrips: businessTrips.count,
            totalMiles: businessTrips.reduce(0) { $0 + $1.distanceMiles },
            totalDeduction: businessTrips.reduce(0) { $0 + $1.deductionAmount }
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Period Picker
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TimePeriod.allCases) { period in
                    Text(period.shortName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewAppeared)
            // v2.4: VoiceOver
            .accessibilityLabel("Time period: \(selectedPeriod.displayName)")
            .accessibilityHint("Filter trips by time period")
            
            // Statistics Card (if there are trips)
            if !filteredTrips.isEmpty {
                StatisticsCard(stats: statistics, appeared: viewAppeared)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
            
            // Trip List
            if filteredTrips.isEmpty {
                VStack(spacing: 16) {
                    MileageIllustration()
                    
                    Text("No Trips")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Text("No trips recorded for \(selectedPeriod.displayName.lowercased())")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Close") {
                        HapticService.shared.mediumImpact()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
            } else {
                List {
                    ForEach(Array(filteredTrips.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink {
                            MileageTripDetailView(trip: trip)
                        } label: {
                            TripListRow(trip: trip)
                        }
                        // v2.4: Rotor action for delete
                        .accessibilityAction(named: "Delete") {
                            tripToDelete = trip
                            showingDeleteConfirmation = true
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(x: viewAppeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(0.15 + Double(index) * 0.03),
                            value: viewAppeared
                        )
                    }
                    .onDelete(perform: confirmDelete)
                }
                .listStyle(.plain)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredTrips.isEmpty)
        .navigationTitle("Mileage Log")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Trip?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                tripToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete {
                    deleteTrip(trip)
                }
            }
        } message: {
            if let trip = tripToDelete {
                Text("Delete the \(String(format: "%.1f", trip.distanceMiles)) mile trip from \(trip.startDate.formatted(date: .abbreviated, time: .omitted))?")
            }
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            HapticService.shared.selection()
            // v2.4: Announce filter change
            AccessibilityAnnouncement.announce("Showing \(newValue.displayName). \(filteredTrips.count) trips.")
            
            viewAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                viewAppeared = true
            }
            // v2.4: Announce screen
            AccessibilityAnnouncement.screenChanged("Mileage Log. \(filteredTrips.count) trips for \(selectedPeriod.displayName).")
        }
    }
    
    // MARK: - Actions
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        HapticService.shared.heavyImpact()
        tripToDelete = filteredTrips[index]
        showingDeleteConfirmation = true
    }
    
    private func deleteTrip(_ trip: MileageTrip) {
        let miles = String(format: "%.1f", trip.distanceMiles)
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            modelContext.delete(trip)
        }
        
        do {
            try modelContext.save()
            HapticService.shared.success()
            // v2.4: Announce deletion
            AccessibilityAnnouncement.announce("\(miles) mile trip deleted")
        } catch {
            HapticService.shared.error()
        }
        
        tripToDelete = nil
    }
}

// MARK: - Trip List Row

struct TripListRow: View {
    let trip: MileageTrip
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Purpose Icon
            Image(systemName: trip.purpose.icon)
                .font(.title2)
                .foregroundStyle(trip.isBusinessTrip ? Color.brandPrimary : .gray)
                .frame(width: 36)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)
                // v2.4: Decorative
                .accessibilityHidden(true)
            
            // Trip Details
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.purpose.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                HStack(spacing: 4) {
                    Text(trip.abbreviatedStartAddress)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("→")
                        .font(.caption2)
                    Text(trip.abbreviatedEndAddress)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                Text(trip.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Miles & Deduction
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                
                if trip.isBusinessTrip {
                    Text(trip.deductionAmount.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                } else {
                    Text("Personal")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        // v2.4: Combined accessible label for row
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tripAccessibilityLabel)
        .accessibilityHint("Double tap to view details. Swipe left to delete.")
        .onAppear {
            appeared = true
        }
    }
    
    // v2.4: Comprehensive VoiceOver label
    private var tripAccessibilityLabel: String {
        var parts: [String] = [trip.purpose.displayName]
        
        parts.append(trip.isBusinessTrip ? "Business" : "Personal")
        
        parts.append(String(format: "%.1f miles", trip.distanceMiles))
        
        if trip.isBusinessTrip {
            parts.append("Deduction: \(AccessibilityFormatters.spokenCurrency(trip.deductionAmount))")
        }
        
        let from = trip.abbreviatedStartAddress
        let to = trip.abbreviatedEndAddress
        if !from.isEmpty && !to.isEmpty {
            parts.append("From \(from) to \(to)")
        }
        
        parts.append(AccessibilityFormatters.spokenDate(trip.startDate))
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Statistics Card

struct StatisticsCard: View {
    let stats: TripStatistics
    let appeared: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            StatColumn(
                title: "Trips",
                value: "\(stats.businessTrips)",
                icon: "car.fill",
                color: Color.brandPrimary,
                delay: 0.1,
                appeared: appeared
            )
            
            Divider()
                .frame(height: 40)
                // v2.4: Decorative divider
                .accessibilityHidden(true)
            
            StatColumn(
                title: "Miles",
                value: String(format: "%.1f", stats.totalMiles),
                icon: "road.lanes",
                color: .blue,
                delay: 0.15,
                appeared: appeared
            )
            
            Divider()
                .frame(height: 40)
                .accessibilityHidden(true)
            
            StatColumn(
                title: "Deduction",
                value: stats.totalDeduction.formatted(.currency(code: "USD")),
                icon: "dollarsign.circle.fill",
                color: .green,
                delay: 0.2,
                appeared: appeared
            )
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .opacity(appeared ? 1 : 0.001)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)
        // v2.4: Combined stats accessible as one element
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Business mileage summary: \(stats.businessTrips) trips, \(String(format: "%.1f", stats.totalMiles)) miles, \(AccessibilityFormatters.spokenCurrency(stats.totalDeduction)) deduction")
        .accessibilityAddTraits(.isSummaryElement)
    }
}

struct StatColumn: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var delay: Double = 0
    var appeared: Bool = true
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                // v2.4: Decorative (parent handles label)
                .accessibilityHidden(true)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0.001)
        .scaleEffect(appeared ? 1 : 0.9)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: appeared)
        // v2.4: Individual stat column (parent combines)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Supporting Types

enum TimePeriod: String, CaseIterable, Identifiable {
    case thisMonth = "thisMonth"
    case lastMonth = "lastMonth"
    case thisYear = "thisYear"
    case all = "all"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .thisMonth: return "This Month"
        case .lastMonth: return "Last Month"
        case .thisYear: return "This Year"
        case .all: return "All Time"
        }
    }
    
    var shortName: String {
        switch self {
        case .thisMonth: return "Month"
        case .lastMonth: return "Last"
        case .thisYear: return "Year"
        case .all: return "All"
        }
    }
}

struct TripStatistics {
    let totalTrips: Int
    let businessTrips: Int
    let totalMiles: Double
    let totalDeduction: Double
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MileageTripListView()
    }
    .modelContainer(for: [MileageTrip.self], inMemory: true)
}
