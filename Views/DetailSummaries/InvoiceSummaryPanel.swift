//  InvoiceSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 contextual summary for the Invoices tab.
//  Shows total receivable hero metric, aging bucket bar chart,
//  overdue count chip, and payment status breakdown.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import Charts

struct InvoiceSummaryPanel: View {
    @Query private var invoices: [Invoice]

    private var unpaidInvoices: [Invoice] {
        invoices.filter { $0.status != .paid && $0.status != .cancelled }
    }

    private var totalOutstanding: Double {
        unpaidInvoices.reduce(0) { $0 + $1.remainingBalance }
    }

    private var overdueInvoices: [Invoice] {
        let now = Date()
        return unpaidInvoices.filter { $0.dueDate < now }
    }

    private var totalOverdue: Double {
        overdueInvoices.reduce(0) { $0 + $1.remainingBalance }
    }

    private var paidThisMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return invoices
            .filter { $0.status == .paid }
            .filter { invoice in
                guard let paidDate = invoice.payments?.compactMap({ $0.date }).max() else { return false }
                return calendar.isDate(paidDate, equalTo: now, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.subtotal }
    }

    private var agingBuckets: [InvoiceAgingBar] {
        let now = Date()
        var buckets: [String: Double] = [
            "Current": 0,
            "1–30": 0,
            "31–60": 0,
            "61–90": 0,
            "90+": 0
        ]

        for invoice in unpaidInvoices {
            let days = Calendar.current.dateComponents([.day], from: invoice.dueDate, to: now).day ?? 0
            if days <= 0 {
                buckets["Current", default: 0] += invoice.remainingBalance
            } else if days <= 30 {
                buckets["1–30", default: 0] += invoice.remainingBalance
            } else if days <= 60 {
                buckets["31–60", default: 0] += invoice.remainingBalance
            } else if days <= 90 {
                buckets["61–90", default: 0] += invoice.remainingBalance
            } else {
                buckets["90+", default: 0] += invoice.remainingBalance
            }
        }

        let order = ["Current", "1–30", "31–60", "61–90", "90+"]
        let colors: [Color] = [.incomeGreen, .brandPrimary, .brandWarning, .orange, .expenseRed]

        return order.enumerated().map { index, label in
            InvoiceAgingBar(label: label, amount: buckets[label] ?? 0, color: colors[index])
        }
    }

    private var statusCounts: [(status: String, count: Int)] {
        var map: [String: Int] = [:]
        for invoice in invoices {
            let name = invoice.status.rawValue.capitalized
            map[name, default: 0] += 1
        }
        return map.sorted { $0.value > $1.value }
            .map { (status: $0.key, count: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero: Total Outstanding
                SummaryHeroMetric(amount: totalOutstanding, subtitle: "Outstanding Receivables", style: .branded)
                    .floGlassCard()

                // Alert chips
                if !overdueInvoices.isEmpty {
                    SummaryChip(
                        icon: "clock.badge.exclamationmark",
                        text: "\(overdueInvoices.count) overdue (\(formatted(totalOverdue)))",
                        style: .urgent
                    )
                }

                // Aging Bar Chart
                if agingBuckets.contains(where: { $0.amount > 0 }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aging Buckets (Days Past Due)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Chart(agingBuckets) { bucket in
                            BarMark(
                                x: .value("Bucket", bucket.label),
                                y: .value("Amount", bucket.amount)
                            )
                            .foregroundStyle(bucket.color)
                            .cornerRadius(4)
                            .annotation(position: .top) {
                                if bucket.amount > 0 {
                                    Text(formatCompact(bucket.amount))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                                AxisValueLabel {
                                    if let amount = value.as(Double.self) {
                                        Text(formatCompact(amount))
                                            .font(.caption2)
                                    }
                                }
                            }
                        }
                        .frame(height: 180)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Invoice aging chart")
                    }
                    .floGlassCard()
                }

                // Stats row
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("\(invoices.count)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.brandPrimaryText)
                        Text("Total Invoices")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .floGlassCard()

                    VStack(spacing: 4) {
                        Text(paidThisMonth, format: .currency(code: "USD").precision(.fractionLength(0)))
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.incomeGreen)
                        Text("Collected This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .floGlassCard()
                }

                // Status breakdown
                if !statusCounts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Status")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(statusCounts, id: \.status) { item in
                            HStack {
                                Text(item.status)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.subheadline.monospacedDigit().weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .floGlassCard()
                }
            }
            .padding()
        }
        .navigationTitle("Invoice Summary")
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1000 {
            return "$\(String(format: "%.1f", value / 1000))k"
        }
        return "$\(Int(value))"
    }
}

private struct InvoiceAgingBar: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let color: Color
}
