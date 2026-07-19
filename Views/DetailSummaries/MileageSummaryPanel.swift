//  MileageSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v1.0 — Zone 3 default summary for the Mileage tab.
//  Shows year-to-date business miles and deduction, a needs-review alert,
//  and recent trips as tappable rows that navigate to trip detail.
//  Mirrors AccountSummaryPanel so the iPad/macOS right pane is populated by
//  default instead of falling through to GenericSummaryPanel.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct MileageSummaryPanel: View {
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var trips: [MileageTrip]

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed Data

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var thisYearTrips: [MileageTrip] {
        trips.filter { $0.tripYear == currentYear }
    }

    private var businessMilesYTD: Double {
        thisYearTrips.filter { $0.isBusinessTrip }.reduce(0) { $0 + $1.distanceMiles }
    }

    private var deductionYTD: Double {
        thisYearTrips.filter { $0.isBusinessTrip }.reduce(0) { $0 + $1.deductionAmount }
    }

    private var needsReviewTrips: [MileageTrip] {
        trips.filter { $0.needsClassification }
    }

    private var recentTrips: [MileageTrip] {
        Array(trips.prefix(8))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if trips.isEmpty {
                    emptyState
                } else {
                    overviewSection

                    if !needsReviewTrips.isEmpty {
                        Button {
                            if let first = needsReviewTrips.first {
                                NavigationService.shared.selectedDetail = .mileageTripDetail(id: first.id)
                            }
                        } label: {
                            SummaryChip(
                                icon: "exclamationmark.triangle.fill",
                                text: "\(needsReviewTrips.count) trip\(needsReviewTrips.count == 1 ? "" : "s") need review",
                                style: .warning
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    tripListSection
                }
            }
            .padding()
        }
        .navigationTitle("Mileage Overview")
    }

    // MARK: - Overview

    private var overviewSection: some View {
        HStack(spacing: 10) {
            metricBox(
                label: "Business Miles (\(String(currentYear)))",
                value: String(format: "%.1f", businessMilesYTD),
                color: .brandPrimary
            )
            metricBox(
                label: "Deduction",
                value: fmt.string(from: NSNumber(value: deductionYTD)) ?? "$0",
                color: .incomeGreen
            )
        }
    }

    private func metricBox(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Trip List

    private var tripListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Trips")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)

            ForEach(recentTrips) { trip in
                Button {
                    NavigationService.shared.selectedDetail = .mileageTripDetail(id: trip.id)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: trip.purpose.icon)
                            .font(.subheadline)
                            .foregroundStyle(trip.needsClassification ? Color.brandWarning : Color.brandPrimary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.purpose.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text(trip.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.1f mi", trip.distanceMiles))
                                .font(.subheadline.monospacedDigit().weight(.semibold))
                                .lineLimit(1)
                            if trip.needsClassification {
                                Text("NEEDS REVIEW")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.brandWarning)
                            } else if trip.isBusinessTrip {
                                Text(fmt.string(from: NSNumber(value: trip.deductionAmount)) ?? "$0")
                                    .font(.caption)
                                    .foregroundStyle(Color.incomeGreen)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.floSystemGroupedSectionBackground)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "car")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No trips yet")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Text("Logged trips and their deductions will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
