//  ReconcileAccountView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Account reconciliation UI.
//  Allows users to set actual bank balance, creating a BalanceAnchor that
//  protects today's balance from historical transaction edits.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData

struct ReconcileAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: Account

    // MARK: - State

    @State private var actualBalance: Double = 0
    @State private var anchorDate = Date()
    @State private var notes = ""
    @State private var anchors: [BalanceAnchor] = []
    @State private var showDeleteConfirmation = false
    @State private var anchorToDelete: BalanceAnchor?
    @State private var startingBalance: Double = 0
    @State private var showStartingBalanceSaved = false

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed

    private var calculatedBalance: Double {
        AccountBalanceService.shared.calculateBalance(for: account, anchors: anchors)
    }

    private var discrepancy: Double {
        account.currentBalance - calculatedBalance
    }

    private var isReconciled: Bool {
        abs(discrepancy) < 0.01
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Section 1: Balance Comparison
                balanceComparisonSection

                // Section 2: Set Actual Balance
                setBalanceSection

                // Section 3: Starting Balance
                startingBalanceSection

                // Section 4: Anchor History
                anchorHistorySection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Reconcile Account")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                loadAnchors()
                // Pre-populate with current balance (absolute for liabilities)
                actualBalance = abs(account.currentBalance)
                startingBalance = abs(account.startingBalance)
            }
            .alert("Delete Anchor?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let anchor = anchorToDelete {
                        deleteAnchor(anchor)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove this balance checkpoint. Your balance may change.")
            }
        }
    }

    // MARK: - Section 1: Balance Comparison

    private var balanceComparisonSection: some View {
        Section {
            HStack {
                Text("Stored Balance")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(from: NSNumber(value: account.currentBalance)) ?? "$0")
                    .font(.body.monospacedDigit().weight(.medium))
            }

            HStack {
                Text("Calculated Balance")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(fmt.string(from: NSNumber(value: calculatedBalance)) ?? "$0")
                    .font(.body.monospacedDigit().weight(.medium))
            }

            HStack {
                Text("Discrepancy")
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    if isReconciled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Matched")
                            .foregroundStyle(.green)
                            .font(.body.weight(.medium))
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(fmt.string(from: NSNumber(value: discrepancy)) ?? "$0")
                            .foregroundStyle(.orange)
                            .font(.body.monospacedDigit().weight(.medium))
                    }
                }
            }
        } header: {
            Text("Balance Status")
        } footer: {
            if !isReconciled {
                Text("Your stored balance differs from the calculated balance (starting balance + transactions). Use \"Set Actual Balance\" below to correct it.")
            }
        }
    }

    // MARK: - Section 2: Set Actual Balance

    private var setBalanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("What does your bank show right now?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CurrencyInputField(
                    amount: $actualBalance,
                    accessibilityLabelText: "Actual bank balance"
                )
            }

            DatePicker("As of", selection: $anchorDate, displayedComponents: .date)

            TextField("Notes (optional)", text: $notes, prompt: Text("e.g., Matched Chase statement"))

            Button {
                reconcileBalance()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Set Balance")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brandPrimary)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        } header: {
            Text("Set Actual Balance")
        } footer: {
            Text("This creates a balance checkpoint. Transactions before this date won't affect your current balance, protecting it from historical edits.")
        }
    }

    // MARK: - Section 3: Starting Balance

    private var startingBalanceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Account Created")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(DateFormatter.mediumDate.string(from: account.createdDate))
                        .foregroundStyle(.secondary)
                }

                Text("Starting Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CurrencyInputField(
                    amount: $startingBalance,
                    accessibilityLabelText: "Starting balance"
                )

                Button {
                    updateStartingBalance()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                        Text(showStartingBalanceSaved ? "Saved!" : "Update Starting Balance")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(Color.brandPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.plain)
                .disabled(abs(startingBalance - abs(account.startingBalance)) < 0.01)
            }
        } header: {
            Text("Starting Balance")
        } footer: {
            Text("The balance when you first added this account to FLO. Changing this adjusts the baseline for all balance calculations.")
        }
    }

    // MARK: - Section 4: Anchor History

    private var anchorHistorySection: some View {
        Section {
            if anchors.isEmpty {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                    Text("No balance checkpoints yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(anchors, id: \.id) { anchor in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fmt.string(from: NSNumber(value: anchor.anchorBalance)) ?? "$0")
                                .font(.body.monospacedDigit().weight(.medium))
                            Text(DateFormatter.mediumDate.string(from: anchor.anchorDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !anchor.notes.isEmpty {
                                Text(anchor.notes)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text(anchor.source.displayName)
                                .font(.caption)
                                .foregroundStyle(Color.brandPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.brandPrimary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if anchor.source != .accountCreation {
                            Button(role: .destructive) {
                                anchorToDelete = anchor
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        } header: {
            Text("Balance History (\(anchors.count))")
        } footer: {
            Text("Each checkpoint locks the balance at a specific date. Only the most recent checkpoint is used for balance calculations.")
        }
    }

    // MARK: - Actions

    private func reconcileBalance() {
        var balance = actualBalance
        // Auto-negate for liabilities
        if !account.accountType.isAsset && balance > 0 {
            balance = -balance
        }

        // Create anchor via ReconciliationService
        let anchor = BalanceAnchor(
            account: account,
            anchorDate: anchorDate,
            anchorBalance: balance,
            source: .manualReconciliation,
            notes: notes.isEmpty ? "Manual reconciliation" : notes
        )
        modelContext.insert(anchor)

        // Update stored balance
        account.currentBalance = balance
        account.lastBalanceUpdate = Date()
        account.touch()

        try? modelContext.save()

        HapticService.play(.success)
        loadAnchors()

        // Reset form
        notes = ""
    }

    private func updateStartingBalance() {
        var balance = startingBalance
        if !account.accountType.isAsset && balance > 0 {
            balance = -balance
        }

        account.startingBalance = balance
        account.touch()

        // Update or create the account creation anchor
        if let creationAnchor = anchors.first(where: { $0.source == .accountCreation }) {
            creationAnchor.anchorBalance = balance
        } else {
            let anchor = BalanceAnchor(
                account: account,
                anchorDate: account.createdDate,
                anchorBalance: balance,
                source: .accountCreation,
                notes: "Starting balance updated"
            )
            modelContext.insert(anchor)
        }

        try? modelContext.save()

        HapticService.play(.success)
        showStartingBalanceSaved = true
        loadAnchors()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showStartingBalanceSaved = false
        }
    }

    private func deleteAnchor(_ anchor: BalanceAnchor) {
        modelContext.delete(anchor)
        try? modelContext.save()
        HapticService.play(.medium)
        loadAnchors()
    }

    private func loadAnchors() {
        anchors = ReconciliationService.shared.fetchAnchors(for: account, context: modelContext)
    }
}

// MARK: - AnchorSource Display Name

extension BalanceAnchor.AnchorSource {
    var displayName: String {
        switch self {
        case .accountCreation: return "Created"
        case .manualReconciliation: return "Reconciled"
        case .csvStatementBalance: return "CSV Import"
        case .csvImportKeepBalance: return "CSV Keep"
        case .plaidSync: return "Bank Sync"
        }
    }
}
