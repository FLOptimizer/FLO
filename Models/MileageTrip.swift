//  MileageTrip.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.1 - UTF-8 Mojibake Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.1:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters
//
//  CHANGES v4.0:
//  - Audit-Defensible Mileage Logs
//
//  FEATURES:
//  - Full IRS compliance with historical rates
//  - Automatic rate assignment based on trip year
//  - Route point storage for trip visualization
//  - CSV export for tax filing
//  - Comprehensive computed properties
//  - Needs Review status for unclassified trips
//
//  CHANGES v4.0:
//  - Added vehicleName field for multi-vehicle households
//  - Added clientName field for CPA-readable structured records
//  - Added .commute case to TripPurpose for explicit commute flagging
//  - CSV export now includes createdDate, modifiedDate, vehicleName, clientName
//  - CSV header updated with audit trail columns
//  - Enhanced audit defensibility per IRS contemporaneous log requirements
//
//  CHANGES v3.2:
//  - Added .needsReview case to TripPurpose for unclassified auto-tracked trips
//  - Added potentialDeduction computed property
//  - deductionAmount returns 0 for needsReview trips
//
//  CHANGES v3.1:
//  - Added 2026 IRS rate: 72.5 cents per mile
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class MileageTrip {
    
    // MARK: - Identifiers
    private(set) var id: UUID = UUID()

    // MARK: - Dates
    var startDate: Date = Date()
    var endDate: Date = Date()
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()

    // MARK: - Location Coordinates
    var startLatitude: Double = 0.0
    var startLongitude: Double = 0.0
    var endLatitude: Double = 0.0
    var endLongitude: Double = 0.0
    
    // MARK: - Addresses
    var startAddress: String?
    var endAddress: String?
    
    // MARK: - Trip Details
    var distanceMiles: Double = 0.0
    var purpose: TripPurpose = TripPurpose.needsReview
    var isBusinessTrip: Bool = false
    var notes: String?
    
    // MARK: - Vehicle Tracking (v4.0)
    /// Vehicle name for multi-vehicle households (e.g. "2022 Honda Civic")
    var vehicleName: String?
    
    // MARK: - Client Tracking (v4.0)
    /// Structured client name for CPA-readable records
    var clientName: String?
    
    // MARK: - Entry Tracking
    var isManualEntry: Bool = false

    // MARK: - IRS Rate & Reimbursement
    var mileageRate: Double = 0.725
    
    // MARK: - Route Data (for visualization)
    var routePoints: [RoutePoint]?
    
    // MARK: - Finance Type
    var financeType: Transaction.FinanceType = Transaction.FinanceType.business
    
    // MARK: - Initialization
    
    init(
        startDate: Date = .now,
        endDate: Date = .now,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        startAddress: String? = nil,
        endAddress: String? = nil,
        distanceMiles: Double,
        purpose: TripPurpose,
        isBusinessTrip: Bool = true,
        notes: String? = nil,
        vehicleName: String? = nil,
        clientName: String? = nil,
        isManualEntry: Bool = false,
        routePoints: [RoutePoint]? = nil
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.createdDate = Date()
        self.modifiedDate = Date()
        
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        
        self.startAddress = startAddress
        self.endAddress = endAddress
        
        self.distanceMiles = max(distanceMiles, 0)
        self.purpose = purpose
        self.isBusinessTrip = isBusinessTrip
        self.notes = notes
        self.vehicleName = vehicleName
        self.clientName = clientName
        
        self.isManualEntry = isManualEntry
        self.routePoints = routePoints
        
        // Auto-assign IRS rate based on trip year
        let year = Calendar.current.component(.year, from: startDate)
        self.mileageRate = Self.irsRateForYear(year)
        
        // Mileage deductions are business type
        self.financeType = .business
    }
    
    // MARK: - IRS Rate History
    
    /// Returns the IRS standard mileage rate for business use in a given year
    static func irsRateForYear(_ year: Int) -> Double {
        switch year {
        case 2026...:
            return 0.725 // 72.5 cents per mile (2026)
        case 2025:
            return 0.70  // 70 cents per mile
        case 2024:
            return 0.67  // 67 cents per mile
        case 2023:
            return 0.655 // 65.5 cents per mile
        case 2022:
            return 0.625 // 62.5 cents per mile (July-Dec), using higher rate
        case 2021:
            return 0.56  // 56 cents per mile
        case 2020:
            return 0.575 // 57.5 cents per mile
        case 2019:
            return 0.58  // 58 cents per mile
        default:
            return 0.725 // Default to 2026 rate for future years
        }
    }
    
    // MARK: - Computed Properties
    
    /// Potential tax deduction if this were a business trip
    /// Always calculates based on IRS rate, regardless of classification
    /// Use this for notifications and "potential" displays
    var potentialDeduction: Double {
        distanceMiles * mileageRate
    }
    
    /// Actual tax deduction amount (0 for personal, commute, or unreviewed trips)
    /// Only counts for CONFIRMED business trips - not needsReview or commute
    var deductionAmount: Double {
        guard isBusinessTrip && purpose != .needsReview && purpose != .personal && purpose != .commute else {
            return 0
        }
        return distanceMiles * mileageRate
    }
    
    /// Whether this trip needs user review/classification
    var needsClassification: Bool {
        purpose == .needsReview
    }
    
    /// Whether this trip is a commute (non-deductible even if marked business)
    var isCommute: Bool {
        purpose == .commute
    }
    
    /// Start location as CLLocationCoordinate2D
    var startLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    
    /// End location as CLLocationCoordinate2D
    var endLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }
    
    /// Trip duration in seconds
    var durationSeconds: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    /// Human-readable duration
    var durationFormatted: String {
        let minutes = max(1, Int(durationSeconds / 60))
        
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
    
    /// Full trip summary (start -> end)
    var displaySummary: String {
        "\(startAddress ?? "Unknown") \u{2192} \(endAddress ?? "Unknown")"
    }
    
    /// Abbreviated start address (first component only)
    var abbreviatedStartAddress: String {
        guard let address = startAddress else { return "Unknown" }
        let components = address.split(separator: ",")
        return components.first.map(String.init) ?? address
    }
    
    /// Abbreviated end address (first component only)
    var abbreviatedEndAddress: String {
        guard let address = endAddress else { return "Unknown" }
        let components = address.split(separator: ",")
        return components.first.map(String.init) ?? address
    }
    
    /// Trip year for grouping/filtering
    var tripYear: Int {
        Calendar.current.component(.year, from: startDate)
    }
    
    /// Trip month for grouping/filtering
    var tripMonth: Int {
        Calendar.current.component(.month, from: startDate)
    }
    
    // MARK: - Classification Methods
    
    /// Classify this trip as business with a specific purpose
    func classifyAsBusiness(purpose: TripPurpose, notes: String? = nil) {
        guard purpose != .personal && purpose != .needsReview && purpose != .commute else {
            return
        }
        self.purpose = purpose
        self.isBusinessTrip = true
        if let notes = notes {
            self.notes = notes
        }
        self.touch()
    }
    
    /// Classify this trip as personal (non-deductible)
    func classifyAsPersonal(notes: String? = nil) {
        self.purpose = .personal
        self.isBusinessTrip = false
        if let notes = notes {
            self.notes = notes
        }
        self.touch()
    }
    
    /// Classify this trip as a commute (non-deductible)
    func classifyAsCommute(notes: String? = nil) {
        self.purpose = .commute
        self.isBusinessTrip = false
        if let notes = notes {
            self.notes = notes
        }
        self.touch()
    }
    
    // MARK: - Date Range Filtering
    
    func isInRange(from start: Date, to end: Date) -> Bool {
        startDate >= start && startDate <= end
    }
    
    func isInMonth(_ month: Int, year: Int) -> Bool {
        tripMonth == month && tripYear == year
    }
    
    func isInYear(_ year: Int) -> Bool {
        tripYear == year
    }
    
    // MARK: - CSV Export (v4.0 - Audit-Defensible)
    
    /// Escapes a string for CSV output
    private static func csvEscape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuotes {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    /// Generates a single CSV row for this trip
    /// v4.0: Now includes createdDate, modifiedDate, vehicleName, clientName for audit defense
    func toCSVRow() -> String {
        let date = DateFormatter.isoDate.string(from: startDate)

        let startTime = DateFormatter.time.string(from: startDate)
        let endTime = DateFormatter.time.string(from: endDate)

        let created = DateFormatter.isoDateTime.string(from: createdDate)
        let modified = DateFormatter.isoDateTime.string(from: modifiedDate)
        
        // For CSV, show review status clearly
        let businessStatus: String
        if purpose == .needsReview {
            businessStatus = "Needs Review"
        } else if purpose == .commute {
            businessStatus = "Commute"
        } else if isBusinessTrip {
            businessStatus = "Yes"
        } else {
            businessStatus = "No"
        }
        
        return [
            Self.csvEscape(date),
            Self.csvEscape(startAddress ?? "Unknown"),
            Self.csvEscape(endAddress ?? "Unknown"),
            Self.csvEscape(purpose.displayName),
            Self.csvEscape(clientName ?? ""),
            String(format: "%.2f", distanceMiles),
            businessStatus,
            Self.csvEscape(vehicleName ?? ""),
            Self.csvEscape(notes ?? ""),
            startTime,
            endTime,
            String(format: "%.3f", mileageRate),
            String(format: "%.2f", deductionAmount),
            Self.csvEscape(created),
            Self.csvEscape(modified),
            isManualEntry ? "Manual" : "Auto-Tracked"
        ].joined(separator: ",")
    }
    
    /// CSV header row
    /// v4.0: Added Client, Vehicle, Created, Modified, Entry Type columns
    static var csvHeader: String {
        "Date,Start Location,End Location,Purpose,Client,Miles,Business,Vehicle,Notes,Start Time,End Time,IRS Rate,Deduction,Created,Modified,Entry Type"
    }
    
    // MARK: - Update Modified Date
    
    func touch() {
        modifiedDate = Date()
    }
}

// MARK: - Protocol Conformances

extension MileageTrip: Identifiable { }

extension MileageTrip: Equatable {
    static func == (lhs: MileageTrip, rhs: MileageTrip) -> Bool {
        lhs.id == rhs.id
    }
}

extension MileageTrip: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - RoutePoint

/// A single point along a trip's route for visualization
struct RoutePoint: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let speed: Double? // meters per second, nil if unknown
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(latitude: Double, longitude: Double, timestamp: Date = Date(), speed: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.speed = speed
    }
    
    init(location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.timestamp = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : nil
    }
}

// MARK: - TripPurpose

/// IRS-compliant trip purpose categories
enum TripPurpose: String, Codable, CaseIterable, Identifiable {
    case needsReview = "needsReview"        // Unclassified auto-tracked trip
    case clientVisit = "clientVisit"
    case clientMeeting = "clientMeeting"
    case businessMeeting = "businessMeeting"
    case suppliesPickup = "suppliesPickup"
    case deliveryDropoff = "deliveryDropoff"
    case bankingErrand = "bankingErrand"
    case other = "other"
    case commute = "commute"                // v4.0: Explicit commute (non-deductible)
    case personal = "personal"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .needsReview: return "Needs Review"
        case .clientVisit: return "Client Visit"
        case .clientMeeting: return "Client Meeting"
        case .businessMeeting: return "Business Meeting"
        case .suppliesPickup: return "Supplies/Equipment"
        case .deliveryDropoff: return "Delivery/Dropoff"
        case .bankingErrand: return "Banking/Business Errand"
        case .other: return "Other Business"
        case .commute: return "Commute (Non-Deductible)"
        case .personal: return "Personal (Non-Deductible)"
        }
    }
    
    var icon: String {
        switch self {
        case .needsReview: return "questionmark.circle.fill"
        case .clientVisit: return "person.2.fill"
        case .clientMeeting: return "person.crop.circle.badge.checkmark"
        case .businessMeeting: return "briefcase.fill"
        case .suppliesPickup: return "shippingbox.fill"
        case .deliveryDropoff: return "shippingbox.and.arrow.backward"
        case .bankingErrand: return "building.columns.fill"
        case .other: return "ellipsis.circle.fill"
        case .commute: return "house.and.flag.fill"
        case .personal: return "house.fill"
        }
    }
    
    /// Whether this purpose is tax deductible
    /// NOTE: needsReview and commute are NOT deductible
    var isDeductible: Bool {
        switch self {
        case .needsReview, .personal, .commute:
            return false
        default:
            return true
        }
    }
    
    /// Business purposes only (excludes personal, commute, and needsReview)
    /// Use this for purpose picker when classifying trips
    static var businessPurposes: [TripPurpose] {
        allCases.filter { $0.isDeductible }
    }
    
    /// All selectable purposes for manual classification (excludes needsReview)
    static var selectablePurposes: [TripPurpose] {
        allCases.filter { $0 != .needsReview }
    }
    
    /// Purposes that need user attention
    static var reviewRequired: [TripPurpose] {
        [.needsReview]
    }
}

// MARK: - Preview Support

#if DEBUG
extension MileageTrip {
    @MainActor static var previewClientVisit: MileageTrip {
        MileageTrip(
            startDate: Date.now.addingTimeInterval(-3600),
            endDate: Date.now,
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.8044,
            endLongitude: -122.2712,
            startAddress: "123 Main St, San Francisco, CA",
            endAddress: "456 Oak Ave, Oakland, CA",
            distanceMiles: 24.5,
            purpose: .clientVisit,
            isBusinessTrip: true,
            notes: "Q4 strategy meeting with Acme Corp",
            vehicleName: "2023 Toyota Camry",
            clientName: "Acme Corp"
        )
    }
    
    @MainActor static var previewSuppliesRun: MileageTrip {
        MileageTrip(
            startDate: Date.now.addingTimeInterval(-1800),
            endDate: Date.now.addingTimeInterval(-900),
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.7849,
            endLongitude: -122.4094,
            startAddress: "Home Office",
            endAddress: "Staples, Market St",
            distanceMiles: 8.3,
            purpose: .suppliesPickup,
            isBusinessTrip: true,
            notes: "Office supplies for new project",
            vehicleName: "2023 Toyota Camry"
        )
    }
    
    @MainActor static var previewPersonalTrip: MileageTrip {
        MileageTrip(
            startDate: Date.now.addingTimeInterval(-7200),
            endDate: Date.now.addingTimeInterval(-6000),
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.7949,
            endLongitude: -122.4394,
            startAddress: "Home",
            endAddress: "Grocery Store",
            distanceMiles: 5.2,
            purpose: .personal,
            isBusinessTrip: false,
            notes: nil
        )
    }
    
    @MainActor static var previewNeedsReview: MileageTrip {
        MileageTrip(
            startDate: Date.now.addingTimeInterval(-1200),
            endDate: Date.now.addingTimeInterval(-300),
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.7649,
            endLongitude: -122.4294,
            startAddress: "Home",
            endAddress: "Downtown",
            distanceMiles: 12.3,
            purpose: .needsReview,
            isBusinessTrip: false,
            notes: nil
        )
    }
    
    @MainActor static var previewCommute: MileageTrip {
        MileageTrip(
            startDate: Date.now.addingTimeInterval(-2400),
            endDate: Date.now.addingTimeInterval(-1800),
            startLatitude: 37.7749,
            startLongitude: -122.4194,
            endLatitude: 37.7949,
            endLongitude: -122.4294,
            startAddress: "Home",
            endAddress: "Office",
            distanceMiles: 9.1,
            purpose: .commute,
            isBusinessTrip: false,
            notes: "Daily commute"
        )
    }
}
#endif
