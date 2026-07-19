//  BasisTrackingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Real-time partner basis monitoring with alert triggers
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Monitors partner basis across partnerships and generates alerts when:
//  - A partner has zero or near-zero basis (losses will be suspended)
//  - Losses exceed basis (§704(d) suspension triggered)
//  - Basis changes significantly from prior period
//

import Foundation
import SwiftData

// MARK: - Alert Types

struct BasisAlert: Identifiable {
    let id = UUID()
    let partnerName: String
    let businessName: String
    let alertType: BasisAlertType
    let currentBasis: Double
    let allocatedIncome: Double
    let message: String
    let severity: AlertSeverity
    let recommendation: String

    enum BasisAlertType: String {
        case zeroBasis           = "zeroBasis"
        case lossesSuspended     = "lossesSuspended"
        case negativeBasis       = "negativeBasis"
        case lowBasis            = "lowBasis"
        case basisRecovered      = "basisRecovered"
    }

    enum AlertSeverity: Int, Comparable {
        case critical = 0
        case warning = 1
        case info = 2

        static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var icon: String {
            switch self {
            case .critical: return "exclamationmark.triangle.fill"
            case .warning:  return "exclamationmark.circle.fill"
            case .info:     return "info.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .critical: return "red"
            case .warning:  return "orange"
            case .info:     return "blue"
            }
        }
    }
}

/// Complete basis snapshot for a partnership.
struct PartnerBasisSnapshot: Identifiable {
    let id = UUID()
    let business: BusinessProfile
    let taxYear: Int
    let partnerSnapshots: [SinglePartnerBasis]
    let alerts: [BasisAlert]

    var hasAlerts: Bool { !alerts.isEmpty }
    var criticalCount: Int { alerts.filter { $0.severity == .critical }.count }
}

struct SinglePartnerBasis: Identifiable {
    let id = UUID()
    let partner: PartnerAllocation
    let allocatedIncome: Double
    let beginningCapital: Double
    let endingCapital: Double
    let outsideBasis: Double
    let canDeductLoss: Bool
    let suspendedAmount: Double
    let basisUtilization: Double // 0.0–1.0, how much basis is "used"
}

// MARK: - Service

@MainActor
final class BasisTrackingService {
    static let shared = BasisTrackingService()

    private init() {}

    // MARK: - Public API

    /// Generates a complete basis snapshot with alerts for all partnerships.
    func generateSnapshots(
        businesses: [BusinessProfile],
        transactions: [Transaction],
        taxYear: Int
    ) -> [PartnerBasisSnapshot] {
        businesses
            .filter { $0.isPartnership && !$0.sortedPartners.isEmpty }
            .map { business in
                generateSnapshot(
                    business: business,
                    transactions: transactions,
                    taxYear: taxYear
                )
            }
    }

    /// Generates a basis snapshot for a single partnership.
    func generateSnapshot(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int
    ) -> PartnerBasisSnapshot {
        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        var partnerSnapshots: [SinglePartnerBasis] = []
        var alerts: [BasisAlert] = []

        for k1 in summary.partnerSummaries {
            let basisUtilization: Double
            if k1.outsideBasis > 0 && k1.ordinaryIncome < 0 {
                let lossAmount = abs(k1.ordinaryIncome)
                basisUtilization = min(1.0, lossAmount / k1.outsideBasis)
            } else {
                basisUtilization = 0
            }

            let snapshot = SinglePartnerBasis(
                partner: k1.partner,
                allocatedIncome: k1.ordinaryIncome,
                beginningCapital: k1.beginningCapital,
                endingCapital: k1.endingCapital,
                outsideBasis: k1.outsideBasis,
                canDeductLoss: k1.lossDeductible,
                suspendedAmount: k1.suspendedLossAmount,
                basisUtilization: basisUtilization
            )
            partnerSnapshots.append(snapshot)

            // Generate alerts
            alerts.append(contentsOf: generateAlerts(
                for: k1,
                businessName: business.businessName
            ))
        }

        return PartnerBasisSnapshot(
            business: business,
            taxYear: taxYear,
            partnerSnapshots: partnerSnapshots,
            alerts: alerts.sorted { $0.severity < $1.severity }
        )
    }

    /// Quick check: are there any critical basis alerts across all partnerships?
    func hasCriticalAlerts(
        businesses: [BusinessProfile],
        transactions: [Transaction],
        taxYear: Int
    ) -> Bool {
        for business in businesses where business.isPartnership {
            let snapshot = generateSnapshot(
                business: business,
                transactions: transactions,
                taxYear: taxYear
            )
            if snapshot.criticalCount > 0 { return true }
        }
        return false
    }

    // MARK: - Alert Generation

    private func generateAlerts(
        for k1: PartnerK1Summary,
        businessName: String
    ) -> [BasisAlert] {
        var alerts: [BasisAlert] = []
        let partner = k1.partner

        // Critical: losses suspended due to zero basis
        if k1.suspendedLossAmount > 0 {
            let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: k1.suspendedLossAmount)) ?? "$0"
            alerts.append(BasisAlert(
                partnerName: partner.partnerName,
                businessName: businessName,
                alertType: .lossesSuspended,
                currentBasis: k1.outsideBasis,
                allocatedIncome: k1.ordinaryIncome,
                message: "\(formatted) in losses suspended under IRC §704(d)",
                severity: .critical,
                recommendation: "Consider additional capital contributions to restore basis and unlock suspended losses."
            ))
        }

        // Warning: zero basis but no losses yet
        if k1.outsideBasis <= 0 && k1.ordinaryIncome >= 0 {
            alerts.append(BasisAlert(
                partnerName: partner.partnerName,
                businessName: businessName,
                alertType: .zeroBasis,
                currentBasis: k1.outsideBasis,
                allocatedIncome: k1.ordinaryIncome,
                message: "Zero outside basis — any future losses will be suspended",
                severity: .warning,
                recommendation: "Capital contributions or debt allocation can increase basis."
            ))
        }

        // Warning: low basis with losses accumulating
        if k1.outsideBasis > 0 && k1.ordinaryIncome < 0 {
            let lossAmount = abs(k1.ordinaryIncome)
            if lossAmount > k1.outsideBasis * 0.8 {
                let remaining = max(0, k1.outsideBasis - lossAmount)
                let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: remaining)) ?? "$0"
                alerts.append(BasisAlert(
                    partnerName: partner.partnerName,
                    businessName: businessName,
                    alertType: .lowBasis,
                    currentBasis: k1.outsideBasis,
                    allocatedIncome: k1.ordinaryIncome,
                    message: "Only \(formatted) basis remaining — losses are consuming basis rapidly",
                    severity: .warning,
                    recommendation: "Monitor closely. Additional losses this year may be partially suspended."
                ))
            }
        }

        // Info: basis recovered (had suspended losses, now has basis)
        if partner.hasLossesSuspended && k1.outsideBasis > 0 && k1.ordinaryIncome > 0 {
            alerts.append(BasisAlert(
                partnerName: partner.partnerName,
                businessName: businessName,
                alertType: .basisRecovered,
                currentBasis: k1.outsideBasis,
                allocatedIncome: k1.ordinaryIncome,
                message: "Basis restored — previously suspended losses may now be deductible",
                severity: .info,
                recommendation: "Review suspended loss carryforwards. Some may be unlocked this year."
            ))
        }

        return alerts
    }
}
