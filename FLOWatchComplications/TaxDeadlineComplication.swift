//  TaxDeadlineComplication.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Tax Deadline Watch Face Complication
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatchComplications (watchOS widget extension)
//
//  COMPLICATION FAMILIES:
//  - accessoryCircular: Days count in circle
//  - accessoryRectangular: Payment amount + deadline + days
//  - accessoryInline: "Q1 Tax: $2,340 in 14d"
//
//  Premium+ feature. Shows placeholder for free tier.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct TaxDeadlineProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> TaxDeadlineEntry {
        TaxDeadlineEntry(
            date: Date(),
            paymentFormatted: "$0",
            paymentRaw: 0,
            deadlineShort: "—",
            daysUntilDeadline: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TaxDeadlineEntry) -> Void) {
        completion(loadCurrentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TaxDeadlineEntry>) -> Void) {
        let entry = loadCurrentEntry()
        // Refresh every 30 minutes (tax data changes slowly)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> TaxDeadlineEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.finchandpoppy.flo"),
              let data = defaults.data(forKey: "watch.complication.spending") else {
            return TaxDeadlineEntry(date: Date(), paymentFormatted: "—", paymentRaw: 0, deadlineShort: "—", daysUntilDeadline: nil)
        }
        
        do {
            let complication = try JSONDecoder().decode(WatchComplicationData.self, from: data)
            return TaxDeadlineEntry(
                date: Date(),
                paymentFormatted: complication.taxPaymentFormatted,
                paymentRaw: complication.taxPaymentRaw,
                deadlineShort: complication.taxDeadlineShort,
                daysUntilDeadline: complication.daysUntilTaxDeadline
            )
        } catch {
            return TaxDeadlineEntry(date: Date(), paymentFormatted: "—", paymentRaw: 0, deadlineShort: "—", daysUntilDeadline: nil)
        }
    }
}

// MARK: - Timeline Entry

struct TaxDeadlineEntry: TimelineEntry {
    let date: Date
    let paymentFormatted: String
    let paymentRaw: Double
    let deadlineShort: String
    let daysUntilDeadline: Int?
}

// MARK: - Widget

struct TaxDeadlineComplication: Widget {
    let kind = "com.finchandpoppy.flo.complication.tax"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaxDeadlineProvider()) { entry in
            TaxDeadlineComplicationView(entry: entry)
        }
        .configurationDisplayName("Tax Deadline")
        .description("Track your quarterly tax payment and upcoming deadline.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Views

struct TaxDeadlineComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: TaxDeadlineEntry
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    private var circularView: some View {
        VStack(spacing: 0) {
            Image(systemName: "building.columns")
                .font(.caption2)
            
            if let days = entry.daysUntilDeadline {
                Text("\(days)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("days")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            } else {
                Text("—")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
        .widgetAccentable()
    }
    
    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Tax Payment Due")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                Text(entry.paymentFormatted)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .widgetAccentable()
                
                HStack(spacing: 3) {
                    if let days = entry.daysUntilDeadline {
                        Image(systemName: days <= 7 ? "exclamationmark.triangle" : "calendar")
                            .font(.system(size: 8))
                        Text(deadlineText(days))
                            .font(.system(size: 8))
                    } else {
                        Text("No upcoming deadline")
                            .font(.system(size: 8))
                    }
                }
                .foregroundColor(deadlineColor)
            }
            Spacer()
        }
    }
    
    private var inlineView: some View {
        if let days = entry.daysUntilDeadline {
            Text("Tax \(entry.paymentFormatted) in \(days)d")
        } else {
            Text("Tax: \(entry.paymentFormatted)")
        }
    }
    
    // MARK: - Helpers
    
    private func deadlineText(_ days: Int) -> String {
        if days <= 0 { return "Due today!" }
        if days == 1 { return "Due tomorrow" }
        return "\(days) days left"
    }
    
    private var deadlineColor: Color {
        guard let days = entry.daysUntilDeadline else { return .secondary }
        if days <= 0 { return .red }
        if days <= 7 { return .orange }
        if days <= 14 { return .yellow }
        return .secondary
    }
}

#Preview(as: .accessoryRectangular) {
    TaxDeadlineComplication()
} timeline: {
    TaxDeadlineEntry(date: Date(), paymentFormatted: "$2,340", paymentRaw: 2340, deadlineShort: "14d", daysUntilDeadline: 14)
}
