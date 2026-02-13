//  TaxEstimateCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing quarterly tax estimates (Premium Feature)
//
//  CHANGES v3.1:
//  ✅ Added comprehensive VoiceOver accessibility labels
//  ✅ Currency amounts read naturally (e.g., "one thousand two hundred dollars")
//  ✅ Status indicators announced with context
//  ✅ Deadline countdown read with urgency context
//  ✅ Tax breakdown rows combined for screen readers
//  ✅ Premium overlay accessible with upgrade action
//  ✅ Info button and interactive elements properly labeled
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
                    .accessibilityHidden(true)
                
                Text("Quarterly Tax Estimate")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                Button {
                    HapticService.play(.medium)
                    
                    if subscriptionManager.currentTier.hasTaxEstimates {
                        showTaxDetails = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Tax details")
                .accessibilityHint(subscriptionManager.currentTier.hasTaxEstimates
                    ? "Shows detailed tax breakdown"
                    : "Upgrade to Premium to view tax details")
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quarterly tax payment: \(estimate.quarterlyPayment.accessibilityCurrency), \(statusAccessibilityLabel(for: estimate))")
                
                // Days until deadline
                if let days = estimate.daysUntilDeadline, let deadline = estimate.nextDeadline {
                    HStack(spacing: 4) {
                        Image(systemName: days <= 7 ? "exclamationmark.triangle.fill" : "calendar")
                            .font(.caption)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                            .scaleEffect(deadlinePulse && days <= 7 ? 1.1 : 1.0)
                            .accessibilityHidden(true)
                        
                        Text("\(days) day\(days == 1 ? "" : "s") until \(deadline.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(deadlineAccessibilityLabel(days: days, deadline: deadline))
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Federal tax: \((estimate.federalIncomeTax / 4).accessibilityCurrency) per quarter")
                    
                    if estimate.stateIncomeTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label: "State",
                            amount: estimate.stateIncomeTax / 4,
                            color: .purple,
                            delay: 0.1,
                            isVisible: breakdownVisible
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("State tax: \((estimate.stateIncomeTax / 4).accessibilityCurrency) per quarter")
                    }
                    
                    if estimate.selfEmploymentTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label: "Self-Employment",
                            amount: estimate.selfEmploymentTax / 4,
                            color: .orange,
                            delay: 0.2,
                            isVisible: breakdownVisible
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Self-employment tax: \((estimate.selfEmploymentTax / 4).accessibilityCurrency) per quarter")
                    }
                }
                .padding(.top, 8)
                
                // Net income context
                Divider()
                    .accessibilityHidden(true)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Net Income (YTD)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(estimate.netIncome.asCurrency)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Year to date net income: \(estimate.netIncome.accessibilityCurrency)")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Effective Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(estimate.effectiveTotalRate.asPercentage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Effective tax rate: \(Int(estimate.effectiveTotalRate * 100)) percent")
                }
            } else {
                // No estimate available - calculating or error
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Calculating...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Calculating tax estimate")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .onAppear {
            calculateTax()
        }
        .onChange(of: transactions.count) { _, _ in
            calculateTax()
        }
    }
    
    // MARK: - Accessibility Helpers
    
    private func statusAccessibilityLabel(for estimate: TaxCalculationService.TaxEstimate) -> String {
        if estimate.isMeetingSafeHarbor {
            return "Status: On track for safe harbor"
        } else {
            return "Status: Below safe harbor threshold, action may be needed"
        }
    }
    
    private func deadlineAccessibilityLabel(days: Int, deadline: Date) -> String {
        let dateString = deadline.formatted(date: .long, time: .omitted)
        if days <= 7 {
            return "Urgent: Only \(days) day\(days == 1 ? "" : "s") until tax deadline on \(dateString)"
        } else if days <= 14 {
            return "Reminder: \(days) days until tax deadline on \(dateString)"
        } else {
            return "\(days) days until next tax deadline on \(dateString)"
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private func statusIndicator(for estimate: TaxCalculationService.TaxEstimate) -> some View {
        if estimate.isMeetingSafeHarbor {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .accessibilityHidden(true) // Included in parent label
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .accessibilityHidden(true) // Included in parent label
        }
    }
    
    // MARK: - Configuration Needed View
    
    private var configurationNeededView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("Configure Tax Settings")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Text("Set up your filing status and state to see estimated taxes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink {
                TaxSettingsView()
            } label: {
                Text("Set Up Now")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.brandPrimary)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Set up tax settings")
            .accessibilityHint("Opens tax configuration screen")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - Premium Overlay
    
    private var premiumOverlay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "lock.fill")
                    .font(.title)
                    .foregroundStyle(Color.brandPrimary)
                    .offset(y: lockBounce ? -4 : 0)
                    .accessibilityHidden(true)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.3)) {
                    lockBounce = true
                }
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("Tax Estimates")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Upgrade to Premium to see quarterly tax estimates and deadlines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button {
                HapticService.play(.medium)
                upgradeButtonScale = 0.95
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    upgradeButtonScale = 1.0
                }
                showingPaywall = true
            } label: {
                Text("Upgrade to Premium")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brandPrimary)
                    .cornerRadius(10)
            }
            .scaleEffect(upgradeButtonScale)
            .accessibilityLabel("Upgrade to Premium")
            .accessibilityHint("Opens subscription options to unlock tax estimates")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tax estimates locked. Premium feature.")
    }
    
    // MARK: - Calculate Tax
    
    @MainActor
    private func calculateTax() {
        guard !taxSettings.isEmpty else { return }
        
        let estimate = TaxCalculationService.shared.calculateYearToDateEstimate(
            transactions: transactions,
            settings: settings
        )
        
        withAnimation(FLOAnimation.standard) {
            self.taxEstimate = estimate
        }
    }
}

// MARK: - Animated Currency Text

struct AnimatedCurrencyText: View {
    let amount: Double
    let isVisible: Bool
    
    @State private var displayAmount: Double = 0
    
    var body: some View {
        Text(displayAmount.asCurrency)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            .onChange(of: isVisible) { _, visible in
                if visible {
                    animateValue()
                }
            }
            .onAppear {
                if isVisible {
                    animateValue()
                }
            }
    }
    
    private func animateValue() {
        let steps = 20
        let stepDuration = 0.5 / Double(steps)
        
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 3) // Ease out cubic
                displayAmount = amount * eased
            }
        }
    }
}

// MARK: - Animated Tax Breakdown Row

struct AnimatedTaxBreakdownRow: View {
    let label: String
    let amount: Double
    let color: Color
    let delay: Double
    let isVisible: Bool
    
    @State private var barWidth: CGFloat = 0
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: barWidth, height: 8)
                }
            }
            .frame(height: 8)
            .onChange(of: isVisible) { _, visible in
                if visible {
                    animateBar()
                }
            }
            
            Text(amount.asCurrency)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        }
    }
    
    private func animateBar() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
            barWidth = 100 // Will be constrained by GeometryReader
        }
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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Annual estimated tax: \(estimate.totalEstimated.accessibilityCurrency)")
                            
                            estimateRow(
                                label: "Quarterly Payment",
                                amount: estimate.quarterlyPayment,
                                color: .teal,
                                isTotal: false
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Quarterly payment due: \(estimate.quarterlyPayment.accessibilityCurrency)")
                        }
                        
                        Divider()
                            .accessibilityHidden(true)
                        
                        // Breakdown Section
                        sectionHeader("Tax Breakdown")
                        
                        VStack(spacing: 12) {
                            detailRow(
                                label: "Federal Income Tax",
                                amount: estimate.federalIncomeTax,
                                rate: estimate.effectiveFederalRate,
                                color: .blue
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Federal income tax: \(estimate.federalIncomeTax.accessibilityCurrency), effective rate \(Int(estimate.effectiveFederalRate * 100)) percent")
                            
                            if estimate.stateIncomeTax > 0 {
                                detailRow(
                                    label: "State Income Tax (\(settings.state))",
                                    amount: estimate.stateIncomeTax,
                                    rate: estimate.effectiveStateRate,
                                    color: .purple
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("State income tax for \(settings.state): \(estimate.stateIncomeTax.accessibilityCurrency), effective rate \(Int(estimate.effectiveStateRate * 100)) percent")
                            }
                            
                            if estimate.selfEmploymentTax > 0 {
                                detailRow(
                                    label: "Self-Employment Tax",
                                    amount: estimate.selfEmploymentTax,
                                    rate: settings.selfEmploymentTaxRate,
                                    color: .orange
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Self-employment tax: \(estimate.selfEmploymentTax.accessibilityCurrency), rate \(Int(settings.selfEmploymentTaxRate * 100)) percent")
                            }
                        }
                        
                        Divider()
                            .accessibilityHidden(true)
                        
                        // Income Section
                        sectionHeader("Income Summary")
                        
                        VStack(spacing: 12) {
                            summaryRow(label: "Net Income (YTD)", amount: estimate.netIncome)
                                .accessibilityLabel("Year to date net income: \(estimate.netIncome.accessibilityCurrency)")
                            summaryRow(label: "Taxable Income", amount: estimate.taxableIncome)
                                .accessibilityLabel("Taxable income: \(estimate.taxableIncome.accessibilityCurrency)")
                            summaryRow(
                                label: "Standard Deduction",
                                amount: TaxSettings.standardDeduction(for: settings.filingStatus)
                            )
                            .accessibilityLabel("Standard deduction: \(TaxSettings.standardDeduction(for: settings.filingStatus).accessibilityCurrency)")
                        }
                        
                        // Safe Harbor (if applicable)
                        if let safeHarbor = estimate.safeHarborAmount {
                            Divider()
                                .accessibilityHidden(true)
                            
                            sectionHeader("Safe Harbor")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: estimate.isMeetingSafeHarbor ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(estimate.isMeetingSafeHarbor ? .green : .orange)
                                        .accessibilityHidden(true)
                                    
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
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(estimate.isMeetingSafeHarbor
                                ? "Safe harbor status: Meeting requirement. Minimum payment: \(safeHarbor.accessibilityCurrency)"
                                : "Safe harbor status: Below requirement. You need to pay at least \(safeHarbor.accessibilityCurrency) to avoid penalties")
                        }
                        
                        // Disclaimer
                        Divider()
                            .accessibilityHidden(true)
                        
                        Text("âš ï¸ **Disclaimer:** These are estimates only. Consult a tax professional for personalized advice. FLO is not responsible for tax filing accuracy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .accessibilityLabel("Disclaimer: These are estimates only. Consult a tax professional for personalized advice.")
                        
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
                        HapticService.play(.medium)
                        dismiss()
                    }
                    .accessibilityLabel("Close tax details")
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TaxSettingsView()
                    } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Tax settings")
                    .accessibilityHint("Configure filing status and state")
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .fontWeight(.semibold)
            .accessibilityAddTraits(.isHeader)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
