//  BusinessMigrationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Multi-Business Migration
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Handles one-time migration from single BusinessProfile (v1.0)
//  to multi-business (v2.0) on first launch after update.
//

import Foundation
import SwiftData

@MainActor
class BusinessMigrationService {
    static let shared = BusinessMigrationService()
    private init() {}

    private static let migrationKey = "hasCompletedMultiBusinessMigration"

    /// Whether migration has already been completed
    var hasMigrated: Bool {
        UserDefaults.standard.bool(forKey: Self.migrationKey)
    }

    /// Check if migration is needed and perform it
    /// Returns true if migration was performed, false if already done or not needed
    @discardableResult
    func migrateIfNeeded(context: ModelContext) -> Bool {
        guard !hasMigrated else { return false }

        let allProfiles = (try? context.fetch(FetchDescriptor<BusinessProfile>())) ?? []

        if allProfiles.isEmpty {
            // No existing data — nothing to migrate, mark as done
            markMigrationComplete()
            return false
        }

        // Find the legacy singleton profile
        guard let legacy = allProfiles.first else {
            markMigrationComplete()
            return false
        }

        // Step 1: Ensure it's marked as primary and active
        if !legacy.isPrimary {
            legacy.isPrimary = true
        }
        if !legacy.isActive {
            legacy.isActive = true
        }
        legacy.sortOrder = 0

        // Step 2: Set business type if not already set
        if legacy.businessTypeRaw.isEmpty || legacy.businessTypeRaw == BusinessType.soleProprietorship.rawValue {
            // Keep default — user can change later
        }

        // Step 3: Link existing business accounts to this profile
        let allAccounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        for account in allAccounts {
            if account.financeType == .business && account.businessProfile == nil {
                account.businessProfile = legacy
            }
        }

        // Step 4: Link existing TaxSettings to this profile
        let allTaxSettings = (try? context.fetch(FetchDescriptor<TaxSettings>())) ?? []
        if let existingSettings = allTaxSettings.first, existingSettings.businessProfile == nil {
            existingSettings.businessProfile = legacy
        } else if legacy.taxSettings == nil {
            // Create TaxSettings for this business if none exist
            let settings = TaxSettings()
            settings.businessProfile = legacy
            context.insert(settings)
        }

        // Step 5: Link existing invoices to this profile
        let allInvoices = (try? context.fetch(FetchDescriptor<Invoice>())) ?? []
        for invoice in allInvoices where invoice.businessProfile == nil {
            invoice.businessProfile = legacy
        }

        // Save
        do {
            try context.save()
            markMigrationComplete()
            #if DEBUG
            print("Multi-business migration complete: linked \(allAccounts.filter { $0.businessProfile != nil }.count) accounts, \(allInvoices.count) invoices to \(legacy.businessName)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("Multi-business migration failed: \(error)")
            #endif
            return false
        }
    }

    /// Mark migration as complete
    private func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: Self.migrationKey)
    }

    /// Reset migration flag (for testing)
    func resetMigration() {
        UserDefaults.standard.removeObject(forKey: Self.migrationKey)
    }
}
