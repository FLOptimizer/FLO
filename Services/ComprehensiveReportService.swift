//  ComprehensiveReportService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - CPA-Ready Comprehensive Financial Reports (Fixed)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Fixed TaxSettings.effectiveTaxRate -> use customFederalRate or default 22%
//  ✅ Fixed BusinessProfile.businessAddress -> use formattedAddress
//  ✅ Fixed conditional binding on non-optional businessName
//  ✅ Fixed MainActor isolation for PDF drawing methods
//  ✅ Fixed UIFont attribute type annotations
//
//  FEATURES:
//  ✅ Professional cover page with business info
//  ✅ Executive summary with financial health score
//  ✅ Income & expense breakdown by category
//  ✅ Business vs Personal expense separation
//  ✅ Tax-deductible expense summary (IRS Schedule C ready)
//  ✅ Mileage log with IRS deduction calculations
//  ✅ Invoice summary (outstanding, paid, overdue)
//  ✅ Quarterly tax estimate breakdown
//  ✅ Monthly trend analysis
//  ✅ Detailed transaction listing
//  ✅ CPA preparation notes section
//

import Foundation
import SwiftData
#if !os(macOS)
import UIKit
#endif

// MARK: - Report Configuration

struct ReportConfiguration {
    let title: String
    let dateRange: ClosedRange<Date>
    let includePersonal: Bool
    let includeMileage: Bool
    let includeInvoices: Bool
    let includeDetailedTransactions: Bool
    let includeTaxEstimates: Bool
    let businessName: String?
    let businessAddress: String?
    let ein: String?
    let preparedFor: String?
    
    static func annual(year: Int, businessName: String? = nil) -> ReportConfiguration {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        
        return ReportConfiguration(
            title: "\(year) Annual Financial Report",
            dateRange: startOfYear...endOfYear,
            includePersonal: true,
            includeMileage: true,
            includeInvoices: true,
            includeDetailedTransactions: true,
            includeTaxEstimates: true,
            businessName: businessName,
            businessAddress: nil,
            ein: nil,
            preparedFor: nil
        )
    }
    
    static func quarterly(year: Int, quarter: Int, businessName: String? = nil) -> ReportConfiguration {
        let calendar = Calendar.current
        let startMonth = (quarter - 1) * 3 + 1
        let endMonth = startMonth + 2
        let startOfQuarter = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1))!
        let endOfQuarter = calendar.date(from: DateComponents(year: year, month: endMonth + 1, day: 0))!
        
        return ReportConfiguration(
            title: "Q\(quarter) \(year) Financial Report",
            dateRange: startOfQuarter...endOfQuarter,
            includePersonal: true,
            includeMileage: true,
            includeInvoices: true,
            includeDetailedTransactions: true,
            includeTaxEstimates: true,
            businessName: businessName,
            businessAddress: nil,
            ein: nil,
            preparedFor: nil
        )
    }
}

// MARK: - Report Data Models

struct ReportSummary {
    let totalIncome: Double
    let totalExpenses: Double
    let businessExpenses: Double
    let personalExpenses: Double
    let taxDeductibleExpenses: Double
    let netIncome: Double
    let transactionCount: Int
    let categoryBreakdown: [(category: String, amount: Double, percentage: Double)]
    let topExpenseCategories: [(category: String, amount: Double)]
    
    var profitMargin: Double {
        guard totalIncome > 0 else { return 0 }
        return (netIncome / totalIncome) * 100
    }
    
    var businessExpenseRatio: Double {
        guard totalExpenses > 0 else { return 0 }
        return (businessExpenses / totalExpenses) * 100
    }
}

struct MileageSummary {
    let totalMiles: Double
    let businessMiles: Double
    let personalMiles: Double
    let totalDeduction: Double
    let tripCount: Int
    let averageRate: Double
    let topPurposes: [(purpose: String, miles: Double, deduction: Double)]
}

struct InvoiceSummary {
    let totalInvoiced: Double
    let totalPaid: Double
    let totalOutstanding: Double
    let overdueAmount: Double
    let invoiceCount: Int
    let paidCount: Int
    let overdueCount: Int
    let averageDaysToPayment: Double?
}

struct QuarterlyTaxSummary {
    let quarter: Int
    let year: Int
    let estimatedIncome: Double
    let estimatedSelfEmploymentTax: Double
    let estimatedIncomeTax: Double
    let totalEstimatedTax: Double
    let dueDate: Date
    let isPastDue: Bool
}

struct MonthlyBreakdown: Identifiable {
    let id = UUID()
    let month: Date
    let monthLabel: String
    let income: Double
    let expenses: Double
    let businessExpenses: Double
    let netCashFlow: Double
}

// MARK: - Comprehensive Report Service

@MainActor
final class ComprehensiveReportService {
    
    static let shared = ComprehensiveReportService()
    static let version = "1.1"
    
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
        businessProfile: BusinessProfile?
    ) -> Result<Data, ReportError> {
        
        #if os(macOS)
        return .failure(.pdfGenerationFailed)
        #else
        
        // Filter data by date range
        let filteredTransactions = transactions.filter { config.dateRange.contains($0.date) }
        let filteredMileage = mileageTrips.filter { config.dateRange.contains($0.startDate) }
        let filteredInvoices = invoices.filter { config.dateRange.contains($0.issueDate) }
        
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
        
        // Generate PDF
        let pdfData = generatePDF(
            config: config,
            summary: reportSummary,
            mileage: mileageSummary,
            invoices: invoiceSummary,
            monthly: monthlyBreakdown,
            quarterlyTaxes: quarterlyTaxes,
            transactions: config.includeDetailedTransactions ? filteredTransactions : [],
            mileageTrips: config.includeMileage ? filteredMileage : [],
            businessProfile: businessProfile
        )
        
        if let data = pdfData {
            return .success(data)
        } else {
            return .failure(.pdfGenerationFailed)
        }
        
        #endif
    }
    
    // MARK: - Summary Calculations
    
    private func calculateReportSummary(transactions: [Transaction]) -> ReportSummary {
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
        
        return ReportSummary(
            totalIncome: income,
            totalExpenses: expenses,
            businessExpenses: businessExp,
            personalExpenses: personalExp,
            taxDeductibleExpenses: taxDeductible,
            netIncome: income - expenses,
            transactionCount: transactions.count,
            categoryBreakdown: breakdown,
            topExpenseCategories: Array(breakdown.prefix(5)).map { ($0.category, $0.amount) }
        )
    }
    
    private func calculateMileageSummary(trips: [MileageTrip]) -> MileageSummary {
        let businessTrips = trips.filter { $0.isBusinessTrip && $0.purpose != .needsReview }
        let personalTrips = trips.filter { !$0.isBusinessTrip || $0.purpose == .personal }
        
        let totalMiles = trips.reduce(0) { $0 + $1.distanceMiles }
        let businessMiles = businessTrips.reduce(0) { $0 + $1.distanceMiles }
        let personalMiles = personalTrips.reduce(0) { $0 + $1.distanceMiles }
        let totalDeduction = businessTrips.reduce(0) { $0 + $1.deductionAmount }
        
        // Average rate
        let avgRate = businessTrips.isEmpty ? 0.70 : businessTrips.reduce(0) { $0 + $1.mileageRate } / Double(businessTrips.count)
        
        // Top purposes
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
        
        // Average days to payment
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
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
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
    
    private func calculateQuarterlyTaxes(
        transactions: [Transaction],
        taxSettings: TaxSettings?,
        dateRange: ClosedRange<Date>
    ) -> [QuarterlyTaxSummary] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: dateRange.lowerBound)
        var results: [QuarterlyTaxSummary] = []
        
        let selfEmploymentRate = 0.153 // 15.3% SE tax
        // Use customFederalRate if set, otherwise default to 22%
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
            
            let income = quarterTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let businessExpenses = quarterTransactions.filter { !$0.isIncome && $0.financeType == .business }.reduce(0) { $0 + $1.amount }
            let netIncome = income - businessExpenses
            
            let seTax = max(0, netIncome * selfEmploymentRate)
            let incomeTax = max(0, netIncome * effectiveIncomeTaxRate)
            
            // Quarterly due dates
            let dueDates: [Int: (month: Int, day: Int)] = [
                1: (4, 15),   // Q1 due April 15
                2: (6, 15),   // Q2 due June 15
                3: (9, 15),   // Q3 due September 15
                4: (1, 15)    // Q4 due January 15 (next year)
            ]
            
            let dueYear = quarter == 4 ? year + 1 : year
            let dueComponents = dueDates[quarter]!
            let dueDate = calendar.date(from: DateComponents(year: dueYear, month: dueComponents.month, day: dueComponents.day)) ?? Date()
            
            results.append(QuarterlyTaxSummary(
                quarter: quarter,
                year: year,
                estimatedIncome: netIncome,
                estimatedSelfEmploymentTax: seTax,
                estimatedIncomeTax: incomeTax,
                totalEstimatedTax: seTax + incomeTax,
                dueDate: dueDate,
                isPastDue: Date() > dueDate
            ))
        }
        
        return results
    }
    
    // MARK: - PDF Generation
    
    #if !os(macOS)
    private func generatePDF(
        config: ReportConfiguration,
        summary: ReportSummary,
        mileage: MileageSummary?,
        invoices: InvoiceSummary?,
        monthly: [MonthlyBreakdown],
        quarterlyTaxes: [QuarterlyTaxSummary],
        transactions: [Transaction],
        mileageTrips: [MileageTrip],
        businessProfile: BusinessProfile?
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
    
    // MARK: - Drawing Helpers
    
    private func drawCoverPage(
        config: ReportConfiguration,
        businessProfile: BusinessProfile?,
        pageWidth: CGFloat,
        pageHeight: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        
        var y: CGFloat = pageHeight * 0.25
        
        // FLO Logo placeholder (teal circle with icon)
        let logoRect = CGRect(x: (pageWidth - 80) / 2, y: y - 100, width: 80, height: 80)
        UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 1.0).setFill() // Teal
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateRange = "\(dateFormatter.string(from: config.dateRange.lowerBound)) - \(dateFormatter.string(from: config.dateRange.upperBound))"
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
    
    private func drawSectionHeader(_ title: String, y: CGFloat, width: CGFloat, margin: CGFloat) -> CGFloat {
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
    
    private func drawExecutiveSummary(
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
    
    private func drawIncomeExpenseBreakdown(
        summary: ReportSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Income section
        let incomeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.systemGreen
        ]
        "INCOME".draw(at: CGPoint(x: margin, y: currentY), withAttributes: incomeAttrs)
        currentY += 25
        
        drawMetricRow("Total Income", value: formatter.string(from: NSNumber(value: summary.totalIncome)) ?? "$0", y: currentY, margin: margin, width: width)
        currentY += 25
        
        // Expense section
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
        
        // Net summary
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
    
    private func drawCategoryBreakdown(
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
        
        // Table rows
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
    
    private func drawTaxDeductibleSummary(
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
        
        // Deductible expenses
        let sectionAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "DEDUCTIBLE BUSINESS EXPENSES".draw(at: CGPoint(x: margin, y: currentY), withAttributes: sectionAttrs)
        currentY += 25
        
        drawMetricRow("Business Expenses (categorized)", value: formatter.string(from: NSNumber(value: summary.businessExpenses)) ?? "$0", y: currentY, margin: margin, width: width)
        currentY += 25
        
        // Mileage deduction
        if let mileage = mileage, mileage.totalDeduction > 0 {
            drawMetricRow("Mileage Deduction (\(String(format: "%.1f", mileage.businessMiles)) mi × $\(String(format: "%.3f", mileage.averageRate)))", value: formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0", y: currentY, margin: margin, width: width)
            currentY += 25
        }
        
        // Total
        currentY += 10
        UIColor.systemGreen.withAlphaComponent(0.1).setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: currentY, width: width, height: 40), cornerRadius: 4).fill()
        
        let totalDeductible = summary.taxDeductibleExpenses + (mileage?.totalDeduction ?? 0)
        
        let totalLabelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: UIColor.black
        ]
        "TOTAL POTENTIAL DEDUCTIONS".draw(at: CGPoint(x: margin + 15, y: currentY + 12), withAttributes: totalLabelAttrs)
        
        let totalStr = formatter.string(from: NSNumber(value: totalDeductible)) ?? "$0"
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.systemGreen
        ]
        let totalSize = totalStr.size(withAttributes: totalAttrs)
        totalStr.draw(at: CGPoint(x: margin + width - totalSize.width - 15, y: currentY + 10), withAttributes: totalAttrs)
        
        currentY += 60
        
        return currentY
    }
    
    private func drawMileageSummary(
        mileage: MileageSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Summary metrics
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
    
    private func drawMileageTripsTable(
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        // Header
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
            
            let from = trip.abbreviatedStartAddress
            String(from.prefix(18)).draw(at: CGPoint(x: margin + 55, y: currentY + 3), withAttributes: rowAttrs)
            
            let to = trip.abbreviatedEndAddress
            String(to.prefix(18)).draw(at: CGPoint(x: margin + 160, y: currentY + 3), withAttributes: rowAttrs)
            
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
    
    private func drawInvoiceSummary(
        invoices: InvoiceSummary,
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        
        // Summary metrics
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
        
        // Collection metrics
        if let avgDays = invoices.averageDaysToPayment {
            let collectionText = "Average Days to Payment: \(String(format: "%.0f", avgDays)) days"
            let collectionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            collectionText.draw(at: CGPoint(x: margin, y: currentY), withAttributes: collectionAttrs)
            currentY += 25
        }
        
        // Warning for overdue
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
    
    private func drawQuarterlyTaxTable(
        taxes: [QuarterlyTaxSummary],
        y: CGFloat,
        width: CGFloat,
        margin: CGFloat
    ) -> CGFloat {
        var currentY = y
        let formatter = currencyFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        // Info text
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
        
        // Total row
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
    
    private func drawMonthlyTable(
        monthly: [MonthlyBreakdown],
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
    
    private func drawCPANotes(
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
        
        // Generate contextual notes
        notes.append("📋 SCHEDULE C PREPARATION")
        notes.append("• Gross receipts (Line 1): \(formatter.string(from: NSNumber(value: summary.totalIncome)) ?? "$0")")
        notes.append("• Total business expenses: \(formatter.string(from: NSNumber(value: summary.businessExpenses)) ?? "$0")")
        
        if let mileage = mileage, mileage.totalDeduction > 0 {
            notes.append("• Vehicle expenses (Line 9): \(formatter.string(from: NSNumber(value: mileage.totalDeduction)) ?? "$0") (\(String(format: "%.1f", mileage.businessMiles)) business miles)")
        }
        
        notes.append("")
        notes.append("📝 ITEMS TO DISCUSS WITH YOUR CPA")
        
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
    
    private func drawTransactionTable(
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
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let sorted = transactions.sorted { $0.date > $1.date }
        
        // Table header
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
            // Check for page break
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
    
    private func drawDisclaimers(
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
    
    nonisolated private func drawPageFooter(pageNumber: Int, pageWidth: CGFloat, pageHeight: CGFloat, margin: CGFloat) {
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
    
    // MARK: - Helper Methods
    
    private func drawMetricRow(_ label: String, value: String, y: CGFloat, margin: CGFloat, width: CGFloat, indent: Bool = false, highlight: Bool = false) {
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
    
    private func currencyFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter
    }
    
    private func calculateHealthScore(summary: ReportSummary, invoices: InvoiceSummary?) -> Int {
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
    
    private func getHealthScoreDescription(score: Int) -> String {
        switch score {
        case 80...100: return "Excellent - Your finances are in great shape!"
        case 60..<80: return "Good - Minor improvements could help"
        case 40..<60: return "Fair - Some areas need attention"
        case 20..<40: return "Needs Work - Review expenses and collections"
        default: return "Critical - Urgent financial review recommended"
        }
    }
    
    #endif
    
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
