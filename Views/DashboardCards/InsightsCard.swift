//  InsightsCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.3.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card displaying AI-like spending insights.
//
//  CHANGES v1.2:
//  ✅ Added accounts query for debt insights
//  ✅ Pass accounts to generateInsights() for debt analysis
//  ✅ handleAction now opens Debt Calculator for debt tips
//  ✅ Added showingDebtCalculator sheet state
//  ✅ Debt insights show "Open Calculator" action
//
//  CHANGES v1.1:
//  ✅ Added VoiceOver labels for all insight rows
//  ✅ Priority indicators announced (urgent, high priority)
//  ✅ Actionable insights have clear hints
//  ✅ Empty state and loading states accessible
//  ✅ Expand/collapse button properly labeled
//  ✅ Compact chips and summary cards accessible
//
//  FEATURES v1.0:
//  ✅ Animated insight cards with staggered entrance
//  ✅ Color-coded by insight type
//  ✅ Expandable for more insights
//  ✅ Haptic feedback on interactions
//  ✅ Empty state handling
//  ✅ Premium feature gating (optional)
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct InsightsCard: View {
    @State private var transactions: [Transaction] = []
    @State private var budgets: [Budget] = []
    @State private var mileageTrips: [MileageTrip] = []
    @Query private var categories: [Category]
    @Query private var accounts: [Account]  // v1.2: Added for debt insights

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var insightsService = InsightsService.shared
    
    @State private var isExpanded = false
    @State private var cardOpacity: Double = 0
    @State private var visibleInsights: Set<UUID> = []
    @State private var showingDebtCalculator = false  // v1.2: Debt calculator sheet
    
    /// Maximum insights to show when collapsed
    private let collapsedCount = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView
            
            // Content
            if insightsService.isGenerating {
                loadingView
            } else if insightsService.insights.isEmpty {
                emptyStateView
            } else {
                insightsListView
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
        .opacity(cardOpacity)
        .onAppear {
            loadData()
            generateInsights()
            animateEntrance()
        }
        .onDisappear {
            transactions = []
            budgets = []
            mileageTrips = []
        }
        .onChange(of: transactions.count) { _, _ in
            insightsService.invalidateCache()
            generateInsights()
        }
        .onChange(of: accounts.count) { _, _ in  // v1.2: Regenerate on account changes
            insightsService.invalidateCache()
            generateInsights()
        }
        // v1.2: Debt calculator sheet
        .sheet(isPresented: $showingDebtCalculator) {
            DebtPayoffCalculatorView()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Financial Insights")
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.title3)
                .accessibilityHidden(true)
            
            Text("Insights")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            if insightsService.insights.count > collapsedCount {
                Button {
                    HapticService.play(.selection)
                    withAnimation(FLOAnimation.standard) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(isExpanded ? "Show Less" : "Show All")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                }
                .accessibilityLabel(isExpanded ? "Show fewer insights" : "Show all \(insightsService.insights.count) insights")
                .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") the insights list")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Insights, \(insightsService.insights.count) available")
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .accessibilityHidden(true)
            Text("Analyzing your finances...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing your financial data, please wait")
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            
            Text("All Caught Up!")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("No new insights right now. Keep tracking your finances and check back later.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All caught up! No new insights right now. Keep tracking your finances and check back later.")
    }
    
    // MARK: - Insights List
    
    private var insightsListView: some View {
        VStack(spacing: 10) {
            let displayedInsights = isExpanded
                ? insightsService.insights
                : Array(insightsService.insights.prefix(collapsedCount))
            
            ForEach(Array(displayedInsights.enumerated()), id: \.element.id) { index, insight in
                SpendingInsightRow(
                    insight: insight,
                    onDebtCalculatorTap: {  // v1.2: Pass action to open calculator
                        showingDebtCalculator = true
                    }
                )
                .opacity(visibleInsights.contains(insight.id) ? 1 : 0.001)
                .offset(y: visibleInsights.contains(insight.id) ? 0 : 10)
                .onAppear {
                    animateInsightEntrance(insight: insight, delay: Double(index) * 0.1)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadData() {
        let calendar = Calendar.current
        let yearStart = calendar.date(from: calendar.dateComponents([.year], from: Date()))!

        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= yearStart },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        transactions = (try? modelContext.fetch(txDescriptor)) ?? []

        let tripDescriptor = FetchDescriptor<MileageTrip>(
            predicate: #Predicate<MileageTrip> { $0.startDate >= yearStart }
        )
        mileageTrips = (try? modelContext.fetch(tripDescriptor)) ?? []

        let budgetDescriptor = FetchDescriptor<Budget>()
        budgets = (try? modelContext.fetch(budgetDescriptor)) ?? []
    }

    private func generateInsights() {
        insightsService.generateInsights(
            transactions: transactions,
            budgets: budgets,
            mileageTrips: mileageTrips,
            categories: categories,
            accounts: accounts  // v1.2: Pass accounts for debt insights
        )
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardOpacity = 1.0
        }
    }
    
    private func animateInsightEntrance(insight: SpendingInsight, delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                _ = visibleInsights.insert(insight.id)
            }
        }
    }
}

// MARK: - Spending Insight Row

struct SpendingInsightRow: View {
    let insight: SpendingInsight
    var onDebtCalculatorTap: (() -> Void)? = nil  // v1.2: Callback for debt calculator
    
    @State private var isPressed = false
    
    /// Accessibility label for the entire row
    private var accessibilityDescription: String {
        var description = insight.title
        
        // Add priority context
        if insight.priority == .urgent {
            description = "Urgent: " + description
        } else if insight.priority == .high {
            description = "Important: " + description
        }
        
        // Add message
        description += ". " + insight.message
        
        // Add action hint if actionable
        if insight.actionable, let actionLabel = insight.actionLabel {
            description += ". Action available: \(actionLabel)"
        }
        
        return description
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(insight.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: insight.icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(insight.color)
            }
            .accessibilityHidden(true)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if insight.priority == .urgent || insight.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                    }
                }
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                // Action button if actionable
                if insight.actionable, let actionLabel = insight.actionLabel {
                    Button {
                        HapticService.play(.light)
                        handleAction(for: insight)
                    } label: {
                        Text(actionLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.teal)
                    }
                    .padding(.top, 2)
                    .accessibilityLabel(actionLabel)
                    .accessibilityHint("Double tap to take action")
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.floTertiarySystemBackground)
        .cornerRadius(12)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            if insight.actionable {
                HapticService.play(.light)
                handleAction(for: insight)
            }
        }
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(insight.actionable ? "Double tap to view details" : "")
        .accessibilityAddTraits(insight.actionable ? .isButton : [])
    }
    
    // v1.2: Updated action handling with debt calculator support
    private func handleAction(for insight: SpendingInsight) {
        // Check if this is a debt insight that should open the calculator
        if insight.shouldOpenDebtCalculator {
            onDebtCalculatorTap?()
            return
        }
        
        // Navigate based on insight type
        switch insight.type {
        case .warning, .alert:
            // Navigate to transactions (could filter by category in future)
            NavigationService.shared.navigateTo(.transactions)
            
        case .success, .milestone:
            // Show celebration or just acknowledge
            break
            
        case .tip:
            // Navigate to relevant section
            if insight.message.lowercased().contains("tax") || insight.message.lowercased().contains("deduction") {
                NavigationService.shared.navigateTo(.tax)
            } else if insight.message.lowercased().contains("credit") || insight.message.lowercased().contains("utilization") {
                // Credit utilization - go to transactions or accounts
                NavigationService.shared.navigateTo(.transactions)
            } else {
                NavigationService.shared.navigateTo(.transactions)
            }
            
        case .trend, .cashFlow:
            NavigationService.shared.navigateTo(.transactions)

        case .prediction:
            // ML-generated insights — navigate to transactions for review
            NavigationService.shared.navigateTo(.transactions)
        }
    }
}

// MARK: - Compact Insights Row (Alternative Layout)

/// A more compact horizontal scrolling layout for insights
struct CompactInsightsRow: View {
    @ObservedObject private var insightsService = InsightsService.shared
    @State private var showingDebtCalculator = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(insightsService.insights.prefix(5)) { insight in
                    CompactInsightChip(insight: insight) {
                        if insight.shouldOpenDebtCalculator {
                            showingDebtCalculator = true
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showingDebtCalculator) {
            DebtPayoffCalculatorView()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick insights")
    }
}

private struct CompactInsightChip: View {
    let insight: SpendingInsight
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: insight.icon)
                .font(.caption)
                .foregroundStyle(insight.color)
                .accessibilityHidden(true)
            
            Text(insight.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(insight.color.opacity(0.1))
        .cornerRadius(20)
        .onTapGesture {
            HapticService.play(.selection)
            onTap?()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.title). \(insight.message)")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Insights Summary Card (Mini Version)

/// A smaller summary card showing insight count
struct InsightsSummaryCard: View {
    @ObservedObject private var insightsService = InsightsService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(.yellow)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(insightsService.insights.count) Insights")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                if let topInsight = insightsService.insights.first {
                    Text(topInsight.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insightsSummaryAccessibilityLabel)
        .accessibilityHint("Double tap to view all insights")
        .accessibilityAddTraits(.isButton)
    }
    
    private var insightsSummaryAccessibilityLabel: String {
        let count = insightsService.insights.count
        if count == 0 {
            return "No insights available"
        } else if count == 1 {
            return "1 insight: \(insightsService.insights.first?.title ?? "")"
        } else {
            return "\(count) insights. Top insight: \(insightsService.insights.first?.title ?? "")"
        }
    }
}

// MARK: - Preview

#Preview("Insights Card") {
    ScrollView {
        VStack(spacing: 16) {
            InsightsCard()
            InsightsSummaryCard()
            CompactInsightsRow()
        }
        .padding()
    }
    .modelContainer(for: [Transaction.self, Budget.self, MileageTrip.self, Category.self, Account.self], inMemory: true)
}

#Preview("Spending Insight Row") {
    VStack(spacing: 12) {
        ForEach(InsightsService.previewInsights) { insight in
            SpendingInsightRow(insight: insight)
        }
    }
    .padding()
}
