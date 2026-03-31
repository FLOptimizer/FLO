//  BalanceAnchor.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Balance Anchor Model
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ CREATED: SwiftData model for balance anchor points
//  ✅ ADDED: Timestamped "truth" assertions that partition transaction timeline
//  ✅ ADDED: AnchorSource enum for tracking how anchors were created
//  ✅ ADDED: sourceRaw String storage with computed source wrapper (migration-safe)
//  ✅ ADDED: @Relationship to Account with .nullify delete rule
//  ✅ NOTE: No inverse relationship on Account — query anchors by account ID

import Foundation
import SwiftData

/// A balance anchor represents a point in time where the account balance
/// is known to be exactly a specific amount.
///
/// Anchors partition the transaction timeline into settled history and live activity:
/// - Transactions **before** the anchor are historical (don't move the balance)
/// - Transactions **after** the anchor are live (affect the balance normally)
///
/// The core balance formula with anchors:
/// ```
/// displayedBalance = latestAnchor.balance + sum(transactions AFTER anchor date)
/// ```
@Model
final class BalanceAnchor {
    var id: UUID = UUID()

    /// The account this anchor belongs to
    @Relationship(deleteRule: .nullify)
    var account: Account?

    /// "As of this date, the balance was exactly..."
    var anchorDate: Date = Date()

    /// "...this amount"
    var anchorBalance: Double = 0.0

    /// How was this anchor created? Stored as raw String for SwiftData migration safety.
    var sourceRaw: String = AnchorSource.accountCreation.rawValue

    /// Optional user note (e.g., "Matched my Chase statement")
    var notes: String = ""

    /// When this anchor was created in FLO
    var createdDate: Date = Date()

    // MARK: - Computed

    /// Typed accessor for the anchor source
    var source: AnchorSource {
        get { AnchorSource(rawValue: sourceRaw) ?? .accountCreation }
        set { sourceRaw = newValue.rawValue }
    }

    /// How the anchor was created
    enum AnchorSource: String, Codable {
        case accountCreation        // Initial balance when account was created
        case manualReconciliation   // User confirmed balance in reconciliation flow
        case csvStatementBalance    // Extracted from CSV running balance column
        case csvImportKeepBalance   // User chose "keep my balance" during CSV import
        case plaidSync              // Future: from bank API
    }

    // MARK: - Init

    init(
        account: Account? = nil,
        anchorDate: Date,
        anchorBalance: Double,
        source: AnchorSource = .accountCreation,
        notes: String = ""
    ) {
        self.account = account
        self.anchorDate = anchorDate
        self.anchorBalance = anchorBalance
        self.sourceRaw = source.rawValue
        self.notes = notes
    }
}

// MARK: - Protocol Conformances

extension BalanceAnchor: Identifiable {}
