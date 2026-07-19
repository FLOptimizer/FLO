//  ConflictResolver.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - VoiceOver Audit: Conflict resolution accessibility
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.5 - VoiceOver Audit:
//  ✅ ADDED: ConflictResolutionView overall label describes conflict type and versions
//  ✅ ADDED: ComparisonCard combines icon + text with spoken label "This Device, modified 2 hours ago"
//  ✅ ADDED: Decorative icons hidden (branch icon, device icons, checkmark indicators)
//  ✅ ADDED: "Keep This Device's Version" button has explicit hint
//  ✅ ADDED: "Keep iCloud Version" button has explicit hint
//  ✅ ADDED: PendingConflictsBanner combines children with spoken count
//  ✅ ADDED: ConflictSettingsView strategy rows combine with selection state
//  ✅ VERIFIED: All action buttons have clear labels from visible text
//
//  PURPOSE:
//  Handles merge conflicts during iCloud synchronization by:
//  - Detecting conflicting changes between local and remote
//  - Applying resolution strategies (last-write-wins, field-level merge)
//  - Preserving user intent where possible
//  - Maintaining data integrity
//
//  CHANGES v1.4:
//  - Fixed #Predicate macro by extracting entityId to local variable
//    (Predicates can't capture object properties directly)
//
//  CHANGES v1.3:
//  - Removed unnecessary await from loadState() and loadConflicts() calls
//
//  CHANGES v1.2:
//  - Removed Sendable from types containing SyncChange

import Foundation
import SwiftData
import SwiftUI

// MARK: - Conflict Resolver

@MainActor
final class ConflictResolver: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ConflictResolver()
    private init() {}
    
    // MARK: - Published State
    
    /// Conflicts requiring user attention
    @Published private(set) var pendingConflicts: [SyncConflict] = []
    
    /// Number of conflicts auto-resolved in last sync
    @Published private(set) var lastAutoResolvedCount: Int = 0
    
    /// Conflict resolution strategy preference
    @Published var preferredStrategy: ConflictStrategy = .lastWriteWins {
        didSet {
            UserDefaults.standard.set(preferredStrategy.rawValue, forKey: "conflictResolver.strategy")
        }
    }
    
    // MARK: - Configuration
    
    /// Entity types that require user confirmation for conflicts
    private let requiresUserConfirmation: Set<String> = [
        "Invoice",      // Financial documents - user should review
        "TaxSettings"   // Important settings - don't auto-merge
    ]
    
    /// Fields that should never be auto-resolved
    private let protectedFields: Set<String> = [
        "amount",       // Money values are critical
        "invoiceNumber" // Must be unique
    ]
    
    // MARK: - Initialization
    
    func initialize() {
        if let savedStrategy = UserDefaults.standard.string(forKey: "conflictResolver.strategy"),
           let strategy = ConflictStrategy(rawValue: savedStrategy) {
            preferredStrategy = strategy
        }
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts between local and remote changes
    func resolveConflicts(
        local: [SyncChange],
        remote: [SyncChange]
    ) async -> ResolvedChanges {
        
        var toApplyLocally: [SyncChange] = []
        var toPushRemote: [SyncChange] = []
        var conflicts: [SyncConflict] = []
        
        lastAutoResolvedCount = 0
        
        // Group changes by entity
        let localByEntity = Dictionary(grouping: local) { "\($0.entityType):\($0.entityId)" }
        let remoteByEntity = Dictionary(grouping: remote) { "\($0.entityType):\($0.entityId)" }
        
        // Process remote-only changes (apply locally)
        for (key, remoteChanges) in remoteByEntity {
            if localByEntity[key] == nil {
                toApplyLocally.append(contentsOf: remoteChanges)
            }
        }
        
        // Process local-only changes (push to remote)
        for (key, localChanges) in localByEntity {
            if remoteByEntity[key] == nil {
                toPushRemote.append(contentsOf: localChanges)
            }
        }
        
        // Process conflicts (both local and remote changed)
        for (key, localChanges) in localByEntity {
            guard let remoteChanges = remoteByEntity[key] else { continue }
            
            guard let localChange = localChanges.first,
                  let remoteChange = remoteChanges.first else { continue }
            
            let conflict = SyncConflict(
                entityType: localChange.entityType,
                entityId: localChange.entityId,
                localChange: localChange,
                remoteChange: remoteChange
            )
            
            if requiresUserConfirmation.contains(localChange.entityType) {
                conflicts.append(conflict)
                continue
            }
            
            if let resolved = autoResolve(conflict) {
                switch resolved.winner {
                case .local:
                    toPushRemote.append(localChange)
                case .remote:
                    toApplyLocally.append(remoteChange)
                case .merged(let mergedChange):
                    toApplyLocally.append(mergedChange)
                    toPushRemote.append(mergedChange)
                }
                lastAutoResolvedCount += 1
            } else {
                conflicts.append(conflict)
            }
        }
        
        pendingConflicts = conflicts
        
        return ResolvedChanges(
            toApplyLocally: toApplyLocally,
            toPushRemote: toPushRemote,
            unresolvedConflicts: conflicts
        )
    }
    
    // MARK: - Auto Resolution
    
    private func autoResolve(_ conflict: SyncConflict) -> ConflictResolution? {
        switch preferredStrategy {
        case .lastWriteWins:
            return resolveByTimestamp(conflict)
        case .fieldLevelMerge:
            return resolveByFieldMerge(conflict)
        case .alwaysLocal:
            return ConflictResolution(winner: .local, reason: "User preference: always local")
        case .alwaysRemote:
            return ConflictResolution(winner: .remote, reason: "User preference: always remote")
        case .askUser:
            return nil
        }
    }
    
    private func resolveByTimestamp(_ conflict: SyncConflict) -> ConflictResolution {
        let localTime = conflict.localChange.modifiedAt
        let remoteTime = conflict.remoteChange.modifiedAt
        
        if localTime > remoteTime {
            return ConflictResolution(
                winner: .local,
                reason: "Local change is newer (\(formatDate(localTime)) vs \(formatDate(remoteTime)))"
            )
        } else {
            return ConflictResolution(
                winner: .remote,
                reason: "Remote change is newer (\(formatDate(remoteTime)) vs \(formatDate(localTime)))"
            )
        }
    }
    
    private func resolveByFieldMerge(_ conflict: SyncConflict) -> ConflictResolution? {
        guard let localData = conflict.localChange.data,
              let remoteData = conflict.remoteChange.data else {
            return resolveByTimestamp(conflict)
        }
        
        var mergedData: [String: Any] = [:]
        var hasConflict = false
        
        let allKeys = Set(localData.keys).union(Set(remoteData.keys))
        
        for key in allKeys {
            let localValue = localData[key]
            let remoteValue = remoteData[key]
            
            if protectedFields.contains(key) && localValue != nil && remoteValue != nil {
                if !valuesEqual(localValue, remoteValue) {
                    hasConflict = true
                    break
                }
            }
            
            if localValue == nil {
                mergedData[key] = remoteValue
            } else if remoteValue == nil {
                mergedData[key] = localValue
            } else if valuesEqual(localValue, remoteValue) {
                mergedData[key] = localValue
            } else {
                let localTime = conflict.localChange.modifiedAt
                let remoteTime = conflict.remoteChange.modifiedAt
                mergedData[key] = localTime > remoteTime ? localValue : remoteValue
            }
        }
        
        if hasConflict {
            return nil
        }
        
        let mergedChange = SyncChange(
            type: conflict.localChange.type,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            modifiedAt: Date(),
            data: mergedData
        )
        
        return ConflictResolution(
            winner: .merged(mergedChange),
            reason: "Fields merged from both versions"
        )
    }
    
    // MARK: - User Resolution
    
    func resolveWithUserChoice(
        _ conflict: SyncConflict,
        choice: UserConflictChoice,
        modelContext: ModelContext
    ) async throws {
        
        switch choice {
        case .keepLocal:
            try await applyResolution(conflict, winner: .local, modelContext: modelContext)
        case .keepRemote:
            try await applyResolution(conflict, winner: .remote, modelContext: modelContext)
        case .keepBoth:
            try await createDuplicate(conflict, modelContext: modelContext)
        case .merge:
            if let resolution = resolveByFieldMerge(conflict),
               case .merged = resolution.winner {
                try await applyResolution(conflict, winner: resolution.winner, modelContext: modelContext)
            } else {
                throw ConflictError.mergeNotPossible
            }
        }
        
        pendingConflicts.removeAll { $0.id == conflict.id }
        logConflictResolution(conflict, choice: choice)
    }
    
    private func applyResolution(
        _ conflict: SyncConflict,
        winner: ConflictWinner,
        modelContext: ModelContext
    ) async throws {
        switch conflict.entityType {
        case "Transaction":
            try await resolveTransactionConflict(conflict, winner: winner, modelContext: modelContext)
        case "Account":
            try await resolveAccountConflict(conflict, winner: winner, modelContext: modelContext)
        case "Category":
            try await resolveCategoryConflict(conflict, winner: winner, modelContext: modelContext)
        case "Budget":
            try await resolveBudgetConflict(conflict, winner: winner, modelContext: modelContext)
        default:
            break
        }
    }
    
    // MARK: - Entity-Specific Resolution
    
    private func resolveTransactionConflict(
        _ conflict: SyncConflict,
        winner: ConflictWinner,
        modelContext: ModelContext
    ) async throws {
        // IMPORTANT: Extract entityId to local variable for #Predicate macro
        let entityId = conflict.entityId
        let predicate = #Predicate<Transaction> { $0.id == entityId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let transaction = try modelContext.fetch(descriptor).first else {
            throw ConflictError.entityNotFound
        }
        
        switch winner {
        case .local:
            transaction.updatedAt = Date()
        case .remote:
            if let data = conflict.remoteChange.data {
                applyTransactionData(data, to: transaction)
            }
        case .merged(let change):
            if let data = change.data {
                applyTransactionData(data, to: transaction)
            }
        }
        
        try modelContext.save()
    }
    
    private func resolveAccountConflict(
        _ conflict: SyncConflict,
        winner: ConflictWinner,
        modelContext: ModelContext
    ) async throws {
        // IMPORTANT: Extract entityId to local variable for #Predicate macro
        let entityId = conflict.entityId
        let predicate = #Predicate<Account> { $0.id == entityId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let account = try modelContext.fetch(descriptor).first else {
            throw ConflictError.entityNotFound
        }
        
        switch winner {
        case .local:
            account.modifiedDate = Date()
        case .remote:
            if let data = conflict.remoteChange.data {
                applyAccountData(data, to: account)
            }
        case .merged(let change):
            if let data = change.data {
                applyAccountData(data, to: account)
            }
        }
        
        try modelContext.save()
    }
    
    private func resolveCategoryConflict(
        _ conflict: SyncConflict,
        winner: ConflictWinner,
        modelContext: ModelContext
    ) async throws {
        // IMPORTANT: Extract entityId to local variable for #Predicate macro
        let entityId = conflict.entityId
        let predicate = #Predicate<Category> { $0.id == entityId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard (try modelContext.fetch(descriptor).first) != nil else {
            throw ConflictError.entityNotFound
        }
        
        try modelContext.save()
    }
    
    private func resolveBudgetConflict(
        _ conflict: SyncConflict,
        winner: ConflictWinner,
        modelContext: ModelContext
    ) async throws {
        // IMPORTANT: Extract entityId to local variable for #Predicate macro
        let entityId = conflict.entityId
        let predicate = #Predicate<Budget> { $0.id == entityId }
        let descriptor = FetchDescriptor(predicate: predicate)
        
        guard let budget = try modelContext.fetch(descriptor).first else {
            throw ConflictError.entityNotFound
        }
        
        switch winner {
        case .local:
            budget.updatedAt = Date()
        case .remote, .merged:
            budget.updatedAt = Date()
        }
        
        try modelContext.save()
    }
    
    // MARK: - Duplicate Creation
    
    private func createDuplicate(
        _ conflict: SyncConflict,
        modelContext: ModelContext
    ) async throws {
        switch conflict.entityType {
        case "Transaction":
            // IMPORTANT: Extract entityId to local variable for #Predicate macro
            let entityId = conflict.entityId
            let predicate = #Predicate<Transaction> { $0.id == entityId }
            let descriptor = FetchDescriptor(predicate: predicate)
            
            guard let original = try modelContext.fetch(descriptor).first else {
                throw ConflictError.entityNotFound
            }
            
            if let data = conflict.remoteChange.data {
                let duplicate = Transaction(
                    amount: data["amount"] as? Double ?? original.amount,
                    date: data["date"] as? Date ?? original.date,
                    note: (data["note"] as? String ?? original.note) + " (Sync Conflict)",
                    isIncome: original.isIncome,
                    merchantName: original.merchantName
                )
                modelContext.insert(duplicate)
            }
            
        default:
            throw ConflictError.duplicateNotSupported
        }
        
        try modelContext.save()
    }
    
    // MARK: - Helpers
    
    private func valuesEqual(_ a: Any?, _ b: Any?) -> Bool {
        if a == nil && b == nil { return true }
        if a == nil || b == nil { return false }
        
        if let aString = a as? String, let bString = b as? String {
            return aString == bString
        }
        if let aInt = a as? Int, let bInt = b as? Int {
            return aInt == bInt
        }
        if let aDouble = a as? Double, let bDouble = b as? Double {
            return abs(aDouble - bDouble) < 0.001
        }
        if let aDate = a as? Date, let bDate = b as? Date {
            return abs(aDate.timeIntervalSince(bDate)) < 1
        }
        if let aBool = a as? Bool, let bBool = b as? Bool {
            return aBool == bBool
        }
        
        return false
    }
    
    private func applyTransactionData(_ data: [String: Any], to transaction: Transaction) {
        if let amount = data["amount"] as? Double { transaction.amount = amount }
        if let date = data["date"] as? Date { transaction.date = date }
        if let note = data["note"] as? String { transaction.note = note }
        if let merchantName = data["merchantName"] as? String { transaction.merchantName = merchantName }
        transaction.updatedAt = Date()
    }
    
    private func applyAccountData(_ data: [String: Any], to account: Account) {
        if let name = data["name"] as? String { account.name = name }
        if let balance = data["currentBalance"] as? Double { account.currentBalance = balance }
        if let notes = data["notes"] as? String { account.notes = notes }
        account.modifiedDate = Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        return DateFormatter.shortDate.string(from: date)
    }
    
    private func logConflictResolution(_ conflict: SyncConflict, choice: UserConflictChoice) {
        print("✅ Conflict resolved: \(conflict.entityType) \(conflict.entityId) -> \(choice)")
    }
    
    func clearPendingConflicts() {
        pendingConflicts.removeAll()
    }
}

// MARK: - Supporting Types

struct SyncConflict: Identifiable {
    let id: String
    let entityType: String
    let entityId: UUID
    let localChange: SyncChange
    let remoteChange: SyncChange
    let detectedAt: Date
    
    init(
        entityType: String,
        entityId: UUID,
        localChange: SyncChange,
        remoteChange: SyncChange
    ) {
        self.id = "\(entityType):\(entityId.uuidString)"
        self.entityType = entityType
        self.entityId = entityId
        self.localChange = localChange
        self.remoteChange = remoteChange
        self.detectedAt = Date()
    }
    
    var localModifiedAt: Date { localChange.modifiedAt }
    var remoteModifiedAt: Date { remoteChange.modifiedAt }
    
    var timeDifference: TimeInterval {
        abs(localModifiedAt.timeIntervalSince(remoteModifiedAt))
    }
}

struct ConflictResolution {
    let winner: ConflictWinner
    let reason: String
}

enum ConflictWinner {
    case local
    case remote
    case merged(SyncChange)
}

enum ConflictStrategy: String, CaseIterable, Sendable {
    case lastWriteWins = "lastWriteWins"
    case fieldLevelMerge = "fieldLevelMerge"
    case alwaysLocal = "alwaysLocal"
    case alwaysRemote = "alwaysRemote"
    case askUser = "askUser"
    
    var displayName: String {
        switch self {
        case .lastWriteWins: return "Most Recent Wins"
        case .fieldLevelMerge: return "Merge Fields"
        case .alwaysLocal: return "Always Keep Local"
        case .alwaysRemote: return "Always Keep Remote"
        case .askUser: return "Always Ask"
        }
    }
    
    var description: String {
        switch self {
        case .lastWriteWins:
            return "The most recently modified version wins"
        case .fieldLevelMerge:
            return "Merge non-conflicting fields from both versions"
        case .alwaysLocal:
            return "Always keep the version on this device"
        case .alwaysRemote:
            return "Always keep the version from iCloud"
        case .askUser:
            return "Ask you to choose for each conflict"
        }
    }
}

enum UserConflictChoice: Sendable {
    case keepLocal
    case keepRemote
    case keepBoth
    case merge
}

struct ResolvedChanges {
    let toApplyLocally: [SyncChange]
    let toPushRemote: [SyncChange]
    let unresolvedConflicts: [SyncConflict]
    
    var hasUnresolved: Bool { !unresolvedConflicts.isEmpty }
    var totalResolved: Int { toApplyLocally.count + toPushRemote.count }
}

enum ConflictError: LocalizedError, Sendable {
    case entityNotFound
    case mergeNotPossible
    case duplicateNotSupported
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "The conflicting item could not be found"
        case .mergeNotPossible:
            return "The changes cannot be merged automatically"
        case .duplicateNotSupported:
            return "This type of item cannot be duplicated"
        case .invalidData:
            return "The conflict data is invalid"
        }
    }
}

// MARK: - Conflict Resolution View

struct ConflictResolutionView: View {
    
    let conflict: SyncConflict
    let onResolve: (UserConflictChoice) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                
                Text("Sync Conflict")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This \(conflict.entityType.lowercased()) was modified on multiple devices.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 16) {
                    ComparisonCard(
                        title: "This Device",
                        date: conflict.localModifiedAt,
                        icon: "iphone",
                        isSelected: false
                    )
                    
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                    
                    ComparisonCard(
                        title: "iCloud",
                        date: conflict.remoteModifiedAt,
                        icon: "icloud.fill",
                        isSelected: false
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        onResolve(.keepLocal)
                        dismiss()
                    } label: {
                        Text("Keep This Device's Version")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityHint("Keeps the version modified on this device and discards the iCloud version")
                    
                    Button {
                        onResolve(.keepRemote)
                        dismiss()
                    } label: {
                        Text("Keep iCloud Version")
                            .font(.headline)
                            .foregroundStyle(Color.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brandPrimary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityHint("Keeps the iCloud version and discards this device's changes")
                    
                    HStack(spacing: 16) {
                        Button {
                            onResolve(.keepBoth)
                            dismiss()
                        } label: {
                            Text("Keep Both")
                                .font(.subheadline)
                        }
                        .accessibilityHint("Creates a duplicate so both versions are kept")
                        
                        Button {
                            onResolve(.merge)
                            dismiss()
                        } label: {
                            Text("Merge")
                                .font(.subheadline)
                        }
                        .accessibilityHint("Attempts to combine changes from both versions")
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .padding(.top, 40)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        dismiss()
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sync conflict for \(conflict.entityType)")
        }
    }
}

private struct ComparisonCard: View {
    let title: String
    let date: Date
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isSelected ? Color.brandPrimary : .secondary)
                .frame(width: 40)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.brandPrimary.opacity(0.1) : Color.floSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.brandPrimary : .clear, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), modified \(date.formatted(.relative(presentation: .named)))")
    }
}

// MARK: - Pending Conflicts Banner

struct PendingConflictsBanner: View {
    
    @State private var pendingConflicts: [SyncConflict] = []
    @State private var showingConflict = false
    @State private var selectedConflict: SyncConflict?
    
    var body: some View {
        if !pendingConflicts.isEmpty {
            Button {
                selectedConflict = pendingConflicts.first
                showingConflict = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pendingConflicts.count) Sync Conflict\(pendingConflicts.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Tap to resolve")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(pendingConflicts.count) sync \(pendingConflicts.count == 1 ? "conflict" : "conflicts") need resolution")
            .accessibilityHint("Double tap to review and resolve conflicts")
            .sheet(isPresented: $showingConflict) {
                if let conflict = selectedConflict {
                    ConflictResolutionView(conflict: conflict) { _ in }
                }
            }
            .task {
                loadConflicts()
            }
        }
    }
    
    @MainActor
    private func loadConflicts() {
        pendingConflicts = ConflictResolver.shared.pendingConflicts
    }
}

// MARK: - Conflict Settings View

struct ConflictSettingsView: View {
    
    @State private var preferredStrategy: ConflictStrategy = .lastWriteWins
    @State private var pendingConflictsCount: Int = 0
    
    var body: some View {
        List {
            Section {
                ForEach(ConflictStrategy.allCases, id: \.self) { strategy in
                    Button {
                        preferredStrategy = strategy
                        Task { @MainActor in
                            ConflictResolver.shared.preferredStrategy = strategy
                        }
                        HapticService.play(.selection)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(strategy.displayName)
                                    .foregroundStyle(.primary)
                                
                                Text(strategy.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if preferredStrategy == strategy {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(strategy.displayName)\(preferredStrategy == strategy ? ", selected" : "")")
                    .accessibilityHint(strategy.description)
                }
            } header: {
                Text("Default Resolution Strategy")
            } footer: {
                Text("Choose how FLO should handle conflicts when the same item is changed on multiple devices.")
            }
            
            if pendingConflictsCount > 0 {
                Section {
                    HStack {
                        Text("Pending Conflicts")
                        Spacer()
                        Text("\(pendingConflictsCount)")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    
                    Button(role: .destructive) {
                        Task { @MainActor in
                            ConflictResolver.shared.clearPendingConflicts()
                            pendingConflictsCount = 0
                        }
                    } label: {
                        Text("Dismiss All Conflicts")
                    }
                    .accessibilityHint("Clears all pending conflicts without resolving them")
                } header: {
                    Text("Current Conflicts")
                }
            }
        }
        .navigationTitle("Conflict Resolution")
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        .task {
            loadState()
        }
    }
    
    @MainActor
    private func loadState() {
        preferredStrategy = ConflictResolver.shared.preferredStrategy
        pendingConflictsCount = ConflictResolver.shared.pendingConflicts.count
    }
}

// MARK: - Preview Support

#if DEBUG
struct ConflictResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        let conflict = SyncConflict(
            entityType: "Transaction",
            entityId: UUID(),
            localChange: SyncChange(
                type: .modified,
                entityType: "Transaction",
                entityId: UUID(),
                modifiedAt: Date().addingTimeInterval(-3600)
            ),
            remoteChange: SyncChange(
                type: .modified,
                entityType: "Transaction",
                entityId: UUID(),
                modifiedAt: Date().addingTimeInterval(-1800)
            )
        )
        
        return ConflictResolutionView(conflict: conflict) { choice in
            print("User chose: \(choice)")
        }
    }
}

struct ConflictSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ConflictSettingsView()
        }
    }
}
#endif
