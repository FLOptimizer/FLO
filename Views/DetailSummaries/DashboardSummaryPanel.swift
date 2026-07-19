//  DashboardSummaryPanel.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 v1.1 — Zone 3 contextual summary for the Dashboard tab.
//  Three charts: Income vs Spending with budget overlay, Cash Flow trend,
//  Savings Rate gauge. Responds to Timeframe and FinanceMode changes.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ FIXED (iPad §2): Monthly Trends / Cash Flow / Savings Rate showed $0 with
//           seeded data. The panel's `.task` load can run BEFORE the async demo
//           seed finishes, and nothing re-fetched afterward. Now subscribes to
//           `.demoDataSeeded` and reloads — mirrors DashboardView v3.13's fix so
//           the middle and right columns agree on the numbers.

import SwiftUI
import SwiftData
import Charts

// MARK: - Notifications for cross-column communication

extension Notification.Name {
    static let dashboardTimeframeChanged = Notification.Name("dashboardTimeframeChanged")
    static let dashboardFinanceModeChanged = Notification.Name("dashboardFinanceModeChanged")
    /// Posted after demo data finishes seeding so views that loaded before the async
    /// seed completed (notably the Dashboard) can refresh instead of showing empty
    /// state until a manual filter toggle. Demo/DEBUG only.
    static let demoDataSeeded = Notification.Name("demoDataSeeded")
}

struct DashboardSummaryPanel: View {
    @Environment(\.modelContext) private var modelContext

    @State private var timeframe: Timeframe = .thisMonth
    @State private var financeMode: FinanceMode = .all
    @State private var transactions: [Transaction] = []
    @State private var budgets: [Budget] = []
    @State private var dataPoints: [ChartPoint] = []

    // MARK: - Computed

    private var income: Double {
        filteredTransactions.filter { $0.isIncome && !$0.isTransfer }.reduce(0) { $0 + $1.amount }
    }

    private var expenses: Double {
        filteredTransactions.filter { !$0.isIncome && !$0.isTransfer }.reduce(0) { $0 + abs($1.amount) }
    }

    private var netCashFlow: Double { income - expenses }

    private var savingsRate: Double {
        guard income > 0 else { return 0 }
        return (income - expenses) / income
    }

    private var filteredTransactions: [Transaction] {
        switch financeMode {
        case .business:
            return transactions.filter { $0.financeType == .business }
        case .personal:
            return transactions.filter { $0.financeType == .personal }
        case .all:
            return transactions
        }
    }

    /// Total monthly budget (planned + carryOver) for current month's budgets
    private var totalMonthlyBudget: Double {
        let calendar = Calendar.current
        let now = Date()
        return budgets
            .filter { calendar.isDate($0.month, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.planned + $1.carryOver }
    }

    private var hasBudgetData: Bool { totalMonthlyBudget > 0 }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                incomeVsSpendingChart

                cashFlowChart

                savingsRateGauge
            }
            .padding()
        }
        .task { loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .dashboardTimeframeChanged)) { notification in
            if let tf = notification.object as? Timeframe {
                timeframe = tf
                loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dashboardFinanceModeChanged)) { notification in
            if let mode = notification.object as? FinanceMode {
                financeMode = mode
                loadData()
            }
        }
        // v1.1: Demo data seeds asynchronously and can finish AFTER this panel's
        // initial `.task` load, leaving all three charts showing $0. Reload when
        // seeding completes so the right column populates without a manual toggle.
        .onReceive(NotificationCenter.default.publisher(for: .demoDataSeeded)) { _ in
            loadData()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Monthly Trends")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                legendDot(color: .incomeGreen, label: "Income: \(formatted(income))")
                legendDot(color: .expenseRed, label: "Spending: \(formatted(expenses))")
            }

            if hasBudgetData {
                HStack(spacing: 4) {
                    // Dashed line icon
                    Rectangle()
                        .fill(Color.brandWarning)
                        .frame(width: 12, height: 2)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
                                .foregroundStyle(Color.brandWarning)
                        )
                    Text("Budget: \(formatted(totalMonthlyBudget))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Chart 1: Income vs Spending + Budget Line

    private var incomeVsSpendingChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Income vs Spending")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if dataPoints.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        BarMark(
                            x: .value("Period", point.label),
                            y: .value("Amount", point.income),
                            width: .ratio(0.35)
                        )
                        .foregroundStyle(Color.incomeGreen.gradient)
                        .cornerRadius(4)
                        .position(by: .value("Type", "Income"))

                        BarMark(
                            x: .value("Period", point.label),
                            y: .value("Amount", point.spending),
                            width: .ratio(0.35)
                        )
                        .foregroundStyle(Color.expenseRed.gradient)
                        .cornerRadius(4)
                        .position(by: .value("Type", "Spending"))
                    }

                    // Budget cap dashed line per period
                    if hasBudgetData {
                        ForEach(dataPoints) { point in
                            if point.budgetLimit > 0 {
                                // Point marks connected by line to show budget level
                                PointMark(
                                    x: .value("Period", point.label),
                                    y: .value("Budget", point.budgetLimit)
                                )
                                .foregroundStyle(Color.brandWarning)
                                .symbolSize(0) // invisible point, just for the line
                            }
                        }

                        // Horizontal dashed rule at the average budget level for context
                        ForEach(dataPoints) { point in
                            if point.budgetLimit > 0 {
                                LineMark(
                                    x: .value("Period", point.label),
                                    y: .value("Budget", point.budgetLimit)
                                )
                                .foregroundStyle(Color.brandWarning)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                                .interpolationMethod(.monotone)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatCompact(v)).font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Chart 2: Cash Flow

    private var cashFlowChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Cash Flow")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Net: \(formatted(netCashFlow))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(netCashFlow >= 0 ? Color.incomeGreen : Color.expenseRed)
            }

            if dataPoints.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Period", point.label),
                        y: .value("Net", point.cumulativeNet)
                    )
                    .foregroundStyle(Color.brandPrimary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle().fill(Color.brandPrimary).frame(width: 8, height: 8)
                    }

                    AreaMark(
                        x: .value("Period", point.label),
                        y: .value("Net", point.cumulativeNet)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.brandPrimary.opacity(0.2), Color.brandPrimary.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    RuleMark(y: .value("Zero", 0))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [5]))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(formatCompact(v)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
            }
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    // MARK: - Chart 3: Savings Rate Gauge

    private var savingsRateGauge: some View {
        VStack(spacing: 12) {
            Text("Savings Rate")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(gaugeColor.opacity(0.15), lineWidth: 12)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: min(max(savingsRate, 0), 1.0))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: savingsRate)

                VStack(spacing: 2) {
                    Text("\(Int(savingsRate * 100))%")
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundStyle(gaugeColor)
                    Text("saved")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if income > 0 {
                Text("You saved \(formatted(max(income - expenses, 0))) of \(formatted(income)) earned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            SummaryChip(
                icon: savingsRateIcon,
                text: savingsRateLabel,
                style: savingsRateChipStyle
            )
        }
        .padding()
        .background(Color.floSystemGroupedSectionBackground)
        .cornerRadius(12)
    }

    private var gaugeColor: Color {
        if savingsRate >= 0.20 { return Color.incomeGreen }
        if savingsRate >= 0.10 { return Color.brandWarning }
        if savingsRate >= 0 { return Color.expenseRed }
        return Color.expenseRed
    }

    private var savingsRateIcon: String {
        if savingsRate >= 0.20 { return "checkmark.circle.fill" }
        if savingsRate >= 0.10 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }

    private var savingsRateLabel: String {
        if savingsRate >= 0.20 { return "Healthy savings rate" }
        if savingsRate >= 0.10 { return "Room to improve" }
        if savingsRate >= 0 { return "Low savings rate" }
        return "Spending exceeds income"
    }

    private var savingsRateChipStyle: SummaryChip.ChipStyle {
        if savingsRate >= 0.20 { return .success }
        if savingsRate >= 0.10 { return .warning }
        return .urgent
    }

    // MARK: - Empty State

    private var emptyChartPlaceholder: some View {
        Text("No data for this period")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(height: 100)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Data Loading

    private func loadData() {
        let calendar = Calendar.current
        let now = Date()
        let (start, _) = dateRange(for: timeframe, now: now, calendar: calendar)

        // Fetch transactions — exclude future-dated (upcoming) items
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let txDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < tomorrow },
            sortBy: [SortDescriptor(\Transaction.date, order: .forward)]
        )

        do {
            transactions = try modelContext.fetch(txDescriptor)
        } catch {
            transactions = []
        }

        // Fetch budgets (all — we filter by month in computed properties)
        let budgetDescriptor = FetchDescriptor<Budget>()
        do {
            budgets = try modelContext.fetch(budgetDescriptor)
        } catch {
            budgets = []
        }

        buildDataPoints(from: start, to: now, calendar: calendar)
    }

    private func dateRange(for tf: Timeframe, now: Date, calendar: Calendar) -> (Date, Date) {
        switch tf {
        case .thisWeek:
            let weekStart = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date ?? now
            return (weekStart, now)
        case .thisMonth:
            let monthStart = calendar.dateComponents([.calendar, .year, .month], from: now).date ?? now
            return (monthStart, now)
        case .thisYear:
            let yearStart = calendar.dateComponents([.calendar, .year], from: now).date ?? now
            return (yearStart, now)
        }
    }

    // MARK: - Budget Helpers

    /// Total budget for a given month (by matching Budget.month to the same year/month)
    private func budgetTotal(forMonth date: Date, calendar: Calendar) -> Double {
        budgets
            .filter { calendar.isDate($0.month, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.planned + $1.carryOver }
    }

    /// Budget proportioned for a number of days within a month
    private func proportionalBudget(forDays days: Int, inMonth monthDate: Date, calendar: Calendar) -> Double {
        let monthly = budgetTotal(forMonth: monthDate, calendar: calendar)
        guard monthly > 0 else { return 0 }
        let daysInMonth = Double(calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30)
        return monthly * (Double(days) / daysInMonth)
    }

    // MARK: - Build Data Points

    private func buildDataPoints(from start: Date, to end: Date, calendar: Calendar) {
        let txns = filteredTransactions

        switch timeframe {
        case .thisWeek:
            dataPoints = buildDaily(txns: txns, from: start, to: end, calendar: calendar)
        case .thisMonth:
            dataPoints = buildWeekly(txns: txns, from: start, to: end, calendar: calendar)
        case .thisYear:
            dataPoints = buildMonthly(txns: txns, from: start, to: end, calendar: calendar)
        }
    }

    // MARK: - Weekly (This Month)

    private func buildWeekly(txns: [Transaction], from start: Date, to end: Date, calendar: Calendar) -> [ChartPoint] {
        var weekStarts: [Date] = []
        var day = start
        while day <= end {
            weekStarts.append(day)
            day = calendar.date(byAdding: .day, value: 7, to: day) ?? end.addingTimeInterval(1)
        }

        var cumulative: Double = 0
        return weekStarts.map { weekStart in
            let weekEnd = min(
                calendar.date(byAdding: .day, value: 7, to: weekStart) ?? end,
                end.addingTimeInterval(86400)
            )

            let (inc, exp) = totals(txns: txns, from: weekStart, before: weekEnd)
            cumulative += inc - exp

            // How many days in this week chunk
            let days = calendar.dateComponents([.day], from: weekStart, to: min(weekEnd, end.addingTimeInterval(86400))).day ?? 7
            let budget = proportionalBudget(forDays: days, inMonth: start, calendar: calendar)

            let startDay = calendar.component(.day, from: weekStart)
            let endDay = calendar.component(.day, from: min(
                calendar.date(byAdding: .day, value: 6, to: weekStart) ?? end,
                end
            ))
            let monthAbbr = weekStart.formatted(.dateTime.month(.abbreviated))

            return ChartPoint(
                label: "\(monthAbbr) \(startDay)-\(endDay)",
                income: inc,
                spending: exp,
                cumulativeNet: cumulative,
                budgetLimit: budget
            )
        }
    }

    // MARK: - Daily (This Week)

    private func buildDaily(txns: [Transaction], from start: Date, to end: Date, calendar: Calendar) -> [ChartPoint] {
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var cumulative: Double = 0
        var points: [ChartPoint] = []

        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: start) else { continue }
            guard dayDate <= end else { break }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayDate) ?? end
            let (inc, exp) = totals(txns: txns, from: dayDate, before: nextDay)
            cumulative += inc - exp

            let dailyBudget = proportionalBudget(forDays: 1, inMonth: dayDate, calendar: calendar)

            let weekday = calendar.component(.weekday, from: dayDate)
            let index = (weekday + 5) % 7
            let label = dayNames[index]

            points.append(ChartPoint(
                label: label,
                income: inc,
                spending: exp,
                cumulativeNet: cumulative,
                budgetLimit: dailyBudget
            ))
        }
        return points
    }

    // MARK: - Monthly (This Year)

    private func buildMonthly(txns: [Transaction], from start: Date, to end: Date, calendar: Calendar) -> [ChartPoint] {
        let currentMonth = calendar.component(.month, from: end)
        var cumulative: Double = 0
        var points: [ChartPoint] = []
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        for month in 1...currentMonth {
            var comps = calendar.dateComponents([.year], from: end)
            comps.month = month
            comps.day = 1
            guard let monthStart = calendar.date(from: comps) else { continue }

            var endComps = comps
            endComps.month = month + 1
            let monthEnd = calendar.date(from: endComps) ?? end

            let (inc, exp) = totals(txns: txns, from: monthStart, before: monthEnd)
            cumulative += inc - exp

            let monthBudget = budgetTotal(forMonth: monthStart, calendar: calendar)

            points.append(ChartPoint(
                label: monthNames[month - 1],
                income: inc,
                spending: exp,
                cumulativeNet: cumulative,
                budgetLimit: monthBudget
            ))
        }
        return points
    }

    // MARK: - Helpers

    private func totals(txns: [Transaction], from start: Date, before end: Date) -> (income: Double, spending: Double) {
        let slice = txns.filter { $0.date >= start && $0.date < end }
        let inc = slice.filter { $0.isIncome && !$0.isTransfer }.reduce(0.0) { $0 + $1.amount }
        let exp = slice.filter { !$0.isIncome && !$0.isTransfer }.reduce(0.0) { $0 + abs($1.amount) }
        return (inc, exp)
    }

    private func formatted(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    private func formatCompact(_ value: Double) -> String {
        let absVal = abs(value)
        let prefix = value < 0 ? "-" : ""
        if absVal >= 1000 {
            return "\(prefix)$\(String(format: "%.1f", absVal / 1000))k"
        }
        return "\(prefix)$\(Int(absVal))"
    }
}

// MARK: - Chart Data Model

private struct ChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let income: Double
    let spending: Double
    let cumulativeNet: Double
    let budgetLimit: Double
}
