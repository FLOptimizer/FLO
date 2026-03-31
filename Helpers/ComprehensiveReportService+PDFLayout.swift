//  ComprehensiveReportService+PDFLayout.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Extracted from ComprehensiveReportService v2.0
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PDF page orchestrator: manages page flow, section ordering, and page breaks.
//  Each section's rendering is delegated to +Sections.swift.
//
//  PAGE ORDER:
//  1. Cover Page
//  2. Executive Summary
//  3. Income & Expense Breakdown + Categories
//  4. Tax-Deductible Expenses (Schedule C)
//  5. Mileage Log Summary (if included)
//  6. Invoice Summary (if included)
//  7. Equity & Transfers (if included)
//  8. Quarterly Tax Estimates
//  9. Monthly Breakdown
//  10. CPA Preparation Notes
//  11. Detailed Transaction List (if included)
//  12. Transfer Appendix — NEW v2.0 (if included)
//  13. Important Disclaimers
//

#if !os(macOS)
#if canImport(UIKit)
import UIKit
#endif

extension ComprehensiveReportService {
    
    // MARK: - PDF Generation Orchestrator
    
    /// Generates the complete PDF report by orchestrating all sections in order.
    /// Called from generateComprehensiveReport() in the core service file.
    func generatePDF(
        config: ReportConfiguration,
        summary: ReportSummary,
        mileage: MileageSummary?,
        invoices: InvoiceSummary?,
        monthly: [MonthlyBreakdown],
        quarterlyTaxes: [QuarterlyTaxSummary],
        transactions: [Transaction],
        transferTransactions: [Transaction],
        mileageTrips: [MileageTrip],
        businessProfile: BusinessProfile?,
        equityData: EquityData?
    ) -> Data? {
        
        let pageWidth: CGFloat = 612  // Letter size
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - (margin * 2)
        
        let pdfMetaData = [
            kCGPDFContextCreator: "FLO - Finance Ledger Optimizer",
            kCGPDFContextAuthor: businessProfile?.businessName ?? "FLO User",
            kCGPDFContextTitle: config.title
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        let data = renderer.pdfData { context in
            var currentY: CGFloat = margin
            var pageNumber = 1
            
            // Helper to start new page
            func startNewPage() {
                context.beginPage()
                currentY = margin
                pageNumber += 1
            }
            
            // Helper to check if we need a new page
            func checkPageBreak(neededHeight: CGFloat) {
                if currentY + neededHeight > pageHeight - margin - 30 {
                    self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
                    startNewPage()
                }
            }
            
            // ==========================================
            // PAGE 1: COVER PAGE
            // ==========================================
            context.beginPage()
            
            currentY = self.drawCoverPage(
                config: config,
                businessProfile: businessProfile,
                pageWidth: pageWidth,
                pageHeight: pageHeight,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            
            // ==========================================
            // PAGE 2: EXECUTIVE SUMMARY
            // ==========================================
            startNewPage()
            
            currentY = self.drawSectionHeader("EXECUTIVE SUMMARY", y: currentY, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawExecutiveSummary(
                summary: summary,
                mileage: mileage,
                invoices: invoices,
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            
            // ==========================================
            // PAGE 3: INCOME & EXPENSE BREAKDOWN
            // ==========================================
            startNewPage()
            
            currentY = self.drawSectionHeader("INCOME & EXPENSE BREAKDOWN", y: currentY, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawIncomeExpenseBreakdown(
                summary: summary,
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            checkPageBreak(neededHeight: 250)
            
            currentY = self.drawSectionHeader("EXPENSE CATEGORIES", y: currentY + 30, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawCategoryBreakdown(
                categories: summary.categoryBreakdown,
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            
            // ==========================================
            // PAGE 4: TAX-DEDUCTIBLE EXPENSES
            // ==========================================
            startNewPage()
            
            currentY = self.drawSectionHeader("TAX-DEDUCTIBLE EXPENSES (Schedule C)", y: currentY, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawTaxDeductibleSummary(
                summary: summary,
                mileage: mileage,
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            
            // ==========================================
            // MILEAGE SUMMARY (if included)
            // ==========================================
            if let mileageSummary = mileage, mileageSummary.tripCount > 0 {
                startNewPage()
                
                currentY = self.drawSectionHeader("MILEAGE LOG SUMMARY", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawMileageSummary(
                    mileage: mileageSummary,
                    y: currentY,
                    width: contentWidth,
                    margin: margin
                )
                
                // Draw mileage trips table
                if !mileageTrips.isEmpty {
                    checkPageBreak(neededHeight: 200)
                    currentY += 30
                    currentY = self.drawMileageTripsTable(
                        trips: mileageTrips,
                        y: currentY,
                        width: contentWidth,
                        margin: margin,
                        pageHeight: pageHeight,
                        context: context,
                        pageNumber: &pageNumber
                    )
                }
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // INVOICE SUMMARY (if included)
            // ==========================================
            if let invoiceSummary = invoices, invoiceSummary.invoiceCount > 0 {
                startNewPage()
                
                currentY = self.drawSectionHeader("INVOICE SUMMARY", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawInvoiceSummary(
                    invoices: invoiceSummary,
                    y: currentY,
                    width: contentWidth,
                    margin: margin
                )
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // EQUITY & TRANSFERS SECTION (v1.3)
            // ==========================================
            if config.includeEquityTransfers, let equityData = equityData {
                startNewPage()
                
                currentY = self.drawSectionHeader("EQUITY & TRANSFERS", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawEquitySection(
                    equityData: equityData,
                    dateRange: config.dateRange,
                    y: currentY,
                    width: contentWidth,
                    margin: margin
                )
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // QUARTERLY TAX ESTIMATES
            // ==========================================
            if !quarterlyTaxes.isEmpty {
                startNewPage()
                
                currentY = self.drawSectionHeader("QUARTERLY TAX ESTIMATES", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawQuarterlyTaxTable(
                    taxes: quarterlyTaxes,
                    y: currentY,
                    width: contentWidth,
                    margin: margin
                )
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // MONTHLY BREAKDOWN
            // ==========================================
            if !monthly.isEmpty {
                startNewPage()
                
                currentY = self.drawSectionHeader("MONTHLY BREAKDOWN", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawMonthlyTable(
                    monthly: monthly,
                    y: currentY,
                    width: contentWidth,
                    margin: margin
                )
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // CPA PREPARATION NOTES
            // ==========================================
            startNewPage()
            
            currentY = self.drawSectionHeader("CPA PREPARATION NOTES", y: currentY, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawCPANotes(
                summary: summary,
                mileage: mileage,
                invoices: invoices,
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            
            // ==========================================
            // DETAILED TRANSACTIONS (if included)
            // ==========================================
            if !transactions.isEmpty {
                startNewPage()
                
                currentY = self.drawSectionHeader("DETAILED TRANSACTION LIST", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                self.drawTransactionTable(
                    transactions: transactions,
                    startY: currentY,
                    width: contentWidth,
                    margin: margin,
                    pageHeight: pageHeight,
                    context: context,
                    pageNumber: &pageNumber
                )
            }
            
            // ==========================================
            // TRANSFER APPENDIX — NEW v2.0
            // ==========================================
            if config.includeTransferAppendix && !transferTransactions.isEmpty {
                startNewPage()
                
                currentY = self.drawSectionHeader("APPENDIX: TRANSFER RECONCILIATION", y: currentY, width: contentWidth, margin: margin)
                currentY += 20
                
                currentY = self.drawTransferAppendix(
                    transfers: transferTransactions,
                    dateRange: config.dateRange,
                    y: currentY,
                    width: contentWidth,
                    margin: margin,
                    pageHeight: pageHeight,
                    context: context,
                    pageNumber: &pageNumber
                )
                
                self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
            }
            
            // ==========================================
            // FINAL PAGE: DISCLAIMER
            // ==========================================
            startNewPage()
            
            currentY = self.drawSectionHeader("IMPORTANT DISCLAIMERS", y: currentY, width: contentWidth, margin: margin)
            currentY += 20
            
            currentY = self.drawDisclaimers(
                y: currentY,
                width: contentWidth,
                margin: margin
            )
            
            self.drawPageFooter(pageNumber: pageNumber, pageWidth: pageWidth, pageHeight: pageHeight, margin: margin)
        }
        
        return data
    }
}

#endif
