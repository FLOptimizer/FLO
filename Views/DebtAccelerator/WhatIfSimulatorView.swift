//  WhatIfSimulatorView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Debt Accelerator Phase 1
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct WhatIfSimulatorView: View {
    let plan: DebtAcceleratorPlan
    @Query private var accounts: [Account]

    @State private var extraPayment: Double = 0
    @State private var vaultAPY: Double = 0
    @State private var selectedStrategy: AcceleratorStrategy = .hybrid
    @State private var projection: DebtCalculationService.AcceleratorProjection?
    @State private var baseProjection: DebtCalculationService.AcceleratorProjection?
    @State private var isCalculating = false

    private var debtAccounts: [Account] {
        accounts.filter { $0.isDebtAccount }
    }

    var body: some View {
        List {
            controlsSection
            if let projection = projection {
                comparisonSection(projection)
                timelineComparison(projection)
            }
        }
        .navigationTitle("What-If Simulator")
        .scrollContentBackground(.hidden)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            extraPayment = plan.extraMonthlyPayment
            vaultAPY = plan.vaultAPY
            selectedStrategy = plan.strategy
        }
        .task {
            await recalculate()
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        Section("Adjust Scenario") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Extra Monthly Payment")
                        .font(.subheadline)
                    Spacer()
                    Text(extraPayment.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                Slider(value: $extraPayment, in: 0...2000, step: 25)
                    .tint(.blue)
                    .onChange(of: extraPayment) { _, _ in
                        Task { await recalculate() }
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Vault/HYSA APY")
                        .font(.subheadline)
                    Spacer()
                    Text("\(vaultAPY, specifier: "%.1f")%")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                Slider(value: $vaultAPY, in: 0...7, step: 0.25)
                    .tint(.green)
                    .onChange(of: vaultAPY) { _, _ in
                        Task { await recalculate() }
                    }
            }

            Picker("Strategy", selection: $selectedStrategy) {
                ForEach(AcceleratorStrategy.allCases) { strategy in
                    Label(strategy.displayName, systemImage: strategy.icon)
                        .tag(strategy)
                }
            }
            .onChange(of: selectedStrategy) { _, _ in
                Task { await recalculate() }
            }
        }
    }

    private func comparisonSection(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Scenario Results") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debt-Free Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projection.payoffDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Minimum Only")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projection.baselinePayoffDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.red)
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

            if projection.monthsSavedVsMinimum > 0 {
                HStack {
                    Label("Months Saved", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(projection.monthsSavedVsMinimum) months")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            }

            // Show delta vs current plan
            if let base = baseProjection {
                let interestDelta = base.totalInterest - projection.totalInterest
                let monthsDelta = base.monthlyAllocations.count - projection.monthlyAllocations.count

                if abs(interestDelta) > 1 || monthsDelta != 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("vs Your Current Plan")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if abs(interestDelta) > 1 {
                            HStack {
                                Image(systemName: interestDelta > 0 ? "arrow.down" : "arrow.up")
                                    .foregroundStyle(interestDelta > 0 ? .green : .red)
                                Text("\(abs(interestDelta).formatted(.currency(code: "USD"))) \(interestDelta > 0 ? "less" : "more") interest")
                                    .font(.subheadline)
                            }
                        }

                        if monthsDelta != 0 {
                            HStack {
                                Image(systemName: monthsDelta > 0 ? "arrow.down" : "arrow.up")
                                    .foregroundStyle(monthsDelta > 0 ? .green : .red)
                                Text("\(abs(monthsDelta)) month\(abs(monthsDelta) == 1 ? "" : "s") \(monthsDelta > 0 ? "sooner" : "later")")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func timelineComparison(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Payoff Comparison") {
            Chart {
                // Scenario line
                ForEach(Array(projection.monthlyAllocations.enumerated()), id: \.offset) { month, allocations in
                    let totalBalance = allocations.reduce(0.0) { $0 + $1.remainingBalance }
                    LineMark(
                        x: .value("Month", month + 1),
                        y: .value("Balance", totalBalance),
                        series: .value("Plan", "Scenario")
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }

                // Current plan line
                if let base = baseProjection {
                    ForEach(Array(base.monthlyAllocations.enumerated()), id: \.offset) { month, allocations in
                        let totalBalance = allocations.reduce(0.0) { $0 + $1.remainingBalance }
                        LineMark(
                            x: .value("Month", month + 1),
                            y: .value("Balance", totalBalance),
                            series: .value("Plan", "Current")
                        )
                        .foregroundStyle(.gray)
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartForegroundStyleScale([
                "Scenario": .blue,
                "Current": .gray
            ])
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
            .frame(height: 200)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Calculation

    private func recalculate() async {
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

        // Current plan baseline (only on first load)
        if baseProjection == nil {
            baseProjection = DebtCalculationService.shared.runAcceleratorOptimization(
                debts: debts,
                extraBudget: plan.extraMonthlyPayment,
                vaultAPY: plan.vaultAPY,
                promoExpirations: promoExpirations
            )
        }

        // Scenario projection
        projection = DebtCalculationService.shared.runAcceleratorOptimization(
            debts: debts,
            extraBudget: extraPayment,
            vaultAPY: vaultAPY,
            promoExpirations: promoExpirations
        )
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
        WhatIfSimulatorView(plan: DebtAcceleratorPlan(
            name: "Test Plan",
            extraMonthlyPayment: 200,
            vaultAPY: 4.5
        ))
    }
    .modelContainer(for: [DebtAcceleratorPlan.self, Account.self])
}
#endif
