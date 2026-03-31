//  CloudSyncService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - SwiftData Automatic CloudKit Sync (Build 8)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.0 - iCloud Sync Enabled:
//  ✅ Adapted to monitoring role — SwiftData handles all CloudKit sync automatically
//  ✅ Added NSPersistentCloudKitContainer.eventChangedNotification listener
//  ✅ Tracks import/export/setup events and updates sync status in real-time
//  ✅ initialize() made internal for FLOApp to call at launch
//  ✅ performSync() simplified — "Sync Now" refreshes status since sync is automatic
//  ✅ Added initial sync migration flag tracking (cloudSync.initialSyncComplete)
//
//  CHANGES v1.3 - VoiceOver Audit:
//  ✅ ADDED: CloudSyncStatusView icon hidden, combines with spoken label "iCloud sync: up to date"
//  ✅ ADDED: CloudSyncDetailsView status icon hidden, status row combines
//  ✅ ADDED: "Sync Now" button has explicit hint describing action
//  ✅ ADDED: "Reset Sync State" button has explicit hint warning about full re-sync
//  ✅ ADDED: Account/Network status rows combine into single spoken elements
//  ✅ VERIFIED: All buttons have clear labels from visible text
//
//  PURPOSE:
//  Monitors iCloud synchronization status for FLO data.
//  SwiftData handles all CloudKit mirroring automatically via cloudKitDatabase: .automatic.
//  This service provides:
//  - Sync event monitoring (import/export/setup tracking)
//  - Account status and network connectivity awareness
//  - User-facing sync status and error reporting
//  - Manual status refresh and sync reset
//
//  CHANGES v1.2:
//  - Removed unnecessary await from loadState() calls
//  - Fixed .task { } blocks to not use await for sync functions
//
//  CHANGES v1.1:
//  - Added import SwiftUI
//  - Removed Sendable from SyncChange (contains [String: Any])
//  - Fixed MainActor isolation patterns
//  - Fixed Preview macros

import Foundation
import CloudKit
import SwiftData
import SwiftUI
import Combine
import Network

// MARK: - Cloud Sync Service

@MainActor
final class CloudSyncService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CloudSyncService()
    private init() {
        setupNetworkMonitor()
        setupAccountStatusMonitor()
    }
    
    // MARK: - Published State
    
    /// Current sync status
    @Published private(set) var syncStatus: SyncStatus = .idle
    
    /// Whether sync is enabled by user
    @Published var isSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(isSyncEnabled, forKey: "cloudSync.enabled")
            if isSyncEnabled {
                scheduleBackgroundSync()
            }
        }
    }
    
    /// Last successful sync date
    @Published private(set) var lastSyncDate: Date?
    
    /// Current sync progress (0.0 - 1.0)
    @Published private(set) var syncProgress: Double = 0.0
    
    /// Current error (if any)
    @Published private(set) var currentError: CloudSyncError?
    
    /// Network availability
    @Published private(set) var isNetworkAvailable = true
    
    /// iCloud account status
    @Published private(set) var accountStatus: CKAccountStatus = .couldNotDetermine
    
    /// Pending changes count
    @Published private(set) var pendingChangesCount: Int = 0
    
    // MARK: - Configuration
    
    /// CloudKit container identifier
    private let containerIdentifier = "iCloud.com.finchandpoppy.flo"
    
    /// Minimum interval between syncs (seconds)
    private let minimumSyncInterval: TimeInterval = 60
    
    /// Background sync interval (seconds)
    private let backgroundSyncInterval: TimeInterval = 900 // 15 minutes
    
    // MARK: - Private Properties
    
    private var container: CKContainer?
    private var database: CKDatabase?
    private var networkMonitor: NWPathMonitor?
    private var accountStatusTask: Task<Void, Never>?
    private var syncTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    private var lastSyncAttempt: Date?
    
    /// Conflict resolver for handling sync conflicts
    private var conflictResolver: ConflictResolver {
        ConflictResolver.shared
    }
    
    // MARK: - Initialization

    /// Call from FLOApp.scheduleDeferredSetup() to start monitoring.
    /// Loads saved preferences, initializes CloudKit container,
    /// sets up sync event monitoring, and checks account status.
    func initialize() {
        // Load saved preferences
        isSyncEnabled = UserDefaults.standard.bool(forKey: "cloudSync.enabled")

        if let lastSync = UserDefaults.standard.object(forKey: "cloudSync.lastSync") as? Date {
            lastSyncDate = lastSync
        }

        // Initialize CloudKit container
        container = CKContainer(identifier: containerIdentifier)
        database = container?.privateCloudDatabase

        // Listen for SwiftData/CloudKit sync events
        setupCloudKitEventMonitor()

        // Track initial sync migration
        trackInitialSyncMigration()

        // Check initial status
        Task {
            await checkAccountStatus()
        }

        #if DEBUG
        print("☁️ CloudSyncService initialized — monitoring CloudKit events")
        #endif
    }

    // MARK: - CloudKit Event Monitoring

    /// Listens for NSPersistentCloudKitContainer sync events to track
    /// import/export/setup progress and update published state.
    private func setupCloudKitEventMonitor() {
        NotificationCenter.default.publisher(
            for: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification")
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.handleCloudKitEvent(notification)
        }
        .store(in: &cancellables)
    }

    /// Handles incoming CloudKit sync event notifications.
    private func handleCloudKitEvent(_ notification: Notification) {
        // NSPersistentCloudKitContainer.Event is not directly accessible,
        // but the notification userInfo contains event details
        guard let userInfo = notification.userInfo else { return }

        // Check if the event succeeded or failed
        if let error = userInfo["error"] as? Error {
            currentError = .cloudKitError(error)
            syncStatus = .error(error.localizedDescription)
            #if DEBUG
            print("☁️ CloudKit sync event error: \(error.localizedDescription)")
            #endif
            return
        }

        // Check event type from userInfo
        if let eventTypeRaw = userInfo["type"] as? Int {
            switch eventTypeRaw {
            case 0: // setup
                syncStatus = .syncing
                syncProgress = 0.2
                #if DEBUG
                print("☁️ CloudKit sync: setup phase")
                #endif
            case 1: // import
                syncStatus = .syncing
                syncProgress = 0.6
                #if DEBUG
                print("☁️ CloudKit sync: importing remote changes")
                #endif
            case 2: // export
                syncStatus = .syncing
                syncProgress = 0.9
                #if DEBUG
                print("☁️ CloudKit sync: exporting local changes")
                #endif
            default:
                break
            }
        }

        // Check if event ended successfully
        if let endDate = userInfo["endDate"] as? Date {
            lastSyncDate = endDate
            UserDefaults.standard.set(endDate, forKey: "cloudSync.lastSync")
            syncStatus = .idle
            syncProgress = 1.0
            currentError = nil

            // Mark initial sync as complete
            if !UserDefaults.standard.bool(forKey: "cloudSync.initialSyncComplete") {
                UserDefaults.standard.set(true, forKey: "cloudSync.initialSyncComplete")
                #if DEBUG
                print("☁️ Initial CloudKit sync completed successfully")
                #endif
            }
        }
    }

    /// Tracks first-time sync migration for existing local data
    private func trackInitialSyncMigration() {
        if !UserDefaults.standard.bool(forKey: "cloudSync.initialSyncComplete") {
            #if DEBUG
            print("☁️ First launch with CloudKit — existing data will auto-export to iCloud")
            #endif
        }
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitor() {
        networkMonitor = NWPathMonitor()
        
        networkMonitor?.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isNetworkAvailable = path.status == .satisfied
                
                // Auto-sync when network becomes available
                if path.status == .satisfied {
                    self?.syncIfNeeded()
                }
            }
        }
        
        let queue = DispatchQueue(label: "com.finchandpoppy.flo.networkMonitor")
        networkMonitor?.start(queue: queue)
    }
    
    // MARK: - Account Status
    
    private func setupAccountStatusMonitor() {
        // Listen for account changes
        NotificationCenter.default.publisher(for: .CKAccountChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAccountStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAccountStatus() async {
        guard let container = container else {
            accountStatus = .couldNotDetermine
            return
        }
        
        do {
            let status = try await container.accountStatus()
            accountStatus = status
            
            // Update sync status based on account
            if status != .available {
                syncStatus = .disabled(reason: accountStatusReason(status))
            }
        } catch {
            accountStatus = .couldNotDetermine
            currentError = .accountStatusCheckFailed(error)
        }
    }
    
    private func accountStatusReason(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Ready"
        case .noAccount:
            return "Sign in to iCloud in Settings"
        case .restricted:
            return "iCloud access is restricted"
        case .couldNotDetermine:
            return "Unable to check iCloud status"
        case .temporarilyUnavailable:
            return "iCloud temporarily unavailable"
        @unknown default:
            return "Unknown status"
        }
    }
    
    // MARK: - Sync Operations
    
    /// Checks if sync is needed and triggers if appropriate
    func syncIfNeeded() {
        guard isSyncEnabled else { return }
        guard accountStatus == .available else { return }
        guard isNetworkAvailable else { return }
        guard syncStatus != .syncing else { return }
        
        // Check minimum interval
        if let lastAttempt = lastSyncAttempt {
            let elapsed = Date().timeIntervalSince(lastAttempt)
            if elapsed < minimumSyncInterval {
                return
            }
        }
        
        Task {
            await performSync()
        }
    }
    
    /// Manually trigger a sync
    func sync() async throws {
        guard accountStatus == .available else {
            throw CloudSyncError.accountNotAvailable(accountStatusReason(accountStatus))
        }
        
        guard isNetworkAvailable else {
            throw CloudSyncError.networkUnavailable
        }
        
        await performSync()
        
        if let error = currentError {
            throw error
        }
    }
    
    /// Refreshes sync status.
    /// With SwiftData automatic CloudKit sync, data syncs continuously.
    /// "Sync Now" refreshes account status and checks connectivity.
    private func performSync() async {
        guard syncTask == nil else { return }

        syncStatus = .syncing
        syncProgress = 0.0
        currentError = nil
        lastSyncAttempt = Date()

        syncTask = Task {
            defer {
                syncTask = nil
            }

            // Refresh account status
            syncProgress = 0.3
            await checkAccountStatus()

            // Verify connectivity
            syncProgress = 0.6
            guard isNetworkAvailable else {
                currentError = .networkUnavailable
                syncStatus = .error("No internet connection")
                return
            }

            guard accountStatus == .available else {
                syncStatus = .disabled(reason: accountStatusReason(accountStatus))
                return
            }

            // SwiftData handles actual sync automatically via NSPersistentCloudKitContainer
            // We just update the status to reflect readiness
            syncProgress = 1.0

            if let lastSync = lastSyncDate {
                syncStatus = .idle
                #if DEBUG
                print("☁️ Sync status refreshed — last sync: \(lastSync)")
                #endif
            } else {
                syncStatus = .idle
                #if DEBUG
                print("☁️ Sync status refreshed — awaiting first automatic sync")
                #endif
            }
        }

        // Wait for completion
        try? await syncTask?.value
    }
    
    // MARK: - Error Handling
    
    private func handleCloudKitError(_ error: CKError) {
        switch error.code {
        case .networkUnavailable, .networkFailure:
            currentError = .networkUnavailable
            syncStatus = .error("Network unavailable")
            
        case .notAuthenticated:
            currentError = .accountNotAvailable("Please sign in to iCloud")
            syncStatus = .disabled(reason: "Sign in to iCloud")
            
        case .quotaExceeded:
            currentError = .quotaExceeded
            syncStatus = .error("iCloud storage full")
            
        case .serverRecordChanged:
            currentError = .conflictDetected
            syncStatus = .error("Sync conflict detected")
            
        case .zoneNotFound, .userDeletedZone:
            Task {
                try? await recreateZone()
            }
            
        case .serviceUnavailable, .requestRateLimited:
            currentError = .serverUnavailable
            syncStatus = .error("iCloud temporarily unavailable")
            scheduleRetry(delay: 60)
            
        case .partialFailure:
            if let partialErrors = error.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecord.ID: Error] {
                for (recordID, partialError) in partialErrors {
                    print("⚠️ Partial sync failure for \(recordID): \(partialError)")
                }
            }
            currentError = .partialFailure(error.localizedDescription)
            syncStatus = .error("Some items failed to sync")
            
        default:
            currentError = .cloudKitError(error)
            syncStatus = .error(error.localizedDescription)
        }
    }
    
    /// Recreates the CloudKit zone if deleted
    private func recreateZone() async throws {
        guard let database = database else { return }
        
        let zone = CKRecordZone(zoneName: "FLO_Zone")
        _ = try await database.save(zone)
        
        // Reset sync token
        UserDefaults.standard.removeObject(forKey: "cloudSync.lastToken")
        
        // Trigger full sync
        await performSync()
    }
    
    /// Schedules a sync retry
    private func scheduleRetry(delay: TimeInterval) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            syncIfNeeded()
        }
    }
    
    // MARK: - Background Sync
    
    /// Schedules background sync
    func scheduleBackgroundSync() {
        guard isSyncEnabled else { return }
        
        Task {
            try? await Task.sleep(nanoseconds: UInt64(backgroundSyncInterval * 1_000_000_000))
            syncIfNeeded()
            scheduleBackgroundSync()
        }
    }
    
    // MARK: - Public Utilities
    
    /// Returns a user-friendly description of the current sync state
    var statusDescription: String {
        switch syncStatus {
        case .idle:
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            }
            return "Not synced"
            
        case .syncing:
            return "Syncing..."
            
        case .error(let message):
            return message
            
        case .disabled(let reason):
            return reason
        }
    }
    
    /// Whether sync can be performed right now
    var canSync: Bool {
        guard isSyncEnabled else { return false }
        guard accountStatus == .available else { return false }
        guard isNetworkAvailable else { return false }
        guard case .syncing = syncStatus else { return true }
        return false
    }
    
    /// Resets all sync state (for troubleshooting)
    func resetSyncState() {
        UserDefaults.standard.removeObject(forKey: "cloudSync.lastSync")
        UserDefaults.standard.removeObject(forKey: "cloudSync.lastToken")
        UserDefaults.standard.removeObject(forKey: "cloudSync.serverToken")
        
        lastSyncDate = nil
        syncStatus = .idle
        currentError = nil
        pendingChangesCount = 0
    }
}

// MARK: - Sync Status

/// Represents the current sync status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
    case disabled(reason: String)
    
    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
    
    var icon: String {
        switch self {
        case .idle: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .error: return "exclamationmark.icloud"
        case .disabled: return "icloud.slash"
        }
    }
    
    var color: String {
        switch self {
        case .idle: return "#10B981"     // Green
        case .syncing: return "#3B82F6"  // Blue
        case .error: return "#EF4444"    // Red
        case .disabled: return "#6B7280" // Gray
        }
    }
}

// MARK: - Sync Change

/// Represents a change to be synced
/// Note: Not Sendable because data contains [String: Any]
struct SyncChange: Identifiable {
    let id: String
    let type: ChangeType
    let entityType: String
    let entityId: UUID
    let modifiedAt: Date
    let data: [String: Any]?
    
    enum ChangeType {
        case added
        case modified
        case deleted
    }
    
    init(
        id: String = UUID().uuidString,
        type: ChangeType,
        entityType: String,
        entityId: UUID,
        modifiedAt: Date = Date(),
        data: [String: Any]? = nil
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.entityId = entityId
        self.modifiedAt = modifiedAt
        self.data = data
    }
}

// MARK: - Cloud Sync Error

/// Errors that can occur during cloud sync
enum CloudSyncError: LocalizedError {
    case notConfigured
    case accountNotAvailable(String)
    case networkUnavailable
    case quotaExceeded
    case conflictDetected
    case serverUnavailable
    case partialFailure(String)
    case cloudKitError(Error)
    case accountStatusCheckFailed(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "iCloud sync is not configured"
        case .accountNotAvailable(let reason):
            return reason
        case .networkUnavailable:
            return "No internet connection"
        case .quotaExceeded:
            return "iCloud storage is full"
        case .conflictDetected:
            return "Sync conflict detected"
        case .serverUnavailable:
            return "iCloud is temporarily unavailable"
        case .partialFailure(let message):
            return "Some items failed to sync: \(message)"
        case .cloudKitError(let error):
            return error.localizedDescription
        case .accountStatusCheckFailed(let error):
            return "Failed to check iCloud status: \(error.localizedDescription)"
        case .unknownError(let error):
            return error.localizedDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notConfigured:
            return "Enable iCloud sync in Settings"
        case .accountNotAvailable:
            return "Sign in to iCloud in device Settings"
        case .networkUnavailable:
            return "Check your internet connection"
        case .quotaExceeded:
            return "Free up iCloud storage or upgrade your plan"
        case .conflictDetected:
            return "Review and resolve conflicts in Settings"
        case .serverUnavailable:
            return "Try again in a few minutes"
        default:
            return nil
        }
    }
}

// MARK: - Sync Status View

/// SwiftUI view for displaying sync status
struct CloudSyncStatusView: View {
    
    @State private var syncStatus: SyncStatus = .idle
    @State private var lastSyncDate: Date?
    @State private var canSync = false
    
    var body: some View {
        Button {
            if canSync {
                Task { @MainActor in
                    try? await CloudSyncService.shared.sync()
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: syncStatus.icon)
                    .symbolEffect(.pulse, isActive: syncStatus.isActive)
                    .foregroundStyle(Color(hex: syncStatus.color))
                    .accessibilityHidden(true)
                
                if syncStatus.isActive {
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let lastSync = lastSyncDate {
                    Text(lastSync, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStatusLabel)
        .accessibilityHint(canSync ? "Double tap to sync now" : "")
        .task {
            loadState()
        }
    }
    
    private var accessibilityStatusLabel: String {
        switch syncStatus {
        case .idle:
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let timeAgo = formatter.localizedString(for: lastSync, relativeTo: Date())
                return "iCloud sync: up to date, last synced \(timeAgo)"
            }
            return "iCloud sync: not synced yet"
            
        case .syncing:
            return "iCloud sync: syncing now"
            
        case .error(let message):
            return "iCloud sync: error, \(message)"
            
        case .disabled(let reason):
            return "iCloud sync: disabled, \(reason)"
        }
    }
    
    @MainActor
    private func loadState() {
        syncStatus = CloudSyncService.shared.syncStatus
        lastSyncDate = CloudSyncService.shared.lastSyncDate
        canSync = CloudSyncService.shared.canSync
    }
}

// MARK: - Sync Details View

/// Detailed view for sync settings and status
struct CloudSyncDetailsView: View {
    
    @State private var isSyncEnabled = false
    @State private var syncStatus: SyncStatus = .idle
    @State private var syncProgress: Double = 0.0
    @State private var accountStatus: CKAccountStatus = .couldNotDetermine
    @State private var isNetworkAvailable = true
    @State private var currentError: CloudSyncError?
    @State private var canSync = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Status Section
                Section {
                    HStack {
                        Image(systemName: syncStatus.icon)
                            .font(.title2)
                            .foregroundStyle(Color(hex: syncStatus.color))
                            .frame(width: 40)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusDescription)
                                .font(.body)
                            
                            if syncStatus.isActive {
                                ProgressView(value: syncProgress)
                                    .tint(Color.brandPrimary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("iCloud sync status: \(statusDescription)")
                } header: {
                    Text("Status")
                }
                
                // Settings Section
                Section {
                    Toggle("iCloud Sync", isOn: $isSyncEnabled)
                        .onChange(of: isSyncEnabled) { _, newValue in
                            Task { @MainActor in
                                CloudSyncService.shared.isSyncEnabled = newValue
                            }
                        }
                    
                    if isSyncEnabled {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(accountStatusText)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("iCloud Account: \(accountStatusText)")
                        
                        HStack {
                            Text("Network")
                            Spacer()
                            Text(isNetworkAvailable ? "Available" : "Unavailable")
                                .foregroundStyle(isNetworkAvailable ? .green : Color.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Network: \(isNetworkAvailable ? "Available" : "Unavailable")")
                    }
                } header: {
                    Text("Settings")
                } footer: {
                    Text("When enabled, your data syncs automatically across all your devices signed into the same iCloud account.")
                }
                
                // Actions Section
                if isSyncEnabled {
                    Section {
                        Button {
                            Task { @MainActor in
                                try? await CloudSyncService.shared.sync()
                                loadState()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .accessibilityHidden(true)
                                Text("Sync Now")
                            }
                        }
                        .disabled(!canSync)
                        .accessibilityHint(canSync ? "Immediately syncs your data with iCloud" : "Sync is not available right now")
                        
                        Button(role: .destructive) {
                            Task { @MainActor in
                                CloudSyncService.shared.resetSyncState()
                                loadState()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .accessibilityHidden(true)
                                Text("Reset Sync State")
                            }
                        }
                        .accessibilityHint("Clears sync history and triggers a full re-sync of all data")
                    } header: {
                        Text("Actions")
                    } footer: {
                        Text("Resetting sync state will cause a full re-sync of your data.")
                    }
                }
                
                // Error Section
                if let error = currentError {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(error.localizedDescription)
                                .foregroundStyle(Color.red)
                            
                            if let recovery = error.recoverySuggestion {
                                Text(recovery)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    } header: {
                        Text("Error")
                    }
                }
            }
            .navigationTitle("iCloud Sync")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                loadState()
            }
        }
    }
    
    private var statusDescription: String {
        switch syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .error(let message):
            return message
        case .disabled(let reason):
            return reason
        }
    }
    
    private var accountStatusText: String {
        switch accountStatus {
        case .available:
            return "Signed In"
        case .noAccount:
            return "Not Signed In"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Unknown"
        case .temporarilyUnavailable:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
    
    @MainActor
    private func loadState() {
        let service = CloudSyncService.shared
        isSyncEnabled = service.isSyncEnabled
        syncStatus = service.syncStatus
        syncProgress = service.syncProgress
        accountStatus = service.accountStatus
        isNetworkAvailable = service.isNetworkAvailable
        currentError = service.currentError
        canSync = service.canSync
    }
}

// MARK: - Preview Support

#if DEBUG
struct CloudSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncStatusView()
            .padding()
    }
}

struct CloudSyncDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncDetailsView()
    }
}
#endif
