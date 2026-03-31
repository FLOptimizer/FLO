//  DebtCalculationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Initial Implementation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Unified debt calculation service for mortgages, auto loans, personal loans,
//  and credit cards. Provides payoff projections, amortization schedules,
//  and strategy comparisons (snowball, avalanche, accelerated payments).
//
//  FEATURES:
//  ✅ Fixed-rate loan amortization (mortgage, auto, personal)
//  ✅ Credit card payoff with minimum payments
//  ✅ Extra payment impact projections
//  ✅ "1/6 Trick" mortgage acceleration (inspired by viral strategy)
//  ✅ Debt snowball vs avalanche comparison
//  ✅ Interest savings calculations
//  ✅ Payoff timeline visualization data
//

import Foundation
import SwiftData

// MARK: - Debt Type

/// Types of debt with different payment structures
enum DebtType: String, Codable, CaseIterable, Identifiable {
    case mortgage = "mortgage"
    case autoLoan = "auto_loan"
    case personalLoan = "personal_loan"
    case studentLoan = "student_loan"
    case creditCard = "credit_card"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mortgage: return "Mortgage"
        case .autoLoan: return "Auto Loan"
        case .personalLoan: return "Personal Loan"
        case .studentLoan: return "Student Loan"
        case .creditCard: return "Credit Card"
        case .other: return "Other Debt"
        }
    }
    
    var icon: String {
        switch self {
        case .mortgage: return "house.fill"
        case .autoLoan: return "car.fill"
        case .personalLoan: return "banknote.fill"
        case .studentLoan: return "graduationcap.fill"
        case .creditCard: return "creditcard.fill"
        case .other: return "dollarsign.circle.fill"
        }
    }
    
    /// Whether this debt type uses fixed monthly payments (amortized)
    var isAmortized: Bool {
        switch self {
        case .mortgage, .autoLoan, .personalLoan, .studentLoan:
            return true
        case .creditCard, .other:
            return false
        }
    }
    
    /// Typical loan term in months for UI defaults
    var typicalTermMonths: Int {
        switch self {
        case .mortgage: return 360 // 30 years
        case .autoLoan: return 60 // 5 years
        case .personalLoan: return 36 // 3 years
        case .studentLoan: return 120 // 10 years
        case .creditCard: return 0 // No fixed term
        case .other: return 60
        }
    }
}

// MARK: - Payment Strategy

/// Debt payoff strategies
enum PayoffStrategy: String, Codable, CaseIterable, Identifiable {
    case minimumOnly = "minimum"
    case fixed = "fixed"
    case oneSixthTrick = "one_sixth"
    case snowball = "snowball"
    case avalanche = "avalanche"
    case custom = "custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .minimumOnly: return "Minimum Payments"
        case .fixed: return "Fixed Extra Payment"
        case .oneSixthTrick: return "1/6 Trick"
        case .snowball: return "Debt Snowball"
        case .avalanche: return "Debt Avalanche"
        case .custom: return "Custom Strategy"
        }
    }
    
    var description: String {
        switch self {
        case .minimumOnly:
            return "Pay only the required minimum each month"
        case .fixed:
            return "Add a fixed extra amount to each payment"
        case .oneSixthTrick:
            return "Divide your P&I payment by 6 and add that as extra principal monthly"
        case .snowball:
            return "Pay off smallest balances first for quick wins"
        case .avalanche:
            return "Pay off highest interest rates first to minimize total interest"
        case .custom:
            return "Set your own extra payment amount"
        }
    }
}

// MARK: - Debt Input Model

/// Input model for debt calculations
struct DebtInput: Identifiable, Hashable {
    let id: UUID
    var name: String
    var debtType: DebtType
    var currentBalance: Double
    var interestRate: Double // APR as percentage (e.g., 6.5 for 6.5%)
    var monthlyPayment: Double // For amortized loans: P&I payment
    var remainingTermMonths: Int? // For amortized loans
    var minimumPaymentPercent: Double? // For credit cards (e.g., 2.0 for 2%)
    var minimumPaymentFloor: Double? // For credit cards (e.g., $25)
    
    init(
        id: UUID = UUID(),
        name: String,
        debtType: DebtType,
        currentBalance: Double,
        interestRate: Double,
        monthlyPayment: Double = 0,
        remainingTermMonths: Int? = nil,
        minimumPaymentPercent: Double? = nil,
        minimumPaymentFloor: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.debtType = debtType
        self.currentBalance = abs(currentBalance) // Always positive for calculations
        self.interestRate = interestRate
        self.monthlyPayment = monthlyPayment
        self.remainingTermMonths = remainingTermMonths
        self.minimumPaymentPercent = minimumPaymentPercent
        self.minimumPaymentFloor = minimumPaymentFloor
    }
    
    /// Create from Account model
    static func fromAccount(_ account: Account) -> DebtInput? {
        guard account.currentBalance < 0 else { return nil } // Only debts

        let debtType: DebtType
        switch account.accountType {
        case .creditCard:
            debtType = .creditCard
        case .loan:
            // Map LoanType to DebtType using the new loanTypeRaw field
            switch account.loanType {
            case .sba, .business:  debtType = .personalLoan // SBA treated as amortized loan
            case .mortgage:        debtType = .mortgage
            case .auto:            debtType = .autoLoan
            case .student:         debtType = .studentLoan
            case .personal:        debtType = .personalLoan
            case .other:           debtType = .other
            }
        default:
            return nil
        }

        return DebtInput(
            id: account.id,
            name: account.name,
            debtType: debtType,
            currentBalance: account.currentBalance,
            interestRate: account.apr ?? 0,
            monthlyPayment: account.monthlyPaymentAmount ?? 0,
            remainingTermMonths: account.estimatedRemainingTermMonths,
            minimumPaymentPercent: account.minimumPaymentPercent ?? 2.0,
            minimumPaymentFloor: account.minimumPaymentFloor ?? 25.0
        )
    }
}

// MARK: - Payoff Result

/// Result of a payoff calculation
struct PayoffResult: Identifiable {
    let id = UUID()
    let strategy: PayoffStrategy
    let totalMonths: Int
    let totalPaid: Double
    let totalInterest: Double
    let monthlyPayment: Double // Average or fixed monthly payment
    let extraPayment: Double // Extra amount per month
    let interestSaved: Double // vs minimum payments
    let monthsSaved: Int // vs minimum payments
    let schedule: [DebtPaymentEntry]
    var interestTrap: Bool = false // True when minimum payments can't cover interest
    
    var payoffDate: Date {
        Calendar.current.date(byAdding: .month, value: totalMonths, to: Date()) ?? Date()
    }
    
    var yearsToPayoff: Double {
        Double(totalMonths) / 12.0
    }
}

// MARK: - Debt Payment Entry

/// Single month in a debt payment schedule
/// Named differently from CreditCardCalculationService.PaymentScheduleEntry to avoid conflicts
struct DebtPaymentEntry: Identifiable {
    let id = UUID()
    let month: Int
    let date: Date
    let payment: Double
    let principal: Double
    let interest: Double
    let extraPrincipal: Double
    let remainingBalance: Double
    let cumulativeInterest: Double
    let cumulativePrincipal: Double
}

// MARK: - Debt Calculation Service

@MainActor
final class DebtCalculationService {
    
    static let shared = DebtCalculationService()
    
    private init() {}
    
    // MARK: - Fixed Rate Loan Calculations (Mortgage, Auto, Personal)
    
    /// Calculate monthly P&I payment for a fixed-rate amortized loan
    ///
    /// Formula: M = P * [r(1+r)^n] / [(1+r)^n - 1]
    /// Where: P = principal, r = monthly rate, n = number of payments
    ///
    /// - Parameters:
    ///   - principal: Loan amount
    ///   - annualRate: Annual interest rate as percentage (e.g., 6.5)
    ///   - termMonths: Loan term in months
    /// - Returns: Monthly payment amount
    func calculateMonthlyPayment(principal: Double, annualRate: Double, termMonths: Int) -> Double {
        guard principal > 0, annualRate > 0, termMonths > 0 else {
            // 0% interest = simple division
            return annualRate == 0 && termMonths > 0 ? principal / Double(termMonths) : 0
        }
        
        let monthlyRate = annualRate / 100.0 / 12.0
        let factor = pow(1 + monthlyRate, Double(termMonths))
        return principal * (monthlyRate * factor) / (factor - 1)
    }
    
    /// Generate full amortization schedule for a fixed-rate loan
    ///
    /// - Parameters:
    ///   - principal: Current loan balance
    ///   - annualRate: Annual interest rate as percentage
    ///   - monthlyPayment: Fixed monthly P&I payment
    ///   - extraMonthlyPayment: Additional principal payment each month
    ///   - maxMonths: Maximum months to project (safety limit)
    /// - Returns: Array of payment schedule entries
    func generateAmortizationSchedule(
        principal: Double,
        annualRate: Double,
        monthlyPayment: Double,
        extraMonthlyPayment: Double = 0,
        maxMonths: Int = 600
    ) -> [DebtPaymentEntry] {
        guard principal > 0, monthlyPayment > 0 else { return [] }
        
        let monthlyRate = annualRate / 100.0 / 12.0
        var balance = principal
        var schedule: [DebtPaymentEntry] = []
        var month = 0
        var cumulativeInterest = 0.0
        var cumulativePrincipal = 0.0
        
        let calendar = Calendar.current
        let startDate = Date()
        
        while balance > 0.01 && month < maxMonths {
            month += 1
            
            // Calculate interest for this month
            let interest = balance * monthlyRate
            
            // Calculate principal portion of regular payment
            let regularPrincipal = min(monthlyPayment - interest, balance)
            
            // Apply extra payment to principal
            let extraPrincipal = min(extraMonthlyPayment, balance - regularPrincipal)
            let totalPrincipal = regularPrincipal + extraPrincipal
            
            // Total payment this month
            let totalPayment = interest + totalPrincipal
            
            // Update balance
            balance -= totalPrincipal
            cumulativeInterest += interest
            cumulativePrincipal += totalPrincipal
            
            let paymentDate = calendar.date(byAdding: .month, value: month, to: startDate) ?? startDate
            
            schedule.append(DebtPaymentEntry(
                month: month,
                date: paymentDate,
                payment: totalPayment,
                principal: regularPrincipal,
                interest: interest,
                extraPrincipal: extraPrincipal,
                remainingBalance: max(0, balance),
                cumulativeInterest: cumulativeInterest,
                cumulativePrincipal: cumulativePrincipal
            ))
        }
        
        return schedule
    }
    
    /// Calculate payoff projections for a fixed-rate loan with different strategies
    ///
    /// - Parameters:
    ///   - debt: Debt input details
    ///   - extraPayment: Optional fixed extra payment (for .fixed strategy)
    /// - Returns: Dictionary of results keyed by strategy
    func calculateFixedLoanPayoff(
        debt: DebtInput,
        extraPayment: Double? = nil
    ) -> [PayoffStrategy: PayoffResult] {
        var results: [PayoffStrategy: PayoffResult] = [:]
        
        let monthlyPayment = debt.monthlyPayment > 0
            ? debt.monthlyPayment
            : calculateMonthlyPayment(
                principal: debt.currentBalance,
                annualRate: debt.interestRate,
                termMonths: debt.remainingTermMonths ?? 360
            )
        
        // 1. Minimum (standard) payments
        let standardSchedule = generateAmortizationSchedule(
            principal: debt.currentBalance,
            annualRate: debt.interestRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: 0
        )
        
        if let lastEntry = standardSchedule.last {
            results[.minimumOnly] = PayoffResult(
                strategy: .minimumOnly,
                totalMonths: standardSchedule.count,
                totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                totalInterest: lastEntry.cumulativeInterest,
                monthlyPayment: monthlyPayment,
                extraPayment: 0,
                interestSaved: 0,
                monthsSaved: 0,
                schedule: standardSchedule
            )
        }
        
        // 2. 1/6 Trick - Add 1/6 of P&I as extra principal
        let oneSixthExtra = monthlyPayment / 6.0
        let oneSixthSchedule = generateAmortizationSchedule(
            principal: debt.currentBalance,
            annualRate: debt.interestRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: oneSixthExtra
        )
        
        if let lastEntry = oneSixthSchedule.last,
           let standardResult = results[.minimumOnly] {
            results[.oneSixthTrick] = PayoffResult(
                strategy: .oneSixthTrick,
                totalMonths: oneSixthSchedule.count,
                totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                totalInterest: lastEntry.cumulativeInterest,
                monthlyPayment: monthlyPayment + oneSixthExtra,
                extraPayment: oneSixthExtra,
                interestSaved: standardResult.totalInterest - lastEntry.cumulativeInterest,
                monthsSaved: standardResult.totalMonths - oneSixthSchedule.count,
                schedule: oneSixthSchedule
            )
        }
        
        // 3. Fixed extra payment (if provided)
        if let extra = extraPayment, extra > 0 {
            let customSchedule = generateAmortizationSchedule(
                principal: debt.currentBalance,
                annualRate: debt.interestRate,
                monthlyPayment: monthlyPayment,
                extraMonthlyPayment: extra
            )
            
            if let lastEntry = customSchedule.last,
               let standardResult = results[.minimumOnly] {
                results[.fixed] = PayoffResult(
                    strategy: .fixed,
                    totalMonths: customSchedule.count,
                    totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                    totalInterest: lastEntry.cumulativeInterest,
                    monthlyPayment: monthlyPayment + extra,
                    extraPayment: extra,
                    interestSaved: standardResult.totalInterest - lastEntry.cumulativeInterest,
                    monthsSaved: standardResult.totalMonths - customSchedule.count,
                    schedule: customSchedule
                )
            }
        }
        
        return results
    }
    
    // MARK: - Credit Card Calculations
    
    /// Calculate credit card payoff with minimum payments
    ///
    /// Credit cards use percentage-based minimum payments with a floor,
    /// unlike fixed-payment amortized loans.
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual percentage rate
    ///   - minimumPercent: Minimum payment as % of balance (e.g., 2.0)
    ///   - minimumFloor: Minimum payment floor (e.g., $25)
    ///   - extraPayment: Additional monthly payment
    ///   - maxMonths: Safety limit
    /// - Returns: Payment schedule
    func generateCreditCardSchedule(
        balance: Double,
        apr: Double,
        minimumPercent: Double = 2.0,
        minimumFloor: Double = 25.0,
        extraPayment: Double = 0,
        maxMonths: Int = 600
    ) -> (schedule: [DebtPaymentEntry], interestTrap: Bool) {
        guard balance > 0, apr >= 0 else { return ([], false) }

        let monthlyRate = apr / 100.0 / 12.0
        var currentBalance = balance
        var schedule: [DebtPaymentEntry] = []
        var month = 0
        var cumulativeInterest = 0.0
        var cumulativePrincipal = 0.0

        let calendar = Calendar.current
        let startDate = Date()

        // Interest trap detection: minimum payment + extra can't cover monthly interest
        if apr > 0 {
            let initialInterest = currentBalance * monthlyRate
            let initialMinPayment = max(currentBalance * (minimumPercent / 100.0), minimumFloor)
            if initialMinPayment + extraPayment <= initialInterest {
                return ([], true) // Interest trap — signal to caller
            }
        }

        while currentBalance > 0.01 && month < maxMonths {
            month += 1

            // 1. Calculate interest on the PRE-interest balance
            let interest = currentBalance * monthlyRate

            // 2. Calculate minimum payment on the PRE-interest balance (how CC companies do it)
            let minPayment = max(
                currentBalance * (minimumPercent / 100.0),
                min(minimumFloor, currentBalance + interest)
            )

            // 3. Total payment = minimum + any extra, capped at full payoff
            let totalPayment = min(minPayment + extraPayment, currentBalance + interest)

            // 4. Principal paid = total payment minus interest portion
            let principalPaid = max(0, totalPayment - interest)
            let extraPrincipalPaid = extraPayment > 0 ? max(0, min(extraPayment, principalPaid)) : 0

            // 5. Update balance: add interest, subtract total payment
            currentBalance = currentBalance + interest - totalPayment
            cumulativeInterest += interest
            cumulativePrincipal += principalPaid

            let paymentDate = calendar.date(byAdding: .month, value: month, to: startDate) ?? startDate

            schedule.append(DebtPaymentEntry(
                month: month,
                date: paymentDate,
                payment: totalPayment,
                principal: principalPaid - extraPrincipalPaid,
                interest: interest,
                extraPrincipal: extraPrincipalPaid,
                remainingBalance: max(0, currentBalance),
                cumulativeInterest: cumulativeInterest,
                cumulativePrincipal: cumulativePrincipal
            ))
        }

        return (schedule, false)
    }
    
    /// Calculate credit card payoff with different strategies
    func calculateCreditCardPayoff(
        debt: DebtInput,
        extraPayment: Double? = nil
    ) -> [PayoffStrategy: PayoffResult] {
        var results: [PayoffStrategy: PayoffResult] = [:]

        let minPercent = debt.minimumPaymentPercent ?? 2.0
        let minFloor = debt.minimumPaymentFloor ?? 25.0

        // 1. Minimum payments only
        let standardResult = generateCreditCardSchedule(
            balance: debt.currentBalance,
            apr: debt.interestRate,
            minimumPercent: minPercent,
            minimumFloor: minFloor,
            extraPayment: 0
        )

        // Interest trap: signal stored on PayoffResult for the view to display
        if standardResult.interestTrap {
            results[.minimumOnly] = PayoffResult(
                strategy: .minimumOnly,
                totalMonths: 0,
                totalPaid: 0,
                totalInterest: 0,
                monthlyPayment: 0,
                extraPayment: 0,
                interestSaved: 0,
                monthsSaved: 0,
                schedule: [],
                interestTrap: true
            )
            return results
        }

        if let lastEntry = standardResult.schedule.last {
            let avgPayment = standardResult.schedule.reduce(0.0) { $0 + $1.payment } / Double(standardResult.schedule.count)

            results[.minimumOnly] = PayoffResult(
                strategy: .minimumOnly,
                totalMonths: standardResult.schedule.count,
                totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                totalInterest: lastEntry.cumulativeInterest,
                monthlyPayment: avgPayment,
                extraPayment: 0,
                interestSaved: 0,
                monthsSaved: 0,
                schedule: standardResult.schedule
            )
        }

        // 2. 1/6 Trick — use average minimum payment / 6 as extra
        if let standardPayoff = results[.minimumOnly], standardPayoff.monthlyPayment > 0 {
            let oneSixthExtra = standardPayoff.monthlyPayment / 6.0
            let oneSixthResult = generateCreditCardSchedule(
                balance: debt.currentBalance,
                apr: debt.interestRate,
                minimumPercent: minPercent,
                minimumFloor: minFloor,
                extraPayment: oneSixthExtra
            )

            if let lastEntry = oneSixthResult.schedule.last {
                let avgPayment = oneSixthResult.schedule.reduce(0.0) { $0 + $1.payment } / Double(oneSixthResult.schedule.count)

                results[.oneSixthTrick] = PayoffResult(
                    strategy: .oneSixthTrick,
                    totalMonths: oneSixthResult.schedule.count,
                    totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                    totalInterest: lastEntry.cumulativeInterest,
                    monthlyPayment: avgPayment,
                    extraPayment: oneSixthExtra,
                    interestSaved: standardPayoff.totalInterest - lastEntry.cumulativeInterest,
                    monthsSaved: standardPayoff.totalMonths - oneSixthResult.schedule.count,
                    schedule: oneSixthResult.schedule
                )
            }
        }

        // 3. Fixed extra payment
        if let extra = extraPayment, extra > 0 {
            let customResult = generateCreditCardSchedule(
                balance: debt.currentBalance,
                apr: debt.interestRate,
                minimumPercent: minPercent,
                minimumFloor: minFloor,
                extraPayment: extra
            )

            if let lastEntry = customResult.schedule.last,
               let standardPayoff = results[.minimumOnly] {
                let avgPayment = customResult.schedule.reduce(0.0) { $0 + $1.payment } / Double(customResult.schedule.count)

                results[.fixed] = PayoffResult(
                    strategy: .fixed,
                    totalMonths: customResult.schedule.count,
                    totalPaid: lastEntry.cumulativePrincipal + lastEntry.cumulativeInterest,
                    totalInterest: lastEntry.cumulativeInterest,
                    monthlyPayment: avgPayment,
                    extraPayment: extra,
                    interestSaved: standardPayoff.totalInterest - lastEntry.cumulativeInterest,
                    monthsSaved: standardPayoff.totalMonths - customResult.schedule.count,
                    schedule: customResult.schedule
                )
            }
        }

        return results
    }
    
    // MARK: - Unified Payoff Calculator
    
    /// Calculate payoff for any debt type
    func calculatePayoff(
        debt: DebtInput,
        extraPayment: Double? = nil
    ) -> [PayoffStrategy: PayoffResult] {
        if debt.debtType.isAmortized {
            return calculateFixedLoanPayoff(debt: debt, extraPayment: extraPayment)
        } else {
            return calculateCreditCardPayoff(debt: debt, extraPayment: extraPayment)
        }
    }
    
    // MARK: - Multi-Debt Strategies
    
    /// Calculate debt snowball payoff order (smallest balance first)
    func snowballOrder(debts: [DebtInput]) -> [DebtInput] {
        debts.sorted { $0.currentBalance < $1.currentBalance }
    }
    
    /// Calculate debt avalanche payoff order (highest interest first)
    func avalancheOrder(debts: [DebtInput]) -> [DebtInput] {
        debts.sorted { $0.interestRate > $1.interestRate }
    }
    
    // MARK: - Quick Calculations for Insights
    
    /// Quick calculation: How much would the 1/6 trick save on a mortgage?
    func quickOneSixthSavings(
        balance: Double,
        annualRate: Double,
        monthlyPayment: Double
    ) -> (interestSaved: Double, monthsSaved: Int)? {
        guard balance > 0, monthlyPayment > 0 else { return nil }
        
        let standardSchedule = generateAmortizationSchedule(
            principal: balance,
            annualRate: annualRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: 0
        )
        
        let acceleratedSchedule = generateAmortizationSchedule(
            principal: balance,
            annualRate: annualRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: monthlyPayment / 6.0
        )
        
        guard let standardLast = standardSchedule.last,
              let acceleratedLast = acceleratedSchedule.last else { return nil }
        
        let interestSaved = standardLast.cumulativeInterest - acceleratedLast.cumulativeInterest
        let monthsSaved = standardSchedule.count - acceleratedSchedule.count
        
        return (interestSaved, monthsSaved)
    }
    
    /// Quick calculation: Interest saved from extra monthly payment
    func quickExtraPaymentSavings(
        balance: Double,
        annualRate: Double,
        monthlyPayment: Double,
        extraPayment: Double
    ) -> (interestSaved: Double, monthsSaved: Int)? {
        guard balance > 0, monthlyPayment > 0, extraPayment > 0 else { return nil }
        
        let standardSchedule = generateAmortizationSchedule(
            principal: balance,
            annualRate: annualRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: 0
        )
        
        let acceleratedSchedule = generateAmortizationSchedule(
            principal: balance,
            annualRate: annualRate,
            monthlyPayment: monthlyPayment,
            extraMonthlyPayment: extraPayment
        )
        
        guard let standardLast = standardSchedule.last,
              let acceleratedLast = acceleratedSchedule.last else { return nil }
        
        return (
            standardLast.cumulativeInterest - acceleratedLast.cumulativeInterest,
            standardSchedule.count - acceleratedSchedule.count
        )
    }
}

// MARK: - Currency Formatting Extension

extension DebtCalculationService {
    
    func formatCurrency(_ amount: Double) -> String {
        return NumberFormatter.appCurrencyCompact.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }

    func formatCurrencyPrecise(_ amount: Double) -> String {
        return NumberFormatter.appCurrency.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}
