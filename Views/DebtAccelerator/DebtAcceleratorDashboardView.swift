//  DebtAcceleratorDashboardView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Debt Accelerator Phase 1
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ FIXED (iPad §3): "Your Debts" rows were inert, leaving the Zone 3 detail
//           pane empty on tap. On regular width (iPad/macOS) tapping a debt row
//           now routes the right pane to that account's detail via
//           `requestDetailNavigation`. (The default right pane is also now
//           populated by DebtSummaryPanel.)
//
//  CHANGES v1.1:
//  ✅ ADDED: "Payoff Calculator" toolbar button presenting DebtPayoffCalculatorView
//           as a sheet. Resolves the Accelerator-vs-Calculator naming confusion by
//           nesting the single-debt Calculator under the multi-debt Accelerator,
//           instead of as a separate (and easily-missed) Settings → Tools row.
//

import SwiftUI
import SwiftData
import Charts

struct DebtAcceleratorDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @Query(sort: \DebtAcceleratorPlan.createdDate, order: .reverse) private var plans: [DebtAcceleratorPlan]
    @Query private var accounts: [Account]
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    /// On regular width (iPad/macOS) debt rows route to the Zone 3 detail pane.
    /// On compact width (iPhone) they stay inert, matching prior behavior.
    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    @State private var showingCreatePlan = false
    @State private var showingPaywall = false
    @State private var showingCalculator = false
    @State private var projection: DebtCalculationService.AcceleratorProjection?
    @State private var isCalculating = false
    @State private var refreshTrigger = UUID()

    private var debtAccounts: [Account] {
        accounts.filter { $0.isDebtAccount }
    }

    private var totalDebt: Double {
        debtAccounts.reduce(0) { $0 + abs($1.currentBalance) }
    }

    private var totalMinimumPayments: Double {
        debtAccounts.reduce(0) { total, account in
            total + (account.minimumPaymentDue ?? account.monthlyPaymentAmount ?? 0)
        }
    }

    private var weightedAPR: Double {
        guard totalDebt > 0 else { return 0 }
        let weightedSum = debtAccounts.reduce(0.0) { $0 + abs($1.currentBalance) * $1.effectiveAPR }
        return weightedSum / totalDebt
    }

    private var activePlan: DebtAcceleratorPlan? {
        plans.first { $0.isActive }
    }

    private var promoExpiringAccounts: [Account] {
        debtAccounts.filter { account in
            guard let days = account.daysUntilPromoExpires else { return false }
            return days > 0 && days <= 90
        }.sorted { ($0.daysUntilPromoExpires ?? 0) < ($1.daysUntilPromoExpires ?? 0) }
    }

    var body: some View {
        List {
            if !subscriptionManager.currentTier.canAccess(.debtCalculator) {
                upgradePromptSection
            } else if debtAccounts.isEmpty {
                noDebtSection
            } else {
                debtOverviewSection
                if let plan = activePlan {
                    activePlanSection(plan)
                    if let projection = projection {
                        projectionSection(projection)
                        payoffTimelineChart(projection)
                    }
                } else {
                    getStartedSection
                }
                if !promoExpiringAccounts.isEmpty {
                    promoWarningSection
                }
                debtListSection
            }
        }
        .navigationTitle("Debt Accelerator")
        .scrollContentBackground(.hidden)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            if subscriptionManager.currentTier.canAccess(.debtCalculator) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCalculator = true
                    } label: {
                        Label("Payoff Calculator", systemImage: "function")
                    }
                }
            }
            if !debtAccounts.isEmpty && subscriptionManager.currentTier.canAccess(.debtCalculator) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Label("New Plan", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePlan) {
            CreateDebtPlanView()
        }
        .onChange(of: showingCreatePlan) { _, isShowing in
            if !isShowing { refreshTrigger = UUID() }
        }
        .sheet(isPresented: $showingPaywall) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingCalculator) {
            DebtPayoffCalculatorView()
        }
        .task(id: refreshTrigger) {
            if let plan = activePlan {
                await runProjection(for: plan)
            }
        }
    }

    // MARK: - Sections

    private var upgradePromptSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("Debt Accelerator")
                    .font(.title2.weight(.bold))

                Text("Create an optimized payoff plan that intelligently prioritizes your debts to save you the most interest.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Premium")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
    }

    private var noDebtSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)

                Text("No Debt Accounts")
                    .font(.title3.weight(.semibold))

                Text("Add a credit card or loan account to start using the Debt Accelerator.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
        }
    }

    private var debtOverviewSection: some View {
        Section("Debt Overview") {
            HStack {
                Label("Total Debt", systemImage: "dollarsign.circle")
                Spacer()
                Text(totalDebt.formatted(.currency(code: "USD")))
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            HStack {
                Label("Accounts", systemImage: "creditcard.fill")
                Spacer()
                Text("\(debtAccounts.count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Weighted APR", systemImage: "percent")
                Spacer()
                Text("\(weightedAPR, specifier: "%.1f")%")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Monthly Minimums", systemImage: "calendar")
                Spacer()
                Text(totalMinimumPayments.formatted(.currency(code: "USD")))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func activePlanSection(_ plan: DebtAcceleratorPlan) -> some View {
        Section("Active Plan") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: plan.strategy.icon)
                        Text(plan.strategy.displayName)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if isCalculating {
                    ProgressView()
                }
            }

            HStack {
                Label("Extra Monthly", systemImage: "plus.circle")
                Spacer()
                Text(plan.extraMonthlyPayment.formatted(.currency(code: "USD")))
                    .foregroundStyle(.blue)
            }

            if plan.vaultAPY > 0 {
                HStack {
                    Label("Vault APY", systemImage: "building.columns")
                    Spacer()
                    Text("\(plan.vaultAPY, specifier: "%.1f")%")
                        .foregroundStyle(.green)
                }
            }

            NavigationLink {
                DebtAcceleratorDetailView(plan: plan)
            } label: {
                Label("View Full Schedule", systemImage: "list.bullet.rectangle")
            }

            NavigationLink {
                WhatIfSimulatorView(plan: plan)
            } label: {
                Label("What-If Simulator", systemImage: "slider.horizontal.3")
            }
        }
    }

    private func projectionSection(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Projected Savings") {
            HStack {
                Label("Payoff Date", systemImage: "calendar.badge.checkmark")
                Spacer()
                Text(projection.payoffDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if projection.monthsSavedVsMinimum > 0 {
                HStack {
                    Label("Months Saved", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(projection.monthsSavedVsMinimum) months")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            if projection.interestSavedVsMinimum > 0 {
                HStack {
                    Label("Interest Saved", systemImage: "banknote")
                    Spacer()
                    Text(projection.interestSavedVsMinimum.formatted(.currency(code: "USD")))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Label("Total Interest", systemImage: "chart.bar")
                Spacer()
                VStack(alignment: .trailing) {
                    Text(projection.totalInterest.formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                    if projection.baselineTotalInterest > 0 {
                        Text("vs \(projection.baselineTotalInterest.formatted(.currency(code: "USD")))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func payoffTimelineChart(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Payoff Timeline") {
            Chart {
                ForEach(Array(projection.monthlyAllocations.enumerated()), id: \.offset) { month, allocations in
                    let totalBalance = allocations.reduce(0.0) { $0 + $1.remainingBalance }
                    LineMark(
                        x: .value("Month", month + 1),
                        y: .value("Balance", totalBalance)
                    )
                    .foregroundStyle(.red.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Month", month + 1),
                        y: .value("Balance", totalBalance)
                    )
                    .foregroundStyle(.red.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompact(amount))
                        }
                    }
                }
            }
            .chartXAxisLabel("Months")
            .chartYAxisLabel("Balance")
            .frame(height: 200)
            .padding(.vertical, 4)
        }
    }

    private var getStartedSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)

                Text("Create Your Payoff Plan")
                    .font(.headline)

                Text("The optimizer will analyze your \(debtAccounts.count) debt account\(debtAccounts.count == 1 ? "" : "s") and create an optimized payment schedule.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingCreatePlan = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Plan")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
    }

    private var promoWarningSection: some View {
        Section {
            ForEach(promoExpiringAccounts) { account in
                let days = account.daysUntilPromoExpires ?? 0
                let isUrgent = days <= 30

                HStack(spacing: 10) {
                    Image(systemName: isUrgent ? "exclamationmark.triangle.fill" : "clock.badge.exclamationmark")
                        .foregroundStyle(isUrgent ? .red : .orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.subheadline.weight(.medium))
                        Text("\(account.promoAPR ?? 0, specifier: "%.1f")% promo rate expires in \(days) day\(days == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Will revert to \(account.apr ?? 0, specifier: "%.1f")% APR")
                            .font(.caption2)
                            .foregroundStyle(isUrgent ? .red : .orange)
                    }

                    Spacer()

                    Text(abs(account.currentBalance).formatted(.currency(code: "USD")))
                        .font(.caption.weight(.semibold))
                }
            }
        } header: {
            Label("Promo Rate Expiring", systemImage: "exclamationmark.triangle")
        }
    }

    private var debtListSection: some View {
        Section("Your Debts") {
            ForEach(debtAccounts.sorted(by: { $0.effectiveAPR > $1.effectiveAPR })) { account in
                debtRow(account)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard routesToDetailPane else { return }
                        HapticService.play(.light)
                        NavigationService.shared.requestDetailNavigation(to: .accountDetail(id: account.id))
                    }
            }
        }
    }

    private func debtRow(_ account: Account) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(account.accountType.displayName)
                    if account.hasActivePromo {
                        Text("PROMO")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.yellow.opacity(0.3))
                            .clipShape(Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(abs(account.currentBalance).formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
                Text("\(account.effectiveAPR, specifier: "%.1f")% APR")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if routesToDetailPane {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func runProjection(for plan: DebtAcceleratorPlan) async {
        isCalculating = true
        defer { isCalculating = false }

        let debts = debtAccounts.compactMap { DebtInput.fromAccount($0) }
        guard !debts.isEmpty else { return }

        var promoExpirations: [UUID: Int] = [:]
        for account in debtAccounts {
            if let days = account.daysUntilPromoExpires {
                promoExpirations[account.id] = days
            }
        }

        let result = DebtCalculationService.shared.runAcceleratorOptimization(
            debts: debts,
            extraBudget: plan.extraMonthlyPayment,
            vaultAPY: plan.vaultAPY,
            promoExpirations: promoExpirations
        )

        projection = result

        // Cache projection on plan
        plan.projectedPayoffDate = result.payoffDate
        plan.projectedTotalInterest = result.totalInterest
        plan.projectedInterestSaved = result.interestSavedVsMinimum
        plan.projectedMonthsSaved = result.monthsSavedVsMinimum
        plan.baselinePayoffDate = result.baselinePayoffDate
        plan.baselineTotalInterest = result.baselineTotalInterest
        plan.modifiedDate = Date()

        // Persist ScheduledPayment records
        // Clear old payments first
        if let existing = plan.scheduledPayments {
            for payment in existing {
                modelContext.delete(payment)
            }
        }

        let calendar = Calendar.current
        let startDate = Date()
        for (monthIndex, allocations) in result.monthlyAllocations.enumerated() {
            let schedDate = calendar.date(byAdding: .month, value: monthIndex + 1, to: startDate) ?? startDate
            for allocation in allocations {
                let payment = ScheduledPayment(
                    accountID: allocation.accountID,
                    accountName: allocation.accountName,
                    debtTypeRaw: allocation.debtType.rawValue,
                    month: monthIndex + 1,
                    scheduledDate: schedDate,
                    minimumPayment: allocation.minimumPayment,
                    extraPayment: allocation.extraPayment,
                    principalPortion: allocation.principalPortion,
                    interestPortion: allocation.interestPortion,
                    remainingBalance: allocation.remainingBalance,
                    priorityScore: allocation.priorityScore
                )
                payment.plan = plan
                modelContext.insert(payment)
            }
        }

        try? modelContext.save()

        // Schedule payment reminders
        if plan.paymentRemindersEnabled {
            await DebtPaymentReminderService.shared.scheduleReminders(
                for: plan,
                accounts: debtAccounts
            )
        }
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0fK", value / 1_000))"
        }
        return "$\(Int(value))"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebtAcceleratorDashboardView()
    }
    .modelContainer(for: [DebtAcceleratorPlan.self, Account.self])
}
#endif
