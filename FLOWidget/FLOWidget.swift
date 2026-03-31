//  FLOWidget.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - VoiceOver Audit: Widget accessibility for home screen
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2 - VoiceOver Audit:
//  ✅ ADDED: SmallWidgetView combines into single spoken element "FLO: Balance five thousand dollars"
//  ✅ ADDED: MediumWidgetView combines with summary "FLO: Balance five thousand dollars. 42 transactions today"
//  ✅ ADDED: LargeWidgetView combines with detailed summary including income, expenses, and quick stats
//  ✅ ADDED: All decorative icons hidden (chart icons, arrow icons, calendar icons, document icons)
//  ✅ VERIFIED: Widget color constants widgetTeal and widgetTealDark unchanged
//  ✅ VERIFIED: Each widget size provides contextually appropriate spoken summary
//
//  CHANGES v2.1 - Dark Mode Optimization:
//  ✅ ADDED: widgetTeal and widgetTealDark color constants at file scope
//  ✅ FIXED: Replaced 5 instances of Color(red: 0.078, green: 0.722, blue: 0.651) with widgetTeal
//  ✅ FIXED: Replaced 2 instances of Color(red: 0.051, green: 0.580, blue: 0.533) with widgetTealDark
//  ✅ NOTE: Widgets use local constants (cannot access ColorSchemeManager in extension process)
//
//  CHANGES FROM v2.0:
//  - Updated to use WidgetDataService v1.3 data structure
//  - Changed to async data loading with fetchWidgetData()
//  - Uses actual data: balance, income, expenses, quickStats
//  - Removed mock data structures (topCategories, recentTransactions)
//  - Simplified to display real financial data
//
//  CHANGES FROM v1.0:
//  - Updated to use WidgetDataService v1.3 data structure
//  - Changed to async data loading with fetchWidgetData()
//  - Uses actual data: balance, income, expenses, quickStats
//  - Removed mock data structures (topCategories, recentTransactions)
//  - Simplified to display real financial data
//

import WidgetKit
import SwiftUI

// MARK: - Release Build Print Silencer (Widget Target)

#if !DEBUG
@inline(__always)
func print(_ items: Any..., separator: String = " ", terminator: String = "\n") { }
#endif

// MARK: - Widget Color Constants

private let widgetTeal = Color(red: 0.078, green: 0.722, blue: 0.651)
private let widgetTealDark = Color(red: 0.051, green: 0.580, blue: 0.533)

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), data: placeholderData())
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        Task {
            let data = await loadWidgetData()
            let entry = WidgetEntry(date: Date(), data: data)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let currentDate = Date()
            let data = await loadWidgetData()
            let entry = WidgetEntry(date: currentDate, data: data)
            
            // Update every 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadWidgetData() async -> WidgetData {
        do {
            return try await WidgetDataService.shared.fetchWidgetData()
        } catch {
            print("⚠️ Widget failed to load data: \(error.localizedDescription)")
            return placeholderData()
        }
    }
    
    private func placeholderData() -> WidgetData {
        WidgetData(
            balance: 5432.10,
            income: 10000.00,
            expenses: 4567.90,
            transactionCount: 42,
            lastUpdated: Date(),
            quickStats: WidgetData.QuickStats(
                thisWeekExpenses: 234.56,
                thisMonthExpenses: 1234.56,
                pendingInvoicesCount: 3,
                upcomingTaxDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date())
            )
        )
    }
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .accessibilityHidden(true)
                Text("FLO")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
            
            Text(entry.data.balance, format: .currency(code: "USD"))
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            
            Text("Net Balance")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            
            Text("\(entry.data.transactionCount) Transactions")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [widgetTeal, widgetTealDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        
        let balanceSpoken = formatter.string(from: NSNumber(value: entry.data.balance)) ?? "zero dollars"
        return "FLO: Balance \(balanceSpoken)"
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 0) {
            // Left side - Balance
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                        .accessibilityHidden(true)
                    Text("FLO")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                Spacer()
                
                Text(entry.data.balance, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.7)
                
                Text("Net Balance")
                    .font(.caption)
                    .opacity(0.8)
                
                Text("\(entry.data.transactionCount) Transactions")
                    .font(.caption2)
                    .opacity(0.6)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [widgetTeal, widgetTealDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Right side - Details
            VStack(alignment: .leading, spacing: 12) {
                // Income/Expense Summary
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text("Income")
                            .font(.caption)
                        Spacer()
                        Text(entry.data.income, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .accessibilityHidden(true)
                        Text("Expenses")
                            .font(.caption)
                        Spacer()
                        Text(entry.data.expenses, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }
                
                Divider()
                
                // Quick Stats
                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .opacity(0.7)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .accessibilityHidden(true)
                        Text("Spent")
                            .font(.caption2)
                        Spacer()
                        Text(entry.data.quickStats.thisMonthExpenses, format: .currency(code: "USD"))
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    
                    if entry.data.quickStats.pendingInvoicesCount > 0 {
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text("Pending")
                                .font(.caption2)
                            Spacer()
                            Text("\(entry.data.quickStats.pendingInvoicesCount) invoices")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        
        let balanceSpoken = formatter.string(from: NSNumber(value: entry.data.balance)) ?? "zero dollars"
        var label = "FLO: Balance \(balanceSpoken). \(entry.data.transactionCount) transactions"
        
        if entry.data.quickStats.pendingInvoicesCount > 0 {
            label += ". \(entry.data.quickStats.pendingInvoicesCount) pending invoice\(entry.data.quickStats.pendingInvoicesCount == 1 ? "" : "s")"
        }
        
        return label
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundStyle(widgetTeal)
                    .accessibilityHidden(true)
                
                Text("FLO")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(entry.data.balance, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Net Balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Income/Expense Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityHidden(true)
                        Text("Income")
                            .font(.subheadline)
                    }
                    Text(entry.data.income, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.red)
                            .accessibilityHidden(true)
                        Text("Expenses")
                            .font(.subheadline)
                    }
                    Text(entry.data.expenses, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Spending Breakdown
            VStack(alignment: .leading, spacing: 8) {
                Text("Spending Overview")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.data.quickStats.thisWeekExpenses, format: .currency(code: "USD"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.data.quickStats.thisMonthExpenses, format: .currency(code: "USD"))
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                }
                
                if entry.data.quickStats.pendingInvoicesCount > 0 {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(widgetTeal)
                            .accessibilityHidden(true)
                        Text("\(entry.data.quickStats.pendingInvoicesCount) pending invoice\(entry.data.quickStats.pendingInvoicesCount == 1 ? "" : "s")")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(widgetTeal.opacity(0.1))
                    .cornerRadius(6)
                }
                
                if let taxDeadline = entry.data.quickStats.upcomingTaxDeadline {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text("Tax deadline: \(taxDeadline, style: .date)")
                            .font(.caption)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("\(entry.data.transactionCount) transactions")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Updated \(entry.data.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    private var accessibilityLabel: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        
        let balanceSpoken = formatter.string(from: NSNumber(value: entry.data.balance)) ?? "zero dollars"
        let incomeSpoken = formatter.string(from: NSNumber(value: entry.data.income)) ?? "zero dollars"
        let expensesSpoken = formatter.string(from: NSNumber(value: entry.data.expenses)) ?? "zero dollars"
        let weekSpoken = formatter.string(from: NSNumber(value: entry.data.quickStats.thisWeekExpenses)) ?? "zero dollars"
        let monthSpoken = formatter.string(from: NSNumber(value: entry.data.quickStats.thisMonthExpenses)) ?? "zero dollars"
        
        var label = "FLO: Balance \(balanceSpoken). Income \(incomeSpoken), Expenses \(expensesSpoken). This week spent \(weekSpoken), this month spent \(monthSpoken)"
        
        if entry.data.quickStats.pendingInvoicesCount > 0 {
            label += ". \(entry.data.quickStats.pendingInvoicesCount) pending invoice\(entry.data.quickStats.pendingInvoicesCount == 1 ? "" : "s")"
        }
        
        if let taxDeadline = entry.data.quickStats.upcomingTaxDeadline {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            let deadlineSpoken = dateFormatter.string(from: taxDeadline)
            label += ". Tax deadline \(deadlineSpoken)"
        }
        
        return label
    }
}

// MARK: - Widget Configuration

struct FLOWidget: Widget {
    let kind: String = "FLOWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FLOWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("FLO")
        .description("Track your finances at a glance")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Entry View

struct FLOWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: Provider.Entry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    FLOWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(
        balance: 5432.10,
        income: 10000.00,
        expenses: 4567.90,
        transactionCount: 42,
        lastUpdated: Date(),
        quickStats: WidgetData.QuickStats(
            thisWeekExpenses: 234.56,
            thisMonthExpenses: 1234.56,
            pendingInvoicesCount: 3,
            upcomingTaxDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date())
        )
    ))
}

#Preview(as: .systemMedium) {
    FLOWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(
        balance: 5432.10,
        income: 10000.00,
        expenses: 4567.90,
        transactionCount: 42,
        lastUpdated: Date(),
        quickStats: WidgetData.QuickStats(
            thisWeekExpenses: 234.56,
            thisMonthExpenses: 1234.56,
            pendingInvoicesCount: 3,
            upcomingTaxDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date())
        )
    ))
}

#Preview(as: .systemLarge) {
    FLOWidget()
} timeline: {
    WidgetEntry(date: .now, data: WidgetData(
        balance: 5432.10,
        income: 10000.00,
        expenses: 4567.90,
        transactionCount: 42,
        lastUpdated: Date(),
        quickStats: WidgetData.QuickStats(
            thisWeekExpenses: 234.56,
            thisMonthExpenses: 1234.56,
            pendingInvoicesCount: 3,
            upcomingTaxDeadline: Calendar.current.date(byAdding: .day, value: 15, to: Date())
        )
    ))
}
