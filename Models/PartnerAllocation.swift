//  PartnerAllocation.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Partnership member tracking for K-1 and tax handoff
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tracks individual partners in a partnership/LLC, their ownership percentages,
//  and profit/loss sharing ratios. Used to compute K-1 allocations and generate
//  partner capital account worksheets in the Tax Handoff PDF.
//

import Foundation
import SwiftData

@Model
final class PartnerAllocation {

    // MARK: - Properties

    /// Unique identifier
    var id: UUID = UUID()

    /// Full name of the partner (e.g., "Travis Tyler Anderson")
    var partnerName: String = ""

    /// Ownership percentage as a decimal (0.0–1.0). Example: 0.50 = 50%
    var ownershipPercentage: Double = 0.0

    /// Profit-sharing percentage (may differ from ownership). Decimal 0.0–1.0.
    var profitSharePercentage: Double = 0.0

    /// Loss-sharing percentage (may differ from profit share). Decimal 0.0–1.0.
    var lossSharePercentage: Double = 0.0

    /// Whether this partner is a managing member with operational authority
    var isManagingMember: Bool = false

    /// Partner's mailing address (for K-1 form)
    var address: String?

    /// Capital contributed by this partner (cumulative, user-entered or computed)
    var capitalContributed: Double = 0.0

    /// Beginning capital account balance for the current year
    var beginningCapitalBalance: Double = 0.0

    /// Debt allocation under IRC §752 (affects partner's outside basis)
    var debtAllocation: Double = 0.0

    /// Whether this partner's losses are currently suspended (e.g., §704(d) basis limitation)
    var hasLossesSuspended: Bool = false

    /// Amount of suspended losses (if applicable)
    var suspendedLossAmount: Double = 0.0

    /// Notes about this partner's tax situation
    var notes: String?

    /// Date this partner was added to the entity
    var dateAdded: Date = Date()

    // MARK: - Relationships

    /// The business profile this partner belongs to
    @Relationship(deleteRule: .nullify)
    var businessProfile: BusinessProfile?

    // MARK: - Computed Properties

    /// Formatted ownership display (e.g., "50%")
    var ownershipDisplay: String {
        "\(Int(ownershipPercentage * 100))%"
    }

    /// Ending capital account balance given allocated income/loss
    func endingCapitalBalance(allocatedIncome: Double) -> Double {
        beginningCapitalBalance + capitalContributed + allocatedIncome
    }

    /// Outside basis = ending capital + debt allocation
    func outsideBasis(allocatedIncome: Double) -> Double {
        max(0, endingCapitalBalance(allocatedIncome: allocatedIncome) + debtAllocation)
    }

    /// Whether this partner can deduct their allocated loss (basis > 0)
    func canDeductLoss(allocatedLoss: Double) -> Bool {
        let basis = outsideBasis(allocatedIncome: allocatedLoss)
        return basis > 0
    }

    // MARK: - Initialization

    init(
        partnerName: String,
        ownershipPercentage: Double = 0.5,
        profitSharePercentage: Double? = nil,
        lossSharePercentage: Double? = nil,
        isManagingMember: Bool = false,
        address: String? = nil,
        capitalContributed: Double = 0.0,
        beginningCapitalBalance: Double = 0.0,
        debtAllocation: Double = 0.0
    ) {
        self.id = UUID()
        self.partnerName = partnerName
        self.ownershipPercentage = ownershipPercentage
        self.profitSharePercentage = profitSharePercentage ?? ownershipPercentage
        self.lossSharePercentage = lossSharePercentage ?? ownershipPercentage
        self.isManagingMember = isManagingMember
        self.address = address
        self.capitalContributed = capitalContributed
        self.beginningCapitalBalance = beginningCapitalBalance
        self.debtAllocation = debtAllocation
        self.dateAdded = Date()
    }
}

// MARK: - Protocol Conformances

extension PartnerAllocation: Identifiable { }

extension PartnerAllocation: Equatable {
    static func == (lhs: PartnerAllocation, rhs: PartnerAllocation) -> Bool {
        lhs.id == rhs.id
    }
}

extension PartnerAllocation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
