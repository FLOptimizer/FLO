//  CreditCardCalculationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (multiplication symbols)
//
//  CHANGES v1.2.1:
//  ✅ FIXED: Restored maxMonths to 600 (min payments can legitimately take 50 years)
//
//  CHANGES v1.2:
//  ✅ ADDED: Interest trap detection in calculatePayoffMonths()
//  ✅ ADDED: Interest trap detection in calculateTotalCostWithMinimumPayments()
//  ✅ ADDED: Early exit when minimum payment ≤ interest (prevents infinite loops)
//
//  CHANGES v1.1:
//  - Fixed zero limit bug in getUtilizationStatus() returning .excellent instead of .unknown
//  - Simplified utilizationStatus logic in CreditCardSummary (removed redundant condition)
//  - Made status calculation consistent between service method and struct
//  - Added formula comments for maintainability
//  - Added extra payment parameter to payoff projection
//
//  FEATURES:
//  - Monthly interest calculations based on APR
//  - Payoff timeline projections
//  - Minimum payment calculations
//  - Credit utilization tracking
//  - Payment schedule generation
//

import Foundation
import SwiftData

// MARK: - Credit Card Calculation Service

@MainActor
final class CreditCardCalculationService {
    
    static let shared = CreditCardCalculationService()
    
    private init() {}
    
    // MARK: - Interest Calculations
    
    /// Calculate monthly interest charge for a credit card
    ///
    /// Formula: `|balance| × (APR / 100 / 12)`
    ///
    /// - Parameters:
    ///   - balance: Current balance (should be negative for owed amount)
    ///   - apr: Annual Percentage Rate (e.g., 24.99 for 24.99%)
    /// - Returns: Monthly interest amount
    func calculateMonthlyInterest(balance: Double, apr: Double) -> Double {
        guard balance < 0, apr > 0 else { return 0 }
        let monthlyRate = apr / 100.0 / 12.0
        return abs(balance) * monthlyRate
    }
    
    /// Calculate daily interest charge
    ///
    /// Formula: `|balance| × (APR / 100 / 365)`
    ///
    /// - Parameters:
    ///   - balance: Current balance (should be negative for owed amount)
    ///   - apr: Annual Percentage Rate
    /// - Returns: Daily interest amount
    func calculateDailyInterest(balance: Double, apr: Double) -> Double {
        guard balance < 0, apr > 0 else { return 0 }
        let dailyRate = apr / 100.0 / 365.0
        return abs(balance) * dailyRate
    }
    
    /// Calculate total interest over a period (with compounding, no payments)
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - months: Number of months
    /// - Returns: Total interest accrued
    func calculateInterestOverPeriod(balance: Double, apr: Double, months: Int) -> Double {
        guard balance < 0, apr > 0, months > 0 else { return 0 }
        let monthlyRate = apr / 100.0 / 12.0
        var totalInterest = 0.0
        var runningBalance = abs(balance)
        
        for _ in 0..<months {
            let monthInterest = runningBalance * monthlyRate
            totalInterest += monthInterest
            runningBalance += monthInterest
        }
        
        return totalInterest
    }
    
    // MARK: - Minimum Payment Calculations
    
    /// Calculate minimum payment due
    ///
    /// Formula: `max(balance × percent, min(floor, balance))`
    /// Most cards require 2% of balance or $25, whichever is greater
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - percentRate: Minimum payment as percentage (e.g., 2.0 for 2%)
    ///   - floor: Minimum dollar amount regardless of percentage
    /// - Returns: Minimum payment amount
    func calculateMinimumPayment(balance: Double, percentRate: Double = 2.0, floor: Double = 25.0) -> Double {
        guard balance < 0 else { return 0 }
        let absBalance = abs(balance)
        let percentPayment = absBalance * (percentRate / 100.0)
        return max(percentPayment, min(floor, absBalance))
    }
    
    // MARK: - Payoff Projections
    
    /// Calculate months to pay off balance with minimum payments only
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - minimumPercent: Minimum payment percentage
    ///   - minimumFloor: Minimum payment floor
    ///   - extraMonthlyPayment: Additional amount paid each month beyond minimum
    /// - Returns: Number of months to payoff (nil if would never pay off)
    func calculatePayoffMonths(
        balance: Double,
        apr: Double,
        minimumPercent: Double = 2.0,
        minimumFloor: Double = 25.0,
        extraMonthlyPayment: Double = 0
    ) -> Int? {
        guard balance < 0, apr > 0 else { return nil }
        
        let monthlyRate = apr / 100.0 / 12.0
        var runningBalance = abs(balance)
        var months = 0
        let maxMonths = 600 // 50 year cap - min payments can take decades
        
        // Early detection: Check if initial payment can exceed interest
        // This catches scenarios where debt can never be paid off
        let initialInterest = runningBalance * monthlyRate
        let initialMinPayment = max(runningBalance * (minimumPercent / 100.0), minimumFloor)
        let initialTotalPayment = initialMinPayment + extraMonthlyPayment
        
        // If payment doesn't exceed interest, debt will never be paid off
        if initialTotalPayment <= initialInterest {
            return nil // Interest trap detected
        }
        
        while runningBalance > 0.01 && months < maxMonths {
            // Add interest first
            let interest = runningBalance * monthlyRate
            runningBalance += interest
            
            // Calculate and apply payment
            let minPayment = max(runningBalance * (minimumPercent / 100.0), min(minimumFloor, runningBalance))
            let totalPayment = min(minPayment + extraMonthlyPayment, runningBalance)
            
            runningBalance -= totalPayment
            months += 1
        }
        
        return months < maxMonths ? months : nil
    }
    
    /// Calculate total cost (principal + interest) with minimum payments
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - minimumPercent: Minimum payment percentage
    ///   - minimumFloor: Minimum payment floor
    ///   - extraMonthlyPayment: Additional amount paid each month beyond minimum
    /// - Returns: Tuple of (totalPaid, totalInterest, months) or nil if never pays off
    func calculateTotalCostWithMinimumPayments(
        balance: Double,
        apr: Double,
        minimumPercent: Double = 2.0,
        minimumFloor: Double = 25.0,
        extraMonthlyPayment: Double = 0
    ) -> (totalPaid: Double, totalInterest: Double, months: Int)? {
        guard balance < 0, apr > 0 else { return nil }
        
        let monthlyRate = apr / 100.0 / 12.0
        var runningBalance = abs(balance)
        var totalPaid = 0.0
        var totalInterest = 0.0
        var months = 0
        let maxMonths = 600 // 50 year cap - min payments can take decades
        
        // Early detection: Check if initial payment can exceed interest
        let initialInterest = runningBalance * monthlyRate
        let initialMinPayment = max(runningBalance * (minimumPercent / 100.0), minimumFloor)
        let initialTotalPayment = initialMinPayment + extraMonthlyPayment
        
        // If payment doesn't exceed interest, debt will never be paid off
        if initialTotalPayment <= initialInterest {
            return nil // Interest trap detected
        }
        
        while runningBalance > 0.01 && months < maxMonths {
            // Add interest first
            let interest = runningBalance * monthlyRate
            runningBalance += interest
            totalInterest += interest
            
            // Calculate and apply payment
            let minPayment = max(runningBalance * (minimumPercent / 100.0), min(minimumFloor, runningBalance))
            let totalPayment = min(minPayment + extraMonthlyPayment, runningBalance)
            
            runningBalance -= totalPayment
            totalPaid += totalPayment
            months += 1
        }
        
        guard months < maxMonths else { return nil }
        return (totalPaid, totalInterest, months)
    }
    
    /// Calculate payoff with fixed monthly payment
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - monthlyPayment: Fixed payment amount
    /// - Returns: Tuple of (months, totalInterest) or nil if payment too low to pay off
    func calculatePayoffWithFixedPayment(
        balance: Double,
        apr: Double,
        monthlyPayment: Double
    ) -> (months: Int, totalInterest: Double)? {
        guard balance < 0, apr > 0, monthlyPayment > 0 else { return nil }
        
        let monthlyRate = apr / 100.0 / 12.0
        let minPaymentNeeded = abs(balance) * monthlyRate
        
        // Payment must exceed monthly interest to ever pay off
        guard monthlyPayment > minPaymentNeeded else { return nil }
        
        var runningBalance = abs(balance)
        var totalInterest = 0.0
        var months = 0
        let maxMonths = 600
        
        while runningBalance > 0.01 && months < maxMonths {
            // Add interest first
            let interest = runningBalance * monthlyRate
            runningBalance += interest
            totalInterest += interest
            
            // Apply payment (capped at remaining balance)
            let payment = min(monthlyPayment, runningBalance)
            runningBalance -= payment
            months += 1
        }
        
        guard months < maxMonths else { return nil }
        return (months, totalInterest)
    }
    
    /// Compare payoff scenarios: minimum only vs. with extra payment
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - minimumPercent: Minimum payment percentage
    ///   - minimumFloor: Minimum payment floor
    ///   - extraPayment: Extra monthly payment to compare
    /// - Returns: Comparison showing time and interest saved
    func comparePayoffScenarios(
        balance: Double,
        apr: Double,
        minimumPercent: Double = 2.0,
        minimumFloor: Double = 25.0,
        extraPayment: Double
    ) -> PayoffComparison? {
        guard let minimumOnly = calculateTotalCostWithMinimumPayments(
            balance: balance,
            apr: apr,
            minimumPercent: minimumPercent,
            minimumFloor: minimumFloor
        ),
        let withExtra = calculateTotalCostWithMinimumPayments(
            balance: balance,
            apr: apr,
            minimumPercent: minimumPercent,
            minimumFloor: minimumFloor,
            extraMonthlyPayment: extraPayment
        ) else {
            return nil
        }
        
        return PayoffComparison(
            minimumOnlyMonths: minimumOnly.months,
            minimumOnlyInterest: minimumOnly.totalInterest,
            minimumOnlyTotalPaid: minimumOnly.totalPaid,
            withExtraMonths: withExtra.months,
            withExtraInterest: withExtra.totalInterest,
            withExtraTotalPaid: withExtra.totalPaid,
            extraMonthlyPayment: extraPayment,
            monthsSaved: minimumOnly.months - withExtra.months,
            interestSaved: minimumOnly.totalInterest - withExtra.totalInterest
        )
    }
    
    // MARK: - Credit Utilization
    
    /// Calculate credit utilization percentage
    ///
    /// Formula: `(|balance| / limit) × 100`
    ///
    /// - Parameters:
    ///   - balance: Current balance (negative)
    ///   - limit: Credit limit
    /// - Returns: Utilization percentage (0-100+)
    func calculateUtilization(balance: Double, limit: Double) -> Double {
        guard limit > 0 else { return 0 }
        return (abs(balance) / limit) * 100.0
    }
    
    /// Get utilization status based on balance and limit
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - limit: Credit limit
    /// - Returns: Status rating (excellent/good/fair/poor/unknown)
    func getUtilizationStatus(balance: Double, limit: Double) -> CreditUtilizationStatus {
        // FIXED: Return .unknown if no limit set (was returning .excellent via 0% utilization)
        guard limit > 0 else { return .unknown }
        
        let utilization = calculateUtilization(balance: balance, limit: limit)
        
        switch utilization {
        case ...30:
            return .excellent
        case ...50:
            return .good
        case ...75:
            return .fair
        default:
            return .poor
        }
    }
    
    // MARK: - Aggregate Calculations
    
    /// Calculate totals across all credit card accounts
    ///
    /// - Parameter accounts: Array of all accounts (will filter to active credit cards)
    /// - Returns: Summary struct with aggregated data
    func calculateCreditCardTotals(accounts: [Account]) -> CreditCardSummary {
        let creditCards = accounts.filter { $0.accountType == .creditCard && $0.isActive }
        
        let totalBalance = creditCards.reduce(0.0) { $0 + $1.currentBalance }
        let totalLimit = creditCards.compactMap { $0.creditLimit }.reduce(0.0, +)
        let totalAvailable = creditCards.compactMap { $0.availableCredit }.reduce(0.0, +)
        
        let totalMonthlyInterest = creditCards.reduce(0.0) { total, card in
            total + (card.estimatedMonthlyInterest ?? 0)
        }
        
        let totalMinimumDue = creditCards.reduce(0.0) { total, card in
            total + (card.minimumPaymentDue ?? 0)
        }
        
        let overallUtilization = totalLimit > 0 ? (abs(totalBalance) / totalLimit) * 100.0 : 0
        
        let cardsWithPaymentsDueSoon = creditCards.filter { $0.isPaymentDueSoon }.count
        let cardsOverdue = creditCards.filter { $0.isPaymentOverdue }.count
        
        return CreditCardSummary(
            totalBalance: totalBalance,
            totalCreditLimit: totalLimit,
            totalAvailableCredit: totalAvailable,
            overallUtilization: overallUtilization,
            estimatedMonthlyInterest: totalMonthlyInterest,
            totalMinimumPaymentDue: totalMinimumDue,
            cardCount: creditCards.count,
            cardsWithPaymentsDueSoon: cardsWithPaymentsDueSoon,
            cardsOverdue: cardsOverdue
        )
    }
    
    // MARK: - Payment Schedule
    
    /// Generate a payment schedule showing payoff progress
    ///
    /// - Parameters:
    ///   - balance: Current balance
    ///   - apr: Annual Percentage Rate
    ///   - monthlyPayment: Fixed monthly payment amount
    ///   - maxMonths: Maximum months to project (default 60 / 5 years)
    /// - Returns: Array of monthly payment entries
    func generatePaymentSchedule(
        balance: Double,
        apr: Double,
        monthlyPayment: Double,
        maxMonths: Int = 60
    ) -> [PaymentScheduleEntry] {
        guard balance < 0, apr > 0, monthlyPayment > 0 else { return [] }
        
        let monthlyRate = apr / 100.0 / 12.0
        var runningBalance = abs(balance)
        var schedule: [PaymentScheduleEntry] = []
        var month = 0
        var cumulativeInterest = 0.0
        var cumulativePrincipal = 0.0
        
        let calendar = Calendar.current
        let startDate = Date()
        
        while runningBalance > 0.01 && month < maxMonths {
            // Add interest first
            let interest = runningBalance * monthlyRate
            runningBalance += interest
            cumulativeInterest += interest
            
            // Apply payment
            let payment = min(monthlyPayment, runningBalance)
            let principalPaid = payment - interest
            runningBalance -= payment
            cumulativePrincipal += max(0, principalPaid)
            
            month += 1
            
            let paymentDate = calendar.date(byAdding: .month, value: month, to: startDate) ?? startDate
            
            let entry = PaymentScheduleEntry(
                month: month,
                date: paymentDate,
                payment: payment,
                principal: max(0, principalPaid),
                interest: interest,
                remainingBalance: max(0, runningBalance),
                cumulativeInterest: cumulativeInterest,
                cumulativePrincipal: cumulativePrincipal
            )
            
            schedule.append(entry)
        }
        
        return schedule
    }
}

// MARK: - Supporting Types

struct CreditCardSummary {
    let totalBalance: Double
    let totalCreditLimit: Double
    let totalAvailableCredit: Double
    let overallUtilization: Double
    let estimatedMonthlyInterest: Double
    let totalMinimumPaymentDue: Double
    let cardCount: Int
    let cardsWithPaymentsDueSoon: Int
    let cardsOverdue: Int
    
    /// Credit utilization status based on overall utilization
    var utilizationStatus: CreditUtilizationStatus {
        // FIXED: Guard against zero limit first, then use clean switch
        guard totalCreditLimit > 0 else { return .unknown }
        
        switch overallUtilization {
        case ...30:
            return .excellent
        case ...50:
            return .good
        case ...75:
            return .fair
        default:
            return .poor
        }
    }
    
    /// Whether any cards have urgent payment situations
    var hasUrgentPayments: Bool {
        cardsWithPaymentsDueSoon > 0 || cardsOverdue > 0
    }
    
    /// Whether all cards are paid off
    var isAllPaidOff: Bool {
        totalBalance >= 0
    }
}

/// Comparison between minimum-only payments vs. extra payments
struct PayoffComparison {
    let minimumOnlyMonths: Int
    let minimumOnlyInterest: Double
    let minimumOnlyTotalPaid: Double
    
    let withExtraMonths: Int
    let withExtraInterest: Double
    let withExtraTotalPaid: Double
    
    let extraMonthlyPayment: Double
    let monthsSaved: Int
    let interestSaved: Double
    
    /// Years saved by paying extra
    var yearsSaved: Double {
        Double(monthsSaved) / 12.0
    }
}

struct PaymentScheduleEntry: Identifiable {
    let id = UUID()
    let month: Int
    let date: Date
    let payment: Double
    let principal: Double
    let interest: Double
    let remainingBalance: Double
    let cumulativeInterest: Double
    let cumulativePrincipal: Double
    
    /// Formatted date string (e.g., "Jan 2026")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
    
    /// Percentage of payment going to principal
    var principalPercentage: Double {
        guard payment > 0 else { return 0 }
        return (principal / payment) * 100
    }
    
    /// Percentage of payment going to interest
    var interestPercentage: Double {
        guard payment > 0 else { return 0 }
        return (interest / payment) * 100
    }
}
