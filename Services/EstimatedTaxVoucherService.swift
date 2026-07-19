//  EstimatedTaxVoucherService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Generates 1040-ES style estimated tax payment vouchers
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Produces a multi-page PDF with one voucher per quarter, modeled after
//  IRS Form 1040-ES. These are reference documents, not official forms.
//
//  Cross-platform CGContext rendering (macOS + iOS).
//

import Foundation
import CoreGraphics
import CoreText

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class EstimatedTaxVoucherService {

    static let shared = EstimatedTaxVoucherService()

    private init() {}

    // MARK: - Page Constants

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50
    private var contentWidth: CGFloat { pageWidth - margin * 2 }

    // MARK: - Fonts

    private var titleFont: PlatformFont { PlatformFont.systemFont(ofSize: 22, weight: .bold) }
    private var h1Font: PlatformFont { PlatformFont.systemFont(ofSize: 16, weight: .bold) }
    private var h2Font: PlatformFont { PlatformFont.systemFont(ofSize: 13, weight: .bold) }
    private var bodyFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .regular) }
    private var bodyBoldFont: PlatformFont { PlatformFont.systemFont(ofSize: 10, weight: .bold) }
    private var captionFont: PlatformFont { PlatformFont.systemFont(ofSize: 8, weight: .regular) }
    private var amountFont: PlatformFont { PlatformFont.monospacedDigitSystemFont(ofSize: 28, weight: .bold) }
    private var monoFont: PlatformFont { PlatformFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium) }

    // MARK: - Colors

    private var brandColor: PlatformColor { PlatformColor(red: 0.08, green: 0.72, blue: 0.65, alpha: 1.0) }
    private var darkText: PlatformColor { PlatformColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0) }
    private var grayText: PlatformColor { PlatformColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) }
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

    /// Generates a PDF containing one 1040-ES style voucher per quarter.
    func generateVoucherPDF(
        taxYear: Int,
        quarterlyStatuses: [QuarterlyStatus],
        taxpayerName: String,
        address: String?
    ) -> Data? {
        guard !quarterlyStatuses.isEmpty else { return nil }

        pageNumber = 0
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: nil, nil)
        else { return nil }

        for qs in quarterlyStatuses {
            drawVoucherPage(
                ctx: ctx,
                taxYear: taxYear,
                quarter: qs,
                taxpayerName: taxpayerName,
                address: address
            )
        }

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
        let footer = "FLO Estimated Tax Vouchers — Page \(pageNumber)"
        draw(footer, at: CGPoint(x: margin, y: pageHeight - 30), font: captionFont, color: grayText)
        ctx.endPDFPage()
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

    // MARK: - Voucher Page

    private func drawVoucherPage(
        ctx: CGContext,
        taxYear: Int,
        quarter: QuarterlyStatus,
        taxpayerName: String,
        address: String?
    ) {
        var y = beginPage(ctx)

        // Header band
        ctx.setFillColor(brandColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: 6))

        // Title
        draw("Estimated Tax Payment Voucher", at: CGPoint(x: margin, y: y), font: titleFont, color: darkText)
        y += 30

        // Subtitle
        draw("Reference Document — Not an Official IRS Form", at: CGPoint(x: margin, y: y), font: bodyFont, color: grayText)
        y += 24

        // Separator
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y), color: brandColor, width: 2)
        y += 16

        // Tax year and quarter info
        let dueDateStr = DateFormatter.mediumDate.string(from: quarter.dueDate)

        draw("Tax Year: \(taxYear)", at: CGPoint(x: margin, y: y), font: h2Font, color: darkText)
        y += 20

        draw(quarter.quarterLabel, at: CGPoint(x: margin, y: y), font: h1Font, color: darkText)
        y += 22

        draw("Due Date: \(dueDateStr)", at: CGPoint(x: margin, y: y), font: bodyBoldFont, color: quarter.isPastDue ? PlatformColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1.0) : darkText)
        y += 30

        // Payment amount box
        ctx.setFillColor(lightBg.cgColor)
        ctx.fill(CGRect(x: margin, y: y - 4, width: contentWidth, height: 60))
        ctx.setStrokeColor(brandColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: margin, y: y - 4, width: contentWidth, height: 60))

        draw("AMOUNT OF ESTIMATED TAX PAYMENT", at: CGPoint(x: margin + 12, y: y + 4), font: captionFont, color: grayText)
        let amountStr = fmtDetailed.string(from: NSNumber(value: quarter.amountDue)) ?? "$0.00"
        draw(amountStr, at: CGPoint(x: margin + 12, y: y + 18), font: amountFont, color: darkText)
        y += 76

        // Taxpayer info section
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y), width: 0.5)
        y += 12

        draw("TAXPAYER INFORMATION", at: CGPoint(x: margin, y: y), font: h2Font, color: darkText)
        y += 22

        draw("Name:", at: CGPoint(x: margin, y: y), font: bodyBoldFont, color: grayText)
        draw(taxpayerName, at: CGPoint(x: margin + 60, y: y), font: bodyFont, color: darkText)
        y += 16

        if let address = address, !address.isEmpty {
            draw("Address:", at: CGPoint(x: margin, y: y), font: bodyBoldFont, color: grayText)
            draw(address, at: CGPoint(x: margin + 60, y: y), font: bodyFont, color: darkText)
            y += 16
        }

        y += 20

        // IRS payment instructions section
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y), width: 0.5)
        y += 12

        draw("PAYMENT INSTRUCTIONS", at: CGPoint(x: margin, y: y), font: h2Font, color: darkText)
        y += 24

        let instructions: [(String, String)] = [
            ("IRS Direct Pay:", "www.irs.gov/payments"),
            ("EFTPS:", "www.eftps.gov (Electronic Federal Tax Payment System)"),
            ("Mail payment to:", "Internal Revenue Service"),
            ("", "P.O. Box address per your state (see IRS.gov)"),
            ("Make check to:", "United States Treasury"),
            ("Memo line:", "Form 1040-ES, Tax Year \(taxYear), \(quarter.quarterLabel)")
        ]

        for (label, value) in instructions {
            if !label.isEmpty {
                draw(label, at: CGPoint(x: margin + 8, y: y), font: bodyBoldFont, color: darkText)
                draw(value, at: CGPoint(x: margin + 130, y: y), font: bodyFont, color: darkText)
            } else {
                draw(value, at: CGPoint(x: margin + 130, y: y), font: bodyFont, color: grayText)
            }
            y += 16
        }

        y += 16

        // EFTPS callout box
        ctx.setFillColor(PlatformColor(red: 0.93, green: 0.97, blue: 0.96, alpha: 1.0).cgColor)
        ctx.fill(CGRect(x: margin, y: y - 4, width: contentWidth, height: 44))
        ctx.setStrokeColor(brandColor.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(x: margin, y: y - 4, width: contentWidth, height: 44))

        draw("For electronic payment: www.eftps.gov", at: CGPoint(x: margin + 12, y: y + 2), font: bodyBoldFont, color: darkText)
        draw("Enroll at EFTPS to schedule payments in advance and receive confirmation numbers.", at: CGPoint(x: margin + 12, y: y + 18), font: captionFont, color: grayText)
        y += 60

        // Payment status
        if quarter.isPaid {
            draw("Status: PAID", at: CGPoint(x: margin, y: y), font: h2Font, color: PlatformColor(red: 0.13, green: 0.55, blue: 0.13, alpha: 1.0))
            let paidStr = fmtDetailed.string(from: NSNumber(value: quarter.amountPaid)) ?? "$0.00"
            draw("Amount paid: \(paidStr)", at: CGPoint(x: margin + 120, y: y + 1), font: bodyFont, color: grayText)
            y += 20
        } else if quarter.isPastDue {
            draw("Status: PAST DUE", at: CGPoint(x: margin, y: y), font: h2Font, color: PlatformColor(red: 0.8, green: 0.2, blue: 0.15, alpha: 1.0))
            y += 20
        } else if let days = quarter.daysUntilDue, days > 0 {
            draw("Status: DUE IN \(days) DAYS", at: CGPoint(x: margin, y: y), font: h2Font, color: PlatformColor(red: 0.9, green: 0.55, blue: 0.1, alpha: 1.0))
            y += 20
        }

        y += 10

        // Disclaimer
        drawLine(ctx, from: CGPoint(x: margin, y: y), to: CGPoint(x: margin + contentWidth, y: y), width: 0.5)
        y += 12

        draw("DISCLAIMER", at: CGPoint(x: margin, y: y), font: captionFont, color: grayText)
        y += 12

        let disclaimer = "This voucher is generated by FLO (Finance Ledger Optimizer) for reference purposes only. It is not an official IRS form and should not be mailed to the IRS in place of Form 1040-ES. Payment amounts are estimates based on projected income and may differ from actual tax liability. Consult a qualified tax professional for personalized advice."
        let disclaimerAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: grayText]
        let disclaimerRect = CGRect(x: margin, y: y, width: contentWidth, height: 60)
        NSAttributedString(string: disclaimer, attributes: disclaimerAttrs).draw(in: disclaimerRect)
        y += 50

        draw("Generated by FLO — \(DateFormatter.mediumDate.string(from: Date()))", at: CGPoint(x: margin, y: y), font: captionFont, color: grayText)

        endPage(ctx)
    }
}
