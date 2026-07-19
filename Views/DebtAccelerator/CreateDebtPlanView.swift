//  CreateDebtPlanView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Debt Accelerator Phase 1
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData

struct CreateDebtPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]

    var existingPlan: DebtAcceleratorPlan?

    @State private var planName: String = "My Debt Plan"
    @State private var strategy: AcceleratorStrategy = .hybrid
    @State private var extraMonthlyPayment: String = ""
    @State private var vaultAPY: String = ""
    @State private var selectedAccountIDs: Set<UUID> = []
    @State private var paymentReminders = true
    @State private var reminderDays = 3

    private var debtAccounts: [Account] {
        accounts.filter { $0.isDebtAccount }
    }

    private var isValid: Bool {
        !planName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !selectedAccountIDs.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Name") {
                    TextField("Plan Name", text: $planName)
                }

                Section("Strategy") {
                    Picker("Payoff Strategy", selection: $strategy) {
                        ForEach(AcceleratorStrategy.allCases) { s in
                            VStack(alignment: .leading) {
                                Label(s.displayName, systemImage: s.icon)
                            }
                            .tag(s)
                        }
                    }
                    .pickerStyle(.inline)

                    Text(strategy.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Extra Payment") {
                    HStack {
                        Text("$")
                        TextField("Monthly extra", text: $extraMonthlyPayment)
                            #if !os(macOS)
                            .keyboardType(.decimalPad)
                            #endif
                    }
                    Text("Amount above minimum payments to accelerate payoff")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if strategy == .hybrid {
                    Section("Vault/HYSA Yield") {
                        HStack {
                            TextField("APY %", text: $vaultAPY)
                                #if !os(macOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Text("%")
                        }
                        Text("Your savings account yield — helps the optimizer decide when to prioritize debt vs. savings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Include Debts") {
                    if debtAccounts.isEmpty {
                        Text("No debt accounts found. Add a credit card or loan first.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(debtAccounts) { account in
                            Button {
                                if selectedAccountIDs.contains(account.id) {
                                    selectedAccountIDs.remove(account.id)
                                } else {
                                    selectedAccountIDs.insert(account.id)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedAccountIDs.contains(account.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedAccountIDs.contains(account.id) ? .blue : .secondary)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(account.name)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(account.effectiveAPR, specifier: "%.1f")% APR")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(abs(account.currentBalance).formatted(.currency(code: "USD")))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .tint(.primary)
                        }
                    }
                }

                Section("Reminders") {
                    Toggle("Payment Reminders", isOn: $paymentReminders)

                    if paymentReminders {
                        Stepper("Remind \(reminderDays) days before", value: $reminderDays, in: 1...14)
                    }
                }
            }
            .navigationTitle(existingPlan != nil ? "Edit Plan" : "New Debt Plan")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingPlan != nil ? "Save" : "Create") {
                        savePlan()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let plan = existingPlan {
                    planName = plan.name
                    strategy = plan.strategy
                    extraMonthlyPayment = plan.extraMonthlyPayment > 0 ? String(format: "%.0f", plan.extraMonthlyPayment) : ""
                    vaultAPY = plan.vaultAPY > 0 ? String(format: "%.1f", plan.vaultAPY) : ""
                    selectedAccountIDs = Set(plan.includedAccountIDs)
                    paymentReminders = plan.paymentRemindersEnabled
                    reminderDays = plan.reminderDaysBefore
                } else {
                    // Pre-select all debt accounts
                    selectedAccountIDs = Set(debtAccounts.map(\.id))
                }
            }
        }
    }

    private func savePlan() {
        let plan = existingPlan ?? DebtAcceleratorPlan()
        plan.name = planName.trimmingCharacters(in: .whitespaces)
        plan.strategy = strategy
        plan.extraMonthlyPayment = Double(extraMonthlyPayment) ?? 0
        plan.vaultAPY = Double(vaultAPY) ?? 0
        plan.includedAccountIDs = Array(selectedAccountIDs)
        plan.paymentRemindersEnabled = paymentReminders
        plan.reminderDaysBefore = reminderDays
        plan.modifiedDate = Date()

        if existingPlan == nil {
            plan.isActive = true
            modelContext.insert(plan)
        }

        try? modelContext.save()
        dismiss()
    }
}

#if DEBUG
#Preview {
    CreateDebtPlanView()
        .modelContainer(for: [DebtAcceleratorPlan.self, Account.self])
}
#endif
