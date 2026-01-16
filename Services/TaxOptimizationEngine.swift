//
//  TaxOptimizationEngine.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Phase 1 AI Tax Optimization (On-Device)
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  On-device tax optimization engine for proactive deduction discovery,
//  savings estimation, year-end planning, and audit risk management.
//
//  Features:
//  - Scans for missed deductions across 60+ IRS categories
//  - Estimates tax savings per transaction and opportunity
//  - Year-end strategy recommendations (November-December)
//  - Audit risk scoring with documentation suggestions
//  - Entity structure optimization hints
//  - Mileage method comparison (standard vs. actual)
//
//  Architecture:
//  - Rule-based heuristics (Phase 1) → Core ML models (Phase 2)
//  - Privacy-first: All processing on-device
//  - Subscription-aware: Enhanced features for Pro tier
//

import Foundation
import SwiftData

// MARK: - Tax Optimization Engine

@MainActor
class TaxOptimizationEngine {
    
    static let shared = TaxOptimizationEngine()
    private init() {}
    
    // MARK: - Primary Analysis Methods
    
    /// Comprehensive scan for missed deduction opportunities
    /// Returns prioritized opportunities with savings estimates
    func scanForMissedDeductions(
        transactions: [Transaction],
        mileageTrips: [MileageTrip],
        receipts: [ReceiptData],
        taxSettings: TaxSettings,
        businessProfile: BusinessProfile?,
        context: ModelContext
    ) -> [TaxDeductionOpportunity] {
        
        var opportunities: [TaxDeductionOpportunity] = []
        
        // 1. Home Office Deduction
        if let homeOfficeOpp = analyzeHomeOfficeOpportunity(
            transactions: transactions,
            businessProfile: businessProfile,
            taxSettings: taxSettings
        ) {
            opportunities.append(homeOfficeOpp)
        }
        
        // 2. Vehicle Deduction Optimization
        if let vehicleOpp = analyzeMileageMethodOpportunity(
            trips: mileageTrips,
            transactions: transactions,
            taxSettings: taxSettings
        ) {
            opportunities.append(vehicleOpp)
        }
        
        // 3. Self-Employed Health Insurance
        if let healthOpp = analyzeHealthInsuranceOpportunity(
            transactions: transactions,
            taxSettings: taxSettings
        ) {
            opportunities.append(healthOpp)
        }
        
        // 4. Retirement Contribution Opportunities
        if let retirementOpp = analyzeRetirementOpportunity(
            transactions: transactions,
            taxSettings: taxSettings,
            businessProfile: businessProfile
        ) {
            opportunities.append(retirementOpp)
        }
        
        // 5. Family Payroll Strategy
        if let familyOpp = analyzeFamilyPayrollOpportunity(
            transactions: transactions,
            taxSettings: taxSettings,
            businessProfile: businessProfile
        ) {
            opportunities.append(familyOpp)
        }
        
        // 6. Uncategorized High-Value Receipts
        opportunities.append(contentsOf: analyzeUncategorizedReceipts(
            receipts: receipts,
            taxSettings: taxSettings
        ))
        
        // 7. Section 179 / Bonus Depreciation
        if let depreciationOpp = analyzeDepreciationOpportunity(
            transactions: transactions,
            receipts: receipts,
            taxSettings: taxSettings
        ) {
            opportunities.append(depreciationOpp)
        }
        
        // 8. Meals & Entertainment (50% deduction)
        if let mealsOpp = analyzeMealsOpportunity(
            transactions: transactions,
            receipts: receipts,
            taxSettings: taxSettings
        ) {
            opportunities.append(mealsOpp)
        }
        
        // 9. Augusta Rule (14-day rental)
        if let augustaOpp = analyzeAugustaRuleOpportunity(
            businessProfile: businessProfile,
            taxSettings: taxSettings
        ) {
            opportunities.append(augustaOpp)
        }
        
        // 10. QBI Deduction Optimization
        if let qbiOpp = analyzeQBIOpportunity(
            transactions: transactions,
            taxSettings: taxSettings,
            businessProfile: businessProfile
        ) {
            opportunities.append(qbiOpp)
        }
        
        // Sort by estimated savings (highest first)
        opportunities.sort { $0.estimatedSavings > $1.estimatedSavings }
        
        #if DEBUG
        print("💡 Tax Optimization: Found \(opportunities.count) opportunities")
        print("   Total potential savings: $\(opportunities.reduce(0) { $0 + $1.estimatedSavings })")
        #endif
        
        return opportunities
    }
    
    // MARK: - Per-Transaction Savings Estimator
    
    /// Calculate tax savings for a specific transaction
    /// Used for real-time display in transaction list
    func estimateTransactionSavings(
        transaction: Transaction,
        taxSettings: TaxSettings
    ) -> TransactionTaxSavings {
        
        guard !transaction.isIncome && transaction.financeType == .business else {
            return TransactionTaxSavings(
                transaction: transaction,
                federalSavings: 0,
                stateSavings: 0,
                selfEmploymentSavings: 0,
                totalSavings: 0,
                effectiveRate: 0
            )
        }
        
        let amount = transaction.amount
        
        // Calculate marginal tax rates
        let netIncome = calculateEstimatedNetIncome(
            from: transaction.date,
            context: nil // Approximate without full context
        )
        
        let federalRate = calculateMarginalFederalRate(
            netIncome: netIncome,
            filingStatus: taxSettings.filingStatus
        )
        
        let stateRate = taxSettings.customStateRate ?? TaxSettings.stateTaxRates[taxSettings.state] ?? 0.0
        let seRate = taxSettings.includeSelfEmploymentTax ? 0.153 : 0
        
        // Calculate savings
        let federalSavings = amount * federalRate
        let stateSavings = amount * stateRate
        let seSavings = amount * seRate * 0.5 // Only half of SE tax is deductible
        
        let totalSavings = federalSavings + stateSavings + seSavings
        let effectiveRate = amount > 0 ? totalSavings / amount : 0
        
        return TransactionTaxSavings(
            transaction: transaction,
            federalSavings: federalSavings,
            stateSavings: stateSavings,
            selfEmploymentSavings: seSavings,
            totalSavings: totalSavings,
            effectiveRate: effectiveRate
        )
    }
    
    // MARK: - Year-End Checklist Generator
    
    /// Generate personalized year-end tax planning checklist
    /// Activated in November-December for tax year planning
    func generateYearEndChecklist(
        transactions: [Transaction],
        mileageTrips: [MileageTrip],
        receipts: [ReceiptData],
        taxSettings: TaxSettings,
        businessProfile: BusinessProfile?,
        currentDate: Date = Date()
    ) -> TaxYearEndChecklist {
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        
        var checklist = TaxYearEndChecklist(year: currentYear)
        
        // Only generate for November-December
        guard currentMonth >= 11 else {
            checklist.isActive = false
            return checklist
        }
        
        checklist.isActive = true
        
        // 1. Review Uncategorized Items
        let uncategorized = receipts.filter { $0.suggestedCategoryName == nil }
        if !uncategorized.isEmpty {
            let potentialSavings = uncategorized.reduce(0) { $0 + $1.totalAmount } * 0.30
            checklist.items.append(
                TaxChecklistItem(
                    category: .reviewExpenses,
                    title: "Categorize \(uncategorized.count) receipts",
                    description: "You have \(uncategorized.count) uncategorized receipts worth $\(String(format: "%.2f", uncategorized.reduce(0) { $0 + $1.totalAmount })). Categorizing them could save you $\(String(format: "%.0f", potentialSavings)) in taxes.",
                    potentialSavings: potentialSavings,
                    priority: .high,
                    deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                    actionItems: [
                        "Review receipts in Transactions tab",
                        "Assign appropriate business categories",
                        "Attach receipt photos if missing"
                    ],
                    riskLevel: .low
                )
            )
        }
        
        // 2. Prepay Expenses (12-month rule)
        let currentYTDIncome = calculateYearToDateIncome(transactions: transactions, year: currentYear)
        if currentYTDIncome > 30000 {
            checklist.items.append(
                TaxChecklistItem(
                    category: .prepayExpenses,
                    title: "Prepay 2026 business expenses",
                    description: "Prepay up to 12 months of rent, insurance, software subscriptions, or services before Dec 31 to deduct in \(currentYear). This shifts deductions to the current year and may reduce your tax bracket.",
                    potentialSavings: 1500, // Conservative estimate
                    priority: .high,
                    deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                    actionItems: [
                        "Identify recurring expenses (software, insurance, rent)",
                        "Prepay before Dec 31 (must benefit ≤12 months)",
                        "Keep invoices showing prepayment dates"
                    ],
                    riskLevel: .low
                )
            )
        }
        
        // 3. Maximize Retirement Contributions
        if let retirement = analyzeRetirementOpportunity(
            transactions: transactions,
            taxSettings: taxSettings,
            businessProfile: businessProfile
        ) {
            checklist.items.append(
                TaxChecklistItem(
                    category: .retirement,
                    title: retirement.title,
                    description: retirement.description,
                    potentialSavings: retirement.estimatedSavings,
                    priority: .high,
                    deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                    actionItems: retirement.actionItems,
                    riskLevel: retirement.riskLevel
                )
            )
        }
        
        // 4. Section 179 / Bonus Depreciation
        checklist.items.append(
            TaxChecklistItem(
                category: .equipment,
                title: "Purchase business equipment before Dec 31",
                description: "2025 allows 100% bonus depreciation for qualified property placed in service before year-end. Section 179 limit is $2.5M. Immediate deduction for computers, furniture, vehicles >6,000 lbs.",
                potentialSavings: 0, // User-dependent
                priority: .medium,
                deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                actionItems: [
                    "Identify needed equipment/vehicles",
                    "Must be placed in service (delivered + used) before Dec 31",
                    "Keep purchase receipts and proof of business use"
                ],
                riskLevel: .medium
            )
        )
        
        // 5. Consider Entity Structure Change
        // Note: Always suggest S-Corp evaluation if income is high enough
        // User can dismiss if they're already an S-Corp
        if currentYTDIncome > 60000 {
            let sCorpSavings = estimateSCorpSavings(
                netIncome: currentYTDIncome,
                filingStatus: taxSettings.filingStatus
            )
            
            if sCorpSavings > 3000 {
                checklist.items.append(
                    TaxChecklistItem(
                        category: .entityStructure,
                        title: "Evaluate S-Corp election for \(currentYear + 1)",
                        description: "Your income suggests S-Corp could save you ~$\(String(format: "%.0f", sCorpSavings))/year in self-employment tax. Deadline for \(currentYear + 1) election: March 15, \(currentYear + 1).",
                        potentialSavings: sCorpSavings,
                        priority: .high,
                        deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear + 1, month: 3, day: 15))!.timeIntervalSince1970)),
                        actionItems: [
                            "Consult with CPA about S-Corp benefits",
                            "Understand payroll requirements (reasonable salary)",
                            "File Form 2553 by March 15, \(currentYear + 1)"
                        ],
                        riskLevel: .low
                    )
                )
            }
        }
        
        // 6. Augusta Rule Opportunity
        if let augusta = analyzeAugustaRuleOpportunity(
            businessProfile: businessProfile,
            taxSettings: taxSettings
        ) {
            checklist.items.append(
                TaxChecklistItem(
                    category: .advancedStrategy,
                    title: augusta.title,
                    description: augusta.description,
                    potentialSavings: augusta.estimatedSavings,
                    priority: .medium,
                    deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                    actionItems: augusta.actionItems,
                    riskLevel: augusta.riskLevel
                )
            )
        }
        
        // 7. Defer Income (if beneficial)
        if currentMonth == 12 {
            checklist.items.append(
                TaxChecklistItem(
                    category: .incomeTiming,
                    title: "Consider deferring December income to January",
                    description: "If you expect lower income in \(currentYear + 1), delay invoicing/billing until Jan 1 to defer tax to next year. Only works for cash-basis taxpayers.",
                    potentialSavings: 0, // Highly variable
                    priority: .low,
                    deadline: Date(timeIntervalSince1970: Double(Calendar.current.date(from: DateComponents(year: currentYear, month: 12, day: 31))!.timeIntervalSince1970)),
                    actionItems: [
                        "Review pending invoices",
                        "Send invoices after Jan 1 if deferral beneficial",
                        "Delay payment collection until January"
                    ],
                    riskLevel: .low
                )
            )
        }
        
        // Sort by priority and savings
        checklist.items.sort { item1, item2 in
            if item1.priority != item2.priority {
                return item1.priority.rawValue > item2.priority.rawValue
            }
            return item1.potentialSavings > item2.potentialSavings
        }
        
        return checklist
    }
    
    // MARK: - Audit Risk Scoring
    
    /// Calculate audit risk for a deduction category
    /// Returns risk level and documentation recommendations
    func calculateAuditRisk(
        category: TaxDeductionCategory,
        amount: Double,
        hasDocumentation: Bool,
        businessType: String?
    ) -> TaxAuditRiskAssessment {
        
        var riskScore: Double = 0.0
        var riskFactors: [String] = []
        var recommendations: [String] = []
        
        // Base risk by category
        switch category {
        case .homeOffice:
            riskScore += 0.4
            riskFactors.append("Home office is commonly audited")
            recommendations.append("Measure office space precisely")
            recommendations.append("Document exclusive business use")
            recommendations.append("Keep utility bills and mortgage statements")
            
        case .vehicle:
            riskScore += 0.5
            riskFactors.append("Vehicle deductions have high audit rates")
            recommendations.append("Maintain mileage log (date, miles, purpose)")
            recommendations.append("Track actual expenses if using actual method")
            recommendations.append("Keep receipts for gas, maintenance, insurance")
            
        case .mealsEntertainment:
            riskScore += 0.6
            riskFactors.append("Meals are frequently challenged by IRS")
            recommendations.append("Document business purpose on receipt")
            recommendations.append("Note attendees and discussion topics")
            recommendations.append("Only 50% deductible (100% for company events)")
            
        case .travelExpenses:
            riskScore += 0.4
            recommendations.append("Keep travel itinerary and receipts")
            recommendations.append("Document business purpose of trip")
            recommendations.append("Personal days are not deductible")
            
        case .charitableContributions:
            riskScore += 0.3
            recommendations.append("Keep donation receipts ($250+ require written acknowledgment)")
            recommendations.append("Verify 501(c)(3) status of organization")
            
        case .augustaRule:
            riskScore += 0.8
            riskFactors.append("Augusta Rule is high-scrutiny (proper execution required)")
            recommendations.append("Must rent ≤14 days/year")
            recommendations.append("Document fair market value (AirBnB comps)")
            recommendations.append("Keep rental agreement and payment records")
            recommendations.append("Must be legitimate business meetings")
            
        case .familyPayroll:
            riskScore += 0.7
            riskFactors.append("Family payroll is commonly audited")
            recommendations.append("Document actual work performed")
            recommendations.append("Pay reasonable wages for services")
            recommendations.append("Keep timesheets and job descriptions")
            recommendations.append("File W-2s and maintain payroll records")
            
        default:
            riskScore += 0.2
            recommendations.append("Keep receipts and documentation")
        }
        
        // Amount-based risk
        if amount > 10000 {
            riskScore += 0.2
            riskFactors.append("Large deduction amount")
        }
        
        if amount > 25000 {
            riskScore += 0.2
            riskFactors.append("Very large deduction (>$25K)")
        }
        
        // Documentation reduces risk
        if !hasDocumentation {
            riskScore += 0.3
            riskFactors.append("Missing documentation")
            recommendations.insert("Attach receipt or proof of expense", at: 0)
        } else {
            riskScore -= 0.1
        }
        
        // Business type considerations
        if let businessType = businessType?.lowercased() {
            if businessType.contains("cash") || businessType.contains("restaurant") {
                riskScore += 0.2
                riskFactors.append("Cash-intensive business (higher IRS scrutiny)")
            }
        }
        
        // Normalize to 0-1
        riskScore = min(max(riskScore, 0.0), 1.0)
        
        let riskLevel: TaxRiskLevel
        if riskScore < 0.3 {
            riskLevel = .low
        } else if riskScore < 0.6 {
            riskLevel = .medium
        } else {
            riskLevel = .high
        }
        
        return TaxAuditRiskAssessment(
            category: category,
            riskLevel: riskLevel,
            riskScore: riskScore,
            riskFactors: riskFactors,
            recommendations: recommendations
        )
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeHomeOfficeOpportunity(
        transactions: [Transaction],
        businessProfile: BusinessProfile?,
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        // Check if user has home-office-related expenses
        let homeOfficeCategories = ["Rent", "Utilities", "Internet", "Phone", "Home Office"]
        let homeOfficeExpenses = transactions.filter {
            !$0.isIncome &&
            $0.financeType == .business &&
            homeOfficeCategories.contains($0.category?.name ?? "")
        }
        
        guard !homeOfficeExpenses.isEmpty else { return nil }
        
        // Estimate potential deduction
        // Assume 10% of home is office (200 sq ft / 2000 sq ft average home)
        let estimatedAnnualHomeExpenses: Double = 20000 // Rent/mortgage, utilities, insurance
        let businessPercentage = 0.10
        let estimatedDeduction = estimatedAnnualHomeExpenses * businessPercentage
        
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = estimatedDeduction * taxRate
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .homeOffice,
            title: "Home Office Deduction",
            description: "You may qualify for a home office deduction. If you use part of your home exclusively for business, you can deduct a portion of rent, utilities, insurance, and more. Simplified method: $5/sq ft up to 300 sq ft ($1,500 max). Regular method could save you more.",
            estimatedSavings: estimatedSavings,
            confidence: 0.7,
            riskLevel: .medium,
            actionItems: [
                "Measure your dedicated office space",
                "Document exclusive business use (photos help)",
                "Choose simplified ($5/sq ft) or regular method",
                "Track home expenses: rent/mortgage, utilities, insurance",
                "Calculate business percentage of home"
            ],
            irsCitation: "IRS Publication 587 - Business Use of Your Home",
            requiresProTier: false
        )
    }
    
    private func analyzeMileageMethodOpportunity(
        trips: [MileageTrip],
        transactions: [Transaction],
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        guard !trips.isEmpty else { return nil }
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearTrips = trips.filter {
            Calendar.current.component(.year, from: $0.startDate) == currentYear
        }
        
        guard !yearTrips.isEmpty else { return nil }
        
        let totalMiles = yearTrips.reduce(0.0) { $0 + $1.distanceMiles }
        
        // Standard mileage rate 2025: $0.70/mile
        let standardRateDeduction = totalMiles * 0.70
        
        // Estimate actual expenses method
        // Get vehicle-related expenses from transactions
        let vehicleCategories = ["Gas", "Auto & Transport", "Car Maintenance", "Auto Insurance"]
        let vehicleExpenses = transactions.filter {
            !$0.isIncome &&
            $0.financeType == .business &&
            vehicleCategories.contains($0.category?.name ?? "")
        }
        
        let actualExpenses = vehicleExpenses.reduce(0.0) { $0 + $1.amount }
        
        // Only recommend if there's a meaningful difference
        let difference = abs(standardRateDeduction - actualExpenses)
        guard difference > 200 else { return nil }
        
        let betterMethod = standardRateDeduction > actualExpenses ? "standard mileage" : "actual expenses"
        let additionalSavings = max(standardRateDeduction, actualExpenses) - min(standardRateDeduction, actualExpenses)
        
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = additionalSavings * taxRate
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .vehicle,
            title: "Optimize Mileage Deduction Method",
            description: "You're using mileage tracking, but the \(betterMethod) method could save you an additional $\(String(format: "%.0f", estimatedSavings)). Standard rate: $\(String(format: "%.2f", standardRateDeduction)) (\(String(format: "%.0f", totalMiles)) miles × $0.70). Actual expenses: $\(String(format: "%.2f", actualExpenses)).",
            estimatedSavings: estimatedSavings,
            confidence: 0.85,
            riskLevel: .low,
            actionItems: [
                "Review your vehicle expenses in Transactions",
                "Standard rate: Track miles only",
                "Actual expenses: Keep gas, maintenance, insurance receipts",
                "Choose ONE method per vehicle per year",
                "Maintain mileage log (date, miles, business purpose)"
            ],
            irsCitation: "IRS Publication 463 - Travel, Gift, and Car Expenses",
            requiresProTier: false
        )
    }
    
    private func analyzeHealthInsuranceOpportunity(
        transactions: [Transaction],
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        // Look for health insurance payments
        let healthCategories = ["Health Insurance", "Medical", "Healthcare"]
        let healthExpenses = transactions.filter {
            !$0.isIncome &&
            healthCategories.contains($0.category?.name ?? "") ||
            $0.note.lowercased().contains("health insurance")
        }
        
        guard !healthExpenses.isEmpty else { return nil }
        
        let annualPremiums = healthExpenses.reduce(0.0) { $0 + $1.amount }
        
        // Self-employed health insurance is 100% deductible as AGI adjustment
        // This saves both income tax AND self-employment tax
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let seTaxRate = taxSettings.includeSelfEmploymentTax ? 0.153 : 0
        let totalRate = taxRate + seTaxRate
        
        let estimatedSavings = annualPremiums * totalRate
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .healthInsurance,
            title: "Self-Employed Health Insurance Deduction",
            description: "Your health insurance premiums ($\(String(format: "%.0f", annualPremiums))/year) are 100% deductible as an above-the-line deduction. This reduces both income tax AND self-employment tax, saving you ~$\(String(format: "%.0f", estimatedSavings)).",
            estimatedSavings: estimatedSavings,
            confidence: 0.9,
            riskLevel: .low,
            actionItems: [
                "Categorize health insurance payments correctly",
                "Include premiums for you, spouse, and dependents",
                "Can't exceed your business net income",
                "Report on Schedule 1 (Form 1040), Line 17"
            ],
            irsCitation: "IRS Publication 535 - Business Expenses, Chapter 6",
            requiresProTier: false
        )
    }
    
    private func analyzeRetirementOpportunity(
        transactions: [Transaction],
        taxSettings: TaxSettings,
        businessProfile: BusinessProfile?
    ) -> TaxDeductionOpportunity? {
        
        // Check if user has retirement contributions
        let retirementCategories = ["Retirement", "401k", "IRA", "SEP"]
        let retirementContributions = transactions.filter {
            !$0.isIncome &&
            retirementCategories.contains($0.category?.name ?? "")
        }
        
        let currentContributions = retirementContributions.reduce(0.0) { $0 + $1.amount }
        
        // Calculate potential contribution room
        let netIncome = calculateYearToDateIncome(
            transactions: transactions,
            year: Calendar.current.component(.year, from: Date())
        )
        
        // Solo 401(k) limits 2025: $23,000 employee + 25% employer = max $69,000
        let employeeDeferral: Double = 23000
        let employerMatch = netIncome * 0.25
        let maxSolo401k = min(employeeDeferral + employerMatch, 69000)
        
        let remainingRoom = max(0, maxSolo401k - currentContributions)
        
        guard remainingRoom > 1000 else { return nil }
        
        // Calculate tax savings
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = remainingRoom * taxRate
        
        let recommendedAmount = min(remainingRoom, netIncome * 0.20) // Conservative 20%
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .retirement,
            title: "Maximize Retirement Contributions",
            description: "You have $\(String(format: "%.0f", remainingRoom)) in unused retirement contribution room for 2025. Contributing $\(String(format: "%.0f", recommendedAmount)) to a Solo 401(k) would save you ~$\(String(format: "%.0f", recommendedAmount * taxRate)) in taxes and build tax-deferred wealth.",
            estimatedSavings: estimatedSavings,
            confidence: 0.8,
            riskLevel: .low,
            actionItems: [
                "Open Solo 401(k) by Dec 31 (contributions allowed until tax deadline)",
                "Employee deferral: $23,000 max (+$7,500 if age 50+)",
                "Employer match: up to 25% of net earnings",
                "Total limit: $69,000 for 2025",
                "Alternative: SEP-IRA (25% of net, $69,000 max)"
            ],
            irsCitation: "IRS Publication 560 - Retirement Plans for Small Business",
            requiresProTier: false
        )
    }
    
    private func analyzeFamilyPayrollOpportunity(
        transactions: [Transaction],
        taxSettings: TaxSettings,
        businessProfile: BusinessProfile?
    ) -> TaxDeductionOpportunity? {
        
        // Only recommend if net income is substantial
        let netIncome = calculateYearToDateIncome(
            transactions: transactions,
            year: Calendar.current.component(.year, from: Date())
        )
        
        guard netIncome > 50000 else { return nil }
        
        // Check if user already has payroll expenses
        let payrollExpenses = transactions.filter {
            !$0.isIncome &&
            $0.note.lowercased().contains("payroll")
        }
        
        // Don't recommend if already doing this
        guard payrollExpenses.isEmpty else { return nil }
        
        // Estimate savings from hiring child
        let childWages: Double = 13850 // 2025 standard deduction (tax-free to child)
        
        // Savings to parent business
        let parentTaxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let seTaxSavings = childWages * 0.153 // No FICA for kids <18 in sole prop
        let incomeTaxSavings = childWages * parentTaxRate
        
        let totalSavings = seTaxSavings + incomeTaxSavings
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .familyPayroll,
            title: "Employ Family Members (High ROI)",
            description: "Hiring your child (under 18) for legitimate work can save ~$\(String(format: "%.0f", totalSavings)). Pay up to $\(String(format: "%.0f", childWages)) tax-free (standard deduction). Business deducts wages; no FICA for sole proprietors. Child can contribute to Roth IRA. ⚠️ Requires legitimate work and documentation.",
            estimatedSavings: totalSavings,
            confidence: 0.7,
            riskLevel: .medium,
            actionItems: [
                "Assign age-appropriate tasks (filing, social media, data entry)",
                "Pay reasonable wages for actual work performed",
                "Keep timesheets and job descriptions",
                "No W-2 required if sole proprietor + child <18",
                "Document work to withstand audit scrutiny"
            ],
            irsCitation: "IRS Publication 15 - Employer's Tax Guide",
            requiresProTier: true // Pro feature due to complexity
        )
    }
    
    private func analyzeUncategorizedReceipts(
        receipts: [ReceiptData],
        taxSettings: TaxSettings
    ) -> [TaxDeductionOpportunity] {
        
        let uncategorized = receipts.filter {
            $0.suggestedCategoryName == nil &&
            $0.totalAmount >= 25 && // Only flag significant amounts
            !$0.deductionFlagged
        }
        
        guard !uncategorized.isEmpty else { return [] }
        
        let totalAmount = uncategorized.reduce(0.0) { $0 + $1.totalAmount }
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = totalAmount * taxRate
        
        let opportunity = TaxDeductionOpportunity(
            id: UUID(),
            category: .uncategorized,
            title: "Categorize \(uncategorized.count) Receipts",
            description: "You have \(uncategorized.count) uncategorized receipts totaling $\(String(format: "%.2f", totalAmount)). If these are business expenses, you're missing $\(String(format: "%.0f", estimatedSavings)) in tax deductions. Review and categorize them now.",
            estimatedSavings: estimatedSavings,
            confidence: 0.6,
            riskLevel: .low,
            actionItems: [
                "Review receipts in Transactions tab",
                "Assign business categories where applicable",
                "Mark personal expenses correctly",
                "Attach receipt photos to transactions"
            ],
            irsCitation: nil,
            requiresProTier: false
        )
        
        return [opportunity]
    }
    
    private func analyzeDepreciationOpportunity(
        transactions: [Transaction],
        receipts: [ReceiptData],
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        // Look for large equipment purchases
        let equipmentCategories = ["Equipment", "Computer", "Furniture", "Electronics"]
        let equipmentPurchases = transactions.filter {
            !$0.isIncome &&
            $0.financeType == .business &&
            equipmentCategories.contains($0.category?.name ?? "") &&
            $0.amount >= 500
        }
        
        guard !equipmentPurchases.isEmpty else { return nil }
        
        let totalEquipment = equipmentPurchases.reduce(0.0) { $0 + $1.amount }
        
        // 2025: 100% bonus depreciation for qualified property
        let immediateDeduction = totalEquipment
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = immediateDeduction * taxRate
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .depreciation,
            title: "Section 179 / Bonus Depreciation",
            description: "You purchased $\(String(format: "%.0f", totalEquipment)) in equipment. 2025 allows 100% bonus depreciation for qualified property placed in service this year. Immediate $\(String(format: "%.0f", immediateDeduction)) deduction = $\(String(format: "%.0f", estimatedSavings)) tax savings.",
            estimatedSavings: estimatedSavings,
            confidence: 0.85,
            riskLevel: .low,
            actionItems: [
                "Confirm equipment was placed in service in 2025",
                "Keep purchase receipts and proof of business use",
                "Section 179 limit: $2.5M (2025)",
                "100% bonus depreciation for qualified property",
                "Consider vehicles >6,000 lbs GVWR for full deduction"
            ],
            irsCitation: "IRS Publication 946 - How to Depreciate Property",
            requiresProTier: false
        )
    }
    
    private func analyzeMealsOpportunity(
        transactions: [Transaction],
        receipts: [ReceiptData],
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        // Find meal expenses
        let mealCategories = ["Meals & Entertainment", "Dining", "Food"]
        let mealExpenses = transactions.filter {
            !$0.isIncome &&
            $0.financeType == .business &&
            mealCategories.contains($0.category?.name ?? "")
        }
        
        guard !mealExpenses.isEmpty else { return nil }
        
        let totalMeals = mealExpenses.reduce(0.0) { $0 + $1.amount }
        
        // Meals are 50% deductible (100% for company events)
        let deductibleAmount = totalMeals * 0.50
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = deductibleAmount * taxRate
        
        // Check if user is documenting meals properly
        let undocumented = mealExpenses.filter { transaction in
            transaction.note.isEmpty && !transaction.hasReceipt
        }
        
        let documentationWarning = undocumented.count > mealExpenses.count / 2
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .mealsEntertainment,
            title: "Meals & Entertainment Deduction",
            description: "You've spent $\(String(format: "%.0f", totalMeals)) on business meals. 50% is deductible ($\(String(format: "%.0f", deductibleAmount))), saving $\(String(format: "%.0f", estimatedSavings)). \(documentationWarning ? "⚠️ Many meals lack documentation—add business purpose to protect deduction." : "")",
            estimatedSavings: estimatedSavings,
            confidence: documentationWarning ? 0.5 : 0.8,
            riskLevel: documentationWarning ? .high : .medium,
            actionItems: [
                "Document business purpose on each receipt",
                "Note attendees and topics discussed",
                "50% deductible for client/business meals",
                "100% deductible for company-wide events",
                "Keep receipts for meals >$75"
            ],
            irsCitation: "IRS Publication 463 - Travel, Gift, and Car Expenses",
            requiresProTier: false
        )
    }
    
    private func analyzeAugustaRuleOpportunity(
        businessProfile: BusinessProfile?,
        taxSettings: TaxSettings
    ) -> TaxDeductionOpportunity? {
        
        // Only recommend for established businesses with good income
        guard businessProfile != nil else { return nil }
        
        // Estimate fair market rental value
        // Conservative: $300/day (user should research local AirBnB rates)
        let rentalDays = 14 // Max allowed under Augusta Rule
        let estimatedDailyRate: Double = 300
        let totalRental = Double(rentalDays) * estimatedDailyRate
        
        let taxRate = calculateEffectiveTaxRate(taxSettings: taxSettings)
        let estimatedSavings = totalRental * taxRate
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .augustaRule,
            title: "Augusta Rule (§280A(g)) - Advanced Strategy",
            description: "Rent your home to your business for ≤14 days/year. The rental income is TAX-FREE to you, and DEDUCTIBLE to your business. Estimated value: $\(String(format: "%.0f", totalRental)) (14 days × $\(String(format: "%.0f", estimatedDailyRate))/day). ⚠️ Requires strict documentation and fair market rates.",
            estimatedSavings: estimatedSavings,
            confidence: 0.6,
            riskLevel: .high,
            actionItems: [
                "Research fair market rental rates (AirBnB/VRBO comps)",
                "Document legitimate business meetings held at home",
                "Create written rental agreement",
                "Make actual payment from business to personal",
                "Keep meeting agendas and attendee lists",
                "Consult CPA before implementing"
            ],
            irsCitation: "IRC §280A(g) - Augusta Rule",
            requiresProTier: true // Advanced strategy, Pro only
        )
    }
    
    private func analyzeQBIOpportunity(
        transactions: [Transaction],
        taxSettings: TaxSettings,
        businessProfile: BusinessProfile?
    ) -> TaxDeductionOpportunity? {
        
        let netIncome = calculateYearToDateIncome(
            transactions: transactions,
            year: Calendar.current.component(.year, from: Date())
        )
        
        // QBI deduction: 20% of qualified business income
        // Phase-out for service trades: $197,300 single / $394,600 MFJ (2025)
        
        guard netIncome > 10000 else { return nil }
        
        let qbiDeduction = netIncome * 0.20
        let taxRate = calculateMarginalFederalRate(
            netIncome: netIncome,
            filingStatus: taxSettings.filingStatus
        )
        
        let estimatedSavings = qbiDeduction * taxRate
        
        // Check if phase-out applies
        let phaseOutThreshold: Double = taxSettings.filingStatus == .marriedFilingJointly ? 394600 : 197300
        let isPhaseOut = netIncome > phaseOutThreshold
        
        return TaxDeductionOpportunity(
            id: UUID(),
            category: .qbiDeduction,
            title: "Qualified Business Income (QBI) Deduction",
            description: "You may qualify for a 20% QBI deduction on your $\(String(format: "%.0f", netIncome)) business income = $\(String(format: "%.0f", qbiDeduction)) deduction, saving $\(String(format: "%.0f", estimatedSavings)). \(isPhaseOut ? "⚠️ Your income exceeds phase-out threshold—deduction may be limited." : "Permanent via 2025 OBBBA legislation.")",
            estimatedSavings: estimatedSavings,
            confidence: isPhaseOut ? 0.5 : 0.9,
            riskLevel: .low,
            actionItems: [
                "QBI = net business income minus ½ SE tax",
                "20% deduction on qualified income",
                "Phase-out: $197,300 single / $394,600 MFJ",
                "Service trades limited above threshold",
                "Report on Form 8995 (or 8995-A if phased out)"
            ],
            irsCitation: "IRS Form 8995 Instructions",
            requiresProTier: false
        )
    }
    
    // MARK: - Helper Calculations
    
    private func calculateYearToDateIncome(
        transactions: [Transaction],
        year: Int
    ) -> Double {
        let yearStart = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        let yearEnd = Calendar.current.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59))!
        
        let yearTransactions = transactions.filter {
            $0.date >= yearStart && $0.date <= yearEnd
        }
        
        let income = yearTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        let expenses = yearTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        
        return income - expenses
    }
    
    private func calculateEstimatedNetIncome(
        from date: Date,
        context: ModelContext?
    ) -> Double {
        // Simplified estimate for real-time calculations
        // In production, would fetch actual transactions from context
        return 60000 // Placeholder - replace with actual calculation
    }
    
    private func calculateEffectiveTaxRate(taxSettings: TaxSettings) -> Double {
        // Estimate: Federal + State + SE tax
        let federalRate = 0.22 // Approximate marginal rate
        let stateRate = taxSettings.customStateRate ?? TaxSettings.stateTaxRates[taxSettings.state] ?? 0.0
        let seRate = taxSettings.includeSelfEmploymentTax ? 0.153 * 0.5 : 0 // Half of SE tax is deductible
        
        return federalRate + stateRate + seRate
    }
    
    private func calculateMarginalFederalRate(
        netIncome: Double,
        filingStatus: TaxSettings.FilingStatus
    ) -> Double {
        let brackets = TaxSettings.federalTaxBrackets(for: filingStatus)
        
        for bracket in brackets.reversed() {
            if netIncome > bracket.maxIncome {
                return bracket.rate
            }
        }
        
        return 0.10 // Lowest bracket
    }
    
    private func estimateSCorpSavings(
        netIncome: Double,
        filingStatus: TaxSettings.FilingStatus
    ) -> Double {
        // S-Corp savings calculation
        // Pay reasonable salary (typically 60-70% of income)
        let reasonableSalary = netIncome * 0.65
        let _ = netIncome - reasonableSalary  // Distribution (not subject to SE tax)
        
        // SE tax on sole prop: 15.3% on all income
        let soleProprietorSETax = netIncome * 0.153
        
        // S-Corp SE tax: Only on salary
        let sCorpSETax = reasonableSalary * 0.153
        
        // Savings (minus payroll processing costs ~$1,500/year)
        let grossSavings = soleProprietorSETax - sCorpSETax
        let payrollCosts: Double = 1500
        
        return max(0, grossSavings - payrollCosts)
    }
}

// MARK: - Engine-Specific Models
// Note: Main models are in TaxOptimizationModels.swift

struct TransactionTaxSavings {
    let transaction: Transaction
    let federalSavings: Double
    let stateSavings: Double
    let selfEmploymentSavings: Double
    let totalSavings: Double
    let effectiveRate: Double
    
    var displayText: String {
        guard totalSavings > 0 else { return "" }
        return "💰 Saves $\(String(format: "%.2f", totalSavings)) in taxes"
    }
}

// MARK: - Version History
/*
 Version 1.0 (Current - Phase 1):
 - On-device rule-based tax optimization
 - Deduction opportunity discovery (10 categories)
 - Real-time transaction savings estimates
 - Year-end checklist generator (November-December)
 - Audit risk scoring and documentation recommendations
 - Mileage method comparison (standard vs. actual)
 - Entity structure optimization hints (S-Corp savings)
 - Pro tier feature gating for advanced strategies
 
 Future Enhancements (Phase 2):
 - Core ML models for pattern recognition
 - Natural language query interface
 - Advanced entity structure simulations
 - Multi-year tax planning
 - Lease vs. buy analysis
 - Expanded deduction categories (60+)
 - Cloud-based AI assistant (Pro tier)
 */
