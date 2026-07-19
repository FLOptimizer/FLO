//  EstimatedTaxAlertService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Safe harbor tracking and quarterly estimated tax alerts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Computes whether the user is on track for estimated tax payments,
//  checks safe harbor thresholds, and generates actionable alerts.
//

import Foundation
import SwiftData

// MARK: - Result Types

struct EstimatedTaxStatus: Identifiable {
    let id = UUID()
    let taxYear: Int
    let currentQuarter: Int
    let quarterlyStatuses: [QuarterlyStatus]
    let safeHarborStatus: SafeHarborStatus
    let projectedAnnualTax: Double
    let totalPaidYTD: Double
    let remainingDue: Double
    let alerts: [EstimatedTaxAlert]
}

struct QuarterlyStatus: Identifiable {
    let id = UUID()
    let quarter: Int
    let quarterLabel: String
    let dueDate: Date
    let amountDue: Double
    let amountPaid: Double
    let isPaid: Bool
    let isPastDue: Bool
    let daysUntilDue: Int?
}

struct SafeHarborStatus {
    let meetsCurrentYearHarbor: Bool  // Paid >= 90% of current year tax
    let meetsPriorYearHarbor: Bool    // Paid >= 100% (or 110%) of prior year tax
    let isSafe: Bool                  // Either harbor met
    let method: String                // Which harbor method applies
    let priorYearThreshold: Double    // 100% or 110% of prior year
    let currentYearThreshold: Double  // 90% of current year
}

struct EstimatedTaxAlert: Identifiable {
    let id = UUID()
    let alertType: AlertType
    let message: String
    let severity: BasisAlert.AlertSeverity
    let recommendation: String
    let quarterAffected: Int?

    enum AlertType: String {
        case underpayment     = "underpayment"
        case pastDue          = "pastDue"
        case upcomingDeadline = "upcomingDeadline"
        case safeHarborRisk   = "safeHarborRisk"
        case onTrack          = "onTrack"
        case overpayment      = "overpayment"
    }
}

// MARK: - Service

@MainActor
final class EstimatedTaxAlertService {
    static let shared = EstimatedTaxAlertService()

    private init() {}

    // MARK: - Public API

    /// Computes the full estimated tax status for a given year.
    func computeStatus(
        taxYear: Int,
        transactions: [Transaction],
        taxSettings: TaxSettings?,
        modelContext: ModelContext,
        referenceDate: Date = Date()
    ) -> EstimatedTaxStatus {
        let settings = taxSettings ?? TaxSettings()
        let calendar = Calendar.current
        let currentQuarter = TaxSettings.quarterNumber(for: referenceDate)
        let deadlines = TaxSettings.quarterlyDeadlines(for: taxYear)

        // Calculate projected annual tax
        let yearTransactions = transactions.filter { txn in
            let year = calendar.component(.year, from: txn.date)
            return year == taxYear && !txn.isTransfer
        }

        let projectedTax = calculateProjectedTax(
            transactions: yearTransactions,
            settings: settings,
            taxYear: taxYear,
            referenceDate: referenceDate
        )

        let quarterlyAmount = projectedTax / 4.0

        // Get payments made (from TransferService)
        let totalPaid = TransferService.shared.calculateYTDTaxPayments(
            context: modelContext,
            year: taxYear
        )

        // Build quarterly statuses
        let quarterLabels = ["Q1 (Jan–Mar)", "Q2 (Apr–May)", "Q3 (Jun–Aug)", "Q4 (Sep–Dec)"]
        var quarterlyStatuses: [QuarterlyStatus] = []

        for (index, deadline) in deadlines.enumerated() {
            let quarter = index + 1
            let paidForQuarter = totalPaid / Double(min(currentQuarter, 4))
            let isPastDue = deadline < referenceDate
            let days = isPastDue ? nil : calendar.dateComponents([.day], from: referenceDate, to: deadline).day

            quarterlyStatuses.append(QuarterlyStatus(
                quarter: quarter,
                quarterLabel: quarterLabels[index],
                dueDate: deadline,
                amountDue: quarterlyAmount,
                amountPaid: quarter <= currentQuarter ? paidForQuarter : 0,
                isPaid: quarter <= currentQuarter && paidForQuarter >= quarterlyAmount * 0.9,
                isPastDue: isPastDue && paidForQuarter < quarterlyAmount * 0.9,
                daysUntilDue: days
            ))
        }

        // Safe harbor check
        let priorYearLiability = settings.priorYearTaxLiability ?? 0
        let priorYearMultiplier = settings.isHighEarner ? 1.10 : 1.00
        let priorYearThreshold = priorYearLiability * priorYearMultiplier
        let currentYearThreshold = projectedTax * 0.90

        let meetsPrior = priorYearLiability > 0 && totalPaid >= priorYearThreshold
        let meetsCurrent = totalPaid >= currentYearThreshold

        let safeHarbor = SafeHarborStatus(
            meetsCurrentYearHarbor: meetsCurrent,
            meetsPriorYearHarbor: meetsPrior,
            isSafe: meetsCurrent || meetsPrior,
            method: meetsPrior ? "Prior Year (\(settings.isHighEarner ? "110%" : "100%"))" : "Current Year (90%)",
            priorYearThreshold: priorYearThreshold,
            currentYearThreshold: currentYearThreshold
        )

        // Generate alerts
        let alerts = generateAlerts(
            quarterlyStatuses: quarterlyStatuses,
            safeHarbor: safeHarbor,
            totalPaid: totalPaid,
            projectedTax: projectedTax,
            currentQuarter: currentQuarter,
            referenceDate: referenceDate
        )

        return EstimatedTaxStatus(
            taxYear: taxYear,
            currentQuarter: currentQuarter,
            quarterlyStatuses: quarterlyStatuses,
            safeHarborStatus: safeHarbor,
            projectedAnnualTax: projectedTax,
            totalPaidYTD: totalPaid,
            remainingDue: max(0, projectedTax - totalPaid),
            alerts: alerts
        )
    }

    // MARK: - Tax Projection

    private func calculateProjectedTax(
        transactions: [Transaction],
        settings: TaxSettings,
        taxYear: Int,
        referenceDate: Date
    ) -> Double {
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: referenceDate)

        // Calculate YTD income
        let seIncome = transactions
            .filter { $0.isIncome && $0.financeType == .business }
            .reduce(0) { $0 + $1.amount }

        let seExpenses = transactions
            .filter { !$0.isIncome && $0.financeType == .business }
            .reduce(0) { $0 + $1.amount }

        let ytdNetIncome = seIncome - seExpenses

        // Annualize based on months elapsed
        let monthsElapsed = max(1, Double(currentMonth))
        let annualizedIncome = ytdNetIncome * (12.0 / monthsElapsed)

        // Self-employment tax
        let seTaxableIncome = annualizedIncome * 0.9235 // 92.35% of net SE income
        let ssWageBase = TaxSettings.socialSecurityWageBase(for: taxYear)
        let ssTax = min(seTaxableIncome, ssWageBase) * 0.124
        let medicareTax = seTaxableIncome * 0.029
        let selfEmploymentTax = settings.includeSelfEmploymentTax ? (ssTax + medicareTax) : 0

        // Deduction for 1/2 SE tax
        let seDeduction = selfEmploymentTax / 2.0

        // AGI approximation
        let agi = annualizedIncome - seDeduction
        let standardDeduction = TaxSettings.standardDeduction(for: settings.filingStatus, year: taxYear)
        let taxableIncome = max(0, agi - standardDeduction)

        // Federal income tax
        let brackets = TaxSettings.federalTaxBrackets(for: settings.filingStatus, year: taxYear)
        var federalTax = 0.0
        var previousMax = 0.0
        for bracket in brackets {
            let taxableInBracket = min(taxableIncome, bracket.maxIncome) - previousMax
            if taxableInBracket > 0 {
                federalTax += taxableInBracket * bracket.rate
            }
            previousMax = bracket.maxIncome
            if taxableIncome <= bracket.maxIncome { break }
        }

        // State tax (simplified)
        let stateTax = taxableIncome * settings.effectiveStateRate

        return selfEmploymentTax + federalTax + stateTax
    }

    // MARK: - Alert Generation

    private func generateAlerts(
        quarterlyStatuses: [QuarterlyStatus],
        safeHarbor: SafeHarborStatus,
        totalPaid: Double,
        projectedTax: Double,
        currentQuarter: Int,
        referenceDate: Date
    ) -> [EstimatedTaxAlert] {
        var alerts: [EstimatedTaxAlert] = []

        // Past due quarters
        for qs in quarterlyStatuses where qs.isPastDue {
            alerts.append(EstimatedTaxAlert(
                alertType: .pastDue,
                message: "\(qs.quarterLabel) payment was due \(DateFormatter.mediumDate.string(from: qs.dueDate))",
                severity: .critical,
                recommendation: "Pay as soon as possible to minimize underpayment penalties.",
                quarterAffected: qs.quarter
            ))
        }

        // Upcoming deadline (within 30 days)
        for qs in quarterlyStatuses {
            if let days = qs.daysUntilDue, days > 0, days <= 30, !qs.isPaid {
                let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: qs.amountDue)) ?? "$0"
                alerts.append(EstimatedTaxAlert(
                    alertType: .upcomingDeadline,
                    message: "\(qs.quarterLabel) payment of \(formatted) due in \(days) days",
                    severity: days <= 7 ? .critical : .warning,
                    recommendation: "Schedule payment via IRS Direct Pay or EFTPS.",
                    quarterAffected: qs.quarter
                ))
            }
        }

        // Safe harbor risk
        if !safeHarbor.isSafe && projectedTax > 1000 {
            alerts.append(EstimatedTaxAlert(
                alertType: .safeHarborRisk,
                message: "Not meeting safe harbor — underpayment penalty risk",
                severity: .warning,
                recommendation: "Increase remaining quarterly payments to meet the \(safeHarbor.method) threshold.",
                quarterAffected: nil
            ))
        }

        // On track
        if safeHarbor.isSafe && alerts.isEmpty {
            alerts.append(EstimatedTaxAlert(
                alertType: .onTrack,
                message: "On track — safe harbor met via \(safeHarbor.method)",
                severity: .info,
                recommendation: "Continue current payment schedule.",
                quarterAffected: nil
            ))
        }

        // Overpayment
        if totalPaid > projectedTax && projectedTax > 0 {
            let overpayment = totalPaid - projectedTax
            let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: overpayment)) ?? "$0"
            alerts.append(EstimatedTaxAlert(
                alertType: .overpayment,
                message: "Overpaid by approximately \(formatted)",
                severity: .info,
                recommendation: "You may reduce remaining quarterly payments or receive a refund at filing.",
                quarterAffected: nil
            ))
        }

        return alerts.sorted { $0.severity < $1.severity }
    }
}
