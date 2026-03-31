//  WatchSessionManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Fixed actor isolation warnings, var→let for unmutated binding
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target ONLY)
//
//  ARCHITECTURE:
//  Watch-side counterpart to WatchConnectivityService (iPhone side).
//  - Receives WatchSnapshot via applicationContext updates
//  - Sends WatchCommand via sendMessage() (immediate) or transferUserInfo() (queued)
//  - Publishes snapshot data for SwiftUI views via @Published properties
//
//  OFFLINE BEHAVIOR:
//  When iPhone is unreachable, commands are queued via transferUserInfo().
//  WatchConnectivity delivers them when connectivity resumes.
//  The Watch UI shows stale snapshot data with a "Last updated" indicator.
//

import Foundation
import Combine
import WatchConnectivity
import os.log

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WatchSessionManager()
    
    // MARK: - Published State
    
    /// Current snapshot from iPhone (nil until first snapshot received)
    @Published private(set) var snapshot: WatchSnapshot?
    
    /// Whether the iPhone is currently reachable for immediate commands
    @Published private(set) var isPhoneReachable = false
    
    /// Whether a command is currently being sent
    @Published private(set) var isSendingCommand = false
    
    /// Last error message (for debugging/UI feedback)
    @Published private(set) var lastError: String?
    
    /// Whether initial data has been loaded
    var hasData: Bool { snapshot != nil }
    
    // MARK: - Convenience Accessors
    
    /// Current subscription tier from snapshot
    var currentTier: WatchSubscriptionTier {
        snapshot?.subscriptionTier ?? .free
    }
    
    /// Whether mileage is actively tracking
    var isMileageActive: Bool {
        snapshot?.activeMileageTrip != nil
    }
    
    /// Whether mileage is paused
    var isMileagePaused: Bool {
        snapshot?.activeMileageTrip?.isPaused ?? false
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.finchandpoppy.flo.watch", category: "SessionManager")
    private var session: WCSession?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Session Activation
    
    /// Call from FLOWatchApp.swift on launch
    func activateSession() {
        guard WCSession.isSupported() else {
            logger.warning("WatchConnectivity not supported")
            return
        }
        
        let wcSession = WCSession.default
        wcSession.delegate = self
        wcSession.activate()
        session = wcSession
        
        logger.info("✅ Watch WCSession activation requested")
    }
    
    // MARK: - Send Commands to iPhone
    
    /// Send a command to the iPhone.
    /// Uses sendMessage() if reachable (immediate), falls back to transferUserInfo() (queued).
    /// Returns true if command was sent or queued successfully.
    @discardableResult
    func sendCommand(_ command: WatchCommand) async -> Bool {
        guard let session = session,
              session.activationState == .activated else {
            logger.error("Session not activated, cannot send command")
            lastError = "Not connected"
            return false
        }
        
        isSendingCommand = true
        defer { isSendingCommand = false }
        
        do {
            let data = try command.encoded()
            let message = [WatchMessageKey.command: data]
            
            if session.isReachable {
                // Immediate delivery with reply
                return await withCheckedContinuation { continuation in
                    session.sendMessage(message, replyHandler: { reply in
                        let success = reply[WatchMessageKey.commandAck] as? Bool ?? false
                        if !success {
                            let error = reply[WatchMessageKey.errorMessage] as? String ?? "Unknown error"
                            Task { @MainActor in
                                self.lastError = error
                                self.logger.error("❌ Command rejected: \(error)")
                            }
                        } else {
                            Task { @MainActor in
                                self.lastError = nil
                                self.logger.info("✅ Command acknowledged by iPhone")
                            }
                        }
                        continuation.resume(returning: success)
                    }, errorHandler: { error in
                        Task { @MainActor in
                            self.lastError = error.localizedDescription
                            self.logger.error("❌ sendMessage failed: \(error.localizedDescription)")
                            
                            // Fall back to queued delivery
                            session.transferUserInfo(message)
                            self.logger.info("📨 Command queued via transferUserInfo")
                        }
                        continuation.resume(returning: true) // Queued counts as success
                    })
                }
            } else {
                // iPhone not reachable — queue for later delivery
                session.transferUserInfo(message)
                logger.info("📨 Command queued (iPhone not reachable)")
                lastError = nil
                return true
            }
            
        } catch {
            logger.error("❌ Failed to encode command: \(error.localizedDescription)")
            lastError = "Encoding error"
            return false
        }
    }
    
    // MARK: - Request Fresh Snapshot
    
    /// Ask the iPhone to push a fresh snapshot.
    /// Useful for pull-to-refresh or when Watch app becomes active.
    func requestSnapshot() async {
        await sendCommand(.requestSnapshot)
    }
    
    // MARK: - Snapshot Processing
    
    /// Decode and apply a snapshot from received WatchConnectivity data
    private func processSnapshotData(_ data: Data) {
        do {
            let newSnapshot = try WatchSnapshot.decoded(from: data)
            self.snapshot = newSnapshot
            self.lastError = nil
            logger.info("✅ Snapshot received (\(data.count) bytes, \(newSnapshot.recentTransactions.count) transactions)")
        } catch {
            logger.error("❌ Failed to decode snapshot: \(error.localizedDescription)")
            lastError = "Sync error"
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    
    /// Session activation completed
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.logger.error("❌ Watch WCSession activation failed: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                return
            }
            
            self.logger.info("✅ Watch WCSession activated")
            self.isPhoneReachable = session.isReachable
            
            // Check for existing application context (snapshot from before launch)
            if let data = session.receivedApplicationContext[WatchMessageKey.snapshot] as? Data {
                self.processSnapshotData(data)
            }
        }
    }
    
    /// iPhone reachability changed
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            self.logger.info("iPhone reachability: \(session.isReachable)")
            
            // Request fresh data when phone becomes reachable
            if session.isReachable {
                await self.requestSnapshot()
            }
        }
    }
    
    /// Received updated application context (new snapshot from iPhone)
    /// This is the primary data delivery mechanism.
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            guard let data = applicationContext[WatchMessageKey.snapshot] as? Data else { return }
            self.processSnapshotData(data)
        }
    }
    
    /// Received immediate message from iPhone (rare — iPhone usually uses applicationContext)
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let data = message[WatchMessageKey.snapshot] as? Data {
                self.processSnapshotData(data)
            }
        }
    }
    
    /// Received queued user info from iPhone
    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        Task { @MainActor in
            if let data = userInfo[WatchMessageKey.complicationUpdate] as? Data {
                // Complication-specific update
                do {
                    let complicationData = try JSONDecoder().decode(WatchComplicationData.self, from: data)
                    // Update just the complication portion of the snapshot
                    if let current = self.snapshot {
                        // Create updated snapshot with new complication data
                        let updated = WatchSnapshot(
                            generatedAt: current.generatedAt,
                            subscriptionTierRaw: current.subscriptionTierRaw,
                            todaySummary: current.todaySummary,
                            recentTransactions: current.recentTransactions,
                            taxEstimate: current.taxEstimate,
                            activeMileageTrip: current.activeMileageTrip,
                            quickCategories: current.quickCategories,
                            complicationData: complicationData
                        )
                        self.snapshot = updated
                    }
                    self.logger.info("✅ Complication data updated")
                } catch {
                    self.logger.error("❌ Failed to decode complication data: \(error.localizedDescription)")
                }
            }
        }
    }
}
