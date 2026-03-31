//  FLOWidgetLiveActivity.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Accessibility Pass
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWidget target (widget extension) - REQUIRED
//  ✅ Main app target - REQUIRED (for MileageLiveActivityAttributes access)
//
//  CHANGES v1.1:
//  ✅ ACCESSIBILITY: Lock Screen banner combines all info into single element
//  ✅ ACCESSIBILITY: Spoken summary includes distance, deduction, start address
//  ✅ ACCESSIBILITY: Paused state announced in accessibility label
//  ✅ ACCESSIBILITY: Decorative icons hidden from VoiceOver
//  ✅ ACCESSIBILITY: Dynamic Island expanded view accessible
//
//  CHANGES v1.0:
//  ✅ ADDED: MileageLiveActivityAttributes with trip data
//  ✅ ADDED: Lock Screen banner with distance, time, deduction, start address
//  ✅ ADDED: Dynamic Island expanded, compact, and minimal states
//  ✅ ADDED: Teal gradient background matching FLO branding
//  ✅ ADDED: Paused state indicator
//  ✅ ADDED: GPS signal indicator
//  ✅ ADDED: Deep linking to flo://mileage

#if os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI


// MARK: - Live Activity Widget

struct FLOWidgetLiveActivity: Widget {
    // Brand colors
    private let widgetTeal = Color(red: 0.078, green: 0.722, blue: 0.651)
    private let widgetTealDark = Color(red: 0.051, green: 0.580, blue: 0.533)
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MileageLiveActivityAttributes.self) { context in
            // LOCK SCREEN BANNER
            lockScreenBanner(context: context)
                .widgetURL(URL(string: "flo://mileage"))
            
        } dynamicIsland: { context in
            DynamicIsland {
                // EXPANDED STATE
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.title3)
                            .foregroundStyle(widgetTeal)
                            .accessibilityHidden(true)  // Decorative icon
                        Text("FLO")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Text(formatDistance(context.state.distanceMiles))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.startTime, style: .timer)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formatDeduction(context.state.estimatedDeduction))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        gpsIndicator(signal: context.state.gpsSignal)
                            .accessibilityHidden(true)  // GPS indicator is decorative
                    }
                    .padding(.horizontal, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Estimated deduction: \(spokenCurrency(context.state.estimatedDeduction))")
                }
                
            } compactLeading: {
                // COMPACT LEADING
                Image(systemName: "car.fill")
                    .font(.caption)
                    .foregroundStyle(widgetTeal)
                    .accessibilityHidden(true)  // Decorative icon
                
            } compactTrailing: {
                // COMPACT TRAILING
                Text(String(format: "%.1f", context.state.distanceMiles))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
            } minimal: {
                // MINIMAL
                Image(systemName: "car.fill")
                    .foregroundStyle(widgetTeal)
                    .accessibilityHidden(true)  // Decorative icon
            }
            .widgetURL(URL(string: "flo://mileage"))
            .keylineTint(widgetTeal)
        }
    }
    
    // MARK: - Lock Screen Banner
    
    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<MileageLiveActivityAttributes>) -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [widgetTeal, widgetTealDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 12) {
                // Top row: Icon + Title | Distance | Deduction
                HStack(alignment: .center, spacing: 12) {
                    // Left: Icon + Title
                    HStack(spacing: 6) {
                        Image(systemName: "car.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)  // Decorative icon
                        Text("FLO Mileage")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    // Center: Distance + Timer
                    VStack(spacing: 2) {
                        Text(formatDistance(context.state.distanceMiles))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        Text(context.attributes.startTime, style: .timer)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Right: Deduction
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Est. Value")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(formatDeduction(context.state.estimatedDeduction))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                
                // Bottom row: Start address + GPS indicator
                HStack(spacing: 8) {
                    Text(context.attributes.startAddress)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    gpsIndicator(signal: context.state.gpsSignal)
                        .accessibilityHidden(true)  // GPS indicator is decorative
                }
                
                // Paused overlay badge
                if context.state.isPaused {
                    HStack {
                        Spacer()
                        Text("PAUSED")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.orange)
                            )
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .contentMargins(.all, 16, for: .automatic)
        }
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: context))
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func gpsIndicator(signal: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(gpsColor(for: signal))
                .frame(width: 6, height: 6)
            
            Text(gpsLabel(for: signal))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDistance(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }
    
    private func formatDeduction(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
    
    private func gpsColor(for signal: String) -> Color {
        switch signal {
        case "strong": return .green
        case "weak": return .orange
        case "searching": return .yellow
        default: return .gray
        }
    }
    
    private func gpsLabel(for signal: String) -> String {
        switch signal {
        case "strong": return "GPS"
        case "weak": return "Weak"
        case "searching": return "Searching"
        default: return "No Signal"
        }
    }
    
    // MARK: - Accessibility Helpers
    
    /// Creates a spoken accessibility label for the Lock Screen banner
    private func accessibilityLabel(for context: ActivityViewContext<MileageLiveActivityAttributes>) -> String {
        if context.state.isPaused {
            return "Mileage trip paused."
        }
        
        let distanceSpoken = spokenDistance(context.state.distanceMiles)
        let deductionSpoken = spokenCurrency(context.state.estimatedDeduction)
        let address = context.attributes.startAddress
        
        return "Mileage trip in progress. Distance: \(distanceSpoken). Estimated deduction: \(deductionSpoken). Started from \(address)."
    }
    
    /// Converts miles to spoken format (e.g., "twelve point four miles")
    private func spokenDistance(_ miles: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.maximumFractionDigits = 1
        
        if let spoken = formatter.string(from: NSNumber(value: miles)) {
            return "\(spoken) miles"
        }
        return "\(String(format: "%.1f", miles)) miles"
    }
    
    /// Converts currency to spoken format (e.g., "eight dollars and ninety nine cents")
    private func spokenCurrency(_ amount: Double) -> String {
        let dollars = Int(amount)
        let cents = Int((amount - Double(dollars)) * 100)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        
        let dollarSpoken = formatter.string(from: NSNumber(value: dollars)) ?? "\(dollars)"
        let centSpoken = formatter.string(from: NSNumber(value: cents)) ?? "\(cents)"
        
        if cents == 0 {
            return "\(dollarSpoken) dollars"
        } else if cents == 1 {
            return "\(dollarSpoken) dollars and one cent"
        } else {
            return "\(dollarSpoken) dollars and \(centSpoken) cents"
        }
    }
}

// MARK: - Preview

#Preview("Active Trip", as: .content, using: MileageLiveActivityAttributes(
    tripId: UUID(),
    startAddress: "123 Main Street, Anytown",
    startTime: Date().addingTimeInterval(-900) // 15 minutes ago
)) {
    FLOWidgetLiveActivity()
} contentStates: {
    // Active trip
    MileageLiveActivityAttributes.ContentState(
        distanceMiles: 12.4,
        elapsedSeconds: 900,
        estimatedDeduction: 8.99,
        isPaused: false,
        gpsSignal: "strong"
    )
    
    // Paused trip
    MileageLiveActivityAttributes.ContentState(
        distanceMiles: 5.7,
        elapsedSeconds: 420,
        estimatedDeduction: 4.13,
        isPaused: true,
        gpsSignal: "searching"
    )
    
    // Just started
    MileageLiveActivityAttributes.ContentState(
        distanceMiles: 0.1,
        elapsedSeconds: 30,
        estimatedDeduction: 0.07,
        isPaused: false,
        gpsSignal: "weak"
    )
}
#endif // os(iOS)
