//  ReceiptsListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Build 10 (iPad §1 fix)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Zone 2 list scaffold for the Receipts tab. Previously the Receipts sidebar
//  item routed straight into SmartReceiptScanningView — the full-screen scanner
//  (own NavigationStack + Cancel button) — which on iPad looked like a modal
//  hijacking the middle column. This view shows stored receipts (or an empty
//  state with a Scan CTA) and presents the Scanner only when the user taps a
//  Scan action. On regular width, tapping a matched receipt routes the Zone 3
//  detail pane to its linked transaction.

import SwiftUI
import SwiftData
import FLODesignSystem

struct ReceiptsListView: View {
    @Environment(\.modelContext) private var modelContext
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @Query(sort: \ReceiptData.date, order: .reverse) private var receipts: [ReceiptData]

    @State private var showingScanner = false
    @State private var showingMatchingQueue = false

    private let fmt = NumberFormatter.appCurrency

    private var routesToDetailPane: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    private var unmatchedCount: Int {
        receipts.filter { $0.matchStatus == .unmatched }.count
    }

    private var deductibleCount: Int {
        receipts.filter { $0.isTaxDeductible }.count
    }

    var body: some View {
        List {
            if receipts.isEmpty {
                emptyStateSection
            } else {
                summarySection
                if unmatchedCount > 0 {
                    matchingQueueSection
                }
                receiptsSection
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Receipts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HapticService.play(.medium)
                    showingScanner = true
                } label: {
                    Label("Scan", systemImage: "doc.text.viewfinder")
                }
                .accessibilityLabel("Scan a receipt")
            }
        }
        .sheet(isPresented: $showingScanner) {
            SmartReceiptScanningView()
        }
        .sheet(isPresented: $showingMatchingQueue) {
            NavigationStack {
                ReceiptMatchingQueueView()
            }
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section {
            HStack(spacing: 10) {
                statBox(value: "\(receipts.count)", label: "Receipts", color: .brandPrimary)
                statBox(value: "\(unmatchedCount)", label: "Unmatched", color: unmatchedCount > 0 ? .brandWarning : .incomeGreen)
                statBox(value: "\(deductibleCount)", label: "Deductible", color: .incomeGreen)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
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
        .background(Color.floSecondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Matching Queue Shortcut

    private var matchingQueueSection: some View {
        Section {
            Button {
                HapticService.play(.light)
                showingMatchingQueue = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.person.crop")
                        .font(.title3)
                        .foregroundStyle(Color.brandWarning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review Matches")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("\(unmatchedCount) receipt\(unmatchedCount == 1 ? "" : "s") waiting to match")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Receipts List

    private var receiptsSection: some View {
        Section("All Receipts") {
            ForEach(receipts) { receipt in
                Button {
                    handleTap(receipt)
                } label: {
                    receiptRow(receipt)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func receiptRow(_ receipt: ReceiptData) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brandPrimary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "doc.text.image")
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.merchantName.isEmpty ? "Receipt" : receipt.merchantName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 6) {
                    Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("·")
                    Text(receipt.matchStatus.displayName)
                        .foregroundStyle(receipt.matchStatus == .unmatched ? Color.brandWarning : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(fmt.string(from: NSNumber(value: receipt.totalAmount)) ?? "$0")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if routesToDetailPane && receipt.transactionID != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(receipt.merchantName.isEmpty ? "Receipt" : receipt.merchantName), \(fmt.string(from: NSNumber(value: receipt.totalAmount)) ?? "$0"), \(receipt.matchStatus.displayName)")
    }

    private func handleTap(_ receipt: ReceiptData) {
        HapticService.play(.light)
        // Matched receipts open their linked transaction in the detail pane.
        if routesToDetailPane, let txID = receipt.transactionID {
            NavigationService.shared.requestDetailNavigation(to: .transactionDetail(id: txID))
        } else if receipt.matchStatus == .unmatched {
            // Unmatched: send the user to the matching queue.
            showingMatchingQueue = true
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(Color.brandPrimary.opacity(0.7))

                Text("No Receipts Yet")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text("Scan a receipt to capture the merchant, amount, and tax category, then match it to a transaction automatically.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)

                Button {
                    HapticService.play(.medium)
                    showingScanner = true
                } label: {
                    Label("Scan Your First Receipt", systemImage: "doc.text.viewfinder")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandPrimary)
                .accessibilityHint("Opens the receipt scanner")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .listRowBackground(Color.clear)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ReceiptsListView()
    }
    .modelContainer(for: [ReceiptData.self, Transaction.self], inMemory: true)
    .environmentObject(SubscriptionManager.shared)
}
#endif
