//  AssistantDataPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — Live Zone 3 data panel for My Assistant.
//  Reacts to conversation context, showing relevant data cards + drill-down.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import Charts

struct AssistantDataPanel: View {
    let context: AssistantContext

    private let fmt = NumberFormatter.appCurrency

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if context.dataType == .none {
                    // Show capabilities help when no conversation active
                    AssistantSummaryPanel()
                } else {
                    // Live data header
                    dataHeader

                    // Hero metric
                    heroCard

                    // Secondary metrics
                    if !context.secondaryMetrics.isEmpty {
                        metricsCard
                    }

                    // Category/item breakdown
                    if !context.dataItems.isEmpty {
                        breakdownCard
                    }

                    // Chart visualization
                    if context.dataItems.count >= 2 {
                        chartCard
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Data Header

    private var dataHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: context.dataType.icon)
                .font(.title3)
                .foregroundStyle(Color.brandPrimary)
            Text(context.dataType.title)
                .font(.title3.bold())
            Spacer()
        }
    }

    // MARK: - Hero Metric Card

    private var heroCard: some View {
        VStack(spacing: 6) {
            Text(fmt.string(from: NSNumber(value: context.heroAmount)) ?? "$0")
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundStyle(context.heroAmount >= 0 ? Color.primary : Color.red)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(context.heroLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Secondary Metrics

    private var metricsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(context.secondaryMetrics.enumerated()), id: \.offset) { index, metric in
                HStack {
                    Text(metric.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(metric.value)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < context.secondaryMetrics.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Breakdown Card

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(context.dataType == .accounts ? "Accounts" : "By Category")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(context.dataItems.prefix(15)) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.subheadline)
                            .lineLimit(1)

                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(fmt.string(from: NSNumber(value: item.amount)) ?? "$0")
                            .font(.subheadline.weight(.medium).monospacedDigit())

                        HStack(spacing: 4) {
                            if item.isBusiness {
                                Text("Business")
                                    .font(.caption2)
                                    .foregroundStyle(Color.brandPrimary)
                            }
                            if item.isTaxDeductible {
                                Text("Deductible")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if item.id != context.dataItems.prefix(15).last?.id {
                    Divider().padding(.leading, 16)
                }
            }

            if context.dataItems.count > 15 {
                Text("\(context.dataItems.count - 15) more...")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            Chart(context.dataItems.prefix(8)) { item in
                BarMark(
                    x: .value("Amount", item.amount),
                    y: .value("Category", item.label)
                )
                .foregroundStyle(
                    item.isBusiness
                        ? Color.brandPrimary.gradient
                        : Color.secondary.opacity(0.6).gradient
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(fmt.string(from: NSNumber(value: v)) ?? "")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(height: CGFloat(min(context.dataItems.prefix(8).count, 8)) * 36)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }
}
