//  DebtAcceleratorDetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Transfer recording, progress tracking, celebration, countdown
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData
import Charts

struct DebtAcceleratorDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: DebtAcceleratorPlan
    @Query private var accounts: [Account]

    @State private var projection: DebtCalculationService.AcceleratorProjection?
    @State private var isCalculating = false
    @State private var showingEditPlan = false
    @State private var showingDeleteConfirmation = false
    @State private var visibleMonths = 12
    @State private var refreshTrigger = UUID()
    @State private var showingCelebration = false
    @State private var celebrationAccountName = ""

    private var debtAccounts: [Account] {
        accounts.filter { $0.isDebtAccount }
    }

    /// Accounts that have been fully paid off (balance == 0 but still marked as debt type)
    private var paidOffAccounts: [Account] {
        accounts.filter { ($0.accountType == .creditCard || $0.accountType == .loan) && $0.currentBalance == 0 }
    }

    /// Total current actual debt remaining
    private var actualTotalDebt: Double {
        debtAccounts.reduce(0) { $0 + abs($1.currentBalance) }
    }

    var body: some View {
        ZStack {
            List {
                debtFreeCountdownSection
                progressTrackingSection
                planInfoSection
                if let projection = projection {
                    savingsSummarySection(projection)
                    balanceBreakdownChart(projection)
                    monthlyScheduleSection(projection)
                } else if isCalculating {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Calculating optimized schedule...")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(plan.name)
            .scrollContentBackground(.hidden)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditPlan = true
                        } label: {
                            Label("Edit Plan", systemImage: "pencil")
                        }

                        Button {
                            Task { await recalculate() }
                        } label: {
                            Label("Recalculate", systemImage: "arrow.clockwise")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Plan", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingEditPlan) {
                CreateDebtPlanView(existingPlan: plan)
            }
            .onChange(of: showingEditPlan) { _, isShowing in
                if !isShowing { refreshTrigger = UUID() }
            }
            .alert("Delete Plan", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(plan)
                    try? modelContext.save()
                }
            } message: {
                Text("Are you sure you want to delete \"\(plan.name)\"? This cannot be undone.")
            }
            .task(id: refreshTrigger) {
                await recalculate()
            }

            // Payoff celebration overlay
            if showingCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Debt-Free Countdown

    @ViewBuilder
    private var debtFreeCountdownSection: some View {
        if let months = plan.monthsUntilPayoff, months > 0 {
            Section {
                VStack(spacing: 12) {
                    // Countdown circle
                    ZStack {
                        Circle()
                            .stroke(Color.green.opacity(0.2), lineWidth: 8)
                            .frame(width: 100, height: 100)

                        let totalMonths = plan.projectedMonthsSaved + months
                        let progress = totalMonths > 0 ? Double(totalMonths - months) / Double(totalMonths) : 0
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 2) {
                            Text("\(months)")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.green)
                            Text(months == 1 ? "month" : "months")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Until Debt-Free")
                        .font(.subheadline.weight(.semibold))

                    if let payoffDate = plan.projectedPayoffDate {
                        Text(payoffDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        } else if debtAccounts.isEmpty && !paidOffAccounts.isEmpty {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)
                    Text("You're Debt-Free!")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.green)
                    Text("Congratulations on paying off all your debts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Progress Tracking (Actual vs Projected)

    @ViewBuilder
    private var progressTrackingSection: some View {
        if let projection = projection, !debtAccounts.isEmpty {
            let currentMonth = currentScheduleMonth
            if currentMonth > 0 && currentMonth <= projection.monthlyAllocations.count {
                let projectedBalance = projection.monthlyAllocations[currentMonth - 1]
                    .reduce(0.0) { $0 + $1.remainingBalance }
                let delta = actualTotalDebt - projectedBalance
                let isAhead = delta < -1  // More than $1 ahead

                Section("Progress") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Actual Balance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(actualTotalDebt.formatted(.currency(code: "USD")))
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Projected (Month \(currentMonth))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(projectedBalance.formatted(.currency(code: "USD")))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: isAhead ? "arrow.up.circle.fill" : (delta > 1 ? "arrow.down.circle.fill" : "checkmark.circle.fill"))
                            .foregroundStyle(isAhead ? .green : (delta > 1 ? .orange : .blue))
                        if abs(delta) <= 1 {
                            Text("Right on track")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.blue)
                        } else {
                            Text("\(abs(delta).formatted(.currency(code: "USD"))) \(isAhead ? "ahead of" : "behind") schedule")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(isAhead ? .green : .orange)
                        }
                    }
                }
            }
        }
    }

    /// Determine which month of the schedule we're currently in
    private var currentScheduleMonth: Int {
        guard let payments = plan.scheduledPayments,
              let firstPayment = payments.min(by: { $0.scheduledDate < $1.scheduledDate }) else { return 0 }
        let monthsSinceStart = Calendar.current.dateComponents([.month], from: firstPayment.scheduledDate, to: Date()).month ?? 0
        return max(1, monthsSinceStart + 1)
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) {
                        showingCelebration = false
                    }
                }

            VStack(spacing: 20) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: showingCelebration)

                Text("\(celebrationAccountName) Paid Off!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("One less debt to worry about. Keep going!")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)

                Button {
                    withAnimation(.spring(response: 0.4)) {
                        showingCelebration = false
                    }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(.green.gradient)
                        .clipShape(Capsule())
                }
            }
            .padding(32)
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Sections

    private var planInfoSection: some View {
        Section("Plan Configuration") {
            HStack {
                Label("Strategy", systemImage: plan.strategy.icon)
                Spacer()
                Text(plan.strategy.displayName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Extra Payment", systemImage: "plus.circle")
                Spacer()
                Text(plan.extraMonthlyPayment.formatted(.currency(code: "USD")))
                    .foregroundStyle(.blue)
            }

            if plan.vaultAPY > 0 {
                HStack {
                    Label("Vault APY", systemImage: "building.columns")
                    Spacer()
                    Text("\(plan.vaultAPY, specifier: "%.1f")%")
                        .foregroundStyle(.green)
                }
            }

            HStack {
                Label("Debts Included", systemImage: "creditcard.fill")
                Spacer()
                Text("\(debtAccounts.count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Created", systemImage: "calendar")
                Spacer()
                Text(plan.createdDate.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savingsSummarySection(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Projected Outcome") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debt-Free By")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projection.payoffDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("vs Minimum")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projection.baselinePayoffDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .strikethrough()
                }
            }

            HStack {
                statCard(
                    title: "Interest Saved",
                    value: projection.interestSavedVsMinimum.formatted(.currency(code: "USD")),
                    color: .green,
                    icon: "banknote"
                )
                Divider()
                statCard(
                    title: "Months Saved",
                    value: "\(projection.monthsSavedVsMinimum)",
                    color: .blue,
                    icon: "clock.arrow.circlepath"
                )
            }
            .padding(.vertical, 4)

            HStack {
                statCard(
                    title: "Total Interest",
                    value: projection.totalInterest.formatted(.currency(code: "USD")),
                    color: .red,
                    icon: "chart.bar"
                )
                Divider()
                statCard(
                    title: "Total Paid",
                    value: projection.totalPaid.formatted(.currency(code: "USD")),
                    color: .primary,
                    icon: "dollarsign.circle"
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func statCard(title: String, value: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func balanceBreakdownChart(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        Section("Balance Over Time") {
            // Group by account across months
            let accountIDs = Set(projection.monthlyAllocations.flatMap { $0.map(\.accountID) })

            Chart {
                ForEach(Array(projection.monthlyAllocations.enumerated()), id: \.offset) { month, allocations in
                    ForEach(allocations) { allocation in
                        BarMark(
                            x: .value("Month", month + 1),
                            y: .value("Balance", allocation.remainingBalance)
                        )
                        .foregroundStyle(by: .value("Account", allocation.accountName))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(formatCompact(amount))
                        }
                    }
                }
            }
            .chartXAxisLabel("Months")
            .frame(height: 220)
            .padding(.vertical, 4)
        }
    }

    private func monthlyScheduleSection(_ projection: DebtCalculationService.AcceleratorProjection) -> some View {
        let totalMonths = projection.monthlyAllocations.count
        let displayMonths = min(visibleMonths, totalMonths)
        let calendar = Calendar.current
        let startDate = Date()

        return Section("Payment Schedule (\(totalMonths) months)") {
            // Upcoming payments from persisted ScheduledPayments
            if let payments = plan.scheduledPayments,
               !payments.filter({ $0.isDue && !$0.isPaid }).isEmpty {
                upcomingPaymentsRow(payments: payments)
            }

            ForEach(0..<displayMonths, id: \.self) { monthIndex in
                let allocations = projection.monthlyAllocations[monthIndex]
                let totalPayment = allocations.reduce(0.0) { $0 + $1.totalPayment }
                let totalBalance = allocations.reduce(0.0) { $0 + $1.remainingBalance }
                let monthDate = calendar.date(byAdding: .month, value: monthIndex + 1, to: startDate) ?? startDate
                let isPast = monthDate < Date()

                DisclosureGroup {
                    ForEach(allocations) { allocation in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(allocation.accountName)
                                    .font(.caption.weight(.medium))
                                if allocation.extraPayment > 0 {
                                    Text("+\(allocation.extraPayment.formatted(.currency(code: "USD"))) extra")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(allocation.totalPayment.formatted(.currency(code: "USD")))
                                    .font(.caption.weight(.medium))
                                Text("Bal: \(allocation.remainingBalance.formatted(.currency(code: "USD")))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Mark month as paid button
                    Button {
                        markMonthAsPaid(month: monthIndex + 1)
                    } label: {
                        Label("Mark Month as Paid", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .disabled(isMonthPaid(month: monthIndex + 1))
                } label: {
                    HStack {
                        if isMonthPaid(month: monthIndex + 1) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Month \(monthIndex + 1)")
                                .font(.subheadline.weight(.medium))
                            Text(monthDate.formatted(.dateTime.month(.abbreviated).year()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(totalPayment.formatted(.currency(code: "USD")))
                                .font(.subheadline)
                            Text("Remaining: \(formatCompact(totalBalance))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(isPast && !isMonthPaid(month: monthIndex + 1) ? 0.6 : 1.0)
                }
            }

            // Show More button
            if displayMonths < totalMonths {
                Button {
                    withAnimation {
                        visibleMonths += 12
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Show Next 12 Months (\(totalMonths - displayMonths) remaining)")
                            .font(.subheadline)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func upcomingPaymentsRow(payments: [ScheduledPayment]) -> some View {
        let duePayments = payments.filter { $0.isDue && !$0.isPaid }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("\(duePayments.count) payment\(duePayments.count == 1 ? "" : "s") due")
                    .font(.subheadline.weight(.semibold))
            }
            ForEach(duePayments) { payment in
                HStack {
                    Text(payment.accountName)
                        .font(.caption)
                    Spacer()
                    Text(payment.totalPayment.formatted(.currency(code: "USD")))
                        .font(.caption.weight(.medium))
                    Button {
                        markPaymentAsPaid(payment)
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func isMonthPaid(month: Int) -> Bool {
        guard let payments = plan.scheduledPayments else { return false }
        let monthPayments = payments.filter { $0.month == month }
        return !monthPayments.isEmpty && monthPayments.allSatisfy(\.isPaid)
    }

    private func markMonthAsPaid(month: Int) {
        guard let payments = plan.scheduledPayments else { return }
        let groupId = UUID()
        for payment in payments where payment.month == month {
            markPaymentAsPaid(payment, groupId: groupId)
        }
    }

    /// Marks a single payment as paid, records a Transfer, and checks for payoff celebration
    private func markPaymentAsPaid(_ payment: ScheduledPayment, groupId: UUID? = nil) {
        payment.isPaid = true
        payment.paidDate = Date()

        // Record a Transfer for audit trail
        if let accountID = payment.accountID {
            let toAccount = accounts.first { $0.id == accountID }
            let transfer = Transfer(
                date: Date(),
                amount: payment.totalPayment,
                transferType: .debtPayment,
                notes: "Debt Accelerator - \(plan.name) (Month \(payment.month))",
                interestPortion: payment.interestPortion,
                principalPortion: payment.principalPortion,
                paymentGroupId: groupId ?? UUID()
            )
            transfer.toAccount = toAccount
            modelContext.insert(transfer)

            // Check if this account is now paid off
            if let account = toAccount, account.currentBalance == 0 {
                celebrationAccountName = account.name
                HapticService.play(.success)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showingCelebration = true
                }
            }
        }

        try? modelContext.save()
        refreshTrigger = UUID()
    }

    // MARK: - Helpers

    private func recalculate() async {
        isCalculating = true
        defer { isCalculating = false }

        let debts = debtAccounts.compactMap { DebtInput.fromAccount($0) }
        guard !debts.isEmpty else { return }

        var promoExpirations: [UUID: Int] = [:]
        for account in debtAccounts {
            if let days = account.daysUntilPromoExpires {
                promoExpirations[account.id] = days
            }
        }

        projection = DebtCalculationService.shared.runAcceleratorOptimization(
            debts: debts,
            extraBudget: plan.extraMonthlyPayment,
            vaultAPY: plan.vaultAPY,
            promoExpirations: promoExpirations
        )
    }

    private func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000 {
            return "$\(String(format: "%.1fM", value / 1_000_000))"
        } else if value >= 1_000 {
            return "$\(String(format: "%.0fK", value / 1_000))"
        }
        return "$\(Int(value))"
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebtAcceleratorDetailView(plan: DebtAcceleratorPlan(
            name: "My Plan",
            extraMonthlyPayment: 200,
            vaultAPY: 4.5
        ))
    }
    .modelContainer(for: [DebtAcceleratorPlan.self, Account.self])
}
#endif
