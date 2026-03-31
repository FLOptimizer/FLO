//  MileageComplication.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Mileage Watch Face Complication
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatchComplications (watchOS widget extension)
//
//  COMPLICATION FAMILIES:
//  - accessoryCircular: Car icon + miles
//  - accessoryRectangular: Trip status, distance, deduction
//  - accessoryInline: "12.4 mi — $9.00 deduction"
//
//  Premium+ feature.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MileageProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> MileageEntry {
        MileageEntry(
            date: Date(),
            isActive: false,
            milesFormatted: "0 mi",
            todayMiles: 0,
            isPaused: false
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MileageEntry) -> Void) {
        completion(loadCurrentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MileageEntry>) -> Void) {
        let entry = loadCurrentEntry()
        // Refresh every 5 minutes when active, 30 when inactive
        let interval = entry.isActive ? 5 : 30
        let refreshDate = Calendar.current.date(byAdding: .minute, value: interval, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> MileageEntry {
        guard let defaults = UserDefaults(suiteName: "group.com.finchandpoppy.flo"),
              let data = defaults.data(forKey: "watch.complication.spending") else {
            return MileageEntry(date: Date(), isActive: false, milesFormatted: "0 mi", todayMiles: 0, isPaused: false)
        }
        
        do {
            let complication = try JSONDecoder().decode(WatchComplicationData.self, from: data)
            return MileageEntry(
                date: Date(),
                isActive: complication.isMileageActive,
                milesFormatted: complication.currentTripMilesFormatted,
                todayMiles: complication.todayTotalMiles,
                isPaused: false // Complication data doesn't track pause state separately
            )
        } catch {
            return MileageEntry(date: Date(), isActive: false, milesFormatted: "0 mi", todayMiles: 0, isPaused: false)
        }
    }
}

// MARK: - Timeline Entry

struct MileageEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let milesFormatted: String
    let todayMiles: Double
    let isPaused: Bool
}

// MARK: - Widget

struct MileageComplication: Widget {
    let kind = "com.finchandpoppy.flo.complication.mileage"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MileageProvider()) { entry in
            MileageComplicationView(entry: entry)
        }
        .configurationDisplayName("Mileage")
        .description("Track your current trip or today's total miles.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Views

struct MileageComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: MileageEntry
    
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
            Image(systemName: entry.isActive ? "car.fill" : "car")
                .font(.caption)
                .foregroundColor(entry.isActive ? .green : .secondary)
            
            if entry.isActive {
                Text(entry.milesFormatted)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            } else {
                Text(todayCompact)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetAccentable()
    }
    
    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: entry.isActive ? "car.fill" : "car")
                        .font(.system(size: 9))
                        .foregroundColor(entry.isActive ? .green : .secondary)
                    Text(entry.isActive ? "Tracking" : "Mileage")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    if entry.isActive {
                        Circle()
                            .fill(.green)
                            .frame(width: 4, height: 4)
                    }
                }
                
                if entry.isActive {
                    Text(entry.milesFormatted)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .widgetAccentable()
                } else {
                    Text(String(format: "%.1f mi today", entry.todayMiles))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .widgetAccentable()
                }
                
                if entry.todayMiles > 0 && !entry.isActive {
                    let deduction = entry.todayMiles * 0.725
                    Text(String(format: "$%.2f deduction", deduction))
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                }
            }
            Spacer()
        }
    }
    
    private var inlineView: some View {
        if entry.isActive {
            Text("🚗 \(entry.milesFormatted) tracking")
        } else if entry.todayMiles > 0 {
            Text("\(String(format: "%.1f", entry.todayMiles)) mi today")
        } else {
            Text("No trips today")
        }
    }
    
    // MARK: - Helpers
    
    private var todayCompact: String {
        if entry.todayMiles >= 100 {
            return "\(Int(entry.todayMiles))"
        } else if entry.todayMiles > 0 {
            return String(format: "%.1f", entry.todayMiles)
        } else {
            return "0"
        }
    }
}

#Preview(as: .accessoryRectangular) {
    MileageComplication()
} timeline: {
    MileageEntry(date: Date(), isActive: true, milesFormatted: "12.4 mi", todayMiles: 24.8, isPaused: false)
    MileageEntry(date: Date(), isActive: false, milesFormatted: "0 mi", todayMiles: 24.8, isPaused: false)
}
