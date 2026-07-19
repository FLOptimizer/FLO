//  YearEndClosingService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Year-end closing workflow engine
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Performs year-end closing operations for each business:
//  1. Roll carryforwards (create new year entries, mark utilized)
//  2. Reset partner capital balances (ending → beginning)
//  3. Advance depreciation (compute next year, update accumulated)
//  4. Generate closing summary
//

import Foundation
import SwiftData

// MARK: - Result Types

/// Summary of a single closing step.
struct ClosingStepResult: Identifiable {
    let id = UUID()
    let stepName: String
    let description: String
    let icon: String
    let itemsProcessed: Int
    let status: StepStatus

    enum StepStatus {
        case success
        case warning(String)
        case skipped(String)
    }
}

/// Summary of the complete year-end close for one business.
struct BusinessClosingSummary: Identifiable {
    let id = UUID()
    let business: BusinessProfile
    let taxYear: Int
    let steps: [ClosingStepResult]
    let closedDate: Date

    var hasWarnings: Bool {
        steps.contains { if case .warning = $0.status { return true } else { return false } }
    }

    var totalItemsProcessed: Int {
        steps.reduce(0) { $0 + $1.itemsProcessed }
    }
}

/// Complete year-end closing result across all businesses.
struct YearEndClosingResult: Identifiable {
    let id = UUID()
    let taxYear: Int
    let businessSummaries: [BusinessClosingSummary]
    let closedDate: Date

    var totalSteps: Int {
        businessSummaries.reduce(0) { $0 + $1.steps.count }
    }

    var totalItemsProcessed: Int {
        businessSummaries.reduce(0) { $0 + $1.totalItemsProcessed }
    }
}

// MARK: - Preview Data

/// Dry-run preview of what the closing will do (before committing).
struct ClosingPreview: Identifiable {
    let id = UUID()
    let business: BusinessProfile
    let taxYear: Int
    let carryforwardsToRoll: [CarryforwardRollPreview]
    let partnersToReset: [PartnerResetPreview]
    let assetsToAdvance: [AssetAdvancePreview]
    let suspendedLossAlerts: [SuspendedLossAlert]
}

struct CarryforwardRollPreview: Identifiable {
    let id = UUID()
    let carryforward: TaxCarryforward
    let action: String // "Roll forward", "Mark expired", etc.
}

struct PartnerResetPreview: Identifiable {
    let id = UUID()
    let partner: PartnerAllocation
    let currentEndingCapital: Double
    let newBeginningCapital: Double
}

struct AssetAdvancePreview: Identifiable {
    let id = UUID()
    let asset: DepreciableAsset
    let currentYearDepreciation: Double
    let nextYearDepreciation: Double
    let remainingBasis: Double
}

struct SuspendedLossAlert: Identifiable {
    let id = UUID()
    let partnerName: String
    let amount: Double
    let reason: String
}

// MARK: - Service

@MainActor
final class YearEndClosingService {
    static let shared = YearEndClosingService()

    private init() {}

    // MARK: - Preview (Dry Run)

    /// Generates a preview of what the year-end close will do without making changes.
    func generatePreview(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int
    ) -> ClosingPreview {
        // Carryforward rolls
        let carryforwardPreviews = (business.carryforwards ?? []).compactMap { cf -> CarryforwardRollPreview? in
            guard cf.isActive else { return nil }

            if let expYear = cf.expirationYear, expYear <= taxYear {
                return CarryforwardRollPreview(
                    carryforward: cf,
                    action: "Mark expired (expired \(expYear))"
                )
            }

            return CarryforwardRollPreview(
                carryforward: cf,
                action: "Roll forward to \(taxYear + 1) (\(NumberFormatter.appCurrency.string(from: NSNumber(value: cf.remainingAmount)) ?? "$0") remaining)"
            )
        }

        // Partner resets
        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        let partnerPreviews = summary.partnerSummaries.map { k1 in
            PartnerResetPreview(
                partner: k1.partner,
                currentEndingCapital: k1.endingCapital,
                newBeginningCapital: k1.endingCapital
            )
        }

        // Asset advances
        let assetPreviews = business.activeAssets.map { asset in
            let currentYearDep = asset.depreciationForYear(taxYear)
            let nextYearDep = asset.depreciationForYear(taxYear + 1)
            let accumulated = asset.accumulatedDepreciation(throughYear: taxYear)
            let remaining = max(0, asset.cost - accumulated)

            return AssetAdvancePreview(
                asset: asset,
                currentYearDepreciation: currentYearDep,
                nextYearDepreciation: nextYearDep,
                remainingBasis: remaining
            )
        }

        // Suspended loss alerts
        let suspendedAlerts = summary.partnerSummaries.compactMap { k1 -> SuspendedLossAlert? in
            guard k1.suspendedLossAmount > 0 else { return nil }
            return SuspendedLossAlert(
                partnerName: k1.partner.partnerName,
                amount: k1.suspendedLossAmount,
                reason: "Losses exceed outside basis — suspended under IRC \u{00A7}704(d)"
            )
        }

        return ClosingPreview(
            business: business,
            taxYear: taxYear,
            carryforwardsToRoll: carryforwardPreviews,
            partnersToReset: partnerPreviews,
            assetsToAdvance: assetPreviews,
            suspendedLossAlerts: suspendedAlerts
        )
    }

    // MARK: - Execute Close

    /// Executes the year-end close for a single business. This mutates SwiftData models.
    func executeClose(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int,
        context: ModelContext
    ) -> BusinessClosingSummary {
        var steps: [ClosingStepResult] = []

        // Step 1: Roll carryforwards
        steps.append(rollCarryforwards(business: business, taxYear: taxYear, context: context))

        // Step 2: Create suspended loss carryforwards from K-1 allocations
        steps.append(createSuspendedLossCarryforwards(
            business: business,
            transactions: transactions,
            taxYear: taxYear,
            context: context
        ))

        // Step 3: Reset partner capital balances
        steps.append(resetPartnerCapital(
            business: business,
            transactions: transactions,
            taxYear: taxYear
        ))

        // Step 4: Advance depreciation (no model changes needed — schedules are computed)
        steps.append(verifyDepreciation(business: business, taxYear: taxYear))

        // Save changes
        do {
            try context.save()
        } catch {
            steps.append(ClosingStepResult(
                stepName: "Save",
                description: "Failed to save changes: \(error.localizedDescription)",
                icon: "exclamationmark.triangle.fill",
                itemsProcessed: 0,
                status: .warning("Save failed — changes may not persist")
            ))
        }

        return BusinessClosingSummary(
            business: business,
            taxYear: taxYear,
            steps: steps,
            closedDate: Date()
        )
    }

    /// Executes year-end close for all active businesses.
    func executeCloseAll(
        businesses: [BusinessProfile],
        transactions: [Transaction],
        taxYear: Int,
        context: ModelContext
    ) -> YearEndClosingResult {
        let summaries = businesses.map { business in
            executeClose(
                business: business,
                transactions: transactions,
                taxYear: taxYear,
                context: context
            )
        }

        return YearEndClosingResult(
            taxYear: taxYear,
            businessSummaries: summaries,
            closedDate: Date()
        )
    }

    // MARK: - Step 1: Roll Carryforwards

    private func rollCarryforwards(
        business: BusinessProfile,
        taxYear: Int,
        context: ModelContext
    ) -> ClosingStepResult {
        let carryforwards = business.carryforwards ?? []
        let active = carryforwards.filter { $0.isActive }

        guard !active.isEmpty else {
            return ClosingStepResult(
                stepName: "Roll Carryforwards",
                description: "No active carryforwards to roll",
                icon: "arrow.uturn.forward.circle.fill",
                itemsProcessed: 0,
                status: .skipped("No active items")
            )
        }

        var processed = 0
        var warnings: [String] = []

        for cf in active {
            // Check expiration
            if let expYear = cf.expirationYear, expYear <= taxYear {
                cf.markExpired()
                processed += 1
                warnings.append("\(cf.type.displayName) expired (origin \(cf.originYear))")
                continue
            }

            // Active carryforwards persist — no model change needed,
            // they remain active for the next year
            processed += 1
        }

        let status: ClosingStepResult.StepStatus = warnings.isEmpty
            ? .success
            : .warning(warnings.joined(separator: "; "))

        return ClosingStepResult(
            stepName: "Roll Carryforwards",
            description: "\(processed) carryforward\(processed == 1 ? "" : "s") reviewed",
            icon: "arrow.uturn.forward.circle.fill",
            itemsProcessed: processed,
            status: status
        )
    }

    // MARK: - Step 2: Create Suspended Loss Carryforwards

    private func createSuspendedLossCarryforwards(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int,
        context: ModelContext
    ) -> ClosingStepResult {
        guard business.isPartnership else {
            return ClosingStepResult(
                stepName: "Suspended Losses",
                description: "Not a partnership — skipped",
                icon: "exclamationmark.circle.fill",
                itemsProcessed: 0,
                status: .skipped("Non-partnership entity")
            )
        }

        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        var created = 0

        for k1 in summary.partnerSummaries where k1.suspendedLossAmount > 0 {
            let cf = TaxCarryforward(
                type: .suspendedLoss704d,
                originYear: taxYear,
                originalAmount: k1.suspendedLossAmount,
                partnerName: k1.partner.partnerName
            )
            cf.businessProfile = business
            context.insert(cf)
            created += 1

            // Update partner's suspended loss tracking
            k1.partner.hasLossesSuspended = true
            k1.partner.suspendedLossAmount += k1.suspendedLossAmount
        }

        return ClosingStepResult(
            stepName: "Suspended Losses",
            description: created > 0
                ? "\(created) suspended loss carryforward\(created == 1 ? "" : "s") created"
                : "No losses to suspend",
            icon: "exclamationmark.circle.fill",
            itemsProcessed: created,
            status: .success
        )
    }

    // MARK: - Step 3: Reset Partner Capital

    private func resetPartnerCapital(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int
    ) -> ClosingStepResult {
        let partners = business.sortedPartners
        guard !partners.isEmpty else {
            return ClosingStepResult(
                stepName: "Reset Partner Capital",
                description: "No partners — skipped",
                icon: "person.2.fill",
                itemsProcessed: 0,
                status: .skipped("No partners configured")
            )
        }

        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        for k1 in summary.partnerSummaries {
            // Ending capital becomes next year's beginning capital
            k1.partner.beginningCapitalBalance = k1.endingCapital
        }

        return ClosingStepResult(
            stepName: "Reset Partner Capital",
            description: "\(partners.count) partner\(partners.count == 1 ? "" : "s") capital rolled forward",
            icon: "person.2.fill",
            itemsProcessed: partners.count,
            status: .success
        )
    }

    // MARK: - Step 4: Verify Depreciation

    private func verifyDepreciation(
        business: BusinessProfile,
        taxYear: Int
    ) -> ClosingStepResult {
        let assets = business.activeAssets
        guard !assets.isEmpty else {
            return ClosingStepResult(
                stepName: "Depreciation Review",
                description: "No depreciable assets",
                icon: "chart.bar.fill",
                itemsProcessed: 0,
                status: .skipped("No assets")
            )
        }

        var fullyDepreciated = 0
        for asset in assets {
            let remaining = asset.cost - asset.accumulatedDepreciation(throughYear: taxYear)
            if remaining <= 0.01 {
                fullyDepreciated += 1
            }
        }

        let description: String
        let status: ClosingStepResult.StepStatus

        if fullyDepreciated > 0 {
            description = "\(assets.count) asset\(assets.count == 1 ? "" : "s") reviewed, \(fullyDepreciated) fully depreciated"
            status = .warning("\(fullyDepreciated) asset\(fullyDepreciated == 1 ? "" : "s") fully depreciated — consider disposing")
        } else {
            description = "\(assets.count) asset\(assets.count == 1 ? "" : "s") reviewed — schedules current"
            status = .success
        }

        return ClosingStepResult(
            stepName: "Depreciation Review",
            description: description,
            icon: "chart.bar.fill",
            itemsProcessed: assets.count,
            status: status
        )
    }
}
