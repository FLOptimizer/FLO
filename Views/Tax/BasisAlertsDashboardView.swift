//  BasisAlertsDashboardView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Real-time partner basis alerts dashboard
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shows partner basis snapshots and alerts across all partnerships.
//  Highlights suspended losses, zero-basis warnings, and recovered basis.
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct BasisAlertsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<BusinessProfile> { $0.isActive },
        sort: \BusinessProfile.sortOrder
    )
    private var businesses: [BusinessProfile]

    @Query private var allTransactions: [Transaction]

    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var snapshots: [PartnerBasisSnapshot] = []
    @State private var viewAppeared = false

    private var hasProAccess: Bool {
        subscriptionManager.currentTier == .pro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                yearPicker

                if snapshots.isEmpty {
                    emptyState
                } else {
                    alertSummaryCard
                    partnershipSections
                }
            }
            .padding()
        }
        .navigationTitle("Basis Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            refreshSnapshots()
            withAnimation(.easeOut(duration: 0.3)) { viewAppeared = true }
        }
        .onChange(of: selectedYear) { _, _ in refreshSnapshots() }
    }

    // MARK: - Header

    private var headerCard: some View {
        ProfileHeaderCard(
            icon: "exclamationmark.triangle.fill",
            title: "Partner Basis Monitor",
            subtitle: "Real-time §704(d) basis tracking across partnerships",
            color: .orange
        )
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Picker("Tax Year", selection: $selectedYear) {
            ForEach((currentYear - 3)...currentYear, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Partnerships", systemImage: "person.2.slash")
        } description: {
            Text("Basis tracking is available for businesses with partner allocations configured.")
        }
    }

    // MARK: - Alert Summary

    private var alertSummaryCard: some View {
        let totalAlerts = snapshots.reduce(0) { $0 + $1.alerts.count }
        let criticalCount = snapshots.reduce(0) { $0 + $1.criticalCount }
        let warningCount = snapshots.reduce(0) { $0 + $1.alerts.filter { $0.severity == .warning }.count }

        return GroupBox {
            HStack(spacing: 20) {
                alertPill(count: criticalCount, label: "Critical", color: .red)
                alertPill(count: warningCount, label: "Warning", color: .orange)
                alertPill(count: totalAlerts - criticalCount - warningCount, label: "Info", color: .blue)
            }
            .frame(maxWidth: .infinity)
        } label: {
            Label("Alert Summary", systemImage: "bell.badge.fill")
                .font(.headline)
        }
    }

    private func alertPill(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2.bold())
                .foregroundStyle(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Partnership Sections

    private var partnershipSections: some View {
        ForEach(snapshots) { snapshot in
            partnershipCard(snapshot)
        }
    }

    private func partnershipCard(_ snapshot: PartnerBasisSnapshot) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Alerts
                ForEach(snapshot.alerts) { alert in
                    alertRow(alert)
                }

                if snapshot.alerts.isEmpty {
                    Label("No alerts — all partners have adequate basis",
                          systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }

                Divider()

                // Partner details
                ForEach(snapshot.partnerSnapshots) { partner in
                    partnerRow(partner)
                }
            }
        } label: {
            HStack {
                Label(snapshot.business.businessName, systemImage: "building.2.fill")
                    .font(.headline)
                Spacer()
                if snapshot.criticalCount > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func alertRow(_ alert: BasisAlert) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: alert.severity.icon)
                .foregroundStyle(alertColor(alert.severity))
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.partnerName)
                    .font(.subheadline.bold())
                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(alert.recommendation)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
        .padding(.vertical, 2)
    }

    private func partnerRow(_ partner: SinglePartnerBasis) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(partner.partner.partnerName)
                    .font(.subheadline.bold())
                Text("\(Int(partner.partner.ownershipPercentage * 100))% ownership")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let formatted = NumberFormatter.appCurrency.string(from: NSNumber(value: partner.outsideBasis)) ?? "$0"
                Text(formatted)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(partner.outsideBasis <= 0 ? .red : .primary)

                if partner.basisUtilization > 0 {
                    basisBar(utilization: partner.basisUtilization)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func basisBar(utilization: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(utilization > 0.8 ? Color.red : Color.orange)
                    .frame(width: geo.size.width * utilization)
            }
        }
        .frame(width: 60, height: 4)
    }

    // MARK: - Helpers

    private func alertColor(_ severity: BasisAlert.AlertSeverity) -> Color {
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private func refreshSnapshots() {
        snapshots = BasisTrackingService.shared.generateSnapshots(
            businesses: businesses,
            transactions: allTransactions,
            taxYear: selectedYear
        )
    }
}
