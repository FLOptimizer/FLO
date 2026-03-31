//  MenuBarWidgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — macOS menu bar quick-glance widget.
//  Shows today's summary: net cash flow, pending invoices, budget status.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

#if os(macOS)
import SwiftUI
import SwiftData

struct MenuBarWidgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var recentTransactions: [Transaction]
    @Query private var allInvoices: [Invoice]

    private var outstandingInvoices: [Invoice] {
        allInvoices.filter { $0.status == .sent || $0.status == .overdue }
    }

    private var todaySpend: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return recentTransactions
            .filter { calendar.isDate($0.date, inSameDayAs: today) && !$0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }

    private var todayIncome: Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return recentTransactions
            .filter { calendar.isDate($0.date, inSameDayAs: today) && $0.isIncome }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            Divider()
            cashFlowSection
            invoiceSection
            Divider()
            actionsSection
        }
        .padding()
        .frame(width: 280)
    }

    private var headerSection: some View {
        HStack {
            Text("FLO")
                .font(.headline)
            Spacer()
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cashFlowSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Income")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(todayIncome, format: .currency(code: "USD"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.green)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Spent")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(todaySpend, format: .currency(code: "USD"))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var invoiceSection: some View {
        if !outstandingInvoices.isEmpty {
            Divider()
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(.orange)
                Text("\(outstandingInvoices.count) outstanding invoice\(outstandingInvoices.count == 1 ? "" : "s")")
                    .font(.caption)
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Add Transaction") {
                NavigationService.shared.showAddTransaction()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)

            Button("Open FLO") {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("o", modifiers: .command)
        }
    }
}

#Preview("Menu Bar Widget") {
    MenuBarWidgetView()
        .modelContainer(for: [Transaction.self, Invoice.self])
}
#endif
