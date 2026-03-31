//  BudgetRecurringService.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Smart linking between budgets and recurring transactions.
//  Uses category matching to automatically connect committed (recurring)
//  spending with discretionary spending within each budget category.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftData

/// Service that links budgets to recurring transactions via shared categories.
/// No model changes needed — uses category + financeType matching.
@MainActor
final class BudgetRecurringService {

    static let shared = BudgetRecurringService()

    // MARK: - Data Types

    /// Breakdown of budget spending into committed (recurring) and discretionary.
    struct BudgetBreakdown {
        /// Sum of active recurring monthly equivalents for this category
        let committed: Double
        /// Actual spending in this category (all transactions)
        let actualSpent: Double
        /// What was spent beyond committed recurring
        let discretionarySpent: Double
        /// Total (same as actualSpent, but clarifies intent)
        let totalSpent: Double
        /// Individual recurring items that contribute to committed
        let recurringItems: [RecurringItem]

        /// Whether this budget has any linked recurring transactions
        var hasRecurring: Bool { !recurringItems.isEmpty }
    }

    /// A single recurring transaction contributing to the committed amount.
    struct RecurringItem: Identifiable {
        let id: UUID
        let name: String
        let monthlyAmount: Double
        let frequency: String
        let isActive: Bool
    }

    // MARK: - Frequency Conversion

    /// Convert any frequency to monthly equivalent.
    static func monthlyEquivalent(amount: Double, frequency: RecurrenceFrequency) -> Double {
        switch frequency {
        case .weekly:    return amount * (52.0 / 12.0)  // ~4.33
        case .biweekly:  return amount * (26.0 / 12.0)  // ~2.17
        case .monthly:   return amount
        case .quarterly: return amount / 3.0
        case .yearly:    return amount / 12.0
        }
    }

    // MARK: - Budget Breakdown

    /// Calculate the committed vs discretionary breakdown for a budget.
    /// - Parameters:
    ///   - budget: The budget to analyze
    ///   - recurring: All active recurring transactions (pre-fetched for performance)
    ///   - spent: The actual amount spent in this budget's category this month
    /// - Returns: BudgetBreakdown with committed and discretionary split
    func breakdown(
        for budget: Budget,
        recurring: [RecurringTransaction],
        spent: Double
    ) -> BudgetBreakdown {
        guard let categoryID = budget.category?.id else {
            return BudgetBreakdown(
                committed: 0,
                actualSpent: spent,
                discretionarySpent: spent,
                totalSpent: spent,
                recurringItems: []
            )
        }

        // Find active recurring expenses matching this budget's category + financeType
        let matching = recurring.filter { r in
            guard r.isActive && !r.isIncome else { return false }
            guard r.category?.id == categoryID else { return false }
            guard r.financeType == budget.financeType else { return false }
            return true
        }

        // Calculate committed monthly total
        let items = matching.map { r in
            RecurringItem(
                id: r.id,
                name: r.merchantName,
                monthlyAmount: Self.monthlyEquivalent(amount: r.amount, frequency: r.frequency),
                frequency: r.frequency.displayName,
                isActive: r.isActive
            )
        }

        let committed = items.reduce(0) { $0 + $1.monthlyAmount }
        let discretionary = max(0, spent - committed)

        return BudgetBreakdown(
            committed: committed,
            actualSpent: spent,
            discretionarySpent: discretionary,
            totalSpent: spent,
            recurringItems: items
        )
    }

    // MARK: - Recurring for Category

    /// Get all active recurring transactions for a specific category.
    func recurringForCategory(
        _ category: Category,
        financeType: Transaction.FinanceType,
        from allRecurring: [RecurringTransaction]
    ) -> [RecurringItem] {
        allRecurring
            .filter { $0.isActive && !$0.isIncome && $0.category?.id == category.id && $0.financeType == financeType }
            .map { r in
                RecurringItem(
                    id: r.id,
                    name: r.merchantName,
                    monthlyAmount: Self.monthlyEquivalent(amount: r.amount, frequency: r.frequency),
                    frequency: r.frequency.displayName,
                    isActive: r.isActive
                )
            }
    }

    /// Calculate total committed monthly amount for a category.
    func committedAmount(
        for category: Category,
        financeType: Transaction.FinanceType,
        from allRecurring: [RecurringTransaction]
    ) -> Double {
        recurringForCategory(category, financeType: financeType, from: allRecurring)
            .reduce(0) { $0 + $1.monthlyAmount }
    }

    // MARK: - Budget Suggestion

    /// Suggest a budget amount based on existing recurring transactions.
    /// Returns nil if no recurring found for the category.
    func suggestedBudgetAmount(
        for category: Category,
        financeType: Transaction.FinanceType,
        from allRecurring: [RecurringTransaction],
        discretionaryBuffer: Double = 0
    ) -> (recurring: Double, suggested: Double, items: [RecurringItem])? {
        let items = recurringForCategory(category, financeType: financeType, from: allRecurring)
        guard !items.isEmpty else { return nil }

        let recurring = items.reduce(0) { $0 + $1.monthlyAmount }
        return (recurring: recurring, suggested: recurring + discretionaryBuffer, items: items)
    }

    // MARK: - Budget Coverage Check

    /// Check if a budget adequately covers its recurring commitments.
    func coverageCheck(
        budget: Budget,
        allRecurring: [RecurringTransaction]
    ) -> (isCovered: Bool, shortfall: Double, committed: Double) {
        guard let category = budget.category else {
            return (true, 0, 0)
        }

        let committed = committedAmount(for: category, financeType: budget.financeType, from: allRecurring)
        let shortfall = committed - budget.planned

        return (
            isCovered: shortfall <= 0,
            shortfall: max(0, shortfall),
            committed: committed
        )
    }
}
