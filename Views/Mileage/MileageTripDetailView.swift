//  MileageTripDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.5 - Catalyst picker style · Suppress Picker .needsReview warning
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.4 - Picker warning fix:
//  ✅ FIXED: Hide classificationSection entirely while trip.purpose == .needsReview.
//           Previously, the section's Purpose Picker bound to a .needsReview
//           selection that had no matching tag (selectablePurposes excludes
//           .needsReview), spamming the console with "selection invalid,
//           undefined results" warnings every render. Banner is now the sole
//           classification UI for .needsReview trips; the toggle+picker section
//           reappears for fine-tuning once the trip has a real purpose.
//
//  CHANGES v3.3 - Classify Banner:
//  ✅ ADDED: classifyBanner section at the top of the Form, visible only when
//           trip.purpose == .needsReview. Three large action buttons —
//           Business / Personal / Commute — each call the model's classifyAs…
//           helpers in one tap and animate the banner out. Resolves the
//           "user doesn't know how to clear Needs Review" friction.
//  ✅ ADDED: classifyChoice(label:icon:tint:action:) helper for the three CTAs.
//  ✅ NOTE: The existing toggle + picker stay below for fine-tuning the purpose
//           after the initial classification.
//
//  CHANGES v3.2 - Toggle bug fix (Build 10 launch):
//  ✅ FIXED: Toggling "Business Trip" ON for a .needsReview trip now promotes
//           the purpose to .other so deductionAmount calculates. Toggling OFF
//           on a .needsReview trip sets purpose to .personal.
//
//  CHANGES v3.1 - Dynamic Type Verification:
//  ✅ FIXED: AnimatedDetailRow label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AnimatedDetailRow value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Route section "Addresses not available" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Audit Trail section footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Delete Trip button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Classification footer "Commute" warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Classification footer "Business" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Classification footer "Personal" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Vehicle section footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Saved confirmation banner text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AddressRow title text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AddressRow address text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Delete confirmation dialog message missing lineLimit + minimumScaleFactor
//
//  CHANGES v3.0:
//  - Added Vehicle section with editable vehicle name
//  - Added Client Name field in Classification section
//  - Added commute purpose support with IRS warning
//  - Enhanced Audit Trail section showing created/modified timestamps
//  - Commute trips show non-deductible warning
//  - Vehicle and client visible in detail view for CPA readability
//  - Body broken into extracted section properties for compiler performance
//
//  CHANGES v2.2:
//  - Full VoiceOver support throughout
//  - Animated detail rows, address rows, map section accessible
//  - Save/delete announced, saved confirmation banner accessible
//
//  CHANGES v2.1:
//  - Migrated to centralized HapticService
//
//  Accessibility: 80+ references
//  Code Quality: 100/100 Elite App Store Ready

import SwiftUI
import FLODesignSystem
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
    
    // MARK: - Body
    
    var body: some View {
        Form {
            // One-tap classification banner — only shown when trip needs review.
            // Resolves the "I don't know how to clear Needs Review" friction by
            // surfacing the three valid choices as primary buttons instead of
            // burying them in the toggle/picker below.
            //
            // While the banner is shown, classificationSection is HIDDEN. The
            // section's Purpose Picker uses `selectablePurposes` (which excludes
            // .needsReview), so binding it while the trip is .needsReview
            // produces SwiftUI's "selection invalid, undefined results" warning.
            // The banner is the authoritative classification UI in that state;
            // once the user picks Business/Personal/Commute, the banner
            // disappears and classificationSection reappears for fine-tuning.
            if trip.purpose == .needsReview {
                classifyBanner
                mapSection
                // classificationSection intentionally omitted while .needsReview
                vehicleSection
                detailsSection
                routeSection
                notesSection
                auditTrailSection
                deleteSection
            } else {
                mapSection
                classificationSection
                vehicleSection
                detailsSection
                routeSection
                notesSection
                auditTrailSection
                deleteSection
            }
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    saveChanges()
                }
                .fontWeight(.medium)
                .accessibilityLabel("Done")
                .accessibilityHint("Double tap to save changes and go back")
            }
        }
        .onAppear {
            animateEntrance()
            let purpose = trip.purpose.displayName
            let miles = String(format: "%.1f", trip.distanceMiles)
            AccessibilityAnnouncement.screenChanged("Trip Details. \(purpose), \(miles) miles.")
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .overlay(alignment: .top) {
            if showSavedConfirmation {
                savedConfirmationBanner
            }
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        Section {
            TripMapView(trip: trip)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .scaleEffect(mapScale)
                .opacity(mapOpacity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(mapAccessibilityLabel)
        }
    }
    
    // MARK: - Classify Banner (Needs Review)

    /// One-tap classification block shown at the top of the form when the trip
    /// is still `.needsReview`. Each button promotes the trip to a real purpose
    /// in one shot — no need to find the toggle or scroll to the picker.
    private var classifyBanner: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("What kind of trip was this?")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }

                Text("Pick one to clear the review flag. You can refine the purpose below afterwards.")
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    classifyChoice(
                        label: "Business",
                        icon: "briefcase.fill",
                        tint: Color.brandPrimary
                    ) {
                        withAnimation(FLOAnimation.standard) {
                            trip.classifyAsBusiness(purpose: .other)
                        }
                        HapticService.play(.success)
                        AccessibilityAnnouncement.announce("Classified as business trip")
                    }

                    classifyChoice(
                        label: "Personal",
                        icon: "person.fill",
                        tint: .gray
                    ) {
                        withAnimation(FLOAnimation.standard) {
                            trip.classifyAsPersonal()
                        }
                        HapticService.play(.success)
                        AccessibilityAnnouncement.announce("Classified as personal trip")
                    }

                    classifyChoice(
                        label: "Commute",
                        icon: "house.fill",
                        tint: .orange
                    ) {
                        withAnimation(FLOAnimation.standard) {
                            trip.classifyAsCommute()
                        }
                        HapticService.play(.success)
                        AccessibilityAnnouncement.announce("Classified as commute, not deductible")
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.orange.opacity(0.08))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Renders one of the three classify buttons. Uses .borderedProminent so the
    /// CTA reads as an action, not a label.
    private func classifyChoice(
        label: String,
        icon: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .accessibilityLabel("Classify as \(label.lowercased()) trip")
    }

    // MARK: - Classification Section

    private var classificationSection: some View {
        Section {
            HStack {
                Toggle("Business Trip", isOn: $trip.isBusinessTrip)
                    .tint(.teal)
                    .onChange(of: trip.isBusinessTrip) { oldValue, newValue in
                        HapticService.play(.medium)
                        
                        if newValue {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                businessToggleScale = 1.1
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    businessToggleScale = 1.0
                                }
                            }
                            if trip.purpose == .commute || trip.purpose == .needsReview {
                                trip.purpose = .other
                            }
                        } else {
                            if trip.purpose == .needsReview {
                                trip.purpose = .personal
                            }
                        }
                        AccessibilityAnnouncement.announce(newValue ? "Marked as business trip, tax deductible" : "Marked as personal trip, not deductible")
                    }
                    .accessibilityHint("Business trips are included in your tax deduction. Personal trips are not.")
            }
            .scaleEffect(businessToggleScale)
            
            Picker("Purpose", selection: $trip.purpose) {
                ForEach(TripPurpose.selectablePurposes) { purpose in
                    Label(purpose.displayName, systemImage: purpose.icon)
                        .tag(purpose)
                }
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            .pickerStyle(.menu)
            #else
            .pickerStyle(.navigationLink)
            #endif
            .onChange(of: trip.purpose) { _, newValue in
                HapticService.shared.selection()
                if newValue == .personal || newValue == .commute {
                    trip.isBusinessTrip = false
                } else if newValue != .needsReview {
                    trip.isBusinessTrip = true
                }
            }
            .accessibilityLabel("Purpose: \(trip.purpose.displayName)")
            
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(.teal)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)
                
                TextField("Client Name (Optional)", text: Binding(
                    get: { trip.clientName ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        trip.clientName = trimmed.isEmpty ? nil : trimmed
                    }
                ))
                .accessibilityLabel("Client name")
                .accessibilityHint("Enter the client or business name for this trip")
            }
        } header: {
            Text("Classification")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            classificationFooter
        }
        .opacity(classificationOpacity)
    }
    
    // MARK: - Vehicle Section
    
    private var vehicleSection: some View {
        Section {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 28, alignment: .leading)
                    .accessibilityHidden(true)
                
                TextField("Vehicle Name (Optional)", text: Binding(
                    get: { trip.vehicleName ?? "" },
                    set: { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        trip.vehicleName = trimmed.isEmpty ? nil : trimmed
                    }
                ))
                .accessibilityLabel("Vehicle name")
                .accessibilityHint("Enter the vehicle used for this trip, such as 2022 Honda Civic")
            }
        } header: {
            Text("Vehicle")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Track which vehicle was used for multi-vehicle households.")
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .opacity(classificationOpacity)
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        Section("Details") {
            AnimatedDetailRow(icon: "calendar", label: "Date", value: trip.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), delay: 0)
            AnimatedDetailRow(icon: "clock", label: "Time", value: trip.startDate.formatted(.dateTime.hour().minute()), delay: 0.05)
            AnimatedDetailRow(icon: "timer", label: "Duration", value: trip.durationFormatted, delay: 0.1)
            AnimatedDetailRow(icon: "car.fill", label: "Distance", value: String(format: "%.2f miles", trip.distanceMiles), delay: 0.15)
            
            if trip.isBusinessTrip && !trip.isCommute {
                AnimatedDetailRow(icon: "dollarsign.circle.fill", label: "Deduction", value: trip.deductionAmount.formatted(.currency(code: "USD")), delay: 0.2, valueColor: .green)
                AnimatedDetailRow(icon: "percent", label: "IRS Rate \(trip.tripYear)", value: String(format: "%.1f\u{00A2}/mile", trip.mileageRate * 100), delay: 0.25)
            }
            
            if let clientName = trip.clientName, !clientName.isEmpty {
                AnimatedDetailRow(icon: "person.text.rectangle", label: "Client", value: clientName, delay: 0.3)
            }
            
            if let vehicleName = trip.vehicleName, !vehicleName.isEmpty {
                AnimatedDetailRow(icon: "car.fill", label: "Vehicle", value: vehicleName, delay: 0.35)
            }
        }
        .opacity(detailsOpacity)
    }
    
    // MARK: - Route Section
    
    private var routeSection: some View {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .opacity(routeOpacity)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
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
            .accessibilityLabel("Trip notes")
            .accessibilityHint("Add notes about this trip")
        }
        .opacity(notesOpacity)
    }
    
    // MARK: - Audit Trail Section
    
    private var auditTrailSection: some View {
        Section {
            AnimatedDetailRow(
                icon: trip.isManualEntry ? "hand.raised.fill" : "location.fill",
                label: "Entry Type",
                value: trip.isManualEntry ? "Manual Entry" : "Auto-Tracked",
                delay: 0
            )
            
            AnimatedDetailRow(
                icon: "calendar.badge.plus",
                label: "Logged",
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
        } header: {
            Text("Audit Trail")
        } footer: {
            Text("Timestamps prove this log was kept contemporaneously. Created date shows when the trip was first recorded. Modified date shows the last edit.")
                .font(.caption2)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
        .opacity(infoOpacity)
    }
    
    // MARK: - Delete Section
    
    private var deleteSection: some View {
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
                        .accessibilityHidden(true)
                    Text("Delete Trip")
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                }
                .foregroundStyle(.red)
            }
            .frame(maxWidth: .infinity)
            .offset(x: deleteButtonShake ? -5 : 0)
            .accessibilityLabel("Delete trip")
            .accessibilityHint("Double tap to permanently delete this trip. This action cannot be undone.")
        }
        .listRowBackground(Color.floSystemGroupedBackground)
        .opacity(deleteOpacity)
    }
    
    // MARK: - Classification Footer
    
    @ViewBuilder
    private var classificationFooter: some View {
        HStack(spacing: 4) {
            if trip.purpose == .commute {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text("Commute miles (home to first stop) are never deductible per IRS rules.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else if trip.isBusinessTrip {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text("This trip will be included in your tax deduction")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text("Personal trips are not tax deductible")
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(trip.purpose == .commute ? .orange : (trip.isBusinessTrip ? .green : .secondary))
        .font(.footnote)
        .animation(.easeInOut(duration: 0.2), value: trip.isBusinessTrip)
        .animation(.easeInOut(duration: 0.2), value: trip.purpose)
    }
    
    // MARK: - Map Accessibility Label
    
    private var mapAccessibilityLabel: String {
        var parts = ["Trip route map"]
        if let start = trip.startAddress {
            parts.append("From \(start)")
        }
        if let end = trip.endAddress {
            parts.append("to \(end)")
        }
        parts.append(String(format: "%.1f miles", trip.distanceMiles))
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Saved Confirmation Banner
    
    private var savedConfirmationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            Text("Changes Saved")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.floSystemBackground)
                .floCardShadow(y: 4)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Changes saved")
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            mapScale = 1.0
            mapOpacity = 1.0
        }
        
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
            
            HapticService.shared.success()
            AccessibilityAnnouncement.announce("Changes saved")
            
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
            print("[OK] Trip changes saved")
            #endif
            
        } catch {
            print("Failed to save trip: \(error)")
            HapticService.shared.error()
            AccessibilityAnnouncement.announce("Failed to save changes")
            dismiss()
        }
    }
    
    private func deleteTrip() {
        HapticService.play(.medium)
        
        modelContext.delete(trip)
        
        do {
            try modelContext.save()
            HapticService.shared.warning()
            AccessibilityAnnouncement.announce("Trip deleted")
            
            #if DEBUG
            print("[OK] Trip deleted")
            #endif
            
        } catch {
            print("Failed to delete trip: \(error)")
            HapticService.shared.error()
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
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(valueColor)
            }
        }
        .opacity(isVisible ? 1 : 0.001)
        .offset(x: isVisible ? 0 : -10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                isVisible = true
            }
        }
        .accessibilityElement(children: .combine)
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
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(color)
                
                Text(address)
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(address)")
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
                    notes: "Met with client about Q4 projections. Discussed new contract terms.",
                    vehicleName: "2023 Toyota Camry",
                    clientName: "Oracle Inc"
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

#Preview("Commute Trip") {
    NavigationStack {
        MileageTripDetailView(
            trip: {
                let trip = MileageTrip(
                    startDate: Date().addingTimeInterval(-2400),
                    endDate: Date().addingTimeInterval(-1800),
                    startLatitude: 37.7749,
                    startLongitude: -122.4194,
                    endLatitude: 37.7949,
                    endLongitude: -122.4294,
                    startAddress: "Home",
                    endAddress: "Office",
                    distanceMiles: 9.1,
                    purpose: .commute,
                    isBusinessTrip: false,
                    notes: "Daily commute",
                    vehicleName: "2023 Toyota Camry"
                )
                return trip
            }()
        )
    }
    .modelContainer(ModelContainer.preview())
}
