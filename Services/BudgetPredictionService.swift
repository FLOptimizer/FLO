//  BudgetPredictionService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Predictive Budgeting
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Analyzes historical spending by category to predict future budget amounts.
//  Uses a weighted moving average of monthly spending with inflation adjustment.
//  Falls back to simple average when insufficient data exists.
//
//  FEATURES v1.0:
//  ✅ Weighted moving average — recent months weighted higher than older months
//  ✅ Configurable annual inflation rate (default 3%)
//  ✅ Confidence band (±15%) for prediction range
//  ✅ Minimum data requirements: 2+ months of history for any prediction
//  ✅ Per-category prediction with months-of-data tracking
//  ✅ Thread-safe singleton matching other FLO services
//

import Foundation
import os.log

// MARK: - Predicted Budget Result

/// Result of a budget prediction for a specific category and target month.
struct PredictedBudget {
    /// The suggested monthly budget amount (inflation-adjusted)
    let suggestedAmount: Double

    /// Lower bound of confidence range
    let lowerBound: Double

    /// Upper bound of confidence range
    let upperBound: Double

    /// Number of months of historical data used
    let basedOnMonths: Int

    /// Annual inflation rate applied
    let inflationRate: Double

    /// Average monthly spending (before inflation)
    let rawAverage: Double

    /// Formatted suggestion string
    var formattedAmount: String {
        AppConstants.currencyFormatter.string(from: NSNumber(value: suggestedAmount)) ?? "$\(Int(suggestedAmount))"
    }

    /// Human-readable explanation
    var explanation: String {
        let monthsText = basedOnMonths == 1 ? "1 month" : "\(basedOnMonths) months"
        let inflationText = inflationRate > 0
            ? ", adjusted for \(Int(inflationRate * 100))% annual inflation"
            : ""
        return "Based on \(monthsText) of spending history\(inflationText)"
    }
}

// MARK: - Budget Prediction Service

@MainActor
final class BudgetPredictionService {
    static let shared = BudgetPredictionService()
    private init() {}

    private static let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "BudgetPrediction"
    )

    /// Minimum months of data required for a prediction
    static let minimumMonths = 2

    /// Default annual inflation rate (3%)
    nonisolated static let defaultInflationRate: Double = 0.03

    /// Confidence band width (±15%)
    static let confidenceBandWidth: Double = 0.15

    // MARK: - Predict Budget Amount

    /// Predicts a budget amount for a specific category and target month.
    ///
    /// Uses a weighted moving average of monthly spending, where recent months
    /// are weighted higher. Applies inflation adjustment based on how far
    /// the target month is from the most recent data.
    ///
    /// - Parameters:
    ///   - category: The category to predict spending for
    ///   - targetMonth: The month to predict (typically next month)
    ///   - transactions: All user transactions
    ///   - inflationRate: Annual inflation rate (default 3%)
    /// - Returns: PredictedBudget if sufficient data exists, nil otherwise
    func predictBudgetAmount(
        for category: Category,
        targetMonth: Date,
        transactions: [Transaction],
        inflationRate: Double = defaultInflationRate
    ) -> PredictedBudget? {
        let calendar = Calendar.current

        // Filter to this category's expenses (not income, not transfers)
        let categoryExpenses = transactions.filter { t in
            t.category?.id == category.id &&
            !t.isIncome &&
            !t.isTransfer
        }

        guard !categoryExpenses.isEmpty else {
            Self.logger.debug("📊 No expenses found for category '\(category.name)'")
            return nil
        }

        // Group expenses by month
        let monthlyTotals = groupByMonth(expenses: categoryExpenses, calendar: calendar)

        guard monthlyTotals.count >= Self.minimumMonths else {
            Self.logger.debug("📊 Only \(monthlyTotals.count) months of data for '\(category.name)' — need \(Self.minimumMonths)+")
            return nil
        }

        // Sort months chronologically
        let sortedMonths = monthlyTotals.sorted { $0.key < $1.key }
        let amounts = sortedMonths.map(\.value)

        // Calculate weighted moving average (recent months weighted higher)
        let weightedAverage = calculateWeightedAverage(amounts)

        // Calculate months ahead for inflation adjustment
        let lastDataMonth = sortedMonths.last!.key
        let monthsAhead = calendar.dateComponents([.month], from: lastDataMonth, to: targetMonth).month ?? 1
        let adjustedMonths = max(monthsAhead, 1)

        // Apply inflation: amount * (1 + annualRate/12)^monthsAhead
        let monthlyInflation = inflationRate / 12.0
        let inflationMultiplier = pow(1.0 + monthlyInflation, Double(adjustedMonths))
        let predicted = weightedAverage * inflationMultiplier

        // Confidence band
        let lower = predicted * (1.0 - Self.confidenceBandWidth)
        let upper = predicted * (1.0 + Self.confidenceBandWidth)

        // Round to nearest dollar for clean display
        let roundedPrediction = (predicted * 100).rounded() / 100

        Self.logger.info("📊 Predicted '\(category.name)': \(String(format: "$%.2f", roundedPrediction)) (avg: \(String(format: "$%.2f", weightedAverage)), \(monthlyTotals.count) months, \(adjustedMonths) months ahead, \(String(format: "%.1f%%", inflationRate * 100)) inflation)")

        return PredictedBudget(
            suggestedAmount: roundedPrediction,
            lowerBound: (lower * 100).rounded() / 100,
            upperBound: (upper * 100).rounded() / 100,
            basedOnMonths: monthlyTotals.count,
            inflationRate: inflationRate,
            rawAverage: weightedAverage
        )
    }

    // MARK: - Predict All Categories

    /// Predicts budget amounts for all categories that have sufficient history.
    ///
    /// - Parameters:
    ///   - categories: All available categories
    ///   - targetMonth: The month to predict
    ///   - transactions: All user transactions
    ///   - inflationRate: Annual inflation rate
    /// - Returns: Dictionary mapping category ID to predicted budget
    func predictAllCategories(
        categories: [Category],
        targetMonth: Date,
        transactions: [Transaction],
        inflationRate: Double = defaultInflationRate
    ) -> [UUID: PredictedBudget] {
        var predictions: [UUID: PredictedBudget] = [:]

        for category in categories where !category.isIncome {
            if let prediction = predictBudgetAmount(
                for: category,
                targetMonth: targetMonth,
                transactions: transactions,
                inflationRate: inflationRate
            ) {
                predictions[category.id] = prediction
            }
        }

        Self.logger.info("📊 Generated \(predictions.count) budget predictions for \(categories.count) categories")
        return predictions
    }

    // MARK: - Private Helpers

    /// Groups expenses by month and calculates monthly totals.
    private func groupByMonth(
        expenses: [Transaction],
        calendar: Calendar
    ) -> [Date: Double] {
        var monthlyTotals: [Date: Double] = [:]

        for expense in expenses {
            let components = calendar.dateComponents([.year, .month], from: expense.date)
            guard let monthStart = calendar.date(from: components) else { continue }

            monthlyTotals[monthStart, default: 0] += abs(expense.amount)
        }

        return monthlyTotals
    }

    /// Calculates a weighted moving average where recent values are weighted higher.
    ///
    /// Weight formula: weight(i) = (i + 1) for position i (0-indexed from oldest).
    /// So the most recent month gets the highest weight.
    private func calculateWeightedAverage(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        guard values.count > 1 else { return values[0] }

        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for (index, value) in values.enumerated() {
            let weight = Double(index + 1) // Older months get lower weight
            weightedSum += value * weight
            totalWeight += weight
        }

        return weightedSum / totalWeight
    }
}
