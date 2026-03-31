//  ComprehensiveReportService+Sections.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Extracted from ComprehensiveReportService v2.0
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Individual PDF section renderers. Each method draws one report section.
//  Called from +PDFLayout.swift orchestrator.
//
//  SECTIONS:
//  ✅ Cover Page — professional cover with business info
//  ✅ Executive Summary — health score, key metrics
//  ✅ Income & Expense Breakdown — P&L with net income
//  ✅ Category Breakdown — expense category table
//  ✅ Tax-Deductible Summary — Schedule C line-by-line
//  ✅ Mileage Summary + Trips Table — IRS compliant log
//  ✅ Invoice Summary — outstanding, paid, overdue
//  ✅ Equity Section — draws, contributions, tax payments
//  ✅ Quarterly Tax Table — estimated quarterly payments
//  ✅ Monthly Table — month-by-month breakdown
//  ✅ CPA Notes — preparation checklist
//  ✅ Transaction Table — detailed listing
//  ✅ Transfer Appendix — NEW v2.0, reconciliation reference
//  ✅ Disclaimers — legal/tax disclaimers
//

#if !os(macOS)
#if canImport(UIKit)
import UIKit
#endif

extension ComprehensiveReportService {
    
    // MARK: - Cover Page
    
    func drawCoverPage(
        config: ReportConfiguration,
        businessProfile: BusinessProfile?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        
        var y: CGFloat = pageHeight * 0.25
        
        // FLO Logo placeholder (teal circle)
        let logoRect = CGRect(x: (pageWidth - 80) / 2, y: y - 100, width: 80, height: 80)
        UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 1.0).setFill()
        UIBezierPath(ovalIn: logoRect).fill()
        
        let iconAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .medium),
            .foregroundColor: UIColor.white
        ]
        let icon = "📊"
        let iconSize = icon.size(withAttributes: iconAttrs)
        icon.draw(at: CGPoint(x: logoRect.midX - iconSize.width/2, y: logoRect.midY - iconSize.height/2), withAttributes: iconAttrs)
        
        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        let title = config.title
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: y), withAttributes: titleAttrs)
        y += titleSize.height + 20
        
        // Date range
        let dateRange = "\(DateFormatter.longDate.string(from: config.dateRange.lowerBound)) - \(DateFormatter.longDate.string(from: config.dateRange.upperBound))"
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let dateSize = dateRange.size(withAttributes: dateAttrs)
        dateRange.draw(at: CGPoint(x: (pageWidth - dateSize.width) / 2, y: y), withAttributes: dateAttrs)
        y += dateSize.height + 60
        
        // Business info box
        if let profile = businessProfile, !profile.businessName.isEmpty {
            let boxY = y
            let boxHeight: CGFloat = 120
            
            UIColor.systemGray6.setFill()
            UIBezierPath(roundedRect: CGRect(x: margin + 50, y: boxY, width: pageWidth - margin * 2 - 100, height: boxHeight), cornerRadius: 8).fill()
            
            let businessAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: UIColor.black
            ]
            
            var textY = boxY + 20
            let preparedFor = "Prepared for:"
            let preparedAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            preparedFor.draw(at: CGPoint(x: margin + 70, y: textY), withAttributes: preparedAttrs)
            textY += 18
            
            profile.businessName.draw(at: CGPoint(x: margin + 70, y: textY), withAttributes: businessAttrs)
            textY += 25
            
            if let address = profile.formattedAddress {
                let addressAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
                address.draw(at: CGPoint(x: margin + 70, y: textY), withAttributes: addressAttrs)
            }
            
            y = boxY + boxHeight + 40
        }
        
        // Generated date
        y = pageHeight - margin - 100
        let generatedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let generated = "Generated: \(Date().formatted(date: .long, time: .shortened))"
        let generatedSize = generated.size(withAttributes: generatedAttrs)
        generated.draw(at: CGPoint(x: (pageWidth - generatedSize.width) / 2, y: y), withAttributes: generatedAttrs)
        
        y += 20
        let poweredBy = "Powered by FLO - Finance Ledger Optimizer v\(ComprehensiveReportService.version)"
        let poweredSize = poweredBy.size(withAttributes: generatedAttrs)
        poweredBy.draw(at: CGPoint(x: (pageWidth - poweredSize.width) / 2, y: y), withAttributes: generatedAttrs)
        
        return y
    }
    
    // MARK: - Executive Summary
    
    func drawExecutiveSummary(
        summary: ReportSummary,
        mileage: MileageSummary?,
        invoices: InvoiceSummary?,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Financial Health Score Box
        let healthScore = calculateHealthScore(summary: summary, invoices: invoices)
        let scoreColor = healthScore >= 70 ? UIColor.systemGreen : (healthScore >= 40 ? UIColor.systemOrange : UIColor.systemRed)
        
        UIColor.systemGray6.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 80), cornerRadius: 8).fill()
        
        let scoreAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: scoreColor
        ]
        let scoreText = "\(healthScore)"
        scoreText.draw(at: CGPoint(x: margin + 20, y: currentY + 15), withAttributes: scoreAttrs)
        
        let scoreLabel = "Financial Health Score"
        let scoreLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        scoreLabel.draw(at: CGPoint(x: margin + 90, y: currentY + 20), withAttributes: scoreLabelAttrs)
        
        let scoreDesc = getHealthScoreDescription(score: healthScore)
        let scoreDescAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        scoreDesc.draw(at: CGPoint(x: margin + 90, y: currentY + 40), withAttributes: scoreDescAttrs)
        
        currentY += 100
        
        // Key Metrics Grid
        let metrics: [(label: String, value: String, color: UIColor)] = [
            ("Total Income", formatter.string(from: NSNumber(value: summary.totalIncome)) ?? "$0", .systemGreen),
            ("Total Expenses", formatter.string(from: NSNumber(value: summary.totalExpenses)) ?? "$0", .systemRed),
            ("Net Income", formatter.string(from: NSNumber(value: summary.netIncome)) ?? "$0", summary.netIncome >= 0 ? .systemGreen : .systemRed),
            ("Tax-Deductible", formatter.string(from: NSNumber(value: summary.taxDeductibleExpenses)) ?? "$0", .systemBlue),
            ("Transactions", "\(summary.transactionCount)", .label),
            ("Profit Margin", String(format: "%.1f%%", summary.profitMargin), summary.profitMargin >= 0 ? .systemGreen : .systemRed)
        ]
        
        let colWidth = width / 3
        for (index, metric) in metrics.enumerated() {
            let col = index % 3
            let row = index / 3
            let x = margin + CGFloat(col) * colWidth
            let boxY = currentY + CGFloat(row) * 70
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            metric.label.draw(at: CGPoint(x: x, y: boxY), withAttributes: labelAttrs)
            
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: metric.color
            ]
            metric.value.draw(at: CGPoint(x: x, y: boxY + 15), withAttributes: valueAttrs)
        }
        
        currentY += 160
        
        // Mileage summary if available
        if let mileage = mileage, mileage.tripCount > 0 {
            let mileageText = "Mileage: \(String(format: "%.1f", mileage.businessMiles)) business miles • \(formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0") deduction"
            let mileageAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            mileageText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: mileageAttrs)
            currentY += 20
        }
        
        // Invoice summary if available
        if let invoices = invoices, invoices.invoiceCount > 0 {
            let invoiceText = "Invoices: \(formatter.string(from: NSNumber(value: invoices.totalOutstanding)) ?? "$0") outstanding • \(invoices.overdueCount) overdue"
            let invoiceColor: UIColor = invoices.overdueCount > 0 ? .systemOrange : .darkGray
            let invoiceAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: invoiceColor
            ]
            invoiceText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: invoiceAttrs)
            currentY += 20
        }
        
        return currentY
    }
    
    // MARK: - Income & Expense Breakdown
    
    func drawIncomeExpenseBreakdown(
        summary: ReportSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        let incomeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.systemGreen
        ]
        "INCOME".draw(at: CGPoint(x: margin, y: currentY), withAttributes: incomeAttrs)
        currentY += 25
        
        drawMetricRow("Total Income", value: formatter.string(from: NSNumber(value: summary.totalIncome)) ?? "$0", y: currentY, margin: margin, width: width)
        currentY += 25
        
        currentY += 20
        let expenseAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.systemRed
        ]
        "EXPENSES".draw(at: CGPoint(x: margin, y: currentY), withAttributes: expenseAttrs)
        currentY += 25
        
        drawMetricRow("Total Expenses", value: formatter.string(from: NSNumber(value: summary.totalExpenses)) ?? "$0", y: currentY, margin: margin, width: width)
        currentY += 22
        drawMetricRow("  Business Expenses", value: formatter.string(from: NSNumber(value: summary.businessExpenses)) ?? "$0", y: currentY, margin: margin, width: width, indent: true)
        currentY += 22
        drawMetricRow("  Personal Expenses", value: formatter.string(from: NSNumber(value: summary.personalExpenses)) ?? "$0", y: currentY, margin: margin, width: width, indent: true)
        currentY += 22
        drawMetricRow("  Tax-Deductible", value: formatter.string(from: NSNumber(value: summary.taxDeductibleExpenses)) ?? "$0", y: currentY, margin: margin, width: width, indent: true, highlight: true)
        currentY += 30
        
        // Net summary box
        UIColor.systemGray5.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 40), cornerRadius: 4).fill()
        
        let netColor: UIColor = summary.netIncome >= 0 ? .systemGreen : .systemRed
        let netAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: netColor
        ]
        
        let netLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        "NET INCOME".draw(at: CGPoint(x: margin + 15, y: currentY + 10), withAttributes: netLabelAttrs)
        
        let netValue = formatter.string(from: NSNumber(value: summary.netIncome)) ?? "$0"
        let netSize = netValue.size(withAttributes: netAttrs)
        netValue.draw(at: CGPoint(x: margin + width - netSize.width - 15, y: currentY + 10), withAttributes: netAttrs)
        
        currentY += 50
        
        return currentY
    }
    
    // MARK: - Category Breakdown
    
    func drawCategoryBreakdown(
        categories: [(category: String, amount: Double, percentage: Double)],
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Table header
        UIColor.systemGray6.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 25)).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        "Category".draw(at: CGPoint(x: margin + 10, y: currentY + 7), withAttributes: headerAttrs)
        "Amount".draw(at: CGPoint(x: margin + width - 150, y: currentY + 7), withAttributes: headerAttrs)
        "%".draw(at: CGPoint(x: margin + width - 40, y: currentY + 7), withAttributes: headerAttrs)
        
        currentY += 25
        
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        for (index, category) in categories.prefix(15).enumerated() {
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 20)).fill()
            }
            
            category.category.draw(at: CGPoint(x: margin + 10, y: currentY + 4), withAttributes: rowAttrs)
            
            let amountStr = formatter.string(from: NSNumber(value: category.amount)) ?? "$0"
            let amountSize = amountStr.size(withAttributes: rowAttrs)
            amountStr.draw(at: CGPoint(x: margin + width - 100 - amountSize.width, y: currentY + 4), withAttributes: rowAttrs)
            
            let pctStr = String(format: "%.1f%%", category.percentage)
            pctStr.draw(at: CGPoint(x: margin + width - 45, y: currentY + 4), withAttributes: rowAttrs)
            
            currentY += 20
        }
        
        if categories.count > 15 {
            let moreText = "... and \(categories.count - 15) more categories"
            let moreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            moreText.draw(at: CGPoint(x: margin + 10, y: currentY + 5), withAttributes: moreAttrs)
            currentY += 20
        }
        
        return currentY
    }
    
    // MARK: - Tax-Deductible Summary (Schedule C)
    
    func drawTaxDeductibleSummary(
        summary: ReportSummary,
        mileage: MileageSummary?,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Info box
        UIColor.systemBlue.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 60), cornerRadius: 8).fill()
        
        let infoText = "The following expenses may be deductible on IRS Schedule C (Form 1040). Consult your tax professional for specific guidance."
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let infoRect = CGRect(x: margin + 15, y: currentY + 10, width: width - 30, height: 40)
        var infoAttrsWithParagraph = infoAttrs
        infoAttrsWithParagraph[.paragraphStyle] = paragraphStyle
        infoText.draw(in: infoRect, withAttributes: infoAttrsWithParagraph)
        
        currentY += 80
        
        // Schedule C Line-by-Line Breakdown header
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "SCHEDULE C — EXPENSE BREAKDOWN BY LINE".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 25
        
        // Table header row
        UIColor.systemGray5.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 20)).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "Line".draw(at: CGPoint(x: margin + 5, y: currentY + 5), withAttributes: headerAttrs)
        "Description".draw(at: CGPoint(x: margin + 50, y: currentY + 5), withAttributes: headerAttrs)
        "Categories".draw(at: CGPoint(x: margin + 220, y: currentY + 5), withAttributes: headerAttrs)
        
        let amountHeader = "Deductible"
        let amountHeaderSize = amountHeader.size(withAttributes: headerAttrs)
        amountHeader.draw(at: CGPoint(x: margin + width - amountHeaderSize.width - 5, y: currentY + 5), withAttributes: headerAttrs)
        
        currentY += 22
        
        // Data rows
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let lineNumAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.systemIndigo
        ]
        let amountAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        let categoryAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        
        var runningDeductibleTotal: Double = 0
        
        for (index, line) in summary.scheduleCBreakdown.enumerated() {
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 30)).fill()
            }
            
            line.lineNumber.draw(at: CGPoint(x: margin + 5, y: currentY + 4), withAttributes: lineNumAttrs)
            
            let descText = String(line.lineLabel.prefix(28))
            descText.draw(at: CGPoint(x: margin + 50, y: currentY + 4), withAttributes: rowAttrs)
            
            let catText = String(line.categories.joined(separator: ", ").prefix(30))
            catText.draw(at: CGPoint(x: margin + 220, y: currentY + 4), withAttributes: categoryAttrs)
            
            let amountStr = formatter.string(from: NSNumber(value: line.deductibleAmount)) ?? "$0"
            let amountSize = amountStr.size(withAttributes: amountAttrs)
            amountStr.draw(at: CGPoint(x: margin + width - amountSize.width - 5, y: currentY + 4), withAttributes: amountAttrs)
            
            // Show "(50%)" note for meals
            if line.grossAmount != line.deductibleAmount {
                let noteText = "(\(Int(line.deductibleAmount / line.grossAmount * 100))% of \(formatter.string(from: NSNumber(value: line.grossAmount)) ?? "$0"))"
                let noteAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 7, weight: .regular),
                    .foregroundColor: UIColor.gray
                ]
                noteText.draw(at: CGPoint(x: margin + 50, y: currentY + 17), withAttributes: noteAttrs)
            }
            
            runningDeductibleTotal += line.deductibleAmount
            currentY += 30
        }
        
        // Separator
        currentY += 5
        UIColor.systemGray4.setStroke()
        let separatorPath = UIBezierPath()
        separatorPath.move(to: CGPoint(x: margin, y: currentY))
        separatorPath.addLine(to: CGPoint(x: margin + width, y: currentY))
        separatorPath.lineWidth = 0.5
        separatorPath.stroke()
        currentY += 10
        
        // Subtotal
        drawMetricRow("Subtotal — Categorized Expenses", value: formatter.string(from: NSNumber(value: runningDeductibleTotal)) ?? "$0", y: currentY, margin: margin, width: width)
        currentY += 25
        
        // Mileage deduction (Line 9 supplement)
        if let mileage = mileage, mileage.totalDeduction > 0 {
            drawMetricRow("Mileage Deduction (Line 9 — \(String(format: "%.1f", mileage.businessMiles)) mi × $\(String(format: "%.3f", mileage.averageRate)))", value: formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0", y: currentY, margin: margin, width: width, indent: true)
            currentY += 25
            runningDeductibleTotal += mileage.totalDeduction
        }
        
        // Total deductions box
        currentY += 10
        UIColor.systemGreen.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 40), cornerRadius: 4).fill()
        
        let totalLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "TOTAL POTENTIAL DEDUCTIONS".draw(at: CGPoint(x: margin + 15, y: currentY + 12), withAttributes: totalLabelAttrs)
        
        let totalStr = formatter.string(from: NSNumber(value: runningDeductibleTotal)) ?? "$0"
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.systemGreen
        ]
        let totalSize = totalStr.size(withAttributes: totalAttrs)
        totalStr.draw(at: CGPoint(x: margin + width - totalSize.width - 15, y: currentY + 10), withAttributes: totalAttrs)
        
        currentY += 60
        
        // CPA note about unmapped categories
        let unmappedCount = summary.scheduleCBreakdown.filter { $0.lineNumber == "—" }.count
        if unmappedCount > 0 {
            let noteText = "Note: \(unmappedCount) category group(s) are not yet mapped to a Schedule C line. Assign lines in Settings → Categories for more accurate reporting."
            let noteAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let noteParaStyle = NSMutableParagraphStyle()
            noteParaStyle.lineBreakMode = .byWordWrapping
            var noteAttrsWithPara = noteAttrs
            noteAttrsWithPara[.paragraphStyle] = noteParaStyle
            let noteRect = CGRect(x: margin, y: currentY, width: width, height: 30)
            noteText.draw(in: noteRect, withAttributes: noteAttrsWithPara)
            currentY += 35
        }
        
        return currentY
    }
    
    // MARK: - Mileage Summary
    
    func drawMileageSummary(
        mileage: MileageSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        let metrics: [(label: String, value: String)] = [
            ("Total Trips", "\(mileage.tripCount)"),
            ("Total Miles", String(format: "%.1f mi", mileage.totalMiles)),
            ("Business Miles", String(format: "%.1f mi", mileage.businessMiles)),
            ("Personal Miles", String(format: "%.1f mi", mileage.personalMiles)),
            ("IRS Rate", String(format: "$%.3f/mi", mileage.averageRate)),
            ("Total Deduction", formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0")
        ]
        
        let colWidth = width / 3
        for (index, metric) in metrics.enumerated() {
            let col = index % 3
            let row = index / 3
            let x = margin + CGFloat(col) * colWidth
            let boxY = currentY + CGFloat(row) * 50
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            metric.label.draw(at: CGPoint(x: x, y: boxY), withAttributes: labelAttrs)
            
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            metric.value.draw(at: CGPoint(x: x, y: boxY + 14), withAttributes: valueAttrs)
        }
        
        currentY += 120
        
        // Purpose breakdown
        if !mileage.topPurposes.isEmpty {
            let purposeHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "MILEAGE BY PURPOSE".draw(at: CGPoint(x: margin, y: currentY), withAttributes: purposeHeaderAttrs)
            currentY += 25
            
            for purpose in mileage.topPurposes {
                let text = "\(purpose.purpose): \(String(format: "%.1f", purpose.miles)) mi • \(formatter.string(from: NSNumber(value: purpose.deduction)) ?? "$0")"
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
                text.draw(at: CGPoint(x: margin + 10, y: currentY), withAttributes: textAttrs)
                currentY += 18
            }
        }
        
        return currentY
    }
    
    // MARK: - Mileage Trips Table
    
    func drawMileageTripsTable(
        trips: [MileageTrip],
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageNumber: inout Int
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        let dateFormatter = DateFormatter.shortDate

        let headerTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "MILEAGE LOG (IRS Compliant)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: headerTitleAttrs)
        currentY += 25
        
        // Table header
        UIColor.systemGray6.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 20)).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        "Date".draw(at: CGPoint(x: margin + 5, y: currentY + 5), withAttributes: headerAttrs)
        "From".draw(at: CGPoint(x: margin + 55, y: currentY + 5), withAttributes: headerAttrs)
        "To".draw(at: CGPoint(x: margin + 160, y: currentY + 5), withAttributes: headerAttrs)
        "Purpose".draw(at: CGPoint(x: margin + 265, y: currentY + 5), withAttributes: headerAttrs)
        "Miles".draw(at: CGPoint(x: margin + 365, y: currentY + 5), withAttributes: headerAttrs)
        "Deduction".draw(at: CGPoint(x: margin + 420, y: currentY + 5), withAttributes: headerAttrs)
        
        currentY += 20
        
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        let businessTrips = trips.filter { $0.isBusinessTrip && $0.purpose != .needsReview }
            .sorted { $0.startDate > $1.startDate }
        
        for (index, trip) in businessTrips.prefix(50).enumerated() {
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 16)).fill()
            }
            
            dateFormatter.string(from: trip.startDate).draw(at: CGPoint(x: margin + 5, y: currentY + 3), withAttributes: rowAttrs)
            String(trip.abbreviatedStartAddress.prefix(18)).draw(at: CGPoint(x: margin + 55, y: currentY + 3), withAttributes: rowAttrs)
            String(trip.abbreviatedEndAddress.prefix(18)).draw(at: CGPoint(x: margin + 160, y: currentY + 3), withAttributes: rowAttrs)
            trip.purpose.displayName.draw(at: CGPoint(x: margin + 265, y: currentY + 3), withAttributes: rowAttrs)
            String(format: "%.1f", trip.distanceMiles).draw(at: CGPoint(x: margin + 365, y: currentY + 3), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: trip.deductionAmount)) ?? "$0").draw(at: CGPoint(x: margin + 420, y: currentY + 3), withAttributes: rowAttrs)
            
            currentY += 16
        }
        
        if businessTrips.count > 50 {
            let moreText = "... and \(businessTrips.count - 50) more trips (see CSV export for complete log)"
            let moreAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            moreText.draw(at: CGPoint(x: margin + 5, y: currentY + 5), withAttributes: moreAttrs)
            currentY += 20
        }
        
        return currentY
    }
    
    // MARK: - Invoice Summary
    
    func drawInvoiceSummary(
        invoices: InvoiceSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        let metrics: [(label: String, value: String, color: UIColor)] = [
            ("Total Invoiced", formatter.string(from: NSNumber(value: invoices.totalInvoiced)) ?? "$0", .black),
            ("Total Paid", formatter.string(from: NSNumber(value: invoices.totalPaid)) ?? "$0", .systemGreen),
            ("Outstanding", formatter.string(from: NSNumber(value: invoices.totalOutstanding)) ?? "$0", .systemOrange),
            ("Overdue", formatter.string(from: NSNumber(value: invoices.overdueAmount)) ?? "$0", .systemRed),
            ("Invoice Count", "\(invoices.invoiceCount)", .black),
            ("Paid Count", "\(invoices.paidCount)", .systemGreen)
        ]
        
        let colWidth = width / 3
        for (index, metric) in metrics.enumerated() {
            let col = index % 3
            let row = index / 3
            let x = margin + CGFloat(col) * colWidth
            let boxY = currentY + CGFloat(row) * 50
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            metric.label.draw(at: CGPoint(x: x, y: boxY), withAttributes: labelAttrs)
            
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: metric.color
            ]
            metric.value.draw(at: CGPoint(x: x, y: boxY + 14), withAttributes: valueAttrs)
        }
        
        currentY += 120
        
        if let avgDays = invoices.averageDaysToPayment {
            let collectionText = "Average Days to Payment: \(String(format: "%.0f", avgDays)) days"
            let collectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            collectionText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: collectionAttrs)
            currentY += 25
        }
        
        if invoices.overdueCount > 0 {
            UIColor.systemRed.withAlphaComponent(0.1).setFill()
            UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 40), cornerRadius: 4).fill()
            
            let warningText = "⚠️ \(invoices.overdueCount) invoice(s) overdue totaling \(formatter.string(from: NSNumber(value: invoices.overdueAmount)) ?? "$0")"
            let warningAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor.systemRed
            ]
            warningText.draw(at: CGPoint(x: margin + 15, y: currentY + 12), withAttributes: warningAttrs)
            currentY += 50
        }
        
        return currentY
    }
    
    // MARK: - Equity & Transfers Section (v1.3, updated v1.4)
    
    func drawEquitySection(
        equityData: EquityData,
        dateRange: ClosedRange<Date>,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Introduction
        let introText = "This section tracks money movement between your business and personal accounts, as well as tax payments made during this period."
        let introAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let introRect = CGRect(x: margin, y: currentY, width: width, height: 60)
        introText.draw(in: introRect, withAttributes: introAttrs)
        let introSize = introText.boundingRect(with: CGSize(width: width, height: .infinity), options: .usesLineFragmentOrigin, attributes: introAttrs, context: nil)
        currentY += introSize.height + 20
        
        let ytdDraws = equityData.ytdDraws
        let ytdContributions = equityData.ytdContributions
        let ytdTaxPaymentsFederal = equityData.ytdTaxPaymentsFederal
        let ytdTaxPaymentsState = equityData.ytdTaxPaymentsState
        let ytdTaxPaymentsTotal = equityData.ytdTaxPaymentsTotal
        let netEquityChange = equityData.netEquityChange
        
        // Metrics grid
        let metrics: [(icon: String, label: String, value: Double, color: UIColor)] = [
            ("↗", "Owner's Draws", ytdDraws, UIColor.systemPurple),
            ("↙", "Capital Contributions", ytdContributions, UIColor.systemTeal),
            ("🏛", "Tax Payments (Federal)", ytdTaxPaymentsFederal, UIColor.systemRed),
            ("🏛", "Tax Payments (State)", ytdTaxPaymentsState, UIColor.systemOrange),
        ]
        
        let colWidth = width / 2
        for (index, metric) in metrics.enumerated() {
            let col = index % 2
            let row = index / 2
            let x = margin + CGFloat(col) * colWidth
            let boxY = currentY + CGFloat(row) * 70
            
            let iconAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .regular)
            ]
            metric.icon.draw(at: CGPoint(x: x, y: boxY), withAttributes: iconAttrs)
            
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            metric.label.draw(at: CGPoint(x: x + 35, y: boxY + 5), withAttributes: labelAttrs)
            
            let valueString = formatter.string(from: NSNumber(value: metric.value)) ?? "$0.00"
            let valueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: metric.color
            ]
            valueString.draw(at: CGPoint(x: x + 35, y: boxY + 22), withAttributes: valueAttrs)
        }
        
        currentY += 160
        
        // Total Tax Payments
        let taxTotalText = "Total Tax Payments: \(formatter.string(from: NSNumber(value: ytdTaxPaymentsTotal)) ?? "$0.00")"
        let taxTotalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.systemRed
        ]
        taxTotalText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: taxTotalAttrs)
        currentY += 30
        
        // Net Equity Change box
        let equityChangeColor = netEquityChange >= 0 ? UIColor.systemGreen : UIColor.systemRed
        equityChangeColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 60), cornerRadius: 8).fill()
        
        let equityLabel = "Net Equity Change"
        let equityLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        equityLabel.draw(at: CGPoint(x: margin + 20, y: currentY + 12), withAttributes: equityLabelAttrs)
        
        let equityValue = "\(formatter.string(from: NSNumber(value: netEquityChange)) ?? "$0.00")"
        let equityValueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
            .foregroundColor: equityChangeColor
        ]
        equityValue.draw(at: CGPoint(x: margin + 20, y: currentY + 32), withAttributes: equityValueAttrs)
        
        let equityNote = netEquityChange >= 0 ? "Money invested into business" : "Money withdrawn from business"
        let equityNoteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let noteX = margin + width - 200
        equityNote.draw(at: CGPoint(x: noteX, y: currentY + 40), withAttributes: equityNoteAttrs)
        
        currentY += 80
        
        // Educational footer
        let footerTitle = "💡 Understanding Equity for Freelancers"
        let footerTitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.systemBlue
        ]
        footerTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: footerTitleAttrs)
        currentY += 25
        
        let footerText = """
        • Owner's Draws: Money you took out of your business for personal use. These are NOT business expenses \
        and don't reduce your taxable income.
        
        • Capital Contributions: Money you put into your business from personal funds. This increases your equity \
        (ownership stake) in the business.
        
        • Net Equity Change: The difference between contributions and draws. A positive number means you invested \
        more than you withdrew; negative means you withdrew more than you invested.
        
        • Tax Payments: Quarterly estimated tax payments made to federal and state authorities. These are tracked \
        separately as they represent tax obligations, not operating expenses.
        
        Important: As a sole proprietor or single-member LLC, owner's draws are NOT deductible expenses. Your business \
        profit (income minus expenses) determines your tax liability, regardless of how much you draw out.
        """
        
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let footerRect = CGRect(x: margin, y: currentY, width: width, height: 300)
        footerText.draw(in: footerRect, withAttributes: footerAttrs)
        let footerSize = footerText.boundingRect(with: CGSize(width: width, height: .infinity), options: .usesLineFragmentOrigin, attributes: footerAttrs, context: nil)
        currentY += footerSize.height + 20
        
        return currentY
    }
    
    // MARK: - Quarterly Tax Table
    
    func drawQuarterlyTaxTable(
        taxes: [QuarterlyTaxSummary],
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        let dateFormatter = DateFormatter.mediumDate

        let infoText = "Estimated quarterly tax payments for self-employment. These are estimates only - consult your CPA for accurate calculations."
        let infoAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        infoText.draw(in: CGRect(x: margin, y: currentY, width: width, height: 30), withAttributes: infoAttrs)
        currentY += 40
        
        // Table header
        UIColor.systemGray6.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 25)).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        "Quarter".draw(at: CGPoint(x: margin + 10, y: currentY + 7), withAttributes: headerAttrs)
        "Net Income".draw(at: CGPoint(x: margin + 100, y: currentY + 7), withAttributes: headerAttrs)
        "SE Tax".draw(at: CGPoint(x: margin + 200, y: currentY + 7), withAttributes: headerAttrs)
        "Income Tax".draw(at: CGPoint(x: margin + 290, y: currentY + 7), withAttributes: headerAttrs)
        "Total".draw(at: CGPoint(x: margin + 380, y: currentY + 7), withAttributes: headerAttrs)
        "Due Date".draw(at: CGPoint(x: margin + 450, y: currentY + 7), withAttributes: headerAttrs)
        
        currentY += 25
        
        var totalTax: Double = 0
        
        for (index, quarter) in taxes.enumerated() {
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 22)).fill()
            }
            
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            
            "Q\(quarter.quarter) \(quarter.year)".draw(at: CGPoint(x: margin + 10, y: currentY + 5), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: quarter.estimatedIncome)) ?? "$0").draw(at: CGPoint(x: margin + 100, y: currentY + 5), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: quarter.estimatedSelfEmploymentTax)) ?? "$0").draw(at: CGPoint(x: margin + 200, y: currentY + 5), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: quarter.estimatedIncomeTax)) ?? "$0").draw(at: CGPoint(x: margin + 290, y: currentY + 5), withAttributes: rowAttrs)
            
            let totalAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            (formatter.string(from: NSNumber(value: quarter.totalEstimatedTax)) ?? "$0").draw(at: CGPoint(x: margin + 380, y: currentY + 5), withAttributes: totalAttrs)
            
            let dueDateColor: UIColor = quarter.isPastDue ? .systemRed : .black
            let dueDateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: quarter.isPastDue ? .bold : .regular),
                .foregroundColor: dueDateColor
            ]
            dateFormatter.string(from: quarter.dueDate).draw(at: CGPoint(x: margin + 450, y: currentY + 5), withAttributes: dueDateAttrs)
            
            totalTax += quarter.totalEstimatedTax
            currentY += 22
        }
        
        // Annual total row
        currentY += 5
        UIColor.systemBlue.withAlphaComponent(0.1).setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 25)).fill()
        
        let annualLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "ANNUAL TOTAL".draw(at: CGPoint(x: margin + 10, y: currentY + 6), withAttributes: annualLabelAttrs)
        
        let annualValueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.systemBlue
        ]
        (formatter.string(from: NSNumber(value: totalTax)) ?? "$0").draw(at: CGPoint(x: margin + 380, y: currentY + 6), withAttributes: annualValueAttrs)
        
        currentY += 35
        
        return currentY
    }
    
    // MARK: - Monthly Table
    
    func drawMonthlyTable(
        monthly: [MonthlyBreakdown],
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        UIColor.systemGray6.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 25)).fill()
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        "Month".draw(at: CGPoint(x: margin + 10, y: currentY + 7), withAttributes: headerAttrs)
        "Income".draw(at: CGPoint(x: margin + 120, y: currentY + 7), withAttributes: headerAttrs)
        "Expenses".draw(at: CGPoint(x: margin + 220, y: currentY + 7), withAttributes: headerAttrs)
        "Business Exp".draw(at: CGPoint(x: margin + 320, y: currentY + 7), withAttributes: headerAttrs)
        "Net".draw(at: CGPoint(x: margin + 430, y: currentY + 7), withAttributes: headerAttrs)
        
        currentY += 25
        
        var totalIncome: Double = 0
        var totalExpenses: Double = 0
        var totalBusiness: Double = 0
        var totalNet: Double = 0
        
        for (index, month) in monthly.enumerated() {
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 20)).fill()
            }
            
            let rowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            
            month.monthLabel.draw(at: CGPoint(x: margin + 10, y: currentY + 4), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: month.income)) ?? "$0").draw(at: CGPoint(x: margin + 120, y: currentY + 4), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: month.expenses)) ?? "$0").draw(at: CGPoint(x: margin + 220, y: currentY + 4), withAttributes: rowAttrs)
            (formatter.string(from: NSNumber(value: month.businessExpenses)) ?? "$0").draw(at: CGPoint(x: margin + 320, y: currentY + 4), withAttributes: rowAttrs)
            
            let netColor: UIColor = month.netCashFlow >= 0 ? .systemGreen : .systemRed
            let netAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: netColor
            ]
            (formatter.string(from: NSNumber(value: month.netCashFlow)) ?? "$0").draw(at: CGPoint(x: margin + 430, y: currentY + 4), withAttributes: netAttrs)
            
            totalIncome += month.income
            totalExpenses += month.expenses
            totalBusiness += month.businessExpenses
            totalNet += month.netCashFlow
            
            currentY += 20
        }
        
        // Totals row
        currentY += 5
        UIColor.systemGray5.setFill()
        UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 25)).fill()
        
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        "TOTAL".draw(at: CGPoint(x: margin + 10, y: currentY + 6), withAttributes: totalAttrs)
        (formatter.string(from: NSNumber(value: totalIncome)) ?? "$0").draw(at: CGPoint(x: margin + 120, y: currentY + 6), withAttributes: totalAttrs)
        (formatter.string(from: NSNumber(value: totalExpenses)) ?? "$0").draw(at: CGPoint(x: margin + 220, y: currentY + 6), withAttributes: totalAttrs)
        (formatter.string(from: NSNumber(value: totalBusiness)) ?? "$0").draw(at: CGPoint(x: margin + 320, y: currentY + 6), withAttributes: totalAttrs)
        
        let netColor: UIColor = totalNet >= 0 ? .systemGreen : .systemRed
        let netTotalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: netColor
        ]
        (formatter.string(from: NSNumber(value: totalNet)) ?? "$0").draw(at: CGPoint(x: margin + 430, y: currentY + 6), withAttributes: netTotalAttrs)
        
        currentY += 35
        
        return currentY
    }
    
    // MARK: - CPA Notes
    
    func drawCPANotes(
        summary: ReportSummary,
        mileage: MileageSummary?,
        invoices: InvoiceSummary?,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        var notes: [String] = []
        
        notes.append("📋 SCHEDULE C PREPARATION")
        notes.append("• Gross receipts (Line 1): \(formatter.string(from: NSNumber(value: summary.totalIncome)) ?? "$0")")
        notes.append("• Total business expenses: \(formatter.string(from: NSNumber(value: summary.businessExpenses)) ?? "$0")")
        
        if let mileage = mileage, mileage.totalDeduction > 0 {
            notes.append("• Vehicle expenses (Line 9): \(formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0") (\(String(format: "%.1f", mileage.businessMiles)) business miles)")
        }
        
        notes.append("")
        notes.append("🔍 ITEMS TO DISCUSS WITH YOUR CPA")
        
        if summary.businessExpenseRatio < 30 {
            notes.append("• Low business expense ratio (\(String(format: "%.0f%%", summary.businessExpenseRatio))) - review for missed deductions")
        }
        
        if let invoices = invoices, invoices.totalOutstanding > 5000 {
            notes.append("• Significant accounts receivable (\(formatter.string(from: NSNumber(value: invoices.totalOutstanding)) ?? "$0")) - discuss cash vs accrual accounting")
        }
        
        if summary.netIncome > 50000 {
            notes.append("• Consider retirement account contributions (SEP-IRA, Solo 401k)")
            notes.append("• Review quarterly estimated tax payments")
        }
        
        notes.append("• Verify home office deduction eligibility")
        notes.append("• Review health insurance premium deductions")
        notes.append("• Confirm all 1099s received match income records")
        
        notes.append("")
        notes.append("📎 DOCUMENTS TO BRING TO TAX APPOINTMENT")
        notes.append("• This financial report (printed or digital)")
        notes.append("• All 1099-NEC and 1099-K forms received")
        notes.append("• Mileage log (included in this report)")
        notes.append("• Receipts for large purchases (>$250)")
        notes.append("• Home office measurements if claiming deduction")
        notes.append("• Health insurance premium statements")
        
        for note in notes {
            note.draw(at: CGPoint(x: margin, y: currentY), withAttributes: noteAttrs)
            currentY += 18
        }
        
        return currentY
    }
    
    // MARK: - Transaction Table
    
    func drawTransactionTable(
        transactions: [Transaction],
        startY: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageNumber: inout Int
    ) {
        var currentY = startY
        let formatter = currencyFormatter()
        let dateFormatter = DateFormatter.shortDate

        let sorted = transactions.sorted { $0.date > $1.date }
        
        func drawHeader() {
            UIColor.systemGray6.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 20)).fill()
            
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            
            "Date".draw(at: CGPoint(x: margin + 5, y: currentY + 5), withAttributes: headerAttrs)
            "Description".draw(at: CGPoint(x: margin + 60, y: currentY + 5), withAttributes: headerAttrs)
            "Category".draw(at: CGPoint(x: margin + 200, y: currentY + 5), withAttributes: headerAttrs)
            "Amount".draw(at: CGPoint(x: margin + 320, y: currentY + 5), withAttributes: headerAttrs)
            "Type".draw(at: CGPoint(x: margin + 400, y: currentY + 5), withAttributes: headerAttrs)
            "Finance".draw(at: CGPoint(x: margin + 460, y: currentY + 5), withAttributes: headerAttrs)
            
            currentY += 20
        }
        
        drawHeader()
        
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        
        for (index, transaction) in sorted.enumerated() {
            if currentY + 16 > pageHeight - margin - 30 {
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: margin * 2 + width, pageHeight: pageHeight, margin: margin)
                context.beginPage()
                pageNumber += 1
                currentY = margin
                drawHeader()
            }
            
            if index % 2 == 0 {
                UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 14)).fill()
            }
            
            dateFormatter.string(from: transaction.date).draw(at: CGPoint(x: margin + 5, y: currentY + 2), withAttributes: rowAttrs)
            String(transaction.note.prefix(25)).draw(at: CGPoint(x: margin + 60, y: currentY + 2), withAttributes: rowAttrs)
            String((transaction.category?.name ?? "Uncategorized").prefix(18)).draw(at: CGPoint(x: margin + 200, y: currentY + 2), withAttributes: rowAttrs)
            
            let amountColor: UIColor = transaction.isIncome ? .systemGreen : .systemRed
            let amountStr = formatter.string(from: NSNumber(value: transaction.amount)) ?? "$0"
            let amountAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: amountColor
            ]
            amountStr.draw(at: CGPoint(x: margin + 320, y: currentY + 2), withAttributes: amountAttrs)
            
            (transaction.isIncome ? "Income" : "Expense").draw(at: CGPoint(x: margin + 400, y: currentY + 2), withAttributes: rowAttrs)
            (transaction.financeType == .business ? "Business" : "Personal").draw(at: CGPoint(x: margin + 460, y: currentY + 2), withAttributes: rowAttrs)
            
            currentY += 14
        }
    }
    
    // MARK: - Transfer Appendix — NEW v2.0
    
    /// Draws a reconciliation appendix listing all transfer transactions.
    /// Groups transfers by type (internal, owner's draws, Zelle, ACH, wire, etc.)
    /// and provides subtotals for CPA verification.
    func drawTransferAppendix(
        transfers: [Transaction],
        dateRange: ClosedRange<Date>,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        pageHeight: CGFloat,
        context: UIGraphicsPDFRendererContext,
        pageNumber: inout Int
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        let dateFormatter = DateFormatter.shortDate

        // Introduction
        let introText = "This appendix lists all transactions identified as transfers between accounts. These are excluded from income/expense calculations in this report. This listing is provided for reconciliation purposes."
        let introAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: UIColor.darkGray
        ]
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        var introAttrsWithPara = introAttrs
        introAttrsWithPara[.paragraphStyle] = paragraphStyle
        let introRect = CGRect(x: margin, y: currentY, width: width, height: 50)
        introText.draw(in: introRect, withAttributes: introAttrsWithPara)
        currentY += 55
        
        // Summary box
        let totalTransferAmount = transfers.reduce(0.0) { $0 + $1.amount }
        
        UIColor.systemPurple.withAlphaComponent(0.08).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 50), cornerRadius: 8).fill()
        
        let summaryLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.darkGray
        ]
        "Total Transfers".draw(at: CGPoint(x: margin + 15, y: currentY + 8), withAttributes: summaryLabelAttrs)
        "\(transfers.count) transactions".draw(at: CGPoint(x: margin + 15, y: currentY + 28), withAttributes: summaryLabelAttrs)
        
        let totalStr = formatter.string(from: NSNumber(value: totalTransferAmount)) ?? "$0"
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.systemPurple
        ]
        let totalSize = totalStr.size(withAttributes: totalAttrs)
        totalStr.draw(at: CGPoint(x: margin + width - totalSize.width - 15, y: currentY + 14), withAttributes: totalAttrs)
        
        currentY += 65
        
        // Group transfers by type based on description patterns
        let grouped = groupTransfersByType(transfers)
        
        let groupHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.systemIndigo
        ]
        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let subtotalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        
        for (groupName, groupTransfers) in grouped {
            // Check for page break before group header
            if currentY + 60 > pageHeight - margin - 30 {
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: margin * 2 + width, pageHeight: pageHeight, margin: margin)
                context.beginPage()
                pageNumber += 1
                currentY = margin
            }
            
            // Group header
            let groupTotal = groupTransfers.reduce(0.0) { $0 + $1.amount }
            let groupLabel = "\(groupName) (\(groupTransfers.count))"
            groupLabel.draw(at: CGPoint(x: margin, y: currentY), withAttributes: groupHeaderAttrs)
            currentY += 20
            
            // Table header for this group
            UIColor.systemGray6.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 16)).fill()
            
            let tableHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            "Date".draw(at: CGPoint(x: margin + 5, y: currentY + 3), withAttributes: tableHeaderAttrs)
            "Description".draw(at: CGPoint(x: margin + 60, y: currentY + 3), withAttributes: tableHeaderAttrs)
            "Merchant".draw(at: CGPoint(x: margin + 260, y: currentY + 3), withAttributes: tableHeaderAttrs)
            "Amount".draw(at: CGPoint(x: margin + width - 70, y: currentY + 3), withAttributes: tableHeaderAttrs)
            currentY += 16
            
            // Transaction rows
            let sorted = groupTransfers.sorted { $0.date > $1.date }
            for (index, transfer) in sorted.enumerated() {
                // Page break check
                if currentY + 14 > pageHeight - margin - 30 {
                    self.drawPageFooter(pageNumber: pageNumber, pageWidth: margin * 2 + width, pageHeight: pageHeight, margin: margin)
                    context.beginPage()
                    pageNumber += 1
                    currentY = margin
                }
                
                if index % 2 == 0 {
                    UIColor.systemGray6.withAlphaComponent(0.3).setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 14)).fill()
                }
                
                dateFormatter.string(from: transfer.date).draw(at: CGPoint(x: margin + 5, y: currentY + 2), withAttributes: rowAttrs)
                String(transfer.note.prefix(32)).draw(at: CGPoint(x: margin + 60, y: currentY + 2), withAttributes: rowAttrs)
                String(transfer.merchantName.prefix(20)).draw(at: CGPoint(x: margin + 260, y: currentY + 2), withAttributes: rowAttrs)
                
                let amountStr = formatter.string(from: NSNumber(value: transfer.amount)) ?? "$0"
                let amountSize = amountStr.size(withAttributes: rowAttrs)
                amountStr.draw(at: CGPoint(x: margin + width - amountSize.width - 5, y: currentY + 2), withAttributes: rowAttrs)
                
                currentY += 14
            }
            
            // Subtotal for group
            UIColor.systemGray5.setFill()
            UIBezierPath(rect: CGRect(x: margin, y: currentY, width: width, height: 18)).fill()
            
            "Subtotal".draw(at: CGPoint(x: margin + 5, y: currentY + 3), withAttributes: subtotalAttrs)
            let subtotalStr = formatter.string(from: NSNumber(value: groupTotal)) ?? "$0"
            let subtotalSize = subtotalStr.size(withAttributes: subtotalAttrs)
            subtotalStr.draw(at: CGPoint(x: margin + width - subtotalSize.width - 5, y: currentY + 3), withAttributes: subtotalAttrs)
            
            currentY += 30
        }
        
        // Reconciliation note
        currentY += 10
        let reconcileNote = "Note: Transfers represent money movement between accounts and do not affect your taxable income or deductible expenses. If any transaction above was incorrectly classified as a transfer, recategorize it in FLO to include it in financial calculations."
        let reconcileAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        var reconcileAttrsWithPara = reconcileAttrs
        reconcileAttrsWithPara[.paragraphStyle] = paragraphStyle
        let reconcileRect = CGRect(x: margin, y: currentY, width: width, height: 50)
        reconcileNote.draw(in: reconcileRect, withAttributes: reconcileAttrsWithPara)
        currentY += 55
        
        return currentY
    }
    
    /// Groups transfer transactions by type based on description/merchant patterns.
    private func groupTransfersByType(_ transfers: [Transaction]) -> [(String, [Transaction])] {
        var groups: [String: [Transaction]] = [:]
        
        for transfer in transfers {
            let description = (transfer.note + " " + transfer.merchantName).lowercased()
            
            let groupName: String
            if description.contains("zelle") {
                groupName = "Zelle Transfers"
            } else if description.contains("ach") || description.contains("direct dep") {
                groupName = "ACH Transfers"
            } else if description.contains("wire") {
                groupName = "Wire Transfers"
            } else if description.contains("venmo") || description.contains("paypal") || description.contains("cash app") {
                groupName = "P2P Transfers"
            } else if description.contains("transfer from") || description.contains("transfer to") {
                groupName = "Internal Account Transfers"
            } else if description.contains("owner") || description.contains("draw") {
                groupName = "Owner's Draws"
            } else if description.contains("contribution") || description.contains("capital") {
                groupName = "Capital Contributions"
            } else if description.contains("tax payment") || description.contains("irs") || description.contains("eftps") {
                groupName = "Tax Payments"
            } else {
                groupName = "Other Transfers"
            }
            
            groups[groupName, default: []].append(transfer)
        }
        
        // Sort groups: named groups first alphabetically, "Other" last
        return groups.sorted { a, b in
            if a.key == "Other Transfers" { return false }
            if b.key == "Other Transfers" { return true }
            return a.key < b.key
        }
    }
    
    // MARK: - Disclaimers
    
    func drawDisclaimers(
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        
        let disclaimers = [
            "⚠️ IMPORTANT TAX DISCLAIMER",
            "",
            "This financial report is generated by FLO (Finance Ledger Optimizer) for informational purposes only. The information contained in this report:",
            "",
            "• Is NOT professional tax, legal, or financial advice",
            "• Should NOT be relied upon as the sole basis for tax filing decisions",
            "• May contain estimates that differ from actual tax obligations",
            "• Does NOT constitute a substitute for consultation with qualified professionals",
            "",
            "FLO and Finch & Poppy Co LLC make no representations or warranties regarding the accuracy, completeness, or applicability of this information to your specific tax situation.",
            "",
            "ALWAYS consult with a qualified tax professional (CPA, EA, or tax attorney) before making tax-related decisions or filing tax returns.",
            "",
            "The quarterly tax estimates in this report are simplified calculations and may not account for:",
            "• State and local tax obligations",
            "• Alternative Minimum Tax (AMT)",
            "• Net Investment Income Tax",
            "• Self-employment tax adjustments",
            "• Credits, deductions, or exemptions specific to your situation",
            "",
            "By using this report, you acknowledge that you understand these limitations and agree to seek professional guidance for your specific tax situation.",
            "",
            "© 2026 Finch & Poppy Co LLC. All rights reserved."
        ]
        
        for disclaimer in disclaimers {
            let attrs: [NSAttributedString.Key: Any]
            
            if disclaimer.starts(with: "⚠️") {
                attrs = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: UIColor.systemRed
                ]
            } else if disclaimer.starts(with: "•") {
                attrs = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.darkGray
                ]
            } else if disclaimer.isEmpty {
                currentY += 8
                continue
            } else {
                attrs = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.black
                ]
            }
            
            let rect = CGRect(x: margin, y: currentY, width: width, height: 60)
            disclaimer.draw(in: rect, withAttributes: attrs)
            
            let size = disclaimer.boundingRect(with: CGSize(width: width, height: .infinity), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
            currentY += size.height + 2
        }
        
        return currentY
    }
}

#endif
