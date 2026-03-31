//  MLInsightsIntegration.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - ML Insights Integration Bridge
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Bridges MLInsightsEngine into InsightsService's standard generation pipeline.
//  Follows the same extension pattern as MoneyMovesInsights.swift.
//
//  ARCHITECTURE:
//  InsightsService.generateInsights() → generateMLInsights() → MLInsightsEngine
//    → predictSpending()      [CreateML model, if trained]
//    → detectAnomalies()      [Statistical z-score, always available]
//    → recognizePatterns()    [Statistical, always available]
//
//  All ML insights output as standard SpendingInsight objects with type: .prediction
//  and metadata["mlGenerated"] = "true" for UI identification.
//

import Foundation
import SwiftUI

// MARK: - InsightsService ML Extension

extension InsightsService {

    /// Generate ML-powered insights by delegating to MLInsightsEngine.
    ///
    /// Called from `generateInsights()` when the user has Premium+ tier.
    /// Triggers model training asynchronously on first call or when cooldown expires.
    /// Statistical insights (anomaly detection, patterns) are available immediately.
    ///
    /// - Parameters:
    ///   - transactions: Filtered transactions (transfers already excluded).
    ///   - budgets: Current budgets for overrun prediction.
    ///   - categories: All categories for per-category analysis.
    /// - Returns: Up to 4 ML-generated `SpendingInsight` objects.
    func generateMLInsights(
        transactions: [Transaction],
        budgets: [Budget],
        categories: [Category]
    ) -> [SpendingInsight] {
        let engine = MLInsightsEngine.shared
        var insights: [SpendingInsight] = []

        // Trigger training if needed (fire-and-forget async task — non-blocking)
        // On first call: model trains in background; predictions available next cycle.
        // On subsequent calls: training is skipped if within 24-hour cooldown.
        Task {
            await engine.trainSpendingModel(
                transactions: transactions,
                categories: categories
            )
        }

        // A. Spending predictions (only when model is trained)
        if case .ready = engine.spendingModelStatus {
            insights.append(contentsOf: engine.predictSpending(
                transactions: transactions,
                budgets: budgets,
                categories: categories
            ))
        }

        // B. Anomaly detection (statistical — no training needed)
        insights.append(contentsOf: engine.detectAnomalies(
            transactions: transactions
        ))

        // C. Pattern recognition (statistical — no training needed)
        insights.append(contentsOf: engine.recognizePatterns(
            transactions: transactions
        ))

        // Cap total ML insights to avoid overwhelming the feed
        return Array(insights.prefix(4))
    }
}
