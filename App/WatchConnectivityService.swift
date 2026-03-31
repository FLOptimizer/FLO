//  WatchConnectivityService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Added Combine import for ObservableObject
//  Version 1.2 - Fixed API mismatches with MileageTrackingService, TaxCalculationService, Transaction init, MileageTrip.distanceMiles
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLO (main app target ONLY)
//
//  ARCHITECTURE:
//  This is the iPhone-side counterpart to WatchSessionManager (Watch side).
//  It uses Option C (Hybrid) architecture:
//  - iPhone → Watch: Pushes WatchSnapshot via updateApplicationContext()
//  - Watch → iPhone: Receives WatchCommand via sendMessage() or transferUserInfo()
//  - iPhone executes commands against SwiftData, then pushes updated snapshot
//
//  DATA FLOW:
//  1. App launches → activateSession() → push initial snapshot
//  2. User adds transaction on iPhone → pushSnapshotToWatch()
//  3. User adds expense on Watch → receiveCommand() → create Transaction → pushSnapshot
//  4. User taps mileage on Watch → receiveCommand() → MileageTrackingService → pushSnapshot
//  5. Complication timeline requests → pushComplicationUpdate()
//
//  CALLED FROM:
//  - FLOApp.swift (activation on launch)
//  - DataManager / AddTransactionView (after transaction changes)
//  - MileageTrackingService (after trip state changes)
//  - SubscriptionManager (after tier changes)
//

#if os(iOS)
import Foundation
import Combine
import WatchConnectivity
import SwiftData
import os.log

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WatchConnectivityService()
    
    // MARK: - Published State
    
    /// Whether the Watch is currently reachable
    @Published private(set) var isWatchReachable = false
    
    /// Whether a Watch app is paired and installed
    @Published private(set) var isWatchAppInstalled = false
    
    /// Last time a snapshot was successfully sent
    @Published private(set) var lastSnapshotSent: Date?
    
    /// Last error (for debugging)
    @Published private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.finchandpoppy.flo", category: "WatchConnectivity")
    private var session: WCSession?
    
    /// Throttle snapshot pushes to avoid overwhelming WatchConnectivity
    private var lastSnapshotPushTime: Date = .distantPast
    private let minimumSnapshotInterval: TimeInterval = 2.0 // seconds
    
    /// Pending snapshot flag (set when push is throttled)
    private var hasPendingSnapshot = false
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Session Activation
    
    /// Call from FLOApp.swift on launch to activate WatchConnectivity session.
    /// Safe to call multiple times — only activates once.
    func activateSession() {
        guard WCSession.isSupported() else {
            logger.info("WatchConnectivity not supported on this device")
            return
        }
        
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        session = wcSession
        
        logger.info("✅ WatchConnectivity session activation requested")
    }
    
    // MARK: - Push Snapshot to Watch
    
    /// Builds a fresh WatchSnapshot from current SwiftData state and pushes to Watch.
    /// Call this after any data change that the Watch should reflect:
    /// - Transaction added/edited/deleted
    /// - Mileage trip state change
    /// - Subscription tier change
    /// - Budget update
    ///
    /// Throttled to avoid excessive updates (minimum 2 second interval).
    func pushSnapshotToWatch() {
        guard let session = session,
              session.activationState == .activated else {
            logger.debug("Session not activated, skipping snapshot push")
            return
        }
        
        guard session.isPaired && session.isWatchAppInstalled else {
            logger.debug("Watch not paired or app not installed, skipping snapshot push")
            return
        }
        
        // Throttle rapid pushes
        let now = Date()
        if now.timeIntervalSince(lastSnapshotPushTime) < minimumSnapshotInterval {
            hasPendingSnapshot = true
            // Schedule delayed push
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(minimumSnapshotInterval * 1_000_000_000))
                if self.hasPendingSnapshot {
                    self.hasPendingSnapshot = false
                    self.performSnapshotPush()
                }
            }
            return
        }
        
        performSnapshotPush()
    }
    
    /// Actually builds and sends the snapshot
    private func performSnapshotPush() {
        lastSnapshotPushTime = Date()
        
        Task { @MainActor in
            do {
                let snapshot = try await buildSnapshot()
                let data = try snapshot.encoded()
                
                // updateApplicationContext replaces previous context (only latest is kept)
                // This is ideal — the Watch always gets the most current state
                try session?.updateApplicationContext([
                    WatchMessageKey.snapshot: data
                ])
                
                lastSnapshotSent = Date()
                lastError = nil
                logger.info("✅ Snapshot pushed to Watch (\(data.count) bytes)")
                
            } catch {
                lastError = error.localizedDescription
                logger.error("❌ Failed to push snapshot: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Push Complication Update
    
    /// Push complication-specific data for Watch face updates.
    /// Uses transferCurrentComplicationUserInfo() which wakes the complication extension.
    /// Call sparingly — watchOS limits complication updates to ~50/day.
    func pushComplicationUpdate() {
        guard let session = session,
              session.activationState == .activated,
              session.isWatchAppInstalled else { return }
        
        #if os(iOS)
        guard session.isComplicationEnabled else {
            logger.debug("No active complication, skipping complication push")
            return
        }
        
        Task { @MainActor in
            do {
                let snapshot = try await buildSnapshot()
                let data = try JSONEncoder().encode(snapshot.complicationData)
                
                session.transferCurrentComplicationUserInfo([
                    WatchMessageKey.complicationUpdate: data
                ])
                
                logger.info("✅ Complication update pushed")
            } catch {
                logger.error("❌ Failed to push complication update: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    // MARK: - Build Snapshot
    
    /// Constructs a WatchSnapshot from current SwiftData state.
    /// Runs on MainActor since it accesses SwiftData context.
    private func buildSnapshot() async throws -> WatchSnapshot {
        let container = try ModelContainer.shared()
        let context = ModelContext(container)
        
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? startOfToday
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? startOfToday
        
        // MARK: Fetch today's transactions
        let todayPredicate = #Predicate<Transaction> {
            $0.date >= startOfToday && !$0.isTransfer
        }
        var todayDescriptor = FetchDescriptor<Transaction>(predicate: todayPredicate)
        todayDescriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        let todayTransactions = (try? context.fetch(todayDescriptor)) ?? []
        
        // MARK: Fetch this week's transactions
        let weekPredicate = #Predicate<Transaction> {
            $0.date >= startOfWeek && !$0.isTransfer
        }
        let weekDescriptor = FetchDescriptor<Transaction>(predicate: weekPredicate)
        let weekTransactions = (try? context.fetch(weekDescriptor)) ?? []
        
        // MARK: Fetch this month's transactions
        let monthPredicate = #Predicate<Transaction> {
            $0.date >= startOfMonth && !$0.isTransfer
        }
        let monthDescriptor = FetchDescriptor<Transaction>(predicate: monthPredicate)
        let monthTransactions = (try? context.fetch(monthDescriptor)) ?? []
        
        // MARK: Compute day summary
        let todaySpending = todayTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let todayIncome = todayTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        let weekSpending = weekTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let monthSpending = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let monthIncome = monthTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        
        let daySummary = WatchDaySummary(
            todaySpending: todaySpending,
            todayIncome: todayIncome,
            weekSpending: weekSpending,
            monthSpending: monthSpending,
            monthIncome: monthIncome,
            todayTransactionCount: todayTransactions.count
        )
        
        // MARK: Build recent transactions (last 10 across all days)
        let recentPredicate = #Predicate<Transaction> { !$0.isTransfer }
        var recentDescriptor = FetchDescriptor<Transaction>(predicate: recentPredicate)
        recentDescriptor.sortBy = [SortDescriptor(\.date, order: .reverse)]
        recentDescriptor.fetchLimit = 10
        let recentTxns = (try? context.fetch(recentDescriptor)) ?? []
        
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = Locale.current
        
        let watchTransactions: [WatchTransaction] = recentTxns.map { txn in
            let formatted = currencyFormatter.string(from: NSNumber(value: txn.amount)) ?? "$\(String(format: "%.2f", txn.amount))"
            return WatchTransaction(
                id: txn.id,
                amount: txn.amount,
                merchantName: txn.merchantName.isEmpty ? (txn.note) : txn.merchantName,
                categoryName: txn.category?.name ?? "Uncategorized",
                categoryIcon: txn.category?.icon ?? "dollarsign.circle",
                isIncome: txn.isIncome,
                isBusiness: txn.financeType == .business,
                date: txn.date,
                formattedAmount: (txn.isIncome ? "+" : "-") + formatted
            )
        }
        
        // MARK: Build quick categories (top 6 most used)
        let allCategories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        
        // Count usage in recent month
        let categoryUsage: [(Category, Int)] = allCategories.compactMap { cat in
            let count = monthTransactions.filter { $0.category?.id == cat.id }.count
            return (cat, count)
        }
        .sorted { $0.1 > $1.1 }
        .prefix(6)
        .map { ($0.0, $0.1) }
        
        let quickCategories: [WatchCategory] = categoryUsage.map { cat, count in
            WatchCategory(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                isBusiness: cat.isBusiness,
                usageCount: count
            )
        }
        
        // MARK: Tax estimate (Premium+ only)
        let currentTier = SubscriptionManager.shared.currentTier
        var taxEstimate: WatchTaxEstimate? = nil
        
        if currentTier.hasTaxEstimates {
            let taxService = TaxCalculationService.shared
            
            // Fetch all transactions for tax calculation
            let allTransactionsDescriptor = FetchDescriptor<Transaction>()
            let allTransactions = (try? context.fetch(allTransactionsDescriptor)) ?? []
            
            // Fetch tax settings
            let settingsDescriptor = FetchDescriptor<TaxSettings>()
            let settings = (try? context.fetch(settingsDescriptor))?.first
            
            if let settings = settings {
                let estimate = taxService.calculateYearToDateEstimate(transactions: allTransactions, settings: settings)
                
                let formattedPayment = currencyFormatter.string(from: NSNumber(value: estimate.adjustedQuarterlyPayment)) ?? "$\(String(format: "%.0f", estimate.adjustedQuarterlyPayment))"
                
                var daysUntil: Int? = nil
                if let deadline = estimate.nextDeadline {
                    daysUntil = calendar.dateComponents([.day], from: startOfToday, to: deadline).day
                }
                
                taxEstimate = WatchTaxEstimate(
                    quarterlyPayment: estimate.quarterlyPayment,
                    adjustedQuarterlyPayment: estimate.adjustedQuarterlyPayment,
                    nextDeadline: estimate.nextDeadline,
                    daysUntilDeadline: daysUntil,
                    ytdIncome: estimate.netIncome,
                    ytdDeductions: estimate.taxableIncome,
                    effectiveTaxRate: estimate.effectiveTotalRate,
                    formattedQuarterlyPayment: formattedPayment
                )
            }
        }
        
        // MARK: Mileage status
        var mileageStatus: WatchMileageStatus? = nil
        let mileageService = MileageTrackingService.shared
        
        if mileageService.isTracking {
            let tripElapsed = mileageService.currentTrip.map { Date().timeIntervalSince($0.startDate) } ?? 0
            mileageStatus = WatchMileageStatus(
                tripId: mileageService.currentTrip?.id ?? UUID(),
                distanceMiles: mileageService.currentDistanceMiles,
                elapsedSeconds: tripElapsed,
                estimatedDeduction: mileageService.currentDistanceMiles * 0.725,
                isPaused: mileageService.isPaused,
                gpsSignal: mileageService.gpsStatus.liveActivitySignal,
                startTime: mileageService.currentTrip?.startDate ?? Date(),
                startAddress: mileageService.currentTrip?.startAddress ?? "Unknown"
            )
        }
        
        // MARK: Complication data
        let taxDeadlineShort: String
        let taxPaymentFormatted: String
        let taxPaymentRaw: Double
        var daysUntilTax: Int? = nil
        
        if let tax = taxEstimate {
            taxPaymentFormatted = tax.formattedQuarterlyPayment
            taxPaymentRaw = tax.adjustedQuarterlyPayment
            daysUntilTax = tax.daysUntilDeadline
            
            if let days = tax.daysUntilDeadline {
                if days <= 0 {
                    taxDeadlineShort = "Due!"
                } else if days <= 7 {
                    taxDeadlineShort = "\(days)d!"
                } else {
                    taxDeadlineShort = "\(days)d"
                }
            } else {
                taxDeadlineShort = "—"
            }
        } else {
            taxDeadlineShort = "—"
            taxPaymentFormatted = "—"
            taxPaymentRaw = 0
        }
        
        // Spending trend (compare this month to last month)
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? startOfMonth
        let lastMonthPredicate = #Predicate<Transaction> {
            $0.date >= lastMonthStart && $0.date < startOfMonth && !$0.isTransfer && !$0.isIncome
        }
        let lastMonthDescriptor = FetchDescriptor<Transaction>(predicate: lastMonthPredicate)
        let lastMonthTxns = (try? context.fetch(lastMonthDescriptor)) ?? []
        let lastMonthSpending = lastMonthTxns.reduce(0) { $0 + $1.amount }
        
        let spendingTrend: String
        let spendingTrendPercent: Double
        if lastMonthSpending > 0 {
            let change = (monthSpending - lastMonthSpending) / lastMonthSpending
            spendingTrendPercent = change * 100
            if change > 0.05 {
                spendingTrend = "up"
            } else if change < -0.05 {
                spendingTrend = "down"
            } else {
                spendingTrend = "flat"
            }
        } else {
            spendingTrend = "flat"
            spendingTrendPercent = 0
        }
        
        let todaySpendingFormatted = currencyFormatter.string(from: NSNumber(value: todaySpending)) ?? "$\(String(format: "%.2f", todaySpending))"
        
        let tripMiles = mileageStatus?.distanceMiles ?? 0
        let tripMilesFormatted = tripMiles > 0 ? String(format: "%.1f mi", tripMiles) : "0 mi"
        
        // Today's total mileage
        let todayMileagePredicate = #Predicate<MileageTrip> {
            $0.startDate >= startOfToday
        }
        let todayMileageDescriptor = FetchDescriptor<MileageTrip>(predicate: todayMileagePredicate)
        let todayTrips = (try? context.fetch(todayMileageDescriptor)) ?? []
        let todayTotalMiles = todayTrips.reduce(0) { $0 + $1.distanceMiles }
        
        let complicationData = WatchComplicationData(
            todaySpendingFormatted: todaySpendingFormatted,
            todaySpendingRaw: todaySpending,
            taxDeadlineShort: taxDeadlineShort,
            taxPaymentFormatted: taxPaymentFormatted,
            taxPaymentRaw: taxPaymentRaw,
            daysUntilTaxDeadline: daysUntilTax,
            isMileageActive: mileageService.isTracking,
            currentTripMilesFormatted: tripMilesFormatted,
            todayTotalMiles: todayTotalMiles + tripMiles,
            spendingTrend: spendingTrend,
            spendingTrendPercent: spendingTrendPercent
        )
        
        return WatchSnapshot(
            generatedAt: now,
            subscriptionTierRaw: currentTier.rawValue,
            todaySummary: daySummary,
            recentTransactions: watchTransactions,
            taxEstimate: taxEstimate,
            activeMileageTrip: mileageStatus,
            quickCategories: quickCategories,
            complicationData: complicationData
        )
    }
    
    // MARK: - Handle Incoming Commands
    
    /// Process a WatchCommand received from the Watch.
    /// Creates transactions in SwiftData or controls mileage tracking.
    private func handleCommand(_ command: WatchCommand) async {
        logger.info("📱 Processing Watch command")
        
        do {
            switch command {
            case .addExpense(let payload):
                try await handleAddExpense(payload)
                
            case .addIncome(let payload):
                try await handleAddIncome(payload)
                
            case .startMileage:
                handleMileageStart()
                
            case .pauseMileage:
                handleMileagePause()
                
            case .resumeMileage:
                handleMileageResume()
                
            case .endMileage:
                handleMileageEnd()
                
            case .requestSnapshot:
                break // Just push snapshot after switch
            }
            
            // Always push updated snapshot after handling any command
            pushSnapshotToWatch()
            
        } catch {
            logger.error("❌ Failed to handle Watch command: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Expense/Income Handling
    
    private func handleAddExpense(_ payload: WatchCommand.AddExpensePayload) async throws {
        let container = try ModelContainer.shared()
        let context = ModelContext(container)
        
        // Find the category
        let categoryId = payload.categoryId
        let categoryPredicate = #Predicate<Category> { $0.id == categoryId }
        let categoryDescriptor = FetchDescriptor<Category>(predicate: categoryPredicate)
        let category = try? context.fetch(categoryDescriptor).first
        
        // Create transaction
        let transaction = Transaction(
            amount: payload.amount,
            date: payload.date,
            note: payload.note ?? "Added from Apple Watch",
            isIncome: false,
            merchantName: "",
            category: category,
            financeType: payload.isBusiness ? .business : .personal
        )
        
        context.insert(transaction)
        try context.save()
        
        logger.info("✅ Watch expense saved: $\(String(format: "%.2f", payload.amount))")
    }
    
    private func handleAddIncome(_ payload: WatchCommand.AddIncomePayload) async throws {
        let container = try ModelContainer.shared()
        let context = ModelContext(container)
        
        let categoryId = payload.categoryId
        let categoryPredicate = #Predicate<Category> { $0.id == categoryId }
        let categoryDescriptor = FetchDescriptor<Category>(predicate: categoryPredicate)
        let category = try? context.fetch(categoryDescriptor).first
        
        let transaction = Transaction(
            amount: payload.amount,
            date: payload.date,
            note: payload.note ?? "Added from Apple Watch",
            isIncome: true,
            merchantName: "",
            category: category,
            financeType: payload.isBusiness ? .business : .personal
        )
        
        context.insert(transaction)
        try context.save()
        
        logger.info("✅ Watch income saved: $\(String(format: "%.2f", payload.amount))")
    }
    
    // MARK: - Mileage Control
    
    private func handleMileageStart() {
        let mileageService = MileageTrackingService.shared
        guard !mileageService.isTracking else {
            logger.info("Mileage already tracking, ignoring start command")
            return
        }
        mileageService.startTracking()
        logger.info("✅ Mileage tracking started from Watch")
    }
    
    private func handleMileagePause() {
        let mileageService = MileageTrackingService.shared
        guard mileageService.isTracking, !mileageService.isPaused else { return }
        mileageService.pauseTracking()
        logger.info("✅ Mileage tracking paused from Watch")
    }
    
    private func handleMileageResume() {
        let mileageService = MileageTrackingService.shared
        guard mileageService.isTracking, mileageService.isPaused else { return }
        mileageService.resumeTracking()
        logger.info("✅ Mileage tracking resumed from Watch")
    }
    
    private func handleMileageEnd() {
        let mileageService = MileageTrackingService.shared
        guard mileageService.isTracking else { return }
        mileageService.stopTracking()
        logger.info("✅ Mileage tracking ended from Watch")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    
    /// Called when session activation completes
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.logger.error("❌ WCSession activation failed: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                return
            }
            
            self.logger.info("✅ WCSession activated: \(String(describing: activationState.rawValue))")
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
            
            // Push initial snapshot after activation
            if session.isWatchAppInstalled {
                self.pushSnapshotToWatch()
            }
        }
    }
    
    /// Required on iOS — called during Watch app switching
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor in
            self.logger.info("WCSession became inactive")
        }
    }
    
    /// Required on iOS — called after session deactivation
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for potential new Watch pairing
        Task { @MainActor in
            self.logger.info("WCSession deactivated, reactivating...")
            session.activate()
        }
    }
    
    /// Watch reachability changed
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchReachable = session.isReachable
            self.logger.info("Watch reachability: \(session.isReachable)")
            
            // Push fresh snapshot when Watch becomes reachable
            if session.isReachable {
                self.pushSnapshotToWatch()
            }
        }
    }
    
    /// Watch app install state changed
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.logger.info("Watch app installed: \(session.isWatchAppInstalled)")
        }
    }
    
    /// Receive immediate message from Watch (Watch is reachable)
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let data = message[WatchMessageKey.command] as? Data else {
            replyHandler([WatchMessageKey.commandAck: false, WatchMessageKey.errorMessage: "Invalid command data"])
            return
        }
        
        Task { @MainActor in
            do {
                let command = try WatchCommand.decoded(from: data)
                await self.handleCommand(command)
                replyHandler([WatchMessageKey.commandAck: true])
            } catch {
                self.logger.error("❌ Failed to decode Watch command: \(error.localizedDescription)")
                replyHandler([WatchMessageKey.commandAck: false, WatchMessageKey.errorMessage: error.localizedDescription])
            }
        }
    }
    
    /// Receive queued user info from Watch (offline commands)
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let data = userInfo[WatchMessageKey.command] as? Data else { return }
        
        Task { @MainActor in
            do {
                let command = try WatchCommand.decoded(from: data)
                await self.handleCommand(command)
            } catch {
                self.logger.error("❌ Failed to decode queued Watch command: \(error.localizedDescription)")
            }
        }
    }
}
#endif // os(iOS)
