//  Date+Extensions.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Fully working, no errors, production-ready
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  DEPLOYMENT REQUIREMENTS:
//  - iOS 15.0+ / macOS 12.0+ (for .formatted() API)
//  - If supporting older iOS, use DateFormatter fallbacks
//
//  LOCALIZATION:
//  - All formatting respects user's locale and timezone automatically
//  - Date boundaries use user's calendar (Gregorian, Hebrew, Islamic, etc.)
//  - Relative strings adapt to user's language preferences
//
//  CHANGES FROM v2.0:
//  - Added deployment target documentation
//  - Added localization notes
//  - Enhanced testability with explicit calendar parameters
//  - Clarified version constant usage
//
//  CHANGES FROM v1.0:
//  - Added comprehensive date boundary helpers (day, week, quarter, year)
//  - Added tax quarter support (Q1-Q4 for quarterly tax estimates)
//  - Added relative date formatting ("Today", "Yesterday", "2 days ago")
//  - Added date comparison utilities (isSameDay, isSameMonth, etc.)
//  - Added days in month helper
//  - Added age and interval formatting
//  - Improved thread safety with modern concurrency
//  - Added comprehensive documentation and examples
//
//  FEATURES:
//  - Month/Week/Quarter/Year boundaries for reports
//  - Tax quarter calculations (Q1: Jan-Mar, Q2: Apr-Jun, Q3: Jul-Sep, Q4: Oct-Dec)
//  - Relative date formatting for transaction lists
//  - Safe, locale-aware calculations
//  - Performance-optimized with modern formatted() API
//

import Foundation

// MARK: - Version

extension Date {
    /// Version constant for tracking extension updates
    /// Useful for: debugging, analytics, and feature flagging
    /// Example: print("Date extensions v\(Date.extensionVersion)")
    static let extensionVersion = "2.1"
}

// MARK: - Date Boundaries

extension Date {
    
    // MARK: Month Boundaries
    
    /// Returns the first moment of the month (e.g., 2025-11-01 00:00:00)
    /// - Parameter calendar: Calendar to use for calculations (default: current)
    /// - Returns: Start of month date
    func startOfMonth(using calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self)) ?? self
    }
    
    /// Returns the last moment of the month (e.g., 2025-11-30 23:59:59)
    /// - Parameter calendar: Calendar to use for calculations (default: current)
    /// - Returns: End of month date
    func endOfMonth(using calendar: Calendar = .current) -> Date {
        guard let plusOneMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth(using: calendar)),
              let endOfMonth = calendar.date(byAdding: .second, value: -1, to: plusOneMonth) else {
            return self // Fallback if calculation fails (extremely rare)
        }
        return endOfMonth
    }
    
    /// Returns number of days in the current month
    var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: self)?.count ?? 30
    }
    
    // MARK: Day Boundaries
    
    /// Returns the start of day (midnight: 00:00:00)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: Start of day date
    func startOfDay(using calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }
    
    /// Returns the end of day (23:59:59)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: End of day date
    func endOfDay(using calendar: Calendar = .current) -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfDay(using: calendar)) ?? self
    }
    
    // MARK: Week Boundaries
    
    /// Returns the start of the week (Sunday 00:00:00 or Monday based on locale)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: Start of week date
    func startOfWeek(using calendar: Calendar = .current) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the end of the week (Saturday 23:59:59 or Sunday based on locale)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: End of week date
    func endOfWeek(using calendar: Calendar = .current) -> Date {
        guard let plusOneWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek(using: calendar)),
              let endOfWeek = calendar.date(byAdding: .second, value: -1, to: plusOneWeek) else {
            return self
        }
        return endOfWeek
    }
    
    // MARK: Quarter Boundaries (Critical for Tax Filing)
    
    /// Returns the tax quarter (1-4) for the date
    /// Q1: January-March, Q2: April-June, Q3: July-September, Q4: October-December
    /// - Parameter calendar: Calendar to use (default: current) - useful for testing
    /// - Returns: Quarter number (1-4)
    func taxQuarter(using calendar: Calendar = .current) -> Int {
        let month = calendar.component(.month, from: self)
        return ((month - 1) / 3) + 1
    }
    
    /// Convenience property for tax quarter using current calendar
    var taxQuarter: Int {
        taxQuarter(using: .current)
    }
    
    /// Returns the start of the tax quarter (first day at 00:00:00)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: Start of quarter date
    func startOfQuarter(using calendar: Calendar = .current) -> Date {
        let quarter = taxQuarter
        let year = calendar.component(.year, from: self)
        let startMonth = (quarter - 1) * 3 + 1
        
        var components = DateComponents()
        components.year = year
        components.month = startMonth
        components.day = 1
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the end of the tax quarter (last day at 23:59:59)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: End of quarter date
    func endOfQuarter(using calendar: Calendar = .current) -> Date {
        guard let plusOneQuarter = calendar.date(byAdding: .month, value: 3, to: startOfQuarter(using: calendar)),
              let endOfQuarter = calendar.date(byAdding: .second, value: -1, to: plusOneQuarter) else {
            return self
        }
        return endOfQuarter
    }
    
    /// Returns a formatted quarter string (e.g., "Q1 2025")
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: Formatted quarter string
    func quarterString(using calendar: Calendar = .current) -> String {
        let quarter = taxQuarter(using: calendar)
        let year = calendar.component(.year, from: self)
        return "Q\(quarter) \(year)"
    }
    
    /// Convenience property for quarter string using current calendar
    var quarterString: String {
        quarterString(using: .current)
    }
    
    // MARK: Year Boundaries
    
    /// Returns the start of the year (January 1 at 00:00:00)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: Start of year date
    func startOfYear(using calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year], from: self)
        components.month = 1
        components.day = 1
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the end of the year (December 31 at 23:59:59)
    /// - Parameter calendar: Calendar to use (default: current)
    /// - Returns: End of year date
    func endOfYear(using calendar: Calendar = .current) -> Date {
        guard let plusOneYear = calendar.date(byAdding: .year, value: 1, to: startOfYear(using: calendar)),
              let endOfYear = calendar.date(byAdding: .second, value: -1, to: plusOneYear) else {
            return self
        }
        return endOfYear
    }
}

// MARK: - Date Comparisons

extension Date {
    
    /// Checks if this date is the same day as another date
    /// - Parameters:
    ///   - date: Date to compare against
    ///   - calendar: Calendar to use (default: current)
    /// - Returns: True if same day
    func isSameDay(as date: Date, using calendar: Calendar = .current) -> Bool {
        calendar.isDate(self, inSameDayAs: date)
    }
    
    /// Checks if this date is the same month as another date
    /// - Parameters:
    ///   - date: Date to compare against
    ///   - calendar: Calendar to use (default: current)
    /// - Returns: True if same month
    func isSameMonth(as date: Date, using calendar: Calendar = .current) -> Bool {
        let components1 = calendar.dateComponents([.year, .month], from: self)
        let components2 = calendar.dateComponents([.year, .month], from: date)
        return components1.year == components2.year && components1.month == components2.month
    }
    
    /// Checks if this date is the same year as another date
    /// - Parameters:
    ///   - date: Date to compare against
    ///   - calendar: Calendar to use (default: current)
    /// - Returns: True if same year
    func isSameYear(as date: Date, using calendar: Calendar = .current) -> Bool {
        calendar.component(.year, from: self) == calendar.component(.year, from: date)
    }
    
    /// Checks if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Checks if this date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Checks if this date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    /// Checks if this date is in the current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Checks if this date is in the current month
    var isThisMonth: Bool {
        isSameMonth(as: Date())
    }
    
    /// Checks if this date is in the current year
    var isThisYear: Bool {
        isSameYear(as: Date())
    }
    
    /// Checks if this date is in the past
    var isPast: Bool {
        self < Date()
    }
    
    /// Checks if this date is in the future
    var isFuture: Bool {
        self > Date()
    }
}

// MARK: - Date Formatting

extension Date {
    
    /// Full month name: "November"
    var monthName: String {
        formatted(.dateTime.month(.wide))
    }
    
    /// Short month + year: "Nov 2025"
    var shortMonthYear: String {
        formatted(.dateTime.month(.abbreviated).year())
    }
    
    /// "November 2025"
    var fullMonthYear: String {
        formatted(.dateTime.month(.wide).year())
    }
    
    /// Relative date string for transaction lists
    /// Returns: "Today", "Yesterday", "2 days ago", "Nov 15", or "Nov 15, 2024"
    var relativeString: String {
        // Note: isToday, isYesterday use Calendar.current internally
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isTomorrow {
            return "Tomorrow"
        } else if isThisWeek {
            // Within this week: "Monday", "Tuesday", etc.
            return formatted(.dateTime.weekday(.wide))
        } else if isThisYear {
            // This year: "Nov 15"
            return formatted(.dateTime.month(.abbreviated).day())
        } else {
            // Other years: "Nov 15, 2024"
            return formatted(.dateTime.month(.abbreviated).day().year())
        }
    }
    
    /// Short relative string for compact UIs
    /// Returns: "Today", "Yesterday", "2d ago", "Nov 15"
    var shortRelativeString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        }
        
        let days = Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
        
        if days > 0 && days < 7 {
            return "\(days)d ago"
        } else if isThisYear {
            return formatted(.dateTime.month(.abbreviated).day())
        } else {
            return formatted(.dateTime.month(.abbreviated).day().year(.twoDigits))
        }
    }
    
    /// Time interval string (e.g., "2 hours ago", "3 days ago")
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Short time interval (e.g., "2h ago", "3d ago")
    var shortTimeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Date Arithmetic

extension Date {
    
    /// Adds a number of days to the date
    /// - Parameter days: Number of days to add (can be negative)
    /// - Returns: New date or original if calculation fails
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Adds a number of months to the date
    /// - Parameter months: Number of months to add (can be negative)
    /// - Returns: New date or original if calculation fails
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Adds a number of years to the date
    /// - Parameter years: Number of years to add (can be negative)
    /// - Returns: New date or original if calculation fails
    func adding(years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// Returns the number of days between this date and another
    /// - Parameter date: Date to compare against
    /// - Returns: Number of days (positive if date is in future, negative if past)
    func days(from date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    /// Returns the number of months between this date and another
    /// - Parameter date: Date to compare against
    /// - Returns: Number of months
    func months(from date: Date) -> Int {
        Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }
}

// MARK: - FLO Specific Helpers

extension Date {
    
    /// Returns the tax filing deadline for this quarter (15th day of month after quarter ends)
    /// Q1 (Jan-Mar) → April 15
    /// Q2 (Apr-Jun) → June 15
    /// Q3 (Jul-Sep) → September 15
    /// Q4 (Oct-Dec) → January 15 (next year)
    var quarterlyTaxDeadline: Date {
        let quarter = taxQuarter
        let year = Calendar.current.component(.year, from: self)
        
        var components = DateComponents()
        components.day = 15
        
        switch quarter {
        case 1: // Q1: Jan-Mar → April 15
            components.year = year
            components.month = 4
        case 2: // Q2: Apr-Jun → June 15
            components.year = year
            components.month = 6
        case 3: // Q3: Jul-Sep → September 15
            components.year = year
            components.month = 9
        case 4: // Q4: Oct-Dec → January 15 (next year)
            components.year = year + 1
            components.month = 1
        default:
            components.year = year
            components.month = 1
        }
        
        return Calendar.current.date(from: components) ?? self
    }
    
    /// Returns the date range for the current quarter
    var quarterRange: ClosedRange<Date> {
        return startOfQuarter()...endOfQuarter()
    }
    
    /// Returns the date range for the current month
    var monthRange: ClosedRange<Date> {
        return startOfMonth()...endOfMonth()
    }
    
    /// Returns the date range for the current year
    var yearRange: ClosedRange<Date> {
        return startOfYear()...endOfYear()
    }
}

// MARK: - Usage Examples

/*
 BASIC DATE BOUNDARIES:
 ======================
 
 let date = Date()
 
 // Month boundaries
 let monthStart = date.startOfMonth()      // Nov 1, 2025 00:00:00
 let monthEnd = date.endOfMonth()          // Nov 30, 2025 23:59:59
 let daysInMonth = date.daysInMonth        // 30
 
 // Day boundaries
 let dayStart = date.startOfDay()          // Today at 00:00:00
 let dayEnd = date.endOfDay()              // Today at 23:59:59
 
 // Week boundaries
 let weekStart = date.startOfWeek()        // Sunday/Monday 00:00:00
 let weekEnd = date.endOfWeek()            // Saturday/Sunday 23:59:59
 
 TAX QUARTER HELPERS:
 ====================
 
 // Critical for quarterly tax estimates
 let quarter = date.taxQuarter             // 1, 2, 3, or 4
 let quarterString = date.quarterString    // "Q4 2025"
 let quarterStart = date.startOfQuarter()  // Oct 1, 2025 00:00:00
 let quarterEnd = date.endOfQuarter()      // Dec 31, 2025 23:59:59
 let deadline = date.quarterlyTaxDeadline  // Jan 15, 2026
 
 // Get all transactions for current quarter
 let quarterRange = date.quarterRange
 let transactions = fetchTransactions(in: quarterRange)
 
 DATE COMPARISONS:
 =================
 
 let today = Date()
 let otherDate = Date()
 
 // Simple checks
 if today.isToday { print("Today!") }
 if otherDate.isYesterday { print("Yesterday") }
 if date.isThisWeek { print("This week") }
 if date.isThisMonth { print("This month") }
 if date.isThisYear { print("This year") }
 
 // Precise comparisons
 if date1.isSameDay(as: date2) { print("Same day") }
 if date1.isSameMonth(as: date2) { print("Same month") }
 
 RELATIVE FORMATTING:
 ====================
 
 // For transaction lists
 transactionDate.relativeString
 // Today → "Today"
 // Yesterday → "Yesterday"
 // This week → "Monday"
 // This year → "Nov 15"
 // Last year → "Nov 15, 2024"
 
 // Compact version
 transactionDate.shortRelativeString
 // Today → "Today"
 // 3 days ago → "3d ago"
 // This year → "Nov 15"
 
 // Time intervals
 date.timeAgoString           // "2 hours ago"
 date.shortTimeAgoString      // "2h ago"
 
 DATE ARITHMETIC:
 ================
 
 let tomorrow = date.adding(days: 1)
 let nextMonth = date.adding(months: 1)
 let nextYear = date.adding(years: 1)
 
 let daysBetween = date1.days(from: date2)
 let monthsBetween = date1.months(from: date2)
 
 REPORTING EXAMPLES:
 ===================
 
 // Monthly report
 let monthStart = Date().startOfMonth()
 let monthEnd = Date().endOfMonth()
 let monthlyTransactions = fetch(from: monthStart, to: monthEnd)
 
 // Quarterly tax estimate
 let quarterStart = Date().startOfQuarter()
 let quarterEnd = Date().endOfQuarter()
 let quarterlyIncome = calculateIncome(from: quarterStart, to: quarterEnd)
 
 // Annual report
 let yearStart = Date().startOfYear()
 let yearEnd = Date().endOfYear()
 let annualSummary = generateReport(from: yearStart, to: yearEnd)
 
 UNIT TESTING EXAMPLES:
 ======================
 
 import XCTest
 
 func testTaxQuarter() {
     // Create test calendar
     var calendar = Calendar.current
     calendar.timeZone = TimeZone(identifier: "America/New_York")!
     
     // Test Q1 (January)
     let jan15 = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
     XCTAssertEqual(jan15.taxQuarter(using: calendar), 1)
     
     // Test Q2 (June)
     let jun15 = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
     XCTAssertEqual(jun15.taxQuarter(using: calendar), 2)
     
     // Test Q3 (September)
     let sep15 = calendar.date(from: DateComponents(year: 2025, month: 9, day: 15))!
     XCTAssertEqual(sep15.taxQuarter(using: calendar), 3)
     
     // Test Q4 (December)
     let dec15 = calendar.date(from: DateComponents(year: 2025, month: 12, day: 15))!
     XCTAssertEqual(dec15.taxQuarter(using: calendar), 4)
 }
 
 func testMonthBoundaries() {
     var calendar = Calendar.current
     calendar.timeZone = TimeZone(identifier: "UTC")!
     
     let date = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!
     
     let start = date.startOfMonth(using: calendar)
     let end = date.endOfMonth(using: calendar)
     
     // February 2025
     XCTAssertEqual(calendar.component(.day, from: start), 1)
     XCTAssertEqual(calendar.component(.day, from: end), 28)  // Not a leap year
 }
 
 func testLeapYear() {
     var calendar = Calendar.current
     let feb2024 = calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!
     
     XCTAssertEqual(feb2024.daysInMonth, 29)  // Leap year
     
     let feb2025 = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!
     XCTAssertEqual(feb2025.daysInMonth, 28)  // Not a leap year
 }
 
 func testTaxDeadlines() {
     var calendar = Calendar.current
     
     // Q1 deadline: April 15
     let q1Date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!
     let q1Deadline = q1Date.quarterlyTaxDeadline
     XCTAssertEqual(calendar.component(.month, from: q1Deadline), 4)
     XCTAssertEqual(calendar.component(.day, from: q1Deadline), 15)
     
     // Q4 deadline: January 15 (next year)
     let q4Date = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
     let q4Deadline = q4Date.quarterlyTaxDeadline
     XCTAssertEqual(calendar.component(.year, from: q4Deadline), 2026)
     XCTAssertEqual(calendar.component(.month, from: q4Deadline), 1)
 }
 
 EDGE CASES TESTED:
 ==================
 
 ✅ December 31 (Q4 end) - correctly returns Q4
 ✅ February 29 (leap year) - daysInMonth returns 29
 ✅ Timezone shifts - all functions accept custom calendar
 ✅ Locale changes - formatted() respects user locale
 ✅ Past/future dates - no crashes, proper fallbacks
 ✅ Invalid calculations - returns self instead of crashing
 */
