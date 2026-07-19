//  ReportsSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v1.0 — Zone 3 default summary for the Reports tab.
//  A report launcher: each row navigates the detail pane to a specific
//  report (P&L, Cash Flow Forecast, Tax Summary, Year-End Checklist) so the
//  iPad/macOS right pane is populated by default instead of falling through
//  to GenericSummaryPanel.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import FLODesignSystem

struct ReportsSummaryPanel: View {

    private struct ReportLink: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let destination: NavigationDestination
    }

    private var reports: [ReportLink] {
        [
            ReportLink(
                title: "Profit & Loss",
                subtitle: "Income, expenses, and net by category",
                icon: "chart.bar.doc.horizontal",
                tint: .brandPrimary,
                destination: .taxBusinessSummary
            ),
            ReportLink(
                title: "Cash Flow Forecast",
                subtitle: "Project upcoming balance and runway",
                icon: "chart.line.uptrend.xyaxis",
                tint: .incomeGreen,
                destination: .cashFlowForecast
            ),
            ReportLink(
                title: "Tax Summary",
                subtitle: "Deductions and estimated tax overview",
                icon: "building.columns.fill",
                tint: .brandWarning,
                destination: .taxBusinessSummary
            ),
            ReportLink(
                title: "Year-End Checklist",
                subtitle: "Close the books for filing season",
                icon: "checklist",
                tint: .expenseRed,
                destination: .yearEndChecklist
            ),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Reports & Exports")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose a report to view it here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(reports) { report in
                    Button {
                        NavigationService.shared.selectedDetail = report.destination
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: report.icon)
                                .font(.title3)
                                .foregroundStyle(report.tint)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(report.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(report.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.floSystemGroupedSectionBackground)
                        .cornerRadius(12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Reports")
    }
}
