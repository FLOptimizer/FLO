//  TaxEstimateCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing quarterly tax estimates (Premium Feature)
//
//  ENHANCEMENTS v3.0:
//  - Animated number counters for tax amounts
//  - Premium overlay with bouncing lock icon
//  - Tax breakdown bars with staggered animations
//  - Haptic feedback on upgrade button press
//  - Deadline countdown with urgency indicators
//  - Smooth card entrance animation
//  - Status indicator pulse effect
//

import SwiftUI
import SwiftData

struct TaxEstimateCard: View {
    @Query private var transactions: [Transaction]
    @Query private var taxSettings: [TaxSettings]
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    @State private var showTaxDetails = false
    @State private var showingPaywall = false
    @State private var taxEstimate: TaxCalculationService.TaxEstimate?
    
    // Animation States
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.95
    @State private var amountVisible = false
    @State private var breakdownVisible = false
    @State private var upgradeButtonScale: CGFloat = 1.0
    @State private var lockBounce = false
    @State private var deadlinePulse = false
    
    private var settings: TaxSettings {
        // Get or create default tax settings
        if let existing = taxSettings.first {
            return existing
        }
        return TaxSettings() // Return default settings
    }
    
    var body: some View {
        ZStack {
            // Base card content (blurred for free users)
            cardContent
                .blur(radius: subscriptionManager.currentTier.hasTaxEstimates ? 0 : 5)
            
            // Premium overlay for free users
            if !subscriptionManager.currentTier.hasTaxEstimates {
                premiumOverlay
            }
        }
        .onAppear {
            animateEntrance()
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .sheet(isPresented: $showTaxDetails) {
            TaxDetailsView(estimate: taxEstimate, settings: settings)
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            cardOpacity = 1.0
            cardScale = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            amountVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            breakdownVisible = true
        }
        
        // Start deadline pulse if urgent
        if let estimate = taxEstimate,
           let days = estimate.daysUntilDeadline,
           days <= 14 {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.5)) {
                deadlinePulse = true
            }
        }
    }
    
    // MARK: - Card Content
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.teal)
                    .font(.title3)
                
                Text("Quarterly Tax Estimate")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    if subscriptionManager.currentTier.hasTaxEstimates {
                        showTaxDetails = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Check if we have valid settings first
            if taxSettings.isEmpty {
                configurationNeededView
            } else if let estimate = taxEstimate {
                // Main amount with status indicator
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AnimatedCurrencyText(
                        amount: estimate.quarterlyPayment,
                        isVisible: amountVisible
                    )
                    
                    statusIndicator(for: estimate)
                }
                
                // Days until deadline
                if let days = estimate.daysUntilDeadline, let deadline = estimate.nextDeadline {
                    HStack(spacing: 4) {
                        Image(systemName: days <= 7 ? "exclamationmark.triangle.fill" : "calendar")
                            .font(.caption)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                            .scaleEffect(deadlinePulse && days <= 7 ? 1.1 : 1.0)
                        
                        Text("\(days) day\(days == 1 ? "" : "s") until \(deadline.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                }
                
                // Tax breakdown
                VStack(spacing: 8) {
                    AnimatedTaxBreakdownRow(
                        label: "Federal",
                        amount: estimate.federalIncomeTax / 4,
                        color: .blue,
                        delay: 0,
                        isVisible: breakdownVisible
                    )
                    
                    if estimate.stateIncomeTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label: "State",
                            amount: estimate.stateIncomeTax / 4,
                            color: .purple,
                            delay: 0.1,
                            isVisible: breakdownVisible
                        )
                    }
                    
                    if estimate.selfEmploymentTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label: "Self-Employment",
                            amount: estimate.selfEmploymentTax / 4,
                            color: .orange,
                            delay: 0.2,
                            isVisible: breakdownVisible
                        )
                    }
                }
                .padding(.top, 8)
                
                // Net income context
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Income (YTD)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(estimate.netIncome.asCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Effective Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(estimate.effectiveTotalRate.asPercentage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .opacity(breakdownVisible ? 1 : 0)
                
            } else {
                // Loading or setup needed
                configurationNeededView
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .onAppear {
            if subscriptionManager.currentTier.hasTaxEstimates {
                calculateEstimate()
            }
        }
        .onChange(of: transactions.count) {
            if subscriptionManager.currentTier.hasTaxEstimates {
                calculateEstimate()
            }
        }
    }
    
    // MARK: - Premium Overlay
    
    private var premiumOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.white)
                .symbolEffect(.bounce, options: .speed(0.5), value: lockBounce)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        lockBounce = true
                    }
                }
            
            VStack(spacing: 8) {
                Text("Premium Feature")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Upgrade to Premium to unlock\nreal-time quarterly tax estimates")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            
            Button {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    upgradeButtonScale = 0.95
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        upgradeButtonScale = 1.0
                    }
                }
                
                showingPaywall = true
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Upgrade to Premium")
                }
                .font(.headline)
                .foregroundColor(Color(hex: "14B8A6"))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white)
                .cornerRadius(10)
                .scaleEffect(upgradeButtonScale)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "14B8A6").opacity(0.9),
                    Color(hex: "0D9488").opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    // MARK: - Configuration Needed View
    
    private var configurationNeededView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("Tax Settings Required")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("Configure your tax settings to see quarterly estimates")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink {
                TaxSettingsView()
            } label: {
                Text("Configure Now")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.teal)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private func statusIndicator(for estimate: TaxCalculationService.TaxEstimate) -> some View {
        if estimate.isMeetingSafeHarbor {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
        }
    }
    
    // MARK: - Calculate Estimate
    
    private func calculateEstimate() {
        guard !taxSettings.isEmpty else { return }
        
        // Filter to business transactions only
        let businessTransactions = transactions.filter { $0.financeType == .business }
        
        taxEstimate = TaxCalculationService.shared.calculateYearToDateEstimate(
            transactions: businessTransactions,
            settings: settings
        )
    }
}

// MARK: - Animated Currency Text

private struct AnimatedCurrencyText: View {
    let amount: Double
    let isVisible: Bool
    
    @State private var displayedAmount: Double = 0
    
    var body: some View {
        Text(displayedAmount.asCurrency)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
            .onChange(of: isVisible) { _, newValue in
                if newValue {
                    animateCounter()
                }
            }
            .onAppear {
                if isVisible {
                    animateCounter()
                }
            }
    }
    
    private func animateCounter() {
        let duration = 0.6
        let steps = 20
        let stepDuration = duration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + (stepDuration * Double(i))) {
                withAnimation(.easeOut(duration: 0.05)) {
                    displayedAmount = amount * Double(i) / Double(steps)
                }
            }
        }
        
        // Ensure final amount is exact
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            displayedAmount = amount
        }
    }
}

// MARK: - Animated Tax Breakdown Row

private struct AnimatedTaxBreakdownRow: View {
    let label: String
    let amount: Double
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    @State private var barWidth: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(color.opacity(0.2))
                        .frame(height: 8)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: barWidth, height: 8)
                }
                .cornerRadius(4)
                .onAppear {
                    if isVisible {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                            barWidth = min(geometry.size.width * 0.8, geometry.size.width)
                        }
                    }
                }
                .onChange(of: isVisible) { _, newValue in
                    if newValue {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
                            barWidth = min(geometry.size.width * 0.8, geometry.size.width)
                        }
                    }
                }
            }
            .frame(height: 8)
            
            Text(amount.asCurrency)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: 70, alignment: .trailing)
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .animation(.easeOut(duration: 0.3).delay(delay), value: isVisible)
    }
}

// MARK: - Tax Details View

struct TaxDetailsView: View {
    let estimate: TaxCalculationService.TaxEstimate?
    let settings: TaxSettings
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let estimate = estimate {
                        // Overview Section
                        sectionHeader("2025 Tax Estimate")
                        
                        VStack(spacing: 16) {
                            estimateRow(
                                label: "Annual Estimated Tax",
                                amount: estimate.totalEstimated,
                                color: .primary,
                                isTotal: true
                            )
                            
                            estimateRow(
                                label: "Quarterly Payment",
                                amount: estimate.quarterlyPayment,
                                color: .teal,
                                isTotal: false
                            )
                        }
                        
                        Divider()
                        
                        // Breakdown Section
                        sectionHeader("Tax Breakdown")
                        
                        VStack(spacing: 12) {
                            detailRow(
                                label: "Federal Income Tax",
                                amount: estimate.federalIncomeTax,
                                rate: estimate.effectiveFederalRate,
                                color: .blue
                            )
                            
                            if estimate.stateIncomeTax > 0 {
                                detailRow(
                                    label: "State Income Tax (\(settings.state))",
                                    amount: estimate.stateIncomeTax,
                                    rate: estimate.effectiveStateRate,
                                    color: .purple
                                )
                            }
                            
                            if estimate.selfEmploymentTax > 0 {
                                detailRow(
                                    label: "Self-Employment Tax",
                                    amount: estimate.selfEmploymentTax,
                                    rate: settings.selfEmploymentTaxRate,
                                    color: .orange
                                )
                            }
                        }
                        
                        Divider()
                        
                        // Income Section
                        sectionHeader("Income Summary")
                        
                        VStack(spacing: 12) {
                            summaryRow(label: "Net Income (YTD)", amount: estimate.netIncome)
                            summaryRow(label: "Taxable Income", amount: estimate.taxableIncome)
                            summaryRow(
                                label: "Standard Deduction",
                                amount: TaxSettings.standardDeduction(for: settings.filingStatus)
                            )
                        }
                        
                        // Safe Harbor (if applicable)
                        if let safeHarbor = estimate.safeHarborAmount {
                            Divider()
                            
                            sectionHeader("Safe Harbor")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: estimate.isMeetingSafeHarbor ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(estimate.isMeetingSafeHarbor ? .green : .orange)
                                    
                                    Text(estimate.isMeetingSafeHarbor ? "Meeting Safe Harbor" : "Below Safe Harbor")
                                        .fontWeight(.medium)
                                }
                                
                                Text("To avoid penalties, pay at least \(safeHarbor.asCurrency) in estimated taxes this year (\(settings.isHighEarner ? "110%" : "100%") of prior year)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        // Disclaimer
                        Divider()
                        
                        Text("⚠️ **Disclaimer:** These are estimates only. Consult a tax professional for personalized advice. FLO is not responsible for tax filing accuracy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        
                    } else {
                        Text("Configure your tax settings to see detailed estimates")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Tax Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TaxSettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.semibold)
    }
    
    private func estimateRow(label: String, amount: Double, color: Color, isTotal: Bool) -> some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundStyle(color)
            
            Spacer()
            
            Text(amount.asCurrency)
                .font(isTotal ? .title2 : .title3)
                .fontWeight(isTotal ? .bold : .semibold)
                .foregroundStyle(color)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func detailRow(label: String, amount: Double, rate: Double, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Text("\(rate.asPercentage) effective rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount.asCurrency)
                    .font(.headline)
                    .foregroundStyle(color)
                
                Text("\((amount / 4).asCurrency)/quarter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func summaryRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(amount.asCurrency)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    TaxEstimateCard()
        .padding()
        .modelContainer(for: [Transaction.self, TaxSettings.self], inMemory: true)
}
