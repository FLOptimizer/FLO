//  TaxHandoffPDFService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Comprehensive tax handoff PDF for CPA/tax preparer
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Generates a multi-entity tax handoff document modeled after a professional
//  tax preparation package. Includes entity profiles, form-line income statements,
//  partner capital & basis worksheets, depreciation schedules, and carryforward items.
//
//  Cross-platform CGContext rendering (macOS + iOS).
//

import Foundation
import SwiftData
import CoreGraphics
import CoreText

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class TaxHandoffPDFService {

    static let shared = TaxHandoffPDFService()

    // MARK: - Page Constants

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - margin * 2 }
    private var maxY: CGFloat { pageHeight - margin - 20 } // Leave room for footer

    // MARK: - Fonts

    private var titleFont: PlatformFont { PlatformFont.systemFont(ofSize: 22, weight: .bold) }
    private var h1Font: PlatformFont { PlatformFont.systemFont(ofSize: 16, weight: .bold) }
    private var h2Font: PlatformFont { PlatformFont.systemFont(ofSize: 13, weight: .bold) }
    private var h3Font: PlatformFont { PlatformFont.systemFont(ofSize: 11, weight: .semibold) }
    private var bodyFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .regular) }
    private var bodyBoldFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .bold) }
    private var captionFont: PlatformFont { PlatformFont.systemFont(ofSize: 8, weight: .regular) }
    private var monoFont: PlatformFont { PlatformFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium) }
    private var monoBoldFont: PlatformFont { PlatformFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold) }

    // MARK: - Colors

    private var brandColor: PlatformColor { PlatformColor(red: 0.08, green: 0.72, blue: 0.65, alpha: 1.0) }
    private var darkText: PlatformColor { PlatformColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) }
    private var grayText: PlatformColor { PlatformColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) }
    private var greenColor: PlatformColor { PlatformColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1.0) }
    private var redColor: PlatformColor { PlatformColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1.0) }
    private var orangeColor: PlatformColor { PlatformColor(red: 0.9, green: 0.55, blue: 0.1, alpha: 1.0) }
    private var lightBg: PlatformColor { PlatformColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0) }
    private var headerBg: PlatformColor { PlatformColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0) }

    private let fmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    private let fmtDetailed: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 2
        return f
    }()

    private var pageNumber = 0

    // MARK: - Generate PDF

    func generateHandoffPDF(year: Int, modelContext: ModelContext) -> Data? {
        // Fetch all data
        let calendar = Calendar.current
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return nil }

        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart && $0.date < yearEnd },
            sortBy: [SortDescriptor(\Transaction.date)]
        )
        let allTransactions = (try? modelContext.fetch(txDescriptor)) ?? []

        let bizDescriptor = FetchDescriptor<BusinessProfile>(
            predicate: #Predicate<BusinessProfile> { $0.isActive },
            sortBy: [SortDescriptor(\BusinessProfile.sortOrder)]
        )
        let businesses = (try? modelContext.fetch(bizDescriptor)) ?? []

        let settingsDescriptor = FetchDescriptor<TaxSettings>()
        let taxSettings = (try? modelContext.fetch(settingsDescriptor))?.first

        // Build summaries
        let aggregationService = TaxLineAggregationService.shared
        let businessSummaries = businesses.map { biz in
            aggregationService.generateBusinessSummary(
                business: biz,
                transactions: allTransactions,
                year: year
            )
        }

        // Create PDF
        pageNumber = 0
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return nil }

        // Page 1: Cover
        drawCoverPage(ctx: ctx, year: year, businesses: businesses, taxSettings: taxSettings)

        // Pages 2+: Entity profiles + income statements
        for summary in businessSummaries {
            drawEntityPage(ctx: ctx, summary: summary, year: year)
        }

        // Partner Capital & Basis pages (for partnerships)
        for summary in businessSummaries where !summary.partnerSummaries.isEmpty {
            drawPartnerBasisPage(ctx: ctx, summary: summary, year: year)
        }

        // Depreciation schedules
        let allAssets = businesses.flatMap { $0.activeAssets }
        if !allAssets.isEmpty {
            drawDepreciationPage(ctx: ctx, businesses: businesses, year: year)
        }

        // Carryforward items
        let allCarryforwards = businesses.flatMap { $0.activeCarryforwards }
        if !allCarryforwards.isEmpty {
            drawCarryforwardPage(ctx: ctx, businesses: businesses)
        }

        // Disclaimer
        drawDisclaimerPage(ctx: ctx, year: year)

        ctx.closePDF()
        return pdfData as Data
    }

    // MARK: - Page Helpers

    private func beginPage(_ ctx: CGContext) -> CGFloat {
        pageNumber += 1
        let mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        ctx.beginPDFPage([kCGPDFContextMediaBox: mediaBox] as CFDictionary)
        ctx.translateBy(x: 0, y: pageHeight)
        ctx.scaleBy(x: 1, y: -1)
        return margin
    }

    private func endPage(_ ctx: CGContext) {
        let footer = "FLO Tax Handoff — Page \(pageNumber)"
        draw(footer, at: CGPoint(x: margin, y: pageHeight - 30), font: captionFont, color: grayText)
        ctx.endPDFPage()
    }

    private func checkPageBreak(_ ctx: CGContext, y: inout CGFloat, needed: CGFloat = 60) {
        if y + needed > maxY {
            endPage(ctx)
            y = beginPage(ctx)
        }
    }

    // MARK: - Drawing Helpers

    private func draw(_ text: String, at point: CGPoint, font: PlatformFont, color: PlatformColor = PlatformColor.black) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        NSAttributedString(string: text, attributes: attrs).draw(at: point)
    }

    private func drawLine(_ ctx: CGContext, from: CGPoint, to: CGPoint, color: PlatformColor = PlatformColor.gray, width: CGFloat = 0.5) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.move(to: from)
        ctx.addLine(to: to)
        ctx.strokePath()
    }

    private func drawKeyValueRow(label: String, value: String, y: CGFloat, bold: Bool = false) {
        let labelFont = bold ? bodyBoldFont : bodyFont
        let valueFont = bold ? bodyBoldFont : bodyFont
        draw(label, at: CGPoint(x: margin, y: y), font: labelFont, color: darkText)
        // Right-align value
        let valueSize = (value as NSString).size(withAttributes: [.font: valueFont])
        draw(value, at: CGPoint(x: margin + contentWidth - valueSize.width, y: y), font: valueFont, color: darkText)
    }

    private func drawTableRow(cols: [(String, CGFloat)], y: CGFloat, font: PlatformFont, color: PlatformColor = PlatformColor.black, rightAlignLast: Bool = true) {
        var x = margin
        for (index, (text, width)) in cols.enumerated() {
            if rightAlignLast && index == cols.count - 1 {
                let size = (text as NSString).size(withAttributes: [.font: font])
                draw(text, at: CGPoint(x: x + width - size.width, y: y), font: font, color: color)
            } else {
                draw(text, at: CGPoint(x: x, y: y), font: font, color: color)
            }
            x += width
        }
    }

    private func drawSectionHeader(_ title: String, ctx: CGContext, y: inout CGFloat) {
        checkPageBreak(ctx, y: &y, needed: 30)
        // Background bar
        ctx.setFillColor(headerBg.cgColor)
        ctx.fill(CGRect(x: margin, y: y - 2, width: contentWidth, height: 18))
        draw(title, at: CGPoint(x: margin + 6, y: y), font: h2Font, color: darkText)
        y += 24
    }

    // MARK: - Page 1: Cover

    private func drawCoverPage(ctx: CGContext, year: Int, businesses: [BusinessProfile], taxSettings: TaxSettings?) {
        var y = beginPage(ctx)

        // Title
        draw("\(year) TAX YEAR", at: CGPoint(x: margin, y: y), font: titleFont, color: brandColor)
        y += 30
        draw("COMPLETE HANDOFF", at: CGPoint(x: margin, y: y), font: h1Font, color: darkText)
        y += 24

        draw("Prepared by FLO — Finance Ledger Optimizer", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 14
        draw("Generated: \(DateFormatter.mediumDate.string(from: Date()))", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 30

        // Filing info
        drawSectionHeader("Household Overview", ctx: ctx, y: &y)

        if let settings = taxSettings {
            drawKeyValueRow(label: "Filing Status", value: settings.filingStatus.rawValue, y: y)
            y += 16
            drawKeyValueRow(label: "State", value: settings.state, y: y)
            y += 16
        }

        y += 10

        // Entity list
        drawSectionHeader("Business Entities", ctx: ctx, y: &y)

        for business in businesses {
            checkPageBreak(ctx, y: &y, needed: 80)
            draw(business.businessName, at: CGPoint(x: margin, y: y), font: bodyBoldFont, color: darkText)
            y += 14
            draw("\(business.businessType.displayName) — \(business.businessType.taxFormName)", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
            y += 14
            if let ein = business.taxId, !ein.isEmpty {
                draw("EIN: \(ein)", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
                y += 14
            }
            if let naics = business.naicsCode, !naics.isEmpty {
                draw("NAICS: \(naics)", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
                y += 14
            }
            draw("Accounting: \(business.accountingMethod.displayName)", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
            y += 14
            if let date = business.formationDate {
                draw("Organized: \(DateFormatter.mediumDate.string(from: date))", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
                y += 14
            }
            // Members
            let partners = business.sortedPartners
            if !partners.isEmpty {
                let memberStr = partners.map { "\($0.partnerName) \($0.ownershipDisplay)" }.joined(separator: " / ")
                draw("Members: \(memberStr)", at: CGPoint(x: margin + 10, y: y), font: bodyFont, color: grayText)
                y += 14
            }
            y += 8
        }

        endPage(ctx)
    }

    // MARK: - Entity Income Statement Page

    private func drawEntityPage(ctx: CGContext, summary: BusinessTaxYearSummary, year: Int) {
        var y = beginPage(ctx)

        let business = summary.businessProfile
        draw("\(business.businessName) — \(String(year))", at: CGPoint(x: margin, y: y), font: h1Font, color: brandColor)
        y += 20
        draw("\(summary.formType.displayName): \(summary.formType.formTitle)", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 24

        // Income lines
        let incomeLines = summary.formLineTotals.filter { $0.isIncome }
        let expenseLines = summary.formLineTotals.filter { !$0.isIncome }

        drawSectionHeader("Income", ctx: ctx, y: &y)

        let colWidths: [(String, CGFloat)] = [("", 60), ("", contentWidth - 60 - 100), ("", 100)]
        // Table header
        drawTableRow(cols: [("Line", 60), ("Description", contentWidth - 60 - 100), ("Amount", 100)],
                     y: y, font: h3Font, color: darkText)
        y += 16

        for lineTotal in incomeLines {
            checkPageBreak(ctx, y: &y)
            let amountStr = fmt.string(from: NSNumber(value: lineTotal.grossAmount)) ?? "$0"
            drawTableRow(cols: [(lineTotal.taxFormLine.lineNumber, 60),
                               (lineTotal.taxFormLine.irsDescription, contentWidth - 60 - 100),
                               (amountStr, 100)],
                         y: y, font: bodyFont, color: darkText)
            y += 14
        }

        if incomeLines.isEmpty {
            draw("No income recorded", at: CGPoint(x: margin + 60, y: y), font: bodyFont, color: grayText)
            y += 14
        }

        let totalIncomeStr = fmt.string(from: NSNumber(value: summary.totalIncome)) ?? "$0"
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y))
        y += 4
        drawKeyValueRow(label: "Total Income", value: totalIncomeStr, y: y, bold: true)
        y += 20

        // Deductions
        drawSectionHeader("Deductions", ctx: ctx, y: &y)

        drawTableRow(cols: [("Line", 60), ("Description", contentWidth - 60 - 100), ("Amount", 100)],
                     y: y, font: h3Font, color: darkText)
        y += 16

        for lineTotal in expenseLines {
            checkPageBreak(ctx, y: &y)
            let amountStr = fmt.string(from: NSNumber(value: lineTotal.deductibleAmount)) ?? "$0"
            drawTableRow(cols: [(lineTotal.taxFormLine.lineNumber, 60),
                               (lineTotal.taxFormLine.irsDescription, contentWidth - 60 - 100),
                               (amountStr, 100)],
                         y: y, font: bodyFont, color: darkText)
            y += 14
        }

        // Depreciation (from assets, not transactions)
        if summary.depreciationTotal > 0 {
            checkPageBreak(ctx, y: &y)
            let deprStr = fmt.string(from: NSNumber(value: summary.depreciationTotal)) ?? "$0"
            drawTableRow(cols: [("", 60), ("Depreciation (from asset schedule)", contentWidth - 60 - 100), (deprStr, 100)],
                         y: y, font: bodyFont, color: darkText)
            y += 14
        }

        let totalDeductionsStr = fmt.string(from: NSNumber(value: summary.totalDeductions + summary.depreciationTotal)) ?? "$0"
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y))
        y += 4
        drawKeyValueRow(label: "Total Deductions", value: totalDeductionsStr, y: y, bold: true)
        y += 20

        // Net
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y), width: 1.5)
        y += 6
        let netLabel = summary.ordinaryIncome >= 0 ? "Ordinary Business Income" : "Ordinary Business Loss"
        let netStr = fmt.string(from: NSNumber(value: summary.ordinaryIncome)) ?? "$0"
        let netColor = summary.ordinaryIncome >= 0 ? greenColor : redColor
        draw(netLabel, at: CGPoint(x: margin, y: y), font: h2Font, color: darkText)
        let netSize = (netStr as NSString).size(withAttributes: [.font: h2Font])
        draw(netStr, at: CGPoint(x: margin + contentWidth - netSize.width, y: y), font: h2Font, color: netColor)
        y += 24

        endPage(ctx)
    }

    // MARK: - Partner Capital & Basis Page

    private func drawPartnerBasisPage(ctx: CGContext, summary: BusinessTaxYearSummary, year: Int) {
        var y = beginPage(ctx)

        draw("\(summary.businessProfile.businessName) — Partner Capital & Basis", at: CGPoint(x: margin, y: y), font: h1Font, color: brandColor)
        y += 24

        // Table header
        let cols: [(String, CGFloat)] = [
            ("Item", contentWidth * 0.4),
            (summary.partnerSummaries.first?.partner.partnerName ?? "Partner 1", contentWidth * 0.3),
            (summary.partnerSummaries.count > 1 ? summary.partnerSummaries[1].partner.partnerName : "Partner 2", contentWidth * 0.3)
        ]
        drawTableRow(cols: cols, y: y, font: h3Font, color: darkText, rightAlignLast: false)
        y += 16
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y))
        y += 6

        for (index, k1) in summary.partnerSummaries.enumerated() {
            if index == 0 {
                // Draw rows comparing all partners
                let rows: [(String, (PartnerK1Summary) -> String)] = [
                    ("Ownership %", { $0.partner.ownershipDisplay }),
                    ("Capital Contributed", { self.fmt.string(from: NSNumber(value: $0.capitalContributed)) ?? "$0" }),
                    ("Beginning Capital", { self.fmt.string(from: NSNumber(value: $0.beginningCapital)) ?? "$0" }),
                    ("Allocated Income (Loss)", { self.fmt.string(from: NSNumber(value: $0.ordinaryIncome)) ?? "$0" }),
                    ("Ending Capital Account", { self.fmt.string(from: NSNumber(value: $0.endingCapital)) ?? "$0" }),
                    ("Debt Allocation (§752)", { self.fmt.string(from: NSNumber(value: $0.partner.debtAllocation)) ?? "$0" }),
                    ("Outside Basis (YE)", { self.fmt.string(from: NSNumber(value: $0.outsideBasis)) ?? "$0" }),
                    ("Loss Deductible?", { $0.lossDeductible || $0.ordinaryIncome >= 0 ? "Yes" : "No — suspended" }),
                ]

                for (label, valueFn) in rows {
                    checkPageBreak(ctx, y: &y)
                    var rowCols: [(String, CGFloat)] = [(label, contentWidth * 0.4)]
                    for k1Sum in summary.partnerSummaries {
                        rowCols.append((valueFn(k1Sum), contentWidth * 0.3))
                    }
                    // Pad to 3 columns
                    while rowCols.count < 3 {
                        rowCols.append(("", contentWidth * 0.3))
                    }
                    let isBold = label.contains("Ending") || label.contains("Outside Basis") || label.contains("Loss Deductible")
                    drawTableRow(cols: rowCols, y: y, font: isBold ? bodyBoldFont : bodyFont, rightAlignLast: false)
                    y += 15
                }
            }
        }

        // Suspended loss note
        let suspendedPartners = summary.partnerSummaries.filter { !$0.lossDeductible && $0.ordinaryIncome < 0 }
        if !suspendedPartners.isEmpty {
            y += 10
            for sp in suspendedPartners {
                checkPageBreak(ctx, y: &y)
                let note = "\(sp.partner.partnerName)'s loss is suspended under IRC §704(d) (insufficient outside basis). Carries forward indefinitely."
                draw(note, at: CGPoint(x: margin, y: y), font: captionFont, color: orangeColor)
                y += 12
            }
        }

        endPage(ctx)
    }

    // MARK: - Depreciation Page

    private func drawDepreciationPage(ctx: CGContext, businesses: [BusinessProfile], year: Int) {
        var y = beginPage(ctx)

        draw("Depreciation Schedules — \(String(year))", at: CGPoint(x: margin, y: y), font: h1Font, color: brandColor)
        y += 24

        for business in businesses {
            let assets = business.activeAssets
            guard !assets.isEmpty else { continue }

            checkPageBreak(ctx, y: &y, needed: 60)
            drawSectionHeader(business.businessName, ctx: ctx, y: &y)

            // Header
            let cols: [(String, CGFloat)] = [
                ("Asset", contentWidth * 0.30),
                ("Cost", contentWidth * 0.15),
                ("Method", contentWidth * 0.15),
                ("Class", contentWidth * 0.15),
                ("\(String(year)) Depr", contentWidth * 0.12),
                ("NBV", contentWidth * 0.13)
            ]
            drawTableRow(cols: cols, y: y, font: h3Font, rightAlignLast: false)
            y += 16

            for asset in assets {
                checkPageBreak(ctx, y: &y)
                let yearDepr = asset.depreciationForYear(year)
                let nbv = asset.netBookValue(atEndOfYear: year)

                drawTableRow(cols: [
                    (asset.name, contentWidth * 0.30),
                    (fmt.string(from: NSNumber(value: asset.cost)) ?? "$0", contentWidth * 0.15),
                    (asset.depreciationMethod.shortName, contentWidth * 0.15),
                    (asset.propertyClass.displayName.replacingOccurrences(of: " Property", with: ""), contentWidth * 0.15),
                    (fmt.string(from: NSNumber(value: yearDepr)) ?? "$0", contentWidth * 0.12),
                    (fmt.string(from: NSNumber(value: nbv)) ?? "$0", contentWidth * 0.13)
                ], y: y, font: bodyFont, rightAlignLast: false)
                y += 14

                if let sn = asset.serialNumber, !sn.isEmpty {
                    draw("SN: \(sn)", at: CGPoint(x: margin + 10, y: y), font: captionFont, color: grayText)
                    y += 12
                }
            }

            let totalDepr = MACRSCalculationService.shared.totalDepreciationForYear(year, assets: assets)
            drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y))
            y += 4
            drawKeyValueRow(label: "Total \(business.businessName) Depreciation", value: fmt.string(from: NSNumber(value: totalDepr)) ?? "$0", y: y, bold: true)
            y += 20
        }

        endPage(ctx)
    }

    // MARK: - Carryforward Page

    private func drawCarryforwardPage(ctx: CGContext, businesses: [BusinessProfile]) {
        var y = beginPage(ctx)

        draw("Carryforward Items for Future Years", at: CGPoint(x: margin, y: y), font: h1Font, color: brandColor)
        y += 24

        let cols: [(String, CGFloat)] = [
            ("Item", contentWidth * 0.30),
            ("Amount", contentWidth * 0.18),
            ("Origin", contentWidth * 0.10),
            ("Entity", contentWidth * 0.22),
            ("Action", contentWidth * 0.20)
        ]
        drawTableRow(cols: cols, y: y, font: h3Font, rightAlignLast: false)
        y += 16

        for business in businesses {
            for item in business.activeCarryforwards {
                checkPageBreak(ctx, y: &y, needed: 30)
                let amountStr = fmt.string(from: NSNumber(value: item.remainingAmount)) ?? "$0"
                let partnerNote = item.partnerName.map { " (\($0))" } ?? ""

                drawTableRow(cols: [
                    (item.type.displayName + partnerNote, contentWidth * 0.30),
                    (amountStr, contentWidth * 0.18),
                    (String(item.originYear), contentWidth * 0.10),
                    (business.businessName, contentWidth * 0.22),
                    (item.notes ?? item.type.ircReference, contentWidth * 0.20)
                ], y: y, font: bodyFont, rightAlignLast: false)
                y += 14
            }
        }

        endPage(ctx)
    }

    // MARK: - Disclaimer Page

    private func drawDisclaimerPage(ctx: CGContext, year: Int) {
        var y = beginPage(ctx)

        draw("Important Disclaimers", at: CGPoint(x: margin, y: y), font: h1Font, color: darkText)
        y += 24

        let disclaimers = [
            "This document was generated by FLO (Finance Ledger Optimizer) for informational purposes only.",
            "FLO is not a registered tax preparer, CPA, or tax advisory service.",
            "This document does not constitute tax advice and should not be relied upon as a substitute for consultation with a qualified tax professional.",
            "All calculations, form line mappings, depreciation schedules, and partner allocations are estimates based on user-entered data and may not reflect your actual tax obligations.",
            "MACRS depreciation tables are sourced from IRS Publication 946. Verify all depreciation calculations with your tax preparer.",
            "Partner basis and §704(d) loss suspension calculations are simplified and may not account for all applicable IRC provisions.",
            "You are responsible for verifying all information in this document before using it for tax filing purposes.",
            "By using this document, you acknowledge that Finch & Poppy Co LLC (the developer of FLO) assumes no liability for errors, omissions, or consequences arising from reliance on this information.",
        ]

        for disclaimer in disclaimers {
            checkPageBreak(ctx, y: &y, needed: 30)
            draw("  \(disclaimer)", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
            y += 24
        }

        y += 20
        draw("Tax Year: \(year)", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 14
        draw("Generated: \(DateFormatter.mediumDate.string(from: Date()))", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 14
        draw("FLO Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)

        endPage(ctx)
    }
}

// DateFormatter.mediumDate is defined in DateFormatter+Shared.swift
