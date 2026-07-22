//  CSVImportQuota.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Free-tier CSV import allowance tracking
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Free users get a lifetime allowance of CSV imports (SubscriptionTier
//  .csvImportLimit) so switchers can bring their data in before hitting a
//  paywall. Premium+ is unlimited and never touches the counter.
//

import Foundation

enum CSVImportQuota {

    private static let usedKey = "csvImport.freeImportsUsed"

    /// Completed imports counted against the free allowance
    static var used: Int {
        UserDefaults.standard.integer(forKey: usedKey)
    }

    /// Remaining imports for this tier; nil means unlimited
    static func remaining(for tier: SubscriptionTier) -> Int? {
        guard let limit = tier.csvImportLimit else { return nil }
        return max(0, limit - used)
    }

    static func canImport(tier: SubscriptionTier) -> Bool {
        remaining(for: tier).map { $0 > 0 } ?? true
    }

    /// Record a completed import. No-ops for unlimited tiers so a later
    /// downgrade doesn't inherit a spuriously spent allowance.
    static func recordImport(tier: SubscriptionTier) {
        guard tier.csvImportLimit != nil else { return }
        UserDefaults.standard.set(used + 1, forKey: usedKey)
    }
}
