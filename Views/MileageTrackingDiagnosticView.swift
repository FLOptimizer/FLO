//  MileageTrackingDiagnosticView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Comprehensive diagnostics and troubleshooting for mileage tracking
//
//  ENHANCEMENTS v3.0:
//  - Animated system health indicator with pulse effect
//  - Staggered section entrance animations
//  - Status indicator animations (GPS, battery)
//  - Button press feedback with haptics
//  - Live trip data with animated distance counter
//  - Troubleshooting tips with reveal animation
//

import SwiftUI
import SwiftData
import CoreLocation

struct MileageTrackingDiagnosticView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var trackingService = MileageTrackingService.shared
    
    @Query(sort: \MileageTrip.startDate, order: .reverse) private var recentTrips: [MileageTrip]
    
    // Animation States
    @State private var healthVisible = false
    @State private var statusVisible = false
    @State private var permissionsVisible = false
    @State private var batteryVisible = false
    @State private var databaseVisible = false
    @State private var tipsVisible = false
    @State private var healthPulse = false
    @State private var settingsButtonScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - System Health Overview
                Section {
                    SystemHealthRow(
                        isHealthy: isSystemHealthy,
                        message: systemHealthMessage,
                        issues: systemIssues
                    )
                    .opacity(healthVisible ? 1 : 0)
                    .scaleEffect(healthVisible ? 1 : 0.95)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: healthVisible)
                } header: {
                    Text("System Health")
                }
                
                // MARK: - Tracking Status
                Section("Tracking Status") {
                    DiagnosticRow(
                        title: "Tracking Active",
                        value: trackingService.isTracking ? "Yes" : "No",
                        status: trackingService.isTracking ? .good : .neutral
                    )
                    .opacity(statusVisible ? 1 : 0)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3), value: statusVisible)
                    
                    DiagnosticRow(
                        title: "GPS Signal",
                        value: trackingService.gpsStatus.description,
                        status: gpsStatusLevel
                    )
                    .opacity(statusVisible ? 1 : 0)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: statusVisible)
                    
                    DiagnosticRow(
                        title: "Trip in Progress",
                        value: trackingService.currentTrip != nil ? "Yes" : "No",
                        status: trackingService.currentTrip != nil ? .good : .neutral
                    )
                    .opacity(statusVisible ? 1 : 0)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(0.1), value: statusVisible)
                    
                    // Live trip data
                    if let trip = trackingService.currentTrip {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Trip Details")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("Distance:")
                                Spacer()
                                Text(String(format: "%.2f miles", trackingService.currentDistanceMiles))
                                    .fontWeight(.medium)
                                    .contentTransition(.numericText())
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Started:")
                                Spacer()
                                Text(trip.startDate.formatted(date: .omitted, time: .shortened))
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Duration:")
                                Spacer()
                                Text(trip.startDate, style: .relative)
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Start Address:")
                                Spacer()
                                Text(trip.startAddress)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Error display
                    if let error = trackingService.trackingError {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Error")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                                Text(error.userMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Permissions
                Section("Location Permissions") {
                    DiagnosticRow(
                        title: "Authorization",
                        value: permissionText,
                        status: permissionStatus
                    )
                    .opacity(permissionsVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: permissionsVisible)
                    
                    if trackingService.trackingPermissionStatus == .authorizedWhenInUse {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Limited Tracking Mode")
                                    .fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            
                            Text("You have 'While Using' permission. Trips will ONLY track when the app is visible on screen. For full background tracking, upgrade to 'Always Allow' in Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                openSettingsAnimated()
                            } label: {
                                Label("Open Settings", systemImage: "gearshape.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppConstants.primaryColor)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .opacity(permissionsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: permissionsVisible)
                    }
                    
                    if trackingService.trackingPermissionStatus == .denied ||
                       trackingService.trackingPermissionStatus == .restricted {
                        Button {
                            openSettingsAnimated()
                        } label: {
                            Label("Enable in Settings", systemImage: "gearshape.fill")
                                .frame(maxWidth: .infinity)
                                .scaleEffect(settingsButtonScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .opacity(permissionsVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.15), value: permissionsVisible)
                    }
                }
                
                // MARK: - Battery & Power
                Section("Battery & Power") {
                    HStack {
                        Image(systemName: batteryIcon)
                            .foregroundStyle(batteryColor)
                        Text("Battery Level")
                        Spacer()
                        if trackingService.batteryLevel >= 0 {
                            Text("\(Int(trackingService.batteryLevel * 100))%")
                                .fontWeight(.medium)
                                .foregroundStyle(batteryColor)
                        } else {
                            Text("Unknown")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(batteryVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: batteryVisible)
                    
                    if trackingService.batteryWarning {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "battery.0")
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low Battery Warning")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                                Text("Battery is below 20%. Tracking may be affected. Consider plugging in or stopping tracking.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .opacity(batteryVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: batteryVisible)
                    }
                }
                
                // MARK: - Database
                Section("Database") {
                    DiagnosticRow(
                        title: "ModelContext",
                        value: trackingService.isContextInjected ? "Connected" : "Not Connected",
                        status: trackingService.isContextInjected ? .good : .bad
                    )
                    .opacity(databaseVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3), value: databaseVisible)
                    
                    DiagnosticRow(
                        title: "Total Trips Saved",
                        value: "\(recentTrips.count)",
                        status: .neutral
                    )
                    .opacity(databaseVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: databaseVisible)
                    
                    if let latestTrip = recentTrips.first {
                        HStack {
                            Text("Latest Trip")
                            Spacer()
                            Text(latestTrip.startDate.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .opacity(databaseVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: databaseVisible)
                    }
                }
                
                // MARK: - Troubleshooting Tips
                if !isSystemHealthy {
                    Section("Troubleshooting") {
                        ForEach(Array(systemIssues.enumerated()), id: \.offset) { index, issue in
                            TroubleshootItem(
                                icon: "lightbulb.fill",
                                title: issue,
                                tips: [tipForIssue(issue)]
                            )
                            .opacity(tipsVisible ? 1 : 0)
                            .offset(x: tipsVisible ? 0 : -10)
                            .animation(.easeOut(duration: 0.3).delay(Double(index) * 0.1), value: tipsVisible)
                        }
                    }
                }
            }
            .navigationTitle("Mileage Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {

                        HapticService.play(.medium)
                        dismiss()
                    }
                }
            }
            .onAppear {
                animateEntrance()
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            healthVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
            statusVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
            permissionsVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.3)) {
            batteryVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            databaseVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            tipsVisible = true
        }
    }
    
    private func openSettingsAnimated() {

        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            settingsButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                settingsButtonScale = 1.0
            }
        }
        
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func tipForIssue(_ issue: String) -> String {
        if issue.contains("Permission") {
            return "Go to Settings → Privacy → Location Services → FLO and select 'Always'"
        } else if issue.contains("GPS") {
            return "Ensure you're in an area with good GPS signal, not indoors or in a basement"
        } else if issue.contains("Database") {
            return "Try restarting the app or checking available storage"
        } else if issue.contains("Battery") {
            return "Plug in your device or reduce screen brightness to extend battery life"
        } else if issue.contains("Error") {
            return "Check the error details above for specific guidance"
        }
        return "Check the issue and try again"
    }
    
    // MARK: - Computed Properties
    
    private var isSystemHealthy: Bool {
        trackingService.trackingPermissionStatus == .authorizedAlways &&
        trackingService.gpsStatus == .available &&
        trackingService.isContextInjected &&
        !trackingService.batteryWarning &&
        trackingService.trackingError == nil
    }
    
    private var systemIssues: [String] {
        var issues: [String] = []
        
        if trackingService.trackingPermissionStatus != .authorizedAlways {
            if trackingService.trackingPermissionStatus == .authorizedWhenInUse {
                issues.append("Permission: 'When In Use' (limited)")
            } else {
                issues.append("Permission: Not granted")
            }
        }
        
        if trackingService.gpsStatus != .available {
            issues.append("GPS: \(trackingService.gpsStatus.description)")
        }
        
        if !trackingService.isContextInjected {
            issues.append("Database: Not connected")
        }
        
        if trackingService.batteryWarning {
            issues.append("Battery: Low")
        }
        
        if trackingService.trackingError != nil {
            issues.append("Error: Active")
        }
        
        return issues
    }
    
    private var systemHealthMessage: String {
        if isSystemHealthy {
            return "All systems operational. Ready for tracking."
        }
        return systemIssues.joined(separator: " • ")
    }
    
    private var gpsStatusLevel: DiagnosticStatus {
        switch trackingService.gpsStatus {
        case .available: return .good
        case .lowAccuracy, .searching: return .warning
        case .unavailable, .unknown: return .bad
        }
    }
    
    private var permissionText: String {
        switch trackingService.trackingPermissionStatus {
        case .authorizedAlways: return "Always Allow ✓"
        case .authorizedWhenInUse: return "When In Use ⚠️"
        case .denied: return "Denied ✕"
        case .restricted: return "Restricted ✕"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }
    
    private var permissionStatus: DiagnosticStatus {
        switch trackingService.trackingPermissionStatus {
        case .authorizedAlways: return .good
        case .authorizedWhenInUse: return .warning
        default: return .bad
        }
    }
    
    private var batteryIcon: String {
        let level = trackingService.batteryLevel
        if level < 0 { return "battery.100" }
        if level < 0.2 { return "battery.0" }
        if level < 0.5 { return "battery.25" }
        if level < 0.8 { return "battery.75" }
        return "battery.100"
    }
    
    private var batteryColor: Color {
        let level = trackingService.batteryLevel
        if level < 0 { return .secondary }
        if level < 0.2 { return .red }
        if level < 0.5 { return .orange }
        return .green
    }
}

// MARK: - Supporting Views

enum DiagnosticStatus {
    case good, warning, bad, neutral
    
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .bad: return .red
        case .neutral: return .secondary
        }
    }
}

struct SystemHealthRow: View {
    let isHealthy: Bool
    let message: String
    let issues: [String]
    
    @State private var pulse = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isHealthy ? .green : .orange)
                .scaleEffect(pulse ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isHealthy ? "All Systems Go" : "Issues Detected")
                    .font(.headline)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            if isHealthy {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }
}

struct DiagnosticRow: View {
    let title: String
    let value: String
    let status: DiagnosticStatus
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(status.color)
        }
    }
}

struct ConfigRow: View {
    let title: String
    let value: String
    let detail: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
                    .foregroundStyle(AppConstants.primaryColor)
            }
            
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TroubleshootItem: View {
    let icon: String
    let title: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.yellow)
                Text(title)
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("→")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    MileageTrackingDiagnosticView()
        .modelContainer(for: [MileageTrip.self], inMemory: true)
}
