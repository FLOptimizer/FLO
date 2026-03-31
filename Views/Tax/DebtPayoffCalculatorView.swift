//  DebtPayoffCalculatorView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - Penny-Up Currency Input:
//  ✅ REPLACED: currentBalance and monthlyPayment TextFields with CurrencyInputField
//  ✅ CHANGED: currentBalance and monthlyPayment state from String to Double
//  ✅ SIMPLIFIED: balanceValue and paymentValue computed properties
//  ✅ SKIPPED: interestRate (percentage) and remainingYears (integer) — not currency
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
    @State private var currentBalance: Double = 0
    @State private var interestRate: String = ""
    @State private var monthlyPayment: Double = 0
    @State private var remainingYears: String = ""
    @State private var extraPayment: Double = 0
    @State private var selectedStrategy: PayoffStrategy = .oneSixthTrick
    
    @State private var results: [PayoffStrategy: PayoffResult] = [:]
    @State private var isCalculating = false
    @State private var showScheduleSheet = false
    @State private var showUpgradePrompt = false

    @FocusState private var isAnyFieldFocused: Bool

    private let debtService = DebtCalculationService.shared
    
    // MARK: - Computed Properties
    
    private var isPremiumUser: Bool {
        subscriptionManager.currentTier >= .premium
    }
    
    private var balanceValue: Double {
        currentBalance
    }

    private var rateValue: Double {
        Double(interestRate) ?? 0
    }

    private var paymentValue: Double {
        monthlyPayment
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

    /// Effective monthly payment for the current debt type.
    /// For amortized loans: the P&I payment. For credit cards: the average minimum from results, or estimated minimum.
    private var effectiveMonthlyPayment: Double {
        if debtType.isAmortized {
            return calculatedMonthlyPayment
        }
        // For credit cards, use the avg min payment from results if available
        if let minResult = results[.minimumOnly], minResult.monthlyPayment > 0 {
            return minResult.monthlyPayment
        }
        // Fallback: estimate minimum payment
        return max(balanceValue * 0.02, 25.0)
    }

    private var oneSixthAmount: Double {
        effectiveMonthlyPayment / 6.0
    }

    private var canCalculate: Bool {
        balanceValue > 0 && rateValue > 0 && (paymentValue > 0 || yearsValue > 0 || !debtType.isAmortized)
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

                        // Chart & Actions (only if we have valid schedule data)
                        if let selected = results[selectedStrategy] ?? results[.minimumOnly],
                           !selected.schedule.isEmpty {
                            comparisonChart
                            actionButtons
                        }
                    }
                }
                .padding()
            }
            .background(Color.floSystemGroupedBackground)
            .navigationTitle("Debt Payoff Calculator")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isAnyFieldFocused = false
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        #endif
                    }
                }
            }
            .onChange(of: debtType) { _, newType in
                updateDefaultsForDebtType(newType)
            }
            .onChange(of: selectedStrategy) { _, _ in
                if !results.isEmpty {
                    calculatePayoff()
                }
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
        .background(Color.floSecondarySystemGroupedBackground)
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

                CurrencyInputField(
                    amount: $currentBalance,
                    placeholder: "$0.00",
                    accessibilityLabelText: "Current balance",
                    showDoneButton: false
                )
                .focused($isAnyFieldFocused)
                .padding()
                .background(Color.floTertiarySystemBackground)
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
                        .focused($isAnyFieldFocused)
                        .accessibilityLabel("Annual interest rate, percent")
                    Text("%")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(Color.floTertiarySystemBackground)
                .cornerRadius(10)
            }
            
            // Conditional inputs based on debt type
            if debtType.isAmortized {
                // Monthly Payment OR Remaining Term
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly P&I Payment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    CurrencyInputField(
                        amount: $monthlyPayment,
                        placeholder: "$0.00",
                        accessibilityLabelText: "Monthly payment",
                        showDoneButton: false
                    )
                    .focused($isAnyFieldFocused)
                    .padding()
                    .background(Color.floTertiarySystemBackground)
                    .cornerRadius(10)
                    
                    Text("Or leave blank and enter remaining years")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if monthlyPayment == 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Remaining Years")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack {
                            TextField("30", text: $remainingYears)
                                .keyboardType(.numberPad)
                                .focused($isAnyFieldFocused)
                                .accessibilityLabel("Remaining years on loan")
                            Text("years")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                        .padding()
                        .background(Color.floTertiarySystemBackground)
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
        .background(Color.floSecondarySystemGroupedBackground)
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
                .background(Color.floTertiarySystemBackground)
                .cornerRadius(10)
            }
            
            // 1/6 Trick Explanation
            if selectedStrategy == .oneSixthTrick {
                oneSixthExplanation
            }
        }
        .padding()
        .background(Color.floSecondarySystemGroupedBackground)
        .cornerRadius(16)
    }
    
    // MARK: - 1/6 Trick Explanation
    
    private var oneSixthExplanation: some View {
        let basePayment = effectiveMonthlyPayment
        let extraAmount = basePayment / 6.0
        let paymentLabel = debtType.isAmortized ? "Your P&I Payment" : "Avg Min Payment"
        let explanationText = debtType.isAmortized
            ? "Take your monthly P&I payment and divide by 6. Add that amount as extra principal each month."
            : "Take your average minimum payment and divide by 6. Add that amount as extra payment each month."

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text("The 1/6 Trick")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .accessibilityAddTraits(.isHeader)

            Text(explanationText)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(paymentLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(debtService.formatCurrency(basePayment))
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
                    Text(debtService.formatCurrency(extraAmount))
                        .font(.headline)
                        .foregroundStyle(.teal)
                }
            }
            .padding()
            .background(Color.floSystemBackground)
            .cornerRadius(10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(paymentLabel) \(debtService.formatCurrency(basePayment)) divided by 6 equals \(debtService.formatCurrency(extraAmount)) extra per month")
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Interest trap warning
            if let standardResult = results[.minimumOnly], standardResult.interestTrap {
                interestTrapWarning
            }

            Text("Your Savings")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            if let standardResult = results[.minimumOnly],
               !standardResult.interestTrap,
               let selectedResult = results[selectedStrategy] ?? results[.minimumOnly] {

                // Main Results Card
                VStack(spacing: 20) {
                    if selectedStrategy == .minimumOnly {
                        // Show baseline payoff summary (no savings comparison)
                        baselinePayoffSummary(result: standardResult)
                    } else {
                        // Show savings comparison vs minimum payments
                        savingsComparison(standard: standardResult, selected: selectedResult)
                    }
                }
                .padding()
                .background(Color.floSecondarySystemGroupedBackground)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Interest Trap Warning

    private var interestTrapWarning: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
                Text("Interest Trap Detected")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            Text("Your minimum payments don't cover the monthly interest. This debt will never be paid off with minimum payments alone. Increase your monthly payment above the interest charge to start reducing the balance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            let monthlyInterest = balanceValue * (rateValue / 100.0 / 12.0)
            if monthlyInterest > 0 {
                Text("Monthly interest: \(debtService.formatCurrencyPrecise(monthlyInterest))")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Baseline Payoff Summary (Minimum Only)

    @ViewBuilder
    private func baselinePayoffSummary(result: PayoffResult) -> some View {
        // Total Interest
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Interest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(debtService.formatCurrency(result.totalInterest))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            Image(systemName: "percent")
                .font(.largeTitle)
                .foregroundStyle(.red.opacity(0.3))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total interest: \(debtService.formatCurrency(result.totalInterest))")

        Divider()

        // Payoff Timeline
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Payoff Timeline")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatMonths(result.totalMonths))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.teal)
            }
            Spacer()
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(.teal.opacity(0.3))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payoff timeline: \(formatMonths(result.totalMonths))")

        Divider()

        // Total Cost
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Cost")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(debtService.formatCurrency(result.totalPaid))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Total cost: \(debtService.formatCurrency(result.totalPaid))")

        // Nudge to try accelerated strategy
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            Text("Try the 1/6 Trick or Fixed Extra strategy to see how much you could save!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Savings Comparison (Accelerated vs Minimum)

    @ViewBuilder
    private func savingsComparison(standard: PayoffResult, selected: PayoffResult) -> some View {
        // Interest Saved
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Interest Saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(debtService.formatCurrency(selected.interestSaved))
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
        .accessibilityLabel("Interest saved: \(debtService.formatCurrency(selected.interestSaved))")

        Divider()

        // Time Saved
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                timeSavedDisplay(months: selected.monthsSaved)
            }
            Spacer()
            Image(systemName: "clock.fill")
                .font(.largeTitle)
                .foregroundStyle(.teal.opacity(0.3))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time saved: \(formatMonths(selected.monthsSaved))")

        Divider()

        // Comparison Row
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard Payoff")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(formatMonths(standard.totalMonths))
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
                Text(formatMonths(selected.totalMonths))
                    .font(.subheadline)
                    .foregroundStyle(.teal)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Standard payoff: \(formatMonths(standard.totalMonths)), accelerated payoff: \(formatMonths(selected.totalMonths))")

        // Monthly Payment Increase
        if selected.extraPayment > 0 {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("This requires paying \(debtService.formatCurrency(selected.extraPayment)) extra per month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private func timeSavedDisplay(months: Int) -> some View {
        let yearsSaved = months / 12
        let monthsRemaining = months % 12

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
            if yearsSaved == 0 && monthsRemaining == 0 {
                Text("—")
                    .font(.title)
                    .foregroundStyle(.secondary)
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
               !standardResult.interestTrap,
               !standardResult.schedule.isEmpty,
               let selectedResult = results[selectedStrategy] ?? results[.minimumOnly],
               !selectedResult.schedule.isEmpty {
                
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
                            let maxMonths = standardResult.totalMonths
                            // Adaptive label interval: show ~4-6 labels regardless of timeline
                            let interval = max(6, (maxMonths / 5 / 12) * 12) // Round to nearest year
                            AxisValueLabel {
                                if month == 0 || month % max(interval, 12) == 0 {
                                    Text(month >= 12 ? "\(month/12)yr" : "\(month)mo")
                                        .font(.caption2)
                                } else {
                                    Text("")
                                }
                            }
                        }
                        AxisGridLine()
                    }
                }
                .frame(height: 200)
                .padding()
                .background(Color.floSecondarySystemGroupedBackground)
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
                .background(Color.floSecondarySystemGroupedBackground)
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

        let termMonths: Int? = debtType.isAmortized ? yearsValue * 12 : nil
        let debt = DebtInput(
            name: debtName,
            debtType: debtType,
            currentBalance: balanceValue,
            interestRate: rateValue,
            monthlyPayment: paymentValue > 0 ? paymentValue : 0,
            remainingTermMonths: termMonths,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0
        )

        // Extra payment for the fixed strategy (service handles 1/6 internally)
        let extra: Double? = (selectedStrategy == .fixed && extraPayment > 0) ? extraPayment : nil

        results = debtService.calculatePayoff(debt: debt, extraPayment: extra)

        // Always ensure minimum baseline exists
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
            return String(format: "$%.1fM", amount / 1_000_000)
        } else if amount >= 100_000 {
            return "$\(Int(amount / 1_000))K"
        } else if amount >= 1_000 {
            return String(format: "$%.1fK", amount / 1_000)
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
            .background(isSelected ? Color.teal.opacity(0.15) : Color.floTertiarySystemBackground)
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
                .background(isSelected ? Color.teal : Color.floTertiarySystemBackground)
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
        NumberFormatter.appCurrencyCompact.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Preview

#Preview("Debt Payoff Calculator") {
    DebtPayoffCalculatorView()
}
