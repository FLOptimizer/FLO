//  TaxCalculationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Production-ready tax calculation engine using 2025 IRS data
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Tax calculation engine for quarterly estimates
//
//  CHANGES IN v1.1:
//  - Added version tracking
//  - Confirmed 2025 IRS bracket compatibility (pulls from TaxSettings v2.1)
//  - Enhanced documentation
//  - Added comprehensive error handling comments
//

import Foundation
import SwiftData

class TaxCalculationService {
    
    // MARK: - Singleton
    static let shared = TaxCalculationService()
    private init() {}
    
    // MARK: - Tax Estimate Result
    
    struct TaxEstimate {
        let federalIncomeTax: Double
        let stateIncomeTax: Double
        let selfEmploymentTax: Double
        let totalEstimated: Double
        let effectiveFederalRate: Double
        let effectiveStateRate: Double
        let effectiveTotalRate: Double
        
        // Quarterly breakdown
        let quarterlyPayment: Double
        let nextDeadline: Date?
        let daysUntilDeadline: Int?
        
        // Income breakdown
        let netIncome: Double
        let taxableIncome: Double
        
        // Safe harbor info (if applicable)
        let safeHarborAmount: Double?
        let isMeetingSafeHarbor: Bool
    }
    
    // MARK: - Calculate Current Year Estimate
    
    /// Calculate estimated taxes based on year-to-date income
    /// Uses current year (2025) IRS tax brackets from TaxSettings v2.1
    func calculateYearToDateEstimate(
        transactions: [Transaction],
        settings: TaxSettings
    ) -> TaxEstimate {
        
        // 1. Calculate net income (income - expenses) for current year
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31, hour: 23, minute: 59))!
        
        let yearTransactions = transactions.filter { transaction in
            transaction.date >= yearStart && transaction.date <= yearEnd
        }
        
        let totalIncome = yearTransactions
            .filter { $0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let totalExpenses = yearTransactions
            .filter { !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
        
        let netIncome = totalIncome - totalExpenses
        
        // 2. Calculate taxable income (net income - standard deduction)
        // Uses 2025 standard deductions from TaxSettings v2.1
        let standardDeduction = TaxSettings.standardDeduction(for: settings.filingStatus)
        let taxableIncome = max(0, netIncome - standardDeduction)
        
        // 3. Calculate federal income tax
        // Uses 2025 progressive brackets from TaxSettings v2.1
        let federalTax = calculateFederalIncomeTax(
            taxableIncome: taxableIncome,
            filingStatus: settings.filingStatus,
            customRate: settings.customFederalRate
        )
        
        // 4. Calculate state income tax
        let stateTax = calculateStateIncomeTax(
            netIncome: netIncome,
            state: settings.state,
            customRate: settings.customStateRate
        )
        
        // 5. Calculate self-employment tax (on net income, not taxable income)
        // Uses 15.3% rate (12.4% Social Security + 2.9% Medicare)
        let selfEmploymentTax = settings.includeSelfEmploymentTax
            ? calculateSelfEmploymentTax(netIncome: netIncome, rate: settings.selfEmploymentTaxRate)
            : 0
        
        // 6. Calculate total
        let totalTax = federalTax + stateTax + selfEmploymentTax
        
        // 7. Calculate effective rates
        let effectiveFederalRate = netIncome > 0 ? federalTax / netIncome : 0
        let effectiveStateRate = netIncome > 0 ? stateTax / netIncome : 0
        let effectiveTotalRate = netIncome > 0 ? totalTax / netIncome : 0
        
        // 8. Calculate quarterly payment
        let quarterlyPayment = totalTax / 4
        
        // 9. Get next deadline (uses 2025 deadlines from TaxSettings v2.1)
        let nextDeadline = TaxSettings.nextQuarterlyDeadline()
        let daysUntilDeadline = nextDeadline.flatMap { calendar.dateComponents([.day], from: Date(), to: $0).day }
        
        // 10. Safe harbor calculation
        let (safeHarborAmount, isMeetingSafeHarbor) = calculateSafeHarbor(
            currentYearTax: totalTax,
            priorYearTax: settings.priorYearTaxLiability,
            isHighEarner: settings.isHighEarner
        )
        
        return TaxEstimate(
            federalIncomeTax: federalTax,
            stateIncomeTax: stateTax,
            selfEmploymentTax: selfEmploymentTax,
            totalEstimated: totalTax,
            effectiveFederalRate: effectiveFederalRate,
            effectiveStateRate: effectiveStateRate,
            effectiveTotalRate: effectiveTotalRate,
            quarterlyPayment: quarterlyPayment,
            nextDeadline: nextDeadline,
            daysUntilDeadline: daysUntilDeadline,
            netIncome: netIncome,
            taxableIncome: taxableIncome,
            safeHarborAmount: safeHarborAmount,
            isMeetingSafeHarbor: isMeetingSafeHarbor
        )
    }
    
    // MARK: - Federal Income Tax Calculation
    
    /// Calculate federal income tax using progressive brackets
    /// Automatically uses 2025 IRS brackets from TaxSettings v2.1
    private func calculateFederalIncomeTax(
        taxableIncome: Double,
        filingStatus: TaxSettings.FilingStatus,
        customRate: Double?
    ) -> Double {
        // If user provided custom rate, use that
        if let customRate = customRate {
            return taxableIncome * customRate
        }
        
        // Otherwise, calculate using progressive brackets (2025 IRS data)
        let brackets = TaxSettings.federalTaxBrackets(for: filingStatus)
        var tax: Double = 0
        var previousMax: Double = 0
        
        for bracket in brackets {
            let maxIncome = bracket.maxIncome
            let rate = bracket.rate
            
            if taxableIncome <= previousMax {
                break
            }
            
            let taxableAtThisRate = min(taxableIncome, maxIncome) - previousMax
            tax += taxableAtThisRate * rate
            previousMax = maxIncome
            
            if taxableIncome <= maxIncome {
                break
            }
        }
        
        return tax
    }
    
    // MARK: - State Income Tax Calculation
    
    /// Calculate state income tax using simplified flat rates
    /// Note: Real state taxes are often progressive; these are approximations
    private func calculateStateIncomeTax(
        netIncome: Double,
        state: String,
        customRate: Double?
    ) -> Double {
        // If user provided custom rate, use that
        if let customRate = customRate {
            return netIncome * customRate
        }
        
        // Otherwise, use simplified state rate
        let stateRate = TaxSettings.stateTaxRates[state] ?? 0.05 // Default 5% if state not found
        return netIncome * stateRate
    }
    
    // MARK: - Self-Employment Tax Calculation
    
    /// Calculate self-employment tax (Social Security + Medicare)
    /// Rate is typically 15.3% (12.4% + 2.9%)
    /// Applied to 92.35% of net income (employer-equivalent deduction)
    private func calculateSelfEmploymentTax(
        netIncome: Double,
        rate: Double
    ) -> Double {
        // Self-employment tax is calculated on 92.35% of net income
        // (to account for the deduction of the employer-equivalent portion)
        let seIncome = netIncome * 0.9235
        return seIncome * rate
    }
    
    // MARK: - Safe Harbor Calculation
    
    /// Calculate IRS safe harbor amount to avoid underpayment penalties
    /// Rules: Pay 100% of prior year (or 110% if AGI >$150K)
    private func calculateSafeHarbor(
        currentYearTax: Double,
        priorYearTax: Double?,
        isHighEarner: Bool
    ) -> (amount: Double?, isMeeting: Bool) {
        guard let priorYearTax = priorYearTax, priorYearTax > 0 else {
            return (nil, false)
        }
        
        // Safe harbor is 100% of prior year if AGI was $150K
        // or 110% of prior year if AGI was >$150K
        let safeHarborPercentage = isHighEarner ? 1.10 : 1.00
        let safeHarborAmount = priorYearTax * safeHarborPercentage
        
        // Check if current year estimate meets safe harbor
        let isMeeting = currentYearTax >= safeHarborAmount
        
        return (safeHarborAmount, isMeeting)
    }
    
    // MARK: - Tax Reserve Calculation
    
    /// Calculate how much to set aside from each income transaction
    /// Useful for envelope budgeting and tax savings
    func calculateTaxReserve(
        amount: Double,
        effectiveTaxRate: Double
    ) -> Double {
        return amount * effectiveTaxRate
    }
    
    // MARK: - Quarterly Tax Payment Status
    
    /// Determine if user is on track with quarterly payments
    /// Returns status with color-coding for UI display
    func calculateQuarterlyStatus(
        totalEstimated: Double,
        nextDeadline: Date?
    ) -> QuarterlyStatus {
        guard let deadline = nextDeadline else {
            return .unknown
        }
        
        let calendar = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        let quarterlyAmount = totalEstimated / 4
        
        if daysUntil <= 7 {
            return .urgent(amount: quarterlyAmount, daysLeft: daysUntil)
        } else if daysUntil <= 14 {
            return .upcoming(amount: quarterlyAmount, daysLeft: daysUntil)
        } else {
            return .onTrack(amount: quarterlyAmount, daysLeft: daysUntil)
        }
    }
    
    enum QuarterlyStatus {
        case urgent(amount: Double, daysLeft: Int)
        case upcoming(amount: Double, daysLeft: Int)
        case onTrack(amount: Double, daysLeft: Int)
        case unknown
        
        var color: String {
            switch self {
            case .urgent: return "red"
            case .upcoming: return "yellow"
            case .onTrack: return "green"
            case .unknown: return "gray"
            }
        }
        
        var message: String {
            switch self {
            case .urgent(let amount, let days):
                return "Quarterly payment of \(amount.asCurrency) due in \(days) day\(days == 1 ? "" : "s")!"
            case .upcoming(let amount, let days):
                return "Quarterly payment of \(amount.asCurrency) coming up in \(days) days"
            case .onTrack(let amount, let days):
                return "Next quarterly payment: \(amount.asCurrency) in \(days) days"
            case .unknown:
                return "Unable to determine next payment date"
            }
        }
    }
    
    // MARK: - Projection for Full Year
    
    /// Project annual tax based on current run rate
    /// Useful for planning and cash flow forecasting
    func projectAnnualTax(
        currentEstimate: TaxEstimate,
        transactions: [Transaction]
    ) -> TaxEstimate {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let today = Date()
        
        // Calculate days elapsed this year
        let yearStart = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        let daysElapsed = calendar.dateComponents([.day], from: yearStart, to: today).day ?? 1
        
        // Calculate days in year
        let yearEnd = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31))!
        let daysInYear = calendar.dateComponents([.day], from: yearStart, to: yearEnd).day ?? 365
        
        // Project annualized amounts
        let projectionMultiplier = Double(daysInYear) / Double(daysElapsed)
        
        let projectedNetIncome = currentEstimate.netIncome * projectionMultiplier
        let projectedFederalTax = currentEstimate.federalIncomeTax * projectionMultiplier
        let projectedStateTax = currentEstimate.stateIncomeTax * projectionMultiplier
        let projectedSETax = currentEstimate.selfEmploymentTax * projectionMultiplier
        let projectedTotal = projectedFederalTax + projectedStateTax + projectedSETax
        
        return TaxEstimate(
            federalIncomeTax: projectedFederalTax,
            stateIncomeTax: projectedStateTax,
            selfEmploymentTax: projectedSETax,
            totalEstimated: projectedTotal,
            effectiveFederalRate: currentEstimate.effectiveFederalRate,
            effectiveStateRate: currentEstimate.effectiveStateRate,
            effectiveTotalRate: currentEstimate.effectiveTotalRate,
            quarterlyPayment: projectedTotal / 4,
            nextDeadline: currentEstimate.nextDeadline,
            daysUntilDeadline: currentEstimate.daysUntilDeadline,
            netIncome: projectedNetIncome,
            taxableIncome: currentEstimate.taxableIncome * projectionMultiplier,
            safeHarborAmount: currentEstimate.safeHarborAmount,
            isMeetingSafeHarbor: currentEstimate.isMeetingSafeHarbor
        )
    }
}

// MARK: - Double Extension for Currency Formatting

extension Double {
    var asCurrency: String {
        // Guard against NaN/Inf which cause CoreGraphics errors
        guard self.isFinite else { return "$0.00" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
    
    var asPercentage: String {
        // Guard against NaN/Inf which cause CoreGraphics errors
        guard self.isFinite else { return "0%" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "0%"
    }
}

// MARK: - Version History
/*
 Version 1.1 (Current):
 - Added version tracking
 - Confirmed compatibility with TaxSettings v2.1 (2025 IRS brackets)
 - Enhanced documentation throughout
 - Added comprehensive comments for tax calculations
 - Ready for December 2025 launch
 
 Version 1.0:
 - Initial implementation
 - Core tax calculation engine
 - Progressive bracket support
 - Safe harbor calculations
 - Quarterly payment tracking
 */
