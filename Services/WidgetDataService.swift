//  WidgetDataService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Elite production-ready widget data management
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v1.2:
//  - FIXED: Swift 6 concurrency - made sharedDefaults nonisolated
//  - Made all UserDefaults access thread-safe
//  - UserDefaults is internally thread-safe, safe to use from any context
//

import Foundation
import SwiftData
import OSLog
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Logging

extension Logger {
    private static var subsystem = "com.finchandpoppy.flo"
    static let widget = Logger(subsystem: subsystem, category: "WidgetDataService")
}

// MARK: - Widget Shared Data Models

/// Shared data structure for widget display
/// Thread-safe and Sendable for cross-process communication
struct WidgetData: Codable, Sendable {
    let balance: Double
    let income: Double
    let expenses: Double
    let transactionCount: Int
    let lastUpdated: Date
    let quickStats: QuickStats
    
    struct QuickStats: Codable, Sendable {
        let thisWeekExpenses: Double
        let thisMonthExpenses: Double
        let pendingInvoicesCount: Int
        let upcomingTaxDeadline: Date?
    }
}

/// Timer state for Control Widget
struct WidgetTimerState: Codable, Sendable {
    let isRunning: Bool
    let startTime: Date?
    let elapsedSeconds: TimeInterval
    let tripId: UUID?
    
    static let initial = WidgetTimerState(
        isRunning: false,
        startTime: nil,
        elapsedSeconds: 0,
        tripId: nil
    )
}

// MARK: - Widget Data Service

/// Centralized service for managing widget data
/// Uses App Group for cross-process data sharing
@MainActor
final class WidgetDataService {
    
    // MARK: - Version
    
    static let version = "1.3"
    
    // MARK: - Singleton
    
    static let shared = WidgetDataService()
    
    private init() {}
    
    // MARK: - Constants
    
    private enum Constants {
        static let appGroupIdentifier = "group.com.finchandpoppy.flo"
        static let widgetDataKey = "com.finchandpoppy.flo.widgetData"
        static let timerStateKey = "com.finchandpoppy.flo.timerState"
        static let lastUpdateKey = "com.finchandpoppy.flo.lastUpdate"
    }
    
    // MARK: - Tax Deadlines
    
    /// Configurable quarterly tax deadlines (month, day)
    /// Q1: April 15, Q2: June 15, Q3: September 15, Q4: January 15 (next year)
    private let taxDeadlines: [(month: Int, day: Int)] = [
        (4, 15), // Q1
        (6, 15), // Q2
        (9, 15), // Q3
        (1, 15)  // Q4 (next year)
    ]
    
    // MARK: - Shared Defaults (Thread-Safe)
    
    /// UserDefaults is internally thread-safe, safe to access from any context
    private nonisolated var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Constants.appGroupIdentifier)
    }
    
    // MARK: - Error Types
    
    enum WidgetError: LocalizedError, Sendable {
        case appGroupUnavailable
        case encodingFailed(String)
        case decodingFailed(String)
        case noData
        case dateCalculationFailed
        
        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                return "App Group not configured properly"
            case .encodingFailed(let type):
                return "Failed to encode \(type) for widget"
            case .decodingFailed(let type):
                return "Failed to decode \(type) from widget storage"
            case .noData:
                return "No widget data available"
            case .dateCalculationFailed:
                return "Failed to calculate date ranges"
            }
        }
    }
    
    // MARK: - Update Widget Data
    
    /// Updates widget data with current transactions and invoices
    /// - Parameters:
    ///   - transactions: Array of transactions to calculate from
    ///   - invoices: Array of invoices for pending count
    /// - Throws: WidgetError if update fails
    nonisolated func updateWidgetData(
        transactions: [Transaction],
        invoices: [Invoice]
    ) async throws {
        guard let defaults = sharedDefaults else {
            throw WidgetError.appGroupUnavailable
        }
        
        // Calculate financial data
        let income = transactions
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let expenses = transactions
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let balance = income - expenses
        
        // Calculate quick stats with safe date handling
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            Logger.widget.error("❌ Failed to calculate date ranges")
            throw WidgetError.dateCalculationFailed
        }
        
        let thisWeekExpenses = transactions
            .filter { !$0.isIncome && $0.date >= weekAgo }
            .reduce(0) { $0 + $1.amount }
        
        let thisMonthExpenses = transactions
            .filter { !$0.isIncome && $0.date >= monthStart }
            .reduce(0) { $0 + $1.amount }
        
        let pendingInvoicesCount = invoices.filter { $0.status != .paid }.count
        
        // Create widget data
        let widgetData = WidgetData(
            balance: balance,
            income: income,
            expenses: expenses,
            transactionCount: transactions.count,
            lastUpdated: now,
            quickStats: WidgetData.QuickStats(
                thisWeekExpenses: thisWeekExpenses,
                thisMonthExpenses: thisMonthExpenses,
                pendingInvoicesCount: pendingInvoicesCount,
                upcomingTaxDeadline: calculateNextTaxDeadline()
            )
        )
        
        // Encode and save
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(widgetData)
            
            defaults.set(data, forKey: Constants.widgetDataKey)
            defaults.set(now, forKey: Constants.lastUpdateKey)
            defaults.synchronize()
            
            Logger.widget.info("✅ Widget data updated: Balance \(balance.formatted(.currency(code: "USD"))), \(transactions.count) transactions")
            
            // Refresh all widget timelines
            await refreshWidgets()
            
        } catch {
            throw WidgetError.encodingFailed("WidgetData")
        }
    }
    
    /// Convenience method for quick balance updates
    /// - Parameter balance: New balance value
    nonisolated func updateBalance(_ balance: Double) async {
        guard let defaults = sharedDefaults else { return }
        
        do {
            // Fetch existing data
            let existingData = try await fetchWidgetData()
            
            // Create new data with updated balance (immutable struct pattern)
            let updatedData = WidgetData(
                balance: balance,
                income: existingData.income,
                expenses: existingData.expenses,
                transactionCount: existingData.transactionCount,
                lastUpdated: Date(),
                quickStats: existingData.quickStats
            )
            
            // Encode and save
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(updatedData)
            
            defaults.set(data, forKey: Constants.widgetDataKey)
            defaults.set(updatedData.lastUpdated, forKey: Constants.lastUpdateKey)
            defaults.synchronize()
            
            Logger.widget.info("✅ Balance updated to \(balance.formatted(.currency(code: "USD")))")
            
            await refreshWidgets()
            
        } catch {
            Logger.widget.error("❌ Failed to update balance: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Fetch Widget Data
    
    /// Fetches current widget data from shared storage
    /// - Returns: WidgetData if available
    /// - Throws: WidgetError if fetch fails
    nonisolated func fetchWidgetData() async throws -> WidgetData {
        guard let defaults = sharedDefaults else {
            throw WidgetError.appGroupUnavailable
        }
        
        guard let data = defaults.data(forKey: Constants.widgetDataKey) else {
            throw WidgetError.noData
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetData.self, from: data)
        } catch {
            throw WidgetError.decodingFailed("WidgetData")
        }
    }
    
    // MARK: - Timer State Management
    
    /// Updates timer state for Control Widget
    /// - Parameter state: New timer state
    /// - Throws: WidgetError if update fails
    nonisolated func updateTimerState(_ state: WidgetTimerState) async throws {
        guard let defaults = sharedDefaults else {
            throw WidgetError.appGroupUnavailable
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            
            defaults.set(data, forKey: Constants.timerStateKey)
            defaults.synchronize()
            
            Logger.widget.info("✅ Timer state updated: \(state.isRunning ? "Running" : "Stopped")")
            
            await refreshWidgets()
        } catch {
            throw WidgetError.encodingFailed("WidgetTimerState")
        }
    }
    
    /// Fetches current timer state
    /// - Returns: WidgetTimerState (defaults to stopped if no data)
    /// - Throws: WidgetError if fetch fails
    nonisolated func fetchTimerState() async throws -> WidgetTimerState {
        guard let defaults = sharedDefaults else {
            throw WidgetError.appGroupUnavailable
        }
        
        guard let data = defaults.data(forKey: Constants.timerStateKey) else {
            // Return default stopped state if no data
            return WidgetTimerState.initial
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WidgetTimerState.self, from: data)
        } catch {
            throw WidgetError.decodingFailed("WidgetTimerState")
        }
    }
    
    // MARK: - Widget Refresh
    
    /// Refreshes all widget timelines
    private nonisolated func refreshWidgets() async {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        Logger.widget.info("🔄 Widget timelines reloaded")
        #endif
    }
    
    // MARK: - Helper Methods
    
    /// Calculates next quarterly tax deadline
    /// - Returns: Next upcoming deadline or nil if calculation fails
    private nonisolated func calculateNextTaxDeadline() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        for (month, day) in taxDeadlines {
            // For Q4 (January) or past deadlines, always check next year
            let year: Int
            if month == 1 {
                // Q4 deadline is always in next year
                year = currentYear + 1
            } else if month < currentMonth {
                // Past deadline this year, try next year
                year = currentYear + 1
            } else {
                // Upcoming deadline this year
                year = currentYear
            }
            
            if let deadline = calendar.date(from: DateComponents(year: year, month: month, day: day)),
               deadline > now {
                return deadline
            }
        }
        
        // Fallback: Q1 of next year
        return calendar.date(from: DateComponents(year: currentYear + 1, month: 4, day: 15))
    }
    
    // MARK: - Data Cleanup
    
    /// Clears all widget data (useful for testing/debugging/logout)
    nonisolated func clearWidgetData() async {
        guard let defaults = sharedDefaults else { return }
        
        defaults.removeObject(forKey: Constants.widgetDataKey)
        defaults.removeObject(forKey: Constants.timerStateKey)
        defaults.removeObject(forKey: Constants.lastUpdateKey)
        defaults.synchronize()
        
        await refreshWidgets()
        
        Logger.widget.info("🗑️ Widget data cleared")
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension WidgetDataService {
    /// Creates sample widget data for previews/testing
    nonisolated static func sampleWidgetData() -> WidgetData {
        WidgetData(
            balance: 5432.10,
            income: 10000.00,
            expenses: 4567.90,
            transactionCount: 42,
            lastUpdated: Date(),
            quickStats: WidgetData.QuickStats(
                thisWeekExpenses: 234.56,
                thisMonthExpenses: 1234.56,
                pendingInvoicesCount: 3,
                upcomingTaxDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date())
            )
        )
    }
    
    /// Creates sample timer state for previews/testing
    nonisolated static func sampleTimerState(running: Bool = false) -> WidgetTimerState {
        WidgetTimerState(
            isRunning: running,
            startTime: running ? Date() : nil,
            elapsedSeconds: running ? 123.0 : 0,
            tripId: running ? UUID() : nil
        )
    }
}
#endif
