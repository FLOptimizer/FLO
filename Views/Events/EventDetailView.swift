//  EventDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Event summary: total, category breakdown, monthly impact
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let event: SpendingEvent

    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var showingEditEvent = false

    // MARK: - Derived data

    private var eventTransactions: [Transaction] {
        (event.transactions ?? []).sorted { $0.date > $1.date }
    }

    /// Unassigned transactions inside the event's date range — offered for
    /// one-tap retroactive assignment
    private var suggestedTransactions: [Transaction] {
        allTransactions.filter { $0.event == nil && event.contains($0.date) && !$0.isTransfer }
    }

    /// Total expenses in the calendar month containing the event's start
    private var monthTotal: Double {
        let calendar = Calendar.current
        return allTransactions
            .filter {
                !$0.isIncome && !$0.isTransfer &&
                calendar.isDate($0.date, equalTo: event.startDate, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthName: String {
        event.startDate.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        List {
            // Hero summary
            Section {
                VStack(spacing: 8) {
                    Image(systemName: event.icon)
                        .font(.largeTitle)
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)
                    Text(event.totalSpent, format: .currency(code: "USD"))
                        .font(.system(size: 36, weight: .heavy).monospacedDigit())
                    Text("\(event.dateRangeDisplay) · \(event.durationDays) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if event.durationDays > 1 && event.totalSpent > 0 {
                        Text("\((event.totalSpent / Double(event.durationDays)), format: .currency(code: "USD")) per day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }

            // Category breakdown — "how much was gas, food, fees"
            if !event.categoryBreakdown.isEmpty {
                Section("By Category") {
                    ForEach(event.categoryBreakdown, id: \.name) { entry in
                        HStack {
                            Image(systemName: entry.icon)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text(entry.name)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(entry.total, format: .currency(code: "USD"))
                                    .font(.subheadline.weight(.semibold))
                                if event.totalSpent > 0 {
                                    Text("\(Int((entry.total / event.totalSpent) * 100))%")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            // Monthly impact — "the trip explains the spike"
            if monthTotal > 0 && event.totalSpent > 0 {
                Section("Impact on \(monthName)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(monthName) spending")
                            Spacer()
                            Text(monthTotal, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("\(event.name)")
                                .foregroundStyle(Color.brandPrimary)
                            Spacer()
                            Text(min(event.totalSpent, monthTotal), format: .currency(code: "USD"))
                                .foregroundStyle(Color.brandPrimary)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Without the event")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(max(monthTotal - event.totalSpent, 0), format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                        if monthTotal > 0 {
                            GeometryReader { geo in
                                HStack(spacing: 2) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.brandPrimary)
                                        .frame(width: geo.size.width * min(event.totalSpent / monthTotal, 1))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.gray.opacity(0.25))
                                }
                            }
                            .frame(height: 8)
                            .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(monthName) spending \(AccessibilityFormatters.spokenCurrency(monthTotal)), of which \(AccessibilityFormatters.spokenCurrency(event.totalSpent)) was \(event.name)")
                }
            }

            // Retroactive assignment
            if !suggestedTransactions.isEmpty {
                Section {
                    Button {
                        assignSuggested()
                    } label: {
                        Label(
                            "Add \(suggestedTransactions.count) unassigned transaction\(suggestedTransactions.count == 1 ? "" : "s") from these dates",
                            systemImage: "plus.circle"
                        )
                    }
                } footer: {
                    Text("Transactions dated \(event.dateRangeDisplay) that aren't part of any event yet.")
                }
            }

            // Transactions in the event
            if !eventTransactions.isEmpty {
                Section("Transactions") {
                    ForEach(eventTransactions) { tx in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tx.displayName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("\(tx.date.formatted(date: .abbreviated, time: .omitted)) · \(tx.category?.name ?? "Uncategorized")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            Spacer()
                            Text(tx.amount, format: .currency(code: "USD"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(tx.isIncome ? Color.green : Color.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                removeFromEvent(tx)
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                            .tint(.orange)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    HapticService.play(.light)
                    showingEditEvent = true
                }
            }
        }
        .sheet(isPresented: $showingEditEvent) {
            EventFormView(event: event)
        }
    }

    // MARK: - Actions

    private func assignSuggested() {
        HapticService.play(.medium)
        let toAssign = suggestedTransactions
        for tx in toAssign {
            tx.event = event
        }
        do {
            try modelContext.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Added \(toAssign.count) transactions to \(event.name)")
        } catch {
            HapticService.play(.error)
            print("Failed to assign transactions to event: \(error)")
        }
    }

    private func removeFromEvent(_ tx: Transaction) {
        HapticService.play(.light)
        tx.event = nil
        try? modelContext.save()
    }
}
