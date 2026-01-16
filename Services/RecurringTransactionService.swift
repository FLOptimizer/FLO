//  RecurringTransactionService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 - Added utility methods for badges and upcoming transactions
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.0:
//  ✅ Added pendingInstanceCount(in:) for UI badges
//  ✅ Added upcomingRecurringTransactions(in:) for dashboard/widgets
//  ✅ Added createPendingInstances(for:in:) for single recurring processing
//  ✅ Added getStatistics(in:) for summary analytics
//  ✅ Added RecurringStatistics struct
//  ✅ Added monthlyMultiplier extension for frequency normalization
//
//  INHERITED FROM v2.0:
//  ✅ Transactions created with SCHEDULED date, not today's date
//  ✅ Properly catches up missed instances with correct dates
//  ✅ Uses calendar-based date calculations (requires RecurringTransaction v2.3+)
//  ✅ Fixed double-negative amount issue
//  ✅ OSLog for production-ready logging
//  ✅ 1000 instance safety limit prevents infinite loops

import Foundation
import SwiftData
import OSLog

/// Elite recurring transaction engine — handles catch-up, timezone safety, background tasks, zero duplicates.
@MainActor
final class RecurringTransactionService {
    static let shared = RecurringTransactionService()
    private let logger = Logger(subsystem: "com.finchandpoppy.flo", category: "Recurring")
    
    private init() {}
    
    // MARK: - Primary Engine
    
    /// Creates all missing instances for active recurring transactions.
    /// Safe to call on launch, foreground, background refresh, or daily timer.
    func createPendingInstances(in container: ModelContainer) async {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isActive }
        )
        
        do {
            let recurrings = try context.fetch(descriptor)
            guard !recurrings.isEmpty else {
                logger.info("No active recurring transactions found")
                return
            }
            
            logger.info("📋 Processing \(recurrings.count) active recurring transactions...")
            var totalCreated = 0
            
            for recurring in recurrings {
                var createdThisCycle = 0
                var instancesCreated: [(date: Date, amount: Double)] = []
                
                // ✅ FIX: Calculate actual due dates and create with those dates
                var nextDue = recurring.nextOccurrence ?? recurring.startDate
                
                // Keep creating until caught up (e.g. user offline for months)
                while nextDue <= today {
                    // Check if already created for this date
                    if let lastCreated = recurring.lastCreated,
                       calendar.isDate(lastCreated, inSameDayAs: nextDue) {
                        logger.debug("Already created for \(nextDue.formatted(date: .abbreviated, time: .omitted))")
                        break
                    }
                    
                    // Check if past end date
                    if let endDate = recurring.endDate, nextDue > endDate {
                        logger.info("Recurring '\(recurring.merchantName)' ended on \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        recurring.deactivate()
                        break
                    }
                    
                    // ✅ FIX: Create with SCHEDULED date, not today
                    if let transaction = recurring.createNextInstance(in: context, on: nextDue) {
                        createdThisCycle += 1
                        totalCreated += 1
                        instancesCreated.append((date: nextDue, amount: transaction.amount))
                        
                        logger.info("✅ Created: \(transaction.merchantName) - \(transaction.formattedAmount) on \(nextDue.formatted(date: .abbreviated, time: .omitted))")
                    } else {
                        logger.warning("Failed to create instance for \(recurring.merchantName) on \(nextDue.formatted(date: .abbreviated, time: .omitted))")
                        break
                    }
                    
                    // Calculate next due date
                    if let next = recurring.nextOccurrence {
                        nextDue = next
                    } else {
                        logger.info("No more occurrences for '\(recurring.merchantName)'")
                        break
                    }
                    
                    // Safety: prevent infinite loops
                    if createdThisCycle > 1000 {
                        logger.error("⚠️ Safety limit reached for '\(recurring.merchantName)' - stopping at 1000 instances")
                        break
                    }
                }
                
                if createdThisCycle > 0 {
                    if createdThisCycle > 1 {
                        logger.notice("📦 Caught up \(createdThisCycle) missed instances for: \(recurring.merchantName)")
                    }
                    
                    // Log all created instances for debugging
                    for instance in instancesCreated {
                        logger.debug("  → \(instance.date.formatted(date: .abbreviated, time: .omitted)): \(instance.amount.formatted(.currency(code: "USD")))")
                    }
                }
            }
            
            if totalCreated > 0 {
                try context.save()
                logger.info("✅ Recurring engine created \(totalCreated) transaction(s) total")
            } else {
                logger.info("ℹ️ No pending recurring transactions to create")
            }
            
        } catch {
            logger.error("❌ Recurring engine failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Single Recurring Processing
    
    /// Creates pending instances for a specific recurring transaction.
    /// Useful when a new recurring transaction is created or reactivated.
    /// - Parameters:
    ///   - recurring: The recurring transaction to process
    ///   - context: The ModelContext to use
    /// - Returns: Number of instances created
    @discardableResult
    func createPendingInstances(for recurring: RecurringTransaction, in context: ModelContext) -> Int {
        guard recurring.isActive else { return 0 }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        var createdCount = 0
        
        var nextDue = recurring.nextOccurrence ?? recurring.startDate
        
        while nextDue <= today && createdCount < 1000 {
            // Check if already created for this date
            if let lastCreated = recurring.lastCreated,
               calendar.isDate(lastCreated, inSameDayAs: nextDue) {
                break
            }
            
            // Check if past end date
            if let endDate = recurring.endDate, nextDue > endDate {
                recurring.deactivate()
                break
            }
            
            // Create with scheduled date
            if let _ = recurring.createNextInstance(in: context, on: nextDue) {
                createdCount += 1
                logger.info("✅ Created instance for '\(recurring.displayName)' on \(nextDue.formatted(date: .abbreviated, time: .omitted))")
            } else {
                break
            }
            
            // Get next occurrence
            if let next = recurring.nextOccurrence {
                nextDue = next
            } else {
                break
            }
        }
        
        if createdCount > 0 {
            do {
                try context.save()
                logger.info("✅ Created \(createdCount) instance(s) for '\(recurring.displayName)'")
            } catch {
                logger.error("❌ Failed to save recurring instances: \(error.localizedDescription)")
            }
        }
        
        return createdCount
    }
    
    // MARK: - Query Methods
    
    /// Returns all recurring transactions that are overdue (for UI badge, notifications, etc.)
    func getOverdue(in container: ModelContainer) -> [RecurringTransaction] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<RecurringTransaction>(
            predicate: #Predicate { $0.isActive }
        )
        
        do {
            let all = try context.fetch(descriptor)
            return all.filter { $0.isOverdue }
        } catch {
            logger.error("Failed to fetch overdue recurrings: \(error)")
            return []
        }
    }
    
    /// Checks if any recurring transactions have pending instances.
    /// Useful for showing badges or notifications.
    /// - Parameter container: The ModelContainer to use
    /// - Returns: Count of recurring transactions with pending instances
    func pendingInstanceCount(in container: ModelContainer) async -> Int {
        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        
        do {
            let descriptor = FetchDescriptor<RecurringTransaction>(
                predicate: #Predicate<RecurringTransaction> { $0.isActive }
            )
            let recurringTransactions = try context.fetch(descriptor)
            
            var pendingCount = 0
            
            for recurring in recurringTransactions {
                // Check if next occurrence is due
                if let nextDue = recurring.nextOccurrence, nextDue <= today {
                    // Make sure we haven't already created for this date
                    if let lastCreated = recurring.lastCreated {
                        if !calendar.isDate(lastCreated, inSameDayAs: nextDue) {
                            pendingCount += 1
                        }
                    } else {
                        // Never created, so it's pending
                        pendingCount += 1
                    }
                }
            }
            
            return pendingCount
            
        } catch {
            logger.error("❌ Failed to check pending instances: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Get upcoming recurring transactions within a specified number of days.
    /// - Parameters:
    ///   - container: The ModelContainer to use
    ///   - days: Number of days to look ahead (default: 7)
    /// - Returns: Array of recurring transactions due within the specified period, sorted by next occurrence
    func upcomingRecurringTransactions(in container: ModelContainer, days: Int = 7) async -> [RecurringTransaction] {
        let context = ModelContext(container)
        let calendar = Calendar.current
        
        do {
            let descriptor = FetchDescriptor<RecurringTransaction>(
                predicate: #Predicate<RecurringTransaction> { $0.isActive }
            )
            let recurringTransactions = try context.fetch(descriptor)
            
            guard let futureDate = calendar.date(byAdding: .day, value: days, to: Date.now) else {
                return []
            }
            
            let upcoming = recurringTransactions.filter { recurring in
                guard let nextDate = recurring.nextOccurrence else { return false }
                return nextDate <= futureDate
            }
            
            // Sort by next occurrence date (soonest first)
            return upcoming.sorted { lhs, rhs in
                let lhsDate = lhs.nextOccurrence ?? .distantFuture
                let rhsDate = rhs.nextOccurrence ?? .distantFuture
                return lhsDate < rhsDate
            }
            
        } catch {
            logger.error("❌ Failed to fetch upcoming recurring: \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    /// Get summary statistics for recurring transactions.
    /// - Parameter container: The ModelContainer to use
    /// - Returns: Summary statistics struct
    func getStatistics(in container: ModelContainer) async -> RecurringStatistics {
        let context = ModelContext(container)
        
        do {
            let allDescriptor = FetchDescriptor<RecurringTransaction>()
            let all = try context.fetch(allDescriptor)
            
            let active = all.filter { $0.isActive }
            let inactive = all.filter { !$0.isActive }
            let overdue = active.filter { $0.isOverdue }
            
            // Calculate monthly totals (exact - only monthly frequency)
            let monthlyIncome = active
                .filter { $0.isIncome && $0.frequency == .monthly }
                .reduce(0.0) { $0 + $1.amount }
            
            let monthlyExpenses = active
                .filter { !$0.isIncome && $0.frequency == .monthly }
                .reduce(0.0) { $0 + $1.amount }
            
            // Estimate total monthly (normalize all frequencies)
            let estimatedMonthlyIncome = active
                .filter { $0.isIncome }
                .reduce(0.0) { $0 + $1.amount * $1.frequency.monthlyMultiplier }
            
            let estimatedMonthlyExpenses = active
                .filter { !$0.isIncome }
                .reduce(0.0) { $0 + $1.amount * $1.frequency.monthlyMultiplier }
            
            return RecurringStatistics(
                totalCount: all.count,
                activeCount: active.count,
                inactiveCount: inactive.count,
                overdueCount: overdue.count,
                monthlyIncomeExact: monthlyIncome,
                monthlyExpensesExact: monthlyExpenses,
                estimatedMonthlyIncome: estimatedMonthlyIncome,
                estimatedMonthlyExpenses: estimatedMonthlyExpenses
            )
            
        } catch {
            logger.error("❌ Failed to get recurring statistics: \(error.localizedDescription)")
            return RecurringStatistics.empty
        }
    }
    
    // MARK: - Manual Trigger
    
    /// Manual trigger for debugging - processes all pending instances immediately
    func processNow(in container: ModelContainer) async {
        logger.info("🔧 Manual trigger: Processing recurring transactions...")
        await createPendingInstances(in: container)
    }
}

// MARK: - Supporting Types

/// Statistics summary for recurring transactions
struct RecurringStatistics: Sendable {
    let totalCount: Int
    let activeCount: Int
    let inactiveCount: Int
    let overdueCount: Int
    let monthlyIncomeExact: Double
    let monthlyExpensesExact: Double
    let estimatedMonthlyIncome: Double
    let estimatedMonthlyExpenses: Double
    
    /// Estimated monthly net (income - expenses) across all frequencies
    var estimatedMonthlyNet: Double {
        estimatedMonthlyIncome - estimatedMonthlyExpenses
    }
    
    /// Whether there are any overdue recurring transactions
    var hasOverdue: Bool {
        overdueCount > 0
    }
    
    /// Formatted estimated monthly net
    var formattedMonthlyNet: String {
        estimatedMonthlyNet.formatted(.currency(code: "USD"))
    }
    
    /// Empty statistics for error cases
    static let empty = RecurringStatistics(
        totalCount: 0,
        activeCount: 0,
        inactiveCount: 0,
        overdueCount: 0,
        monthlyIncomeExact: 0,
        monthlyExpensesExact: 0,
        estimatedMonthlyIncome: 0,
        estimatedMonthlyExpenses: 0
    )
}

// MARK: - Frequency Extension

extension RecurrenceFrequency {
    /// Multiplier to normalize amounts to monthly equivalent
    var monthlyMultiplier: Double {
        switch self {
        case .weekly:     return 4.33    // 52 weeks / 12 months
        case .biweekly:   return 2.17    // 26 periods / 12 months
        case .monthly:    return 1.0
        case .quarterly:  return 0.33    // 4 times / 12 months
        case .yearly:     return 0.083   // 1 time / 12 months
        }
    }
}

// MARK: - Usage Examples
/*
 // On app launch (FLOApp.swift):
 Task { @MainActor in
     await RecurringTransactionService.shared.createPendingInstances(in: container)
 }
 
 // Check for pending count (for badge):
 let pendingCount = await RecurringTransactionService.shared.pendingInstanceCount(in: container)
 if pendingCount > 0 {
     // Show badge on recurring tab
 }
 
 // Get upcoming recurring transactions for dashboard:
 let upcoming = await RecurringTransactionService.shared.upcomingRecurringTransactions(in: container, days: 7)
 for item in upcoming {
     print("\(item.displayName) due: \(item.nextOccurrence?.formatted() ?? "N/A")")
 }
 
 // Get statistics for settings/dashboard:
 let stats = await RecurringTransactionService.shared.getStatistics(in: container)
 print("Active: \(stats.activeCount), Overdue: \(stats.overdueCount)")
 print("Est. Monthly Net: \(stats.formattedMonthlyNet)")
 
 // When creating a new recurring transaction:
 let recurring = RecurringTransaction(
     amount: 15.99,
     merchantName: "Netflix",
     frequency: .monthly,
     startDate: Date()
 )
 context.insert(recurring)
 try context.save()
 
 // Create any pending instances immediately:
 RecurringTransactionService.shared.createPendingInstances(for: recurring, in: context)
 */
