//  BudgetWrapUpView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Per-Budget Wrap-Up with Paid & Carryover Controls
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.0:
//  ✅ ADDED: Per-budget wrap-up rows with category icon, spent vs planned
//  ✅ ADDED: Auto-detected paid status with manual override toggle
//  ✅ ADDED: Per-budget carryover toggle for one-time month override
//  ✅ ADDED: Carryover amount preview when enabled
//  ✅ ADDED: Summary header with overall month stats
//  ✅ ADDED: Full VoiceOver and Dynamic Type support

import SwiftUI
import FLODesignSystem
import SwiftData

struct BudgetWrapUpView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let budgets: [Budget]
    let allTransactions: [Transaction]
    let monthStart: Date
    let monthName: String

    @State private var viewAppeared = false

    private let calendar = Calendar.current

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

                    ForEach(Array(sortedBudgets.enumerated()), id: \.element.id) { index, budget in
                        let spent = calculateSpent(for: budget)
                        WrapUpBudgetRow(
                            budget: budget,
                            spent: spent,
                            carryOverAmount: calculateCarryOver(for: budget, spent: spent),
                            onPaidToggle: { togglePaid(budget, spent: spent) },
                            onCarryOverToggle: { toggleCarryOver(budget) }
                        )
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.1 + Double(index) * 0.05), value: viewAppeared)
                    }
                }
                .padding()
            }
            .background(Color.floSystemGroupedBackground)
            .navigationTitle("\(monthName) Wrap-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityHint("Save changes and close wrap-up")
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("\(monthName) budget wrap-up")
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)

                Text("\(monthName) Summary")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
            }

            let stats = budgetStats
            HStack(spacing: 4) {
                Image(systemName: stats.paidCount == stats.total ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(stats.paidCount == stats.total ? Color.incomeGreen : Color.orange)
                    .accessibilityHidden(true)

                Text("\(stats.paidCount) of \(stats.total) marked paid")
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.forward.circle.fill")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)

                Text("\(stats.carryOverCount) budget\(stats.carryOverCount == 1 ? "" : "s") carrying over")
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            if stats.totalCarryOver > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(Color.incomeGreen)
                        .accessibilityHidden(true)

                    Text("\(stats.totalCarryOver.formatted(.currency(code: "USD"))) total rolling forward")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Calculations

    private var sortedBudgets: [Budget] {
        budgets.sorted { ($0.displayName).localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var budgetStats: (paidCount: Int, total: Int, carryOverCount: Int, totalCarryOver: Double) {
        var paidCount = 0
        var carryOverCount = 0
        var totalCarryOver: Double = 0

        for budget in budgets {
            let spent = calculateSpent(for: budget)
            if budget.isPaid(spent: spent) {
                paidCount += 1
            }
            if budget.effectiveShouldCarryOver {
                carryOverCount += 1
                let co = calculateCarryOver(for: budget, spent: spent)
                if co > 0 { totalCarryOver += co }
            }
        }

        return (paidCount, budgets.count, carryOverCount, totalCarryOver)
    }

    private func calculateSpent(for budget: Budget) -> Double {
        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? monthStart

        let relevantTransactions = allTransactions.filter { transaction in
            guard !transaction.isIncome else { return false }
            guard transaction.financeType == budget.financeType else { return false }
            guard transaction.date >= monthStart && transaction.date <= monthEnd else { return false }

            if let budgetCategory = budget.category {
                return transaction.category?.id == budgetCategory.id
            }
            return true
        }

        return abs(relevantTransactions.reduce(0) { $0 + $1.amount })
    }

    private func calculateCarryOver(for budget: Budget, spent: Double) -> Double {
        let remaining = budget.totalAvailable - spent
        return max(remaining, 0)
    }

    // MARK: - Actions

    private func togglePaid(_ budget: Budget, spent: Double) {
        HapticService.play(.medium)
        let currentPaid = budget.isPaid(spent: spent)
        budget.setPaidOverride(!currentPaid)
    }

    private func toggleCarryOver(_ budget: Budget) {
        HapticService.play(.medium)
        let currentlySkipped = budget.monthlyCarryOverSkip ?? false
        budget.monthlyCarryOverSkip = !currentlySkipped
        budget.touch()
    }

    private func saveChanges() {
        do {
            try context.save()
            HapticService.play(.success)
        } catch {
            print("Failed to save wrap-up changes: \(error)")
            HapticService.play(.error)
        }
    }
}

// MARK: - Per-Budget Row

struct WrapUpBudgetRow: View {
    let budget: Budget
    let spent: Double
    let carryOverAmount: Double
    let onPaidToggle: () -> Void
    let onCarryOverToggle: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var isPaid: Bool {
        budget.isPaid(spent: spent)
    }

    private var isAutoDetected: Bool {
        budget.isPaidOverride == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Category + Paid status
            HStack(spacing: 10) {
                Image(systemName: budget.category?.icon ?? "dollarsign.circle")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if isAccessibilitySize {
                        spentVsBudgetText
                    }
                }

                Spacer()

                if !isAccessibilitySize {
                    spentVsBudgetText
                }

                // Paid toggle button
                Button(action: onPaidToggle) {
                    VStack(spacing: 2) {
                        Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isPaid ? Color.incomeGreen : Color.secondary)

                        Text(isPaid ? "Paid" : "Unpaid")
                            .font(.caption2)
                            .foregroundStyle(isPaid ? Color.incomeGreen : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPaid ? "Marked as paid" : "Not paid")
                .accessibilityHint(isAutoDetected
                    ? "Auto-detected. Double tap to override."
                    : "Manually set. Double tap to toggle.")
            }

            // Auto-detect indicator
            if isAutoDetected {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Color.brandPrimary)
                        .accessibilityHidden(true)

                    Text("Auto-detected from transactions")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("Manually marked")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    Button {
                        HapticService.play(.light)
                        budget.setPaidOverride(nil)
                    } label: {
                        Text("Reset to Auto")
                            .font(.caption2)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset to auto-detect")
                    .accessibilityHint("Double tap to let FLO detect paid status from transactions")
                }
            }

            Divider()

            // Carryover toggle
            HStack {
                Toggle(isOn: Binding(
                    get: { budget.effectiveShouldCarryOver },
                    set: { _ in onCarryOverToggle() }
                )) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.forward.circle")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)

                        Text("Carry over")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .tint(Color.brandPrimary)
                .accessibilityLabel("Carry over unused funds")
                .accessibilityHint("Double tap to toggle carryover for this month")
            }

            if budget.effectiveShouldCarryOver && carryOverAmount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "dollarsign.circle")
                        .font(.caption)
                        .foregroundStyle(Color.incomeGreen)
                        .accessibilityHidden(true)

                    Text("\(carryOverAmount.formatted(.currency(code: "USD"))) will roll forward")
                        .font(.caption)
                        .foregroundStyle(Color.incomeGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .floCardShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private var spentVsBudgetText: some View {
        Text("\(spent.formatted(.currency(code: "USD"))) / \(budget.planned.formatted(.currency(code: "USD")))")
            .font(.caption.monospacedDigit())
            .foregroundStyle(spent > budget.totalAvailable ? Color.red : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }

    private var rowAccessibilityLabel: String {
        var label = "\(budget.displayName). Spent \(spent.formatted(.currency(code: "USD"))) of \(budget.planned.formatted(.currency(code: "USD")))."
        label += isPaid ? " Paid." : " Not paid."
        if budget.effectiveShouldCarryOver && carryOverAmount > 0 {
            label += " \(carryOverAmount.formatted(.currency(code: "USD"))) carrying over."
        }
        return label
    }
}

// MARK: - Preview

#Preview("Budget Wrap-Up") {
    let container = try! ModelContainer(
        for: Budget.self, Category.self, Transaction.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "10B981", isIncome: false)
    let utilities = Category(name: "Utilities", icon: "bolt.fill", colorHex: "F59E0B", isIncome: false)
    context.insert(groceries)
    context.insert(utilities)

    let calendar = Calendar.current
    let prevMonth = calendar.date(byAdding: .month, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!)!

    let b1 = Budget(month: prevMonth, planned: 500, category: groceries, financeType: .personal)
    let b2 = Budget(month: prevMonth, planned: 200, carryOver: 50, category: utilities, budgetType: .envelope, financeType: .personal)
    context.insert(b1)
    context.insert(b2)

    return BudgetWrapUpView(
        budgets: [b1, b2],
        allTransactions: [],
        monthStart: prevMonth,
        monthName: DateFormatter.fullMonth.string(from: prevMonth)
    )
    .modelContainer(container)
}
