//  MileageTripListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 ELITE - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.1:
//  ✅ Haptic feedback on period changes
//  ✅ Haptic on delete/export actions
//  ✅ List row staggered animations
//  ✅ Statistics card animations
//  ✅ Empty state icon animation
//  ✅ Export success haptic
//  ✅ Value content transitions
//
//  PREVIOUS (v2.0):
//  - Period filtering, CSV export, swipe to delete

import SwiftUI
import SwiftData

struct MileageTripListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \MileageTrip.startDate, order: .reverse)
    private var allTrips: [MileageTrip]
    
    @State private var selectedPeriod: TimePeriod = .thisMonth
    @State private var showingManualEntry = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var tripToDelete: MileageTrip?
    @State private var viewAppeared = false
    
    // Haptic Generators
                        
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
                    Text(period.shortName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 12)
            .opacity(viewAppeared ? 1 : 0)
            .animation(FLOAnimation.standard, value: viewAppeared)
            
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
                ContentUnavailableView {
                    Label("No Trips", systemImage: "car")
                        .symbolEffect(.bounce, value: viewAppeared)
                } description: {
                    Text("No trips recorded for \(selectedPeriod.displayName.lowercased())")
                } actions: {
                    Button("Add Manual Trip") {
                        HapticService.play(.medium)
                        showingManualEntry = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppConstants.primaryColor)
                }
                .frame(maxHeight: .infinity)
                .opacity(viewAppeared ? 1 : 0)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
            } else {
                List {
                    ForEach(Array(filteredTrips.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink {
                            MileageTripDetailView(trip: trip)
                        } label: {
                            TripListRow(trip: trip)
                        }
                        .opacity(viewAppeared ? 1 : 0)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticService.play(.medium)
                        showingManualEntry = true
                    } label: {
                        Label("Add Manual Trip", systemImage: "plus.circle")
                    }
                    
                    Divider()
                    
                    Button {
                        HapticService.play(.medium)
                        exportToCSV()
                    } label: {
                        Label("Export to CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(businessTrips.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            NavigationStack {
                ManualTripEntryView()
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
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
            HapticService.play(.selection)
            // Reset animation state briefly for re-animation effect
            viewAppeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
        .onAppear {
                        withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Actions
    
    private func confirmDelete(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        HapticService.play(.heavy)
        tripToDelete = filteredTrips[index]
        showingDeleteConfirmation = true
    }
    
    private func deleteTrip(_ trip: MileageTrip) {
        withAnimation(FLOAnimation.quick) {
            modelContext.delete(trip)
        }
        
        do {
            try modelContext.save()
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
        }
        
        tripToDelete = nil
    }
    
    private func exportToCSV() {
        guard !businessTrips.isEmpty else { return }
        
        // Build CSV content
        var csv = MileageTrip.csvHeader + "\n"
        for trip in businessTrips.sorted(by: { $0.startDate < $1.startDate }) {
            csv += trip.toCSVRow() + "\n"
        }
        
        // Add summary footer
        csv += "\n"
        csv += "Summary\n"
        csv += "Total Business Trips,\(statistics.businessTrips)\n"
        csv += "Total Miles,\(String(format: "%.2f", statistics.totalMiles))\n"
        csv += "Total Deduction,\(String(format: "%.2f", statistics.totalDeduction))\n"
        csv += "Export Date,\(Date().formatted(date: .complete, time: .shortened))\n"
        
        // Generate filename
        let periodName = selectedPeriod.displayName.replacingOccurrences(of: " ", with: "_")
        let dateStr = Date().formatted(.iso8601.year().month().day())
        let fileName = "FLO_Mileage_\(periodName)_\(dateStr).csv"
        
        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingExportSheet = true
            HapticService.play(.success)
        } catch {
            HapticService.play(.error)
            print("❌ Failed to export CSV: \(error)")
        }
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
                .foregroundStyle(trip.isBusinessTrip ? AppConstants.primaryColor : .gray)
                .frame(width: 36)
                .scaleEffect(appeared ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appeared)
            
            // Trip Details
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.purpose.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text(trip.abbreviatedStartAddress)
                        .lineLimit(1)
                    Text("→")
                        .font(.caption2)
                    Text(trip.abbreviatedEndAddress)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                Text(trip.startDate.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // Miles & Deduction
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())
                
                if trip.isBusinessTrip {
                    Text(trip.deductionAmount.formatted(.currency(code: "USD")))
                        .font(.caption)
                        .foregroundStyle(.green)
                        .contentTransition(.numericText())
                } else {
                    Text("Personal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            appeared = true
        }
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
                color: AppConstants.primaryColor,
                delay: 0.1,
                appeared: appeared
            )
            
            Divider()
                .frame(height: 40)
            
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
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.1), value: appeared)
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
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .contentTransition(.numericText())
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.9)
        .animation(FLOAnimation.standard.delay(delay), value: appeared)
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
