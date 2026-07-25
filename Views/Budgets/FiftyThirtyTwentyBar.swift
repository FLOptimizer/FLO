//  FiftyThirtyTwentyBar.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Color-coded 50/30/20 summary bar for the budget list
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shows how classified budgets (need/want/savings) track against the
//  50/30/20 rule for the month. Green = healthy, teal = right on track,
//  red = off the rule (over on needs/wants, under on savings).
//

import SwiftUI
import FLODesignSystem

struct FiftyThirtyTwentyBar: View {
    let summaries: [PurposeBucketSummary]
    let incomeBasis: MonthlyIncomeBasis

    /// Bars are scaled so the target sits at 80% of the track width,
    /// leaving headroom to visualize overshoot before capping.
    private let targetPosition: CGFloat = 0.8

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if incomeBasis.amount > 0 {
                ForEach(summaries) { summary in
                    bucketRow(summary)
                }
            } else {
                Text("Add income transactions to see how your budgets track against the 50/30/20 rule.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }

            if incomeBasis.usedPreviousMonth {
                Text("Based on last month's income — no income recorded yet this month.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isSummaryElement)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "chart.bar.xaxis")
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)

            Text("50/30/20 Check")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            Text("of \(incomeBasis.amount.formatted(.currency(code: "USD"))) income")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    // MARK: - Bucket Row

    private func bucketRow(_ summary: PurposeBucketSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: summary.purpose.systemImageName)
                    .font(.caption)
                    .foregroundStyle(color(for: summary))
                    .frame(width: 16)
                    .accessibilityHidden(true)

                Text(summary.purpose.displayName + "s")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer()

                Text("\(Int((summary.share * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(color(for: summary))

                Text("/ \(Int(summary.targetShare * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(statusLabel(summary))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color(for: summary))
                    .clipShape(Capsule())
            }

            track(for: summary)
        }
    }

    /// Progress track with a tick mark at the 50/30/20 target.
    private func track(for summary: PurposeBucketSummary) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillFraction = min(
                CGFloat(summary.share / summary.targetShare) * targetPosition,
                1.0
            )

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.1))
                    .frame(height: 6)

                Capsule()
                    .fill(color(for: summary))
                    .frame(width: max(width * fillFraction, summary.share > 0 ? 6 : 0), height: 6)

                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1.5, height: 10)
                    .offset(x: width * targetPosition)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func color(for summary: PurposeBucketSummary) -> Color {
        switch summary.status {
        case .onTrack:
            return FLOSemanticColors.tealDark
        case .under, .over:
            return summary.isHealthy ? FLOSemanticColors.success : FLOSemanticColors.error
        }
    }

    private func statusLabel(_ summary: PurposeBucketSummary) -> String {
        switch summary.status {
        case .under:   return "Under"
        case .onTrack: return "On track"
        case .over:    return "Over"
        }
    }

    private var accessibilitySummary: String {
        guard incomeBasis.amount > 0 else {
            return "50/30/20 check. Add income transactions to see how your budgets track against the rule."
        }
        let rows = summaries.map { summary in
            "\(summary.purpose.displayName)s at \(Int((summary.share * 100).rounded())) percent of income, target \(Int(summary.targetShare * 100)) percent, \(statusLabel(summary))"
        }
        let basis = incomeBasis.usedPreviousMonth ? " Based on last month's income." : ""
        return "50/30/20 check. " + rows.joined(separator: ". ") + "." + basis
    }
}

// MARK: - Preview

#Preview("50/30/20 Bar") {
    VStack(spacing: 16) {
        FiftyThirtyTwentyBar(
            summaries: [
                PurposeBucketSummary(purpose: .need, spent: 2_600, share: 0.52, status: .onTrack),
                PurposeBucketSummary(purpose: .want, spent: 1_900, share: 0.38, status: .over),
                PurposeBucketSummary(purpose: .savings, spent: 500, share: 0.10, status: .under)
            ],
            incomeBasis: MonthlyIncomeBasis(amount: 5_000, usedPreviousMonth: false)
        )

        FiftyThirtyTwentyBar(
            summaries: [],
            incomeBasis: MonthlyIncomeBasis(amount: 0, usedPreviousMonth: false)
        )
    }
    .padding()
}
