//  TodaySummaryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Today's Summary for Apple Watch
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  DESIGN:
//  The "home" screen of the Watch app. Shows:
//  - Today's spending total (hero number)
//  - Week/month context
//  - Quick recent transactions list
//  - Stale data indicator when snapshot is old
//  All tiers see this view.
//

import SwiftUI

struct TodaySummaryView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    
    private var summary: WatchDaySummary? {
        session.snapshot?.todaySummary
    }
    
    private var transactions: [WatchTransaction] {
        session.snapshot?.recentTransactions ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Stale data warning
                if let generated = session.snapshot?.generatedAt {
                    StaleDataBanner(lastUpdated: generated)
                }
                
                // FLO header
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("FLO")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 2)
                
                if let summary = summary {
                    // Today's spending (hero number)
                    VStack(spacing: 2) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatCurrency(summary.todaySpending))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(summary.todaySpending > 0 ? .red : .green)
                        
                        if summary.todayIncome > 0 {
                            Text("+" + formatCurrency(summary.todayIncome) + " income")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Divider().padding(.horizontal, 8)
                    
                    // Week & month context
                    HStack(spacing: 16) {
                        VStack(spacing: 1) {
                            Text("Week")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatCompact(summary.weekSpending))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        VStack(spacing: 1) {
                            Text("Month")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatCompact(summary.monthSpending))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    // Spending trend
                    if let data = session.snapshot?.complicationData {
                        trendBadge(trend: data.spendingTrend, percent: data.spendingTrendPercent)
                    }
                    
                    Divider().padding(.horizontal, 8)
                    
                    // Recent transactions (first 5)
                    if !transactions.isEmpty {
                        VStack(spacing: 0) {
                            Text("Recent")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 2)
                            
                            ForEach(transactions.prefix(5)) { txn in
                                transactionRow(txn)
                            }
                        }
                        
                        if transactions.count > 5 {
                            NavigationLink {
                                RecentTransactionsView()
                                    .environmentObject(session)
                            } label: {
                                Text("See All (\(transactions.count))")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "tray")
                                .foregroundColor(.secondary)
                            Text("No transactions today")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                    }
                } else {
                    ProgressView()
                        .tint(.blue)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Transaction Row
    
    private func transactionRow(_ txn: WatchTransaction) -> some View {
        HStack(spacing: 6) {
            Image(systemName: txn.categoryIcon)
                .font(.caption2)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(txn.merchantName)
                    .font(.caption2)
                    .lineLimit(1)
                Text(txn.categoryName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(txn.formattedAmount)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(txn.isIncome ? .green : .primary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }
    
    // MARK: - Trend Badge
    
    private func trendBadge(trend: String, percent: Double) -> some View {
        HStack(spacing: 3) {
            Image(systemName: trendIcon(trend))
                .font(.system(size: 9))
            Text(trendText(trend, percent: percent))
                .font(.system(size: 9))
        }
        .foregroundColor(trendColor(trend))
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(trendColor(trend).opacity(0.1))
        .cornerRadius(4)
    }
    
    private func trendIcon(_ trend: String) -> String {
        switch trend {
        case "up":   return "arrow.up.right"
        case "down": return "arrow.down.right"
        default:     return "arrow.right"
        }
    }
    
    private func trendText(_ trend: String, percent: Double) -> String {
        let pct = abs(percent)
        switch trend {
        case "up":   return String(format: "%.0f%% vs last month", pct)
        case "down": return String(format: "%.0f%% vs last month", pct)
        default:     return "Flat vs last month"
        }
    }
    
    private func trendColor(_ trend: String) -> Color {
        switch trend {
        case "up":   return .red
        case "down": return .green
        default:     return .secondary
        }
    }
    
    // MARK: - Formatters
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
    
    private func formatCompact(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(Int(amount))"
    }
}

#Preview {
    TodaySummaryView()
        .environmentObject(WatchSessionManager.shared)
}
