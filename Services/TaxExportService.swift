//  TaxExportService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — CPA-facing tax data export (Lacerte CSV, generic CSV)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Exports tax line aggregation data in formats importable by tax prep software.
//  Phase 2 of tax prep roadmap — bridges FLO data to CPA workflows.
//

import Foundation
import SwiftData

// MARK: - Export Format

enum TaxExportFormat: String, CaseIterable {
    case lacerteCSV   = "lacerteCSV"
    case genericCSV   = "genericCSV"

    var displayName: String {
        switch self {
        case .lacerteCSV: return "Lacerte CSV"
        case .genericCSV: return "Generic CSV"
        }
    }

    var fileExtension: String { "csv" }

    var description: String {
        switch self {
        case .lacerteCSV: return "Intuit Lacerte tax software import format"
        case .genericCSV: return "Standard CSV for any tax preparer"
        }
    }

    var icon: String {
        switch self {
        case .lacerteCSV: return "doc.badge.arrow.up"
        case .genericCSV: return "tablecells"
        }
    }
}

// MARK: - Export Result

struct TaxExportResult {
    let format: TaxExportFormat
    let csvContent: String
    let filename: String
    let businessName: String
    let taxYear: Int
    let lineCount: Int
    let totalIncome: Double
    let totalDeductions: Double
}

// MARK: - Service

@MainActor
final class TaxExportService {
    static let shared = TaxExportService()

    private init() {}

    // MARK: - Public API

    /// Exports tax data for a single business in the specified format.
    func exportBusiness(
        business: BusinessProfile,
        transactions: [Transaction],
        taxYear: Int,
        format: TaxExportFormat
    ) -> TaxExportResult {
        let summary = TaxLineAggregationService.shared.generateBusinessSummary(
            business: business,
            transactions: transactions,
            year: taxYear
        )

        let csv: String
        switch format {
        case .lacerteCSV:
            csv = generateLacerteCSV(summary: summary)
        case .genericCSV:
            csv = generateGenericCSV(summary: summary)
        }

        let filename = "\(business.safeBusinessName)_\(taxYear)_\(format.rawValue).\(format.fileExtension)"

        return TaxExportResult(
            format: format,
            csvContent: csv,
            filename: filename,
            businessName: business.businessName,
            taxYear: taxYear,
            lineCount: summary.formLineTotals.count,
            totalIncome: summary.totalIncome,
            totalDeductions: summary.totalDeductions
        )
    }

    /// Exports tax data for all businesses into a single CSV.
    func exportAll(
        businesses: [BusinessProfile],
        transactions: [Transaction],
        taxYear: Int,
        format: TaxExportFormat
    ) -> TaxExportResult {
        let summaries = businesses.map { business in
            TaxLineAggregationService.shared.generateBusinessSummary(
                business: business,
                transactions: transactions,
                year: taxYear
            )
        }

        let csv: String
        switch format {
        case .lacerteCSV:
            csv = generateLacerteCSVMulti(summaries: summaries, taxYear: taxYear)
        case .genericCSV:
            csv = generateGenericCSVMulti(summaries: summaries, taxYear: taxYear)
        }

        let filename = "FLO_TaxExport_\(taxYear)_\(format.rawValue).\(format.fileExtension)"
        let totalIncome = summaries.reduce(0) { $0 + $1.totalIncome }
        let totalDeductions = summaries.reduce(0) { $0 + $1.totalDeductions }
        let lineCount = summaries.reduce(0) { $0 + $1.formLineTotals.count }

        return TaxExportResult(
            format: format,
            csvContent: csv,
            filename: filename,
            businessName: "All Entities",
            taxYear: taxYear,
            lineCount: lineCount,
            totalIncome: totalIncome,
            totalDeductions: totalDeductions
        )
    }

    /// Saves export result to a temporary file and returns the URL.
    func saveToFile(_ result: TaxExportResult) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(result.filename)

        do {
            try result.csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("TaxExportService: Failed to save export — \(error)")
            return nil
        }
    }

    // MARK: - Lacerte CSV Format

    /// Lacerte CSV uses a specific column structure for import:
    /// Form, Line, Description, Amount
    /// The form/line identifiers map to Lacerte's internal codes.
    private func generateLacerteCSV(summary: BusinessTaxYearSummary) -> String {
        var lines: [String] = []

        // Header comment
        lines.append("# FLO Tax Export — Lacerte CSV Format")
        lines.append("# Entity: \(escapeCSV(summary.businessProfile.businessName))")
        lines.append("# Tax Year: \(summary.taxYear)")
        lines.append("# Form Type: \(summary.formType.displayName)")
        lines.append("# Generated: \(DateFormatter.mediumDate.string(from: Date()))")
        lines.append("#")

        // Column headers
        lines.append("Form,Line Number,IRS Description,Gross Amount,Deductible Amount,Transaction Count")

        // Income lines
        let incomeLines = summary.formLineTotals.filter { $0.isIncome }.sorted()
        if !incomeLines.isEmpty {
            for line in incomeLines {
                lines.append(formatLacerteLine(line, formName: summary.formType.displayName))
            }
        }

        // Expense/deduction lines
        let expenseLines = summary.formLineTotals.filter { !$0.isIncome }.sorted()
        if !expenseLines.isEmpty {
            for line in expenseLines {
                lines.append(formatLacerteLine(line, formName: summary.formType.displayName))
            }
        }

        // Depreciation total
        if summary.depreciationTotal > 0 {
            let depLine = lacerteDepreciationLine(summary: summary)
            lines.append(depLine)
        }

        // Summary row
        lines.append("")
        lines.append("# Summary")
        lines.append("# Total Income: \(formatAmount(summary.totalIncome))")
        lines.append("# Total Deductions: \(formatAmount(summary.totalDeductions))")
        lines.append("# Depreciation: \(formatAmount(summary.depreciationTotal))")
        lines.append("# Ordinary Income: \(formatAmount(summary.ordinaryIncome))")

        // K-1 allocations for partnerships
        if !summary.partnerSummaries.isEmpty {
            lines.append("")
            lines.append("# Partner K-1 Allocations")
            lines.append("Partner Name,Ownership %,Ordinary Income,SE Earnings,Beginning Capital,Ending Capital,Outside Basis,Losses Suspended")

            for k1 in summary.partnerSummaries {
                lines.append(formatK1Line(k1))
            }
        }

        return lines.joined(separator: "\n")
    }

    private func generateLacerteCSVMulti(summaries: [BusinessTaxYearSummary], taxYear: Int) -> String {
        var lines: [String] = []

        lines.append("# FLO Tax Export — Lacerte CSV Format (Multi-Entity)")
        lines.append("# Tax Year: \(taxYear)")
        lines.append("# Entities: \(summaries.count)")
        lines.append("# Generated: \(DateFormatter.mediumDate.string(from: Date()))")
        lines.append("#")

        // Column headers
        lines.append("Entity,Form,Line Number,IRS Description,Gross Amount,Deductible Amount,Transaction Count")

        for summary in summaries {
            lines.append("")
            lines.append("# --- \(escapeCSV(summary.businessProfile.businessName)) (\(summary.formType.displayName)) ---")

            for line in summary.formLineTotals.sorted() {
                let entityCol = escapeCSV(summary.businessProfile.businessName)
                let formCol = escapeCSV(summary.formType.displayName)
                lines.append("\(entityCol),\(formCol),\(escapeCSV(line.taxFormLine.lineNumber)),\(escapeCSV(line.taxFormLine.irsDescription)),\(formatAmount(line.grossAmount)),\(formatAmount(line.deductibleAmount)),\(line.transactionCount)")
            }

            if summary.depreciationTotal > 0 {
                let entityCol = escapeCSV(summary.businessProfile.businessName)
                let formCol = escapeCSV(summary.formType.displayName)
                lines.append("\(entityCol),\(formCol),Depreciation,MACRS/§179 Depreciation,\(formatAmount(summary.depreciationTotal)),\(formatAmount(summary.depreciationTotal)),0")
            }
        }

        // Combined K-1s
        let allK1s = summaries.flatMap { s in
            s.partnerSummaries.map { (s.businessProfile.businessName, $0) }
        }

        if !allK1s.isEmpty {
            lines.append("")
            lines.append("# Partner K-1 Allocations")
            lines.append("Entity,Partner Name,Ownership %,Ordinary Income,SE Earnings,Beginning Capital,Ending Capital,Outside Basis,Losses Suspended")

            for (entityName, k1) in allK1s {
                lines.append("\(escapeCSV(entityName)),\(formatK1Line(k1))")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Generic CSV Format

    private func generateGenericCSV(summary: BusinessTaxYearSummary) -> String {
        var lines: [String] = []

        lines.append("Form,Line Number,Description,Type,Gross Amount,Deductible Amount,Transactions")

        for line in summary.formLineTotals.sorted() {
            let type = line.isIncome ? "Income" : "Expense"
            lines.append("\(escapeCSV(summary.formType.displayName)),\(escapeCSV(line.taxFormLine.lineNumber)),\(escapeCSV(line.taxFormLine.irsDescription)),\(type),\(formatAmount(line.grossAmount)),\(formatAmount(line.deductibleAmount)),\(line.transactionCount)")
        }

        if summary.depreciationTotal > 0 {
            lines.append("\(escapeCSV(summary.formType.displayName)),Depreciation,MACRS/§179 Depreciation,Expense,\(formatAmount(summary.depreciationTotal)),\(formatAmount(summary.depreciationTotal)),0")
        }

        return lines.joined(separator: "\n")
    }

    private func generateGenericCSVMulti(summaries: [BusinessTaxYearSummary], taxYear: Int) -> String {
        var lines: [String] = []

        lines.append("Entity,Form,Line Number,Description,Type,Gross Amount,Deductible Amount,Transactions")

        for summary in summaries {
            for line in summary.formLineTotals.sorted() {
                let type = line.isIncome ? "Income" : "Expense"
                lines.append("\(escapeCSV(summary.businessProfile.businessName)),\(escapeCSV(summary.formType.displayName)),\(escapeCSV(line.taxFormLine.lineNumber)),\(escapeCSV(line.taxFormLine.irsDescription)),\(type),\(formatAmount(line.grossAmount)),\(formatAmount(line.deductibleAmount)),\(line.transactionCount)")
            }

            if summary.depreciationTotal > 0 {
                lines.append("\(escapeCSV(summary.businessProfile.businessName)),\(escapeCSV(summary.formType.displayName)),Depreciation,MACRS/§179 Depreciation,Expense,\(formatAmount(summary.depreciationTotal)),\(formatAmount(summary.depreciationTotal)),0")
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Formatting Helpers

    private func formatLacerteLine(_ line: FormLineTotal, formName: String) -> String {
        "\(escapeCSV(formName)),\(escapeCSV(line.taxFormLine.lineNumber)),\(escapeCSV(line.taxFormLine.irsDescription)),\(formatAmount(line.grossAmount)),\(formatAmount(line.deductibleAmount)),\(line.transactionCount)"
    }

    private func lacerteDepreciationLine(summary: BusinessTaxYearSummary) -> String {
        "\(escapeCSV(summary.formType.displayName)),Depreciation,MACRS/§179 Depreciation,\(formatAmount(summary.depreciationTotal)),\(formatAmount(summary.depreciationTotal)),0"
    }

    private func formatK1Line(_ k1: PartnerK1Summary) -> String {
        let ownership = String(format: "%.1f%%", k1.partner.ownershipPercentage * 100)
        let suspended = k1.suspendedLossAmount > 0 ? formatAmount(k1.suspendedLossAmount) : "0.00"
        return "\(escapeCSV(k1.partner.partnerName)),\(ownership),\(formatAmount(k1.ordinaryIncome)),\(formatAmount(k1.selfEmploymentEarnings)),\(formatAmount(k1.beginningCapital)),\(formatAmount(k1.endingCapital)),\(formatAmount(k1.outsideBasis)),\(suspended)"
    }

    private func formatAmount(_ amount: Double) -> String {
        String(format: "%.2f", amount)
    }

    /// RFC 4180 CSV escaping
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
