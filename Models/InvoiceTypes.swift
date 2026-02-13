//  InvoiceTypes.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - ReminderRecord as Codable struct (not @Model)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shared types for invoice management
//
//  CHANGES v2.2:
//  ✅ Converted ReminderRecord from @Model to Codable struct
//  ✅ ReminderRecord is now embedded data owned by Invoice
//  ✅ Eliminates SwiftData relationship issues
//  ✅ Removed SwiftData import (not needed for supporting types)
//

import Foundation

// MARK: - Invoice Statistics

struct InvoiceStats {
    let totalOutstanding: Double
    let overdueCount: Int
    let overdueAmount: Double
    let dueThisWeek: Int
    let averageDaysToPayment: Double?
    var totalPaidThisMonth: Double = 0
    var paidCountThisMonth: Int = 0
    
    var hasOverdue: Bool {
        overdueCount > 0
    }
    
    var formattedTotalOutstanding: String {
        totalOutstanding.formatted(.currency(code: "USD"))
    }
    
    var formattedOverdueAmount: String {
        overdueAmount.formatted(.currency(code: "USD"))
    }
    
    var formattedAverageDays: String? {
        guard let days = averageDaysToPayment else { return nil }
        return String(format: "%.0f days", days)
    }
}

// MARK: - Invoice Status

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft = "Draft"
    case sent = "Sent"
    case viewed = "Viewed"
    case paid = "Paid"
    case partiallyPaid = "Partially Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"
    
    var icon: String {
        switch self {
        case .draft: return "doc.text"
        case .sent: return "paperplane"
        case .viewed: return "eye"
        case .paid: return "checkmark.circle.fill"
        case .partiallyPaid: return "circle.lefthalf.filled"
        case .overdue: return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .draft: return "gray"
        case .sent: return "blue"
        case .viewed: return "cyan"
        case .paid: return "green"
        case .partiallyPaid: return "orange"
        case .overdue: return "red"
        case .cancelled: return "gray"
        }
    }
    
    var isFinal: Bool {
        self == .paid || self == .cancelled
    }
    
    var canSendReminder: Bool {
        [.sent, .viewed, .partiallyPaid, .overdue].contains(self)
    }
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Aging Buckets

enum AgingBucket: String, Codable, CaseIterable {
    case current = "Current (Not Due)"
    case days1to30 = "1-30 Days"
    case days31to60 = "31-60 Days"
    case days61to90 = "61-90 Days"
    case days90Plus = "90+ Days"
    
    var icon: String {
        switch self {
        case .current: return "checkmark.circle"
        case .days1to30: return "clock"
        case .days31to60: return "clock.fill"
        case .days61to90: return "exclamationmark.circle"
        case .days90Plus: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .current: return "green"
        case .days1to30: return "blue"
        case .days31to60: return "yellow"
        case .days61to90: return "orange"
        case .days90Plus: return "red"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .current: return "Current"
        case .days1to30: return "1–30"
        case .days31to60: return "31–60"
        case .days61to90: return "61–90"
        case .days90Plus: return "90+"
        }
    }
    
    static func bucket(for invoice: Invoice) -> AgingBucket {
        let daysOverdue = max(invoice.daysOverdue, 0) // Defensive
        
        switch daysOverdue {
        case ..<0:
            return .current
        case 0...30:
            return .days1to30
        case 31...60:
            return .days31to60
        case 61...90:
            return .days61to90
        default:
            return .days90Plus
        }
    }
}

// MARK: - Urgency Level

enum UrgencyLevel: String, Codable, CaseIterable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .none: return "gray"
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return ""
        case .low: return "exclamationmark.triangle"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon"
        case .critical: return "exclamationmark.shield.fill"
        }
    }
}

// MARK: - Reminder Types

enum ReminderType: String, Codable, CaseIterable {
    case gentle = "Gentle Reminder"
    case standard = "Payment Reminder"
    case firm = "Overdue Notice"
    case final = "Final Notice"
    
    var level: Int {
        switch self {
        case .gentle: return 1
        case .standard: return 2
        case .firm: return 3
        case .final: return 4
        }
    }
    
    var daysThreshold: Int {
        switch self {
        case .gentle: return -3   // 3 days before due
        case .standard: return 1   // 1 day after due
        case .firm: return 14
        case .final: return 30
        }
    }
    
    var notificationTitle: String {
        switch self {
        case .gentle: return "Invoice Reminder"
        case .standard: return "Payment Reminder"
        case .firm: return "⚠️ Invoice Overdue"
        case .final: return "🚨 Final Notice"
        }
    }
    
    var emailTone: String {
        switch self {
        case .gentle: return "Friendly and understanding"
        case .standard: return "Professional and direct"
        case .firm: return "Firm but respectful"
        case .final: return "Urgent and serious"
        }
    }
}

// MARK: - Email Reminder

struct EmailReminder {
    let subject: String
    let body: String
}

// MARK: - Reminder Record (Embedded Data)
// This is embedded data owned by Invoice, not a separate SwiftData model.
// Stored as JSON-encoded array in Invoice.remindersSent

struct ReminderRecord: Codable, Identifiable, Hashable {
    var id: UUID
    var date: Date
    var daysOverdue: Int
    var reminderType: ReminderType
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        daysOverdue: Int,
        reminderType: ReminderType
    ) {
        self.id = id
        self.date = date
        self.daysOverdue = daysOverdue
        self.reminderType = reminderType
    }
}

// MARK: - Extensions

extension Collection where Element == ReminderRecord {
    var lastSentType: ReminderType? {
        self.max(by: { $0.date < $1.date })?.reminderType
    }
}
