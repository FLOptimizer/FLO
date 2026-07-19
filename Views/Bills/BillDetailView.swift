//  BillDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Bill detail with Mark Paid (top-right) and payment history
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Mirrors InvoiceDetailView's structure but pared down for bills:
//  status header, payment progress, vendor + due-date details, payment history,
//  scanned image preview, and the Mark Paid button pinned to the top-right.
//

import SwiftUI
import SwiftData

struct BillDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bill: Bill

    @State private var showingMarkPaid = false
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var actionError: Error?
    @State private var showingActionError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusHeader

                if bill.hasPayments && !bill.isFullyPaid {
                    paymentProgressSection
                }

                detailsSection

                if bill.hasPayments {
                    paymentHistorySection
                }

                if let imageData = bill.scannedImageData {
                    scannedImageSection(imageData)
                }

                if !bill.note.isEmpty {
                    noteSection
                }

                actionsSection
            }
            .padding()
        }
        .navigationTitle(bill.vendorName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticService.play(.light)
                    showingMarkPaid = true
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(bill.status == .paid || bill.status == .cancelled)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        HapticService.play(.light)
                        showingEdit = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if bill.status == .cancelled {
                        Button {
                            HapticService.play(.light)
                            reactivate()
                        } label: {
                            Label("Reactivate", systemImage: "arrow.uturn.backward")
                        }
                    } else if bill.status != .paid {
                        Button {
                            HapticService.play(.light)
                            cancel()
                        } label: {
                            Label("Cancel Bill", systemImage: "xmark.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        HapticService.play(.medium)
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingMarkPaid) {
            MarkBillPaidSheet(bill: bill)
        }
        .sheet(isPresented: $showingEdit) {
            BillFormView(editingBill: bill)
        }
        .alert("Delete Bill?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \(bill.vendorName) and its payment history. This cannot be undone.")
        }
        .alert("Couldn't update bill", isPresented: $showingActionError, presenting: actionError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: bill.status.icon)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                Text(statusTitle)
                    .font(.headline)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline) {
                Text(bill.formattedAmount)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                Text(bill.formattedDueDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(statusColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusColor: Color {
        if bill.status == .paid { return .green }
        if bill.status == .cancelled { return .gray }
        if bill.isOverdue { return .red }
        if bill.isPartiallyPaid { return .orange }
        return .accentColor
    }

    private var statusTitle: String {
        if bill.status == .paid { return "Paid" }
        if bill.status == .cancelled { return "Cancelled" }
        if bill.isOverdue { return "Overdue" }
        if bill.isPartiallyPaid { return "Partially Paid" }
        if bill.isUponReceipt { return "Upon Receipt" }
        return "Pending"
    }

    // MARK: - Payment Progress

    private var paymentProgressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Payment Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(bill.paymentProgress * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: bill.paymentProgress)
                .tint(.orange)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid").font(.caption).foregroundStyle(.secondary)
                    Text(bill.formattedAmountPaid)
                        .font(.subheadline.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining").font(.caption).foregroundStyle(.secondary)
                    Text(bill.formattedRemainingBalance)
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Details

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            DetailRow(label: "Vendor", value: bill.vendorName)
            DetailRow(label: "Due", value: bill.formattedDueDate)
            DetailRow(label: "Type", value: bill.financeType == .business ? "Business" : "Personal")
            if let category = bill.category {
                DetailRow(label: "Category", value: category.name)
            }
            if let account = bill.account {
                DetailRow(label: "Pay From", value: account.name)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Payment History

    private var paymentHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment History")
                .font(.headline)
            ForEach(sortedPayments, id: \.id) { payment in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payment.paymentMethod.displayName)
                            .font(.subheadline)
                        Text(payment.formattedDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(payment.formattedAmount)
                        .font(.subheadline.monospacedDigit())
                }
                if payment.id != sortedPayments.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sortedPayments: [BillPayment] {
        (bill.payments ?? []).sorted { $0.date > $1.date }
    }

    // MARK: - Scanned Image

    private func scannedImageSection(_ data: Data) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scanned Bill")
                .font(.headline)
            #if canImport(UIKit)
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            #elseif canImport(AppKit)
            if let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            #endif
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.headline)
            Text(bill.note)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if bill.status != .paid && bill.status != .cancelled {
                Button {
                    HapticService.play(.light)
                    showingMarkPaid = true
                } label: {
                    Label(bill.hasPayments ? "Record Another Payment" : "Mark Paid",
                          systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Action Handlers

    private func delete() {
        do {
            try BillService.shared.deleteBill(bill, context: modelContext)
            HapticService.play(.success)
            dismiss()
        } catch {
            actionError = error
            showingActionError = true
        }
    }

    private func cancel() {
        do {
            try BillService.shared.cancelBill(bill, context: modelContext)
        } catch {
            actionError = error
            showingActionError = true
        }
    }

    private func reactivate() {
        do {
            try BillService.shared.reactivateBill(bill, context: modelContext)
        } catch {
            actionError = error
            showingActionError = true
        }
    }
}

// MARK: - DetailRow

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#if DEBUG
#Preview("Pending") {
    NavigationStack {
        BillDetailView(bill: Bill.previewPending)
    }
    .modelContainer(ModelContainer.preview())
}

#Preview("Overdue") {
    NavigationStack {
        BillDetailView(bill: Bill.previewOverdue)
    }
    .modelContainer(ModelContainer.preview())
}

#Preview("Partially Paid") {
    NavigationStack {
        BillDetailView(bill: Bill.previewPartiallyPaid)
    }
    .modelContainer(ModelContainer.preview())
}
#endif
