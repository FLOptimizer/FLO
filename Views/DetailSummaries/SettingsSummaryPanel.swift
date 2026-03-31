//  SettingsSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 contextual summary for the Settings tab.
//  App health dashboard: storage, sync status, subscription tier,
//  quick stats, and actionable recommendations.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData

struct SettingsSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var transactionCount: Int = 0
    @State private var accountCount: Int = 0
    @State private var categoryCount: Int = 0
    @State private var invoiceCount: Int = 0
    @State private var clientCount: Int = 0
    @State private var tripCount: Int = 0

    private var hasPasscode: Bool {
        BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundStyle(Color.brandPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Overview")
                            .font(.title3.weight(.semibold))
                        Text("FLO \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Subscription Card
                subscriptionCard

                // Quick Stats Grid
                statsGrid

                // App Health
                healthChecks

                // Recommendations
                if !recommendations.isEmpty {
                    recommendationsCard
                }
            }
            .padding()
        }
        .task { loadStats() }
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(Color.brandWarning)
                Text("Subscription")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                Text(subscriptionManager.currentTier.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.brandPrimary)
                Spacer()
                Text(subscriptionManager.currentTier == .free ? "Upgrade Available" : "Active")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(subscriptionManager.currentTier == .free ? Color.brandWarning : Color.incomeGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        (subscriptionManager.currentTier == .free ? Color.brandWarning : Color.incomeGreen).opacity(0.12)
                    )
                    .clipShape(Capsule())
            }

            // Feature highlights for current tier
            HStack(spacing: 16) {
                tierFeature(icon: "infinity", label: "Accounts", available: true)
                tierFeature(icon: "doc.text.viewfinder", label: "Smart Scan", available: subscriptionManager.currentTier.hasSmartReceiptScanning)
                tierFeature(icon: "person.2", label: "Clients", available: subscriptionManager.currentTier.hasInvoicing)
                tierFeature(icon: "chart.bar", label: "Reports", available: subscriptionManager.currentTier.hasProfitLossReports)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
    }

    private func tierFeature(icon: String, label: String, available: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(available ? Color.brandPrimary : Color.secondary.opacity(0.4))
            Text(label)
                .font(.caption2)
                .foregroundStyle(available ? Color.secondary : Color.secondary.opacity(0.4))
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption2)
                .foregroundStyle(available ? Color.incomeGreen : Color.secondary.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Data")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCell(count: transactionCount, label: "Transactions", icon: "arrow.left.arrow.right")
                statCell(count: accountCount, label: "Accounts", icon: "building.columns")
                statCell(count: categoryCount, label: "Categories", icon: "folder")
                statCell(count: invoiceCount, label: "Invoices", icon: "doc.text")
                statCell(count: clientCount, label: "Clients", icon: "person.2")
                statCell(count: tripCount, label: "Trips", icon: "car")
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
    }

    private func statCell(count: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.brandPrimary)
            Text("\(count)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Health Checks

    private var healthChecks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Health")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            healthRow(
                icon: "lock.shield.fill",
                label: "Security",
                status: hasPasscode ? "Protected" : "Not configured",
                isGood: hasPasscode
            )

            healthRow(
                icon: "icloud.fill",
                label: "iCloud Sync",
                status: "Enabled",
                isGood: true
            )

            healthRow(
                icon: "internaldrive",
                label: "Data",
                status: "\(transactionCount) records",
                isGood: true
            )
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
    }

    private func healthRow(icon: String, label: String, status: String, isGood: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(isGood ? Color.incomeGreen : Color.brandWarning)
                    .frame(width: 6, height: 6)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Recommendations

    private var recommendations: [(icon: String, text: String, style: SummaryChip.ChipStyle)] {
        var items: [(String, String, SummaryChip.ChipStyle)] = []

        if !hasPasscode {
            items.append(("lock.open", "Set up a passcode or biometrics", .warning))
        }

        if categoryCount < 3 {
            items.append(("folder.badge.plus", "Add more categories to organize spending", .info))
        }

        if accountCount == 0 {
            items.append(("building.columns", "Add an account to start tracking", .urgent))
        }

        if transactionCount == 0 {
            items.append(("plus.circle", "Add your first transaction", .info))
        }

        return items
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(recommendations, id: \.text) { item in
                SummaryChip(icon: item.icon, text: item.text, style: item.style)
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
    }

    // MARK: - Data Loading

    private func loadStats() {
        do {
            let txDesc = FetchDescriptor<Transaction>()
            transactionCount = try modelContext.fetchCount(txDesc)

            let acctDesc = FetchDescriptor<Account>()
            accountCount = try modelContext.fetchCount(acctDesc)

            let catDesc = FetchDescriptor<Category>()
            categoryCount = try modelContext.fetchCount(catDesc)

            let invDesc = FetchDescriptor<Invoice>()
            invoiceCount = try modelContext.fetchCount(invDesc)

            let clientDesc = FetchDescriptor<Client>()
            clientCount = try modelContext.fetchCount(clientDesc)

            let tripDesc = FetchDescriptor<MileageTrip>()
            tripCount = try modelContext.fetchCount(tripDesc)
        } catch {
            #if DEBUG
            print("SettingsSummaryPanel: Failed to load stats: \(error)")
            #endif
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
