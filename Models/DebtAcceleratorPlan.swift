//  DebtAcceleratorPlan.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Debt Accelerator Phase 1
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ DebtAcceleratorPlan — user's debt payoff optimization plan
//  ✅ ScheduledPayment — individual payment in the optimized schedule
//  ✅ Hybrid optimizer integration (avalanche + vault yield awareness)
//

import Foundation
import SwiftData

// MARK: - Debt Accelerator Plan

@Model
final class DebtAcceleratorPlan {
    var id: UUID = UUID()
    var name: String = "My Debt Plan"
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var isActive: Bool = true

    // Strategy configuration
    var strategyRaw: String = "hybrid"
    var monthlyBudget: Double = 0.0          // Total monthly amount user can put toward debt
    var extraMonthlyPayment: Double = 0.0    // Extra beyond minimums

    // Projected outcomes (cached from last optimization run)
    var projectedPayoffDate: Date?
    var projectedTotalInterest: Double = 0.0
    var projectedInterestSaved: Double = 0.0  // vs minimum-only
    var projectedMonthsSaved: Int = 0         // vs minimum-only
    var baselinePayoffDate: Date?             // Minimum-only payoff date for comparison
    var baselineTotalInterest: Double = 0.0   // Minimum-only total interest

    // Vault awareness
    var vaultAPY: Double = 0.0               // HYSA/vault yield (e.g., 4.5 for 4.5%)

    // Notification preferences
    var paymentRemindersEnabled: Bool = true
    var reminderDaysBefore: Int = 3           // Days before due date to remind

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \ScheduledPayment.plan)
    var scheduledPayments: [ScheduledPayment]?

    // Track which accounts are included
    var includedAccountIDs: [UUID] = []

    init(
        name: String = "My Debt Plan",
        monthlyBudget: Double = 0.0,
        extraMonthlyPayment: Double = 0.0,
        vaultAPY: Double = 0.0
    ) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isActive = true
        self.strategyRaw = "hybrid"
        self.monthlyBudget = monthlyBudget
        self.extraMonthlyPayment = extraMonthlyPayment
        self.vaultAPY = vaultAPY
        self.projectedTotalInterest = 0.0
        self.projectedInterestSaved = 0.0
        self.projectedMonthsSaved = 0
        self.baselineTotalInterest = 0.0
        self.paymentRemindersEnabled = true
        self.reminderDaysBefore = 3
        self.includedAccountIDs = []
    }

    // MARK: - Computed Properties

    var strategy: AcceleratorStrategy {
        get { AcceleratorStrategy(rawValue: strategyRaw) ?? .hybrid }
        set { strategyRaw = newValue.rawValue }
    }

    var totalDebtIncluded: Double {
        // Sum of scheduled payment balances at month 0 (will be calculated externally)
        0  // Populated by optimizer
    }

    var hasProjection: Bool {
        projectedPayoffDate != nil
    }

    var monthsUntilPayoff: Int? {
        guard let payoffDate = projectedPayoffDate else { return nil }
        let months = Calendar.current.dateComponents([.month], from: Date(), to: payoffDate).month
        return months
    }
}

// MARK: - Accelerator Strategy

enum AcceleratorStrategy: String, Codable, CaseIterable, Identifiable {
    case avalanche = "avalanche"       // Highest APR first
    case snowball = "snowball"         // Lowest balance first
    case hybrid = "hybrid"             // APR-weighted with vault yield awareness

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .avalanche: return "Avalanche"
        case .snowball: return "Snowball"
        case .hybrid: return "Smart Hybrid"
        }
    }

    var description: String {
        switch self {
        case .avalanche:
            return "Pay highest interest rate first to minimize total interest paid"
        case .snowball:
            return "Pay smallest balance first for motivational quick wins"
        case .hybrid:
            return "Intelligently prioritizes debts by comparing rates against your savings yield"
        }
    }

    var icon: String {
        switch self {
        case .avalanche: return "arrow.down.right.circle.fill"
        case .snowball: return "snowflake.circle.fill"
        case .hybrid: return "brain.fill"
        }
    }
}

// MARK: - Scheduled Payment

@Model
final class ScheduledPayment {
    var id: UUID = UUID()
    var plan: DebtAcceleratorPlan?

    // Which account this payment targets
    var accountID: UUID?
    var accountName: String = ""
    var debtTypeRaw: String = "other"

    // Payment details
    var month: Int = 0                      // Month number in the schedule (1-indexed)
    var scheduledDate: Date = Date()
    var minimumPayment: Double = 0.0
    var extraPayment: Double = 0.0          // Extra allocated by optimizer
    var totalPayment: Double = 0.0          // minimum + extra

    // Balance tracking
    var principalPortion: Double = 0.0
    var interestPortion: Double = 0.0
    var remainingBalance: Double = 0.0

    // Priority score from optimizer
    var priorityScore: Double = 0.0

    // Status
    var isPaid: Bool = false
    var paidDate: Date?

    init(
        accountID: UUID,
        accountName: String,
        debtTypeRaw: String = "other",
        month: Int,
        scheduledDate: Date,
        minimumPayment: Double,
        extraPayment: Double,
        principalPortion: Double,
        interestPortion: Double,
        remainingBalance: Double,
        priorityScore: Double = 0.0
    ) {
        self.id = UUID()
        self.accountID = accountID
        self.accountName = accountName
        self.debtTypeRaw = debtTypeRaw
        self.month = month
        self.scheduledDate = scheduledDate
        self.minimumPayment = minimumPayment
        self.extraPayment = extraPayment
        self.totalPayment = minimumPayment + extraPayment
        self.principalPortion = principalPortion
        self.interestPortion = interestPortion
        self.remainingBalance = remainingBalance
        self.priorityScore = priorityScore
        self.isPaid = false
    }

    // MARK: - Computed

    var isUpcoming: Bool {
        !isPaid && scheduledDate > Date()
    }

    var isDue: Bool {
        !isPaid && scheduledDate <= Date()
    }
}
