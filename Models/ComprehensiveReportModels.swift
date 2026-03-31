//  ComprehensiveReportModels.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Extracted from ComprehensiveReportService v1.5
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  All data models used by the Comprehensive Report system.
//  Extracted for maintainability — no logic changes from v1.5.
//
//  CONTENTS:
//  ✅ ReportConfiguration — report generation settings
//  ✅ ReportSummary — calculated financial summary with Schedule C breakdown
//  ✅ EquityData — owner's draws, contributions, tax payments
//  ✅ MileageSummary — mileage log totals and deductions
//  ✅ InvoiceSummary — invoice totals and collection metrics
//  ✅ QuarterlyTaxSummary — quarterly estimated tax breakdown
//  ✅ MonthlyBreakdown — month-by-month income/expense/cash flow
//

import Foundation

// MARK: - Report Configuration

struct ReportConfiguration {
    let title: String
    let dateRange: ClosedRange<Date>
    let includePersonal: Bool
    let includeMileage: Bool
    let includeInvoices: Bool
    let includeDetailedTransactions: Bool
    let includeTaxEstimates: Bool
    let includeEquityTransfers: Bool
    let includeTransferAppendix: Bool = true
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
            includeEquityTransfers: true,
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
            includeEquityTransfers: true,
            businessName: businessName,
            businessAddress: nil,
            ein: nil,
            preparedFor: nil
        )
    }
}

// MARK: - Report Summary

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
    
    /// v1.5 — Schedule C line-by-line breakdown for CPA-ready reports.
    /// Each entry groups deductible expenses by their IRS Schedule C line number.
    /// Categories without a scheduleCLine are grouped under lineLabel "Other (Unassigned)".
    let scheduleCBreakdown: [(lineLabel: String, lineNumber: String, categories: [String], grossAmount: Double, deductibleAmount: Double)]
    
    var profitMargin: Double {
        guard totalIncome > 0 else { return 0 }
        return (netIncome / totalIncome) * 100
    }
    
    var businessExpenseRatio: Double {
        guard totalExpenses > 0 else { return 0 }
        return (businessExpenses / totalExpenses) * 100
    }
}

// MARK: - Equity Data (v1.4)

struct EquityData {
    let ytdDraws: Double
    let ytdContributions: Double
    let ytdTaxPaymentsFederal: Double
    let ytdTaxPaymentsState: Double
    
    var ytdTaxPaymentsTotal: Double {
        ytdTaxPaymentsFederal + ytdTaxPaymentsState
    }
    
    var netEquityChange: Double {
        ytdContributions - ytdDraws
    }
}

// MARK: - Mileage Summary

struct MileageSummary {
    let totalMiles: Double
    let businessMiles: Double
    let personalMiles: Double
    let totalDeduction: Double
    let tripCount: Int
    let averageRate: Double
    let topPurposes: [(purpose: String, miles: Double, deduction: Double)]
}

// MARK: - Invoice Summary

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

// MARK: - Quarterly Tax Summary

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

// MARK: - Monthly Breakdown

struct MonthlyBreakdown: Identifiable {
    let id = UUID()
    let month: Date
    let monthLabel: String
    let income: Double
    let expenses: Double
    let businessExpenses: Double
    let netCashFlow: Double
}
