//  MileageControlView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Mileage Control for Apple Watch
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  FEATURE GATING:
//  Premium+ required for mileage control.
//  Free tier sees upgrade prompt.
//
//  UX DESIGN:
//  - Large start/stop button (easy to tap while driving)
//  - Live trip stats: distance, time, estimated deduction
//  - GPS signal indicator
//  - Pause/resume for stops
//  - All GPS tracking runs on iPhone — Watch is remote control only
//

import SwiftUI
import WatchKit

struct MileageControlView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    @State private var isSending = false
    
    private var tier: WatchSubscriptionTier {
        session.currentTier
    }
    
    private var trip: WatchMileageStatus? {
        session.snapshot?.activeMileageTrip
    }
    
    var body: some View {
        if tier.hasMileageControl {
            mileageContent
        } else {
            WatchUpgradePrompt(
                featureName: "Mileage Tracking",
                icon: "car.fill"
            )
        }
    }
    
    // MARK: - Main Content
    
    private var mileageContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "car.fill")
                        .foregroundColor(.blue)
                    Text("Mileage")
                        .font(.headline)
                }
                
                if let trip = trip {
                    // Active trip display
                    activeTripView(trip)
                } else {
                    // No active trip — show start button
                    noTripView
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Active Trip
    
    private func activeTripView(_ trip: WatchMileageStatus) -> some View {
        VStack(spacing: 8) {
            // Distance (hero stat)
            Text(String(format: "%.1f mi", trip.distanceMiles))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
            
            // Time elapsed
            Text(formatElapsed(trip.elapsedSeconds))
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Estimated deduction
            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text(formatCurrency(trip.estimatedDeduction))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            // GPS signal
            gpsSignalView(trip.gpsSignal)
            
            // Pause indicator
            if trip.isPaused {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.yellow)
                    Text("Paused")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer().frame(height: 4)
            
            // Control buttons
            HStack(spacing: 16) {
                // Pause / Resume
                Button(action: {
                    togglePause(isPaused: trip.isPaused)
                }) {
                    Image(systemName: trip.isPaused ? "play.fill" : "pause.fill")
                        .font(.body)
                        .foregroundColor(trip.isPaused ? .green : .yellow)
                        .frame(width: 44, height: 44)
                        .background(
                            (trip.isPaused ? Color.green : Color.yellow).opacity(0.15)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending)
                
                // End Trip
                Button(action: {
                    endTrip()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
    }
    
    // MARK: - No Active Trip
    
    private var noTripView: some View {
        VStack(spacing: 12) {
            Text("No active trip")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Today's mileage summary
            if let data = session.snapshot?.complicationData, data.todayTotalMiles > 0 {
                HStack(spacing: 4) {
                    Text("Today:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f mi", data.todayTotalMiles))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            
            // Big start button
            Button(action: {
                startTrip()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                    Text("Start Trip")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(isSending)
            
            if isSending {
                ProgressView()
                    .tint(.blue)
            }
        }
    }
    
    // MARK: - GPS Signal
    
    private func gpsSignalView(_ signal: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: gpsIcon(for: signal))
                .font(.caption2)
            Text(signal.capitalized)
                .font(.system(size: 10))
        }
        .foregroundColor(gpsColor(for: signal))
    }
    
    private func gpsIcon(for signal: String) -> String {
        switch signal {
        case "strong":    return "location.fill"
        case "weak":      return "location"
        case "searching": return "location.slash"
        default:          return "location"
        }
    }
    
    private func gpsColor(for signal: String) -> Color {
        switch signal {
        case "strong":    return .green
        case "weak":      return .yellow
        case "searching": return .red
        default:          return .gray
        }
    }
    
    // MARK: - Actions
    
    private func startTrip() {
        isSending = true
        Task {
            await session.sendCommand(.startMileage)
            isSending = false
            WKInterfaceDevice.current().play(.start)
        }
    }
    
    private func togglePause(isPaused: Bool) {
        isSending = true
        Task {
            if isPaused {
                await session.sendCommand(.resumeMileage)
            } else {
                await session.sendCommand(.pauseMileage)
            }
            isSending = false
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    private func endTrip() {
        isSending = true
        Task {
            await session.sendCommand(.endMileage)
            isSending = false
            WKInterfaceDevice.current().play(.stop)
        }
    }
    
    // MARK: - Formatters
    
    private func formatElapsed(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

#Preview {
    MileageControlView()
        .environmentObject(WatchSessionManager.shared)
}
