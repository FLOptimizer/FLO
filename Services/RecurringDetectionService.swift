//  RecurringDetectionService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Auto-Recurring Detection
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Analyzes transaction history to detect recurring patterns and suggest
//  RecurringTransaction templates. Groups transactions by merchant name,
//  computes intervals between consecutive occurrences, and clusters intervals
//  to detect frequency (weekly/biweekly/monthly/quarterly/yearly).
//
//  FEATURES v1.0:
//  ✅ Interval clustering algorithm detects 5 frequency types
//  ✅ Confidence scoring based on match ratio, count, and recency
//  ✅ Filters out merchants already covered by active RecurringTransactions
//  ✅ Dismiss/accept pattern actions with UserDefaults persistence
//  ✅ Premium+ subscription gated (reuses hasRecurringTransactions)
//  ✅ Runs deferred on app launch (+3.0s)
//  ✅ Thread-safe singleton matching FLO service pattern

import Foundation
import SwiftData
import OSLog

// MARK: - Detected Pattern

/// A detected recurring spending/income pattern from transaction history.
struct DetectedRecurringPattern: Identifiable, Sendable {
    let id: UUID
    let merchantName: String
    let averageAmount: Double
    let medianAmount: Double
    let amountMin: Double
    let amountMax: Double
    let detectedFrequency: RecurrenceFrequency
    let confidence: Double
    let transactionCount: Int
    let isIncome: Bool
    let financeType: Transaction.FinanceType
    let mostRecentDate: Date
    let estimatedNextDate: Date?
    let matchingTransactionIDs: [UUID]
    let suggestedCategoryID: UUID?
    let suggestedCategoryName: String?
    let suggestedAccountID: UUID?
    let suggestedAccountName: String?

    /// Formatted average amount for display
    var formattedAmount: String {
        averageAmount.formatted(.currency(code: "USD"))
    }

    /// Human-readable confidence label
    var confidenceLabel: String {
        if confidence >= 0.80 { return "High" }
        if confidence >= 0.60 { return "Medium" }
        return "Low"
    }

    /// Confidence color name for UI
    var confidenceColor: String {
        if confidence >= 0.80 { return "green" }
        if confidence >= 0.60 { return "orange" }
        return "yellow"
    }

    /// Display string for the pattern summary
    var summaryText: String {
        "\(detectedFrequency.displayName) \(isIncome ? "income" : "expense") of \(formattedAmount)"
    }
}

// MARK: - Recurring Detection Service

/// Analyzes transaction history to detect recurring patterns and suggest RecurringTransaction templates.
@MainActor
final class RecurringDetectionService: ObservableObject {

    // MARK: - Singleton

    static let shared = RecurringDetectionService()
    private init() {
        loadDismissedMerchants()
    }

    private let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "RecurringDetection"
    )

    // MARK: - Configuration

    /// Minimum number of transactions needed to detect a pattern
    static let minimumOccurrences = 3

    /// Amount tolerance for grouping (±10%)
    static let amountTolerancePercent = 0.10

    /// Minimum confidence to surface a detected pattern
    static let minimumConfidence = 0.50

    /// Maximum age of transactions to analyze (12 months)
    static let analysisWindowMonths = 12

    // MARK: - Frequency Detection Windows (days)

    private struct FrequencyWindow {
        let frequency: RecurrenceFrequency
        let minDays: Double
        let maxDays: Double

        func contains(_ interval: Double) -> Bool {
            interval >= minDays && interval <= maxDays
        }
    }

    private let frequencyWindows: [FrequencyWindow] = [
        FrequencyWindow(frequency: .weekly, minDays: 5, maxDays: 9),
        FrequencyWindow(frequency: .biweekly, minDays: 12, maxDays: 16),
        FrequencyWindow(frequency: .monthly, minDays: 26, maxDays: 35),
        FrequencyWindow(frequency: .quarterly, minDays: 80, maxDays: 100),
        FrequencyWindow(frequency: .yearly, minDays: 350, maxDays: 380),
    ]

    // MARK: - Published State

    /// Currently detected patterns, sorted by confidence descending
    @Published private(set) var detectedPatterns: [DetectedRecurringPattern] = []

    /// Whether analysis is currently running
    @Published private(set) var isAnalyzing = false

    /// When the last analysis completed
    @Published private(set) var lastAnalysisDate: Date?

    // MARK: - Private State

    /// Merchants the user has dismissed (stored in UserDefaults)
    private var dismissedMerchants: Set<String> = []
    private let dismissedMerchantsKey = "recurringDetection.dismissedMerchants"

    // MARK: - Primary Analysis

    /// Analyze all transactions to detect recurring patterns.
    /// Safe to call on launch, after Plaid sync, or manually.
    func analyzeTransactions(in container: ModelContainer) async {
        guard !isAnalyzing else {
            logger.info("Analysis already in progress, skipping")
            return
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        logger.info("Starting recurring pattern detection...")

        let context = ModelContext(container)
        let calendar = Calendar.current

        // Fetch transactions from the last 12 months (non-transfer only)
        guard let cutoffDate = calendar.date(
            byAdding: .month,
            value: -Self.analysisWindowMonths,
            to: Date.now
        ) else {
            logger.error("Failed to calculate analysis cutoff date")
            return
        }

        do {
            // Fetch transactions
            let transactionDescriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate<Transaction> { transaction in
                    transaction.date >= cutoffDate && !transaction.isTransfer
                },
                sortBy: [SortDescriptor(\Transaction.date, order: .forward)]
            )
            let transactions = try context.fetch(transactionDescriptor)

            guard !transactions.isEmpty else {
                logger.info("No transactions found for analysis")
                detectedPatterns = []
                lastAnalysisDate = Date.now
                return
            }

            // Fetch existing recurring transactions to filter out already-covered patterns
            let recurringDescriptor = FetchDescriptor<RecurringTransaction>(
                predicate: #Predicate<RecurringTransaction> { $0.isActive }
            )
            let existingRecurring = try context.fetch(recurringDescriptor)

            // Run detection
            let patterns = detectPatterns(
                transactions: transactions,
                existingRecurring: existingRecurring
            )

            detectedPatterns = patterns
            lastAnalysisDate = Date.now

            logger.info("Detection complete: found \(patterns.count) patterns from \(transactions.count) transactions")

        } catch {
            logger.error("Failed to fetch transactions for analysis: \(error.localizedDescription)")
        }
    }

    // MARK: - Detection Algorithm

    /// Core detection algorithm. Pure function for testability.
    func detectPatterns(
        transactions: [Transaction],
        existingRecurring: [RecurringTransaction]
    ) -> [DetectedRecurringPattern] {

        // Step 1: Group by normalized merchant name
        let merchantGroups = groupByNormalizedMerchant(transactions)

        var patterns: [DetectedRecurringPattern] = []

        for (normalizedMerchant, merchantTransactions) in merchantGroups {
            // Step 2: Need minimum occurrences
            guard merchantTransactions.count >= Self.minimumOccurrences else { continue }

            // Skip dismissed merchants
            guard !dismissedMerchants.contains(normalizedMerchant) else { continue }

            // Step 3: Check if already covered by an active RecurringTransaction
            let existingNames = Set(existingRecurring.map { normalizeMerchant($0.merchantName) })
            guard !existingNames.contains(normalizedMerchant) else { continue }

            // Step 4: Sort by date and compute intervals
            let sorted = merchantTransactions.sorted { $0.date < $1.date }
            let intervals = computeIntervals(sorted)

            guard !intervals.isEmpty else { continue }

            // Step 5: Detect frequency from intervals
            guard let (frequency, matchRatio) = detectFrequency(from: intervals) else { continue }

            // Must have at least 60% match
            guard matchRatio >= 0.60 else { continue }

            // Step 6: Check amount consistency
            let amounts = sorted.map { $0.amount }
            let medianAmount = Self.median(amounts)
            let avgAmount = amounts.reduce(0, +) / Double(amounts.count)

            // Step 7: Calculate confidence
            let daysSinceLast = Calendar.current.dateComponents(
                [.day], from: sorted.last!.date, to: Date.now
            ).day ?? 999

            let confidence = calculateConfidence(
                matchRatio: matchRatio,
                count: sorted.count,
                recencyDays: daysSinceLast
            )

            guard confidence >= Self.minimumConfidence else { continue }

            // Step 8: Determine income/expense direction (majority vote)
            let incomeCount = sorted.filter { $0.isIncome }.count
            let isIncome = incomeCount > sorted.count / 2

            // Step 9: Find most common category and account
            let (categoryID, categoryName) = mostCommonCategory(in: sorted)
            let (accountID, accountName) = mostCommonAccount(in: sorted)

            // Step 10: Determine finance type (majority vote)
            let businessCount = sorted.filter { $0.financeType == .business }.count
            let financeType: Transaction.FinanceType = businessCount > sorted.count / 2 ? .business : .personal

            // Step 11: Estimate next occurrence
            let estimatedNext = frequency.nextDate(from: sorted.last!.date)

            // Step 12: Use original casing from most recent transaction
            let displayMerchantName = sorted.last!.merchantName

            let pattern = DetectedRecurringPattern(
                id: UUID(),
                merchantName: displayMerchantName,
                averageAmount: avgAmount,
                medianAmount: medianAmount,
                amountMin: amounts.min() ?? avgAmount,
                amountMax: amounts.max() ?? avgAmount,
                detectedFrequency: frequency,
                confidence: confidence,
                transactionCount: sorted.count,
                isIncome: isIncome,
                financeType: financeType,
                mostRecentDate: sorted.last!.date,
                estimatedNextDate: estimatedNext,
                matchingTransactionIDs: sorted.map { $0.id },
                suggestedCategoryID: categoryID,
                suggestedCategoryName: categoryName,
                suggestedAccountID: accountID,
                suggestedAccountName: accountName
            )

            patterns.append(pattern)
        }

        // Sort by confidence descending
        return patterns.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - User Actions

    /// Accept a detected pattern and create a RecurringTransaction from it.
    @discardableResult
    func acceptPattern(_ pattern: DetectedRecurringPattern, in context: ModelContext) -> RecurringTransaction {
        // Look up the category and account by ID
        var category: Category?
        if let catID = pattern.suggestedCategoryID {
            let descriptor = FetchDescriptor<Category>(
                predicate: #Predicate<Category> { $0.id == catID }
            )
            category = try? context.fetch(descriptor).first
        }

        var account: Account?
        if let accID = pattern.suggestedAccountID {
            let descriptor = FetchDescriptor<Account>(
                predicate: #Predicate<Account> { $0.id == accID }
            )
            account = try? context.fetch(descriptor).first
        }

        let recurring = RecurringTransaction(
            amount: pattern.medianAmount,
            merchantName: pattern.merchantName,
            note: pattern.merchantName,
            isIncome: pattern.isIncome,
            financeType: pattern.financeType,
            frequency: pattern.detectedFrequency,
            startDate: pattern.mostRecentDate,
            category: category,
            account: account,
            isActive: true
        )

        context.insert(recurring)

        do {
            try context.save()
            logger.info("Accepted pattern: \(pattern.merchantName) (\(pattern.detectedFrequency.displayName))")
        } catch {
            logger.error("Failed to save accepted pattern: \(error.localizedDescription)")
        }

        // Remove from detected list
        detectedPatterns.removeAll { $0.id == pattern.id }

        return recurring
    }

    /// Dismiss a detected pattern so it won't appear again.
    func dismissPattern(_ pattern: DetectedRecurringPattern) {
        let normalized = normalizeMerchant(pattern.merchantName)
        dismissedMerchants.insert(normalized)
        saveDismissedMerchants()

        // Remove from detected list
        detectedPatterns.removeAll { $0.id == pattern.id }

        logger.info("Dismissed pattern: \(pattern.merchantName)")
    }

    /// Clear all dismissed merchants (allows re-detection).
    func clearDismissedPatterns() {
        dismissedMerchants.removeAll()
        saveDismissedMerchants()
        logger.info("Cleared all dismissed patterns")
    }

    // MARK: - Private Algorithm Helpers

    /// Normalize merchant name for grouping (lowercase, trimmed).
    private func normalizeMerchant(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Group transactions by normalized merchant name.
    private func groupByNormalizedMerchant(_ transactions: [Transaction]) -> [String: [Transaction]] {
        var groups: [String: [Transaction]] = [:]
        for transaction in transactions {
            let key = normalizeMerchant(transaction.merchantName)
            guard !key.isEmpty else { continue }
            groups[key, default: []].append(transaction)
        }
        return groups
    }

    /// Compute day-intervals between consecutive transactions (sorted by date ascending).
    private func computeIntervals(_ sortedTransactions: [Transaction]) -> [Double] {
        guard sortedTransactions.count >= 2 else { return [] }

        var intervals: [Double] = []
        for i in 1..<sortedTransactions.count {
            let prev = sortedTransactions[i - 1].date
            let curr = sortedTransactions[i].date
            let daysBetween = curr.timeIntervalSince(prev) / 86400.0
            intervals.append(daysBetween)
        }
        return intervals
    }

    /// Detect frequency by clustering intervals into predefined windows.
    /// Returns the best-matching frequency and its match ratio, or nil if no match.
    private func detectFrequency(from intervals: [Double]) -> (frequency: RecurrenceFrequency, matchRatio: Double)? {
        guard !intervals.isEmpty else { return nil }

        var bestMatch: (frequency: RecurrenceFrequency, matchRatio: Double)?

        for window in frequencyWindows {
            let matchCount = intervals.filter { window.contains($0) }.count
            let ratio = Double(matchCount) / Double(intervals.count)

            if ratio >= 0.60 {
                if bestMatch == nil || ratio > bestMatch!.matchRatio {
                    bestMatch = (window.frequency, ratio)
                }
            }
        }

        return bestMatch
    }

    /// Calculate confidence score based on match quality, count, and recency.
    private func calculateConfidence(matchRatio: Double, count: Int, recencyDays: Int) -> Double {
        // Base confidence from interval match ratio
        let baseConfidence = matchRatio

        // Count bonus: +0.05 per occurrence beyond 3, capped at +0.15
        let countBonus = min(Double(count - Self.minimumOccurrences) * 0.05, 0.15)

        // Recency factor: penalize stale patterns
        let recencyFactor: Double = {
            if recencyDays <= 45 { return 1.0 }
            if recencyDays <= 90 { return 0.85 }
            if recencyDays <= 180 { return 0.6 }
            return 0.3
        }()

        return min((baseConfidence + countBonus) * recencyFactor, 1.0)
    }

    /// Find the most common category among transactions.
    private func mostCommonCategory(in transactions: [Transaction]) -> (UUID?, String?) {
        var counts: [UUID: (count: Int, name: String)] = [:]
        for transaction in transactions {
            if let category = transaction.category {
                let existing = counts[category.id]
                counts[category.id] = (count: (existing?.count ?? 0) + 1, name: category.name)
            }
        }
        guard let best = counts.max(by: { $0.value.count < $1.value.count }) else {
            return (nil, nil)
        }
        return (best.key, best.value.name)
    }

    /// Find the most common account among transactions.
    private func mostCommonAccount(in transactions: [Transaction]) -> (UUID?, String?) {
        var counts: [UUID: (count: Int, name: String)] = [:]
        for transaction in transactions {
            if let account = transaction.account {
                let existing = counts[account.id]
                counts[account.id] = (count: (existing?.count ?? 0) + 1, name: account.name)
            }
        }
        guard let best = counts.max(by: { $0.value.count < $1.value.count }) else {
            return (nil, nil)
        }
        return (best.key, best.value.name)
    }

    /// Compute the median of an array of doubles.
    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        }
        return sorted[mid]
    }

    // MARK: - Persistence

    private func loadDismissedMerchants() {
        if let saved = UserDefaults.standard.array(forKey: dismissedMerchantsKey) as? [String] {
            dismissedMerchants = Set(saved)
        }
    }

    private func saveDismissedMerchants() {
        UserDefaults.standard.set(Array(dismissedMerchants), forKey: dismissedMerchantsKey)
    }
}
