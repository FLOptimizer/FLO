//  CashFlowForecastCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Cash Flow Forecast Dashboard Card
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Compact dashboard card showing a 30-day balance trajectory sparkline
//  with current → projected balance and warning indicators.
//  Taps open the full CashFlowForecastView.
//
//  FEATURES v1.0:
//  ✅ Mini sparkline chart (30-day projection)
//  ✅ Current balance → projected 30-day balance
//  ✅ Warning icon when balance goes negative
//  ✅ Tap to open full CashFlowForecastView
//  ✅ VoiceOver accessibility support
//  ✅ Dynamic Type support with lineLimit + minimumScaleFactor
//  ✅ Follows existing dashboard card pattern

import SwiftUI
import Charts
import FLODesignSystem

struct CashFlowForecastCard: View {
    @ObservedObject private var forecastService = CashFlowForecastService.shared
    @State private var showingForecast = false

    var body: some View {
        Button {
            HapticService.play(.light)
            showingForecast = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingForecast) {
            CashFlowForecastView()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view detailed cash flow forecast")
        .accessibilityAddTraits(.isButton)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.mint)
                    .accessibilityHidden(true)

                Text("Cash Flow Forecast")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if let forecast = forecastService.currentForecast, forecast.hasDangerZones {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .accessibilityLabel("Low balance warning")
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            if let forecast = forecastService.currentForecast, !forecast.dailyBalances.isEmpty {
                // Mini sparkline chart
                Chart(forecast.dailyBalances) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.projectedBalance)
                    )
                    .foregroundStyle(
                        point.projectedBalance >= 0 ? Color.brandPrimary : Color.red
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 50)
                .accessibilityHidden(true)

                // Current → Projected
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Now")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(forecast.startingBalance, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }

                    Spacer()

                    Image(systemName: forecast.isTrendingUp ? "arrow.right" : "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(forecast.horizon.fullDisplayName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(forecast.projectedEndBalance, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(
                                forecast.projectedEndBalance >= 0 ? .primary : .red
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            } else if forecastService.isForecasting {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Generating forecast...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 50)
            } else {
                Text("Add recurring bills to see your projected cash flow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 50)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(16)
        .floCardShadow()
    }

    private var accessibilityLabel: String {
        guard let forecast = forecastService.currentForecast else {
            return "Cash Flow Forecast. No data available."
        }
        let trend = forecast.isTrendingUp ? "increasing" : "decreasing"
        let warning = forecast.hasDangerZones ? " Low balance warning detected." : ""
        return "Cash Flow Forecast. Balance \(trend) from \(forecast.formattedStartingBalance) to \(forecast.formattedEndBalance) over \(forecast.horizon.fullDisplayName).\(warning)"
    }
}
