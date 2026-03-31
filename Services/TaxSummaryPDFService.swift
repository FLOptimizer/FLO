//  TaxSummaryPDFService.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — One-click 2025 Tax Summary PDF export.
//  Cross-platform CGContext rendering (works on macOS and iOS).
//  Generates a focused 5-page tax position summary for CPA or tax software use.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import SwiftData
import CoreGraphics
import CoreText

#if os(macOS)
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#else
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#endif

/// Generates a focused Tax Summary PDF using CGContext (cross-platform).
@MainActor
final class TaxSummaryPDFService {

    static let shared = TaxSummaryPDFService()

    // MARK: - Page Constants

    private let pageWidth: CGFloat = 612   // US Letter
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Fonts

    private var titleFont: PlatformFont { PlatformFont.systemFont(ofSize: 24, weight: .bold) }
    private var headerFont: PlatformFont { PlatformFont.systemFont(ofSize: 16, weight: .bold) }
    private var subheaderFont: PlatformFont { PlatformFont.systemFont(ofSize: 12, weight: .semibold) }
    private var bodyFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .regular) }
    private var bodyBoldFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .bold) }
    private var captionFont: PlatformFont { PlatformFont.systemFont(ofSize: 8, weight: .regular) }
    private var monoFont: PlatformFont { PlatformFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium) }

    // MARK: - Colors

    private var tealColor: PlatformColor { PlatformColor(red: 0.08, green: 0.72, blue: 0.65, alpha: 1.0) }
    private var greenColor: PlatformColor { PlatformColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0) }
    private var redColor: PlatformColor { PlatformColor(red: 0.9, green: 0.26, blue: 0.2, alpha: 1.0) }
    private var grayColor: PlatformColor { PlatformColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0) }
    private var lightGrayBg: PlatformColor { PlatformColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) }
    private var headerBg: PlatformColor { PlatformColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0) }

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Generate PDF

    /// Generates the Tax Summary PDF for the given year.
    /// Returns PDF data on success, nil on failure.
    func generateTaxSummaryPDF(year: Int, modelContext: ModelContext) -> Data? {
        // Fetch data
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return nil }

        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        let transactions = (try? modelContext.fetch(txDescriptor)) ?? []
        let nonTransfer = transactions.filter { !$0.isTransfer }

        let settingsDescriptor = FetchDescriptor<TaxSettings>()
        let taxSettings = (try? modelContext.fetch(settingsDescriptor))?.first

        let profileDescriptor = FetchDescriptor<BusinessProfile>()
        let profile = (try? modelContext.fetch(profileDescriptor))?.first

        let tripDescriptor = FetchDescriptor<MileageTrip>(
            predicate: #Predicate<MileageTrip> { $0.startDate >= yearStart && $0.startDate < yearEnd }
        )
        let trips = (try? modelContext.fetch(tripDescriptor)) ?? []

        // Calculate using existing services
        let reportService = ComprehensiveReportService.shared
        let summary = reportService.calculateReportSummary(transactions: nonTransfer)
        let quarterly = reportService.calculateQuarterlyTaxes(
            transactions: nonTransfer,
            taxSettings: taxSettings,
            dateRange: yearStart...calendar.date(byAdding: .day, value: -1, to: yearEnd)!
        )

        let totalMiles = trips.reduce(0) { $0 + $1.distanceMiles }
        let irsRate: Double = year >= 2026 ? 0.725 : 0.70
        let mileageDeduction = totalMiles * irsRate

        // Create PDF
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let pdfContext = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return nil }

        // Page 1: Cover + Annual Summary
        drawCoverPage(context: pdfContext, year: year, summary: summary,
                     taxSettings: taxSettings, profile: profile,
                     mileageDeduction: mileageDeduction, quarterly: quarterly)

        // Page 2: Schedule C
        drawScheduleCPage(context: pdfContext, year: year, summary: summary,
                         mileageDeduction: mileageDeduction)

        // Page 3: Quarterly Breakdown
        drawQuarterlyPage(context: pdfContext, year: year, quarterly: quarterly)

        // Page 4: Deduction Details
        drawDeductionPage(context: pdfContext, year: year, summary: summary,
                         totalMiles: totalMiles, irsRate: irsRate,
                         mileageDeduction: mileageDeduction, quarterly: quarterly)

        // Page 5: Disclaimer
        drawDisclaimerPage(context: pdfContext, year: year)

        pdfContext.closePDF()
        return pdfData as Data
    }

    // MARK: - Page Drawing

    private func beginPage(_ context: CGContext) {
        let mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pageInfo: [CFString: Any] = [kCGPDFContextMediaBox: mediaBox]
        context.beginPDFPage(pageInfo as CFDictionary)
        // Flip coordinates for top-left origin
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
    }

    private func endPage(_ context: CGContext, pageNumber: Int) {
        // Page footer
        let footer = "FLO Tax Summary • Page \(pageNumber)"
        let attrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: grayColor]
        let str = NSAttributedString(string: footer, attributes: attrs)
        str.draw(at: CGPoint(x: margin, y: pageHeight - 30))
        context.endPDFPage()
    }

    // MARK: - Page 1: Cover + Annual Summary

    private func drawCoverPage(context: CGContext, year: Int, summary: ReportSummary,
                               taxSettings: TaxSettings?, profile: BusinessProfile?,
                               mileageDeduction: Double, quarterly: [QuarterlyTaxSummary]) {
        beginPage(context)
        var y: CGFloat = margin

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: tealColor]
        NSAttributedString(string: "\(year) Tax Summary", attributes: titleAttrs).draw(at: CGPoint(x: margin, y: y))
        y += 35

        // Subtitle
        let subtitleAttrs: [NSAttributedString.Key: Any] = [.font: subheaderFont, .foregroundColor: grayColor]
        NSAttributedString(string: "Prepared by FLO — Finance Ledger Optimizer", attributes: subtitleAttrs).draw(at: CGPoint(x: margin, y: y))
        y += 18
        NSAttributedString(string: "Generated: \(DateFormatter.mediumDate.string(from: Date()))", attributes: subtitleAttrs).draw(at: CGPoint(x: margin, y: y))
        y += 30

        // Business info
        if let name = profile?.businessName, !name.isEmpty {
            let bizAttrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: PlatformColor.black]
            NSAttributedString(string: name, attributes: bizAttrs).draw(at: CGPoint(x: margin, y: y))
            y += 16
        }

        // Filing info
        let state = taxSettings?.state ?? "Not Set"
        let filing = taxSettings?.filingStatus.rawValue ?? "Not Set"
        drawMetricRow("State:", state, at: &y, context: context)
        drawMetricRow("Filing Status:", filing, at: &y, context: context)
        y += 10

        // Divider
        drawDivider(at: &y, context: context)

        // Annual Summary header
        drawSectionHeader("Annual Summary", at: &y, context: context)

        // Income
        drawMetricRow("Total Income:", fmtAmount(summary.totalIncome), at: &y, context: context, bold: true)

        // Expenses
        drawMetricRow("Total Business Expenses:", fmtAmount(summary.businessExpenses), at: &y, context: context)
        drawMetricRow("Total Personal Expenses:", fmtAmount(summary.personalExpenses), at: &y, context: context)
        drawMetricRow("Tax-Deductible Expenses:", fmtAmount(summary.taxDeductibleExpenses), at: &y, context: context)
        y += 5

        // Net
        let net = summary.totalIncome - summary.businessExpenses
        drawMetricRow("Net Self-Employment Income:", fmtAmount(net), at: &y, context: context, bold: true, color: net >= 0 ? greenColor : redColor)
        y += 10

        drawDivider(at: &y, context: context)

        // Tax Estimates
        drawSectionHeader("Estimated Tax Liability", at: &y, context: context)

        let totalSETax = quarterly.reduce(0) { $0 + $1.estimatedSelfEmploymentTax }
        let totalIncomeTax = quarterly.reduce(0) { $0 + $1.estimatedIncomeTax }
        let totalTax = quarterly.reduce(0) { $0 + $1.totalEstimatedTax }

        drawMetricRow("Self-Employment Tax (15.3%):", fmtAmount(totalSETax), at: &y, context: context)
        drawMetricRow("Estimated Income Tax:", fmtAmount(totalIncomeTax), at: &y, context: context)
        drawMetricRow("Total Estimated Tax:", fmtAmount(totalTax), at: &y, context: context, bold: true, color: redColor)
        y += 5
        drawMetricRow("Mileage Deduction:", fmtAmount(mileageDeduction), at: &y, context: context)
        drawMetricRow("Total Deductions:", fmtAmount(summary.taxDeductibleExpenses + mileageDeduction), at: &y, context: context, bold: true)

        endPage(context, pageNumber: 1)
    }

    // MARK: - Page 2: Schedule C

    private func drawScheduleCPage(context: CGContext, year: Int, summary: ReportSummary,
                                    mileageDeduction: Double) {
        beginPage(context)
        var y: CGFloat = margin

        drawSectionHeader("Schedule C Overview (\(year))", at: &y, context: context)
        y += 5

        // Gross Income
        drawMetricRow("Line 1 — Gross Income:", fmtAmount(summary.totalIncome), at: &y, context: context, bold: true)
        y += 10

        // Schedule C breakdown table
        if !summary.scheduleCBreakdown.isEmpty {
            // Table header
            drawTableHeader(["Schedule C Line", "Categories", "Deductible Amount"], at: &y, context: context, widths: [150, 220, 140])

            for line in summary.scheduleCBreakdown where line.deductibleAmount > 0 {
                let cats = line.categories.prefix(3).joined(separator: ", ")
                let truncated = line.categories.count > 3 ? cats + "..." : cats
                drawTableRow([line.lineLabel, truncated, fmtAmount(line.deductibleAmount)],
                           at: &y, context: context, widths: [150, 220, 140])
            }

            // Mileage line
            drawTableRow(["Line 9 — Car/Truck", "Business Mileage", fmtAmount(mileageDeduction)],
                        at: &y, context: context, widths: [150, 220, 140], highlight: true)
        }

        y += 15

        // Totals
        let totalExpenses = summary.businessExpenses + mileageDeduction
        let netProfit = summary.totalIncome - totalExpenses
        drawDivider(at: &y, context: context)
        drawMetricRow("Total Expenses:", fmtAmount(totalExpenses), at: &y, context: context, bold: true)
        drawMetricRow("Line 31 — Net Profit/Loss:", fmtAmount(netProfit), at: &y, context: context, bold: true, color: netProfit >= 0 ? greenColor : redColor)

        endPage(context, pageNumber: 2)
    }

    // MARK: - Page 3: Quarterly Breakdown

    private func drawQuarterlyPage(context: CGContext, year: Int, quarterly: [QuarterlyTaxSummary]) {
        beginPage(context)
        var y: CGFloat = margin

        drawSectionHeader("Quarterly Tax Breakdown (\(year))", at: &y, context: context)
        y += 5

        // Table header
        drawTableHeader(["Quarter", "Income", "SE Tax", "Income Tax", "Total", "Due Date"],
                       at: &y, context: context,
                       widths: [70, 90, 80, 80, 80, 110])

        for q in quarterly {
            let dueStr = DateFormatter.mediumDate.string(from: q.dueDate)
            let status = q.isPastDue ? " ⚠" : ""
            drawTableRow([
                "Q\(q.quarter)",
                fmtAmount(q.estimatedIncome),
                fmtAmount(q.estimatedSelfEmploymentTax),
                fmtAmount(q.estimatedIncomeTax),
                fmtAmount(q.totalEstimatedTax),
                dueStr + status
            ], at: &y, context: context, widths: [70, 90, 80, 80, 80, 110])
        }

        y += 5

        // Totals row
        let totInc = quarterly.reduce(0) { $0 + $1.estimatedIncome }
        let totSE = quarterly.reduce(0) { $0 + $1.estimatedSelfEmploymentTax }
        let totIT = quarterly.reduce(0) { $0 + $1.estimatedIncomeTax }
        let totTax = quarterly.reduce(0) { $0 + $1.totalEstimatedTax }
        drawTableRow([
            "TOTAL",
            fmtAmount(totInc),
            fmtAmount(totSE),
            fmtAmount(totIT),
            fmtAmount(totTax),
            ""
        ], at: &y, context: context, widths: [70, 90, 80, 80, 80, 110], highlight: true)

        y += 20

        // Quarterly payment note
        let noteAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: grayColor]
        let perQuarter = totTax / 4
        NSAttributedString(string: "Estimated quarterly payment: \(fmtAmount(perQuarter))", attributes: noteAttrs).draw(at: CGPoint(x: margin, y: y))

        endPage(context, pageNumber: 3)
    }

    // MARK: - Page 4: Deduction Details

    private func drawDeductionPage(context: CGContext, year: Int, summary: ReportSummary,
                                    totalMiles: Double, irsRate: Double,
                                    mileageDeduction: Double, quarterly: [QuarterlyTaxSummary]) {
        beginPage(context)
        var y: CGFloat = margin

        drawSectionHeader("Deduction Details (\(year))", at: &y, context: context)
        y += 5

        // Deductible categories
        let deductibleCats = summary.categoryBreakdown.filter { cat in
            summary.scheduleCBreakdown.contains { line in
                line.categories.contains(cat.category)
            }
        }

        if !deductibleCats.isEmpty {
            drawTableHeader(["Category", "Amount", "% of Total"], at: &y, context: context, widths: [250, 130, 130])
            for cat in deductibleCats {
                drawTableRow([cat.category, fmtAmount(cat.amount), String(format: "%.1f%%", cat.percentage)],
                           at: &y, context: context, widths: [250, 130, 130])
            }
        }
        y += 15

        // Mileage detail
        drawSectionHeader("Mileage Deduction", at: &y, context: context)
        drawMetricRow("Total Business Miles:", String(format: "%.1f miles", totalMiles), at: &y, context: context)
        drawMetricRow("IRS Standard Rate:", "$\(String(format: "%.3f", irsRate))/mile", at: &y, context: context)
        drawMetricRow("Mileage Deduction:", fmtAmount(mileageDeduction), at: &y, context: context, bold: true)
        y += 15

        // Effective Rates
        drawSectionHeader("Effective Tax Rates", at: &y, context: context)
        let totalTax = quarterly.reduce(0) { $0 + $1.totalEstimatedTax }
        let effectiveRate = summary.totalIncome > 0 ? (totalTax / summary.totalIncome) * 100 : 0
        let totalSETax = quarterly.reduce(0) { $0 + $1.estimatedSelfEmploymentTax }
        let seRate = summary.totalIncome > 0 ? (totalSETax / summary.totalIncome) * 100 : 0
        let totalIT = quarterly.reduce(0) { $0 + $1.estimatedIncomeTax }
        let itRate = summary.totalIncome > 0 ? (totalIT / summary.totalIncome) * 100 : 0

        drawMetricRow("SE Tax Rate:", String(format: "%.1f%%", seRate), at: &y, context: context)
        drawMetricRow("Income Tax Rate:", String(format: "%.1f%%", itRate), at: &y, context: context)
        drawMetricRow("Total Effective Rate:", String(format: "%.1f%%", effectiveRate), at: &y, context: context, bold: true)

        endPage(context, pageNumber: 4)
    }

    // MARK: - Page 5: Disclaimer

    private func drawDisclaimerPage(context: CGContext, year: Int) {
        beginPage(context)
        var y: CGFloat = margin

        drawSectionHeader("Important Disclaimers", at: &y, context: context)
        y += 10

        let disclaimerText = """
        This tax summary is generated from financial data entered into FLO (Finance Ledger Optimizer) \
        and is provided for informational purposes only.

        This document is NOT a substitute for professional tax advice. The calculations and estimates \
        contained herein are based on the data available in FLO and standard tax formulas. They may \
        not reflect your complete tax situation.

        LIMITATIONS:
        • Self-employment tax is estimated at 15.3% on 92.35% of net self-employment income
        • Federal income tax estimates use simplified brackets and may not account for all credits, \
        deductions, or special circumstances
        • State tax calculations are estimates and vary by jurisdiction
        • This summary does not include W-2 withholding, estimated tax payments already made, \
        or other tax credits
        • Mileage deductions use the IRS standard mileage rate and assume all tracked miles \
        qualify as business use

        RECOMMENDATIONS:
        • Consult a qualified CPA or tax professional before filing your tax return
        • Verify all income and expense amounts against your bank and financial records
        • Keep this summary and your FLO data as part of your tax documentation
        • Retain all receipts and supporting documents for at least 7 years

        Prepared by FLO — Finance Ledger Optimizer
        © \(year + 1) Finch & Poppy Co LLC. All rights reserved.
        """

        let attrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: PlatformColor.darkGray,
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.lineSpacing = 4
                return p
            }()
        ]

        let attrStr = NSAttributedString(string: disclaimerText, attributes: attrs)
        let textRect = CGRect(x: margin, y: y, width: contentWidth, height: pageHeight - y - 50)
        attrStr.draw(in: textRect)

        endPage(context, pageNumber: 5)
    }

    // MARK: - Drawing Helpers

    private func drawSectionHeader(_ title: String, at y: inout CGFloat, context: CGContext) {
        let attrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: tealColor]
        NSAttributedString(string: title, attributes: attrs).draw(at: CGPoint(x: margin, y: y))
        y += 22

        // Underline
        context.saveGState()
        context.setStrokeColor(tealColor.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        context.restoreGState()
        y += 8
    }

    private func drawMetricRow(_ label: String, _ value: String, at y: inout CGFloat, context: CGContext,
                               bold: Bool = false, color: PlatformColor? = nil) {
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: PlatformColor.darkGray]
        let valueFont = bold ? bodyBoldFont : monoFont
        let valueColor = color ?? PlatformColor.black
        let valueAttrs: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: valueColor]

        NSAttributedString(string: label, attributes: labelAttrs).draw(at: CGPoint(x: margin + 10, y: y))

        let valueStr = NSAttributedString(string: value, attributes: valueAttrs)
        let valueWidth = valueStr.size().width
        valueStr.draw(at: CGPoint(x: margin + contentWidth - valueWidth, y: y))

        y += 16
    }

    private func drawDivider(at y: inout CGFloat, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(PlatformColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        context.restoreGState()
        y += 10
    }

    private func drawTableHeader(_ columns: [String], at y: inout CGFloat, context: CGContext, widths: [CGFloat]) {
        // Background
        context.saveGState()
        context.setFillColor(headerBg.cgColor)
        context.fill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 18))
        context.restoreGState()

        let attrs: [NSAttributedString.Key: Any] = [.font: bodyBoldFont, .foregroundColor: PlatformColor.darkGray]
        var x = margin + 5
        for (i, col) in columns.enumerated() {
            NSAttributedString(string: col, attributes: attrs).draw(at: CGPoint(x: x, y: y))
            x += widths[i]
        }
        y += 20
    }

    private func drawTableRow(_ values: [String], at y: inout CGFloat, context: CGContext,
                              widths: [CGFloat], highlight: Bool = false) {
        if highlight {
            context.saveGState()
            context.setFillColor(lightGrayBg.cgColor)
            context.fill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 16))
            context.restoreGState()
        }

        let font = highlight ? bodyBoldFont : bodyFont
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: PlatformColor.black]
        var x = margin + 5
        for (i, val) in values.enumerated() {
            NSAttributedString(string: val, attributes: attrs).draw(at: CGPoint(x: x, y: y))
            x += widths[i]
        }
        y += 18
    }

    private func fmtAmount(_ amount: Double) -> String {
        fmt.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    // MARK: - Save to File

    /// Generates and saves the Tax Summary PDF, returning the file URL.
    func saveTaxSummaryToFile(year: Int, modelContext: ModelContext) -> URL? {
        guard let pdfData = generateTaxSummaryPDF(year: year, modelContext: modelContext) else { return nil }

        let fileName = "FLO_Tax_Summary_\(year).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            #if DEBUG
            print("❌ Failed to save Tax Summary PDF: \(error)")
            #endif
            return nil
        }
    }
}
