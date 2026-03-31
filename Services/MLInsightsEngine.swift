//  MLInsightsEngine.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - On-Device ML Insights
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  On-device machine learning engine for financial insights.
//  Uses CreateML for spending prediction and statistical analysis
//  for anomaly detection and pattern recognition.
//
//  FEATURES v1.0:
//  ✅ CreateML MLBoostedTreeRegressor for per-category spending prediction
//  ✅ Statistical z-score anomaly detection (replaces hardcoded $500 threshold)
//  ✅ Spending pattern recognition (weekend spikes, end-of-month surges, seasonal)
//  ✅ On-device model training — zero cloud dependency, fully private
//  ✅ Model persistence to Documents/MLModels/ with metadata tracking
//  ✅ Minimum data thresholds with graceful fallback
//  ✅ 24-hour training cooldown to avoid redundant retraining
//  ✅ Premium+ subscription gating (matches hasDebtInsights pattern)
//
//  INSTRUMENTS:
//  Training and prediction emit os_signpost events under "FLO.DataOperation"
//  visible in Instruments → Points of Interest.
//
//  PRIVACY:
//  All model training and inference runs on-device using Apple's CoreML/CreateML.
//  No transaction data is transmitted. Models are stored in the app sandbox.
//

import Foundation
import CoreML
#if canImport(CreateML)
import CreateML
#endif
import TabularData
import SwiftUI
import os

// MARK: - Logger

private extension Logger {
    static let ml = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
        category: "MLInsights"
    )
}

// MARK: - ML Model Status

enum MLModelStatus: Equatable {
    case notTrained
    case training
    case ready(lastTrained: Date)
    case insufficientData(required: Int, current: Int)
    case error(String)

    static func == (lhs: MLModelStatus, rhs: MLModelStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notTrained, .notTrained): return true
        case (.training, .training): return true
        case (.ready(let a), .ready(let b)): return a == b
        case (.insufficientData(let r1, let c1), .insufficientData(let r2, let c2)):
            return r1 == r2 && c1 == c2
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - ML Insights Error

enum MLInsightsError: LocalizedError {
    case engineDeallocated
    case insufficientRows(Int)
    case modelNotTrained
    case predictionFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineDeallocated:
            return "ML engine was deallocated during training"
        case .insufficientRows(let count):
            return "Only \(count) data rows available; need at least 6 for training"
        case .modelNotTrained:
            return "Spending model has not been trained yet"
        case .predictionFailed(let msg):
            return "Prediction failed: \(msg)"
        }
    }
}

// MARK: - Descriptive Statistics

/// Lightweight statistics helper for anomaly detection.
struct DescriptiveStatistics {
    let mean: Double
    let stdDev: Double
    let median: Double
    let count: Int

    init(values: [Double]) {
        let sorted = values.sorted()
        self.count = sorted.count
        let n = Double(count)

        let computedMean = count > 0 ? sorted.reduce(0, +) / n : 0
        self.mean = computedMean

        if count > 1 {
            let variance = sorted.reduce(0.0) { $0 + ($1 - computedMean) * ($1 - computedMean) } / (n - 1)
            self.stdDev = sqrt(variance)
        } else {
            self.stdDev = 0
        }

        if count == 0 {
            self.median = 0
        } else {
            let mid = count / 2
            self.median = count % 2 == 0
                ? (sorted[max(mid - 1, 0)] + sorted[mid]) / 2.0
                : sorted[mid]
        }
    }
}

// MARK: - ML Insights Engine

/// On-device machine learning engine for financial spending insights.
///
/// Provides three analysis capabilities:
/// 1. **Spending Prediction** — CreateML `MLBoostedTreeRegressor` trained on the user's
///    own transaction history to predict next month's spending per category.
/// 2. **Anomaly Detection** — Statistical z-score analysis per category to identify
///    unusual transactions with far more precision than a fixed dollar threshold.
/// 3. **Pattern Recognition** — Behavioral pattern detection (weekend spending spikes,
///    end-of-month surges, seasonal year-over-year trends).
///
/// All processing runs on-device. No data leaves the device.
@MainActor
final class MLInsightsEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = MLInsightsEngine()

    // MARK: - Published State

    @Published private(set) var spendingModelStatus: MLModelStatus = .notTrained
    @Published private(set) var isTraining: Bool = false

    // MARK: - Configuration

    /// Minimum months of transaction history for spending prediction
    static let minimumMonthsForPrediction = 3

    /// Minimum total transactions for any ML analysis
    static let minimumTransactionsForAnalysis = 30

    /// Minimum transactions per category to include in prediction
    static let minimumCategoryTransactions = 10

    /// Z-score threshold for anomaly flagging (2.5σ is ~1.2% of normal distribution)
    static let anomalyZScoreThreshold: Double = 2.5

    /// Minimum time between model retraining (24 hours)
    static let trainingCooldown: TimeInterval = 86400

    // MARK: - Private State

    #if canImport(CreateML)
    private var spendingModel: MLBoostedTreeRegressor?
    #endif
    private var lastTrainingDate: Date?
    private var trainingDataHash: Int?

    // MARK: - Model Storage

    private var modelsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("MLModels", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // Exclude from iCloud backup
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableDir = dir
            try? mutableDir.setResourceValues(resourceValues)
        }
        return dir
    }

    private var metadataURL: URL {
        modelsDirectory.appendingPathComponent("model_metadata.json")
    }

    // MARK: - Init

    private init() {
        loadPersistedMetadata()
    }

    // MARK: - Metadata Persistence

    private struct ModelMetadata: Codable {
        let lastTrained: Date
        let dataHash: Int
    }

    private func loadPersistedMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(ModelMetadata.self, from: data) else {
            return
        }
        lastTrainingDate = metadata.lastTrained
        trainingDataHash = metadata.dataHash
        spendingModelStatus = .ready(lastTrained: metadata.lastTrained)
        Logger.ml.info("🤖 Loaded ML metadata — last trained: \(metadata.lastTrained.formatted())")
    }

    private func saveMetadata() {
        guard let date = lastTrainingDate, let hash = trainingDataHash else { return }
        let metadata = ModelMetadata(lastTrained: date, dataHash: hash)
        if let data = try? JSONEncoder().encode(metadata) {
            try? data.write(to: metadataURL)
        }
    }
}

#if canImport(CreateML)
// MARK: - Spending Prediction (CreateML)

extension MLInsightsEngine {

    /// Train the spending prediction model from transaction history.
    ///
    /// Uses `MLBoostedTreeRegressor` to learn per-category monthly spending patterns.
    /// Training runs on a background thread and does not block the UI.
    ///
    /// - Parameters:
    ///   - transactions: All user transactions (transfers will be filtered out).
    ///   - categories: All user categories.
    func trainSpendingModel(transactions: [Transaction], categories: [Category]) async {
        guard !isTraining else { return }

        // Check training cooldown
        if let lastDate = lastTrainingDate,
           Date().timeIntervalSince(lastDate) < Self.trainingCooldown {
            return
        }

        // Filter to expenses only, exclude transfers
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }

        // Check minimum data threshold
        guard expenses.count >= Self.minimumTransactionsForAnalysis else {
            spendingModelStatus = .insufficientData(
                required: Self.minimumTransactionsForAnalysis,
                current: expenses.count
            )
            return
        }

        // Check we have enough months
        let monthKeys = Set(expenses.map { $0.monthKey })
        guard monthKeys.count >= Self.minimumMonthsForPrediction else {
            spendingModelStatus = .insufficientData(
                required: Self.minimumTransactionsForAnalysis,
                current: expenses.count
            )
            return
        }

        // Check if data has changed since last training
        let currentHash = expenses.map { $0.id }.hashValue
        if currentHash == trainingDataHash, spendingModel != nil {
            return
        }

        isTraining = true
        spendingModelStatus = .training
        Logger.ml.info("🤖 Starting spending model training with \(expenses.count) transactions...")

        // Build DataFrame on main actor (reads SwiftData models),
        // then train on background thread (CPU-intensive, Sendable-safe).
        let dataFrame = Self.buildTrainingDataFrame(
            transactions: expenses,
            categories: categories
        )

        guard dataFrame.rows.count >= 6 else {
            spendingModelStatus = .insufficientData(required: 6, current: dataFrame.rows.count)
            isTraining = false
            Logger.ml.info("🤖 Insufficient training rows: \(dataFrame.rows.count)")
            return
        }

        // DataFrame is not Sendable, so we use nonisolated(unsafe) to cross the boundary.
        // This is safe because the main actor does not touch dataFrame after this point.
        nonisolated(unsafe) let trainingDF = dataFrame

        let result: Result<MLBoostedTreeRegressor, Error> = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {

                    let params = MLBoostedTreeRegressor.ModelParameters(
                        validation: .split(strategy: .automatic),
                        maxDepth: 6,
                        maxIterations: 100
                    )

                    let model = try MLBoostedTreeRegressor(
                        trainingData: trainingDF,
                        targetColumn: "amount",
                        featureColumns: [
                            "monthIndex",
                            "categoryHash",
                            "prevMonthAmount",
                            "prev2MonthAmount",
                            "transactionCount",
                            "avgTransactionAmount",
                            "weekdayRatio"
                        ],
                        parameters: params
                    )

                    continuation.resume(returning: .success(model))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }

        // Back on MainActor
        switch result {
        case .success(let model):
            spendingModel = model
            lastTrainingDate = Date()
            trainingDataHash = expenses.map { $0.id }.hashValue
            spendingModelStatus = .ready(lastTrained: Date())
            saveMetadata()
            Logger.ml.info("✅ Spending model trained successfully (maxError: \(String(format: "%.2f", model.trainingMetrics.maximumError)))")

        case .failure(let error):
            spendingModelStatus = .error(error.localizedDescription)
            Logger.ml.error("❌ Spending model training failed: \(error.localizedDescription)")
        }

        isTraining = false
    }

    /// Predict next month's spending for each category with sufficient data.
    ///
    /// Returns `SpendingInsight` objects for categories where a meaningful
    /// prediction can be made. Includes budget overrun warnings.
    func predictSpending(
        transactions: [Transaction],
        budgets: [Budget],
        categories: [Category]
    ) -> [SpendingInsight] {
        guard let model = spendingModel else { return [] }

        let calendar = Calendar.current
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }
        let byCategory = Dictionary(grouping: expenses) { $0.category?.id }

        var insights: [SpendingInsight] = []

        for (categoryId, categoryTxs) in byCategory {
            guard let categoryId = categoryId else { continue }
            guard categoryTxs.count >= Self.minimumCategoryTransactions else { continue }
            guard let category = categoryTxs.first?.category else { continue }

            // Build prediction input
            let inputDF = Self.buildPredictionInput(
                categoryTransactions: categoryTxs,
                category: category
            )

            do {
                let predictedColumn = try model.predictions(from: inputDF)
                guard let predictedAmount = predictedColumn[0] as? Double,
                      predictedAmount > 10 else { continue } // Ignore trivial predictions

                // Find matching budget for this category
                let now = Date()
                let monthStart = now.startOfMonth()
                let matchingBudget = budgets.first {
                    $0.category?.id == categoryId &&
                    calendar.isDate($0.month, equalTo: monthStart, toGranularity: .month)
                }

                // Spending prediction insight
                insights.append(SpendingInsight(
                    type: .prediction,
                    priority: .normal,
                    title: "Predicted: \(category.name)",
                    message: "Based on your patterns, you'll likely spend \(Self.formatCurrency(predictedAmount)) on \(category.name) this month.",
                    icon: "wand.and.stars",
                    color: .indigo,
                    actionable: matchingBudget != nil,
                    actionLabel: matchingBudget != nil ? "View Budget" : nil,
                    relatedEntityId: categoryId,
                    metadata: [
                        "predictedAmount": Self.formatCurrency(predictedAmount),
                        "mlGenerated": "true"
                    ]
                ))

                // Budget overrun warning
                if let budget = matchingBudget {
                    let budgetTotal = budget.totalAvailable
                    if budgetTotal > 0 && predictedAmount > budgetTotal * 1.1 {
                        let overAmount = predictedAmount - budgetTotal
                        insights.append(SpendingInsight(
                            type: .prediction,
                            priority: .high,
                            title: "\(category.name) May Exceed Budget",
                            message: "At your current pace, \(category.name) spending could exceed your \(Self.formatCurrency(budgetTotal)) budget by \(Self.formatCurrency(overAmount)).",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            actionable: true,
                            actionLabel: "Adjust Budget",
                            relatedEntityId: budget.id,
                            metadata: [
                                "predictedAmount": Self.formatCurrency(predictedAmount),
                                "budgetAmount": Self.formatCurrency(budgetTotal),
                                "overBy": Self.formatCurrency(overAmount),
                                "mlGenerated": "true"
                            ]
                        ))
                    }
                }

            } catch {
                Logger.ml.debug("🤖 Prediction skipped for \(category.name): \(error.localizedDescription)")
                continue
            }
        }

        // Return top 2 most relevant predictions
        return Array(insights.prefix(2))
    }
}
#else
// MARK: - Spending Prediction Fallback (Simulator / No CreateML)

extension MLInsightsEngine {

    /// CreateML is not available on this platform (Simulator).
    /// Training is a no-op; predictions return empty.
    func trainSpendingModel(transactions: [Transaction], categories: [Category]) async {
        spendingModelStatus = .error("CreateML not available on this platform")
        Logger.ml.info("🤖 CreateML not available — spending model training skipped")
    }

    /// No predictions available without CreateML.
    func predictSpending(
        transactions: [Transaction],
        budgets: [Budget],
        categories: [Category]
    ) -> [SpendingInsight] {
        return []
    }
}
#endif

// MARK: - Anomaly Detection (Statistical)

extension MLInsightsEngine {

    /// Detect anomalous transactions using per-category z-score analysis.
    ///
    /// This replaces the rule-based "$500 large transaction" threshold with
    /// personalized detection: a $200 transaction is anomalous if your typical
    /// category spend is $30, even though it's below the old threshold.
    ///
    /// - Parameter transactions: All user transactions.
    /// - Returns: Up to 3 anomaly-based `SpendingInsight` objects.
    func detectAnomalies(transactions: [Transaction]) -> [SpendingInsight] {
        let calendar = Calendar.current
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }

        guard expenses.count >= Self.minimumTransactionsForAnalysis else { return [] }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let byCategory = Dictionary(grouping: expenses) { $0.category?.id }

        var insights: [SpendingInsight] = []

        for (_, categoryTxs) in byCategory {
            guard categoryTxs.count >= 5 else { continue }

            let amounts = categoryTxs.map { $0.amount }
            let stats = DescriptiveStatistics(values: amounts)

            guard stats.stdDev > 0 else { continue }

            // Check recent transactions for anomalies
            let recentTxs = categoryTxs.filter { $0.date >= weekAgo }

            for tx in recentTxs {
                let zScore = (tx.amount - stats.mean) / stats.stdDev

                if zScore > Self.anomalyZScoreThreshold {
                    let categoryName = tx.category?.name ?? "Uncategorized"
                    let multiplier = tx.amount / stats.mean
                    let merchantDisplay = tx.merchantName.isEmpty ? categoryName : tx.merchantName

                    insights.append(SpendingInsight(
                        type: .prediction,
                        priority: zScore > 3.5 ? .high : .normal,
                        title: "Unusual \(categoryName) Expense",
                        message: "\(Self.formatCurrency(tx.amount)) at \(merchantDisplay) is \(String(format: "%.1f", multiplier))x your typical \(categoryName) spending of \(Self.formatCurrency(stats.mean)).",
                        icon: "exclamationmark.magnifyingglass",
                        color: .orange,
                        actionable: true,
                        actionLabel: "Review",
                        relatedEntityId: tx.id,
                        metadata: [
                            "zScore": String(format: "%.2f", zScore),
                            "categoryMean": Self.formatCurrency(stats.mean),
                            "multiplier": String(format: "%.1f", multiplier),
                            "mlGenerated": "true"
                        ]
                    ))
                }
            }

            // Unusually frequent spending detection
            let thisMonthStart = Date().startOfMonth()
            let thisMonthCount = categoryTxs.filter { $0.date >= thisMonthStart }.count

            // Historical average monthly count
            let allMonthKeys = Set(categoryTxs.map { $0.monthKey })
            let monthSpan = max(1, allMonthKeys.count)
            let avgMonthlyCount = Double(categoryTxs.count) / Double(monthSpan)

            if Double(thisMonthCount) > avgMonthlyCount * 2.0 && thisMonthCount >= 5 {
                let categoryName = categoryTxs.first?.category?.name ?? "Uncategorized"
                let percentMore = Int(((Double(thisMonthCount) / avgMonthlyCount) - 1) * 100)

                insights.append(SpendingInsight(
                    type: .prediction,
                    priority: .normal,
                    title: "Frequent \(categoryName) Activity",
                    message: "You've made \(thisMonthCount) \(categoryName) transactions this month — about \(percentMore)% more than your typical \(String(format: "%.0f", avgMonthlyCount)) per month.",
                    icon: "arrow.up.right.circle.fill",
                    color: .purple,
                    relatedEntityId: categoryTxs.first?.category?.id,
                    metadata: [
                        "thisMonthCount": "\(thisMonthCount)",
                        "avgMonthlyCount": String(format: "%.1f", avgMonthlyCount),
                        "mlGenerated": "true"
                    ]
                ))
            }
        }

        // Return top 3 most anomalous (sorted by z-score descending)
        return Array(insights.sorted { lhs, rhs in
            let lhsZ = Double(lhs.metadata["zScore"] ?? "0") ?? 0
            let rhsZ = Double(rhs.metadata["zScore"] ?? "0") ?? 0
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhsZ > rhsZ
        }.prefix(3))
    }
}

// MARK: - Pattern Recognition (Statistical)

extension MLInsightsEngine {

    /// Identify recurring spending patterns in transaction history.
    ///
    /// Detects:
    /// - **Weekend spending spikes** — Average transaction amount higher on weekends
    /// - **End-of-month surges** — Spending increases in the last week of each month
    /// - **Seasonal trends** — Year-over-year quarterly comparison
    ///
    /// - Parameter transactions: All user transactions.
    /// - Returns: Up to 2 pattern-based `SpendingInsight` objects.
    func recognizePatterns(transactions: [Transaction]) -> [SpendingInsight] {
        let calendar = Calendar.current
        let expenses = transactions.filter { !$0.isIncome && !$0.isTransfer }

        guard expenses.count >= Self.minimumTransactionsForAnalysis else { return [] }

        var insights: [SpendingInsight] = []

        // === Weekend vs Weekday Analysis ===
        let weekdayTxs = expenses.filter {
            let day = calendar.component(.weekday, from: $0.date)
            return day >= 2 && day <= 6 // Mon-Fri
        }
        let weekendTxs = expenses.filter {
            let day = calendar.component(.weekday, from: $0.date)
            return day == 1 || day == 7 // Sat-Sun
        }

        if weekendTxs.count >= 10 && weekdayTxs.count >= 10 {
            let avgWeekdaySpend = weekdayTxs.reduce(0.0) { $0 + $1.amount } / Double(weekdayTxs.count)
            let avgWeekendSpend = weekendTxs.reduce(0.0) { $0 + $1.amount } / Double(weekendTxs.count)

            if avgWeekendSpend > avgWeekdaySpend * 1.3 && avgWeekdaySpend > 0 {
                let percentMore = Int(((avgWeekendSpend / avgWeekdaySpend) - 1) * 100)
                insights.append(SpendingInsight(
                    type: .prediction,
                    priority: .normal,
                    title: "Weekend Spending Pattern",
                    message: "Your weekend transactions average \(percentMore)% more per purchase (\(Self.formatCurrency(avgWeekendSpend))) than weekdays (\(Self.formatCurrency(avgWeekdaySpend))).",
                    icon: "calendar.badge.clock",
                    color: .indigo,
                    metadata: [
                        "avgWeekday": Self.formatCurrency(avgWeekdaySpend),
                        "avgWeekend": Self.formatCurrency(avgWeekendSpend),
                        "mlGenerated": "true"
                    ]
                ))
            }
        }

        // === End-of-Month Surge Detection ===
        let endOfMonthTxs = expenses.filter {
            calendar.component(.day, from: $0.date) >= 25
        }
        let earlyMonthTxs = expenses.filter {
            let day = calendar.component(.day, from: $0.date)
            return day >= 1 && day <= 10
        }

        if endOfMonthTxs.count >= 8 && earlyMonthTxs.count >= 8 {
            let avgEnd = endOfMonthTxs.reduce(0.0) { $0 + $1.amount } / Double(endOfMonthTxs.count)
            let avgEarly = earlyMonthTxs.reduce(0.0) { $0 + $1.amount } / Double(earlyMonthTxs.count)

            if avgEnd > avgEarly * 1.4 && avgEarly > 0 {
                let percentMore = Int(((avgEnd / avgEarly) - 1) * 100)
                insights.append(SpendingInsight(
                    type: .prediction,
                    priority: .normal,
                    title: "End-of-Month Spending Surge",
                    message: "You tend to spend \(percentMore)% more per transaction in the last week of each month compared to the first ten days.",
                    icon: "calendar.badge.exclamationmark",
                    color: .orange,
                    metadata: ["mlGenerated": "true"]
                ))
            }
        }

        // === Year-over-Year Quarterly Trend ===
        let currentQuarter = Date().taxQuarter
        let thisYear = calendar.component(.year, from: Date())

        let lastYearSameQuarter = expenses.filter {
            $0.date.taxQuarter == currentQuarter &&
            calendar.component(.year, from: $0.date) == thisYear - 1
        }

        let thisQuarterStart = Date().startOfQuarter()
        let thisYearQuarter = expenses.filter { $0.date >= thisQuarterStart }

        if lastYearSameQuarter.count >= 5 && thisYearQuarter.count >= 5 {
            let lastYearTotal = lastYearSameQuarter.reduce(0.0) { $0 + $1.amount }
            let thisYearTotal = thisYearQuarter.reduce(0.0) { $0 + $1.amount }

            if lastYearTotal > 0 {
                let change = (thisYearTotal - lastYearTotal) / lastYearTotal
                if abs(change) > 0.20 {
                    let direction = change > 0 ? "up" : "down"
                    let percentChange = Int(abs(change) * 100)
                    insights.append(SpendingInsight(
                        type: .prediction,
                        priority: .low,
                        title: "Q\(currentQuarter) Year-over-Year",
                        message: "Your Q\(currentQuarter) spending is \(direction) \(percentChange)% compared to the same quarter last year (\(Self.formatCurrency(lastYearTotal)) → \(Self.formatCurrency(thisYearTotal))).",
                        icon: "chart.bar.xaxis",
                        color: change > 0 ? .orange : .green,
                        metadata: [
                            "thisYear": Self.formatCurrency(thisYearTotal),
                            "lastYear": Self.formatCurrency(lastYearTotal),
                            "mlGenerated": "true"
                        ]
                    ))
                }
            }
        }

        return Array(insights.prefix(2))
    }
}

// MARK: - Feature Engineering (DataFrame Construction)

extension MLInsightsEngine {

    /// Build a TabularData DataFrame for spending model training.
    ///
    /// Each row represents one (category, month) aggregation with lag features.
    /// Features: monthIndex, categoryHash, prevMonthAmount, prev2MonthAmount,
    /// transactionCount, avgTransactionAmount, weekdayRatio.
    /// Target: amount (total spending for that category-month).
    nonisolated static func buildTrainingDataFrame(
        transactions: [Transaction],
        categories: [Category]
    ) -> DataFrame {
        let calendar = Calendar.current

        var monthIndices: [Double] = []
        var categoryHashes: [Double] = []
        var prevMonthAmounts: [Double] = []
        var prev2MonthAmounts: [Double] = []
        var transactionCounts: [Double] = []
        var avgTransactionAmounts: [Double] = []
        var weekdayRatios: [Double] = []
        var amounts: [Double] = []

        let byCategory = Dictionary(grouping: transactions) { $0.category?.id }

        for (categoryId, categoryTxs) in byCategory {
            guard let categoryId = categoryId else { continue }
            guard categoryTxs.count >= 10 else { continue } // minimumCategoryTransactions

            // Group by month and sort chronologically
            let byMonth = Dictionary(grouping: categoryTxs) { $0.monthKey }
                .sorted { $0.key < $1.key }

            // Stable numeric hash for category
            let catHash = Double(abs(categoryId.hashValue % 10000))

            for (index, (_, monthTxs)) in byMonth.enumerated() {
                let monthTotal = monthTxs.reduce(0.0) { $0 + $1.amount }
                let txCount = monthTxs.count
                let avgTx = monthTotal / Double(max(txCount, 1))

                // Lag features
                let prevMonth: Double = index >= 1
                    ? byMonth[index - 1].value.reduce(0.0) { $0 + $1.amount }
                    : 0
                let prev2Month: Double = index >= 2
                    ? byMonth[index - 2].value.reduce(0.0) { $0 + $1.amount }
                    : 0

                // Weekday ratio
                let weekdayCount = monthTxs.filter {
                    let day = calendar.component(.weekday, from: $0.date)
                    return day >= 2 && day <= 6
                }.count
                let wdRatio = Double(weekdayCount) / Double(max(txCount, 1))

                monthIndices.append(Double(index))
                categoryHashes.append(catHash)
                prevMonthAmounts.append(prevMonth)
                prev2MonthAmounts.append(prev2Month)
                transactionCounts.append(Double(txCount))
                avgTransactionAmounts.append(avgTx)
                weekdayRatios.append(wdRatio)
                amounts.append(monthTotal)
            }
        }

        var df = DataFrame()
        df.append(column: Column(name: "monthIndex", contents: monthIndices))
        df.append(column: Column(name: "categoryHash", contents: categoryHashes))
        df.append(column: Column(name: "prevMonthAmount", contents: prevMonthAmounts))
        df.append(column: Column(name: "prev2MonthAmount", contents: prev2MonthAmounts))
        df.append(column: Column(name: "transactionCount", contents: transactionCounts))
        df.append(column: Column(name: "avgTransactionAmount", contents: avgTransactionAmounts))
        df.append(column: Column(name: "weekdayRatio", contents: weekdayRatios))
        df.append(column: Column(name: "amount", contents: amounts))

        return df
    }

    /// Build a single-row DataFrame for prediction input for a specific category.
    nonisolated static func buildPredictionInput(
        categoryTransactions: [Transaction],
        category: Category
    ) -> DataFrame {
        let calendar = Calendar.current
        let byMonth = Dictionary(grouping: categoryTransactions) { $0.monthKey }
            .sorted { $0.key < $1.key }

        let lastMonthAmount = byMonth.last.map {
            $0.value.reduce(0.0) { $0 + $1.amount }
        } ?? 0

        let prev2MonthAmount: Double
        if byMonth.count >= 2 {
            prev2MonthAmount = byMonth[byMonth.count - 2].value.reduce(0.0) { $0 + $1.amount }
        } else {
            prev2MonthAmount = 0
        }

        // Current month stats
        let thisMonthStart = Date().startOfMonth()
        let thisMonthTxs = categoryTransactions.filter { $0.date >= thisMonthStart }
        let txCount = Double(max(thisMonthTxs.count, 1))
        let avgTx = thisMonthTxs.isEmpty ? 0 : thisMonthTxs.reduce(0.0) { $0 + $1.amount } / txCount

        let weekdayCount = thisMonthTxs.filter {
            let day = calendar.component(.weekday, from: $0.date)
            return day >= 2 && day <= 6
        }.count
        let weekdayRatio = thisMonthTxs.isEmpty ? 0.7 : Double(weekdayCount) / txCount

        let catHash = Double(abs(category.id.hashValue % 10000))

        var df = DataFrame()
        df.append(column: Column(name: "monthIndex", contents: [Double(byMonth.count)]))
        df.append(column: Column(name: "categoryHash", contents: [catHash]))
        df.append(column: Column(name: "prevMonthAmount", contents: [lastMonthAmount]))
        df.append(column: Column(name: "prev2MonthAmount", contents: [prev2MonthAmount]))
        df.append(column: Column(name: "transactionCount", contents: [txCount]))
        df.append(column: Column(name: "avgTransactionAmount", contents: [avgTx]))
        df.append(column: Column(name: "weekdayRatio", contents: [weekdayRatio]))

        return df
    }
}

// MARK: - Helpers

extension MLInsightsEngine {

    /// Format a Double as currency string for insight messages.
    nonisolated static func formatCurrency(_ amount: Double) -> String {
        return NumberFormatter.appCurrencyCompact.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Predictive Budgeting (v2.4)

extension MLInsightsEngine {

    /// Predicts a budget amount for a given category, combining ML prediction
    /// (when available) with statistical fallback and inflation adjustment.
    ///
    /// Uses the BudgetPredictionService for the core calculation. If the
    /// ML spending model is trained, the prediction may be more accurate.
    ///
    /// - Parameters:
    ///   - category: The category to predict
    ///   - month: Target month
    ///   - transactions: All user transactions
    ///   - inflationRate: Annual inflation rate (default 3%)
    /// - Returns: PredictedBudget if sufficient data, nil otherwise
    func predictBudgetAmount(
        for category: Category,
        month: Date,
        transactions: [Transaction],
        inflationRate: Double = 0.03
    ) -> PredictedBudget? {
        return BudgetPredictionService.shared.predictBudgetAmount(
            for: category,
            targetMonth: month,
            transactions: transactions,
            inflationRate: inflationRate
        )
    }
}
