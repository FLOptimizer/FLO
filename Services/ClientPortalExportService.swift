//  ClientPortalExportService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Read-only shareable tax data snapshot
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Generates a comprehensive JSON snapshot of all tax-relevant data
//  for a given year, suitable for sharing with a preparer or archiving.
//  Includes entity profiles, form-line totals, partner allocations,
//  depreciation schedules, and carryforward items.
//

import Foundation
import SwiftData

// MARK: - Export Model

struct ClientPortalSnapshot: Codable, Identifiable {
    let id: String
    let exportDate: String
    let taxYear: Int
    let appVersion: String
    let filingStatus: String
    let entities: [EntitySnapshot]
    let personalIncome: IncomeSummary
    let estimatedPayments: EstimatedPaymentSummary
}

struct EntitySnapshot: Codable, Identifiable {
    let id: String
    let businessName: String
    let businessType: String
    let ein: String?
    let naicsCode: String?
    let accountingMethod: String?
    let formType: String
    let incomeSummary: IncomeSummary
    let formLineTotals: [FormLineExport]
    let partners: [PartnerExport]?
    let assets: [AssetExport]?
    let carryforwards: [CarryforwardExport]?
}

struct IncomeSummary: Codable {
    let grossIncome: Double
    let totalExpenses: Double
    let netIncome: Double
    let transactionCount: Int
}

struct FormLineExport: Codable {
    let formType: String
    let lineNumber: String
    let description: String
    let amount: Double
    let transactionCount: Int
}

struct PartnerExport: Codable {
    let partnerName: String
    let ownershipPercent: Double
    let ordinaryIncome: Double
    let selfEmploymentEarnings: Double
    let beginningCapital: Double
    let endingCapital: Double
    let outsideBasis: Double
    let suspendedLosses: Double
}

struct AssetExport: Codable {
    let name: String
    let cost: Double
    let placedInService: String
    let recoveryPeriod: Double
    let method: String
    let currentYearDepreciation: Double
    let accumulatedDepreciation: Double
    let remainingBasis: Double
}

struct CarryforwardExport: Codable {
    let type: String
    let originYear: Int
    let originalAmount: Double
    let remainingAmount: Double
    let status: String
    let partnerName: String?
}

struct EstimatedPaymentSummary: Codable {
    let totalPaid: Double
    let projectedLiability: Double
    let safeHarborMet: Bool
}

// MARK: - Service

@MainActor
final class ClientPortalExportService {
    static let shared = ClientPortalExportService()

    private init() {}

    // MARK: - Public API

    /// Generates a full JSON snapshot of tax data for a given year.
    func generateSnapshot(
        businesses: [BusinessProfile],
        transactions: [Transaction],
        taxSettings: TaxSettings?,
        taxYear: Int,
        modelContext: ModelContext
    ) -> ClientPortalSnapshot {
        let settings = taxSettings ?? TaxSettings()
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Personal income (non-business)
        let personalTxns = transactions.filter {
            calendar.component(.year, from: $0.date) == taxYear
            && $0.financeType == .personal
            && !$0.isTransfer
        }
        let personalIncome = IncomeSummary(
            grossIncome: personalTxns.filter { $0.isIncome }.reduce(0) { $0 + $1.amount },
            totalExpenses: personalTxns.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount },
            netIncome: personalTxns.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) },
            transactionCount: personalTxns.count
        )

        // Entity snapshots
        let entities = businesses
            .filter { $0.isActive }
            .map { biz in
                entitySnapshot(
                    business: biz,
                    transactions: transactions,
                    taxYear: taxYear,
                    dateFormatter: dateFormatter
                )
            }

        // Estimated payments
        let totalPaid = TransferService.shared.calculateYTDTaxPayments(
            context: modelContext,
            year: taxYear
        )

        let estimatedStatus = EstimatedTaxAlertService.shared.computeStatus(
            taxYear: taxYear,
            transactions: transactions,
            taxSettings: taxSettings,
            modelContext: modelContext
        )

        let payments = EstimatedPaymentSummary(
            totalPaid: totalPaid,
            projectedLiability: estimatedStatus.projectedAnnualTax,
            safeHarborMet: estimatedStatus.safeHarborStatus.isSafe
        )

        return ClientPortalSnapshot(
            id: UUID().uuidString,
            exportDate: dateFormatter.string(from: Date()),
            taxYear: taxYear,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            filingStatus: settings.filingStatus.displayName,
            entities: entities,
            personalIncome: personalIncome,
            estimatedPayments: payments
        )
    }

    /// Exports snapshot as formatted JSON data.
    func exportJSON(snapshot: ClientPortalSnapshot) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(snapshot)
    }

    /// Saves JSON to a temporary file and returns the URL.
    func saveToFile(snapshot: ClientPortalSnapshot) -> URL? {
        guard let data = exportJSON(snapshot: snapshot) else { return nil }
        let fileName = "FLO_TaxData_\(snapshot.taxYear)_\(snapshot.exportDate).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Entity Snapshot Builder

    private func entitySnapshot(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int,
        dateFormatter: DateFormatter
    ) -> EntitySnapshot {
        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        let incomeSummary = IncomeSummary(
            grossIncome: summary.totalIncome,
            totalExpenses: summary.totalDeductions,
            netIncome: summary.ordinaryIncome,
            transactionCount: summary.formLineTotals.reduce(0) { $0 + $1.transactionCount }
        )

        let formLines = summary.formLineTotals.map { flt in
            FormLineExport(
                formType: summary.formType.displayName,
                lineNumber: flt.taxFormLine.lineNumber,
                description: flt.taxFormLine.irsDescription,
                amount: flt.deductibleAmount,
                transactionCount: flt.transactionCount
            )
        }

        // Partners
        let partners: [PartnerExport]? = business.isPartnership ? summary.partnerSummaries.map { k1 in
            PartnerExport(
                partnerName: k1.partner.partnerName,
                ownershipPercent: k1.partner.ownershipPercentage * 100,
                ordinaryIncome: k1.ordinaryIncome,
                selfEmploymentEarnings: k1.selfEmploymentEarnings,
                beginningCapital: k1.beginningCapital,
                endingCapital: k1.endingCapital,
                outsideBasis: k1.outsideBasis,
                suspendedLosses: k1.suspendedLossAmount
            )
        } : nil

        // Assets
        let assets: [AssetExport]? = business.assets?.map { asset in
            let schedule = MACRSCalculationService.shared.generateFullSchedule(for: asset)
            let currentYear = schedule.first { $0.year == taxYear }
            let accumulated = schedule
                .filter { $0.year <= taxYear }
                .reduce(0) { $0 + $1.amount }

            return AssetExport(
                name: asset.name,
                cost: asset.cost,
                placedInService: dateFormatter.string(from: asset.placedInServiceDate),
                recoveryPeriod: asset.recoveryPeriodYears,
                method: asset.depreciationMethod.rawValue,
                currentYearDepreciation: currentYear?.amount ?? 0,
                accumulatedDepreciation: accumulated,
                remainingBasis: max(0, asset.cost - accumulated)
            )
        }

        // Carryforwards
        let carryforwards: [CarryforwardExport]? = business.carryforwards?
            .filter { $0.status == .active || $0.status == .partiallyUtilized }
            .map { cf in
                CarryforwardExport(
                    type: cf.type.displayName,
                    originYear: cf.originYear,
                    originalAmount: cf.originalAmount,
                    remainingAmount: cf.remainingAmount,
                    status: cf.status.rawValue,
                    partnerName: cf.partnerName
                )
            }

        return EntitySnapshot(
            id: business.id.uuidString,
            businessName: business.businessName,
            businessType: business.businessType.displayName,
            ein: business.taxId,
            naicsCode: business.naicsCode,
            accountingMethod: business.accountingMethod.rawValue,
            formType: summary.formType.displayName,
            incomeSummary: incomeSummary,
            formLineTotals: formLines,
            partners: partners,
            assets: assets,
            carryforwards: carryforwards
        )
    }
}
