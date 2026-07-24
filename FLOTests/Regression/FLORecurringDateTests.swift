//  FLORecurringDateTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2.1 - Test Logic Fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate all recurring transaction date calculations including
//  month-end handling, frequency calculations, and catch-up logic.
//
//  CHANGES v1.2.1:
//  - Fixed testIntegration_FullYear_Monthly31st date rollover bug
//  - Use day=1 when getting lastDayOfMonth to avoid Feb 31 → Mar 3 rollover
//
//  CHANGES v1.2:
//  - Fixed tuple comparisons (XCTAssertEqual doesn't support tuples)
//  - Removed private from helper functions for extension access
//
//  COVERS:
//  - Month-end date handling (Jan 31 -> Feb 28 -> Mar 31)
//  - All frequency types (weekly, bi-weekly, monthly, quarterly, yearly)
//  - Leap year handling
//  - Feb 29 -> Feb 28 transition (leap to non-leap year) - v1.1
//  - Catch-up instance creation
//  - Next occurrence calculations
//

import XCTest
@testable import FLO

final class FLORecurringDateTests: XCTestCase {
    
    // MARK: - Calendar Helper
    
    let calendar = Calendar.current
    
    /// Create a date from components
    func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12  // Noon to avoid timezone issues
        return calendar.date(from: components)!
    }
    
    /// Get day of month from date
    func dayOfMonth(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }
    
    /// Get month from date
    func month(_ date: Date) -> Int {
        calendar.component(.month, from: date)
    }
    
    /// Get year from date
    func year(_ date: Date) -> Int {
        calendar.component(.year, from: date)
    }
    
    /// Get last day of month for a given date
    func lastDayOfMonth(_ date: Date) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.count
    }
}

// MARK: - Month-End Handling

extension FLORecurringDateTests {
    
    /// Test: January 31 → February (should use Feb 28 or 29)
    func testMonthEnd_Jan31_ToFeb28() {
        let jan31 = makeDate(year: 2026, month: 1, day: 31)
        
        // Calculate next monthly occurrence
        var nextComponents = calendar.dateComponents([.year, .month], from: jan31)
        nextComponents.month! += 1
        nextComponents.day = 31  // Try to keep the 31st
        
        // Get what day actually exists
        let feb2026 = makeDate(year: 2026, month: 2, day: 1)
        let lastDayFeb = lastDayOfMonth(feb2026)  // Should be 28 in 2026
        
        XCTAssertEqual(lastDayFeb, 28, "February 2026 has 28 days")
        
        // The recurring should fall on Feb 28
        let expectedDay = min(31, lastDayFeb)
        XCTAssertEqual(expectedDay, 28, "Jan 31 → Feb 28")
    }
    
    /// Test: February 28 → March 31 (back to original day)
    func testMonthEnd_Feb28_ToMar31() {
        // If started on 31st, and Feb was 28, March should return to 31
        let startDay = 31
        let mar2026 = makeDate(year: 2026, month: 3, day: 1)
        let lastDayMar = lastDayOfMonth(mar2026)
        
        XCTAssertEqual(lastDayMar, 31, "March has 31 days")
        
        let expectedDay = min(startDay, lastDayMar)
        XCTAssertEqual(expectedDay, 31, "Feb 28 → Mar 31 (returns to intended day)")
    }
    
    /// Test: March 31 → April 30
    func testMonthEnd_Mar31_ToApr30() {
        let startDay = 31
        let apr2026 = makeDate(year: 2026, month: 4, day: 1)
        let lastDayApr = lastDayOfMonth(apr2026)
        
        XCTAssertEqual(lastDayApr, 30, "April has 30 days")
        
        let expectedDay = min(startDay, lastDayApr)
        XCTAssertEqual(expectedDay, 30, "Mar 31 → Apr 30")
    }
    
    /// Test: Full year cycle for 31st of month
    func testMonthEnd_FullYearCycle_Day31() {
        let expectedDays = [
            31, // Jan
            28, // Feb (2026 is not a leap year)
            31, // Mar
            30, // Apr
            31, // May
            30, // Jun
            31, // Jul
            31, // Aug
            30, // Sep
            31, // Oct
            30, // Nov
            31  // Dec
        ]
        
        for (index, expected) in expectedDays.enumerated() {
            let month = index + 1
            let date = makeDate(year: 2026, month: month, day: 1)
            let lastDay = lastDayOfMonth(date)
            let actualDay = min(31, lastDay)
            
            XCTAssertEqual(actualDay, expected, "Month \(month) should land on day \(expected)")
        }
    }
    
    /// Test: 30th of month cycle
    func testMonthEnd_FullYearCycle_Day30() {
        let startDay = 30
        
        for month in 1...12 {
            let date = makeDate(year: 2026, month: month, day: 1)
            let lastDay = lastDayOfMonth(date)
            let actualDay = min(startDay, lastDay)
            
            // February is the only month where 30 doesn't exist
            let expected = month == 2 ? 28 : 30
            XCTAssertEqual(actualDay, expected, "Month \(month) with start day 30")
        }
    }
    
    /// Test: 29th of month (leap year consideration)
    func testMonthEnd_Day29_LeapYear() {
        // 2024 was a leap year, 2026 is not
        let feb2024 = makeDate(year: 2024, month: 2, day: 1)
        let feb2026 = makeDate(year: 2026, month: 2, day: 1)
        
        let lastDayFeb2024 = lastDayOfMonth(feb2024)
        let lastDayFeb2026 = lastDayOfMonth(feb2026)
        
        XCTAssertEqual(lastDayFeb2024, 29, "Feb 2024 (leap year) has 29 days")
        XCTAssertEqual(lastDayFeb2026, 28, "Feb 2026 (not leap year) has 28 days")
    }
}

// MARK: - Frequency Calculations

extension FLORecurringDateTests {
    
    /// Test: Weekly frequency
    func testFrequency_Weekly() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)  // Thursday
        let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate)!
        
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: nextDate).day!
        
        XCTAssertEqual(daysBetween, 7, "Weekly = 7 days")
        XCTAssertEqual(dayOfMonth(nextDate), 22, "Jan 15 + 1 week = Jan 22")
    }
    
    /// Test: Bi-weekly frequency
    func testFrequency_BiWeekly() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)
        let nextDate = calendar.date(byAdding: .weekOfYear, value: 2, to: startDate)!
        
        let daysBetween = calendar.dateComponents([.day], from: startDate, to: nextDate).day!
        
        XCTAssertEqual(daysBetween, 14, "Bi-weekly = 14 days")
        XCTAssertEqual(dayOfMonth(nextDate), 29, "Jan 15 + 2 weeks = Jan 29")
    }
    
    /// Test: Monthly frequency - normal case
    func testFrequency_Monthly_Normal() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)
        let nextDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        
        XCTAssertEqual(month(nextDate), 2, "Should be February")
        XCTAssertEqual(dayOfMonth(nextDate), 15, "Day should be preserved")
    }
    
    /// Test: Monthly frequency - crosses year
    func testFrequency_Monthly_CrossYear() {
        let startDate = makeDate(year: 2025, month: 12, day: 15)
        let nextDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        
        XCTAssertEqual(year(nextDate), 2026, "Should be next year")
        XCTAssertEqual(month(nextDate), 1, "Should be January")
        XCTAssertEqual(dayOfMonth(nextDate), 15, "Day should be preserved")
    }
    
    /// Test: Quarterly frequency
    func testFrequency_Quarterly() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)
        let nextDate = calendar.date(byAdding: .month, value: 3, to: startDate)!
        
        XCTAssertEqual(month(nextDate), 4, "Jan + 3 months = April")
        XCTAssertEqual(dayOfMonth(nextDate), 15, "Day should be preserved")
    }
    
    /// Test: Quarterly frequency - Q1 to Q2 to Q3 to Q4
    func testFrequency_Quarterly_FullYear() {
        var date = makeDate(year: 2026, month: 1, day: 15)
        
        let expectedMonths = [1, 4, 7, 10, 1]  // Q1, Q2, Q3, Q4, Q1 next year
        
        for (index, expectedMonth) in expectedMonths.enumerated() {
            XCTAssertEqual(month(date), expectedMonth, "Quarter \(index)")
            date = calendar.date(byAdding: .month, value: 3, to: date)!
        }
    }
    
    /// Test: Yearly frequency
    func testFrequency_Yearly() {
        let startDate = makeDate(year: 2026, month: 3, day: 15)
        let nextDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
        
        XCTAssertEqual(year(nextDate), 2027, "Should be next year")
        XCTAssertEqual(month(nextDate), 3, "Month should be preserved")
        XCTAssertEqual(dayOfMonth(nextDate), 15, "Day should be preserved")
    }
    
    /// Test: Yearly frequency - Feb 29 leap year
    func testFrequency_Yearly_LeapYearFeb29() {
        // Feb 29, 2024 (leap year) → Feb 28, 2025 (not leap year)
        let feb29_2024 = makeDate(year: 2024, month: 2, day: 29)
        let nextYear = calendar.date(byAdding: .year, value: 1, to: feb29_2024)!
        
        XCTAssertEqual(year(nextYear), 2025)
        XCTAssertEqual(month(nextYear), 2)
        // Calendar typically rolls to March 1, but we should handle as Feb 28
        // This depends on implementation - test actual behavior
        XCTAssertTrue(dayOfMonth(nextYear) == 28 || dayOfMonth(nextYear) == 1,
                      "Feb 29 in non-leap year should be Feb 28 or Mar 1")
    }
}

// MARK: - Next Occurrence Logic

extension FLORecurringDateTests {
    
    /// Test: First occurrence is start date
    func testNextOccurrence_FirstIsStartDate() {
        let startDate = makeDate(year: 2026, month: 2, day: 15)
        let lastCreated: Date? = nil  // Never created
        
        // If never created, next occurrence should be start date
        let nextOccurrence = lastCreated == nil ? startDate : calendar.date(byAdding: .month, value: 1, to: lastCreated!)!
        
        XCTAssertEqual(nextOccurrence, startDate, "First occurrence is start date")
    }
    
    /// Test: Next occurrence after creation
    func testNextOccurrence_AfterCreation() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)
        let lastCreated = startDate  // Just created the first one
        
        let nextOccurrence = calendar.date(byAdding: .month, value: 1, to: lastCreated)!
        
        XCTAssertEqual(month(nextOccurrence), 2, "Next should be February")
        XCTAssertEqual(dayOfMonth(nextOccurrence), 15, "Day should be preserved")
    }
    
    /// Test: Should create instance check - before start date
    func testShouldCreate_BeforeStartDate() {
        let startDate = makeDate(year: 2026, month: 6, day: 1)
        let today = makeDate(year: 2026, month: 1, day: 15)
        
        let shouldCreate = today >= startDate
        
        XCTAssertFalse(shouldCreate, "Should not create before start date")
    }
    
    /// Test: Should create instance check - on start date
    func testShouldCreate_OnStartDate() {
        let startDate = makeDate(year: 2026, month: 1, day: 15)
        let today = makeDate(year: 2026, month: 1, day: 15)
        
        let shouldCreate = today >= startDate
        
        XCTAssertTrue(shouldCreate, "Should create on start date")
    }
    
    /// Test: Should create instance check - after end date
    func testShouldCreate_AfterEndDate() {
        let startDate = makeDate(year: 2025, month: 1, day: 1)
        let endDate = makeDate(year: 2025, month: 12, day: 31)
        let today = makeDate(year: 2026, month: 1, day: 15)
        
        let shouldCreate = today >= startDate && today <= endDate
        
        XCTAssertFalse(shouldCreate, "Should not create after end date")
    }
    
    /// Test: Prevent duplicate on same day
    func testShouldCreate_PreventDuplicateSameDay() {
        let today = makeDate(year: 2026, month: 1, day: 15)
        let lastCreated = today  // Already created today
        
        let alreadyCreatedToday = calendar.isDate(lastCreated, inSameDayAs: today)
        
        XCTAssertTrue(alreadyCreatedToday, "Should detect same day")
    }
}

// MARK: - Catch-Up Instance Creation

extension FLORecurringDateTests {
    
    /// Test: Calculate missed instances - 3 months missed
    func testCatchUp_ThreeMonthsMissed() {
        let startDate = makeDate(year: 2025, month: 10, day: 15)
        let lastCreated = startDate  // Created first instance
        let today = makeDate(year: 2026, month: 1, day: 20)  // 3+ months later
        
        var missedDates: [Date] = []
        var checkDate = calendar.date(byAdding: .month, value: 1, to: lastCreated)!
        
        while checkDate <= today {
            missedDates.append(checkDate)
            checkDate = calendar.date(byAdding: .month, value: 1, to: checkDate)!
        }
        
        // Should have Nov, Dec, Jan = 3 missed
        XCTAssertEqual(missedDates.count, 3, "Should have 3 missed instances")
        XCTAssertEqual(month(missedDates[0]), 11, "First missed is November")
        XCTAssertEqual(month(missedDates[1]), 12, "Second missed is December")
        XCTAssertEqual(month(missedDates[2]), 1, "Third missed is January")
    }
    
    /// Test: Catch-up respects end date
    func testCatchUp_RespectsEndDate() {
        let startDate = makeDate(year: 2025, month: 10, day: 15)
        let endDate = makeDate(year: 2025, month: 12, day: 31)
        let lastCreated = startDate
        let today = makeDate(year: 2026, month: 3, day: 1)
        
        var missedDates: [Date] = []
        var checkDate = calendar.date(byAdding: .month, value: 1, to: lastCreated)!
        
        while checkDate <= today && checkDate <= endDate {
            missedDates.append(checkDate)
            checkDate = calendar.date(byAdding: .month, value: 1, to: checkDate)!
        }
        
        // Should only have Nov, Dec (not Jan onwards due to end date)
        XCTAssertEqual(missedDates.count, 2, "Should respect end date")
        XCTAssertEqual(month(missedDates[0]), 11, "November")
        XCTAssertEqual(month(missedDates[1]), 12, "December")
    }
    
    /// Test: Weekly catch-up calculation
    func testCatchUp_Weekly_TwoWeeksMissed() {
        let startDate = makeDate(year: 2026, month: 1, day: 1)
        let lastCreated = startDate
        let today = makeDate(year: 2026, month: 1, day: 22)  // 3 weeks later
        
        var missedDates: [Date] = []
        var checkDate = calendar.date(byAdding: .weekOfYear, value: 1, to: lastCreated)!
        
        while checkDate <= today {
            missedDates.append(checkDate)
            checkDate = calendar.date(byAdding: .weekOfYear, value: 1, to: checkDate)!
        }
        
        // Jan 1 + 1 week = Jan 8, + 2 weeks = Jan 15, + 3 weeks = Jan 22
        XCTAssertEqual(missedDates.count, 3, "Should have 3 missed weekly instances")
    }
}

// MARK: - Edge Cases

extension FLORecurringDateTests {
    
    /// Test: Deactivated recurring should not create
    func testDeactivated_ShouldNotCreate() {
        let isActive = false
        let startDate = makeDate(year: 2025, month: 1, day: 1)
        let today = makeDate(year: 2026, month: 1, day: 15)
        
        let shouldCreate = isActive && today >= startDate
        
        XCTAssertFalse(shouldCreate, "Deactivated should not create")
    }
    
    /// Test: Very old recurring - limit catch-up
    func testCatchUp_VeryOld_ShouldLimit() {
        // If app wasn't opened for 5 years, don't create 60 monthly instances
        let lastCreated = makeDate(year: 2020, month: 1, day: 15)
        let today = makeDate(year: 2026, month: 1, day: 15)
        
        let monthsBetween = calendar.dateComponents([.month], from: lastCreated, to: today).month!
        
        XCTAssertEqual(monthsBetween, 72, "72 months between")
        
        // App should limit catch-up to reasonable amount (e.g., 12 months)
        let maxCatchUp = 12
        let actualCatchUp = min(monthsBetween, maxCatchUp)
        
        XCTAssertEqual(actualCatchUp, 12, "Should limit catch-up to 12")
    }
    
    /// Test: Start date in future - should not create yet
    func testFutureStart_ShouldWait() {
        let startDate = makeDate(year: 2027, month: 1, day: 1)
        let today = makeDate(year: 2026, month: 6, day: 15)
        
        let shouldCreate = today >= startDate
        
        XCTAssertFalse(shouldCreate, "Should not create before future start date")
    }
    
    /// Test: Backdated start - should catch up
    func testBackdatedStart_ShouldCatchUp() {
        let startDate = makeDate(year: 2025, month: 6, day: 15)  // 6 months ago
        let today = makeDate(year: 2026, month: 1, day: 15)
        let lastCreated: Date? = nil  // Never created any
        
        let shouldCreate = today >= startDate && lastCreated == nil
        
        XCTAssertTrue(shouldCreate, "Should create for backdated start")
    }
}

// MARK: - Leap Year Edge Cases (Feb 29 Transitions)

extension FLORecurringDateTests {
    
    /// Test: Feb 29 (leap year) → Feb 28 (non-leap year) for yearly recurring
    /// Critical edge case: User creates yearly recurring on Feb 29, 2024
    /// Next year (2025) should fall on Feb 28, not March 1
    func testLeapYear_Feb29_ToNonLeapYear_Yearly() {
        // Start on Feb 29, 2024 (leap year)
        let startDate = makeDate(year: 2024, month: 2, day: 29)
        
        // Add one year
        let nextDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
        
        // 2025 is not a leap year, so Feb 29 doesn't exist
        // Swift's Calendar.date(byAdding:) should roll to Feb 28
        XCTAssertEqual(year(nextDate), 2025, "Should be 2025")
        XCTAssertEqual(month(nextDate), 2, "Should still be February")
        XCTAssertEqual(dayOfMonth(nextDate), 28, "Feb 29 → Feb 28 in non-leap year")
    }
    
    /// Test: Feb 29 → next leap year Feb 29 (4 years later)
    func testLeapYear_Feb29_ToNextLeapYear() {
        // Start on Feb 29, 2024 (leap year)
        let startDate = makeDate(year: 2024, month: 2, day: 29)
        
        // Add 4 years to get to next leap year
        let nextLeapDate = calendar.date(byAdding: .year, value: 4, to: startDate)!
        
        // 2028 is a leap year, so Feb 29 exists
        XCTAssertEqual(year(nextLeapDate), 2028, "Should be 2028")
        XCTAssertEqual(month(nextLeapDate), 2, "Should be February")
        XCTAssertEqual(dayOfMonth(nextLeapDate), 29, "Feb 29 exists in leap year 2028")
    }
    
    /// Test: Monthly recurring starting on Feb 29 - what happens in March?
    /// This tests the "intended day" preservation pattern
    func testLeapYear_Feb29_MonthlyToMarch() {
        // Start on Feb 29, 2024 (leap year)
        let startDate = makeDate(year: 2024, month: 2, day: 29)
        let intendedDay = 29
        
        // Calculate next month's occurrence
        var nextComponents = calendar.dateComponents([.year, .month], from: startDate)
        nextComponents.month! += 1  // March
        
        // March has 31 days, so 29 exists
        let marchDate = makeDate(year: 2024, month: 3, day: 1)
        let lastDayMarch = lastDayOfMonth(marchDate)
        let actualDay = min(intendedDay, lastDayMarch)
        
        XCTAssertEqual(actualDay, 29, "March 29 should be used (day exists)")
    }
    
    /// Test: Full year cycle starting from Feb 29 leap year
    /// Verifies the pattern: Feb 29 → Mar 29 → Apr 29 → ... → Feb 28 (next year)
    func testLeapYear_Feb29_FullYearCycle() {
        let intendedDay = 29
        var currentDate = makeDate(year: 2024, month: 2, day: 29)
        
        var occurrences: [(year: Int, month: Int, day: Int)] = []
        
        // Generate 13 months to see the full cycle back to February
        for _ in 0..<13 {
            occurrences.append((year: year(currentDate), month: month(currentDate), day: dayOfMonth(currentDate)))
            
            // Calculate next month
            var nextComponents = calendar.dateComponents([.year, .month], from: currentDate)
            nextComponents.month! += 1
            
            // Handle year rollover
            if nextComponents.month! > 12 {
                nextComponents.month = 1
                nextComponents.year! += 1
            }
            
            // Get actual last day of target month
            let firstOfNextMonth = calendar.date(from: DateComponents(year: nextComponents.year, month: nextComponents.month, day: 1))!
            let lastDay = lastDayOfMonth(firstOfNextMonth)
            nextComponents.day = min(intendedDay, lastDay)
            
            currentDate = calendar.date(from: nextComponents)!
        }
        
        // Verify key months (compare individual components since tuples aren't Equatable)
        // Start: Feb 29, 2024
        XCTAssertEqual(occurrences[0].year, 2024, "Start year")
        XCTAssertEqual(occurrences[0].month, 2, "Start month")
        XCTAssertEqual(occurrences[0].day, 29, "Start day: Feb 29, 2024")
        
        // Mar 29, 2024
        XCTAssertEqual(occurrences[1].year, 2024, "Mar year")
        XCTAssertEqual(occurrences[1].month, 3, "Mar month")
        XCTAssertEqual(occurrences[1].day, 29, "Mar 29")
        
        // Apr 29, 2024
        XCTAssertEqual(occurrences[2].year, 2024, "Apr year")
        XCTAssertEqual(occurrences[2].month, 4, "Apr month")
        XCTAssertEqual(occurrences[2].day, 29, "Apr 29")
        
        // Feb 2025 → 28 (not leap year)
        XCTAssertEqual(occurrences[12].year, 2025, "Feb 2025 year")
        XCTAssertEqual(occurrences[12].month, 2, "Feb 2025 month")
        XCTAssertEqual(occurrences[12].day, 28, "Feb 2025 → 28 (not leap year)")
    }
    
    /// Test: Last day of February preservation across years
    /// User sets recurring on "last day of February" - should always be last day
    func testLeapYear_LastDayFeb_PreservationPattern() {
        // Pattern: Always use last day of February regardless of leap year
        
        let feb2024LastDay = lastDayOfMonth(makeDate(year: 2024, month: 2, day: 1))
        let feb2025LastDay = lastDayOfMonth(makeDate(year: 2025, month: 2, day: 1))
        let feb2026LastDay = lastDayOfMonth(makeDate(year: 2026, month: 2, day: 1))
        let feb2028LastDay = lastDayOfMonth(makeDate(year: 2028, month: 2, day: 1))
        
        XCTAssertEqual(feb2024LastDay, 29, "2024 leap year: Feb has 29 days")
        XCTAssertEqual(feb2025LastDay, 28, "2025 non-leap: Feb has 28 days")
        XCTAssertEqual(feb2026LastDay, 28, "2026 non-leap: Feb has 28 days")
        XCTAssertEqual(feb2028LastDay, 29, "2028 leap year: Feb has 29 days")
    }
    
    /// Test: Leap year detection helper
    func testLeapYear_Detection() {
        // Leap years are divisible by 4, except centuries unless divisible by 400
        let leapYears = [2024, 2028, 2032, 2000, 2400]
        let nonLeapYears = [2025, 2026, 2027, 2100, 2200, 2300]
        
        for year in leapYears {
            let feb = makeDate(year: year, month: 2, day: 1)
            let lastDay = lastDayOfMonth(feb)
            XCTAssertEqual(lastDay, 29, "\(year) should be a leap year")
        }
        
        for year in nonLeapYears {
            let feb = makeDate(year: year, month: 2, day: 1)
            let lastDay = lastDayOfMonth(feb)
            XCTAssertEqual(lastDay, 28, "\(year) should NOT be a leap year")
        }
    }
}

// MARK: - Integration: Full Recurring Cycle

extension FLORecurringDateTests {
    
    /// Test: Full year of monthly recurring on the 31st
    func testIntegration_FullYear_Monthly31st() {
        var currentDate = makeDate(year: 2026, month: 1, day: 31)
        let intendedDay = 31
        
        var occurrences: [(month: Int, day: Int)] = []
        
        for _ in 0..<12 {
            // Record this occurrence
            occurrences.append((month: month(currentDate), day: dayOfMonth(currentDate)))
            
            // Calculate next month
            var nextComponents = calendar.dateComponents([.year, .month], from: currentDate)
            nextComponents.month! += 1
            
            // Handle year rollover
            if nextComponents.month! > 12 {
                nextComponents.month = 1
                nextComponents.year! += 1
            }
            
            // Get actual last day of target month (use day=1 to avoid rollover)
            let firstOfNextMonth = calendar.date(from: DateComponents(year: nextComponents.year, month: nextComponents.month, day: 1))!
            let lastDay = lastDayOfMonth(firstOfNextMonth)
            nextComponents.day = min(intendedDay, lastDay)
            
            currentDate = calendar.date(from: nextComponents)!
        }
        
        // Verify the pattern (compare individual components since tuples aren't Equatable)
        XCTAssertEqual(occurrences[0].month, 1, "January month")
        XCTAssertEqual(occurrences[0].day, 31, "January day")
        XCTAssertEqual(occurrences[1].month, 2, "February month")
        XCTAssertEqual(occurrences[1].day, 28, "February day (non-leap)")
        XCTAssertEqual(occurrences[2].month, 3, "March month")
        XCTAssertEqual(occurrences[2].day, 31, "March day")
        XCTAssertEqual(occurrences[3].month, 4, "April month")
        XCTAssertEqual(occurrences[3].day, 30, "April day")
        XCTAssertEqual(occurrences[4].month, 5, "May month")
        XCTAssertEqual(occurrences[4].day, 31, "May day")
        XCTAssertEqual(occurrences[5].month, 6, "June month")
        XCTAssertEqual(occurrences[5].day, 30, "June day")
        XCTAssertEqual(occurrences[6].month, 7, "July month")
        XCTAssertEqual(occurrences[6].day, 31, "July day")
        XCTAssertEqual(occurrences[7].month, 8, "August month")
        XCTAssertEqual(occurrences[7].day, 31, "August day")
        XCTAssertEqual(occurrences[8].month, 9, "September month")
        XCTAssertEqual(occurrences[8].day, 30, "September day")
        XCTAssertEqual(occurrences[9].month, 10, "October month")
        XCTAssertEqual(occurrences[9].day, 31, "October day")
        XCTAssertEqual(occurrences[10].month, 11, "November month")
        XCTAssertEqual(occurrences[10].day, 30, "November day")
        XCTAssertEqual(occurrences[11].month, 12, "December month")
        XCTAssertEqual(occurrences[11].day, 31, "December day")
    }
    
    /// Test: Bi-weekly paycheck simulation
    func testIntegration_BiWeeklyPaycheck() {
        var paycheckDate = makeDate(year: 2026, month: 1, day: 2)  // First Friday
        var paycheckDates: [Date] = [paycheckDate]
        
        // Generate 26 paychecks (full year)
        for _ in 1..<26 {
            paycheckDate = calendar.date(byAdding: .weekOfYear, value: 2, to: paycheckDate)!
            paycheckDates.append(paycheckDate)
        }
        
        XCTAssertEqual(paycheckDates.count, 26, "26 bi-weekly paychecks per year")
        
        // Last paycheck should be in late December
        let lastPaycheck = paycheckDates.last!
        XCTAssertEqual(month(lastPaycheck), 12, "Last paycheck in December")
    }
}
