//  InvoiceSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v2 — Zone 3 invoice analysis panel.
//  Shows outstanding amount hero metric, overdue invoices highlighted at top,
//  each client with their invoices listed underneath, payment status indicators,
//  and tappable invoices that navigate to InvoiceDetailView.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData
import FLODesignSystem

struct InvoiceSummaryPanel: View {
    @Query private var invoices: [Invoice]

    @State private var expandedClients: Set<String> = []

    private let fmt = NumberFormatter.appCurrency

    // MARK: - Computed Data

    private var activeInvoices: [Invoice] {
        invoices.filter { $0.status != .cancelled }
    }

    private var unpaidInvoices: [Invoice] {
        activeInvoices.filter { !$0.isFinal }
    }

    private var overdueInvoices: [Invoice] {
        activeInvoices.filter { $0.isOverdue }
            .sorted { $0.daysOverdue > $1.daysOverdue }
    }

    private var totalOutstanding: Double {
        unpaidInvoices.reduce(0) { $0 + $1.remainingBalance }
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
                guard let paidDate = (invoice.payments ?? []).compactMap({ $0.date }).max() else { return false }
                return calendar.isDate(paidDate, equalTo: now, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.totalAmount }
    }

    /// Group non-cancelled invoices by client name, sorted by overdue first
    private var clientGroups: [ClientInvoiceGroup] {
        var map: [String: [Invoice]] = [:]
        for invoice in activeInvoices {
            let clientName = invoice.client?.name ?? "No Client"
            map[clientName, default: []].append(invoice)
        }
        return map
            .map { name, invoiceList in
                let sorted = invoiceList.sorted { a, b in
                    if a.isOverdue != b.isOverdue { return a.isOverdue }
                    return a.dueDate < b.dueDate
                }
                let outstanding = sorted.filter { !$0.isFinal }.reduce(0) { $0 + $1.remainingBalance }
                let hasOverdue = sorted.contains { $0.isOverdue }
                return ClientInvoiceGroup(
                    clientName: name,
                    invoices: sorted,
                    outstanding: outstanding,
                    hasOverdue: hasOverdue
                )
            }
            .sorted { a, b in
                if a.hasOverdue != b.hasOverdue { return a.hasOverdue }
                return a.outstanding > b.outstanding
            }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Outstanding hero + collected stat
                outstandingSection

                // Overdue alert
                if !overdueInvoices.isEmpty {
                    SummaryChip(
                        icon: "clock.badge.exclamationmark",
                        text: "\(overdueInvoices.count) overdue — \(fmt.string(from: NSNumber(value: totalOverdue)) ?? "$0") at risk",
                        style: .urgent
                    )
                }

                // Overdue invoices pinned at top
                if !overdueInvoices.isEmpty {
                    overdueSection
                }

                // Client groups
                if clientGroups.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Client")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)

                        ForEach(clientGroups) { group in
                            clientSection(group)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Invoice Analysis")
        .onAppear {
            // Auto-expand clients with overdue invoices
            for group in clientGroups where group.hasOverdue {
                expandedClients.insert(group.clientName)
            }
        }
    }

    // MARK: - Outstanding Section

    private var outstandingSection: some View {
        HStack(spacing: 10) {
            metricBox(label: "Outstanding", amount: totalOutstanding, color: totalOutstanding > 0 ? .brandPrimary : .secondary)
            metricBox(label: "Collected MTD", amount: paidThisMonth, color: .incomeGreen)
        }
    }

    private func metricBox(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(fmt.string(from: NSNumber(value: amount)) ?? "$0")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(10)
    }

    // MARK: - Overdue Section

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.expenseRed)
                Text("Overdue")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ForEach(overdueInvoices) { invoice in
                invoiceRow(invoice)

                if invoice.id != overdueInvoices.last?.id {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.expenseRed.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Client Section

    private func clientSection(_ group: ClientInvoiceGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Client header — tappable to expand/collapse
            Button {
                withAnimation(FLOAnimation.quick) {
                    if expandedClients.contains(group.clientName) {
                        expandedClients.remove(group.clientName)
                    } else {
                        expandedClients.insert(group.clientName)
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if group.hasOverdue {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.expenseRed)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.clientName)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("\(group.invoices.count) invoice\(group.invoices.count == 1 ? "" : "s") · \(fmt.string(from: NSNumber(value: group.outstanding)) ?? "$0") outstanding")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: expandedClients.contains(group.clientName) ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Invoice list (expanded)
            if expandedClients.contains(group.clientName) {
                Divider()

                ForEach(group.invoices) { invoice in
                    invoiceRow(invoice)

                    if invoice.id != group.invoices.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    group.hasOverdue ? Color.expenseRed.opacity(0.2) : Color.floCardBorder,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Invoice Row

    private func invoiceRow(_ invoice: Invoice) -> some View {
        Button {
            NavigationService.shared.selectedDetail = .invoiceDetail(id: invoice.id)
        } label: {
            HStack(spacing: 10) {
                // Status icon
                Image(systemName: invoice.status.icon)
                    .font(.caption)
                    .foregroundStyle(statusColor(invoice.status))
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(invoice.invoiceNumber.isEmpty ? "Invoice" : invoice.invoiceNumber)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if invoice.isOverdue {
                        Text("\(invoice.daysOverdue)d overdue")
                            .font(.caption2)
                            .foregroundStyle(Color.expenseRed)
                    } else if !invoice.isFinal {
                        let days = invoice.daysUntilDue
                        Text(days == 0 ? "Due today" : days > 0 ? "Due in \(days)d" : "Overdue")
                            .font(.caption2)
                            .foregroundStyle(days <= 3 ? Color.brandWarning : .secondary)
                    } else {
                        Text(invoice.status.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(fmt.string(from: NSNumber(value: invoice.remainingBalance)) ?? "$0")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(invoice.isFinal ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Payment progress for partial
                    if invoice.isPartiallyPaid {
                        Text("\(Int(invoice.paymentProgress * 100))% paid")
                            .font(.caption2)
                            .foregroundStyle(Color.brandPrimary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status Color

    private func statusColor(_ status: InvoiceStatus) -> Color {
        switch status {
        case .draft:          return .secondary
        case .sent:           return .blue
        case .viewed:         return Color(hue: 0.54, saturation: 0.7, brightness: 0.8)
        case .paid:           return .incomeGreen
        case .partiallyPaid:  return .brandWarning
        case .overdue:        return .expenseRed
        case .cancelled:      return .secondary
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 36, weight: .ultraLight))
                .foregroundStyle(.quaternary)
            Text("No invoices yet")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - Supporting Data

private struct ClientInvoiceGroup: Identifiable {
    let id = UUID()
    let clientName: String
    let invoices: [Invoice]
    let outstanding: Double
    let hasOverdue: Bool
}
