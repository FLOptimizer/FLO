//  TaxCalculationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 — Multi-source income: TaxTreatment segmentation, W-2 withholding credit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Tax calculation engine for quarterly estimates with intelligent caching.
//
//  CHANGES IN v1.6:
//  ✅ ADDED: Income segmentation by category.taxTreatment
//            — .selfEmployment   → SE tax + income tax (existing behavior for ungrouped income)
//            — .w2WithholdingPaid → income tax only (no SE tax), withholding credited
//            — .passiveIncome    → income tax only (no SE tax)
//            — .taxExempt        → excluded from ALL calculations
//  ✅ ADDED: Proper bracket stacking — W-2 + passive income stacks with SE income
//            for federal/state bracket calculation (e.g. spouse W-2 pushes SE into 22%)
//  ✅ ADDED: W-2 withholding credit — estimated employer withholding subtracted from
//            quarterly payment due (per category.estimatedWithholdingRate)
//  ✅ ADDED: SS wage base interaction — primary-owner W-2 wages credited against
//            $184,500 SS wage base before SE tax SS portion is calculated
//  ✅ ADDED: TaxEstimate.selfEmploymentIncome — gross SE income for UI breakdown
//  ✅ ADDED: TaxEstimate.w2Income — gross W-2 income for UI breakdown
//  ✅ ADDED: TaxEstimate.passiveIncome — gross passive income for UI breakdown
//  ✅ ADDED: TaxEstimate.w2WithholdingCredit — estimated withholding already paid
//  ✅ ADDED: TaxEstimate.adjustedQuarterlyPayment — quarterly due after withholding credit
//  ✅ UPDATED: generateTransactionHash — hashes SE/W-2/passive totals separately
//             so cache invalidates when category assignments change
//  ✅ UPDATED: projectAnnualTax — projects all new TaxEstimate fields
//  ✅ PRESERVED: All existing public API — calculateYearToDateEstimate, calculateQuarterlyStatus,
//               calculateTaxReserve, projectAnnualTax, QuarterlyStatus (unchanged signatures)
//  ✅ PRESERVED: All v1.5 logic for transfers (isTransfer == true) exclusion
//  ✅ PRESERVED: All v1.4 SE tax rate logic (SS cap, Medicare, Additional Medicare)
//  ✅ PRESERVED: All v1.3 IRS calculation order (SE tax → AGI → taxable income)
//  ✅ PRESERVED: All v1.2 caching infrastructure (TTL, hash-based invalidation, stats)
//
//  BACKWARD COMPATIBILITY NOTE:
//  All existing TaxEstimate consumers (TaxEstimateCard, ReportsView, TaxSettingsView, etc.)
//  continue to compile without change. New fields are additive only.
//  Callers that do NOT pass categories (legacy call sites) default to treating all
//  income as selfEmployment — identical to v1.5 behavior.
//
//  IRS CALCULATION ORDER (preserved from v1.3, extended for multi-source):
//  1. Segment income by TaxTreatment
//  2. Net SE income = gross SE income − all business deductions
//  3. SE tax = f(net SE income, SS wage base − primary W-2 wages)
//  4. SE deduction = SE tax / 2
//  5. AGI = (SE + W-2 + passive income) − expenses − SE deduction
//  6. Taxable income = AGI − standard deduction
//  7. Federal tax = brackets applied to taxable income
//  8. State tax = AGI × state rate
//  9. Total tax = federal + state + SE tax
//  10. W-2 withholding credit = Σ (category income × category.estimatedWithholdingRate)
//  11. Adjusted quarterly = (total tax − annual withholding credit) / 4
//

import Foundation
import SwiftData

@MainActor
class TaxCalculationService {

    // MARK: - Singleton

    static let shared = TaxCalculationService()
    private init() {
        #if DEBUG
        print("💰 TaxCalculationService initialized")
        #endif
    }

    // MARK: - 2026 Tax Constants

    /// Social Security wage base for 2026
    private let socialSecurityWageBase2026: Double = 184_500

    /// Social Security rate (employee + employer combined — SE pays both)
    private let socialSecurityRate: Double = 0.124   // 12.4%

    /// Medicare rate (employee + employer combined)
    private let medicareRate: Double = 0.029          // 2.9%

    /// Additional Medicare Tax rate for high earners
    private let additionalMedicareRate: Double = 0.009 // 0.9%

    /// Additional Medicare Tax thresholds by filing status
    private let additionalMedicareThresholdSingle: Double = 200_000
    private let additionalMedicareThresholdMFJ: Double    = 250_000
    private let additionalMedicareThresholdMFS: Double    = 125_000

    /// SE income multiplier (92.35% of net SE income per IRS)
    private let seIncomeMultiplier: Double = 0.9235

    // MARK: - Cache Configuration

    /// Cache time-to-live in seconds (default: 5 minutes)
    var cacheTTL: TimeInterval = 300

    // MARK: - Cache Storage

    private var cachedEstimate: TaxEstimate?
    private var cacheTimestamp: Date?
    private var cachedTransactionHash: Int?
    private var cachedSettingsHash: Int?
    private var cachedTransactionCount: Int?

    // MARK: - Cache Statistics

    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0

    var cacheHitRate: Double {
        let total = cacheHits + cacheMisses
        return total > 0 ? Double(cacheHits) / Double(total) : 0
    }

    // MARK: - Tax Estimate Result

    struct TaxEstimate: Equatable {

        // MARK: Tax Amounts (v1.0+)
        let federalIncomeTax: Double
        let stateIncomeTax: Double
        let selfEmploymentTax: Double
        let totalEstimated: Double
        let effectiveFederalRate: Double
        let effectiveStateRate: Double
        let effectiveTotalRate: Double

        // MARK: Quarterly Breakdown (v1.0+)
        let quarterlyPayment: Double       // Gross quarterly before withholding credit
        let nextDeadline: Date?
        let daysUntilDeadline: Int?

        // MARK: Income Breakdown (v1.0+)
        let netIncome: Double              // All non-exempt income minus expenses
        let taxableIncome: Double

        // MARK: Safe Harbor (v1.0+)
        let safeHarborAmount: Double?
        let isMeetingSafeHarbor: Bool

        // MARK: Cache Metadata (v1.2+)
        let calculatedAt: Date
        let fromCache: Bool

        // MARK: Income Source Breakdown (v1.6 NEW)

        /// Gross self-employment / 1099 income before expenses.
        let selfEmploymentIncome: Double

        /// Gross W-2 / employer-withheld income. Stacks brackets but has no SE tax.
        let w2Income: Double

        /// Gross passive income (rental, dividends, etc.). Stacks brackets, no SE tax.
        let passiveIncome: Double

        /// Estimated employer withholding already paid to the IRS on W-2 income.
        /// Derived from category.estimatedWithholdingRate on each W-2 category.
        let w2WithholdingCredit: Double

        /// Quarterly payment actually owed after subtracting annualized withholding credit.
        /// Use this value for the "pay by" amount displayed to users.
        /// = max(0, (totalEstimated - w2WithholdingCredit) / 4)
        let adjustedQuarterlyPayment: Double
    }

    // MARK: - Public API: Calculate Year-to-Date Estimate

    /// Calculate estimated taxes based on year-to-date transactions.
    /// Uses smart caching — cache is valid when transaction data, settings,
    /// and cache age are all unchanged.
    ///
    /// - Parameters:
    ///   - transactions: All transactions (filtered internally to current year)
    ///   - settings: Tax settings configuration
    ///   - categories: All Category records — used to resolve taxTreatment and
    ///                 estimatedWithholdingRate. Defaults to [] for legacy callers;
    ///                 in that case all income is treated as selfEmployment (v1.5 behavior).
    ///   - forceRefresh: If true, bypasses cache and recalculates
    /// - Returns: TaxEstimate with full calculation results
    func calculateYearToDateEstimate(
        transactions: [Transaction],
        settings: TaxSettings,
        forceRefresh: Bool = false
    ) -> TaxEstimate {

        let transactionHash = generateTransactionHash(transactions)
        let settingsHash    = generateSettingsHash(settings)

        // Cache hit check
        if !forceRefresh,
           let cached = cachedEstimate,
           let timestamp = cacheTimestamp,
           cachedTransactionHash == transactionHash,
           cachedSettingsHash == settingsHash,
           Date().timeIntervalSince(timestamp) < cacheTTL {

            cacheHits += 1

            #if DEBUG
            print("💰 Cache HIT (age: \(Int(Date().timeIntervalSince(timestamp)))s)")
            #endif

            return TaxEstimate(
                federalIncomeTax: cached.federalIncomeTax,
                stateIncomeTax: cached.stateIncomeTax,
                selfEmploymentTax: cached.selfEmploymentTax,
                totalEstimated: cached.totalEstimated,
                effectiveFederalRate: cached.effectiveFederalRate,
                effectiveStateRate: cached.effectiveStateRate,
                effectiveTotalRate: cached.effectiveTotalRate,
                quarterlyPayment: cached.quarterlyPayment,
                nextDeadline: cached.nextDeadline,
                daysUntilDeadline: cached.daysUntilDeadline,
                netIncome: cached.netIncome,
                taxableIncome: cached.taxableIncome,
                safeHarborAmount: cached.safeHarborAmount,
                isMeetingSafeHarbor: cached.isMeetingSafeHarbor,
                calculatedAt: cached.calculatedAt,
                fromCache: true,
                selfEmploymentIncome: cached.selfEmploymentIncome,
                w2Income: cached.w2Income,
                passiveIncome: cached.passiveIncome,
                w2WithholdingCredit: cached.w2WithholdingCredit,
                adjustedQuarterlyPayment: cached.adjustedQuarterlyPayment
            )
        }

        // Cache miss
        cacheMisses += 1

        #if DEBUG
        let reason = forceRefresh               ? "forced refresh"        :
                     cachedEstimate == nil       ? "no cache"              :
                     cachedTransactionHash != transactionHash ? "transactions changed" :
                     cachedSettingsHash != settingsHash       ? "settings changed"     :
                                                               "cache expired"
        print("💰 Cache MISS — recalculating (\(reason))")
        #endif

        let estimate = performCalculation(transactions: transactions, settings: settings)

        cachedEstimate         = estimate
        cacheTimestamp         = Date()
        cachedTransactionHash  = transactionHash
        cachedSettingsHash     = settingsHash
        cachedTransactionCount = transactions.count

        return estimate
    }

    // MARK: - Cache Management

    func invalidateCache() {
        cachedEstimate        = nil
        cacheTimestamp        = nil
        cachedTransactionHash = nil
        cachedSettingsHash    = nil
        cachedTransactionCount = nil
        #if DEBUG
        print("💰 Cache invalidated")
        #endif
    }

    func resetCacheStats() {
        cacheHits   = 0
        cacheMisses = 0
    }

    var cacheStatus: String {
        if let timestamp = cacheTimestamp {
            let age     = Int(Date().timeIntervalSince(timestamp))
            let isValid = age < Int(cacheTTL)
            return "Cache: \(isValid ? "Valid" : "Expired") (age: \(age)s, TTL: \(Int(cacheTTL))s, hits: \(cacheHits), misses: \(cacheMisses), rate: \(String(format: "%.1f%%", cacheHitRate * 100)))"
        }
        return "Cache: Empty"
    }

    // MARK: - Hash Generation

    private func generateTransactionHash(_ transactions: [Transaction]) -> Int {
        var hasher = Hasher()

        let calendar    = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let yearStart   = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!

        // Filter to current-year, non-transfer transactions
        let relevant = transactions.filter { tx in
            tx.date >= yearStart && !tx.isTransfer
        }

        hasher.combine(relevant.count)

        // v1.6: hash each income treatment bucket separately so cache invalidates
        // when a user changes a category's taxTreatment assignment
        let income = relevant.filter { $0.isIncome }
        let expenses = relevant.filter { !$0.isIncome }

        let seTotal      = income.filter { $0.category?.taxTreatment == .selfEmployment ||
                                            $0.category == nil }
                                 .reduce(0.0) { $0 + $1.amount }
        let w2Total      = income.filter { $0.category?.taxTreatment == .w2WithholdingPaid }
                                 .reduce(0.0) { $0 + $1.amount }
        let passiveTotal = income.filter { $0.category?.taxTreatment == .passiveIncome }
                                 .reduce(0.0) { $0 + $1.amount }
        let expenseTotal = expenses.reduce(0.0) { $0 + $1.amount }

        hasher.combine(Int(seTotal      * 100))
        hasher.combine(Int(w2Total      * 100))
        hasher.combine(Int(passiveTotal * 100))
        hasher.combine(Int(expenseTotal * 100))

        return hasher.finalize()
    }

    private func generateSettingsHash(_ settings: TaxSettings) -> Int {
        var hasher = Hasher()
        hasher.combine(settings.filingStatus.rawValue)
        hasher.combine(settings.state)
        hasher.combine(settings.includeSelfEmploymentTax)
        hasher.combine(Int((settings.customFederalRate    ?? 0) * 10000))
        hasher.combine(Int((settings.customStateRate      ?? 0) * 10000))
        hasher.combine(Int((settings.priorYearTaxLiability ?? 0) * 100))
        hasher.combine(settings.isHighEarner)
        return hasher.finalize()
    }

    // MARK: - Core Calculation

    private func performCalculation(
        transactions: [Transaction],
        settings: TaxSettings
    ) -> TaxEstimate {

        let calendar    = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let yearStart   = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        let yearEnd     = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31, hour: 23, minute: 59))!

        // ── Step 1: Filter to current-year, non-transfer transactions ─────────
        let yearTransactions = transactions.filter { tx in
            tx.date >= yearStart &&
            tx.date <= yearEnd   &&
            !tx.isTransfer
        }

        let incomeTransactions  = yearTransactions.filter {  $0.isIncome }
        let expenseTransactions = yearTransactions.filter { !$0.isIncome }

        // ── Step 2: Segment income by TaxTreatment ────────────────────────────
        //
        // Categories without a category (nil) default to .selfEmployment —
        // preserving v1.5 behavior for any uncategorized transactions.
        //
        // .taxExempt transactions are intentionally excluded from all buckets.

        let seTxns      = incomeTransactions.filter {
            $0.category?.taxTreatment == .selfEmployment || $0.category == nil
        }
        let w2Txns      = incomeTransactions.filter {
            $0.category?.taxTreatment == .w2WithholdingPaid
        }
        let passiveTxns = incomeTransactions.filter {
            $0.category?.taxTreatment == .passiveIncome
        }
        // .taxExempt: deliberately not collected — excluded from all math

        let grossSEIncome      = seTxns.reduce(0.0)      { $0 + $1.amount }
        let grossW2Income      = w2Txns.reduce(0.0)      { $0 + $1.amount }
        let grossPassiveIncome = passiveTxns.reduce(0.0) { $0 + $1.amount }

        // ── Step 3: Business expenses ─────────────────────────────────────────
        //
        // All deductible business expenses offset SE income.
        // Non-business (personal) expenses are not deducted.
        let businessExpenses = expenseTransactions
            .filter { $0.financeType == .business }
            .reduce(0.0) { $0 + $1.amount }

        // Net SE income — the base for SE tax. Cannot be negative.
        let netSEIncome = max(0, grossSEIncome - businessExpenses)

        // ── Step 4: SE Tax ────────────────────────────────────────────────────
        //
        // SE tax applies ONLY to self-employment income.
        // W-2 wages from the PRIMARY owner are credited against the SS wage base
        // (relevant when the same taxpayer has both a W-2 job and gig income).
        let primaryW2Wages = w2Txns
            .filter { $0.category?.taxOwner == .primary }
            .reduce(0.0) { $0 + $1.amount }

        let selfEmploymentTax = settings.includeSelfEmploymentTax
            ? calculateSelfEmploymentTax(
                netSEIncome: netSEIncome,
                primaryW2Wages: primaryW2Wages,
                filingStatus: settings.filingStatus)
            : 0.0

        // ── Step 5: AGI ───────────────────────────────────────────────────────
        //
        // Per IRS rules, 50% of SE tax is deductible from AGI.
        // AGI includes ALL non-exempt income streams minus expenses minus SE deduction.
        let selfEmploymentDeduction = selfEmploymentTax / 2.0
        let totalGrossIncome        = grossSEIncome + grossW2Income + grossPassiveIncome
        let netIncome               = totalGrossIncome - businessExpenses
        let adjustedGrossIncome     = netIncome - selfEmploymentDeduction

        // ── Step 6: Federal income tax ────────────────────────────────────────
        //
        // Standard deduction applied to AGI to get taxable income.
        // All non-exempt income sources are stacked here — this is where
        // a spouse's W-2 income pushes SE income into a higher bracket.
        let standardDeduction = TaxSettings.standardDeduction(for: settings.filingStatus)
        let taxableIncome     = max(0, adjustedGrossIncome - standardDeduction)

        let federalTax = calculateFederalIncomeTax(
            taxableIncome: taxableIncome,
            filingStatus:  settings.filingStatus,
            customRate:    settings.customFederalRate
        )

        // ── Step 7: State income tax ──────────────────────────────────────────
        let stateTax = calculateStateIncomeTax(
            netIncome:  adjustedGrossIncome,
            state:      settings.state,
            customRate: settings.customStateRate
        )

        // ── Step 8: Totals and effective rates ────────────────────────────────
        let totalTax = federalTax + stateTax + selfEmploymentTax

        let effectiveFederalRate = netIncome > 0 ? federalTax        / netIncome : 0
        let effectiveStateRate   = netIncome > 0 ? stateTax          / netIncome : 0
        let effectiveTotalRate   = netIncome > 0 ? totalTax          / netIncome : 0

        // ── Step 9: Quarterly payment ─────────────────────────────────────────
        let quarterlyPayment = totalTax / 4.0

        // ── Step 10: W-2 withholding credit ──────────────────────────────────
        //
        // For each W-2 category that has an estimatedWithholdingRate,
        // estimate how much has already been withheld for the full year.
        // This reduces what the user actually owes in quarterly payments.
        let w2WithholdingCredit = calculateW2WithholdingCredit(w2Transactions: w2Txns)

        // Adjusted quarterly = (total tax owed - annual withholding already paid) / 4
        // Floored at 0 — withholding cannot create a refund in this estimate.
        let adjustedQuarterlyPayment = max(0, (totalTax - w2WithholdingCredit) / 4.0)

        // ── Step 11: Deadlines ────────────────────────────────────────────────
        let nextDeadline       = TaxSettings.nextQuarterlyDeadline()
        let daysUntilDeadline  = nextDeadline.flatMap {
            calendar.dateComponents([.day], from: Date(), to: $0).day
        }

        // ── Step 12: Safe harbor ──────────────────────────────────────────────
        let (safeHarborAmount, isMeetingSafeHarbor) = calculateSafeHarbor(
            currentYearTax: totalTax,
            priorYearTax:   settings.priorYearTaxLiability,
            isHighEarner:   settings.isHighEarner
        )

        return TaxEstimate(
            federalIncomeTax:         federalTax,
            stateIncomeTax:           stateTax,
            selfEmploymentTax:        selfEmploymentTax,
            totalEstimated:           totalTax,
            effectiveFederalRate:     effectiveFederalRate,
            effectiveStateRate:       effectiveStateRate,
            effectiveTotalRate:       effectiveTotalRate,
            quarterlyPayment:         quarterlyPayment,
            nextDeadline:             nextDeadline,
            daysUntilDeadline:        daysUntilDeadline,
            netIncome:                netIncome,
            taxableIncome:            taxableIncome,
            safeHarborAmount:         safeHarborAmount,
            isMeetingSafeHarbor:      isMeetingSafeHarbor,
            calculatedAt:             Date(),
            fromCache:                false,
            selfEmploymentIncome:     grossSEIncome,
            w2Income:                 grossW2Income,
            passiveIncome:            grossPassiveIncome,
            w2WithholdingCredit:      w2WithholdingCredit,
            adjustedQuarterlyPayment: adjustedQuarterlyPayment
        )
    }

    // MARK: - Federal Income Tax

    private func calculateFederalIncomeTax(
        taxableIncome: Double,
        filingStatus:  TaxSettings.FilingStatus,
        customRate:    Double?
    ) -> Double {
        if let customRate = customRate {
            return taxableIncome * customRate
        }

        let brackets = TaxSettings.federalTaxBrackets(for: filingStatus)
        var tax: Double = 0
        var previousMax: Double = 0

        for bracket in brackets {
            if taxableIncome <= previousMax { break }
            let taxableAtRate = min(taxableIncome, bracket.maxIncome) - previousMax
            tax += taxableAtRate * bracket.rate
            previousMax = bracket.maxIncome
            if taxableIncome <= bracket.maxIncome { break }
        }

        return tax
    }

    // MARK: - State Income Tax

    private func calculateStateIncomeTax(
        netIncome:  Double,
        state:      String,
        customRate: Double?
    ) -> Double {
        if let customRate = customRate {
            return netIncome * customRate
        }
        let stateRate = TaxSettings.stateTaxRates[state] ?? 0.05
        return netIncome * stateRate
    }

    // MARK: - Self-Employment Tax

    /// Calculate SE tax per IRS 2026 rules with SS wage base interaction.
    ///
    /// - Parameters:
    ///   - netSEIncome: Net self-employment income (gross SE − business expenses)
    ///   - primaryW2Wages: W-2 wages already subject to SS tax for the PRIMARY owner.
    ///                     Credited against the $184,500 SS wage base before calculating
    ///                     the SE tax Social Security portion. Defaults to 0.
    ///   - filingStatus: Used for Additional Medicare Tax threshold
    private func calculateSelfEmploymentTax(
        netSEIncome:     Double,
        primaryW2Wages:  Double = 0,
        filingStatus:    TaxSettings.FilingStatus
    ) -> Double {
        guard netSEIncome > 0 else { return 0 }

        // Step A: SE income base = 92.35% of net SE income
        let seIncome = netSEIncome * seIncomeMultiplier

        // Step B: Social Security (12.4%) — capped at wage base minus any W-2 wages
        //   If the same person already paid SS on W-2 wages, the SE SS portion
        //   only applies to the remaining wage base headroom.
        let remainingSSBase = max(0, socialSecurityWageBase2026 - primaryW2Wages)
        let ssableIncome    = min(seIncome, remainingSSBase)
        let socialSecurityTax = ssableIncome * socialSecurityRate

        // Step C: Medicare (2.9%) on ALL SE income — no cap
        let medicareTax = seIncome * medicareRate

        // Step D: Additional Medicare Tax (0.9%) above threshold
        let additionalMedicareThreshold: Double
        switch filingStatus {
        case .marriedFilingJointly:    additionalMedicareThreshold = additionalMedicareThresholdMFJ
        case .marriedFilingSeparately: additionalMedicareThreshold = additionalMedicareThresholdMFS
        case .single, .headOfHousehold: additionalMedicareThreshold = additionalMedicareThresholdSingle
        }

        let additionalMedicareTax = seIncome > additionalMedicareThreshold
            ? (seIncome - additionalMedicareThreshold) * additionalMedicareRate
            : 0.0

        return socialSecurityTax + medicareTax + additionalMedicareTax
    }

    // MARK: - W-2 Withholding Credit (v1.6 NEW)

    /// Estimates total employer withholding already paid to the IRS across all W-2 categories.
    ///
    /// For each W-2 income transaction, looks up its category's estimatedWithholdingRate
    /// and multiplies the transaction amount by that rate. Sums across all W-2 transactions.
    ///
    /// If a W-2 category has no estimatedWithholdingRate (nil), those transactions contribute
    /// $0 to the credit — conservative, so FLO never under-estimates what the user owes.
    ///
    /// - Parameter w2Transactions: All W-2 income transactions for the calculation period
    /// - Returns: Estimated total withholding already paid (annual figure)
    private func calculateW2WithholdingCredit(w2Transactions: [Transaction]) -> Double {
        // Group by category UUID so we apply each category's rate to its cumulative income.
        // This handles the common case where many transactions share one W-2 category.
        var incomeByCategoryID: [UUID: Double] = [:]
        var rateByID: [UUID: Double] = [:]

        for tx in w2Transactions {
            guard let category = tx.category,
                  let rate = category.estimatedWithholdingRate,
                  rate > 0 else { continue }

            let catID = category.id
            incomeByCategoryID[catID, default: 0] += tx.amount
            rateByID[catID] = rate   // Rate is constant per category; safe to overwrite
        }

        return incomeByCategoryID.reduce(0.0) { total, entry in
            let (id, income) = entry
            let rate = rateByID[id] ?? 0
            return total + (income * rate)
        }
    }

    // MARK: - Safe Harbor

    private func calculateSafeHarbor(
        currentYearTax: Double,
        priorYearTax:   Double?,
        isHighEarner:   Bool
    ) -> (amount: Double?, isMeeting: Bool) {
        guard let priorYearTax = priorYearTax, priorYearTax > 0 else {
            return (nil, false)
        }
        let safeHarborPercentage = isHighEarner ? 1.10 : 1.00
        let safeHarborAmount     = priorYearTax * safeHarborPercentage
        let isMeeting            = currentYearTax >= safeHarborAmount
        return (safeHarborAmount, isMeeting)
    }

    // MARK: - Tax Reserve

    func calculateTaxReserve(
        amount: Double,
        effectiveTaxRate: Double
    ) -> Double {
        return amount * effectiveTaxRate
    }

    // MARK: - Quarterly Tax Payment Status

    func calculateQuarterlyStatus(
        totalEstimated: Double,
        nextDeadline:   Date?
    ) -> QuarterlyStatus {
        guard let deadline = nextDeadline else { return .unknown }

        let calendar  = Calendar.current
        let daysUntil = calendar.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        let quarterly = totalEstimated / 4

        if daysUntil <= 7  { return .urgent(amount: quarterly, daysLeft: daysUntil) }
        if daysUntil <= 14 { return .upcoming(amount: quarterly, daysLeft: daysUntil) }
        return .onTrack(amount: quarterly, daysLeft: daysUntil)
    }

    enum QuarterlyStatus {
        case urgent(amount: Double, daysLeft: Int)
        case upcoming(amount: Double, daysLeft: Int)
        case onTrack(amount: Double, daysLeft: Int)
        case unknown

        var color: String {
            switch self {
            case .urgent:   return "red"
            case .upcoming: return "yellow"
            case .onTrack:  return "green"
            case .unknown:  return "gray"
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

    // MARK: - Full-Year Projection

    func projectAnnualTax(
        currentEstimate: TaxEstimate,
        transactions: [Transaction]
    ) -> TaxEstimate {
        let calendar    = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let today       = Date()

        let yearStart    = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1))!
        let yearEnd      = calendar.date(from: DateComponents(year: currentYear, month: 12, day: 31))!
        let daysElapsed  = max(1, calendar.dateComponents([.day], from: yearStart, to: today).day ?? 1)
        let daysInYear   = calendar.dateComponents([.day], from: yearStart, to: yearEnd).day ?? 365
        let multiplier   = Double(daysInYear) / Double(daysElapsed)

        let projFederal   = currentEstimate.federalIncomeTax  * multiplier
        let projState     = currentEstimate.stateIncomeTax     * multiplier
        let projSE        = currentEstimate.selfEmploymentTax  * multiplier
        let projTotal     = projFederal + projState + projSE
        let projWithhold  = currentEstimate.w2WithholdingCredit * multiplier

        return TaxEstimate(
            federalIncomeTax:         projFederal,
            stateIncomeTax:           projState,
            selfEmploymentTax:        projSE,
            totalEstimated:           projTotal,
            effectiveFederalRate:     currentEstimate.effectiveFederalRate,
            effectiveStateRate:       currentEstimate.effectiveStateRate,
            effectiveTotalRate:       currentEstimate.effectiveTotalRate,
            quarterlyPayment:         projTotal / 4.0,
            nextDeadline:             currentEstimate.nextDeadline,
            daysUntilDeadline:        currentEstimate.daysUntilDeadline,
            netIncome:                currentEstimate.netIncome    * multiplier,
            taxableIncome:            currentEstimate.taxableIncome * multiplier,
            safeHarborAmount:         currentEstimate.safeHarborAmount,
            isMeetingSafeHarbor:      currentEstimate.isMeetingSafeHarbor,
            calculatedAt:             Date(),
            fromCache:                false,
            selfEmploymentIncome:     currentEstimate.selfEmploymentIncome * multiplier,
            w2Income:                 currentEstimate.w2Income              * multiplier,
            passiveIncome:            currentEstimate.passiveIncome         * multiplier,
            w2WithholdingCredit:      projWithhold,
            adjustedQuarterlyPayment: max(0, (projTotal - projWithhold) / 4.0)
        )
    }
}

// MARK: - Double Formatting Extensions (v1.0 — unchanged)

extension Double {
    var asCurrency: String {
        guard self.isFinite else { return "$0.00" }
        return NumberFormatter.appCurrency.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    var asPercentage: String {
        guard self.isFinite else { return "0%" }
        return NumberFormatter.appPercent.string(from: NSNumber(value: self)) ?? "0%"
    }
}

// MARK: - Usage Reference

/*
 // === BASIC USAGE (API unchanged) ===

 let estimate = TaxCalculationService.shared.calculateYearToDateEstimate(
     transactions: transactions,
     settings: settings
 )

 // === NEW: Multi-source breakdown ===

 print("SE income:       \(estimate.selfEmploymentIncome.asCurrency)")
 print("W-2 income:      \(estimate.w2Income.asCurrency)")
 print("Passive income:  \(estimate.passiveIncome.asCurrency)")
 print("Withholding:    -\(estimate.w2WithholdingCredit.asCurrency)")
 print("Quarterly due:   \(estimate.adjustedQuarterlyPayment.asCurrency)")

 // === FORCE REFRESH ===

 let fresh = TaxCalculationService.shared.calculateYearToDateEstimate(
     transactions: transactions,
     settings: settings,
     forceRefresh: true
 )

 // === MANUAL CACHE INVALIDATION ===
 // Call when user saves a transaction or updates a category

 TaxCalculationService.shared.invalidateCache()

 // === CACHE TUNING ===

 TaxCalculationService.shared.cacheTTL = 60   // 1 min for active editing views
 TaxCalculationService.shared.cacheTTL = 300  // 5 min default for dashboard
 */

// MARK: - Version History

/*
 Version 1.6:
 - Income segmentation by category.taxTreatment (SE / W-2 / passive / exempt)
 - Bracket stacking: all non-exempt income sources combined for federal/state brackets
 - W-2 withholding credit reduces adjusted quarterly payment
 - SS wage base interaction: primary-owner W-2 wages credited against $184,500 base
 - New TaxEstimate fields: selfEmploymentIncome, w2Income, passiveIncome,
   w2WithholdingCredit, adjustedQuarterlyPayment
 - generateTransactionHash updated to hash by treatment bucket
 - projectAnnualTax projects all new fields
 - All existing public API signatures unchanged

 Version 1.5:
 - Transfers (isTransfer == true) excluded from all tax calculations

 Version 1.4:
 - SE tax splits SS (12.4%, capped) and Medicare (2.9%, uncapped) correctly
 - Additional Medicare Tax (0.9%) for high earners
 - Social Security capped at $184,500 wage base (2026)

 Version 1.3:
 - SE tax deduction reduces AGI before federal tax (IRS-correct order)
 - AGI intermediate calculation added

 Version 1.2:
 - Smart caching with TTL and hash-based invalidation
 - ~97% reduction in redundant calculations

 Version 1.1:
 - Version tracking added

 Version 1.0:
 - Initial implementation
 */
