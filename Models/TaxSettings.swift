//  TaxSettings.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Updated with 2026 IRS tax brackets and deadlines
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Tax configuration and settings model
//
//  CHANGES IN v2.2:
//  ✅ Updated to 2026 federal tax brackets (projected ~2.8% inflation adjustment)
//  ✅ Updated to 2026 standard deductions (inflation-adjusted)
//  ✅ Added 2026 quarterly estimated tax deadlines
//  ✅ Added dynamic year detection for brackets and deadlines
//  ✅ Added Social Security wage base for 2026 ($176,100)
//  ✅ Retained all v2.1 functionality
//
//  CHANGES IN v2.1:
//  - Updated to official 2025 federal tax brackets (Rev. Proc. 2024-40)
//  - Updated to 2025 standard deductions (inflation-adjusted)
//  - Added @Attribute(.unique) to id for data integrity
//

import Foundation
import SwiftData

@Model
final class TaxSettings {
    // MARK: - Properties
    
    /// Unique identifier (should only ever be one TaxSettings record)
    @Attribute(.unique) var id: UUID
    
    /// User's state for state tax calculations
    var state: String
    
    /// User's federal filing status
    var filingStatus: FilingStatus
    
    /// Estimated federal tax rate (if user wants to override calculated rate)
    var customFederalRate: Double?
    
    /// Estimated state tax rate (if user wants to override)
    var customStateRate: Double?
    
    /// Whether to include self-employment tax in calculations
    var includeSelfEmploymentTax: Bool
    
    /// Self-employment tax rate (default 15.3% = 12.4% Social Security + 2.9% Medicare)
    /// Note: This is the IRS standard rate. While legally fixed, we keep it configurable
    /// for edge cases and testing scenarios. UI should display as "15.3% (IRS standard)".
    var selfEmploymentTaxRate: Double
    
    /// Whether to enable quarterly tax notifications
    var enableQuarterlyReminders: Bool
    
    /// How many days before deadline to send first reminder
    var reminderDaysBefore: Int
    
    /// Prior year's tax liability (for safe harbor calculation)
    var priorYearTaxLiability: Double?
    
    /// Whether user is high earner (>$150K AGI) requiring 110% safe harbor
    var isHighEarner: Bool
    
    /// Date when settings were last updated
    var lastUpdated: Date
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        state: String = "CA",
        filingStatus: FilingStatus = .single,
        customFederalRate: Double? = nil,
        customStateRate: Double? = nil,
        includeSelfEmploymentTax: Bool = true,
        selfEmploymentTaxRate: Double = 0.153,
        enableQuarterlyReminders: Bool = true,
        reminderDaysBefore: Int = 14,
        priorYearTaxLiability: Double? = nil,
        isHighEarner: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.state = state
        self.filingStatus = filingStatus
        self.customFederalRate = customFederalRate
        self.customStateRate = customStateRate
        self.includeSelfEmploymentTax = includeSelfEmploymentTax
        self.selfEmploymentTaxRate = selfEmploymentTaxRate
        self.enableQuarterlyReminders = enableQuarterlyReminders
        self.reminderDaysBefore = reminderDaysBefore
        self.priorYearTaxLiability = priorYearTaxLiability
        self.isHighEarner = isHighEarner
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Filing Status

extension TaxSettings {
    enum FilingStatus: String, Codable, CaseIterable {
        case single = "Single"
        case marriedFilingJointly = "Married Filing Jointly"
        case marriedFilingSeparately = "Married Filing Separately"
        case headOfHousehold = "Head of Household"
        
        var displayName: String {
            return self.rawValue
        }
    }
}

// MARK: - Tax Year Detection

extension TaxSettings {
    /// Get the current tax year based on the date
    static func currentTaxYear(for date: Date = Date()) -> Int {
        Calendar.current.component(.year, from: date)
    }
}

// MARK: - Tax Bracket Data (2026)

extension TaxSettings {
    /// Federal tax brackets for 2026 tax year (projected ~2.8% inflation adjustment from 2025)
    /// Note: Official IRS rates released in Rev. Proc. 2025-XX (typically October/November)
    /// These are projected values based on historical inflation adjustments
    static func federalTaxBrackets2026(for filingStatus: FilingStatus) -> [(maxIncome: Double, rate: Double)] {
        switch filingStatus {
        case .single:
            return [
                (12_260, 0.10),     // 10% on income up to $12,260
                (49_830, 0.12),     // 12% on income $12,260 to $49,830
                (106_250, 0.22),    // 22% on income $49,830 to $106,250
                (202_820, 0.24),    // 24% on income $106,250 to $202,820
                (257_540, 0.32),    // 32% on income $202,820 to $257,540
                (643_880, 0.35),    // 35% on income $257,540 to $643,880
                (.infinity, 0.37)   // 37% on income over $643,880
            ]
            
        case .marriedFilingJointly:
            return [
                (24_520, 0.10),     // 10% on income up to $24,520
                (99_660, 0.12),     // 12% on income $24,520 to $99,660
                (212_490, 0.22),    // 22% on income $99,660 to $212,490
                (405_650, 0.24),    // 24% on income $212,490 to $405,650
                (515_080, 0.32),    // 32% on income $405,650 to $515,080
                (772_650, 0.35),    // 35% on income $515,080 to $772,650
                (.infinity, 0.37)   // 37% on income over $772,650
            ]
            
        case .marriedFilingSeparately:
            return [
                (12_260, 0.10),     // 10% on income up to $12,260
                (49_830, 0.12),     // 12% on income $12,260 to $49,830
                (106_250, 0.22),    // 22% on income $49,830 to $106,250
                (202_820, 0.24),    // 24% on income $106,250 to $202,820
                (257_540, 0.32),    // 32% on income $202,820 to $257,540
                (386_330, 0.35),    // 35% on income $257,540 to $386,330
                (.infinity, 0.37)   // 37% on income over $386,330
            ]
            
        case .headOfHousehold:
            return [
                (17_480, 0.10),     // 10% on income up to $17,480
                (66_670, 0.12),     // 12% on income $17,480 to $66,670
                (106_250, 0.22),    // 22% on income $66,670 to $106,250
                (202_820, 0.24),    // 24% on income $106,250 to $202,820
                (257_510, 0.32),    // 32% on income $202,820 to $257,510
                (643_880, 0.35),    // 35% on income $257,510 to $643,880
                (.infinity, 0.37)   // 37% on income over $643,880
            ]
        }
    }
    
    /// Federal tax brackets for 2025 tax year (per IRS Rev. Proc. 2024-40)
    static func federalTaxBrackets2025(for filingStatus: FilingStatus) -> [(maxIncome: Double, rate: Double)] {
        switch filingStatus {
        case .single:
            return [
                (11_925, 0.10),
                (48_475, 0.12),
                (103_350, 0.22),
                (197_300, 0.24),
                (250_525, 0.32),
                (626_350, 0.35),
                (.infinity, 0.37)
            ]
            
        case .marriedFilingJointly:
            return [
                (23_850, 0.10),
                (96_950, 0.12),
                (206_700, 0.22),
                (394_600, 0.24),
                (501_050, 0.32),
                (751_600, 0.35),
                (.infinity, 0.37)
            ]
            
        case .marriedFilingSeparately:
            return [
                (11_925, 0.10),
                (48_475, 0.12),
                (103_350, 0.22),
                (197_300, 0.24),
                (250_525, 0.32),
                (375_800, 0.35),
                (.infinity, 0.37)
            ]
            
        case .headOfHousehold:
            return [
                (17_000, 0.10),
                (64_850, 0.12),
                (103_350, 0.22),
                (197_300, 0.24),
                (250_500, 0.32),
                (626_350, 0.35),
                (.infinity, 0.37)
            ]
        }
    }
    
    /// Get federal tax brackets for a specific year
    /// Automatically selects the correct brackets based on tax year
    static func federalTaxBrackets(for filingStatus: FilingStatus, year: Int? = nil) -> [(maxIncome: Double, rate: Double)] {
        let taxYear = year ?? currentTaxYear()
        
        switch taxYear {
        case 2026...:
            return federalTaxBrackets2026(for: filingStatus)
        case 2025:
            return federalTaxBrackets2025(for: filingStatus)
        default:
            // For older years, use 2025 brackets as fallback
            return federalTaxBrackets2025(for: filingStatus)
        }
    }
    
    /// Standard deduction amounts for 2026 tax year (projected ~2.8% inflation adjustment)
    static func standardDeduction2026(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single, .marriedFilingSeparately:
            return 15_420      // $15,420 for single filers in 2026 (up from $15,000)
        case .marriedFilingJointly:
            return 30_840      // $30,840 for married filing jointly in 2026 (up from $30,000)
        case .headOfHousehold:
            return 23_130      // $23,130 for head of household in 2026 (up from $22,500)
        }
    }
    
    /// Standard deduction amounts for 2025 tax year
    static func standardDeduction2025(for filingStatus: FilingStatus) -> Double {
        switch filingStatus {
        case .single, .marriedFilingSeparately:
            return 15_000
        case .marriedFilingJointly:
            return 30_000
        case .headOfHousehold:
            return 22_500
        }
    }
    
    /// Get standard deduction for a specific year
    static func standardDeduction(for filingStatus: FilingStatus, year: Int? = nil) -> Double {
        let taxYear = year ?? currentTaxYear()
        
        switch taxYear {
        case 2026...:
            return standardDeduction2026(for: filingStatus)
        case 2025:
            return standardDeduction2025(for: filingStatus)
        default:
            return standardDeduction2025(for: filingStatus)
        }
    }
    
    // MARK: - Social Security Wage Base
    
    /// Social Security wage base limits by year
    /// Income above this amount is not subject to the 12.4% Social Security portion of SE tax
    static func socialSecurityWageBase(for year: Int? = nil) -> Double {
        let taxYear = year ?? currentTaxYear()
        
        switch taxYear {
        case 2026...:
            return 176_100  // Projected 2026 (up from $168,600 in 2025)
        case 2025:
            return 168_600  // 2025 wage base
        case 2024:
            return 168_600  // 2024 wage base
        default:
            return 168_600
        }
    }
    
    /// State income tax rates (simplified - actual rates vary by income level)
    /// These are approximate middle-bracket rates for self-employed individuals
    /// For precise calculations, consult state-specific tax tables
    static let stateTaxRates: [String: Double] = [
        // States with no income tax
        "AK": 0.00, "FL": 0.00, "NV": 0.00, "NH": 0.00,
        "SD": 0.00, "TN": 0.00, "TX": 0.00, "WA": 0.00, "WY": 0.00,
        
        // States with flat tax rates
        "CO": 0.044, "IL": 0.0495, "IN": 0.0315, "KY": 0.04,
        "MA": 0.05, "MI": 0.0425, "NC": 0.0475, "PA": 0.0307,
        "UT": 0.0485,
        
        // States with progressive tax (using approximate middle rate for freelancers)
        "AL": 0.04, "AR": 0.055, "AZ": 0.045, "CA": 0.093,
        "CT": 0.065, "DE": 0.055, "GA": 0.055, "HI": 0.085,
        "ID": 0.058, "IA": 0.06, "KS": 0.057, "LA": 0.045,
        "MD": 0.055, "ME": 0.075, "MN": 0.09, "MO": 0.054,
        "MS": 0.05, "MT": 0.065, "NE": 0.068, "NJ": 0.065,
        "NM": 0.049, "NY": 0.065, "ND": 0.029, "OH": 0.039,
        "OK": 0.05, "OR": 0.09, "RI": 0.059, "SC": 0.065,
        "VT": 0.085, "VA": 0.055, "WI": 0.065, "WV": 0.065,
        "DC": 0.085
    ]
    
    // MARK: - Quarterly Deadlines
    
    /// IRS quarterly estimated tax payment deadlines for 2026
    static let quarterlyDeadlines2026: [Date] = {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        // Q1 2026 (for income Jan-Mar) - Due April 15, 2026
        if let q1 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15)) {
            dates.append(q1)
        }
        
        // Q2 2026 (for income Apr-May) - Due June 15, 2026
        if let q2 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15)) {
            dates.append(q2)
        }
        
        // Q3 2026 (for income Jun-Aug) - Due September 15, 2026
        if let q3 = calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)) {
            dates.append(q3)
        }
        
        // Q4 2026 (for income Sep-Dec) - Due January 15, 2027
        if let q4 = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15)) {
            dates.append(q4)
        }
        
        return dates
    }()
    
    /// IRS quarterly estimated tax payment deadlines for 2025
    static let quarterlyDeadlines2025: [Date] = {
        let calendar = Calendar.current
        var dates: [Date] = []
        
        if let q1 = calendar.date(from: DateComponents(year: 2025, month: 4, day: 15)) {
            dates.append(q1)
        }
        if let q2 = calendar.date(from: DateComponents(year: 2025, month: 6, day: 16)) {
            dates.append(q2)
        }
        if let q3 = calendar.date(from: DateComponents(year: 2025, month: 9, day: 15)) {
            dates.append(q3)
        }
        if let q4 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15)) {
            dates.append(q4)
        }
        
        return dates
    }()
    
    /// Get quarterly deadlines for a specific year
    static func quarterlyDeadlines(for year: Int? = nil) -> [Date] {
        let taxYear = year ?? currentTaxYear()
        
        switch taxYear {
        case 2026...:
            return quarterlyDeadlines2026
        case 2025:
            return quarterlyDeadlines2025
        default:
            return quarterlyDeadlines2025
        }
    }
    
    /// Get the next upcoming quarterly deadline
    static func nextQuarterlyDeadline(from date: Date = Date()) -> Date? {
        let year = currentTaxYear(for: date)
        let deadlines = quarterlyDeadlines(for: year)
        
        // Check current year's deadlines first
        if let next = deadlines.first(where: { $0 > date }) {
            return next
        }
        
        // If all current year deadlines passed, get next year's first deadline
        let nextYearDeadlines = quarterlyDeadlines(for: year + 1)
        return nextYearDeadlines.first
    }
    
    /// Get the current quarter's deadline
    static func currentQuarterDeadline(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        let deadlines = quarterlyDeadlines(for: year)
        
        guard deadlines.count >= 4 else { return nil }
        
        switch month {
        case 1...3:  // Q1: Jan-Mar
            return deadlines[0]
        case 4...5:  // Q2: Apr-May
            return deadlines[1]
        case 6...8:  // Q3: Jun-Aug
            return deadlines[2]
        case 9...12: // Q4: Sep-Dec
            return deadlines[3]
        default:
            return nil
        }
    }
    
    /// Get quarter number (1-4) for a date
    static func quarterNumber(for date: Date = Date()) -> Int {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 1...3: return 1
        case 4...5: return 2
        case 6...8: return 3
        case 9...12: return 4
        default: return 1
        }
    }
    
    /// Days until next quarterly deadline
    static func daysUntilNextDeadline(from date: Date = Date()) -> Int? {
        guard let deadline = nextQuarterlyDeadline(from: date) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: deadline).day
        return days
    }
}

// MARK: - Protocol Conformances

extension TaxSettings: Identifiable { }

extension TaxSettings: Equatable {
    static func == (lhs: TaxSettings, rhs: TaxSettings) -> Bool {
        lhs.id == rhs.id
    }
}

extension TaxSettings: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Version History
/*
 Version 2.2 (Current):
 - Updated to projected 2026 IRS tax brackets (~2.8% inflation adjustment)
 - Updated to projected 2026 standard deductions
 - Added 2026 quarterly estimated tax deadlines
 - Added dynamic year detection for automatic bracket selection
 - Added Social Security wage base tracking
 - Added helper functions for deadline calculations
 - Retained all 2025 data for backward compatibility
 
 Version 2.1:
 - Updated to 2025 IRS tax brackets (Rev. Proc. 2024-40)
 - Updated to 2025 standard deductions ($15K single, $30K MFJ, $22.5K HOH)
 - Added @Attribute(.unique) to id for data integrity
 
 Version 2.0:
 - Initial production release
 - 2024 tax brackets
 - Safe date handling with optional binding
 - Comprehensive state tax rates
 - Quarterly deadline tracking
 
 Note: 2026 brackets are projections based on historical ~2.8% annual inflation
 adjustments. Update with official IRS Rev. Proc. 2025-XX when released
 (typically October/November 2025).
 */
