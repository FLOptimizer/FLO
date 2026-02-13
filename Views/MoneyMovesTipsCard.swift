//  MoneyMovesTipsCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Added 44pt minimum touch target to See All button
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card displaying "Money Moves" financial tips.
//  Shows generic tips for Free users (teaser), personalized tips for Premium+.
//
//  FEATURES:
//  ✅ Animated tip cards with swipe
//  ✅ Free tier: 3 generic rotating tips
//  ✅ Premium tier: Personalized debt/spending tips
//  ✅ Tap to expand tip details
//  ✅ Links to Debt Calculator for debt tips
//  ✅ Upgrade prompt for Free users
//

import SwiftUI
import SwiftData

struct MoneyMovesTipsCard: View {
    
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var insightsService = InsightsService.shared
    
    @State private var tips: [MoneyMove] = []
    @State private var currentTipIndex = 0
    @State private var showAllTips = false
    @State private var showDebtCalculator = false
    @State private var showUpgradePrompt = false
    @State private var cardOpacity: Double = 0
    
    private var isPremium: Bool {
        subscriptionManager.currentTier >= .premium
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView
            
            // Current Tip
            if !tips.isEmpty {
                currentTipView
                
                // Pagination dots
                paginationDots
            } else {
                emptyStateView
            }
            
            // Upgrade CTA for Free Users
            if !isPremium && !tips.isEmpty {
                upgradeCTA
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .opacity(cardOpacity)
        .onAppear {
            loadTips()
            animateEntrance()
        }
        .onChange(of: accounts.count) { _, _ in
            loadTips()
        }
        .sheet(isPresented: $showAllTips) {
            AllMoneyMovesSheet(tips: tips, isPremium: isPremium)
        }
        .sheet(isPresented: $showDebtCalculator) {
            DebtPayoffCalculatorView()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            SubscriptionView()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                    .font(.title3)
                
                Text("Money Moves")
                    .font(.headline)
            }
            
            Spacer()
            
            if tips.count > 1 {
                Button {
                    showAllTips = true
                    HapticService.play(.light)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.teal)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
    
    // MARK: - Current Tip View
    
    private var currentTipView: some View {
        let tip = tips[currentTipIndex]
        
        return VStack(alignment: .leading, spacing: 12) {
            // Tip Header
            HStack(spacing: 10) {
                Image(systemName: tip.type.icon)
                    .font(.title2)
                    .foregroundStyle(tip.type.color)
                    .frame(width: 36, height: 36)
                    .background(tip.type.color.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(tip.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        if tip.isPersonalized {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.teal)
                        }
                    }
                    
                    if let savings = tip.potentialSavings {
                        Text("Potential savings: \(formatCurrency(savings))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
            }
            
            // Tip Description
            Text(tip.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // Action Button
            if let actionLabel = tip.actionLabel {
                Button {
                    handleTipAction(tip)
                    HapticService.play(.light)
                } label: {
                    HStack {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.teal)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -30 && currentTipIndex < tips.count - 1 {
                        withAnimation(.spring(response: 0.3)) {
                            currentTipIndex += 1
                        }
                        HapticService.play(.selection)
                    } else if value.translation.width > 30 && currentTipIndex > 0 {
                        withAnimation(.spring(response: 0.3)) {
                            currentTipIndex -= 1
                        }
                        HapticService.play(.selection)
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tipAccessibilityLabel(tip))
        .accessibilityHint(tip.actionLabel != nil ? "Double tap to \(tip.actionLabel ?? "view details")" : "")
    }
    
    // MARK: - Pagination Dots
    
    private var paginationDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<min(tips.count, 5), id: \.self) { index in
                Circle()
                    .fill(index == currentTipIndex ? Color.teal : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentTipIndex)
            }
            
            if tips.count > 5 {
                Text("+\(tips.count - 5)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "lightbulb")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("No tips available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Upgrade CTA
    
    private var upgradeCTA: some View {
        Button {
            showUpgradePrompt = true
            HapticService.play(.medium)
        } label: {
            HStack {
                Image(systemName: "lock.fill")
                    .font(.caption)
                Text("Unlock personalized tips")
                    .font(.caption)
                Spacer()
                Text("Upgrade")
                    .font(.caption)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .padding(12)
            .background(Color.teal.opacity(0.1))
            .foregroundStyle(.teal)
            .cornerRadius(10)
        }
    }
    
    // MARK: - Actions
    
    private func loadTips() {
        tips = insightsService.generateMoneyMovesTips(
            accounts: accounts,
            transactions: transactions,
            isPremium: isPremium
        )
        
        // Reset index if needed
        if currentTipIndex >= tips.count {
            currentTipIndex = 0
        }
    }
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardOpacity = 1.0
        }
    }
    
    private func handleTipAction(_ tip: MoneyMove) {
        if tip.type == .debtPayoff {
            if isPremium {
                showDebtCalculator = true
            } else {
                showUpgradePrompt = true
            }
        }
        // Future: Add navigation to other features based on tip type
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
    
    private func tipAccessibilityLabel(_ tip: MoneyMove) -> String {
        var label = "\(tip.title). \(tip.description)"
        if let savings = tip.potentialSavings {
            label += " Potential savings: \(formatCurrency(savings))"
        }
        if tip.isPersonalized {
            label += " This tip is personalized for you."
        }
        return label
    }
}

// MARK: - All Money Moves Sheet

struct AllMoneyMovesSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let tips: [MoneyMove]
    let isPremium: Bool
    
    @State private var showDebtCalculator = false
    @State private var showUpgradePrompt = false
    
    var body: some View {
        NavigationStack {
            List {
                if !isPremium {
                    Section {
                        upgradePromptRow
                    }
                }
                
                Section {
                    ForEach(tips) { tip in
                        MoneyMoveTipRow(tip: tip) {
                            handleTipAction(tip)
                        }
                    }
                } header: {
                    Text(isPremium ? "Your Money Moves" : "Financial Tips")
                } footer: {
                    if !isPremium {
                        Text("Upgrade to Premium for personalized tips based on your accounts and spending.")
                    }
                }
            }
            .navigationTitle("Money Moves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showDebtCalculator) {
            DebtPayoffCalculatorView()
        }
        .sheet(isPresented: $showUpgradePrompt) {
            SubscriptionView()
        }
    }
    
    private var upgradePromptRow: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Get Personalized Tips")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Unlock tips based on your actual finances")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showUpgradePrompt = true
            } label: {
                Text("Upgrade")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.teal)
                    .foregroundStyle(.white)
                    .cornerRadius(16)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func handleTipAction(_ tip: MoneyMove) {
        if tip.type == .debtPayoff {
            if isPremium {
                showDebtCalculator = true
            } else {
                showUpgradePrompt = true
            }
        }
    }
}

// MARK: - Money Move Tip Row

struct MoneyMoveTipRow: View {
    let tip: MoneyMove
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: tip.type.icon)
                    .font(.title3)
                    .foregroundStyle(tip.type.color)
                    .frame(width: 32, height: 32)
                    .background(tip.type.color.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(tip.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        if tip.isPersonalized {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                                .foregroundStyle(.teal)
                        }
                    }
                    
                    if let savings = tip.potentialSavings {
                        Text("Save \(formatCurrency(savings))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Spacer()
                
                if tip.actionLabel != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(tip.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if tip.actionLabel != nil {
                onAction()
                HapticService.play(.light)
            }
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Compact Money Moves Row (Alternative Layout)

/// Horizontal scrolling layout for dashboard
struct CompactMoneyMovesRow: View {
    @Query private var accounts: [Account]
    @Query private var transactions: [Transaction]
    
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var insightsService = InsightsService.shared
    
    @State private var tips: [MoneyMove] = []
    @State private var showDebtCalculator = false
    
    private var isPremium: Bool {
        subscriptionManager.currentTier >= .premium
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text("Money Moves")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tips.prefix(5)) { tip in
                        CompactMoneyMoveChip(tip: tip) {
                            if tip.type == .debtPayoff && isPremium {
                                showDebtCalculator = true
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            tips = insightsService.generateMoneyMovesTips(
                accounts: accounts,
                transactions: transactions,
                isPremium: isPremium
            )
        }
        .sheet(isPresented: $showDebtCalculator) {
            DebtPayoffCalculatorView()
        }
    }
}

struct CompactMoneyMoveChip: View {
    let tip: MoneyMove
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: tip.type.icon)
                    .font(.caption)
                    .foregroundStyle(tip.type.color)
                
                Text(tip.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            
            if let savings = tip.potentialSavings {
                Text("Save \(formatCurrency(savings))")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(tip.type.color.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
            HapticService.play(.selection)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

// MARK: - Previews

#Preview("Money Moves Card") {
    ScrollView {
        MoneyMovesTipsCard()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Compact Row") {
    CompactMoneyMovesRow()
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
}
