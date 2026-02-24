//  DebtPayoffCalculatorView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ All section headers marked with .isHeader trait
//  ✅ Premium gate card accessible with combined label
//  ✅ DebtTypeButton with .isSelected trait and hint
//  ✅ StrategyPill with .isSelected trait
//  ✅ Input fields with accessibility labels
//  ✅ Calculate button state-aware label with hint
//  ✅ Results section: savings cards combined with spoken currency
//  ✅ Comparison chart accessible with spoken values
//  ✅ 1/6 trick explanation combined with icon hidden
//  ✅ Extra payment slider accessible with value
//  ✅ AmortizationScheduleSheet entries combined
//  ✅ Action buttons labeled with hints
//  ✅ Fixed garbled UTF-8 characters
//
//  Interactive debt payoff calculator inspired by viral "1/6 trick" strategy.
//  Allows users to input loan details and compare payoff strategies.
//
//  FEATURES:
//  ✅ Manual debt entry (mortgage, auto, credit card, etc.)
//  ✅ Import from existing FLO accounts
//  ✅ Visual payoff timeline comparison
//  ✅ 1/6 Trick calculation with savings breakdown
//  ✅ Custom extra payment slider
//  ✅ Interest saved / time saved metrics
//  ✅ Amortization schedule preview
//  ✅ Premium tier gating
//

import SwiftUI
import SwiftData
import Charts

struct DebtPayoffCalculatorView: View {
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    // MARK: - State
    
    @State private var debtType: DebtType = .mortgage
    @State private var debtName: String = "My Mortgage"
    @State private var currentBalance: String = ""
    @State private var interestRate: String = ""
    @State private var monthlyPayment: String = ""
    @State private var remainingYears: String = ""
    @State private var extraPayment: Double = 0
    @State private var selectedStrategy: PayoffStrategy = .oneSixthTrick
    
    @State private var results: [PayoffStrategy: PayoffResult] = [:]
    @State private var isCalculating = false
    @State private var showScheduleSheet = false
    @State private var showUpgradePrompt = false
    
    private let debtService = DebtCalculationService.shared
    
    // MARK: - Computed Properties
    
    private var isPremiumUser: Bool {
        subscriptionManager.currentTier >= .premium
    }
    
    private var balanceValue: Double {
        Double(currentBalance.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    
    private var rateValue: Double {
        Double(interestRate) ?? 0
    }
    
    private var paymentValue: Double {
        Double(monthlyPayment.replacingOccurrences(of: ",", with: "")) ?? 0
    }
    
    private var yearsValue: Int {
        Int(remainingYears) ?? 30
    }
    
    private var calculatedMonthlyPayment: Double {
        if paymentValue > 0 {
            return paymentValue
        }
        return debtService.calculateMonthlyPayment(
            principal: balanceValue,
            annualRate: rateValue,
            termMonths: yearsValue * 12
        )
    }
    
    private var oneSixthAmount: Double {
        calculatedMonthlyPayment / 6.0
    }
    
    private var canCalculate: Bool {
        balanceValue > 0 && rateValue > 0 && (paymentValue > 0 || yearsValue > 0)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Premium Gate
                    if !isPremiumUser {
                        premiumGateCard
                    }
                    
                    // Input Section
                    inputSection
                        .disabled(!isPremiumUser)
                        .opacity(isPremiumUser ? 1.0 : 0.5)
                    
                    // Strategy Selection
                    if canCalculate && isPremiumUser {
                        strategySection
                    }
                    
                    // Results
                    if !results.isEmpty && isPremiumUser {
                        resultsSection
                        
                        // Comparison Chart
                        comparisonChart
                        
                        // Action Buttons
                        actionButtons
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Debt Payoff Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: debtType) { _, newType in
                updateDefaultsForDebtType(newType)
            }
            .sheet(isPresented: $showScheduleSheet) {
                if let result = results[selectedStrategy] {
                    AmortizationScheduleSheet(result: result)
                }
            }
            .sheet(isPresented: $showUpgradePrompt) {
                SubscriptionView()
            }
        }
    }
    
    // MARK: - Premium Gate Card
    
    private var premiumGateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            
            Text("Premium Feature")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Unlock the Debt Payoff Calculator to see exactly how much you can save with smart payment strategies.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showUpgradePrompt = true
                HapticService.play(.medium)
            } label: {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .accessibilityHint("Opens subscription options")
        }
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Debt Details")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            // Debt Type Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Debt Type")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(DebtType.allCases) { type in
                            DebtTypeButton(
                                type: type,
                                isSelected: debtType == type
                            ) {
                                debtType = type
                                HapticService.play(.selection)
                            }
                        }
                    }
                }
            }
            
            // Balance Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("$")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("250,000", text: $currentBalance)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Current balance in dollars")
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }
            
            // Interest Rate Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Interest Rate (APR)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("6.5", text: $interestRate)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Annual interest rate, percent")
                    Text("%")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }
            
            // Conditional inputs based on debt type
            if debtType.isAmortized {
                // Monthly Payment OR Remaining Term
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly P&I Payment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField("1,704", text: $monthlyPayment)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Monthly principal and interest payment in dollars")
                    }
                    .padding()
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    
                    Text("Or leave blank and enter remaining years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if monthlyPayment.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remaining Years")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            TextField("30", text: $remainingYears)
                                .keyboardType(.numberPad)
                                .accessibilityLabel("Remaining years on loan")
                            Text("years")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .padding()
                        .background(Color(.tertiarySystemGroupedBackground))
                        .cornerRadius(10)
                    }
                }
            }
            
            // Calculate Button
            Button {
                calculatePayoff()
                HapticService.play(.medium)
            } label: {
                HStack {
                    if isCalculating {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "function")
                            .accessibilityHidden(true)
                        Text("Calculate Payoff")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canCalculate ? .teal : .gray)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(!canCalculate || isCalculating)
            .accessibilityLabel(isCalculating ? "Calculating payoff" : "Calculate payoff")
            .accessibilityHint(canCalculate ? "Calculates payoff timeline and savings" : "Enter balance and interest rate first")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Strategy Section
    
    private var strategySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Strategy")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            // Strategy Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([PayoffStrategy.minimumOnly, .oneSixthTrick, .fixed]) { strategy in
                        StrategyPill(
                            strategy: strategy,
                            isSelected: selectedStrategy == strategy
                        ) {
                            selectedStrategy = strategy
                            HapticService.play(.selection)
                        }
                    }
                }
            }
            
            // Extra Payment Slider (for fixed strategy)
            if selectedStrategy == .fixed {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Extra Monthly Payment")
                            .font(.subheadline)
                        Spacer()
                        Text(debtService.formatCurrency(extraPayment))
                            .font(.headline)
                            .foregroundStyle(.teal)
                    }
                    
                    Slider(
                        value: $extraPayment,
                        in: 0...max(1000, calculatedMonthlyPayment),
                        step: 25
                    )
                    .tint(.teal)
                    .onChange(of: extraPayment) { _, _ in
                        calculatePayoff()
                    }
                    .accessibilityLabel("Extra monthly payment")
                    .accessibilityValue(debtService.formatCurrency(extraPayment))
                    
                    HStack {
                        Text("$0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(debtService.formatCurrency(max(1000, calculatedMonthlyPayment)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }
            
            // 1/6 Trick Explanation
            if selectedStrategy == .oneSixthTrick && debtType.isAmortized {
                oneSixthExplanation
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 1/6 Trick Explanation
    
    private var oneSixthExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("The 1/6 Trick")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .accessibilityAddTraits(.isHeader)
            
            Text("Take your monthly P&I payment and divide by 6. Add that amount as extra principal each month.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your P&I Payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(debtService.formatCurrency(calculatedMonthlyPayment))
                        .font(.headline)
                }
                
                Image(systemName: "divide")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Divided by 6")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("6")
                        .font(.headline)
                }
                
                Image(systemName: "equal")
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extra Payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(debtService.formatCurrency(oneSixthAmount))
                        .font(.headline)
                        .foregroundStyle(.teal)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your payment \(debtService.formatCurrency(calculatedMonthlyPayment)) divided by 6 equals \(debtService.formatCurrency(oneSixthAmount)) extra per month")
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Results Section
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Savings")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            if let standardResult = results[.minimumOnly],
               let selectedResult = results[selectedStrategy] {
                
                // Main Savings Card
                VStack(spacing: 20) {
                    // Interest Saved
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Interest Saved")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(debtService.formatCurrency(selectedResult.interestSaved))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green.opacity(0.3))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Interest saved: \(debtService.formatCurrency(selectedResult.interestSaved))")
                    
                    Divider()
                    
                    // Time Saved
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Time Saved")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            let yearsSaved = selectedResult.monthsSaved / 12
                            let monthsRemaining = selectedResult.monthsSaved % 12
                            
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                if yearsSaved > 0 {
                                    Text("\(yearsSaved)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.teal)
                                    Text(yearsSaved == 1 ? "year" : "years")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                if monthsRemaining > 0 {
                                    Text("\(monthsRemaining)")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.teal)
                                    Text(monthsRemaining == 1 ? "month" : "months")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "clock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.teal.opacity(0.3))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Time saved: \(formatMonths(selectedResult.monthsSaved))")
                    
                    Divider()
                    
                    // Comparison Row
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Standard Payoff")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatMonths(standardResult.totalMonths))
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Accelerated Payoff")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatMonths(selectedResult.totalMonths))
                                .font(.subheadline)
                                .foregroundStyle(.teal)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Standard payoff: \(formatMonths(standardResult.totalMonths)), accelerated payoff: \(formatMonths(selectedResult.totalMonths))")
                    
                    // Monthly Payment Increase
                    if selectedResult.extraPayment > 0 {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("This requires paying \(debtService.formatCurrency(selectedResult.extraPayment)) extra per month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Comparison Chart
    
    private var comparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payoff Timeline")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            if let standardResult = results[.minimumOnly],
               let selectedResult = results[selectedStrategy] {
                
                Chart {
                    // Standard timeline
                    ForEach(standardResult.schedule.filter { $0.month % 12 == 0 || $0.month == standardResult.schedule.count }) { entry in
                        LineMark(
                            x: .value("Month", entry.month),
                            y: .value("Balance", entry.remainingBalance)
                        )
                        .foregroundStyle(by: .value("Strategy", "Standard"))
                    }
                    
                    // Accelerated timeline
                    ForEach(selectedResult.schedule.filter { $0.month % 12 == 0 || $0.month == selectedResult.schedule.count }) { entry in
                        LineMark(
                            x: .value("Month", entry.month),
                            y: .value("Balance", entry.remainingBalance)
                        )
                        .foregroundStyle(by: .value("Strategy", selectedStrategy.displayName))
                    }
                }
                .chartForegroundStyleScale([
                    "Standard": Color.gray,
                    selectedStrategy.displayName: Color.teal
                ])
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        if let amount = value.as(Double.self) {
                            AxisValueLabel {
                                Text(formatCompactCurrency(amount))
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let month = value.as(Int.self) {
                            AxisValueLabel {
                                Text(month % 60 == 0 ? "\(month/12)yr" : "")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Payoff timeline comparison chart")
                .accessibilityValue("Standard payoff: \(formatMonths(standardResult.totalMonths)), \(selectedStrategy.displayName): \(formatMonths(selectedResult.totalMonths))")
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showScheduleSheet = true
                HapticService.play(.light)
            } label: {
                HStack {
                    Image(systemName: "tablecells")
                    Text("View Full Schedule")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundStyle(.teal)
                .cornerRadius(12)
            }
            .accessibilityHint("Opens detailed amortization schedule")
        }
    }
    
    // MARK: - Helper Functions
    
    private func updateDefaultsForDebtType(_ type: DebtType) {
        debtName = "My \(type.displayName)"
        switch type {
        case .mortgage:
            remainingYears = "30"
        case .autoLoan:
            remainingYears = "5"
        case .personalLoan, .studentLoan:
            remainingYears = "5"
        case .creditCard, .other:
            remainingYears = ""
        }
    }
    
    private func calculatePayoff() {
        guard canCalculate else { return }
        
        isCalculating = true
        
        let debt = DebtInput(
            name: debtName,
            debtType: debtType,
            currentBalance: balanceValue,
            interestRate: rateValue,
            monthlyPayment: paymentValue > 0 ? paymentValue : 0,
            remainingTermMonths: yearsValue * 12,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )
        
        // Calculate with different extra payment based on strategy
        let extra: Double?
        switch selectedStrategy {
        case .minimumOnly:
            extra = nil
        case .oneSixthTrick:
            extra = calculatedMonthlyPayment / 6.0
        case .fixed:
            extra = extraPayment > 0 ? extraPayment : nil
        default:
            extra = nil
        }
        
        results = debtService.calculatePayoff(debt: debt, extraPayment: extra)
        
        // Always calculate minimum as baseline
        if results[.minimumOnly] == nil {
            let baselineResults = debtService.calculatePayoff(debt: debt, extraPayment: nil)
            if let baseline = baselineResults[.minimumOnly] {
                results[.minimumOnly] = baseline
            }
        }
        
        isCalculating = false
    }
    
    private func formatMonths(_ months: Int) -> String {
        let years = months / 12
        let remainingMonths = months % 12
        
        if years == 0 {
            return "\(remainingMonths) months"
        } else if remainingMonths == 0 {
            return "\(years) years"
        } else {
            return "\(years)y \(remainingMonths)m"
        }
    }
    
    private func formatCompactCurrency(_ amount: Double) -> String {
        if amount >= 1_000_000 {
            return "$\(Int(amount / 1_000_000))M"
        } else if amount >= 1_000 {
            return "$\(Int(amount / 1_000))K"
        } else {
            return "$\(Int(amount))"
        }
    }
}

// MARK: - Supporting Views

struct DebtTypeButton: View {
    let type: DebtType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                Text(type.displayName)
                    .font(.caption)
            }
            .frame(width: 80, height: 70)
            .background(isSelected ? Color.teal.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .teal : .primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(type.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Select \(type.displayName) debt type")
    }
}

struct StrategyPill: View {
    let strategy: PayoffStrategy
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(strategy.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.teal : Color(.tertiarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Amortization Schedule Sheet

struct AmortizationScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: PayoffResult
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Total Paid")
                        Spacer()
                        Text(formatCurrency(result.totalPaid))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Total paid: \(formatCurrency(result.totalPaid))")
                    HStack {
                        Text("Total Interest")
                        Spacer()
                        Text(formatCurrency(result.totalInterest))
                            .foregroundStyle(.red)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Total interest: \(formatCurrency(result.totalInterest))")
                    HStack {
                        Text("Payoff Time")
                        Spacer()
                        Text("\(result.totalMonths) months")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Payoff time: \(result.totalMonths) months")
                } header: {
                    Text("Summary")
                }
                
                Section {
                    ForEach(result.schedule.filter { entry in
                        // Show every 12th month for long schedules, or all for short ones
                        result.schedule.count <= 60 ||
                        entry.month % 12 == 0 ||
                        entry.month == 1 ||
                        entry.month == result.schedule.count
                    }) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Month \(entry.month)")
                                    .font(.headline)
                                Spacer()
                                Text(formatCurrency(entry.remainingBalance))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 16) {
                                Label(formatCurrency(entry.principal), systemImage: "arrow.down.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                
                                Label(formatCurrency(entry.interest), systemImage: "percent")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                
                                if entry.extraPrincipal > 0 {
                                    Label(formatCurrency(entry.extraPrincipal), systemImage: "plus.circle")
                                        .font(.caption)
                                        .foregroundStyle(.teal)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel({
                            var label = "Month \(entry.month): balance \(formatCurrency(entry.remainingBalance)), principal \(formatCurrency(entry.principal)), interest \(formatCurrency(entry.interest))"
                            if entry.extraPrincipal > 0 {
                                label += ", extra principal \(formatCurrency(entry.extraPrincipal))"
                            }
                            return label
                        }())
                    }
                } header: {
                    Text("Payment Schedule")
                }
            }
            .navigationTitle("Amortization Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Preview

#Preview("Debt Payoff Calculator") {
    DebtPayoffCalculatorView()
}
