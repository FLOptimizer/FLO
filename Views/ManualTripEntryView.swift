//  ManualTripEntryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - MapKit Integration with Address Autocomplete & Route Calculation
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  ENHANCEMENTS v3.0:
//  - Address autocomplete using MKLocalSearchCompleter
//  - Real geocoding to get actual coordinates
//  - Automatic driving distance calculation via MKDirections
//  - Mini route preview map
//  - Smart fallback to manual entry if geocoding fails
//  - Haptic feedback on interactions
//  - Animated field transitions
//

import SwiftUI
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
        guard let distance = parsedDistance, isBusinessTrip else { return 0 }
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
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                }
            } header: {
                Text("Date & Time")
            } footer: {
                let year = Calendar.current.component(.year, from: tripDate)
                Text("IRS rate for \(year): \(String(format: "%.1f¢", currentIRSRate * 100))/mile")
            }
            .opacity(formVisible ? 1 : 0)
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
                                Text("Calculating route...")
                            } else {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                Text("Calculate Driving Distance")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isCalculatingRoute || startAddress.isEmpty || endAddress.isEmpty)
                    .foregroundStyle(AppConstants.primaryColor)
                }
            } header: {
                Text("Locations")
            } footer: {
                if routeCalculationFailed {
                    Text("Could not calculate route. Please enter distance manually.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Start typing to see address suggestions. Tap to auto-fill.")
                }
            }
            .opacity(formVisible ? 1 : 0)
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
                    
                    HStack {
                        Label("Driving Distance", systemImage: "car.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f miles", route.distance / 1609.34))
                            .fontWeight(.semibold)
                            .foregroundStyle(AppConstants.primaryColor)
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Label("Est. Travel Time", systemImage: "clock.fill")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatTravelTime(route.expectedTravelTime))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // MARK: - Distance Section
            Section {
                HStack {
                    TextField("Distance", text: $distanceString)
                        .keyboardType(.decimalPad)
                        .offset(x: distanceFieldShake ? -5 : 0)
                    
                    Text("miles")
                        .foregroundStyle(.secondary)
                    
                    if isCalculatingRoute {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                
                // Real-time deduction estimate
                if let distance = parsedDistance, distance > 0 {
                    HStack {
                        Text("Estimated Deduction")
                            .foregroundStyle(.secondary)
                        Spacer()
                        
                        if isBusinessTrip {
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
                }
            } header: {
                Text("Distance")
            } footer: {
                if let distance = parsedDistance, distance > 100 {
                    Text("High mileage trips may be flagged during audit. Ensure accuracy.")
                        .foregroundStyle(.orange)
                } else if calculatedRoute != nil {
                    Text("Distance auto-calculated from route. You can adjust if needed.")
                        .foregroundStyle(.green)
                }
            }
            .opacity(formVisible ? 1 : 0)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.2), value: formVisible)
            
            // MARK: - Classification Section
            Section {
                Toggle("Business Trip", isOn: $isBusinessTrip)
                    .tint(AppConstants.primaryColor)
                    .onChange(of: isBusinessTrip) { _, newValue in

                        HapticService.play(.medium)
                        
                        if !newValue {
                            purpose = .personal
                        } else if purpose == .personal {
                            purpose = .other
                        }
                    }
                
                Picker("Purpose", selection: $purpose) {
                    ForEach(TripPurpose.allCases.filter { isBusinessTrip ? $0 != .personal : true }) { tripPurpose in
                        Label(tripPurpose.displayName, systemImage: tripPurpose.icon)
                            .tag(tripPurpose)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: purpose) { _, newValue in
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                    isBusinessTrip = (newValue != .personal)
                }
            } header: {
                Text("Classification")
            } footer: {
                if !isBusinessTrip {
                    Text("Personal trips are tracked but not tax deductible.")
                } else {
                    Text("Business trips are deductible at the IRS standard rate.")
                }
            }
            .opacity(formVisible ? 1 : 0)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.3), value: formVisible)
            
            // MARK: - Notes Section
            Section {
                TextEditor(text: $notes)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            } header: {
                Text("Notes (Optional)")
            } footer: {
                Text("Include client name, meeting purpose, or other details for your records.")
            }
            .opacity(formVisible ? 1 : 0)
            .offset(y: formVisible ? 0 : 10)
            .animation(.easeOut(duration: 0.3).delay(0.4), value: formVisible)
            
            // MARK: - Summary Section
            if isFormValid {
                Section("Summary") {
                    VStack(alignment: .leading, spacing: 8) {
                        SummaryRow(label: "Date", value: tripDate.formatted(date: .abbreviated, time: .shortened))
                        SummaryRow(label: "From", value: startAddress.trimmingCharacters(in: .whitespacesAndNewlines))
                        SummaryRow(label: "To", value: endAddress.trimmingCharacters(in: .whitespacesAndNewlines))
                        SummaryRow(label: "Distance", value: String(format: "%.1f miles", parsedDistance ?? 0))
                        SummaryRow(label: "Purpose", value: purpose.displayName)
                        
                        Divider()
                        
                        HStack {
                            Text("Tax Deduction")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "$%.2f", estimatedDeduction))
                                .fontWeight(.bold)
                                .foregroundStyle(isBusinessTrip ? .green : .secondary)
                        }
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
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveTrip()
                }
                .disabled(!isFormValid || isSaving)
                .fontWeight(isFormValid ? .semibold : .regular)
            }
        }
        .alert("Unable to Save", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isSaving {
                SavingOverlay()
            }
        }
        .interactiveDismissDisabled(isSaving)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                formVisible = true
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: calculatedRoute != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFormValid)
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
    
    // MARK: - Address Selection
    
    private func selectStartAddress(_ completion: MKLocalSearchCompletion) {

        HapticService.play(.medium)
        
        startAddress = "\(completion.title), \(completion.subtitle)"
        showStartSuggestions = false
        
        // Geocode the address
        geocodeAddress(completion) { coordinate in
            startCoordinate = coordinate
            tryCalculateRouteIfBothSet()
        }
    }
    
    private func selectEndAddress(_ completion: MKLocalSearchCompletion) {
        HapticService.play(.medium)
        
        endAddress = "\(completion.title), \(completion.subtitle)"
        showEndSuggestions = false
        
        // Geocode the address
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
            // Try geocoding first if we have addresses but no coordinates
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
        
        // Geocode start address
        geocoder.geocodeAddressString(startAddr) { startPlacemarks, startError in
            guard let startPlacemark = startPlacemarks?.first,
                  let startLocation = startPlacemark.location else {
                DispatchQueue.main.async {
                    self.isCalculatingRoute = false
                    self.routeCalculationFailed = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                }
                return
            }
            
            self.startCoordinate = startLocation.coordinate
            
            // Geocode end address
            let endGeocoder = CLGeocoder()
            endGeocoder.geocodeAddressString(endAddr) { endPlacemarks, endError in
                guard let endPlacemark = endPlacemarks?.first,
                      let endLocation = endPlacemark.location else {
                    DispatchQueue.main.async {
                        self.isCalculatingRoute = false
                        self.routeCalculationFailed = true
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                    }
                    return
                }
                
                self.endCoordinate = endLocation.coordinate
                
                // Now calculate route
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
                    
                    // Auto-fill distance (convert meters to miles)
                    let distanceMiles = route.distance / 1609.34
                    self.distanceString = String(format: "%.1f", distanceMiles)
                    
                    // Success haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } else {
                    self.routeCalculationFailed = true
                    
                    // Warning haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                }
            }
        }
    }
    
    // MARK: - Save Action
    
    private func saveTrip() {
        guard isFormValid, let distance = parsedDistance else {
            // Shake animation
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
        
        isSaving = true
        
        Task {
            do {
                try await MileageTrackingService.shared.saveManualTrip(
                    startDate: tripDate,
                    startLocation: start,
                    endLocation: end,
                    distanceMiles: distance,
                    purpose: purpose,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                )
                
                await MainActor.run {
                    isSaving = false
                    
                    // Success haptic
                    let successGenerator = UINotificationFeedbackGenerator()
                    successGenerator.notificationOccurred(.success)
                    
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showingError = true
                    
                    let errorGenerator = UINotificationFeedbackGenerator()
                    errorGenerator.notificationOccurred(.error)
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
                        // Clear coordinate when manually editing
                        coordinate = nil
                    }
                    .onChange(of: isFieldFocused) { _, focused in
                        showSuggestions = focused && !address.isEmpty
                    }
                
                if coordinate != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .transition(.scale.combined(with: .opacity))
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
                }
            }
            
            // Suggestions dropdown
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
                                
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
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
        print("🗺️ Address search error: \(error.localizedDescription)")
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
            // Route polyline
            MapPolyline(route.polyline)
                .stroke(AppConstants.primaryColor, lineWidth: 4)
            
            // Start marker
            Annotation("Start", coordinate: startCoordinate) {
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }
            
            // End marker
            Annotation("End", coordinate: endCoordinate) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                    Image(systemName: "mappin")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls { }
        .allowsHitTesting(false)
        .onAppear {
            // Set camera to show the entire route
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
        }
        .font(.subheadline)
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
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(16)
            .shadow(radius: 20)
        }
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
