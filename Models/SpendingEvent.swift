//  SpendingEvent.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Time-bounded expense grouping ("Events")
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  A second dimension of categorization: transactions keep their normal
//  category (dining, gas, fees) and can additionally belong to one Event —
//  a named date range like "Baseball trip, Jul 4–12". Events answer "what
//  occasion caused this spending?" and explain month-over-month spikes.
//
//  CloudKit rules honored: all attributes defaulted, relationships optional,
//  no unique constraints.
//

import Foundation
import SwiftData

@Model
final class SpendingEvent {
    var id: UUID = UUID()

    /// User-facing name, e.g. "Baseball trip", "Christmas", "SF conference"
    var name: String = ""

    /// First day of the event (inclusive)
    var startDate: Date = Date()

    /// Last day of the event (inclusive)
    var endDate: Date = Date()

    var notes: String = ""

    /// SF Symbol shown next to the event
    var icon: String = "airplane"

    var createdDate: Date = Date()

    /// Transactions assigned to this event (inverse of Transaction.event)
    @Relationship(deleteRule: .nullify, inverse: \Transaction.event)
    var transactions: [Transaction]?

    init(
        name: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        icon: String = "airplane"
    ) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.icon = icon
        self.createdDate = Date()
    }

    // MARK: - Computed Properties

    /// Whether the given date falls inside the event's range (whole days)
    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: startDate)
            && day <= calendar.startOfDay(for: endDate)
    }

    /// Whether the event covers today
    var isActive: Bool {
        contains(Date())
    }

    var durationDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startDate),
            to: calendar.startOfDay(for: endDate)
        ).day ?? 0
        return days + 1
    }

    /// Total spent (expenses only; income during an event isn't a cost)
    var totalSpent: Double {
        (transactions ?? [])
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }

    var transactionCount: Int {
        transactions?.count ?? 0
    }

    /// Expense totals grouped by category name, largest first
    var categoryBreakdown: [(name: String, icon: String, total: Double)] {
        let expenses = (transactions ?? []).filter { !$0.isIncome }
        var totals: [String: (icon: String, total: Double)] = [:]
        for tx in expenses {
            let key = tx.category?.name ?? "Uncategorized"
            let icon = tx.category?.icon ?? "questionmark.circle"
            totals[key, default: (icon, 0)].total += tx.amount
        }
        return totals
            .map { (name: $0.key, icon: $0.value.icon, total: $0.value.total) }
            .sorted { $0.total > $1.total }
    }

    var dateRangeDisplay: String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate, to: endDate)
    }
}
