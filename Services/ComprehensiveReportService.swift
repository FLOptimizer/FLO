//  ComprehensiveReportService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 — TaxTreatment-Aware Quarterly Tax Estimates
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Core service class: public API, summary calculations, and equity logic.
//  PDF drawing split into companion files for maintainability.
//
//  CHANGES v2.1 — TaxTreatment-Aware Quarterly Tax Estimates:
//  ✅ FIXED: calculateQuarterlyTaxes now segments income by TaxTreatment
//  ✅ FIXED: SE tax (15.3%) only applied to .selfEmployment + uncategorized income
//  ✅ FIXED: .taxExempt income (disability, VA, Pell Grant, etc.) excluded from ALL tax math
//  ✅ FIXED: .w2WithholdingPaid and .passiveIncome only incur income tax, not SE tax
//  ✅ BUG: Previous v2.0 applied flat 15.3% SE rate to ALL income — hugely inflated SE tax
//
//  CHANGES v2.0 — Modular Split + Transfer Appendix:
//  ✅ SPLIT: 2,086-line file into 5 focused files
//  ✅ ADDED: Transfer Appendix section for CPA reconciliation
//  ✅ ADDED: includeTransferAppendix config option
//  ✅ ADDED: transferTransactions passed to PDF generation
//  ✅ PRESERVED: All v1.5 functionality intact (Schedule C, equity, etc.)
//
//  COMPANION FILES:
//  • ComprehensiveReportModels.swift — data structs
//  • ComprehensiveReportService+PDFLayout.swift — PDF page orchestration
//  • ComprehensiveReportService+Sections.swift — individual section renderers
//  • ComprehensiveReportService+Helpers.swift — shared drawing utilities
//
//  PREVIOUS CHANGES:
//  v1.5: Schedule C line-by-line breakdown
//  v1.4: Live equity data from TransferService
//  v1.3: Owner's draws, contributions, tax payments section
//  v1.2: Transfers excluded from P&L
//  v1.1: TaxSettings, BusinessProfile, MainActor fixes
//

import Foundation
import SwiftData

// MARK: - Comprehensive Report Service

@MainActor
final class ComprehensiveReportService {
    
    static let shared = ComprehensiveReportService()
    static let version = "2.1"
    
    private init() {}
    
    // MARK: - Error Types
    
    enum ReportError: LocalizedError {
        case noData
        case pdfGenerationFailed
        case invalidDateRange
        
        var errorDescription: String? {
            switch self {
            case .noData: return "No data available for the selected period"
            case .pdfGenerationFailed: return "Failed to generate PDF report"
            case .invalidDateRange: return "Invalid date range specified"
            }
        }
    }
    
    // MARK: - Generate Comprehensive Report
    
    func generateComprehensiveReport(
        config: ReportConfiguration,
        transactions: [Transaction],
        mileageTrips: [MileageTrip],
        invoices: [Invoice],
        taxSettings: TaxSettings?,
        businessProfile: BusinessProfile?,
        context: ModelContext
    ) -> Result<Data, ReportError> {
        
        #if os(macOS)
        return .failure(.pdfGenerationFailed)
        #else
        
        // Filter data by date range, excluding transfers from financial calculations
        let filteredTransactions = transactions.filter {
            config.dateRange.contains($0.date) && !$0.isTransfer
        }
        let filteredMileage = mileageTrips.filter { config.dateRange.contains($0.startDate) }
        let filteredInvoices = invoices.filter { config.dateRange.contains($0.issueDate) }
        
        // v2.0: Collect transfer transactions separately for appendix
        let transferTransactions = config.includeTransferAppendix ? transactions.filter {
            config.dateRange.contains($0.date) && $0.isTransfer
        } : []
        
        // Calculate summaries
        let reportSummary = calculateReportSummary(transactions: filteredTransactions)
        let mileageSummary = config.includeMileage ? calculateMileageSummary(trips: filteredMileage) : nil
        let invoiceSummary = config.includeInvoices ? calculateInvoiceSummary(invoices: filteredInvoices) : nil
        let monthlyBreakdown = calculateMonthlyBreakdown(transactions: filteredTransactions, dateRange: config.dateRange)
        let quarterlyTaxes = config.includeTaxEstimates ? calculateQuarterlyTaxes(
            transactions: filteredTransactions,
            taxSettings: taxSettings,
            dateRange: config.dateRange
        ) : []
        
        // Calculate equity data (v1.4) — only if section is included
        let equityData: EquityData? = config.includeEquityTransfers ? calculateEquityData(
            context: context,
            dateRange: config.dateRange
        ) : nil
        
        // Generate PDF (defined in +PDFLayout extension)
        let pdfData = generatePDF(
            config: config,
            summary: reportSummary,
            mileage: mileageSummary,
            invoices: invoiceSummary,
            monthly: monthlyBreakdown,
            quarterlyTaxes: quarterlyTaxes,
            transactions: config.includeDetailedTransactions ? filteredTransactions : [],
            transferTransactions: transferTransactions,
            mileageTrips: config.includeMileage ? filteredMileage : [],
            businessProfile: businessProfile,
            equityData: equityData
        )
        
        if let data = pdfData {
            return .success(data)
        } else {
            return .failure(.pdfGenerationFailed)
        }
        
        #endif
    }
    
    // MARK: - Summary Calculations
    
    func calculateReportSummary(transactions: [Transaction]) -> ReportSummary {
        let income = transactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expenses = transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let businessExp = transactions.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }
        let personalExp = transactions.filter { !$0.isIncome && $0.financeType == .personal }.reduce(0) { $0 + $1.amount }
        let taxDeductible = transactions.filter { !$0.isIncome && $0.category?.isTaxDeductible == true }.reduce(0) { $0 + $1.amount }
        
        // Category breakdown
        let expenseTransactions = transactions.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenseTransactions) { $0.category?.name ?? "Uncategorized" }
        let breakdown = grouped.map { (category: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }, percentage: 0.0) }
            .sorted { $0.amount > $1.amount }
            .map { (category: $0.category, amount: $0.amount, percentage: expenses > 0 ? ($0.amount / expenses) * 100 : 0) }
        
        // v1.5 — Schedule C line-by-line breakdown
        let deductibleTransactions = transactions.filter { !$0.isIncome && $0.category?.isTaxDeductible == true }
        
        let lineGrouped = Dictionary(grouping: deductibleTransactions) { transaction -> String in
            transaction.category?.scheduleCLineRaw ?? "__unassigned__"
        }
        
        var scheduleCLines: [(lineLabel: String, lineNumber: String, categories: [String], grossAmount: Double, deductibleAmount: Double)] = []
        
        for (lineRaw, lineTransactions) in lineGrouped {
            let grossAmount = lineTransactions.reduce(0) { $0 + $1.amount }
            let categoryNames = Array(Set(lineTransactions.compactMap { $0.category?.name })).sorted()
            
            if lineRaw == "__unassigned__" {
                scheduleCLines.append((
                    lineLabel: "Other (Unassigned)",
                    lineNumber: "—",
                    categories: categoryNames,
                    grossAmount: grossAmount,
                    deductibleAmount: grossAmount
                ))
            } else if let line = ScheduleCLine(rawValue: lineRaw) {
                let deductibleAmount = grossAmount * line.defaultDeductionRate
                scheduleCLines.append((
                    lineLabel: line.irsDescription,
                    lineNumber: line.lineNumber,
                    categories: categoryNames,
                    grossAmount: grossAmount,
                    deductibleAmount: deductibleAmount
                ))
            }
        }
        
        scheduleCLines.sort { a, b in
            if a.lineNumber == "—" { return false }
            if b.lineNumber == "—" { return true }
            let numA = Self.lineNumberSortKey(a.lineNumber)
            let numB = Self.lineNumberSortKey(b.lineNumber)
            return numA < numB
        }
        
        return ReportSummary(
            totalIncome: income,
            totalExpenses: expenses,
            businessExpenses: businessExp,
            personalExpenses: personalExp,
            taxDeductibleExpenses: taxDeductible,
            netIncome: income - expenses,
            transactionCount: transactions.count,
            categoryBreakdown: breakdown,
            topExpenseCategories: Array(breakdown.prefix(5)).map { ($0.category, $0.amount) },
            scheduleCBreakdown: scheduleCLines
        )
    }
    
    /// Converts "Line 8" -> 8.0, "Line 24a" -> 24.1, "Line 24b" -> 24.2 for sorting.
    private static func lineNumberSortKey(_ lineNumber: String) -> Double {
        let cleaned = lineNumber
            .replacingOccurrences(of: "Line ", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        if let last = cleaned.last, last.isLetter {
            let numPart = String(cleaned.dropLast())
            let letterOffset = Double(last.asciiValue ?? 97) - 96.0
            return (Double(numPart) ?? 0) + (letterOffset * 0.1)
        }
        return Double(cleaned) ?? 999
    }
    
    private func calculateMileageSummary(trips: [MileageTrip]) -> MileageSummary {
        let businessTrips = trips.filter { $0.isBusinessTrip && $0.purpose != .needsReview }
        let personalTrips = trips.filter { !$0.isBusinessTrip || $0.purpose == .personal }
        
        let totalMiles = trips.reduce(0) { $0 + $1.distanceMiles }
        let businessMiles = businessTrips.reduce(0) { $0 + $1.distanceMiles }
        let personalMiles = personalTrips.reduce(0) { $0 + $1.distanceMiles }
        let totalDeduction = businessTrips.reduce(0) { $0 + $1.deductionAmount }
        
        let avgRate = businessTrips.isEmpty ? 0.725 : businessTrips.reduce(0) { $0 + $1.mileageRate } / Double(businessTrips.count)
        
        let purposeGroups = Dictionary(grouping: businessTrips) { $0.purpose.displayName }
        let topPurposes = purposeGroups.map { purpose, trips in
            (purpose: purpose, miles: trips.reduce(0) { $0 + $1.distanceMiles }, deduction: trips.reduce(0) { $0 + $1.deductionAmount })
        }.sorted { $0.miles > $1.miles }
        
        return MileageSummary(
            totalMiles: totalMiles,
            businessMiles: businessMiles,
            personalMiles: personalMiles,
            totalDeduction: totalDeduction,
            tripCount: trips.count,
            averageRate: avgRate,
            topPurposes: Array(topPurposes.prefix(5))
        )
    }
    
    private func calculateInvoiceSummary(invoices: [Invoice]) -> InvoiceSummary {
        let totalInvoiced = invoices.reduce(0) { $0 + $1.totalAmount }
        let paidInvoices = invoices.filter { $0.status == .paid }
        let totalPaid = paidInvoices.reduce(0) { $0 + $1.totalAmount }
        let outstanding = invoices.filter { $0.status != .paid && $0.status != .cancelled }
        let totalOutstanding = outstanding.reduce(0) { $0 + $1.remainingBalance }
        let overdue = invoices.filter { $0.isOverdue }
        let overdueAmount = overdue.reduce(0) { $0 + $1.remainingBalance }
        
        let paidWithDates = paidInvoices.compactMap { invoice -> Int? in
            guard let paidDate = invoice.paidDate else { return nil }
            return Calendar.current.dateComponents([.day], from: invoice.issueDate, to: paidDate).day
        }
        let avgDays = paidWithDates.isEmpty ? nil : Double(paidWithDates.reduce(0, +)) / Double(paidWithDates.count)
        
        return InvoiceSummary(
            totalInvoiced: totalInvoiced,
            totalPaid: totalPaid,
            totalOutstanding: totalOutstanding,
            overdueAmount: overdueAmount,
            invoiceCount: invoices.count,
            paidCount: paidInvoices.count,
            overdueCount: overdue.count,
            averageDaysToPayment: avgDays
        )
    }
    
    private func calculateMonthlyBreakdown(transactions: [Transaction], dateRange: ClosedRange<Date>) -> [MonthlyBreakdown] {
        let calendar = Calendar.current
        var result: [MonthlyBreakdown] = []
        
        var currentDate = dateRange.lowerBound
        let formatter = DateFormatter.shortMonthYear
        
        while currentDate <= dateRange.upperBound {
            let monthTransactions = transactions.filter {
                calendar.isDate($0.date, equalTo: currentDate, toGranularity: .month)
            }
            
            let income = monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let expenses = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            let businessExp = monthTransactions.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }
            
            result.append(MonthlyBreakdown(
                month: currentDate,
                monthLabel: formatter.string(from: currentDate),
                income: income,
                expenses: expenses,
                businessExpenses: businessExp,
                netCashFlow: income - expenses
            ))
            
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
            currentDate = nextMonth
        }
        
        return result
    }
    
    /// v2.1: Fixed — now segments income by `TaxTreatment` (mirrors TaxCalculationService).
    ///
    /// Previously applied a flat 15.3% SE rate to ALL income, which drastically
    /// over-stated SE tax for users with tax-exempt or passive income (disability,
    /// military retirement, Pell Grant, etc.).
    ///
    /// Now:
    ///   • Only `.selfEmployment` (and uncategorized) income incurs SE tax (15.3%)
    ///   • `.w2WithholdingPaid` income incurs federal income tax but NOT SE tax
    ///   • `.passiveIncome` incurs federal income tax but NOT SE tax
    ///   • `.taxExempt` income is excluded from ALL tax calculations
    func calculateQuarterlyTaxes(
        transactions: [Transaction],
        taxSettings: TaxSettings?,
        dateRange: ClosedRange<Date>
    ) -> [QuarterlyTaxSummary] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: dateRange.lowerBound)
        var results: [QuarterlyTaxSummary] = []

        let selfEmploymentRate = 0.153
        let effectiveIncomeTaxRate = taxSettings?.customFederalRate ?? 0.22

        for quarter in 1...4 {
            let startMonth = (quarter - 1) * 3 + 1
            let endMonth = startMonth + 2

            guard let quarterStart = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)),
                  let quarterEnd = calendar.date(from: DateComponents(year: year, month: endMonth + 1, day: 0)) else {
                continue
            }

            let quarterTransactions = transactions.filter {
                $0.date >= quarterStart && $0.date <= quarterEnd
            }

            let incomeTransactions = quarterTransactions.filter(\.isIncome)
            let businessExpenses = quarterTransactions.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }

            // ── Segment income by TaxTreatment (mirrors TaxCalculationService) ──
            // Uncategorized income (category == nil) defaults to selfEmployment
            // to match TaxCalculationService behavior and avoid silent tax omission.
            let seIncome = incomeTransactions.filter {
                $0.category?.taxTreatment == .selfEmployment || $0.category == nil
            }.reduce(0) { $0 + $1.amount }

            let w2Income = incomeTransactions.filter {
                $0.category?.taxTreatment == .w2WithholdingPaid
            }.reduce(0) { $0 + $1.amount }

            let passiveIncome = incomeTransactions.filter {
                $0.category?.taxTreatment == .passiveIncome
            }.reduce(0) { $0 + $1.amount }

            // .taxExempt income is intentionally excluded from all calculations

            // SE tax only applies to self-employment income minus business expenses
            let netSEIncome = max(0, seIncome - businessExpenses)
            let seTax = max(0, netSEIncome * selfEmploymentRate)

            // Federal income tax applies to SE + W-2 + passive (NOT tax-exempt)
            let taxableIncome = netSEIncome + w2Income + passiveIncome
            let incomeTax = max(0, taxableIncome * effectiveIncomeTaxRate)

            // Estimated income for report display = all non-exempt income minus expenses
            let estimatedIncome = taxableIncome

            let dueDates: [Int: (month: Int, day: Int)] = [
                1: (4, 15), 2: (6, 15), 3: (9, 15), 4: (1, 15)
            ]

            let dueYear = quarter == 4 ? year + 1 : year
            let dueComponents = dueDates[quarter]!
            let dueDate = calendar.date(from: DateComponents(year: dueYear, month: dueComponents.month, day: dueComponents.day)) ?? Date()

            results.append(QuarterlyTaxSummary(
                quarter: quarter,
                year: year,
                estimatedIncome: estimatedIncome,
                estimatedSelfEmploymentTax: seTax,
                estimatedIncomeTax: incomeTax,
                totalEstimatedTax: seTax + incomeTax,
                dueDate: dueDate,
                isPastDue: Date() > dueDate
            ))
        }

        return results
    }
    
    // MARK: - Equity Calculation (v1.4)
    
    @MainActor
    private func calculateEquityData(
        context: ModelContext,
        dateRange: ClosedRange<Date>
    ) -> EquityData {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: dateRange.lowerBound)
        
        let ytdDraws = TransferService.shared.calculateYTDDraws(context: context, year: year)
        let ytdContributions = TransferService.shared.calculateYTDContributions(context: context, year: year)
        let ytdTaxPaymentsFederal = TransferService.shared.calculateYTDTaxPayments(context: context, authority: .federalIRS, year: year)
        let ytdTaxPaymentsState = TransferService.shared.calculateYTDTaxPayments(context: context, authority: .state, year: year)
        
        return EquityData(
            ytdDraws: ytdDraws,
            ytdContributions: ytdContributions,
            ytdTaxPaymentsFederal: ytdTaxPaymentsFederal,
            ytdTaxPaymentsState: ytdTaxPaymentsState
        )
    }
    
    // MARK: - Save to File
    
    func saveReportToTemporaryFile(data: Data, filename: String) -> Result<URL, ReportError> {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).pdf")
        
        do {
            try data.write(to: fileURL)
            return .success(fileURL)
        } catch {
            return .failure(.pdfGenerationFailed)
        }
    }
}
