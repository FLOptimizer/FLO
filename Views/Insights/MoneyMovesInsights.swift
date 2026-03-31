//  MoneyMovesInsights.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 — Transfer Exclusion Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 — Transfer Exclusion:
//  ✅ FIXED: personalizedSpendingTips() excludes transfers from spending analysis
//
//  Extension to InsightsService that adds "Money Moves" financial tips
//  and debt optimization insights. Provides proactive guidance based on
//  user's accounts, transactions, and recurring payments.
//
//  FEATURES:
//  ✅ Generic financial literacy tips (Free tier)
//  ✅ Personalized debt insights (Premium+)
//  ✅ 1/6 Trick mortgage recommendations
//  ✅ Credit card payoff optimization
//  ✅ Recurring debt payment detection
//  ✅ Interest savings projections
//
//  CHANGES v1.1:
//  ✅ Updated Track Business Miles tip to 2026 IRS rate ($0.725/mile)
//  ✅ Fixed UTF-8 encoding (copyright, checkmarks, em-dashes)
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - Money Move Type

/// Types of financial tips/moves
enum MoneyMoveType: String, CaseIterable {
    case debtPayoff = "debt_payoff"
    case savingsGoal = "savings_goal"
    case budgetOptimization = "budget"
    case taxTip = "tax"
    case emergencyFund = "emergency"
    case investmentBasics = "investing"
    case creditScore = "credit"
    case incomeGrowth = "income"
    
    var icon: String {
        switch self {
        case .debtPayoff: return "creditcard.trianglebadge.exclamationmark"
        case .savingsGoal: return "banknote"
        case .budgetOptimization: return "chart.pie"
        case .taxTip: return "doc.text"
        case .emergencyFund: return "shield.checkered"
        case .investmentBasics: return "chart.line.uptrend.xyaxis"
        case .creditScore: return "star.circle"
        case .incomeGrowth: return "arrow.up.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .debtPayoff: return .red
        case .savingsGoal: return .green
        case .budgetOptimization: return .blue
        case .taxTip: return .purple
        case .emergencyFund: return .orange
        case .investmentBasics: return .teal
        case .creditScore: return .yellow
        case .incomeGrowth: return .mint
        }
    }
}

// MARK: - Money Move Model

/// A financial tip or actionable "money move"
struct MoneyMove: Identifiable {
    let id = UUID()
    let type: MoneyMoveType
    let title: String
    let description: String
    let actionLabel: String?
    let potentialSavings: Double?
    let isPersonalized: Bool
    let priority: InsightPriority
    let relatedDebtId: UUID?
    
    init(
        type: MoneyMoveType,
        title: String,
        description: String,
        actionLabel: String? = nil,
        potentialSavings: Double? = nil,
        isPersonalized: Bool = false,
        priority: InsightPriority = .normal,
        relatedDebtId: UUID? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.actionLabel = actionLabel
        self.potentialSavings = potentialSavings
        self.isPersonalized = isPersonalized
        self.priority = priority
        self.relatedDebtId = relatedDebtId
    }
}

// MARK: - InsightsService Extension

extension InsightsService {
    
    // MARK: - Generate Debt Insights
    
    /// Generate debt optimization insights from accounts
    /// Call this from generateInsights() to include debt tips
    func generateDebtInsights(accounts: [Account]) -> [SpendingInsight] {
        var insights: [SpendingInsight] = []
        let debtService = DebtCalculationService.shared
        
        // Find credit card accounts with balances
        let creditCards = accounts.filter {
            $0.accountType == .creditCard && $0.currentBalance < 0
        }
        
        // Find loan accounts
        let _ = accounts.filter {
            $0.accountType == .loan && $0.currentBalance < 0
        }
        
        // Credit Card Insights
        for card in creditCards {
            guard let apr = card.apr, apr > 0 else { continue }
            
            let balance = abs(card.currentBalance)
            let minPercent = card.minimumPaymentPercent ?? 2.0
            let minFloor = card.minimumPaymentFloor ?? 25.0
            
            // Calculate minimum payment payoff
            let scheduleResult = debtService.generateCreditCardSchedule(
                balance: balance,
                apr: apr,
                minimumPercent: minPercent,
                minimumFloor: minFloor,
                extraPayment: 0
            )
            let schedule = scheduleResult.schedule

            guard schedule.count > 0 else { continue }

            let totalInterestAtMinimum = schedule.last?.cumulativeInterest ?? 0
            
            // High interest warning
            if apr >= 20 {
                insights.append(SpendingInsight(
                    type: .warning,
                    priority: .high,
                    title: "High Interest Alert: \(card.name)",
                    message: "At \(formatPercent(apr)) APR, you'll pay \(formatCurrency(totalInterestAtMinimum)) in interest with minimum payments.",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    actionable: true,
                    actionLabel: "View Payoff Options",
                    relatedEntityId: card.id,
                    metadata: [
                        "apr": "\(apr)",
                        "totalInterest": formatCurrency(totalInterestAtMinimum),
                        "months": "\(schedule.count)"
                    ]
                ))
            }
            
            // Extra payment opportunity
            // Calculate savings from doubling minimum payment
            let extraScheduleResult = debtService.generateCreditCardSchedule(
                balance: balance,
                apr: apr,
                minimumPercent: minPercent,
                minimumFloor: minFloor,
                extraPayment: minFloor // Add one minimum as extra
            )
            let extraSchedule = extraScheduleResult.schedule

            if extraSchedule.count > 0 {
                let interestSaved = totalInterestAtMinimum - (extraSchedule.last?.cumulativeInterest ?? 0)
                let monthsSaved = schedule.count - extraSchedule.count
                
                if interestSaved > 100 && monthsSaved > 6 {
                    insights.append(SpendingInsight(
                        type: .tip,
                        priority: .normal,
                        title: "Save \(formatCurrency(interestSaved)) on \(card.name)",
                        message: "Paying \(formatCurrency(minFloor)) extra each month would save you \(formatCurrency(interestSaved)) in interest and pay off \(monthsSaved) months faster.",
                        icon: "lightbulb.fill",
                        color: .blue,
                        actionable: true,
                        actionLabel: "Open Calculator",
                        relatedEntityId: card.id,
                        metadata: [
                            "extraPayment": formatCurrency(minFloor),
                            "interestSaved": formatCurrency(interestSaved),
                            "monthsSaved": "\(monthsSaved)"
                        ]
                    ))
                }
            }
        }
        
        // Credit Utilization Insights
        let totalCreditLimit = creditCards.compactMap { $0.creditLimit }.reduce(0, +)
        let totalCreditBalance = creditCards.reduce(0.0) { $0 + abs($1.currentBalance) }
        
        if totalCreditLimit > 0 {
            let utilization = (totalCreditBalance / totalCreditLimit) * 100
            
            if utilization > 30 {
                insights.append(SpendingInsight(
                    type: .warning,
                    priority: utilization > 50 ? .high : .normal,
                    title: "High Credit Utilization",
                    message: "You're using \(Int(utilization))% of your available credit. Keeping utilization under 30% helps your credit score.",
                    icon: "chart.bar.fill",
                    color: .orange,
                    actionable: false,
                    metadata: [
                        "utilization": "\(Int(utilization))%",
                        "totalBalance": formatCurrency(totalCreditBalance),
                        "totalLimit": formatCurrency(totalCreditLimit)
                    ]
                ))
            }
        }
        
        return insights
    }
    
    // MARK: - Generate Money Moves Tips
    
    /// Generate financial tips - mix of generic and personalized
    /// - Parameter isPremium: Whether user has Premium (unlocks personalized tips)
    /// - Returns: Array of money move tips
    func generateMoneyMovesTips(
        accounts: [Account] = [],
        transactions: [Transaction] = [],
        isPremium: Bool
    ) -> [MoneyMove] {
        var moves: [MoneyMove] = []
        
        // Generic tips available to all users
        moves.append(contentsOf: genericFinancialTips())
        
        // Personalized tips for Premium users
        if isPremium {
            moves.append(contentsOf: personalizedDebtTips(accounts: accounts))
            moves.append(contentsOf: personalizedSpendingTips(transactions: transactions))
        }
        
        // Sort by priority and shuffle within priority groups for variety
        let sortedMoves = moves.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        // Return limited set - more for premium
        let limit = isPremium ? 10 : 3
        return Array(sortedMoves.prefix(limit))
    }
    
    // MARK: - Generic Financial Tips
    
    private func genericFinancialTips() -> [MoneyMove] {
        // Rotate through these tips - in a real app, would track which tips
        // have been shown and prioritize unshown ones
        return [
            MoneyMove(
                type: .debtPayoff,
                title: "The 1/6 Mortgage Trick",
                description: "Divide your monthly P&I payment by 6 and add that as extra principal. This can cut years off your mortgage and save tens of thousands in interest.",
                actionLabel: "Try Calculator",
                isPersonalized: false,
                priority: .normal
            ),
            MoneyMove(
                type: .savingsGoal,
                title: "The 50/30/20 Rule",
                description: "Allocate 50% of income to needs, 30% to wants, and 20% to savings and debt repayment. A simple framework for balanced finances.",
                isPersonalized: false,
                priority: .low
            ),
            MoneyMove(
                type: .emergencyFund,
                title: "Build Your Safety Net",
                description: "Aim for 3-6 months of expenses in an emergency fund. Start small — even $500 can cover many unexpected costs.",
                isPersonalized: false,
                priority: .normal
            ),
            MoneyMove(
                type: .debtPayoff,
                title: "Avalanche vs Snowball",
                description: "Pay highest interest debts first (avalanche) to save the most money, or smallest balances first (snowball) for quick wins. Both work — pick what motivates you.",
                isPersonalized: false,
                priority: .low
            ),
            MoneyMove(
                type: .creditScore,
                title: "The 30% Rule",
                description: "Keep credit utilization under 30% for a healthy credit score. Under 10% is even better.",
                isPersonalized: false,
                priority: .low
            ),
            MoneyMove(
                type: .taxTip,
                title: "Track Business Miles",
                description: "If you drive for work, the 2026 IRS rate is $0.725/mile. A 10-mile round trip to meet a client = $7.25 deduction.",
                isPersonalized: false,
                priority: .low
            ),
            MoneyMove(
                type: .incomeGrowth,
                title: "Automate Your Savings",
                description: "Set up automatic transfers on payday. What you don't see, you don't spend. Even $25/week adds up to $1,300/year.",
                isPersonalized: false,
                priority: .low
            ),
            MoneyMove(
                type: .budgetOptimization,
                title: "Audit Your Subscriptions",
                description: "The average American spends $219/month on subscriptions. Review yours quarterly and cancel what you don't use.",
                isPersonalized: false,
                priority: .low
            )
        ]
    }
    
    // MARK: - Personalized Debt Tips
    
    private func personalizedDebtTips(accounts: [Account]) -> [MoneyMove] {
        var moves: [MoneyMove] = []
        let debtService = DebtCalculationService.shared
        
        // Find accounts with debt
        let creditCards = accounts.filter { $0.accountType == .creditCard && $0.currentBalance < 0 }
        let loans = accounts.filter { $0.accountType == .loan && $0.currentBalance < 0 }
        
        // Mortgage/Loan 1/6 Trick Recommendation
        for loan in loans {
            guard let apr = loan.apr, apr > 0 else { continue }
            
            // Estimate monthly payment if we don't have it
            // For this we'd need more data, so just use a general tip
            let balance = abs(loan.currentBalance)
            
            if balance > 50000 { // Likely a mortgage
                // Quick estimate of potential savings
                let estimatedPayment = debtService.calculateMonthlyPayment(
                    principal: balance,
                    annualRate: apr,
                    termMonths: 360
                )
                
                if let savings = debtService.quickOneSixthSavings(
                    balance: balance,
                    annualRate: apr,
                    monthlyPayment: estimatedPayment
                ) {
                    moves.append(MoneyMove(
                        type: .debtPayoff,
                        title: "Save \(formatCurrency(savings.interestSaved)) on \(loan.name)",
                        description: "Using the 1/6 trick (\(formatCurrency(estimatedPayment / 6)) extra/month), you could save \(formatCurrency(savings.interestSaved)) in interest and pay off \(savings.monthsSaved / 12) years early.",
                        actionLabel: "Open Calculator",
                        potentialSavings: savings.interestSaved,
                        isPersonalized: true,
                        priority: .high,
                        relatedDebtId: loan.id
                    ))
                }
            }
        }
        
        // Credit Card Priority Recommendations
        if creditCards.count > 1 {
            // Find highest interest card
            if let highestAPR = creditCards.max(by: { ($0.apr ?? 0) < ($1.apr ?? 0) }),
               let apr = highestAPR.apr {
                moves.append(MoneyMove(
                    type: .debtPayoff,
                    title: "Focus on \(highestAPR.name) First",
                    description: "At \(formatPercent(apr)) APR, this card costs you the most in interest. Pay minimums on others and throw extra at this one.",
                    actionLabel: "View Details",
                    isPersonalized: true,
                    priority: .high,
                    relatedDebtId: highestAPR.id
                ))
            }
            
            // Find smallest balance card for snowball
            if let smallestBalance = creditCards.min(by: { abs($0.currentBalance) < abs($1.currentBalance) }) {
                let balance = abs(smallestBalance.currentBalance)
                if balance < 1000 {
                    moves.append(MoneyMove(
                        type: .debtPayoff,
                        title: "Quick Win: Pay Off \(smallestBalance.name)",
                        description: "With only \(formatCurrency(balance)) left, you could eliminate this card and free up its minimum payment for other debts.",
                        isPersonalized: true,
                        priority: .normal,
                        relatedDebtId: smallestBalance.id
                    ))
                }
            }
        }
        
        return moves
    }
    
    // MARK: - Personalized Spending Tips
    
    private func personalizedSpendingTips(transactions: [Transaction]) -> [MoneyMove] {
        var moves: [MoneyMove] = []
        let calendar = Calendar.current
        
        // Get this month's transactions
        let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let thisMonthTxs = transactions.filter { $0.date >= thisMonth && !$0.isIncome && !$0.isTransfer }
        
        // Group by category and find high spending
        let byCategory = Dictionary(grouping: thisMonthTxs) { $0.category?.name ?? "Uncategorized" }
        
        for (category, txs) in byCategory {
            let total = txs.reduce(0) { $0 + $1.amount }
            
            // Dining out check
            if category.lowercased().contains("dining") || category.lowercased().contains("restaurant") {
                if total > 300 {
                    moves.append(MoneyMove(
                        type: .budgetOptimization,
                        title: "Dining Out: \(formatCurrency(total)) This Month",
                        description: "Consider meal prepping 2 days a week. At $15/meal savings, that's $120/month back in your pocket.",
                        potentialSavings: 120,
                        isPersonalized: true,
                        priority: .normal
                    ))
                }
            }
            
            // Subscription check
            if category.lowercased().contains("subscription") {
                if total > 100 {
                    moves.append(MoneyMove(
                        type: .budgetOptimization,
                        title: "Subscription Check: \(formatCurrency(total))/month",
                        description: "Review your subscriptions — are you using all of them? Cutting just one $15 service saves $180/year.",
                        potentialSavings: 180,
                        isPersonalized: true,
                        priority: .low
                    ))
                }
            }
        }
        
        return moves
    }
    
    // MARK: - Formatting Helpers
    
    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        NumberFormatter.appCurrencyCompact.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - SpendingInsight Extension for Debt Navigation

extension SpendingInsight {
    
    /// Check if this insight should navigate to the debt calculator
    var shouldOpenDebtCalculator: Bool {
        metadata["interestSaved"] != nil || metadata["monthsSaved"] != nil
    }
}
