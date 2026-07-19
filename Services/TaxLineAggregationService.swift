//  TaxLineAggregationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Multi-form tax line aggregation and K-1 allocation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Aggregates transactions by IRS tax form line for a given business profile
//  and tax year. Computes partner K-1 allocations for partnerships/LLCs.
//  Powers the Tax Summary view and Tax Handoff PDF.
//

import Foundation
import SwiftData

// MARK: - Result Types

/// Aggregated total for a single tax form line.
struct FormLineTotal: Identifiable {
    let id = UUID()
    let taxFormLine: TaxFormLine
    let grossAmount: Double
    let deductibleAmount: Double
    let transactionCount: Int

    var formType: TaxFormType { taxFormLine.formType }
    var isIncome: Bool { taxFormLine.isIncomeLine }
}

/// Summary of a partner's K-1 allocation.
struct PartnerK1Summary: Identifiable {
    let id = UUID()
    let partner: PartnerAllocation
    let ordinaryIncome: Double
    let selfEmploymentEarnings: Double
    let capitalContributed: Double
    let beginningCapital: Double
    let endingCapital: Double
    let outsideBasis: Double
    let lossDeductible: Bool
    let suspendedLossAmount: Double
}

/// Complete business tax summary for a year.
struct BusinessTaxYearSummary: Identifiable {
    let id = UUID()
    let businessProfile: BusinessProfile
    let taxYear: Int
    let formType: TaxFormType
    let formLineTotals: [FormLineTotal]
    let totalIncome: Double
    let totalDeductions: Double
    let ordinaryIncome: Double
    let depreciationTotal: Double
    let partnerSummaries: [PartnerK1Summary]
    let carryforwards: [TaxCarryforward]
}

// MARK: - Service

@MainActor
final class TaxLineAggregationService {
    static let shared = TaxLineAggregationService()

    private init() {}

    // MARK: - Public API

    /// Aggregates all transactions for a business by their resolved tax form line.
    func aggregateByFormLine(
        business: BusinessProfile,
        transactions: [Transaction],
        year: Int
    ) -> [FormLineTotal] {
        let calendar = Calendar.current
        let formType = business.taxFormType

        // Filter to business transactions for the given year
        let yearTransactions = transactions.filter { txn in
            let txnYear = calendar.component(.year, from: txn.date)
            return txnYear == year
                && !txn.isTransfer
                && txn.financeType == .business
        }

        // Group by resolved tax form line
        var lineGroups: [TaxFormLine: (gross: Double, deductible: Double, count: Int)] = [:]

        for txn in yearTransactions {
            guard let line = resolvedFormLine(for: txn, formType: formType) else { continue }

            let existing = lineGroups[line] ?? (0, 0, 0)
            let amount = txn.amount
            let deductionRate = line.defaultDeductionRate

            lineGroups[line] = (
                gross: existing.gross + amount,
                deductible: existing.deductible + (amount * deductionRate),
                count: existing.count + 1
            )
        }

        return lineGroups.map { line, totals in
            FormLineTotal(
                taxFormLine: line,
                grossAmount: totals.gross,
                deductibleAmount: totals.deductible,
                transactionCount: totals.count
            )
        }.sorted()
    }

    /// Resolves the correct tax form line for a transaction given its business context.
    func resolvedFormLine(for transaction: Transaction, formType: TaxFormType) -> TaxFormLine? {
        guard let category = transaction.category else { return nil }

        // Try the multi-form taxFormLine first
        if let taxLine = category.taxFormLine {
            if taxLine.formType == formType {
                return taxLine
            }
            // Cross-form translation via ScheduleCLine bridge
        }

        // Translate via effectiveTaxLine
        let businessType = businessTypeFor(formType: formType)
        return category.effectiveTaxLine(for: businessType)
    }

    /// Computes partner K-1 allocations from form line totals.
    func partnerAllocations(
        business: BusinessProfile,
        formLineTotals: [FormLineTotal],
        year: Int
    ) -> [PartnerK1Summary] {
        let partners = business.sortedPartners
        guard !partners.isEmpty else { return [] }

        let totalIncome = formLineTotals
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.grossAmount }

        let totalDeductions = formLineTotals
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.deductibleAmount }

        let ordinaryIncome = totalIncome - totalDeductions

        // Add depreciation from assets
        let depreciationTotal = MACRSCalculationService.shared
            .totalDepreciationForYear(year, assets: business.activeAssets)

        let netOrdinaryIncome = ordinaryIncome - depreciationTotal

        return partners.map { partner in
            let sharePercent = netOrdinaryIncome >= 0
                ? partner.profitSharePercentage
                : partner.lossSharePercentage

            let allocatedIncome = netOrdinaryIncome * sharePercent
            let endingCapital = partner.endingCapitalBalance(allocatedIncome: allocatedIncome)
            let basis = partner.outsideBasis(allocatedIncome: allocatedIncome)
            let lossDeductible = allocatedIncome >= 0 || basis > 0

            let suspendedAmount: Double
            if allocatedIncome < 0 && !lossDeductible {
                suspendedAmount = abs(allocatedIncome)
            } else {
                suspendedAmount = 0
            }

            return PartnerK1Summary(
                partner: partner,
                ordinaryIncome: allocatedIncome,
                selfEmploymentEarnings: business.businessType.hasSelfEmploymentTax ? allocatedIncome : 0,
                capitalContributed: partner.capitalContributed,
                beginningCapital: partner.beginningCapitalBalance,
                endingCapital: endingCapital,
                outsideBasis: basis,
                lossDeductible: lossDeductible,
                suspendedLossAmount: suspendedAmount
            )
        }
    }

    /// Generates a complete business tax year summary.
    func generateBusinessSummary(
        business: BusinessProfile,
        transactions: [Transaction],
        year: Int
    ) -> BusinessTaxYearSummary {
        let formLineTotals = aggregateByFormLine(
            business: business,
            transactions: transactions,
            year: year
        )

        let totalIncome = formLineTotals
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.grossAmount }

        let totalDeductions = formLineTotals
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.deductibleAmount }

        let depreciationTotal = MACRSCalculationService.shared
            .totalDepreciationForYear(year, assets: business.activeAssets)

        let ordinaryIncome = totalIncome - totalDeductions - depreciationTotal

        let partnerSummaries = partnerAllocations(
            business: business,
            formLineTotals: formLineTotals,
            year: year
        )

        let activeCarryforwards = business.activeCarryforwards

        return BusinessTaxYearSummary(
            businessProfile: business,
            taxYear: year,
            formType: business.taxFormType,
            formLineTotals: formLineTotals,
            totalIncome: totalIncome,
            totalDeductions: totalDeductions,
            ordinaryIncome: ordinaryIncome,
            depreciationTotal: depreciationTotal,
            partnerSummaries: partnerSummaries,
            carryforwards: activeCarryforwards
        )
    }

    // MARK: - Private Helpers

    /// Reverse-maps a TaxFormType to BusinessType for effectiveTaxLine resolution.
    private func businessTypeFor(formType: TaxFormType) -> BusinessType {
        switch formType {
        case .scheduleC: return .soleProprietorship
        case .form1065:  return .llc
        case .scheduleF: return .farm
        case .scheduleE: return .rentalProperty
        }
    }
}

// MARK: - FormLineTotal Comparable

extension FormLineTotal: Comparable {
    static func < (lhs: FormLineTotal, rhs: FormLineTotal) -> Bool {
        lhs.taxFormLine < rhs.taxFormLine
    }
}
