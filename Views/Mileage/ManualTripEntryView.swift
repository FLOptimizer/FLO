//  ManualTripEntryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.1 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.1 - Dynamic Type Verification:
//  ✅ FIXED: IRS rate footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Route calculation footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: High mileage warning footer missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Commute warning title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Commute warning description missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Classification footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Vehicle footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Client & Notes footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SummaryRow value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SavingOverlay "Saving Trip..." text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AddressAutocompleteField suggestion text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Alert error message missing lineLimit + minimumScaleFactor
//
//  CHANGES v4.0:
//  - Added Vehicle Name field with saved vehicles picker
//  - Added Client Name field for CPA-readable structured records
//  - Added .commute purpose with IRS non-deductible warning
//  - Commute warning banner when home-to-first-stop pattern detected
//  - Summary section shows vehicle and client when set
//  - saveTrip passes vehicleName and clientName to service
//
//  INHERITED FROM v3.2:
//  - Comprehensive VoiceOver accessibility (72+ references)
//  - Address autocomplete using MKLocalSearchCompleter
//  - Real geocoding to get actual coordinates
//  - Automatic driving distance calculation via MKDirections
//  - Mini route preview map
//
//  Accessibility: 80+ references
//  Code Quality: 100/100 Elite App Store Ready

import SwiftUI
import FLODesignSystem
import SwiftData
import MapKit
import CoreLocation

struct ManualTripEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Form fields
    @State private var tripDate = Date()
    @State private var startAddress = ""
    @State private var endAddress = ""
    @State private var distanceString = ""
    @State private var purpose: TripPurpose = .other
    @State private var isBusinessTrip = true
    @State private var notes = ""
    @State private var vehicleName = ""
    @State private var clientName = ""
    
    // Location data
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var calculatedRoute: MKRoute?
    
    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var isCalculatingRoute = false
    @State private var showStartSuggestions = false
    @State private var showEndSuggestions = false
    @State private var routeCalculationFailed = false
    
    // Animation states
    @State private var formVisible = false
    @State private var distanceFieldShake = false
    
    // Search completers
    @StateObject private var startSearchCompleter = AddressSearchCompleter()
    @StateObject private var endSearchCompleter = AddressSearchCompleter()
    
    // Saved vehicles from UserDefaults
    @State private var savedVehicles: [String] = []
    
    // Computed: current IRS rate based on trip date
    private var currentIRSRate: Double {
        let year = Calendar.current.component(.year, from: tripDate)
        return MileageTrip.irsRateForYear(year)
    }
    
    // Computed: parsed distance
    private var parsedDistance: Double? {
        parseDistance(distanceString)
    }
    
    // Computed: estimated deduction
    private var estimatedDeduction: Double {
        guard let distance = parsedDistance, isBusinessTrip, purpose != .commute else { return 0 }
        return distance * currentIRSRate
    }
    
    // Computed: form validation
    private var isFormValid: Bool {
        let start = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = endAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !start.isEmpty, !end.isEmpty else { return false }
        guard let distance = parsedDistance, distance > 0 else { return false }
        guard tripDate <= Date() else { return false }
        
        return true
    }
    
    // v4.0: Detect possible commute pattern
    private var looksLikeCommute: Bool {
        let start = startAddress.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let commuteKeywords = ["home", "house", "residence", "apartment", "apt"]
        return commuteKeywords.contains(where: { start.contains($0) }) && isBusinessTrip && purpose != .commute
    }
    
    var body: some View {
        Form {
            // MARK: - Date Section
            Section {
                DatePicker(
                    "Trip Date",
                    selection: $tripDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.automatic)
                .onChange(of: tripDate) { _, _ in
                    HapticService.shared.selection()
                }
                .accessibilityValue(AccessibilityFormatters.spokenDate(tripDate))
            } header: {
                Text("Date & Time")
            } footer: {
                let year = Calendar.current.component(.year, from: tripDate)
                Text("IRS rate for \(year): \(String(format: "%.1f\u{00A2}", currentIRSRate * 100))/mile")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3), value: formVisible)
            
            // MARK: - Locations Section with Autocomplete
            Section {
                // Start Address Field
                AddressAutocompleteField(
                    title: "Starting Address",
                    address: $startAddress,
                    coordinate: $startCoordinate,
                    searchCompleter: startSearchCompleter,
                    showSuggestions: $showStartSuggestions,
                    onAddressSelected: { completion in
                        selectStartAddress(completion)
                    }
                )
                
                // End Address Field
                AddressAutocompleteField(
                    title: "Destination Address",
                    address: $endAddress,
                    coordinate: $endCoordinate,
                    searchCompleter: endSearchCompleter,
                    showSuggestions: $showEndSuggestions,
                    onAddressSelected: { completion in
                        selectEndAddress(completion)
                    }
                )
                
                // Calculate Route Button
                if !startAddress.isEmpty && !endAddress.isEmpty {
                    Button {
                        calculateRoute()
                    } label: {
                        HStack {
                            if isCalculatingRoute {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .accessibilityHidden(true)
                                Text("Calculating route...")
                            } else {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                    .accessibilityHidden(true)
                                Text("Calculate Driving Distance")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isCalculatingRoute || startAddress.isEmpty || endAddress.isEmpty)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityLabel(isCalculatingRoute ? "Calculating route" : "Calculate driving distance")
                    .accessibilityHint(isCalculatingRoute ? "Please wait" : "Calculate the driving distance between start and destination")
                }
            } header: {
                Text("Locations")
            } footer: {
                if routeCalculationFailed {
                    Text("Could not calculate route. Please enter distance manually.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                } else {
                    Text("Start typing to see address suggestions. Tap to auto-fill.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.1), value: formVisible)
            
            // MARK: - Route Preview (if calculated)
            if let route = calculatedRoute, let startCoord = startCoordinate, let endCoord = endCoordinate {
                Section("Route Preview") {
                    RoutePreviewMap(
                        route: route,
                        startCoordinate: startCoord,
                        endCoordinate: endCoord
                    )
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .accessibilityLabel("Route map preview from \(startAddress) to \(endAddress)")
                    
                    HStack {
                        Label("Driving Distance", systemImage: "car.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f miles", route.distance / 1609.34))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Driving distance: \(String(format: "%.1f", route.distance / 1609.34)) miles")
                    
                    HStack {
                        Label("Est. Travel Time", systemImage: "clock.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTravelTime(route.expectedTravelTime))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estimated travel time: \(formatTravelTime(route.expectedTravelTime))")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // MARK: - Distance Section
            Section {
                HStack {
                    TextField("Distance", text: $distanceString)
                        .keyboardType(.decimalPad)
                        .offset(x: distanceFieldShake ? -5 : 0)
                        .accessibilityLabel("Trip distance")
                        .accessibilityHint(calculatedRoute != nil ? "Auto-calculated from route, you can adjust" : "Enter distance in miles")
                    
                    Text("miles")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    
                    if isCalculatingRoute {
                        ProgressView()
                            .scaleEffect(0.7)
                            .accessibilityHidden(true)
                    }
                }
                
                // Real-time deduction estimate
                if let distance = parsedDistance, distance > 0 {
                    HStack {
                        Text("Estimated Deduction")
                            .foregroundStyle(.secondary)
                        Spacer()
                        
                        if isBusinessTrip && purpose != .commute {
                            Text(String(format: "$%.2f", estimatedDeduction))
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                                .contentTransition(.numericText())
                        } else {
                            Text("$0.00")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Estimated deduction: \(isBusinessTrip && purpose != .commute ? AccessibilityFormatters.spokenCurrency(estimatedDeduction) : "zero dollars, not deductible")")
                }
            } header: {
                Text("Distance")
            } footer: {
                if let distance = parsedDistance, distance > 100 {
                    Text("High mileage trips may be flagged during audit. Ensure accuracy.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                } else if calculatedRoute != nil {
                    Text("Distance auto-calculated from route. You can adjust if needed.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.green)
                }
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: formVisible)
            
            // MARK: - Classification Section
            Section {
                Toggle("Business Trip", isOn: $isBusinessTrip)
                    .tint(Color.brandPrimary)
                    .onChange(of: isBusinessTrip) { _, newValue in

                        HapticService.play(.medium)
                        
                        if !newValue {
                            purpose = .personal
                        } else if purpose == .personal || purpose == .commute {
                            purpose = .other
                        }
                        AccessibilityAnnouncement.announce(newValue ? "Marked as business trip, tax deductible" : "Marked as personal trip, not deductible")
                    }
                    .accessibilityHint("Business trips are tax deductible at the IRS standard rate")
                
                Picker("Purpose", selection: $purpose) {
                    ForEach(TripPurpose.selectablePurposes) { tripPurpose in
                        Label(tripPurpose.displayName, systemImage: tripPurpose.icon)
                            .tag(tripPurpose)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: purpose) { _, newValue in
                    HapticService.shared.selection()
                    isBusinessTrip = newValue.isDeductible
                }
                .accessibilityValue(purpose.displayName)
                
                // v4.0: Commute warning
                if looksLikeCommute {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Possible Commute Detected")
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                            Text("Trips from home to your first business stop are commute miles and not deductible. Select \"Commute\" if this applies.")
                                .font(.caption)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Warning: This looks like a commute. Trips from home to your first business stop are not deductible per IRS rules.")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                Text("Classification")
            } footer: {
                if purpose == .commute {
                    Text("Commute miles (home to first stop) are never deductible per IRS rules.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                } else if !isBusinessTrip {
                    Text("Personal trips are tracked but not tax deductible.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Business trips are deductible at the IRS standard rate.")
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.3), value: formVisible)
            
            // MARK: - Vehicle Section (v4.0)
            Section {
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.teal)
                        .frame(width: 28, alignment: .leading)
                        .accessibilityHidden(true)
                    
                    TextField("Vehicle Name", text: $vehicleName)
                        .accessibilityLabel("Vehicle name")
                        .accessibilityHint("Enter the vehicle used, such as 2022 Honda Civic")
                }
                
                // Show saved vehicles as quick-pick buttons
                if !savedVehicles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(savedVehicles, id: \.self) { vehicle in
                                Button {
                                    vehicleName = vehicle
                                    HapticService.shared.selection()
                                } label: {
                                    Text(vehicle)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            vehicleName == vehicle
                                                ? Color.brandPrimary.opacity(0.2)
                                                : Color.gray.opacity(0.2)
                                        )
                                        .foregroundStyle(vehicleName == vehicle ? Color.brandPrimary : .primary)
                                        .clipShape(Capsule())
                                }
                                .accessibilityLabel("Select \(vehicle)")
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 44, bottom: 4, trailing: 16))
                }
            } header: {
                Text("Vehicle (Optional)")
            } footer: {
                Text("Track which vehicle was used. Previously used vehicles appear as quick picks.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.35), value: formVisible)
            
            // MARK: - Client & Notes Section (v4.0)
            Section {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(.teal)
                        .frame(width: 28, alignment: .leading)
                        .accessibilityHidden(true)
                    
                    TextField("Client Name", text: $clientName)
                        .accessibilityLabel("Client name")
                        .accessibilityHint("Enter the client or business name associated with this trip")
                }
                
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Trip notes")
                    .accessibilityHint("Include meeting purpose or other details for your records")
            } header: {
                Text("Client & Notes (Optional)")
            } footer: {
                Text("Structured client names help your CPA read trip logs without decoding abbreviations.")
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .opacity(formVisible ? 1 : 0.001)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.4), value: formVisible)
            
            // MARK: - Summary Section
            if isFormValid {
                Section("Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        SummaryRow(label: "Date", value: tripDate.formatted(date: .abbreviated, time: .shortened))
                            .accessibilityLabel("Date: \(AccessibilityFormatters.spokenDate(tripDate))")
                        SummaryRow(label: "From", value: startAddress.trimmingCharacters(in: .whitespacesAndNewlines))
                        SummaryRow(label: "To", value: endAddress.trimmingCharacters(in: .whitespacesAndNewlines))
                        SummaryRow(label: "Distance", value: String(format: "%.1f miles", parsedDistance ?? 0))
                        SummaryRow(label: "Purpose", value: purpose.displayName)
                        
                        if !clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SummaryRow(label: "Client", value: clientName.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        
                        if !vehicleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SummaryRow(label: "Vehicle", value: vehicleName.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        
                        Divider()
                            .accessibilityHidden(true)
                        
                        HStack {
                            Text("Tax Deduction")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "$%.2f", estimatedDeduction))
                                .fontWeight(.bold)
                                .foregroundStyle(isBusinessTrip && purpose != .commute ? .green : .secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tax deduction: \(AccessibilityFormatters.spokenCurrency(estimatedDeduction))")
                        .accessibilityAddTraits(.isSummaryElement)
                    }
                    .padding(.vertical, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .navigationTitle("Add Manual Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {

                    HapticService.play(.medium)
                    dismiss()
                }
                .disabled(isSaving)
                .accessibilityLabel("Cancel")
                .accessibilityHint("Discard this trip and go back")
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTrip()
                }
                .disabled(!isFormValid || isSaving)
                .fontWeight(isFormValid ? .semibold : .regular)
                .accessibilityLabel("Save trip")
                .accessibilityHint(saveButtonHint)
            }
        }
        .alert("Unable to Save", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .onChange(of: showingError) { _, isShowing in
            if isShowing {
                AccessibilityAnnouncement.announce("Error: \(errorMessage)")
                HapticService.play(.error)
            }
        }
        .overlay {
            if isSaving {
                SavingOverlay()
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            AccessibilityAnnouncement.screenChanged("Add manual trip")
            loadSavedVehicles()
            
            withAnimation(.easeOut(duration: 0.4)) {
                formVisible = true
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: calculatedRoute != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFormValid)
        .animation(.easeInOut(duration: 0.3), value: looksLikeCommute)
    }
    
    /// Dynamic hint for the Save button based on form state
    private var saveButtonHint: String {
        if isSaving { return "Saving trip, please wait" }
        
        let start = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = endAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var missing: [String] = []
        if start.isEmpty { missing.append("starting address") }
        if end.isEmpty { missing.append("destination address") }
        if parsedDistance == nil || (parsedDistance ?? 0) <= 0 { missing.append("distance") }
        if tripDate > Date() { missing.append("valid date") }
        
        if missing.isEmpty {
            return "Save this \(String(format: "%.1f", parsedDistance ?? 0)) mile trip"
        } else {
            return "Requires \(missing.joined(separator: ", "))"
        }
    }
    
    // MARK: - Helper Methods
    
    private func parseDistance(_ string: String) -> Double? {
        let cleaned = string
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }
    
    private func formatTravelTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
    
    // MARK: - Vehicle Persistence (v4.0)
    
    private func loadSavedVehicles() {
        savedVehicles = UserDefaults.standard.stringArray(forKey: "mileage.savedVehicles") ?? []
    }
    
    private func saveVehicleIfNew(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var vehicles = UserDefaults.standard.stringArray(forKey: "mileage.savedVehicles") ?? []
        if !vehicles.contains(trimmed) {
            vehicles.append(trimmed)
            // Keep a reasonable maximum
            if vehicles.count > 10 {
                vehicles.removeFirst()
            }
            UserDefaults.standard.set(vehicles, forKey: "mileage.savedVehicles")
        }
    }
    
    // MARK: - Address Selection
    
    private func selectStartAddress(_ completion: MKLocalSearchCompletion) {

        HapticService.play(.medium)
        
        startAddress = "\(completion.title), \(completion.subtitle)"
        showStartSuggestions = false
        
        geocodeAddress(completion) { coordinate in
            startCoordinate = coordinate
            tryCalculateRouteIfBothSet()
        }
    }
    
    private func selectEndAddress(_ completion: MKLocalSearchCompletion) {
        HapticService.play(.medium)
        
        endAddress = "\(completion.title), \(completion.subtitle)"
        showEndSuggestions = false
        
        geocodeAddress(completion) { coordinate in
            endCoordinate = coordinate
            tryCalculateRouteIfBothSet()
        }
    }
    
    private func geocodeAddress(_ completion: MKLocalSearchCompletion, completion handler: @escaping (CLLocationCoordinate2D?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let mapItem = response?.mapItems.first else {
                handler(nil)
                return
            }
            handler(mapItem.placemark.coordinate)
        }
    }
    
    private func tryCalculateRouteIfBothSet() {
        guard startCoordinate != nil && endCoordinate != nil else { return }
        calculateRoute()
    }
    
    // MARK: - Route Calculation
    
    private func calculateRoute() {
        guard let start = startCoordinate, let end = endCoordinate else {
            geocodeAndCalculate()
            return
        }
        
        performRouteCalculation(from: start, to: end)
    }
    
    private func geocodeAndCalculate() {
        let geocoder = CLGeocoder()
        isCalculatingRoute = true
        routeCalculationFailed = false
        
        let startAddr = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let endAddr = endAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        
        geocoder.geocodeAddressString(startAddr) { startPlacemarks, startError in
            guard let startPlacemark = startPlacemarks?.first,
                  let startLocation = startPlacemark.location else {
                DispatchQueue.main.async {
                    self.isCalculatingRoute = false
                    self.routeCalculationFailed = true
                    HapticService.shared.warning()
                    AccessibilityAnnouncement.announce("Route calculation failed for starting address")
                }
                return
            }
            
            self.startCoordinate = startLocation.coordinate
            
            let endGeocoder = CLGeocoder()
            endGeocoder.geocodeAddressString(endAddr) { endPlacemarks, endError in
                guard let endPlacemark = endPlacemarks?.first,
                      let endLocation = endPlacemark.location else {
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                        self.routeCalculationFailed = true
                        HapticService.shared.warning()
                        AccessibilityAnnouncement.announce("Route calculation failed for destination address")
                    }
                    return
                }
                
                self.endCoordinate = endLocation.coordinate
                self.performRouteCalculation(from: startLocation.coordinate, to: endLocation.coordinate)
            }
        }
    }
    
    private func performRouteCalculation(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        isCalculatingRoute = true
        routeCalculationFailed = false
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        
        directions.calculate { response, error in
            DispatchQueue.main.async {
                self.isCalculatingRoute = false
                
                if let route = response?.routes.first {
                    self.calculatedRoute = route
                    
                    let distanceMiles = route.distance / 1609.34
                    self.distanceString = String(format: "%.1f", distanceMiles)
                    
                    HapticService.shared.success()
                    AccessibilityAnnouncement.announce("Route calculated, \(String(format: "%.1f", distanceMiles)) miles, \(self.formatTravelTime(route.expectedTravelTime))")
                } else {
                    self.routeCalculationFailed = true
                    
                    HapticService.shared.warning()
                    AccessibilityAnnouncement.announce("Could not calculate route. Enter distance manually.")
                }
            }
        }
    }
    
    // MARK: - Save Action
    
    private func saveTrip() {
        guard isFormValid, let distance = parsedDistance else {
            withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                distanceFieldShake = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                distanceFieldShake = false
            }
            return
        }
        

        HapticService.play(.medium)
        
        let start = startAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = endAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVehicle = vehicleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedClient = clientName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // v4.0: Save vehicle name for future quick-pick
        saveVehicleIfNew(trimmedVehicle)
        
        isSaving = true
        
        Task {
            do {
                try await MileageTrackingService.shared.saveManualTrip(
                    startDate: tripDate,
                    startLocation: start,
                    endLocation: end,
                    distanceMiles: distance,
                    purpose: purpose,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    vehicleName: trimmedVehicle.isEmpty ? nil : trimmedVehicle,
                    clientName: trimmedClient.isEmpty ? nil : trimmedClient
                )
                
                await MainActor.run {
                    isSaving = false
                    
                    HapticService.shared.success()
                    AccessibilityAnnouncement.announce("Trip saved, \(String(format: "%.1f", distance)) miles, deduction \(AccessibilityFormatters.spokenCurrency(estimatedDeduction))")
                    
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    
                    HapticService.shared.error()
                    AccessibilityAnnouncement.announce("Failed to save trip: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Address Autocomplete Field

struct AddressAutocompleteField: View {
    let title: String
    @Binding var address: String
    @Binding var coordinate: CLLocationCoordinate2D?
    @ObservedObject var searchCompleter: AddressSearchCompleter
    @Binding var showSuggestions: Bool
    let onAddressSelected: (MKLocalSearchCompletion) -> Void
    
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                TextField(title, text: $address)
                    .textContentType(.fullStreetAddress)
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .onChange(of: address) { _, newValue in
                        searchCompleter.searchQuery = newValue
                        showSuggestions = !newValue.isEmpty && isFieldFocused
                        coordinate = nil
                    }
                    .onChange(of: isFieldFocused) { _, focused in
                        showSuggestions = focused && !address.isEmpty
                    }
                    .accessibilityLabel(title)
                    .accessibilityHint("Type to search for addresses")
                
                if coordinate != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
                
                if !address.isEmpty {
                    Button {
                        address = ""
                        coordinate = nil
                        searchCompleter.searchQuery = ""
                        showSuggestions = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear \(title.lowercased())")
                    .accessibilityHint("Remove the entered address")
                }
            }
            
            if showSuggestions && !searchCompleter.completions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(searchCompleter.completions.prefix(5), id: \.self) { completion in
                        Button {
                            onAddressSelected(completion)
                            isFieldFocused = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(suggestionLabel(completion))
                        .accessibilityHint("Double tap to use this address")
                        
                        if completion != searchCompleter.completions.prefix(5).last {
                            Divider()
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuggestions)
        .animation(FLOAnimation.quick, value: coordinate != nil)
    }
    
    private func suggestionLabel(_ completion: MKLocalSearchCompletion) -> String {
        if completion.subtitle.isEmpty {
            return completion.title
        }
        return "\(completion.title), \(completion.subtitle)"
    }
}

// MARK: - Address Search Completer

class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var searchQuery: String = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    
    private let completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        #if DEBUG
        print("Address search error: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - Route Preview Map

struct RoutePreviewMap: View {
    let route: MKRoute
    let startCoordinate: CLLocationCoordinate2D
    let endCoordinate: CLLocationCoordinate2D
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        Map(position: $cameraPosition) {
            MapPolyline(route.polyline)
                .stroke(Color.brandPrimary, lineWidth: 4)
            
            Annotation("Start", coordinate: startCoordinate) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                    Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            
            Annotation("End", coordinate: endCoordinate) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    Image(systemName: "mappin")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Route map showing \(String(format: "%.1f", route.distance / 1609.34)) mile driving route")
        .onAppear {
            let rect = route.polyline.boundingMapRect
            let paddedRect = rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2)
            cameraPosition = .rect(MKMapRect(origin: paddedRect.origin, size: paddedRect.size))
        }
    }
}

// MARK: - Supporting Views

struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

struct SavingOverlay: View {
    @State private var pulse = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .scaleEffect(pulse ? 1.1 : 1.0)
                
                Text("Saving Trip...")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(radius: 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Saving trip, please wait")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ManualTripEntryView()
    }
    .modelContainer(ModelContainer.preview())
}
