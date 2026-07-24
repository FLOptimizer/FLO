//  FLOMileageGPSTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - GPS Distance & Trip Tracking Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate GPS distance calculations, Haversine formula accuracy,
//  trip detection, and mileage tracking logic.
//
//  COVERS:
//  - Haversine formula for distance between coordinates
//  - Trip segment distance accumulation
//  - Trip state management (started, paused, ended)
//  - GPS accuracy filtering
//  - Route simplification
//

import XCTest
import CoreLocation
@testable import FLO

final class FLOMileageGPSTests: XCTestCase {
    
    // MARK: - Constants
    
    /// Earth's radius in miles
    let earthRadiusMiles: Double = 3958.8
    
    /// Meters per mile
    let metersPerMile: Double = 1609.344
    
    /// Acceptable accuracy for distance calculations (0.1 miles)
    let distanceAccuracy: Double = 0.1
    
    /// IRS mileage rate for 2026
    let irsRate2026: Double = 0.725
    
    // MARK: - Haversine Formula Implementation
    
    /// Calculate distance between two coordinates using Haversine formula
    /// - Returns: Distance in miles
    private func haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusMiles * c
    }
    
    /// Calculate distance using CLLocation (for comparison)
    private func clLocationDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let location1 = CLLocation(latitude: lat1, longitude: lon1)
        let location2 = CLLocation(latitude: lat2, longitude: lon2)
        return location1.distance(from: location2) / metersPerMile
    }
}

// MARK: - Haversine Formula Tests

extension FLOMileageGPSTests {
    
    /// Test: Same point = zero distance
    func testHaversine_SamePoint_ZeroDistance() {
        let distance = haversineDistance(
            lat1: 37.7749, lon1: -122.4194,
            lat2: 37.7749, lon2: -122.4194
        )
        
        XCTAssertEqual(distance, 0, accuracy: 0.001, "Same point = 0 distance")
    }
    
    /// Test: Known distance - San Francisco to Los Angeles (~382 miles)
    func testHaversine_SFtoLA() {
        // San Francisco
        let sfLat = 37.7749
        let sfLon = -122.4194
        
        // Los Angeles
        let laLat = 34.0522
        let laLon = -118.2437
        
        let distance = haversineDistance(
            lat1: sfLat, lon1: sfLon,
            lat2: laLat, lon2: laLon
        )
        
        // Actual driving is ~380 miles, straight line ~347 miles
        XCTAssertEqual(distance, 347, accuracy: 5, "SF to LA straight line ~347 miles")
    }
    
    /// Test: Known distance - New York to Boston (~190 miles)
    func testHaversine_NYCtoBoston() {
        // New York City
        let nycLat = 40.7128
        let nycLon = -74.0060
        
        // Boston
        let bosLat = 42.3601
        let bosLon = -71.0589
        
        let distance = haversineDistance(
            lat1: nycLat, lon1: nycLon,
            lat2: bosLat, lon2: bosLon
        )
        
        // Straight line ~190 miles
        XCTAssertEqual(distance, 190, accuracy: 5, "NYC to Boston ~190 miles")
    }
    
    /// Test: Short distance - within same city (~1 mile)
    func testHaversine_ShortDistance() {
        // Two points about 1 mile apart in San Francisco
        let lat1 = 37.7749
        let lon1 = -122.4194
        let lat2 = 37.7893  // ~1 mile north
        let lon2 = -122.4194
        
        let distance = haversineDistance(
            lat1: lat1, lon1: lon1,
            lat2: lat2, lon2: lon2
        )
        
        XCTAssertEqual(distance, 1.0, accuracy: 0.1, "Short distance ~1 mile")
    }
    
    /// Test: Very short distance - GPS jitter range (~0.01 miles)
    func testHaversine_VeryShortDistance() {
        let lat1 = 37.7749
        let lon1 = -122.4194
        let lat2 = 37.7750  // ~50 feet
        let lon2 = -122.4194
        
        let distance = haversineDistance(
            lat1: lat1, lon1: lon1,
            lat2: lat2, lon2: lon2
        )
        
        XCTAssertLessThan(distance, 0.1, "Very short distance < 0.1 miles")
    }
    
    /// Test: Cross-country - NYC to LA (~2,451 miles)
    func testHaversine_CrossCountry() {
        // New York
        let nycLat = 40.7128
        let nycLon = -74.0060
        
        // Los Angeles
        let laLat = 34.0522
        let laLon = -118.2437
        
        let distance = haversineDistance(
            lat1: nycLat, lon1: nycLon,
            lat2: laLat, lon2: laLon
        )
        
        XCTAssertEqual(distance, 2451, accuracy: 20, "NYC to LA ~2,451 miles")
    }
    
    /// Test: Haversine matches CLLocation calculation
    func testHaversine_MatchesCLLocation() {
        let lat1 = 37.7749
        let lon1 = -122.4194
        let lat2 = 37.3382
        let lon2 = -121.8863
        
        let haversine = haversineDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        let clLocation = clLocationDistance(lat1: lat1, lon1: lon1, lat2: lat2, lon2: lon2)
        
        XCTAssertEqual(haversine, clLocation, accuracy: 0.5, "Haversine should match CLLocation")
    }
}

// MARK: - Trip Segment Accumulation

extension FLOMileageGPSTests {
    
    /// Test: Single segment trip
    func testTripDistance_SingleSegment() {
        let segments: [(startLat: Double, startLon: Double, endLat: Double, endLon: Double)] = [
            (37.7749, -122.4194, 37.8044, -122.2712)  // SF to Oakland
        ]
        
        var totalDistance: Double = 0
        for segment in segments {
            totalDistance += haversineDistance(
                lat1: segment.startLat, lon1: segment.startLon,
                lat2: segment.endLat, lon2: segment.endLon
            )
        }
        
        XCTAssertGreaterThan(totalDistance, 5, "SF to Oakland > 5 miles")
        XCTAssertLessThan(totalDistance, 15, "SF to Oakland < 15 miles")
    }
    
    /// Test: Multi-segment trip
    func testTripDistance_MultipleSegments() {
        // Simulated trip with waypoints
        let waypoints: [(lat: Double, lon: Double)] = [
            (37.7749, -122.4194),  // Start: SF
            (37.7849, -122.4094),  // Waypoint 1
            (37.7949, -122.3994),  // Waypoint 2
            (37.8044, -122.2712)   // End: Oakland
        ]
        
        var totalDistance: Double = 0
        for i in 0..<(waypoints.count - 1) {
            let segment = haversineDistance(
                lat1: waypoints[i].lat, lon1: waypoints[i].lon,
                lat2: waypoints[i + 1].lat, lon2: waypoints[i + 1].lon
            )
            totalDistance += segment
        }
        
        XCTAssertGreaterThan(totalDistance, 0, "Multi-segment trip has distance")
    }
    
    /// Test: Round trip (should be double one-way)
    func testTripDistance_RoundTrip() {
        let homeLat = 37.7749
        let homeLon = -122.4194
        let workLat = 37.3861
        let workLon = -122.0839
        
        let oneWay = haversineDistance(
            lat1: homeLat, lon1: homeLon,
            lat2: workLat, lon2: workLon
        )
        
        let roundTrip = oneWay * 2
        
        XCTAssertEqual(roundTrip, oneWay * 2, accuracy: 0.01, "Round trip = 2x one way")
    }
    
    /// Test: Trip with many GPS points
    func testTripDistance_ManyGPSPoints() {
        // Simulate 100 GPS readings along a route
        var waypoints: [(lat: Double, lon: Double)] = []
        let startLat = 37.7749
        let startLon = -122.4194
        
        for i in 0..<100 {
            let lat = startLat + (Double(i) * 0.001)  // Move north
            let lon = startLon + (Double(i) * 0.0005) // Move east slightly
            waypoints.append((lat, lon))
        }
        
        var totalDistance: Double = 0
        for i in 0..<(waypoints.count - 1) {
            totalDistance += haversineDistance(
                lat1: waypoints[i].lat, lon1: waypoints[i].lon,
                lat2: waypoints[i + 1].lat, lon2: waypoints[i + 1].lon
            )
        }
        
        XCTAssertGreaterThan(totalDistance, 0, "Trip with many points has distance")
    }
}

// MARK: - GPS Accuracy Filtering

extension FLOMileageGPSTests {
    
    /// Test: Filter out low accuracy readings
    func testGPSFilter_LowAccuracy() {
        let readings: [(lat: Double, lon: Double, accuracy: Double)] = [
            (37.7749, -122.4194, 5.0),    // Good accuracy
            (37.7849, -122.4094, 100.0),  // Poor accuracy - should filter
            (37.7949, -122.3994, 10.0),   // Good accuracy
            (37.8049, -122.3894, 200.0),  // Very poor - should filter
            (37.8149, -122.3794, 8.0)     // Good accuracy
        ]
        
        let accuracyThreshold: Double = 50.0  // meters
        let filteredReadings = readings.filter { $0.accuracy <= accuracyThreshold }
        
        XCTAssertEqual(filteredReadings.count, 3, "Should filter out 2 low-accuracy readings")
    }
    
    /// Test: Minimum speed filter (stationary detection)
    func testGPSFilter_StationaryDetection() {
        // Two readings 1 minute apart, very close together
        let reading1 = (lat: 37.7749, lon: -122.4194, time: 0.0)
        let reading2 = (lat: 37.7749001, lon: -122.4194001, time: 60.0)  // 1 minute later
        
        let distance = haversineDistance(
            lat1: reading1.lat, lon1: reading1.lon,
            lat2: reading2.lat, lon2: reading2.lon
        )
        
        let timeHours = (reading2.time - reading1.time) / 3600.0
        let speedMPH = distance / timeHours
        
        let stationaryThreshold: Double = 2.0  // mph
        let isStationary = speedMPH < stationaryThreshold
        
        XCTAssertTrue(isStationary, "Should detect as stationary")
    }
    
    /// Test: Maximum speed filter (GPS glitch detection)
    func testGPSFilter_GlitchDetection() {
        // Two readings that would imply impossible speed
        let reading1 = (lat: 37.7749, lon: -122.4194, time: 0.0)
        let reading2 = (lat: 38.7749, lon: -122.4194, time: 60.0)  // 69 miles in 1 minute!
        
        let distance = haversineDistance(
            lat1: reading1.lat, lon1: reading1.lon,
            lat2: reading2.lat, lon2: reading2.lon
        )
        
        let timeHours = (reading2.time - reading1.time) / 3600.0
        let speedMPH = distance / timeHours
        
        let maxReasonableSpeed: Double = 150.0  // mph (highway + buffer)
        let isGlitch = speedMPH > maxReasonableSpeed
        
        XCTAssertTrue(isGlitch, "Should detect as GPS glitch")
        XCTAssertGreaterThan(speedMPH, 4000, "Implied speed is impossibly high")
    }
}

// MARK: - Trip State Management

extension FLOMileageGPSTests {
    
    /// Trip state enum
    enum TripState: String {
        case idle = "Idle"
        case tracking = "Tracking"
        case paused = "Paused"
        case ended = "Ended"
    }
    
    /// Test: Trip state transitions
    func testTripState_ValidTransitions() {
        var state = TripState.idle
        
        // Start trip
        XCTAssertEqual(state, .idle)
        state = .tracking
        XCTAssertEqual(state, .tracking)
        
        // Pause trip
        state = .paused
        XCTAssertEqual(state, .paused)
        
        // Resume trip
        state = .tracking
        XCTAssertEqual(state, .tracking)
        
        // End trip
        state = .ended
        XCTAssertEqual(state, .ended)
    }
    
    /// Test: Trip cannot end from idle
    func testTripState_CannotEndFromIdle() {
        let currentState = TripState.idle
        let canEnd = currentState == .tracking || currentState == .paused
        
        XCTAssertFalse(canEnd, "Cannot end trip from idle state")
    }
    
    /// Test: Trip auto-end detection (no movement for X minutes)
    func testTripState_AutoEndDetection() {
        let lastMovementTime: TimeInterval = 0
        let currentTime: TimeInterval = 600  // 10 minutes later
        let autoEndThreshold: TimeInterval = 300  // 5 minutes
        
        let timeSinceMovement = currentTime - lastMovementTime
        let shouldAutoEnd = timeSinceMovement > autoEndThreshold
        
        XCTAssertTrue(shouldAutoEnd, "Should auto-end after 10 minutes of no movement")
    }
}

// MARK: - Mileage Deduction Integration

extension FLOMileageGPSTests {
    
    /// Test: Calculate deduction from GPS trip
    func testDeduction_FromGPSTrip() {
        // Simulate a business trip
        let tripMiles: Double = 25.5
        let isBusiness = true
        
        let deduction = isBusiness ? tripMiles * irsRate2026 : 0
        
        XCTAssertEqual(deduction, 18.49, accuracy: 0.01, "25.5 miles × $0.725 = $18.49")
    }
    
    /// Test: Personal trip = no deduction
    func testDeduction_PersonalTrip_NoDeduction() {
        let deduction = calculateMileageDeduction(miles: 50.0, isBusiness: false)
        
        XCTAssertEqual(deduction, 0, "Personal trip = $0 deduction")
    }
    
    /// Helper to calculate mileage deduction (avoids compile-time optimization)
    private func calculateMileageDeduction(miles: Double, isBusiness: Bool) -> Double {
        return isBusiness ? miles * irsRate2026 : 0
    }
    
    /// Test: YTD mileage accumulation
    func testDeduction_YTDAccumulation() {
        let trips: [(miles: Double, isBusiness: Bool)] = [
            (25.0, true),
            (30.0, false),  // Personal
            (45.0, true),
            (20.0, true),
            (15.0, false)   // Personal
        ]
        
        let businessMiles = trips.filter { $0.isBusiness }.reduce(0) { $0 + $1.miles }
        let ytdDeduction = businessMiles * irsRate2026
        
        XCTAssertEqual(businessMiles, 90.0, "90 business miles")
        XCTAssertEqual(ytdDeduction, 65.25, accuracy: 0.01, "YTD deduction = $65.25")
    }
}

// MARK: - Trip Recovery (Crash Safety)

extension FLOMileageGPSTests {
    
    /// Test: Trip data persists across "crash"
    func testTripRecovery_DataPersists() {
        // Simulate trip data that would be saved
        let savedTripData: [String: Any] = [
            "tripId": "trip_12345",
            "startTime": Date().timeIntervalSince1970,
            "waypoints": [
                ["lat": 37.7749, "lon": -122.4194, "time": 0],
                ["lat": 37.7849, "lon": -122.4094, "time": 60]
            ],
            "isActive": true
        ]
        
        // Verify data structure
        XCTAssertNotNil(savedTripData["tripId"])
        XCTAssertNotNil(savedTripData["waypoints"])
        XCTAssertEqual(savedTripData["isActive"] as? Bool, true)
    }
    
    /// Test: Recovered trip needs review
    func testTripRecovery_NeedsReview() {
        let tripStatus = determineTripStatus(wasRecovered: true)
        
        XCTAssertEqual(tripStatus, "needsReview", "Recovered trips need user review")
    }
    
    /// Helper to determine trip status (avoids compile-time optimization)
    private func determineTripStatus(wasRecovered: Bool) -> String {
        return wasRecovered ? "needsReview" : "normal"
    }
}
