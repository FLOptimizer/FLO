//  SpendingSummaryComplication.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Spending Summary Watch Face Complication
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatchComplications (watchOS widget extension)
//
//  COMPLICATION FAMILIES:
//  - accessoryCircular: Dollar amount in circle
//  - accessoryRectangular: Amount + trend + label
//  - accessoryInline: "Spent $142 today"
//  - accessoryCorner: Amount with gauge
//
//  Available to ALL subscription tiers.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct SpendingSummaryProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> SpendingEntry {
        SpendingEntry(
            date: Date(),
            spending: 0,
            formattedSpending: "$0",
            trend: "flat",
            trendPercent: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        let entry = loadCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let entry = loadCurrentEntry()
        
        // Refresh every 15 minutes (complication data is updated by Watch app)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> SpendingEntry {
        // Read from App Group shared defaults
        guard let defaults = UserDefaults(suiteName: "group.com.finchandpoppy.flo"),
              let data = defaults.data(forKey: "watch.complication.spending") else {
            return SpendingEntry(
                date: Date(),
                spending: 0,
                formattedSpending: "$0",
                trend: "flat",
                trendPercent: 0
            )
        }
        
        do {
            let complication = try JSONDecoder().decode(WatchComplicationData.self, from: data)
            return SpendingEntry(
                date: Date(),
                spending: complication.todaySpendingRaw,
                formattedSpending: complication.todaySpendingFormatted,
                trend: complication.spendingTrend,
                trendPercent: complication.spendingTrendPercent
            )
        } catch {
            return SpendingEntry(
                date: Date(),
                spending: 0,
                formattedSpending: "$0",
                trend: "flat",
                trendPercent: 0
            )
        }
    }
}

// MARK: - Timeline Entry

struct SpendingEntry: TimelineEntry {
    let date: Date
    let spending: Double
    let formattedSpending: String
    let trend: String
    let trendPercent: Double
}

// MARK: - Complication Views

struct SpendingSummaryComplication: Widget {
    let kind = "com.finchandpoppy.flo.complication.spending"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingSummaryProvider()) { entry in
            SpendingComplicationView(entry: entry)
        }
        .configurationDisplayName("Today's Spending")
        .description("See how much you've spent today at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct SpendingComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: SpendingEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }
    
    // MARK: - Circular (small circle on watch face)
    
    private var circularView: some View {
        VStack(spacing: 0) {
            Image(systemName: "dollarsign.circle")
                .font(.caption)
            Text(compactAmount)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .widgetAccentable()
    }
    
    // MARK: - Rectangular (medium bar on watch face)
    
    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today's Spending")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(entry.formattedSpending)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .widgetAccentable()
                
                HStack(spacing: 2) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 8))
                    Text(trendText)
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Inline (single line text)
    
    private var inlineView: some View {
        Text("Spent \(entry.formattedSpending) today")
    }
    
    // MARK: - Corner (amount with gauge)
    
    private var cornerView: some View {
        Text(compactAmount)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .widgetAccentable()
    }
    
    // MARK: - Helpers
    
    private var compactAmount: String {
        if entry.spending >= 1000 {
            return "$\(String(format: "%.0f", entry.spending / 1000))k"
        } else if entry.spending >= 100 {
            return "$\(Int(entry.spending))"
        } else {
            return entry.formattedSpending
        }
    }
    
    private var trendIcon: String {
        switch entry.trend {
        case "up":   return "arrow.up.right"
        case "down": return "arrow.down.right"
        default:     return "arrow.right"
        }
    }
    
    private var trendText: String {
        let pct = abs(entry.trendPercent)
        if pct < 1 { return "Flat vs last month" }
        let direction = entry.trend == "up" ? "↑" : "↓"
        return "\(direction) \(String(format: "%.0f", pct))% vs last mo"
    }
}

#Preview(as: .accessoryRectangular) {
    SpendingSummaryComplication()
} timeline: {
    SpendingEntry(date: Date(), spending: 142.50, formattedSpending: "$142.50", trend: "up", trendPercent: 12.5)
}
