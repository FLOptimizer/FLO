//  CashFlowForecastService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Cash Flow Forecasting Engine
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Multi-layer projection engine that forecasts future account balances using:
//  1. Current account balances as starting point
//  2. Known recurring income/expenses from RecurringTransaction templates
//  3. Predicted variable spending from BudgetPredictionService
//  4. Historical seasonality adjustments
//
//  FEATURES v1.0:
//  ✅ Daily balance projections for 1/3/6/12 month horizons
//  ✅ Multi-layer forecast: starting balance + recurring + variable + seasonality
//  ✅ Upcoming bills timeline from active RecurringTransaction templates
//  ✅ Danger zone detection when projected balance drops below threshold
//  ✅ Lowest projected balance tracking with date
//  ✅ Thread-safe singleton matching FLO service pattern

import Foundation
import SwiftData
import OSLog

// MARK: - Data Structures

/// A single day's projected balance point for charting.
struct DailyBalancePoint: Identifiable {
    let id = UUID()
    let date: Date
    let projectedBalance: Double
    let isHistorical: Bool
    let recurringIncome: Double
    let recurringExpenses: Double
    let variableSpending: Double
}

/// Forecast time horizon options.
enum ForecastHorizon: Int, CaseIterable, Identifiable {
    case oneMonth = 1
    case threeMonths = 3
    case sixMonths = 6
    case twelveMonths = 12

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMonth: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .twelveMonths: return "1Y"
        }
    }

    var fullDisplayName: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        case .sixMonths: return "6 Months"
        case .twelveMonths: return "12 Months"
        }
    }
}

/// An upcoming bill/income from a recurring transaction template.
struct UpcomingBill: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let dueDate: Date
    let isIncome: Bool
    let frequency: RecurrenceFrequency

    var formattedAmount: String {
        amount.formatted(.currency(code: "USD"))
    }

    var formattedDate: String {
        dueDate.formatted(date: .abbreviated, time: .omitted)
    }
}

/// A date range where the projected balance falls below the user's threshold.
struct DangerZone: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let lowestBalance: Double

    var durationDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
}

/// The complete result of a cash flow forecast.
struct ForecastResult {
    let dailyBalances: [DailyBalancePoint]
    let upcomingBills: [UpcomingBill]
    let dangerZones: [DangerZone]
    let projectedEndBalance: Double
    let lowestProjectedBalance: Double
    let lowestBalanceDate: Date?
    let startingBalance: Double
    let horizon: ForecastHorizon

    /// Whether any danger zones exist
    var hasDangerZones: Bool { !dangerZones.isEmpty }

    /// Net change over the forecast period
    var netChange: Double { projectedEndBalance - startingBalance }

    /// Whether the balance is trending up
    var isTrendingUp: Bool { netChange > 0 }

    /// Formatted starting balance
    var formattedStartingBalance: String {
        startingBalance.formatted(.currency(code: "USD"))
    }

    /// Formatted projected end balance
    var formattedEndBalance: String {
        projectedEndBalance.formatted(.currency(code: "USD"))
    }

    /// Formatted lowest balance
    var formattedLowestBalance: String {
        lowestProjectedBalance.formatted(.currency(code: "USD"))
    }
}

// MARK: - Cash Flow Forecast Service

/// Multi-layer cash flow projection engine.
@MainActor
final class CashFlowForecastService: ObservableObject {

    // MARK: - Singleton

    static let shared = CashFlowForecastService()
    private init() {}

    private let logger = Logger(
        subsystem: "com.finchandpoppy.flo",
        category: "CashFlowForecast"
    )

    // MARK: - Published State

    /// The current forecast result (nil until first generation)
    @Published private(set) var currentForecast: ForecastResult?

    /// Whether a forecast is being generated
    @Published private(set) var isForecasting = false

    // MARK: - Primary Forecast Method

    /// Generate a cash flow forecast.
    ///
    /// - Parameters:
    ///   - container: ModelContainer for data access
    ///   - horizon: How far into the future to project
    ///   - selectedAccountIDs: Specific accounts to include (nil = all active accounts)
    ///   - balanceThreshold: Balance level that triggers danger zone warnings (default: 0)
    /// - Returns: A complete ForecastResult
    @discardableResult
    func generateForecast(
        in container: ModelContainer,
        horizon: ForecastHorizon = .threeMonths,
        selectedAccountIDs: Set<UUID>? = nil,
        balanceThreshold: Double = 0
    ) async -> ForecastResult {
        guard !isForecasting else {
            logger.info("Forecast already in progress, skipping")
            return currentForecast ?? emptyForecast(horizon: horizon)
        }

        isForecasting = true
        defer { isForecasting = false }

        logger.info("Generating \(horizon.fullDisplayName) cash flow forecast...")

        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)

        guard let endDate = calendar.date(byAdding: .month, value: horizon.rawValue, to: today) else {
            logger.error("Failed to calculate forecast end date")
            return emptyForecast(horizon: horizon)
        }

        do {
            // LAYER 1: Starting balance — sum of all active account balances
            let startingBalance = try calculateStartingBalance(
                context: context,
                selectedAccountIDs: selectedAccountIDs
            )
            logger.info("Layer 1: Starting balance = \(startingBalance.formatted(.currency(code: "USD")))")

            // LAYER 2: Recurring transactions — project known future events
            let recurringEvents = try projectRecurringEvents(
                context: context,
                from: today,
                to: endDate,
                calendar: calendar
            )
            logger.info("Layer 2: \(recurringEvents.count) recurring events projected")

            // LAYER 3: Variable spending prediction from historical data
            let (dailyVariableSpending, seasonalIndices) = try calculateVariableSpending(
                context: context,
                calendar: calendar
            )
            logger.info("Layer 3: Daily variable spending = \(dailyVariableSpending.formatted(.currency(code: "USD")))")

            // LAYER 4: Build daily balance projections
            let dailyBalances = buildDailyProjection(
                startingBalance: startingBalance,
                startDate: today,
                endDate: endDate,
                recurringEvents: recurringEvents,
                dailyVariableSpending: dailyVariableSpending,
                seasonalIndices: seasonalIndices,
                calendar: calendar
            )

            // Extract upcoming bills (next 10 recurring expenses)
            let upcomingBills = extractUpcomingBills(from: recurringEvents, limit: 10)

            // Detect danger zones
            let dangerZones = detectDangerZones(
                dailyBalances: dailyBalances,
                threshold: balanceThreshold,
                calendar: calendar
            )

            // Find lowest point
            let lowestPoint = dailyBalances.min(by: { $0.projectedBalance < $1.projectedBalance })

            let result = ForecastResult(
                dailyBalances: dailyBalances,
                upcomingBills: upcomingBills,
                dangerZones: dangerZones,
                projectedEndBalance: dailyBalances.last?.projectedBalance ?? startingBalance,
                lowestProjectedBalance: lowestPoint?.projectedBalance ?? startingBalance,
                lowestBalanceDate: lowestPoint?.date,
                startingBalance: startingBalance,
                horizon: horizon
            )

            currentForecast = result
            logger.info("Forecast complete: \(dailyBalances.count) daily points, \(dangerZones.count) danger zones, end balance \(result.formattedEndBalance)")

            return result

        } catch {
            logger.error("Forecast generation failed: \(error.localizedDescription)")
            return emptyForecast(horizon: horizon)
        }
    }

    // MARK: - Layer 1: Starting Balance

    private func calculateStartingBalance(
        context: ModelContext,
        selectedAccountIDs: Set<UUID>?
    ) throws -> Double {
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { $0.isActive }
        )
        let accounts = try context.fetch(accountDescriptor)

        return accounts
            .filter { selectedAccountIDs == nil || selectedAccountIDs!.contains($0.id) }
            .reduce(0.0) { $0 + $1.currentBalance }
    }

    // MARK: - Layer 2: Recurring Events

    /// A single projected recurring event (income or expense on a specific date).
    private struct RecurringEvent {
        let name: String
        let amount: Double
        let date: Date
        let isIncome: Bool
        let frequency: RecurrenceFrequency
    }

    private func projectRecurringEvents(
        context: ModelContext,
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) throws -> [RecurringEvent] {
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate<RecurringTransaction> { $0.isActive }
        )
        let allRecurring = try context.fetch(descriptor)
        var events: [RecurringEvent] = []

        for recurring in allRecurring {
            // Start from the next occurrence after today
            var nextDate = recurring.nextOccurrence ?? recurring.startDate

            // Safety: cap at 500 events per recurring to prevent runaway
            var count = 0

            while nextDate <= endDate && count < 500 {
                if nextDate >= startDate {
                    events.append(RecurringEvent(
                        name: recurring.displayName,
                        amount: recurring.amount,
                        date: nextDate,
                        isIncome: recurring.isIncome,
                        frequency: recurring.frequency
                    ))
                }

                // Advance to next occurrence
                guard let next = recurring.frequency.nextDate(from: nextDate) else { break }
                nextDate = next
                count += 1
            }
        }

        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Layer 3: Variable Spending

    private func calculateVariableSpending(
        context: ModelContext,
        calendar: Calendar
    ) throws -> (dailyAverage: Double, seasonalIndices: [Int: Double]) {
        // Fetch last 12 months of non-transfer, non-income transactions
        guard let cutoffDate = calendar.date(byAdding: .month, value: -12, to: Date.now) else {
            return (0, [:])
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.date >= cutoffDate &&
                !transaction.isTransfer &&
                !transaction.isIncome
            }
        )
        let expenses = try context.fetch(descriptor)

        guard !expenses.isEmpty else { return (0, [:]) }

        // Group by month and compute monthly totals
        var monthlyTotals: [Int: [Double]] = [:]  // month number -> [amounts per occurrence of that month]
        var allMonthlyTotals: [String: Double] = [:] // "YYYY-MM" -> total

        for expense in expenses {
            let month = calendar.component(.month, from: expense.date)
            let yearMonth = "\(calendar.component(.year, from: expense.date))-\(month)"
            allMonthlyTotals[yearMonth, default: 0] += expense.amount
        }

        // Compute average monthly total
        let months = allMonthlyTotals.values
        let overallMonthlyAverage = months.isEmpty ? 0 : months.reduce(0, +) / Double(months.count)

        // Compute seasonality index per calendar month
        var seasonalIndices: [Int: Double] = [:]
        for (yearMonth, total) in allMonthlyTotals {
            let components = yearMonth.split(separator: "-")
            if let monthNum = Int(components.last ?? "0") {
                monthlyTotals[monthNum, default: []].append(total)
            }
        }

        for (month, totals) in monthlyTotals {
            let monthAvg = totals.reduce(0, +) / Double(totals.count)
            seasonalIndices[month] = overallMonthlyAverage > 0 ? monthAvg / overallMonthlyAverage : 1.0
        }

        // Daily average variable spending
        let dailyAverage = overallMonthlyAverage / 30.0

        return (dailyAverage, seasonalIndices)
    }

    // MARK: - Layer 4: Daily Projection

    private func buildDailyProjection(
        startingBalance: Double,
        startDate: Date,
        endDate: Date,
        recurringEvents: [RecurringEvent],
        dailyVariableSpending: Double,
        seasonalIndices: [Int: Double],
        calendar: Calendar
    ) -> [DailyBalancePoint] {
        var balance = startingBalance
        var points: [DailyBalancePoint] = []
        var currentDate = startDate

        // Index recurring events by day for O(1) lookup
        var eventsByDay: [String: [RecurringEvent]] = [:]
        let dayFormatter = DateFormatter.isoDate

        for event in recurringEvents {
            let key = dayFormatter.string(from: event.date)
            eventsByDay[key, default: []].append(event)
        }

        while currentDate <= endDate {
            let dayKey = dayFormatter.string(from: currentDate)
            let month = calendar.component(.month, from: currentDate)
            let seasonalFactor = seasonalIndices[month] ?? 1.0

            // Daily recurring income/expenses
            var dayRecurringIncome: Double = 0
            var dayRecurringExpenses: Double = 0

            if let dayEvents = eventsByDay[dayKey] {
                for event in dayEvents {
                    if event.isIncome {
                        dayRecurringIncome += event.amount
                    } else {
                        dayRecurringExpenses += event.amount
                    }
                }
            }

            // Variable spending adjusted for seasonality
            let adjustedDailySpending = dailyVariableSpending * seasonalFactor

            // Update balance
            balance += dayRecurringIncome
            balance -= dayRecurringExpenses
            balance -= adjustedDailySpending

            points.append(DailyBalancePoint(
                date: currentDate,
                projectedBalance: balance,
                isHistorical: false,
                recurringIncome: dayRecurringIncome,
                recurringExpenses: dayRecurringExpenses,
                variableSpending: adjustedDailySpending
            ))

            // Advance one day
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }

        return points
    }

    // MARK: - Upcoming Bills

    private func extractUpcomingBills(from events: [RecurringEvent], limit: Int) -> [UpcomingBill] {
        // Already sorted by date from projectRecurringEvents
        return events
            .filter { !$0.isIncome }
            .prefix(limit)
            .map { event in
                UpcomingBill(
                    name: event.name,
                    amount: event.amount,
                    dueDate: event.date,
                    isIncome: event.isIncome,
                    frequency: event.frequency
                )
            }
    }

    // MARK: - Danger Zone Detection

    private func detectDangerZones(
        dailyBalances: [DailyBalancePoint],
        threshold: Double,
        calendar: Calendar
    ) -> [DangerZone] {
        var zones: [DangerZone] = []
        var currentZoneStart: Date?
        var currentLowest: Double = .infinity

        for point in dailyBalances {
            if point.projectedBalance < threshold {
                if currentZoneStart == nil {
                    currentZoneStart = point.date
                }
                currentLowest = min(currentLowest, point.projectedBalance)
            } else {
                if let start = currentZoneStart {
                    zones.append(DangerZone(
                        startDate: start,
                        endDate: point.date,
                        lowestBalance: currentLowest
                    ))
                    currentZoneStart = nil
                    currentLowest = .infinity
                }
            }
        }

        // Close any open zone at the end
        if let start = currentZoneStart, let lastDate = dailyBalances.last?.date {
            zones.append(DangerZone(
                startDate: start,
                endDate: lastDate,
                lowestBalance: currentLowest
            ))
        }

        return zones
    }

    // MARK: - Helpers

    private func emptyForecast(horizon: ForecastHorizon) -> ForecastResult {
        ForecastResult(
            dailyBalances: [],
            upcomingBills: [],
            dangerZones: [],
            projectedEndBalance: 0,
            lowestProjectedBalance: 0,
            lowestBalanceDate: nil,
            startingBalance: 0,
            horizon: horizon
        )
    }
}
