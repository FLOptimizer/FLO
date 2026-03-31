//  LiabilityBalanceMigrationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - One-Time Liability Balance Polarity Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  MIGRATION PURPOSE:
//  Fixes existing liability accounts (credit cards, loans) that were saved with
//  positive balances due to a bug where the input view did not auto-negate
//  user-entered values. Credit card and loan balances should always be stored
//  as negative values (representing money owed).
//
//  WHY THIS IS NEEDED:
//  - Old behavior: User entered "1500" for a credit card balance → stored as +1500
//  - Correct behavior: User enters "1500" → stored as -1500
//  - Positive balances cause: wrong color display, broken utilization/interest
//    calculations, missing payment alerts, and cards not appearing in summaries
//
//  MIGRATION STRATEGY:
//  1. Fetch all accounts where accountType is a liability (credit card, loan)
//  2. For each account with currentBalance > 0, negate both currentBalance and startingBalance
//  3. Track completion with UserDefaults to prevent re-running
//
//  SAFETY FEATURES:
//  ✅ Only negates positive balances (zero and already-negative are untouched)
//  ✅ UserDefaults flag prevents duplicate migrations
//  ✅ Logs all changes for debugging
//  ✅ Handles startingBalance alongside currentBalance
//

import Foundation
import SwiftData

// MARK: - Liability Balance Migration Service

@MainActor
final class LiabilityBalanceMigrationService {

    // MARK: - Singleton

    static let shared = LiabilityBalanceMigrationService()
    private init() {}

    // MARK: - Constants

    private static let migrationCompletedKey = "FLO.HasCompletedLiabilityBalanceMigration"

    // MARK: - Migration Check

    /// Checks if the liability balance migration should run.
    /// Returns true only if migration has never been completed.
    static func shouldRunMigration() -> Bool {
        let hasCompleted = UserDefaults.standard.bool(forKey: migrationCompletedKey)
        return !hasCompleted
    }

    /// Marks the migration as completed so it won't run again.
    private static func markMigrationCompleted() {
        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        print("✅ Liability balance migration marked as completed")
    }

    // MARK: - Migration Result

    struct MigrationResult {
        let accountsFixed: Int
        let accountsScanned: Int
    }

    // MARK: - Main Migration Method

    /// Scans all liability accounts and negates any positive balances.
    /// This is a one-time fix for accounts created before auto-negation was added.
    func migrateLiabilityBalances(context: ModelContext) -> MigrationResult {
        let descriptor = FetchDescriptor<Account>()

        guard let allAccounts = try? context.fetch(descriptor) else {
            print("⚠️ Liability balance migration: failed to fetch accounts")
            LiabilityBalanceMigrationService.markMigrationCompleted()
            return MigrationResult(accountsFixed: 0, accountsScanned: 0)
        }

        let liabilityAccounts = allAccounts.filter { $0.isLiability }
        var fixedCount = 0

        for account in liabilityAccounts {
            var changed = false

            if account.currentBalance > 0 {
                print("🔧 Fixing \(account.name): currentBalance \(account.currentBalance) → \(-account.currentBalance)")
                account.currentBalance = -account.currentBalance
                changed = true
            }

            if account.startingBalance > 0 {
                print("🔧 Fixing \(account.name): startingBalance \(account.startingBalance) → \(-account.startingBalance)")
                account.startingBalance = -account.startingBalance
                changed = true
            }

            if changed {
                account.lastBalanceUpdate = Date()
                fixedCount += 1
            }
        }

        if fixedCount > 0 {
            do {
                try context.save()
                print("✅ Liability balance migration: fixed \(fixedCount) account(s)")
            } catch {
                print("❌ Liability balance migration: failed to save — \(error)")
            }
        } else {
            print("✅ Liability balance migration: no accounts needed fixing")
        }

        LiabilityBalanceMigrationService.markMigrationCompleted()
        return MigrationResult(accountsFixed: fixedCount, accountsScanned: liabilityAccounts.count)
    }
}
