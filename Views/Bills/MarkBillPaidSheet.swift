//  MarkBillPaidSheet.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Record a bill payment
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Sheet for recording a payment against a Bill. Mirrors MarkAsPaidView (the
//  invoice flow) but pared down: bills don't have an "income transaction" toggle,
//  no celebration overlay, no client information.
//

import SwiftUI
import SwiftData

struct MarkBillPaidSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { $0.isActive }, sort: \Account.name)
    private var accounts: [Account]

    let bill: Bill

    @State private var paymentAmount: Double = 0
    @State private var paymentDate: Date = Date()
    @State private var paymentMethod: PaymentMethod = .bankTransfer
    @State private var selectedAccount: Account?
    @State private var notes: String = ""

    @State private var isProcessing = false
    @State private var saveError: Error?
    @State private var showingSaveError = false

    private var isValidAmount: Bool {
        paymentAmount > 0 && paymentAmount <= bill.remainingBalance + 0.01
    }

    private var isFullPayment: Bool {
        abs(paymentAmount - bill.remainingBalance) < 0.01
    }

    private var remainingAfter: Double {
        max(bill.remainingBalance - paymentAmount, 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                summarySection
                amountSection
                paymentDetailsSection
                accountSection
                notesSection
            }
            .navigationTitle("Mark Paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.heavy)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { recordPayment() }
                        .disabled(!isValidAmount || isProcessing)
                        .fontWeight(.semibold)
                }
            }
            .alert("Couldn't record payment", isPresented: $showingSaveError, presenting: saveError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onAppear(perform: setupDefaults)
        }
        .floMacSheetFrame(minWidth: 520, minHeight: 560)
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(bill.vendorName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text(bill.formattedAmount)
                        .font(.headline.monospacedDigit())
                }
                HStack {
                    Text(bill.formattedDueDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if bill.hasPayments {
                        Text("Remaining \(bill.formattedRemainingBalance)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var amountSection: some View {
        Section {
            CurrencyInputField(amount: $paymentAmount, font: .title2)
                .padding(.vertical, 4)

            if paymentAmount > 0 {
                HStack {
                    Text(isFullPayment ? "Pays bill in full" : "Remaining after payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isFullPayment {
                        Text(remainingAfter.formatted(.currency(code: "USD")))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                quickAmountButton("Full", value: bill.remainingBalance)
                quickAmountButton("Half", value: bill.remainingBalance / 2)
                quickAmountButton("$50", value: 50)
                quickAmountButton("$100", value: 100)
            }
            .buttonStyle(.bordered)
        } header: {
            Text("Payment Amount")
        }
    }

    private func quickAmountButton(_ label: String, value: Double) -> some View {
        Button(label) {
            HapticService.play(.light)
            paymentAmount = value
        }
        .disabled(value <= 0 || value > bill.remainingBalance + 0.01)
    }

    private var paymentDetailsSection: some View {
        Section("Payment Details") {
            DatePicker("Date", selection: $paymentDate, displayedComponents: .date)
            Picker("Method", selection: $paymentMethod) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
        }
    }

    private var accountSection: some View {
        Section("Pay From") {
            Picker("Account", selection: $selectedAccount) {
                Text("None").tag(Account?.none)
                ForEach(accounts, id: \.id) { account in
                    Text(account.name).tag(Account?.some(account))
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - Setup & Save

    private func setupDefaults() {
        paymentAmount = bill.remainingBalance
        selectedAccount = bill.account ?? accounts.first { $0.isPrimary } ?? accounts.first
    }

    private func recordPayment() {
        guard !isProcessing else { return }
        isProcessing = true
        do {
            try BillService.shared.recordPayment(
                for: bill,
                amount: paymentAmount,
                date: paymentDate,
                paymentMethod: paymentMethod,
                account: selectedAccount,
                notes: notes,
                context: modelContext
            )
            HapticService.play(.success)
            dismiss()
        } catch {
            HapticService.play(.error)
            saveError = error
            showingSaveError = true
            isProcessing = false
        }
    }
}

#if DEBUG
#Preview("Mark Paid — Pending") {
    MarkBillPaidSheet(bill: Bill.previewPending)
        .modelContainer(ModelContainer.preview())
}
#Preview("Mark Paid — Partially Paid") {
    MarkBillPaidSheet(bill: Bill.previewPartiallyPaid)
        .modelContainer(ModelContainer.preview())
}
#endif
