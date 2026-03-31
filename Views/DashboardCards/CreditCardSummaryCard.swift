//  CreditCardSummaryCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3 - Dynamic Type verification: fixed font sizes, lineLimit + minimumScaleFactor
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: paidOffContent checkmark used .system(size: 40) → now .largeTitle (scales with DT)
//  ✅ FIXED: noCardsForModeContent icon used .system(size: 32) → now .largeTitle (scales with DT)
//  ✅ FIXED: CreditCardMiniRow balance text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: CreditCardMiniRow card name missing minimumScaleFactor
//  ✅ FIXED: CreditCardMiniRow utilization percentage missing lineLimit + minimumScaleFactor
//  ✅ FIXED: paymentAlertRow amounts missing lineLimit + minimumScaleFactor
//  ✅ FIXED: paidOffContent available credit text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: headerSubtitle missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.1:
//  - Fixed @Query predicate issue (enum comparison crashes SwiftData)
//  - Now fetches all accounts and filters in-memory (matches AccountsSummaryCard pattern)
//  - Added accessibility labels to utilization gauge and stat items
//  - Added empty state for filtered mode with no credit cards
//  - Simplified utilizationStatus logic
//  - Extracted CurrencyFormatter for consistency
//  - Added accessibility hints with utilization recommendations
//
//  FEATURES:
//  - Total credit card balance overview
//  - Credit utilization gauge with accessibility
//  - Upcoming payment alerts
//  - Monthly interest estimates
//  - Individual card quick view
//  - Payoff insights
//  - Finance mode filtering (business/personal/all)
//

import SwiftUI
import FLODesignSystem
import SwiftData

// MARK: - Currency Formatter Helper

/// Shared currency formatting to avoid duplication
private struct CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
    
    static func format(_ value: Double) -> String {
        shared.string(from: NSNumber(value: value)) ?? "$0.00"
    }
}

// MARK: - Credit Card Summary Card

struct CreditCardSummaryCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // FIXED: Fetch all accounts and filter in-memory
    // SwiftData predicates with enum comparisons can crash at runtime
    @Query(sort: \Account.name) private var allAccounts: [Account]
    
    let financeMode: FinanceMode
    
    @State private var cardVisible = false
    @State private var contentAnimated = false
    @State private var showingAllCards = false
    
    // MARK: - Computed Properties
    
    /// All active credit cards
    private var creditCards: [Account] {
        allAccounts.filter { $0.accountType == .creditCard && $0.isActive }
    }
    
    /// Credit cards filtered by finance mode
    private var filteredCards: [Account] {
        switch financeMode {
        case .business:
            return creditCards.filter { $0.financeType == .business }
        case .personal:
            return creditCards.filter { $0.financeType == .personal }
        case .all:
            return creditCards
        }
    }
    
    /// Cards that have an outstanding balance
    private var cardsWithBalance: [Account] {
        filteredCards.filter { $0.currentBalance < 0 }
    }
    
    /// Total balance across all filtered cards (negative value)
    private var totalBalance: Double {
        cardsWithBalance.reduce(0) { $0 + $1.currentBalance }
    }
    
    /// Total credit limit across all filtered cards
    private var totalCreditLimit: Double {
        filteredCards.compactMap { $0.creditLimit }.reduce(0, +)
    }
    
    /// Total available credit across all filtered cards
    private var totalAvailableCredit: Double {
        filteredCards.compactMap { $0.availableCredit }.reduce(0, +)
    }
    
    /// Overall credit utilization percentage
    private var overallUtilization: Double {
        guard totalCreditLimit > 0 else { return 0 }
        return (abs(totalBalance) / totalCreditLimit) * 100
    }
    
    /// Credit utilization status based on percentage
    private var utilizationStatus: CreditUtilizationStatus {
        // Guard against no credit limit first
        guard totalCreditLimit > 0 else { return .unknown }
        
        // Simplified switch-based logic
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
    
    /// Total estimated monthly interest across all cards
    private var totalMonthlyInterest: Double {
        cardsWithBalance.compactMap { $0.estimatedMonthlyInterest }.reduce(0, +)
    }
    
    /// Total minimum payment due across all cards
    private var totalMinimumDue: Double {
        cardsWithBalance.compactMap { $0.minimumPaymentDue }.reduce(0, +)
    }
    
    /// Cards with payment due within 7 days
    private var cardsPaymentDueSoon: [Account] {
        filteredCards.filter { $0.isPaymentDueSoon && $0.currentBalance < 0 }
    }
    
    /// Cards with overdue payments
    private var cardsOverdue: [Account] {
        filteredCards.filter { $0.isPaymentOverdue && $0.currentBalance < 0 }
    }
    
    /// Whether there are any credit cards in the system
    private var hasAnyCreditCards: Bool {
        !creditCards.isEmpty
    }
    
    /// Whether there are credit cards for the current filter
    private var hasFilteredCards: Bool {
        !filteredCards.isEmpty
    }
    
    /// Whether any filtered cards have a balance
    private var hasBalance: Bool {
        !cardsWithBalance.isEmpty
    }
    
    /// Label for current finance mode
    private var financeModeLabel: String {
        switch financeMode {
        case .business: return "business"
        case .personal: return "personal"
        case .all: return ""
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        // Only show for Premium+ users with balance tracking who have credit cards
        if subscriptionManager.currentTier.hasBalanceTracking && hasAnyCreditCards {
            VStack(spacing: 0) {
                headerView
                
                Divider()
                
                // Content based on state
                if !hasFilteredCards {
                    // No cards for this finance mode
                    noCardsForModeContent
                } else if hasBalance {
                    // Has cards with balance
                    balanceContent
                } else {
                    // All cards paid off
                    paidOffContent
                }
            }
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .floCardShadow()
            .onAppear {
                animateEntrance()
            }
            .onChange(of: financeMode) { _, _ in
                withAnimation(FLOAnimation.quick) {
                    contentAnimated = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(FLOAnimation.standard) {
                        contentAnimated = true
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            FLOBrandedIcon(icon: .accounts, size: .medium, color: Color(hex: AccountType.creditCard.color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Credit Cards")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer()
            
            // Payment alert badge
            if !cardsOverdue.isEmpty {
                alertBadge(count: cardsOverdue.count, isOverdue: true)
            } else if !cardsPaymentDueSoon.isEmpty {
                alertBadge(count: cardsPaymentDueSoon.count, isOverdue: false)
            }
            
            Button {
                HapticService.play(.light)
                NavigationService.shared.selectedTab = .accounts
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View all accounts")
        }
        .padding()
        .opacity(cardVisible ? 1 : 0.001)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headerAccessibilityLabel)
    }
    
    private var headerSubtitle: String {
        if !hasFilteredCards {
            return "No \(financeModeLabel) cards".trimmingCharacters(in: .whitespaces)
        }
        return "\(filteredCards.count) card\(filteredCards.count == 1 ? "" : "s")"
    }
    
    private var headerAccessibilityLabel: String {
        var label = "Credit Cards, \(filteredCards.count) card\(filteredCards.count == 1 ? "" : "s")"
        if !cardsOverdue.isEmpty {
            label += ", \(cardsOverdue.count) overdue"
        } else if !cardsPaymentDueSoon.isEmpty {
            label += ", \(cardsPaymentDueSoon.count) due soon"
        }
        return label
    }
    
    private func alertBadge(count: Int, isOverdue: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock.fill")
                .font(.caption2)
                .accessibilityHidden(true)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isOverdue ? Color.red : Color.orange)
        .cornerRadius(12)
        .accessibilityLabel("\(count) \(isOverdue ? "overdue" : "due soon")")
    }
    
    // MARK: - No Cards For Mode Content
    
    private var noCardsForModeContent: some View {
        VStack(spacing: 12) {
            // v1.3: Replaced .system(size: 32) with .largeTitle for Dynamic Type scaling
            Image(systemName: "creditcard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("No \(financeModeLabel) credit cards".trimmingCharacters(in: .whitespaces).capitalized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                // v1.3: Dynamic Type protection
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            if creditCards.count > 0 {
                Text("You have \(creditCards.count) card\(creditCards.count == 1 ? "" : "s") in other categories")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    // v1.3: Dynamic Type protection
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(contentAnimated ? 1 : 0.001)
    }
    
    // MARK: - Balance Content
    
    private var balanceContent: some View {
        VStack(spacing: 16) {
            // Main Balance Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(CurrencyFormatter.format(abs(totalBalance)))
                        .font(.title2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.expenseRed)
                        .accessibleCurrency(abs(totalBalance), label: "Total credit card balance")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total credit card balance: \(CurrencyFormatter.format(abs(totalBalance)))")
                
                Spacer()
                
                // Utilization Gauge
                utilizationGauge
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            // Stats Row
            HStack(spacing: 0) {
                // Monthly Interest
                statItem(
                    title: "Est. Monthly Interest",
                    value: totalMonthlyInterest,
                    icon: "percent",
                    color: .orange
                )
                
                Divider()
                    .frame(height: 40)
                
                // Minimum Due
                statItem(
                    title: "Min. Payment Due",
                    value: totalMinimumDue,
                    icon: "calendar",
                    color: Color.brandPrimary
                )
                
                Divider()
                    .frame(height: 40)
                
                // Available Credit
                statItem(
                    title: "Available Credit",
                    value: totalAvailableCredit,
                    icon: "creditcard",
                    color: .green
                )
            }
            
            // Cards with payments due soon
            if !cardsPaymentDueSoon.isEmpty || !cardsOverdue.isEmpty {
                Divider()
                    .padding(.horizontal)
                
                paymentAlertSection
            }
            
            // Individual cards (expandable)
            if filteredCards.count > 1 {
                Divider()
                    .padding(.horizontal)
                
                individualCardsSection
            }
        }
        .padding(.vertical, 12)
        .opacity(contentAnimated ? 1 : 0.001)
        .offset(y: contentAnimated ? 0 : 10)
    }
    
    // MARK: - Utilization Gauge
    
    private var utilizationGauge: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    .frame(width: 50, height: 50)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: min(overallUtilization / 100, 1.0))
                    .stroke(
                        Color(hex: utilizationStatus.color),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: overallUtilization)
                
                // Percentage text
                Text("\(Int(overallUtilization))%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(hex: utilizationStatus.color))
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            
            Text("Utilization")
                .font(.caption2)
                .foregroundStyle(.secondary)
                // v1.3: Dynamic Type protection
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Credit utilization: \(Int(overallUtilization)) percent, \(utilizationStatus.displayName)")
        .accessibilityHint(utilizationStatus.recommendation)
    }
    
    // MARK: - Stat Item
    
    private func statItem(title: String, value: Double, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            
            Text(CurrencyFormatter.format(value))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibleCurrency(value, label: title)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(AccessibilityFormatters.spokenCurrency(value))")
    }
    
    // MARK: - Payment Alert Section
    
    private var paymentAlertSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: cardsOverdue.isEmpty ? "clock.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(cardsOverdue.isEmpty ? .orange : .red)
                    .accessibilityHidden(true)
                
                Text(paymentAlertTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal)
            
            ForEach(cardsOverdue + cardsPaymentDueSoon, id: \.id) { card in
                paymentAlertRow(for: card)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Dynamic title based on payment status
    private var paymentAlertTitle: String {
        if !cardsOverdue.isEmpty && !cardsPaymentDueSoon.isEmpty {
            return "Payments (\(cardsOverdue.count) overdue)"
        } else if !cardsOverdue.isEmpty {
            return "Overdue Payments"
        } else {
            return "Payments Due Soon"
        }
    }
    
    private func paymentAlertRow(for card: Account) -> some View {
        HStack {
            Text(card.name)
                .font(.caption)
                .lineLimit(1)
                // v1.3: Dynamic Type protection
                .minimumScaleFactor(0.7)
            
            Spacer()
            
            if let dueDate = card.nextPaymentDueDate {
                Text(dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(card.isPaymentOverdue ? .red : .orange)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            if let minPayment = card.minimumPaymentDue {
                Text(CurrencyFormatter.format(minPayment))
                    .font(.caption)
                    .fontWeight(.medium)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibleCurrency(minPayment, label: "Minimum payment")
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(paymentAlertAccessibilityLabel(for: card))
    }
    
    private func paymentAlertAccessibilityLabel(for card: Account) -> String {
        var label = card.name
        if card.isPaymentOverdue {
            label += ", payment overdue"
        } else if let days = card.daysUntilPaymentDue {
            label += ", due in \(days) days"
        }
        if let minPayment = card.minimumPaymentDue {
            label += ", minimum payment \(CurrencyFormatter.format(minPayment))"
        }
        return label
    }
    
    // MARK: - Individual Cards Section
    
    private var individualCardsSection: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingAllCards.toggle()
                }
                HapticService.play(.light)
            } label: {
                HStack {
                    Text(showingAllCards ? "Hide Cards" : "Show All Cards")
                        .font(.caption)
                         .foregroundStyle(Color.brandPrimaryText)
                    
                    Image(systemName: showingAllCards ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint(showingAllCards ? "Hides individual card details" : "Shows individual card details")
            
            if showingAllCards {
                ForEach(filteredCards.sorted { abs($0.currentBalance) > abs($1.currentBalance) }) { card in
                    CreditCardMiniRow(account: card)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Paid Off Content
    
    private var paidOffContent: some View {
        VStack(spacing: 12) {
            // v1.3: Replaced .system(size: 40) with .largeTitle for Dynamic Type scaling
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: contentAnimated)
                .accessibilityHidden(true)
            
            Text("All Paid Off!")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.green)
                .accessibilityAddTraits(.isHeader)
            
            Text("No credit card balance")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if totalCreditLimit > 0 {
                Text("\(CurrencyFormatter.format(totalAvailableCredit)) available credit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibleCurrency(totalAvailableCredit, label: "Available credit")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .opacity(contentAnimated ? 1 : 0.001)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All credit cards paid off. \(CurrencyFormatter.format(totalAvailableCredit)) available credit")
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(FLOAnimation.standard) {
            cardVisible = true
        }
        
        withAnimation(FLOAnimation.gentle.delay(0.2)) {
            contentAnimated = true
        }
    }
}

// MARK: - Credit Card Mini Row

struct CreditCardMiniRow: View {
    let account: Account
    
    var body: some View {
        HStack(spacing: 8) {
            // Card icon with utilization color
            ZStack {
                Circle()
                    .fill(Color(hex: account.utilizationStatus.color).opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: account.utilizationStatus.color))
            }
            
            // Card name and last 4
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    // v1.3: Dynamic Type protection
                    .minimumScaleFactor(0.7)
                
                if let digits = account.lastFourDigits {
                    Text("**** \(digits)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Balance and utilization
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(abs(account.currentBalance)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(account.currentBalance < 0 ? Color.expenseRed : .green)
                    // v1.3: Dynamic Type protection
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibleCurrency(abs(account.currentBalance), label: "\(account.name) balance")
                
                if let utilization = account.creditUtilization {
                    Text("\(Int(utilization))% used")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: account.utilizationStatus.color))
                        // v1.3: Dynamic Type protection
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        var description = account.name
        if let digits = account.lastFourDigits {
            description += ", ending in \(digits)"
        }
        description += ", balance \(CurrencyFormatter.format(abs(account.currentBalance)))"
        if let utilization = account.creditUtilization {
            description += ", \(Int(utilization)) percent utilization"
        }
        return description
    }
}

// MARK: - Preview

#Preview("With Balances") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    let card1 = Account(
        name: "Chase Sapphire",
        accountType: .creditCard,
        currentBalance: -2500.00,
        financeType: .personal,
        lastFourDigits: "4521",
        institutionName: "Chase",
        creditLimit: 10000.00,
        apr: 24.99,
        paymentDueDay: 15
    )
    
    let card2 = Account(
        name: "Business Ink",
        accountType: .creditCard,
        currentBalance: -890.00,
        financeType: .business,
        lastFourDigits: "1234",
        creditLimit: 15000.00,
        apr: 21.99,
        paymentDueDay: 25
    )
    
    context.insert(card1)
    context.insert(card2)
    
    return NavigationStack {
        ScrollView {
            CreditCardSummaryCard(financeMode: .all)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Paid Off") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    let card = Account(
        name: "Paid Off Card",
        accountType: .creditCard,
        currentBalance: 0,
        financeType: .personal,
        creditLimit: 5000.00
    )
    
    context.insert(card)
    
    return NavigationStack {
        ScrollView {
            CreditCardSummaryCard(financeMode: .all)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Business Only - Empty") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    // Only personal card exists
    let card = Account(
        name: "Personal Card",
        accountType: .creditCard,
        currentBalance: -500.00,
        financeType: .personal,
        creditLimit: 5000.00
    )
    
    context.insert(card)
    
    return NavigationStack {
        ScrollView {
            CreditCardSummaryCard(financeMode: .business)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}

#Preview("Payment Due Soon") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Account.self, Transaction.self, configurations: config)
    
    let context = container.mainContext
    
    // Card with payment due in 3 days
    let today = Calendar.current.component(.day, from: Date())
    let dueDayInThreeDays = ((today + 3 - 1) % 31) + 1
    
    let card = Account(
        name: "Due Soon Card",
        accountType: .creditCard,
        currentBalance: -1500.00,
        financeType: .personal,
        lastFourDigits: "9999",
        creditLimit: 5000.00,
        apr: 19.99,
        paymentDueDay: dueDayInThreeDays
    )
    
    context.insert(card)
    
    return NavigationStack {
        ScrollView {
            CreditCardSummaryCard(financeMode: .all)
                .padding()
        }
        .background(Color.floSystemGroupedBackground)
    }
    .modelContainer(container)
    .environmentObject(SubscriptionManager.shared)
}
