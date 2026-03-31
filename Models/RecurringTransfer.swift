//  RecurringTransfer.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Recurring Transfer Model
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Model for scheduled recurring transfers like monthly owner's draws,
//  regular debt payments, or quarterly tax payments.
//
//  FEATURES:
//  ✅ Flexible frequency: daily, weekly, biweekly, monthly, quarterly, yearly
//  ✅ End conditions: never, after N occurrences, or by end date
//  ✅ Auto-generation of Transfer records
//  ✅ Skip/pause capability
//  ✅ Last generated tracking to prevent duplicates
//

import Foundation
import SwiftData

// MARK: - Recurring Transfer Model

@Model
final class RecurringTransfer {
    
    // MARK: - Identifiers

    private(set) var id: UUID = UUID()

    // MARK: - Schedule Properties

    /// User-defined name for this recurring transfer
    var name: String = ""

    /// Amount to transfer each occurrence (always positive)
    var amount: Double = 0.0

    /// Type of transfer (Owner's Draw, Tax Payment, etc.)
    var transferTypeRaw: String = TransferType.ownersDraw.rawValue

    /// How often the transfer occurs
    var frequencyRaw: String = RecurringFrequency.monthly.rawValue

    /// Day of month for monthly transfers (1-31, 0 = last day)
    var dayOfMonth: Int?

    /// Day of week for weekly transfers (1=Sunday, 7=Saturday)
    var dayOfWeek: Int?

    /// Start date for the recurring schedule
    var startDate: Date = Date()

    /// End date (nil = no end date)
    var endDate: Date?

    /// Maximum number of occurrences (nil = unlimited)
    var maxOccurrences: Int?

    // MARK: - Account References

    /// Source account (money leaves this account)
    @Relationship(deleteRule: .nullify)
    var fromAccount: Account?

    /// Destination account (money enters this account)
    @Relationship(deleteRule: .nullify)
    var toAccount: Account?

    // MARK: - Tax Payment Specifics

    /// For recurring tax payments: which authority
    var taxAuthorityRaw: String?

    // MARK: - State Tracking

    /// Whether this recurring transfer is active
    var isActive: Bool = true

    /// Date of the last generated transfer
    var lastGeneratedDate: Date?

    /// Count of transfers generated from this recurring
    var generatedCount: Int = 0

    /// User notes
    var notes: String?

    // MARK: - Generated Transfers

    /// All transfers generated from this recurring
    @Relationship(deleteRule: .nullify, inverse: \Transfer.recurringTransfer)
    var generatedTransfers: [Transfer]?

    // MARK: - Audit Trail

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // MARK: - Initialization
    
    init(
        name: String,
        amount: Double,
        transferType: TransferType = .ownersDraw,
        frequency: RecurringFrequency = .monthly,
        dayOfMonth: Int? = 1,
        dayOfWeek: Int? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        maxOccurrences: Int? = nil,
        fromAccount: Account? = nil,
        toAccount: Account? = nil,
        taxAuthority: TaxAuthority? = nil,
        isActive: Bool = true,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = abs(amount)
        self.transferTypeRaw = transferType.rawValue
        self.frequencyRaw = frequency.rawValue
        self.dayOfMonth = dayOfMonth
        self.dayOfWeek = dayOfWeek
        self.startDate = startDate
        self.endDate = endDate
        self.maxOccurrences = maxOccurrences
        self.fromAccount = fromAccount
        self.toAccount = toAccount
        self.taxAuthorityRaw = taxAuthority?.rawValue
        self.isActive = isActive
        self.notes = notes
        self.lastGeneratedDate = nil
        self.generatedCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Typed Accessors
    
    var transferType: TransferType {
        get { TransferType(rawValue: transferTypeRaw) ?? .ownersDraw }
        set { transferTypeRaw = newValue.rawValue }
    }
    
    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }
    
    var taxAuthority: TaxAuthority? {
        get { taxAuthorityRaw.flatMap { TaxAuthority(rawValue: $0) } }
        set { taxAuthorityRaw = newValue?.rawValue }
    }
    
    // MARK: - Computed Properties
    
    /// Display-friendly description
    var displayDescription: String {
        let from = fromAccount?.name ?? "Unknown"
        let to = toAccount?.name ?? "Unknown"
        return "\(from) → \(to)"
    }
    
    /// Formatted amount
    var formattedAmount: String {
        NumberFormatter.appCurrency.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    /// Whether this recurring has reached its end condition
    var isExpired: Bool {
        // Check end date
        if let endDate = endDate, Date() > endDate {
            return true
        }
        
        // Check max occurrences
        if let max = maxOccurrences, generatedCount >= max {
            return true
        }
        
        return false
    }
    
    /// Whether a new transfer should be generated today
    var isDueToday: Bool {
        guard isActive && !isExpired else { return false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // If never generated, check if start date is today or past
        guard lastGeneratedDate != nil else {
            return calendar.startOfDay(for: startDate) <= today
        }
        
        // Calculate next due date
        guard let nextDue = nextDueDate else { return false }
        return calendar.startOfDay(for: nextDue) <= today
    }
    
    /// Calculate the next due date based on frequency
    var nextDueDate: Date? {
        guard isActive && !isExpired else { return nil }
        
        let calendar = Calendar.current
        let baseDate = lastGeneratedDate ?? calendar.date(byAdding: .day, value: -1, to: startDate)!
        
        var nextDate: Date?
        
        switch frequency {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: 1, to: baseDate)
            
        case .weekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
            
        case .biweekly:
            nextDate = calendar.date(byAdding: .weekOfYear, value: 2, to: baseDate)
            
        case .monthly:
            // Move to next month
            var components = calendar.dateComponents([.year, .month], from: baseDate)
            components.month! += 1
            
            // Set the day
            if let day = dayOfMonth {
                if day == 0 {
                    // Last day of month
                    components.month! += 1
                    components.day = 0
                } else {
                    components.day = min(day, 28)  // Safe for all months
                }
            } else {
                components.day = calendar.component(.day, from: baseDate)
            }
            
            nextDate = calendar.date(from: components)
            
        case .quarterly:
            nextDate = calendar.date(byAdding: .month, value: 3, to: baseDate)
            
        case .yearly:
            nextDate = calendar.date(byAdding: .year, value: 1, to: baseDate)
        }
        
        // Ensure we don't go past end date
        if let end = endDate, let next = nextDate, next > end {
            return nil
        }
        
        return nextDate
    }
    
    /// Human-readable schedule description
    var scheduleDescription: String {
        var desc = frequency.displayName
        
        if frequency == .monthly, let day = dayOfMonth {
            if day == 0 {
                desc += " (last day)"
            } else {
                let suffix: String
                switch day {
                case 1, 21, 31: suffix = "st"
                case 2, 22:     suffix = "nd"
                case 3, 23:     suffix = "rd"
                default:        suffix = "th"
                }
                desc += " (on the \(day)\(suffix))"
            }
        }
        
        if let end = endDate {
            desc += " until \(DateFormatter.mediumDate.string(from: end))"
        } else if let max = maxOccurrences {
            let remaining = max - generatedCount
            desc += " (\(remaining) remaining)"
        }
        
        return desc
    }
}

// MARK: - Recurring Frequency Enum

enum RecurringFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily:     return "Daily"
        case .weekly:    return "Weekly"
        case .biweekly:  return "Every 2 Weeks"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly:    return "Yearly"
        }
    }
    
    var shortName: String {
        switch self {
        case .daily:     return "Day"
        case .weekly:    return "Week"
        case .biweekly:  return "2 Wks"
        case .monthly:   return "Month"
        case .quarterly: return "Qtr"
        case .yearly:    return "Year"
        }
    }
    
    var icon: String {
        switch self {
        case .daily:     return "calendar.day.timeline.left"
        case .weekly:    return "calendar.badge.clock"
        case .biweekly:  return "calendar.badge.clock"
        case .monthly:   return "calendar"
        case .quarterly: return "calendar.badge.plus"
        case .yearly:    return "calendar.circle"
        }
    }
}

// MARK: - Protocol Conformances

extension RecurringTransfer: Identifiable { }

extension RecurringTransfer: Equatable {
    static func == (lhs: RecurringTransfer, rhs: RecurringTransfer) -> Bool {
        lhs.id == rhs.id
    }
}

extension RecurringTransfer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension RecurringTransfer {
    
    @MainActor static var previewMonthlyDraw: RecurringTransfer {
        RecurringTransfer(
            name: "Monthly Owner's Draw",
            amount: 2500.00,
            transferType: .ownersDraw,
            frequency: .monthly,
            dayOfMonth: 1,
            notes: "Pay myself on the 1st"
        )
    }
    
    @MainActor static var previewQuarterlyTax: RecurringTransfer {
        RecurringTransfer(
            name: "Quarterly Federal Tax",
            amount: 3500.00,
            transferType: .taxPayment,
            frequency: .quarterly,
            taxAuthority: .federalIRS,
            notes: "IRS estimated payments"
        )
    }
    
    @MainActor static var previewWeeklyTransfer: RecurringTransfer {
        RecurringTransfer(
            name: "Weekly Savings",
            amount: 500.00,
            transferType: .internal,
            frequency: .weekly,
            dayOfWeek: 6,  // Friday
            notes: "Auto-save every Friday"
        )
    }
}
#endif
