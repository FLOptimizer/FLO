//  ComprehensiveReportService+Helpers.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Extracted from ComprehensiveReportService v2.0
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shared drawing utilities used across all report sections.
//
//  CONTENTS:
//  ✅ drawSectionHeader — teal header with underline
//  ✅ drawMetricRow — label/value row with optional indent/highlight
//  ✅ drawPageFooter — page number and copyright footer
//  ✅ currencyFormatter — shared NumberFormatter
//  ✅ calculateHealthScore — financial health score algorithm
//  ✅ getHealthScoreDescription — score-to-text mapping
//

#if !os(macOS)
#if canImport(UIKit)
import UIKit
#endif

extension ComprehensiveReportService {
    
    // MARK: - Section Header
    
    func drawSectionHeader(_ title: String, y: CGFloat, width: CGFloat, margin: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 1.0) // Teal
        ]
        
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: attrs)
        
        // Underline
        let lineY = y + 25
        UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 1.0).setStroke()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: lineY))
        path.addLine(to: CGPoint(x: margin + width, y: lineY))
        path.lineWidth = 2
        path.stroke()
        
        return lineY + 5
    }
    
    // MARK: - Metric Row
    
    func drawMetricRow(_ label: String, value: String, y: CGFloat, margin: CGFloat, width: CGFloat, indent: Bool = false, highlight: Bool = false) {
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: indent ? .regular : .medium),
            .foregroundColor: UIColor.darkGray
        ]
        
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: highlight ? .bold : .medium),
            .foregroundColor: highlight ? UIColor.systemBlue : UIColor.black
        ]
        
        label.draw(at: CGPoint(x: margin + (indent ? 20 : 0), y: y), withAttributes: labelAttrs)
        
        let valueSize = value.size(withAttributes: valueAttrs)
        value.draw(at: CGPoint(x: margin + width - valueSize.width, y: y), withAttributes: valueAttrs)
    }
    
    // MARK: - Page Footer
    
    nonisolated func drawPageFooter(pageNumber: Int, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
        let footerY = pageHeight - margin + 10
        
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        
        let leftText = "FLO - Finance Ledger Optimizer"
        leftText.draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttrs)
        
        let centerText = "Page \(pageNumber)"
        let centerSize = centerText.size(withAttributes: footerAttrs)
        centerText.draw(at: CGPoint(x: (pageWidth - centerSize.width) / 2, y: footerY), withAttributes: footerAttrs)
        
        let rightText = "© 2026 Finch & Poppy Co LLC"
        let rightSize = rightText.size(withAttributes: footerAttrs)
        rightText.draw(at: CGPoint(x: pageWidth - margin - rightSize.width, y: footerY), withAttributes: footerAttrs)
    }
    
    // MARK: - Currency Formatter
    
    func currencyFormatter() -> NumberFormatter {
        return NumberFormatter.appCurrency
    }
    
    // MARK: - Health Score
    
    func calculateHealthScore(summary: ReportSummary, invoices: InvoiceSummary?) -> Int {
        var score = 50 // Base score
        
        // Profitability (+/- 20 points)
        if summary.netIncome > 0 {
            score += min(20, Int(summary.profitMargin / 2))
        } else {
            score -= min(20, Int(abs(summary.profitMargin) / 2))
        }
        
        // Business expense ratio (+/- 10 points)
        if summary.businessExpenseRatio > 20 {
            score += 10
        }
        
        // Invoice health (+/- 20 points)
        if let invoices = invoices {
            if invoices.overdueCount == 0 {
                score += 10
            } else {
                score -= min(20, invoices.overdueCount * 5)
            }
            
            if let avgDays = invoices.averageDaysToPayment, avgDays < 30 {
                score += 10
            }
        }
        
        return max(0, min(100, score))
    }
    
    func getHealthScoreDescription(score: Int) -> String {
        switch score {
        case 80...100: return "Excellent - Your finances are in great shape!"
        case 60..<80: return "Good - Minor improvements could help"
        case 40..<60: return "Fair - Some areas need attention"
        case 20..<40: return "Needs Work - Review expenses and collections"
        default: return "Critical - Urgent financial review recommended"
        }
    }
}

#endif
