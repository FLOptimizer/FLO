//  CashFlowForecastView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Accessibility Audit Fixes
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Dedicated view for cash flow forecasting with interactive chart,
//  horizon picker, summary stats, upcoming bills timeline, and
//  danger zone warnings.
//
//  FEATURES v1.0:
//  ✅ Horizon picker (1M/3M/6M/12M) with segmented control
//  ✅ Swift Charts area chart with projected balance line
//  ✅ Summary cards: current → projected balance, lowest point
//  ✅ Upcoming bills timeline (next 10 recurring expenses)
//  ✅ Danger zone warnings when balance goes below threshold
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support with lineLimit + minimumScaleFactor
//  ✅ Haptic feedback via HapticService
//
//  CHANGES v1.1 - Accessibility Audit:
//  ✅ FIXED: Danger zone rows missing .accessibilityElement(children: .combine)
//  ✅ FIXED: Lowest point callout missing accessibility grouping
//  ✅ FIXED: Loading ProgressView missing .updatesFrequently trait

import SwiftUI
import Charts
import SwiftData

struct CashFlowForecastView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @ObservedObject private var forecastService = CashFlowForecastService.shared

    @State private var selectedHorizon: ForecastHorizon = .threeMonths
    @State private var isLoading = true
    @State private var viewAppeared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Horizon Picker
                    horizonPicker
                        .padding(.horizontal)

                    if let forecast = forecastService.currentForecast {
                        // Summary Cards
                        summarySection(forecast)
                            .padding(.horizontal)

                        // Main Chart — guard against empty data (Charts crashes on empty arrays)
                        if !forecast.dailyBalances.isEmpty {
                            chartSection(forecast)
                        }

                        // Danger Zone Warnings
                        if forecast.hasDangerZones {
                            dangerZoneSection(forecast)
                                .padding(.horizontal)
                        }

                        // Upcoming Bills
                        if !forecast.upcomingBills.isEmpty {
                            upcomingBillsSection(forecast)
                                .padding(.horizontal)
                        }
                    } else if isLoading {
                        ProgressView("Generating forecast...")
                            .padding(.top, 60)
                            .accessibilityAddTraits(.updatesFrequently)
                    } else {
                        ContentUnavailableView(
                            "No Forecast Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("Add transactions and recurring bills to see your projected cash flow.")
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Cash Flow Forecast")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Cash flow forecast")
                loadForecast()
            }
            .onChange(of: selectedHorizon) { _, _ in
                HapticService.play(.light)
                loadForecast()
            }
        }
    }

    // MARK: - Horizon Picker

    private var horizonPicker: some View {
        Picker("Forecast Horizon", selection: $selectedHorizon) {
            ForEach(ForecastHorizon.allCases) { horizon in
                Text(horizon.displayName).tag(horizon)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Forecast time horizon")
    }

    // MARK: - Summary Section

    private func summarySection(_ forecast: ForecastResult) -> some View {
        HStack(spacing: 12) {
            // Current Balance
            summaryCard(
                title: "Now",
                amount: forecast.startingBalance,
                color: .primary
            )

            // Arrow
            Image(systemName: forecast.isTrendingUp ? "arrow.up.right" : "arrow.down.right")
                .font(.title2)
                .foregroundStyle(forecast.isTrendingUp ? .green : .red)
                .accessibilityHidden(true)

            // Projected Balance
            summaryCard(
                title: selectedHorizon.fullDisplayName,
                amount: forecast.projectedEndBalance,
                color: forecast.projectedEndBalance >= 0 ? .primary : .red
            )
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }

    private func summaryCard(title: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(amount, format: .currency(code: "USD"))
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Chart Section

    private func chartSection(_ forecast: ForecastResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projected Balance")
                .font(.headline)
                .padding(.horizontal)
                .accessibilityAddTraits(.isHeader)

            Chart(forecast.dailyBalances) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.projectedBalance)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            point.projectedBalance >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3),
                            point.projectedBalance >= 0 ? Color.green.opacity(0.05) : Color.red.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Balance", point.projectedBalance)
                )
                .foregroundStyle(Color.brandPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompactCurrency(amount))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cash flow projection chart")
            .accessibilityValue("Projected balance from \(forecast.formattedStartingBalance) to \(forecast.formattedEndBalance) over \(selectedHorizon.fullDisplayName)")

            // Lowest point callout
            if let lowestDate = forecast.lowestBalanceDate {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(forecast.lowestProjectedBalance < 0 ? .red : .orange)
                        .accessibilityHidden(true)
                    Text("Lowest: \(forecast.formattedLowestBalance) on \(lowestDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical)
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
        .padding(.horizontal)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }

    // MARK: - Danger Zone Section

    private func dangerZoneSection(_ forecast: ForecastResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Low Balance Warning", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.red)
                .accessibilityAddTraits(.isHeader)

            ForEach(forecast.dangerZones) { zone in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(zone.startDate.formatted(date: .abbreviated, time: .omitted)) - \(zone.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(zone.durationDays) day\(zone.durationDays == 1 ? "" : "s") below threshold")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(zone.lowestBalance.formatted(.currency(code: "USD")))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(12)
                .background(Color.red.opacity(0.08))
                .cornerRadius(10)
                .accessibilityElement(children: .combine)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
    }

    // MARK: - Upcoming Bills Section

    private func upcomingBillsSection(_ forecast: ForecastResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Bills")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(forecast.upcomingBills) { bill in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bill.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(bill.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer()
                    Text(bill.formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.expenseRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
    }

    // MARK: - Data Loading

    private func loadForecast() {
        isLoading = true
        Task { @MainActor in
            _ = await forecastService.generateForecast(
                in: context.container,
                horizon: selectedHorizon
            )
            isLoading = false
        }
    }

    // MARK: - Formatting

    private func formatCompactCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)$\(String(format: "%.0f", absValue / 1_000))K"
        } else {
            return "\(sign)$\(String(format: "%.0f", absValue))"
        }
    }
}
