//  MarkRecurringSentView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Mark Recurring as Sent
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ ADDED: Form to mark a recurring transaction as sent for a specific month
//  ✅ ADDED: Amount field pre-filled from recurring template (editable for variable bills)
//  ✅ ADDED: Date picker for actual payment date
//  ✅ ADDED: Billing month picker
//  ✅ ADDED: Optional note
//  ✅ ADDED: Creates transaction + payment log on save
//  ✅ ADDED: Shows suggested date info when payment history exists

import SwiftUI
import FLODesignSystem
import SwiftData

struct MarkRecurringSentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let recurring: RecurringTransaction

    @State private var amount: Double
    @State private var dateSent: Date = Date()
    @State private var billingMonth: Date
    @State private var paymentNote: String = ""
    @State private var viewAppeared = false

    private let calendar = Calendar.current

    init(recurring: RecurringTransaction) {
        self.recurring = recurring
        _amount = State(initialValue: recurring.amount)

        // Default billing month to current month
        let cal = Calendar.current
        let components = cal.dateComponents([.year, .month], from: Date())
        _billingMonth = State(initialValue: cal.date(from: components) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                amountSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                dateSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

                if let suggestedDay = recurring.suggestedDayOfMonth {
                    suggestedDateSection(suggestedDay: suggestedDay)
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
                }

                noteSection
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Mark as Sent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityHint("Discard and go back")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                    .accessibilityHint("Creates the payment record")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        #endif
                    }
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Mark \(recurring.displayName) as sent")
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 12) {
                if let category = recurring.category {
                    Image(systemName: category.icon)
                        .font(.title2)
                        .foregroundStyle(Color(flowHex: category.colorHex))
                        .frame(width: 44, height: 44)
                        .background(Color(flowHex: category.colorHex).opacity(0.1))
                        .cornerRadius(10)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "repeat")
                        .font(.title2)
                        .foregroundStyle(Color.brandPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.brandPrimary.opacity(0.1))
                        .cornerRadius(10)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recurring.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(recurring.frequency.displayName) • \(recurring.amount.formatted(.currency(code: "USD")))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            if alreadySentForMonth {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)

                    Text("Already marked as sent for \(billingMonth, format: .dateTime.month(.wide).year())")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    private var amountSection: some View {
        Section {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Payment amount"
            )
        } header: {
            Text("Amount Sent")
        } footer: {
            if abs(amount - recurring.amount) > 0.01 && amount > 0 {
                let diff = amount - recurring.amount
                Text("Differs from scheduled amount by \(diff.formatted(.currency(code: "USD")))")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else {
                Text("Pre-filled from recurring amount. Edit if the actual payment differs.")
                    .font(.caption)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var dateSection: some View {
        Section {
            DatePicker("Date Sent", selection: $dateSent, displayedComponents: .date)
                .accessibilityLabel("Payment date")
                .accessibilityHint("When the payment was sent")

            Picker("Billing Month", selection: $billingMonth) {
                ForEach(billingMonthOptions, id: \.self) { date in
                    Text(date, format: .dateTime.month(.wide).year())
                        .tag(date)
                }
            }
            .accessibilityLabel("Billing month")
            .accessibilityHint("Which month this payment covers")
        } header: {
            Text("Payment Date")
        }
    }

    private func suggestedDateSection(suggestedDay: Int) -> some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggested payment day: \(ordinalDay(suggestedDay))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    let logCount = (recurring.paymentLogs ?? []).count
                    Text("Based on \(logCount) previous payment\(logCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
            }
        } header: {
            Text("Payment Pattern")
        }
    }

    private var noteSection: some View {
        Section("Note (Optional)") {
            TextField("e.g. Paid early, different amount", text: $paymentNote)
                .lineLimit(2)
                .accessibilityLabel("Payment note")
        }
    }

    // MARK: - Computed Properties

    private var isValid: Bool {
        amount > 0 && !alreadySentForMonth
    }

    private var alreadySentForMonth: Bool {
        recurring.isSentForMonth(billingMonth)
    }

    private var billingMonthOptions: [Date] {
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let currentMonth = calendar.date(from: components) else { return [] }

        // Show -3 to +2 months
        return (-3...2).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }

    // MARK: - Actions

    private func save() {
        HapticService.play(.medium)

        let log = recurring.markAsSent(
            for: billingMonth,
            amount: amount,
            on: dateSent,
            in: context
        )

        guard log != nil else {
            HapticService.play(.error)
            return
        }

        if !paymentNote.isEmpty {
            log?.paymentNote = paymentNote
        }

        do {
            try context.save()
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("\(recurring.displayName) marked as sent")
            dismiss()
        } catch {
            HapticService.play(.error)
            print("Failed to save payment log: \(error)")
        }
    }

    // MARK: - Helpers

    private func ordinalDay(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}

// MARK: - Preview

#Preview("Mark as Sent") {
    let container = try! ModelContainer(
        for: RecurringTransaction.self, RecurringPaymentLog.self,
        Transaction.self, Category.self, Account.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let subscriptions = Category(
        name: "Subscriptions",
        icon: "tv.fill",
        colorHex: "3B82F6",
        isIncome: false
    )
    context.insert(subscriptions)

    let netflix = RecurringTransaction(
        amount: 15.99,
        merchantName: "Netflix",
        note: "Streaming",
        isIncome: false,
        financeType: .personal,
        frequency: .monthly,
        startDate: Date(),
        category: subscriptions,
        isActive: true
    )
    context.insert(netflix)

    return MarkRecurringSentView(recurring: netflix)
        .modelContainer(container)
}
