//  BillRow.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Compact bill row for the Upcoming section
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  A row used inside TransactionListView's Upcoming section. Shows vendor,
//  due date / Upon Receipt, amount, and a colored status badge (Due / Overdue
//  / Partial / Upon Receipt). Tap → BillDetailView, swipe-left (iOS) or
//  context menu (macOS) → Mark Paid.
//

import SwiftUI
import SwiftData

struct BillRow: View {
    let bill: Bill

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(badgeColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.vendorName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Text(bill.formattedDueDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    badge
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(bill.formattedRemainingBalance)
                    .font(.body.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if bill.isPartiallyPaid {
                    Text("of \(bill.formattedAmount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(bill.vendorName), \(bill.badgeLabel), \(bill.formattedRemainingBalance) due \(bill.formattedDueDate)")
    }

    private var badge: some View {
        Text(bill.badgeLabel.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        if bill.isOverdue { return .red }
        if bill.isPartiallyPaid { return .orange }
        if bill.isUponReceipt { return .purple }
        return .accentColor
    }
}

#if DEBUG
#Preview {
    List {
        BillRow(bill: Bill.previewPending)
        BillRow(bill: Bill.previewOverdue)
        BillRow(bill: Bill.previewUponReceipt)
        BillRow(bill: Bill.previewPartiallyPaid)
    }
    .modelContainer(ModelContainer.preview())
}
#endif
