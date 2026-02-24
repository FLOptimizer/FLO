//  TaxEstimateCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.4 — W-2 withholding credit display (Option B)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing quarterly tax estimates (Premium Feature)
//
//  CHANGES v3.4:
//  ✅ UPDATED: Main card primary amount now shows estimate.adjustedQuarterlyPayment
//             (after W-2 withholding credit) instead of estimate.quarterlyPayment
//  ✅ ADDED: Withholding credit row in card breakdown — appears only when
//             estimate.w2WithholdingCredit > 0, shows "−$X.XX withheld/quarter"
//             in green so users can see exactly why their number is lower than
//             gross quarterly tax ÷ 4
//  ✅ ADDED: Income Sources section in TaxDetailsView — shows SE / W-2 / passive /
//             exempt income breakdown when more than one source is present
//  ✅ ADDED: Withholding credit row in TaxDetailsView overview section — "W-2
//             Withholding Credit" as a deduction-style row against annual tax
//  ✅ UPDATED: TaxDetailsView "Quarterly Payment" row uses adjustedQuarterlyPayment
//  ✅ UPDATED: All accessibility labels updated to read adjusted payment amount
//  ✅ PRESERVED: All v3.3 Dynamic Type fixes (font sizes, @ScaledMetric, adaptive layout)
//  ✅ PRESERVED: All v3.1 VoiceOver accessibility labels and hints
//  ✅ PRESERVED: All v3.0 animations (counter, breakdown bars, premium overlay pulse)
//
//  CHANGES v3.3 — Dynamic Type Verification:
//  ✅ AnimatedCurrencyText .system(size:32) → .title
//  ✅ AnimatedTaxBreakdownRow fixed widths → @ScaledMetric
//  ✅ configurationNeededView .system(size:32) → .largeTitle
//  ✅ Adaptive Net Income/Rate layout via @Environment(\.dynamicTypeSize)
//  ✅ lineLimit + minimumScaleFactor throughout
//
//  CHANGES v3.1:
//  ✅ Comprehensive VoiceOver accessibility labels
//  ✅ Currency amounts read naturally
//  ✅ Status indicators announced with context
//  ✅ Premium overlay accessible with upgrade action
//
//  ENHANCEMENTS v3.0:
//  - Animated number counters, premium overlay, staggered breakdown bars
//  - Haptic feedback, deadline countdown, smooth entrance animation
//

import SwiftUI
import SwiftData

struct TaxEstimateCard: View {
    @Query private var transactions: [Transaction]
    @Query private var taxSettings: [TaxSettings]
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showTaxDetails   = false
    @State private var showingPaywall   = false
    @State private var taxEstimate: TaxCalculationService.TaxEstimate?

    // Animation states
    @State private var cardOpacity: Double  = 0
    @State private var cardScale: CGFloat   = 0.95
    @State private var amountVisible        = false
    @State private var breakdownVisible     = false
    @State private var upgradeButtonScale: CGFloat = 1.0
    @State private var lockBounce           = false
    @State private var deadlinePulse        = false

    // v3.3: Dynamic Type awareness
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool { dynamicTypeSize.isAccessibilitySize }

    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }

    var body: some View {
        ZStack {
            cardContent
                .blur(radius: subscriptionManager.currentTier.hasTaxEstimates ? 0 : 5)

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
            cardScale   = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            amountVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            breakdownVisible = true
        }
        if let estimate = taxEstimate,
           let days = estimate.daysUntilDeadline, days <= 14 {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true).delay(0.5)) {
                deadlinePulse = true
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Header ────────────────────────────────────────────────
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

            // ── Body ──────────────────────────────────────────────────
            if taxSettings.isEmpty {
                configurationNeededView
            } else if let estimate = taxEstimate {

                // v3.4: Primary amount = adjustedQuarterlyPayment (after withholding)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    AnimatedCurrencyText(
                        amount:    estimate.adjustedQuarterlyPayment,
                        isVisible: amountVisible
                    )
                    statusIndicator(for: estimate)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(primaryAmountAccessibilityLabel(for: estimate))

                // v3.4: Sub-label — "after withholding" hint when withholding credit exists
                if estimate.w2WithholdingCredit > 0 {
                    Text("after W-2 withholding credit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true) // included in parent label above
                }

                // Deadline countdown
                if let days = estimate.daysUntilDeadline,
                   let deadline = estimate.nextDeadline {
                    HStack(spacing: 4) {
                        Image(systemName: days <= 7 ? "exclamationmark.triangle.fill" : "calendar")
                            .font(.caption)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                            .scaleEffect(deadlinePulse && days <= 7 ? 1.1 : 1.0)
                            .accessibilityHidden(true)

                        Text("\(days) day\(days == 1 ? "" : "s") until \(deadline.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundStyle(days <= 7 ? .orange : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(deadlineAccessibilityLabel(days: days, deadline: deadline))
                }

                // ── Tax breakdown bars ────────────────────────────────
                VStack(spacing: 8) {
                    AnimatedTaxBreakdownRow(
                        label:     "Federal",
                        amount:    estimate.federalIncomeTax / 4,
                        color:     .blue,
                        delay:     0,
                        isVisible: breakdownVisible
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Federal tax: \((estimate.federalIncomeTax / 4).accessibilityCurrency) per quarter")

                    if estimate.stateIncomeTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label:     "State",
                            amount:    estimate.stateIncomeTax / 4,
                            color:     .purple,
                            delay:     0.1,
                            isVisible: breakdownVisible
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("State tax: \((estimate.stateIncomeTax / 4).accessibilityCurrency) per quarter")
                    }

                    if estimate.selfEmploymentTax > 0 {
                        AnimatedTaxBreakdownRow(
                            label:     "Self-Employment",
                            amount:    estimate.selfEmploymentTax / 4,
                            color:     .orange,
                            delay:     0.2,
                            isVisible: breakdownVisible
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Self-employment tax: \((estimate.selfEmploymentTax / 4).accessibilityCurrency) per quarter")
                    }

                    // v3.4: Withholding credit row — green, only when nonzero
                    if estimate.w2WithholdingCredit > 0 {
                        AnimatedTaxBreakdownRow(
                            label:     "W-2 Withheld",
                            amount:    estimate.w2WithholdingCredit / 4,
                            color:     .green,
                            delay:     0.3,
                            isVisible: breakdownVisible,
                            isCredit:  true   // renders as "−$X.XX" in green
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("W-2 withholding credit: \((estimate.w2WithholdingCredit / 4).accessibilityCurrency) already withheld per quarter")
                    }
                }
                .padding(.top, 8)

                // ── Net income / effective rate ────────────────────────
                Divider()
                    .accessibilityHidden(true)

                // v3.3: Adaptive layout for accessibility sizes
                if isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        netIncomeColumn(estimate: estimate)
                        effectiveRateColumn(estimate: estimate)
                    }
                } else {
                    HStack {
                        netIncomeColumn(estimate: estimate)
                        Spacer()
                        effectiveRateColumn(estimate: estimate)
                    }
                }

            } else {
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
        .onAppear { calculateTax() }
        .onChange(of: transactions.count) { _, _ in calculateTax() }
    }

    // MARK: - Net Income / Effective Rate Columns (v3.3)

    private func netIncomeColumn(estimate: TaxCalculationService.TaxEstimate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Net Income (YTD)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(estimate.netIncome.asCurrency)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Year to date net income: \(estimate.netIncome.accessibilityCurrency)")
    }

    private func effectiveRateColumn(estimate: TaxCalculationService.TaxEstimate) -> some View {
        VStack(alignment: isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text("Effective Rate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(estimate.effectiveTotalRate.asPercentage)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Effective tax rate: \(Int(estimate.effectiveTotalRate * 100)) percent")
    }

    // MARK: - Accessibility Helpers

    /// v3.4: Builds the VoiceOver label for the primary amount.
    /// When withholding credit exists, includes "after withholding credit" context.
    private func primaryAmountAccessibilityLabel(for estimate: TaxCalculationService.TaxEstimate) -> String {
        let amountLabel = "Quarterly tax payment due: \(estimate.adjustedQuarterlyPayment.accessibilityCurrency)"
        let statusLabel = statusAccessibilityLabel(for: estimate)

        if estimate.w2WithholdingCredit > 0 {
            let creditLabel = "\((estimate.w2WithholdingCredit / 4).accessibilityCurrency) per quarter already withheld by employer"
            return "\(amountLabel), after withholding credit — \(creditLabel). \(statusLabel)"
        }
        return "\(amountLabel), \(statusLabel)"
    }

    private func statusAccessibilityLabel(for estimate: TaxCalculationService.TaxEstimate) -> String {
        estimate.isMeetingSafeHarbor
            ? "Status: On track for safe harbor"
            : "Status: Below safe harbor threshold, action may be needed"
    }

    private func deadlineAccessibilityLabel(days: Int, deadline: Date) -> String {
        let dateString = deadline.formatted(date: .long, time: .omitted)
        if days <= 7  { return "Urgent: Only \(days) day\(days == 1 ? "" : "s") until tax deadline on \(dateString)" }
        if days <= 14 { return "Reminder: \(days) days until tax deadline on \(dateString)" }
        return "\(days) days until next tax deadline on \(dateString)"
    }

    // MARK: - Status Indicator

    @ViewBuilder
    private func statusIndicator(for estimate: TaxCalculationService.TaxEstimate) -> some View {
        if estimate.isMeetingSafeHarbor {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Configuration Needed

    private var configurationNeededView: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape.2")
                .font(.largeTitle) // v3.3: Dynamic Type-safe
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

// MARK: - Animated Currency Text (v3.3 — unchanged)

struct AnimatedCurrencyText: View {
    let amount: Double
    let isVisible: Bool

    @State private var displayAmount: Double = 0

    var body: some View {
        Text(displayAmount.asCurrency)
            .font(.title)           // v3.3: Dynamic Type-safe
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .onChange(of: isVisible) { _, visible in
                if visible { animateValue() }
            }
            .onAppear {
                if isVisible { animateValue() }
            }
    }

    private func animateValue() {
        let steps        = 20
        let stepDuration = 0.5 / Double(steps)
        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                let eased    = 1 - pow(1 - progress, 3)
                displayAmount = amount * eased
            }
        }
    }
}

// MARK: - Animated Tax Breakdown Row (v3.4 — added isCredit parameter)

struct AnimatedTaxBreakdownRow: View {
    let label:     String
    let amount:    Double
    let color:     Color
    let delay:     Double
    let isVisible: Bool
    /// v3.4: When true, renders the amount as "−$X.XX" to indicate a credit/reduction.
    var isCredit: Bool = false

    @State private var barWidth: CGFloat = 0

    // v3.3: @ScaledMetric prevents overflow at large Dynamic Type sizes
    @ScaledMetric(relativeTo: .caption) private var labelWidth:  CGFloat = 100
    @ScaledMetric(relativeTo: .caption) private var amountWidth: CGFloat = 80

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: min(labelWidth, 160), alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { _ in
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
                if visible { animateBar() }
            }

            // v3.4: Prefix with "−" for credit rows
            Text(isCredit ? "−\(amount.asCurrency)" : amount.asCurrency)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .frame(width: min(amountWidth, 120), alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func animateBar() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay)) {
            barWidth = 100
        }
    }
}

// MARK: - Tax Details View (v3.4 — withholding credit + income sources)

struct TaxDetailsView: View {
    let estimate: TaxCalculationService.TaxEstimate?
    let settings: TaxSettings

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let estimate = estimate {

                        // ── Overview ──────────────────────────────────
                        sectionHeader("2026 Tax Estimate")

                        VStack(spacing: 16) {
                            estimateRow(
                                label:   "Annual Estimated Tax",
                                amount:  estimate.totalEstimated,
                                color:   .primary,
                                isTotal: true
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Annual estimated tax: \(estimate.totalEstimated.accessibilityCurrency)")

                            // v3.4: Withholding credit row — only when nonzero
                            if estimate.w2WithholdingCredit > 0 {
                                estimateRow(
                                    label:   "W-2 Withholding Credit",
                                    amount:  estimate.w2WithholdingCredit,
                                    color:   .green,
                                    isTotal: false,
                                    isCredit: true
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("W-2 withholding credit: \(estimate.w2WithholdingCredit.accessibilityCurrency) already paid by employer")
                            }

                            // v3.4: Quarterly shows adjusted (after-withholding) amount
                            estimateRow(
                                label:   estimate.w2WithholdingCredit > 0
                                             ? "Quarterly Payment Due"
                                             : "Quarterly Payment",
                                amount:  estimate.adjustedQuarterlyPayment,
                                color:   .teal,
                                isTotal: false
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Quarterly payment due: \(estimate.adjustedQuarterlyPayment.accessibilityCurrency)")
                        }

                        Divider().accessibilityHidden(true)

                        // ── Income Sources (v3.4) ─────────────────────
                        // Only shown when more than one income type is present,
                        // otherwise this section adds noise without insight.
                        let hasMultipleSources = hasMultipleIncomeSources(estimate)
                        if hasMultipleSources {
                            sectionHeader("Income Sources")

                            VStack(spacing: 12) {
                                if estimate.selfEmploymentIncome > 0 {
                                    incomeSourceRow(
                                        label:      "Self-Employment / 1099",
                                        amount:     estimate.selfEmploymentIncome,
                                        icon:       "laptopcomputer",
                                        color:      .orange,
                                        note:       "SE tax applies"
                                    )
                                }
                                if estimate.w2Income > 0 {
                                    incomeSourceRow(
                                        label:      "W-2 / Salary",
                                        amount:     estimate.w2Income,
                                        icon:       "building.columns.fill",
                                        color:      .blue,
                                        note:       "Employer withholds"
                                    )
                                }
                                if estimate.passiveIncome > 0 {
                                    incomeSourceRow(
                                        label:      "Passive / Investment",
                                        amount:     estimate.passiveIncome,
                                        icon:       "chart.line.uptrend.xyaxis",
                                        color:      .purple,
                                        note:       "Income tax only"
                                    )
                                }
                            }

                            Divider().accessibilityHidden(true)
                        }

                        // ── Tax Breakdown ─────────────────────────────
                        sectionHeader("Tax Breakdown")

                        VStack(spacing: 12) {
                            detailRow(
                                label:  "Federal Income Tax",
                                amount: estimate.federalIncomeTax,
                                rate:   estimate.effectiveFederalRate,
                                color:  .blue
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Federal income tax: \(estimate.federalIncomeTax.accessibilityCurrency), effective rate \(Int(estimate.effectiveFederalRate * 100)) percent")

                            if estimate.stateIncomeTax > 0 {
                                detailRow(
                                    label:  "State Income Tax (\(settings.state))",
                                    amount: estimate.stateIncomeTax,
                                    rate:   estimate.effectiveStateRate,
                                    color:  .purple
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("State income tax for \(settings.state): \(estimate.stateIncomeTax.accessibilityCurrency), effective rate \(Int(estimate.effectiveStateRate * 100)) percent")
                            }

                            if estimate.selfEmploymentTax > 0 {
                                detailRow(
                                    label:  "Self-Employment Tax",
                                    amount: estimate.selfEmploymentTax,
                                    rate:   settings.selfEmploymentTaxRate,
                                    color:  .orange
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Self-employment tax: \(estimate.selfEmploymentTax.accessibilityCurrency), rate \(Int(settings.selfEmploymentTaxRate * 100)) percent")
                            }
                        }

                        Divider().accessibilityHidden(true)

                        // ── Income Summary ────────────────────────────
                        sectionHeader("Income Summary")

                        VStack(spacing: 12) {
                            summaryRow(label: "Net Income (YTD)",  amount: estimate.netIncome)
                                .accessibilityLabel("Year to date net income: \(estimate.netIncome.accessibilityCurrency)")
                            summaryRow(label: "Taxable Income",    amount: estimate.taxableIncome)
                                .accessibilityLabel("Taxable income: \(estimate.taxableIncome.accessibilityCurrency)")
                            summaryRow(
                                label:  "Standard Deduction",
                                amount: TaxSettings.standardDeduction(for: settings.filingStatus)
                            )
                            .accessibilityLabel("Standard deduction: \(TaxSettings.standardDeduction(for: settings.filingStatus).accessibilityCurrency)")
                        }

                        // ── Safe Harbor ───────────────────────────────
                        if let safeHarbor = estimate.safeHarborAmount {
                            Divider().accessibilityHidden(true)

                            sectionHeader("Safe Harbor")

                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: estimate.isMeetingSafeHarbor
                                          ? "checkmark.circle.fill"
                                          : "exclamationmark.triangle.fill")
                                        .foregroundStyle(estimate.isMeetingSafeHarbor ? .green : .orange)
                                        .accessibilityHidden(true)

                                    Text(estimate.isMeetingSafeHarbor
                                         ? "Meeting Safe Harbor"
                                         : "Below Safe Harbor")
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
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
                                ? "Safe harbor: Meeting requirement. Minimum payment: \(safeHarbor.accessibilityCurrency)"
                                : "Safe harbor: Below requirement. Pay at least \(safeHarbor.accessibilityCurrency) to avoid penalties")
                        }

                        Divider().accessibilityHidden(true)

                        // ── Disclaimer ────────────────────────────────
                        Text("⚠️ **Disclaimer:** These are estimates only. Consult a tax professional for personalized advice. FLO is not responsible for tax filing accuracy.")
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

    // MARK: - Income Source Helpers

    /// True when the estimate has income from more than one treatment bucket.
    private func hasMultipleIncomeSources(_ estimate: TaxCalculationService.TaxEstimate) -> Bool {
        let buckets = [estimate.selfEmploymentIncome, estimate.w2Income, estimate.passiveIncome]
        return buckets.filter { $0 > 0 }.count > 1
    }

    /// Compact row showing a single income source type with icon and note.
    private func incomeSourceRow(
        label:  String,
        amount: Double,
        icon:   String,
        color:  Color,
        note:   String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Text(amount.asCurrency)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(amount.accessibilityCurrency). \(note).")
    }

    // MARK: - Helper Views

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.title3)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityAddTraits(.isHeader)
    }

    /// v3.4: Added optional isCredit flag — renders amount in parentheses-style
    ///       with negative sign for credit rows (withholding).
    private func estimateRow(
        label:    String,
        amount:   Double,
        color:    Color,
        isTotal:  Bool,
        isCredit: Bool = false
    ) -> some View {
        HStack {
            Text(label)
                .font(isTotal ? .headline : .subheadline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Text(isCredit ? "−\(amount.asCurrency)" : amount.asCurrency)
                .font(isTotal ? .title2 : .title3)
                .fontWeight(isTotal ? .bold : .semibold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(rate.asPercentage) effective rate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(amount.asCurrency)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

// MARK: - Preview

#Preview {
    TaxEstimateCard()
        .padding()
        .modelContainer(for: [Transaction.self, TaxSettings.self, Category.self], inMemory: true)
}
