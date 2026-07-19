//  LoanAmortizationView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Loan amortization schedule display
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData

struct LoanAmortizationView: View {
    let account: Account

    @State private var schedule: [DebtPaymentEntry] = []
    @State private var extraPayment: Double = 0
    @State private var showingExtraPayment = false

    private var totalInterest: Double {
        schedule.last?.cumulativeInterest ?? 0
    }

    private var totalPaid: Double {
        schedule.reduce(0) { $0 + $1.payment + $1.extraPrincipal }
    }

    private var payoffDate: Date? {
        schedule.last?.date
    }

    var body: some View {
        List {
            // Summary section
            Section("Loan Summary") {
                HStack {
                    Label("Principal", systemImage: "banknote")
                    Spacer()
                    Text((account.originalLoanAmount ?? 0).formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("APR", systemImage: "percent")
                    Spacer()
                    Text("\(account.apr ?? 0, specifier: "%.2f")%")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Monthly Payment", systemImage: "calendar")
                    Spacer()
                    Text((account.monthlyPaymentAmount ?? 0).formatted(.currency(code: "USD")))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Total Interest", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(totalInterest.formatted(.currency(code: "USD")))
                        .foregroundStyle(.red)
                }

                if let payoff = payoffDate {
                    HStack {
                        Label("Payoff Date", systemImage: "checkmark.circle")
                        Spacer()
                        Text(payoff.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.green)
                    }
                }

                HStack {
                    Label("Months Remaining", systemImage: "clock")
                    Spacer()
                    Text("\(schedule.count)")
                        .foregroundStyle(.secondary)
                }
            }

            // Extra payment toggle
            Section {
                Toggle("Extra Monthly Payment", isOn: $showingExtraPayment.animation())

                if showingExtraPayment {
                    HStack {
                        Text("Extra")
                        Slider(value: $extraPayment, in: 0...1000, step: 25)
                            .onChange(of: extraPayment) { _, _ in
                                recalculate()
                            }
                        Text(extraPayment.formatted(.currency(code: "USD")))
                            .font(.caption.monospacedDigit())
                            .frame(width: 70, alignment: .trailing)
                    }

                    if extraPayment > 0 {
                        let baseSchedule = generateSchedule(extra: 0)
                        let savedInterest = (baseSchedule.last?.cumulativeInterest ?? 0) - totalInterest
                        let savedMonths = baseSchedule.count - schedule.count

                        if savedInterest > 0 || savedMonths > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.green)
                                Text("Save \(savedInterest.formatted(.currency(code: "USD"))) interest and \(savedMonths) months")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            // Schedule table
            Section("Amortization Schedule") {
                // Header row
                HStack {
                    Text("#")
                        .frame(width: 30, alignment: .leading)
                    Text("Payment")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Principal")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Interest")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text("Balance")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

                ForEach(Array(schedule.enumerated()), id: \.offset) { index, entry in
                    HStack {
                        Text("\(entry.month)")
                            .frame(width: 30, alignment: .leading)
                            .font(.caption.monospacedDigit())
                        Text(entry.payment.formatted(.currency(code: "USD")))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption.monospacedDigit())
                        Text(entry.principal.formatted(.currency(code: "USD")))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.green)
                        Text(entry.interest.formatted(.currency(code: "USD")))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.red)
                        Text(entry.remainingBalance.formatted(.currency(code: "USD")))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption.monospacedDigit())
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
            }
        }
        .navigationTitle("Amortization")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            recalculate()
        }
    }

    private func recalculate() {
        schedule = generateSchedule(extra: showingExtraPayment ? extraPayment : 0)
    }

    private func generateSchedule(extra: Double) -> [DebtPaymentEntry] {
        let principal = account.originalLoanAmount ?? abs(account.currentBalance)
        let rate = account.apr ?? 0
        let monthly = account.monthlyPaymentAmount ?? 0

        guard principal > 0, rate > 0, monthly > 0 else { return [] }

        return DebtCalculationService.shared.generateAmortizationSchedule(
            principal: principal,
            annualRate: rate,
            monthlyPayment: monthly,
            extraMonthlyPayment: extra
        )
    }
}
