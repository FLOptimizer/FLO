//  MileageTripDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Detail view for viewing and editing a mileage trip
//
//  ENHANCEMENTS v2.0:
//  - Haptic feedback on toggle switches and button interactions
//  - Animated map entrance with scale effect
//  - Smooth section reveals with staggered timing
//  - Business toggle with visual celebration
//  - Delete button shake animation on tap
//  - Enhanced detail row hover states
//  - Save confirmation haptic pattern
//

import SwiftUI
import SwiftData
import MapKit

struct MileageTripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var trip: MileageTrip
    
    @State private var showingDeleteConfirmation = false
    
    // Animation States
    @State private var mapScale: CGFloat = 0.95
    @State private var mapOpacity: Double = 0
    @State private var classificationOpacity: Double = 0
    @State private var detailsOpacity: Double = 0
    @State private var routeOpacity: Double = 0
    @State private var notesOpacity: Double = 0
    @State private var infoOpacity: Double = 0
    @State private var deleteOpacity: Double = 0
    @State private var businessToggleScale: CGFloat = 1.0
    @State private var deleteButtonShake = false
    @State private var showSavedConfirmation = false
    
    var body: some View {
        Form {
            // Map Section
            Section {
                TripMapView(trip: trip)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .scaleEffect(mapScale)
                    .opacity(mapOpacity)
            }
            
            // Trip Classification
            Section {
                HStack {
                    Toggle("Business Trip", isOn: $trip.isBusinessTrip)
                        .tint(.teal)
                        .onChange(of: trip.isBusinessTrip) { oldValue, newValue in

                            HapticService.play(.medium)
                            
                            // Celebration animation when marking as business
                            if newValue {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    businessToggleScale = 1.1
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                        businessToggleScale = 1.0
                                    }
                                }
                            }
                        }
                }
                .scaleEffect(businessToggleScale)
                
                Picker("Purpose", selection: $trip.purpose) {
                    ForEach(TripPurpose.allCases) { purpose in
                        Label(purpose.displayName, systemImage: purpose.icon)
                            .tag(purpose)
                    }
                }
                .pickerStyle(.navigationLink)
                .onChange(of: trip.purpose) { _, _ in
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
            } header: {
                Text("Classification")
            } footer: {
                HStack(spacing: 4) {
                    Image(systemName: trip.isBusinessTrip ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption2)
                    Text(trip.isBusinessTrip ?
                         "This trip will be included in your tax deduction" :
                         "Personal trips are not tax deductible")
                }
                .foregroundStyle(trip.isBusinessTrip ? .green : .secondary)
                .font(.footnote)
                .animation(.easeInOut(duration: 0.2), value: trip.isBusinessTrip)
            }
            .opacity(classificationOpacity)
            
            // Trip Details
            Section("Details") {
                AnimatedDetailRow(icon: "calendar", label: "Date", value: trip.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), delay: 0)
                AnimatedDetailRow(icon: "clock", label: "Time", value: trip.startDate.formatted(.dateTime.hour().minute()), delay: 0.05)
                AnimatedDetailRow(icon: "timer", label: "Duration", value: trip.durationFormatted, delay: 0.1)
                AnimatedDetailRow(icon: "car.fill", label: "Distance", value: String(format: "%.2f miles", trip.distanceMiles), delay: 0.15)
                
                if trip.isBusinessTrip {
                    AnimatedDetailRow(icon: "dollarsign.circle.fill", label: "Deduction", value: trip.deductionAmount.formatted(.currency(code: "USD")), delay: 0.2, valueColor: .green)
                    AnimatedDetailRow(icon: "percent", label: "IRS Rate 2025", value: String(format: "%.1f¢/mile", trip.mileageRate * 100), delay: 0.25)
                }
            }
            .opacity(detailsOpacity)
            
            // Locations
            Section("Route") {
                if let startAddress = trip.startAddress {
                    AddressRow(title: "Start", address: startAddress, color: .green, icon: "location.circle.fill")
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                
                if let endAddress = trip.endAddress {
                    AddressRow(title: "End", address: endAddress, color: .red, icon: "location.circle.fill")
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                
                if trip.startAddress == nil && trip.endAddress == nil {
                    Text("Addresses not available")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            .opacity(routeOpacity)
            
            // Notes
            Section("Notes") {
                TextEditor(text: Binding(
                    get: { trip.notes ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        trip.notes = trimmed.isEmpty ? nil : trimmed
                    }
                ))
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
            }
            .opacity(notesOpacity)
            
            // Metadata
            Section("Info") {
                AnimatedDetailRow(
                    icon: trip.isManualEntry ? "hand.raised.fill" : "location.fill",
                    label: "Entry Type",
                    value: trip.isManualEntry ? "Manual Entry" : "Auto-Tracked",
                    delay: 0
                )
                
                AnimatedDetailRow(
                    icon: "calendar.badge.plus",
                    label: "Created",
                    value: trip.createdDate.formatted(.dateTime.year().month(.abbreviated).day().hour().minute()),
                    delay: 0.05
                )
                
                if trip.modifiedDate != trip.createdDate {
                    AnimatedDetailRow(
                        icon: "pencil.circle.fill",
                        label: "Last Modified",
                        value: trip.modifiedDate.formatted(.dateTime.year().month(.abbreviated).day().hour().minute()),
                        delay: 0.1
                    )
                }
            }
            .opacity(infoOpacity)
            
            // Delete Button
            Section {
                Button(role: .destructive) {
       
                    HapticService.play(.medium)
                    
                    withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                        deleteButtonShake = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        deleteButtonShake = false
                    }
                    
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete Trip")
                        Spacer()
                    }
                    .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity)
                .offset(x: deleteButtonShake ? -5 : 0)
            }
            .listRowBackground(Color(UIColor.systemGroupedBackground))
            .opacity(deleteOpacity)
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    saveChanges()
                }
                .fontWeight(.medium)
            }
        }
        .onAppear {
            animateEntrance()
        }
        .confirmationDialog(
            "Delete this trip?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteTrip()
            }
            Button("Cancel", role: .cancel) {

                HapticService.play(.medium)
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .overlay(alignment: .top) {
            if showSavedConfirmation {
                savedConfirmationBanner
            }
        }
    }
    
    // MARK: - Saved Confirmation Banner
    
    private var savedConfirmationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Changes Saved")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .padding(.top, 8)
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Map animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            mapScale = 1.0
            mapOpacity = 1.0
        }
        
        // Staggered section reveals
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            classificationOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            detailsOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            routeOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            notesOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            infoOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            deleteOpacity = 1.0
        }
    }
    
    // MARK: - Actions
    
    private func saveChanges() {
        trip.modifiedDate = Date()
        
        do {
            try modelContext.save()
            
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Show confirmation banner briefly
            withAnimation(FLOAnimation.quick) {
                showSavedConfirmation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(FLOAnimation.quickEase) {
                    showSavedConfirmation = false
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
            
            #if DEBUG
            print("✅ Trip changes saved")
            #endif
            
        } catch {
            print("Failed to save trip: \(error)")
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            dismiss()
        }
    }
    
    private func deleteTrip() {
        // Heavy haptic for delete

        HapticService.play(.medium)
        
        modelContext.delete(trip)
        
        do {
            try modelContext.save()
            
            // Warning haptic after delete
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.warning)
            
            #if DEBUG
            print("✅ Trip deleted")
            #endif
            
        } catch {
            print("Failed to delete trip: \(error)")
            
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.error)
        }
        
        dismiss()
    }
}

// MARK: - Animated Detail Row

private struct AnimatedDetailRow: View {
    let icon: String
    let label: String
    let value: String
    let delay: Double
    var valueColor: Color = .primary
    
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.teal)
                .frame(width: 28, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(valueColor)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Address Row

struct AddressRow: View {
    let title: String
    let address: String
    let color: Color
    let icon: String
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
        .onTapGesture {

            HapticService.play(.medium)
            
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                isHovered = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isHovered = false
                }
            }
        }
    }
}

// MARK: - Trip Map View

struct TripMapView: View {
    let trip: MileageTrip
    @State private var region: MKCoordinateRegion
    @State private var showAnnotations = false
    
    init(trip: MileageTrip) {
        self.trip = trip
        
        let center = CLLocationCoordinate2D(
            latitude: (trip.startLatitude + trip.endLatitude) / 2,
            longitude: (trip.startLongitude + trip.endLongitude) / 2
        )
        
        let latDelta = max(abs(trip.startLatitude - trip.endLatitude) * 1.8, 0.012)
        let lonDelta = max(abs(trip.startLongitude - trip.endLongitude) * 1.8, 0.012)
        
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        
        _region = State(initialValue: MKCoordinateRegion(center: center, span: span))
    }
    
    var body: some View {
        Map(position: .constant(.region(region))) {
            if showAnnotations {
                Annotation("Start", coordinate: trip.startLocation) {
                    ZStack {
                        Circle().fill(.green.opacity(0.9)).frame(width: 34, height: 34)
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                    .scaleEffect(showAnnotations ? 1.0 : 0.5)
                }
                
                Annotation("End", coordinate: trip.endLocation) {
                    ZStack {
                        Circle().fill(.red.opacity(0.9)).frame(width: 34, height: 34)
                        Image(systemName: "flag.checkered.circle.fill")
                            .foregroundStyle(.white)
                            .font(.title2)
                    }
                    .scaleEffect(showAnnotations ? 1.0 : 0.5)
                }
            }
            
            if let routePoints = trip.routePoints, !routePoints.isEmpty {
                MapPolyline(coordinates: routePoints.map(\.coordinate))
                    .stroke(Color.teal, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onAppear {
            // Delay annotation appearance for dramatic effect
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showAnnotations = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MileageTripDetailView(
            trip: {
                let trip = MileageTrip(
                    startDate: Date().addingTimeInterval(-5400),
                    endDate: Date().addingTimeInterval(-1800),
                    startLatitude: 37.7749,
                    startLongitude: -122.4194,
                    endLatitude: 37.8044,
                    endLongitude: -122.2712,
                    startAddress: "1 Infinite Loop, Cupertino, CA",
                    endAddress: "500 Oracle Pkwy, Redwood City, CA",
                    distanceMiles: 28.7,
                    purpose: .clientMeeting,
                    isBusinessTrip: true,
                    notes: "Met with client about Q4 projections. Discussed new contract terms."
                )
                return trip
            }()
        )
    }
    .modelContainer(ModelContainer.preview())
}

#Preview("Personal Trip") {
    NavigationStack {
        MileageTripDetailView(
            trip: {
                let trip = MileageTrip(
                    startDate: Date().addingTimeInterval(-3600),
                    endDate: Date().addingTimeInterval(-1200),
                    startLatitude: 37.7749,
                    startLongitude: -122.4194,
                    endLatitude: 37.7849,
                    endLongitude: -122.4094,
                    startAddress: "Home",
                    endAddress: "Grocery Store",
                    distanceMiles: 5.2,
                    purpose: .other,
                    isBusinessTrip: false,
                    notes: nil
                )
                return trip
            }()
        )
    }
    .modelContainer(ModelContainer.preview())
}
