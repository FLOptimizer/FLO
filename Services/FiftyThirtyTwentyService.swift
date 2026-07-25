//  FiftyThirtyTwentyService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — 50/30/20 rule calculations for need/want/savings budgets
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Pure calculation layer behind the color-coded 50/30/20 bar on the budget
//  list. Income basis is actual personal income transactions for the month,
//  falling back to the previous month before the first paycheck lands.
//

import Foundation

// MARK: - Result Types

/// How a purpose bucket compares to its 50/30/20 target share of income.
enum PurposeStatus: Equatable {
    case under
    case onTrack
    case over

    /// Whether this status is financially healthy for the given purpose.
    /// Under is good for needs/wants; over is good for savings.
    func isHealthy(for purpose: BudgetPurpose) -> Bool {
        switch self {
        case .onTrack: return true
        case .under:   return !purpose.higherIsBetter
        case .over:    return purpose.higherIsBetter
        }
    }
}

/// One row of the 50/30/20 summary: a purpose, what flowed through it this
/// month, and how that compares to the rule's target share of income.
struct PurposeBucketSummary: Identifiable {
    let purpose: BudgetPurpose
    let spent: Double
    /// spent ÷ income (0 when income is 0)
    let share: Double
    let status: PurposeStatus

    var id: String { purpose.rawValue }
    var targetShare: Double { purpose.targetShare }
    var isHealthy: Bool { status.isHealthy(for: purpose) }
}

/// Income figure used for the percentages, with provenance for the UI footnote.
struct MonthlyIncomeBasis: Equatable {
    let amount: Double
    /// True when this month had no income yet and the previous month was used.
    let usedPreviousMonth: Bool
}

// MARK: - Service

enum FiftyThirtyTwentyService {

    /// Shares within ±2 percentage points of target count as "right on track".
    static let onTrackTolerance = 0.02

    // MARK: Income

    /// Actual personal income for the month containing `monthStart`.
    /// Mirrors the budget list's transaction filters (skips transfers).
    static func monthlyIncome(
        for monthStart: Date,
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> Double {
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }

        let incomeTotal = transactions
            .filter { txn in
                txn.isIncome
                    && !txn.isTransfer
                    && txn.financeType == .personal
                    && txn.date >= monthStart && txn.date <= monthEnd
            }
            .reduce(0) { $0 + $1.amount }

        return abs(incomeTotal)
    }

    /// Actuals-with-fallback: this month's income, or the previous month's
    /// when nothing has landed yet (early-month paycheck gap).
    static func incomeBasis(
        for monthStart: Date,
        transactions: [Transaction],
        calendar: Calendar = .current
    ) -> MonthlyIncomeBasis {
        let current = monthlyIncome(for: monthStart, transactions: transactions, calendar: calendar)
        if current > 0 {
            return MonthlyIncomeBasis(amount: current, usedPreviousMonth: false)
        }

        guard let previousStart = calendar.date(byAdding: .month, value: -1, to: monthStart) else {
            return MonthlyIncomeBasis(amount: 0, usedPreviousMonth: false)
        }
        let previous = monthlyIncome(for: previousStart, transactions: transactions, calendar: calendar)
        return MonthlyIncomeBasis(amount: previous, usedPreviousMonth: previous > 0)
    }

    // MARK: Buckets

    /// Status of a share against a purpose's target under the rule.
    static func status(share: Double, target: Double) -> PurposeStatus {
        // Small epsilon keeps exact-boundary shares (e.g. 52% vs 50% target)
        // on-track despite floating-point representation drift.
        let epsilon = 1e-9
        if abs(share - target) <= onTrackTolerance + epsilon { return .onTrack }
        return share < target ? .under : .over
    }

    /// Aggregates per-budget spending into the three purpose buckets.
    /// - Parameter classifiedSpending: (purpose, spent) pairs — one per
    ///   classified budget. Unclassified budgets are excluded upstream.
    /// - Returns: A summary for each purpose that has at least one classified
    ///   budget, in fixed need → want → savings order.
    static func summaries(
        classifiedSpending: [(purpose: BudgetPurpose, spent: Double)],
        income: Double
    ) -> [PurposeBucketSummary] {
        BudgetPurpose.allCases.compactMap { purpose in
            let entries = classifiedSpending.filter { $0.purpose == purpose }
            guard !entries.isEmpty else { return nil }

            let spent = entries.reduce(0) { $0 + $1.spent }
            let share = income > 0 ? spent / income : 0
            return PurposeBucketSummary(
                purpose: purpose,
                spent: spent,
                share: share,
                status: status(share: share, target: purpose.targetShare)
            )
        }
    }
}
