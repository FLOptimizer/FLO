//  MileageTrackingDiagnosticView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.3 - VoiceOver Audit: Diagnostic row accessibility with spoken labels
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.3 - VoiceOver Audit:
//  ✅ ADDED: SystemHealthRow combines children with spoken label "All Systems Go" or "Issues Detected, [issues]"
//  ✅ ADDED: DiagnosticRow combines children with spoken label "GPS Signal: Available" not "checkmark.circle.fill Available"
//  ✅ ADDED: Battery row combines with spoken label "Battery Level, 85 percent"
//  ✅ ADDED: Permission status with spoken emoji replacement ("Always Allow" not "Always Allow ✅") via cleanValueForAccessibility
//  ✅ ADDED: Decorative icons hidden (warning triangles, battery icons, lightbulb icons, arrow icons)
//  ✅ ADDED: TroubleshootItem combines icon + text into single spoken element
//  ✅ FIXED: Garbled UTF-8 emoji handled by cleanValueForAccessibility function (removes ✅⚠️❌ from speech)
//  ✅ VERIFIED: Current trip details already readable with proper labels
//
//  CHANGES v3.2 - Dynamic Type Verification:
//  ✅ FIXED: Section header "System Health" missing lineLimit + minimumScaleFactor
//  ✅ FIXED: DiagnosticRow title and value text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Current trip details text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Error message text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Permission warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Battery level text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Battery warning text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Database row text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: TroubleshootItem text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: SystemHealthRow text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: ConfigRow text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: BulletPoint text missing lineLimit + minimumScaleFactor
//
//  CHANGES v3.1:
//  ✅ Screen change announcement on appear
//  ✅ Fixed garbled UTF-8 characters (arrows, checkmarks)
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
                    .opacity(healthVisible ? 1 : 0.001)
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
                    .opacity(statusVisible ? 1 : 0.001)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3), value: statusVisible)
                    
                    DiagnosticRow(
                        title: "GPS Signal",
                        value: trackingService.gpsStatus.description,
                        status: gpsStatusLevel
                    )
                    .opacity(statusVisible ? 1 : 0.001)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: statusVisible)
                    
                    DiagnosticRow(
                        title: "Trip in Progress",
                        value: trackingService.currentTrip != nil ? "Yes" : "No",
                        status: trackingService.currentTrip != nil ? .good : .neutral
                    )
                    .opacity(statusVisible ? 1 : 0.001)
                    .offset(x: statusVisible ? 0 : -10)
                    .animation(.easeOut(duration: 0.3).delay(0.1), value: statusVisible)
                    
                    // Live trip data
                    if let trip = trackingService.currentTrip {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Trip Details")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("Distance:")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text(String(format: "%.2f miles", trackingService.currentDistanceMiles))
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .contentTransition(.numericText())
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Started:")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text(trip.startDate.formatted(date: .omitted, time: .shortened))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Duration:")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text(trip.startDate, style: .relative)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Text("Start Address:")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Text(trip.startAddress)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
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
                                .accessibilityHidden(true)
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Active Error")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.red)
                                Text(error.userMessage)
                                    .font(.caption)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
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
                    .opacity(permissionsVisible ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.3), value: permissionsVisible)
                    
                    #if !os(macOS)
                    if trackingService.trackingPermissionStatus == .authorizedWhenInUse {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Limited Tracking Mode")
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .font(.subheadline)

                            Text("You have 'While Using' permission. Trips will ONLY track when the app is visible on screen. For full background tracking, upgrade to 'Always Allow' in Settings.")
                                .font(.caption)
                                .lineLimit(4)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)

                            Button {
                                openSettingsAnimated()
                            } label: {
                                Label("Open Settings", systemImage: "gearshape.fill")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.brandPrimary)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .opacity(permissionsVisible ? 1 : 0.001)
                        .animation(.easeOut(duration: 0.3).delay(0.1), value: permissionsVisible)
                    }
                    #endif
                    
                    if trackingService.trackingPermissionStatus == .denied ||
                       trackingService.trackingPermissionStatus == .restricted {
                        Button {
                            openSettingsAnimated()
                        } label: {
                            Label("Enable in Settings", systemImage: "gearshape.fill")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(settingsButtonScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .opacity(permissionsVisible ? 1 : 0.001)
                        .animation(.easeOut(duration: 0.3).delay(0.15), value: permissionsVisible)
                    }
                }
                
                // MARK: - Battery & Power
                Section("Battery & Power") {
                    HStack {
                        Image(systemName: batteryIcon)
                        .accessibilityHidden(true)
                            .foregroundStyle(batteryColor)
                        Text("Battery Level")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        if trackingService.batteryLevel >= 0 {
                            Text("\(Int(trackingService.batteryLevel * 100))%")
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(batteryColor)
                        } else {
                            Text("Unknown")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(trackingService.batteryLevel >= 0
                        ? "Battery Level: \(Int(trackingService.batteryLevel * 100)) percent"
                        : "Battery Level: Unknown")
                    .opacity(batteryVisible ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.3), value: batteryVisible)
                    
                    if trackingService.batteryWarning {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "battery.0")
                                .accessibilityHidden(true)
                                .foregroundStyle(.red)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Low Battery Warning")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.orange)
                                Text("Battery is below 20%. Tracking may be affected. Consider plugging in or stopping tracking.")
                                    .font(.caption)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .opacity(batteryVisible ? 1 : 0.001)
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
                    .opacity(databaseVisible ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.3), value: databaseVisible)
                    
                    DiagnosticRow(
                        title: "Total Trips Saved",
                        value: "\(recentTrips.count)",
                        status: .neutral
                    )
                    .opacity(databaseVisible ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.3).delay(0.05), value: databaseVisible)
                    
                    if let latestTrip = recentTrips.first {
                        HStack {
                            Text("Latest Trip")
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Spacer()
                            Text(latestTrip.startDate.formatted(date: .abbreviated, time: .shortened))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(databaseVisible ? 1 : 0.001)
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
                            .opacity(tipsVisible ? 1 : 0.001)
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
                        // a11y: label from button text

                        HapticService.play(.medium)
                        dismiss()
                    }
                }
            }
            .onAppear {
                animateEntrance()
                AccessibilityAnnouncement.screenChanged("Mileage diagnostics")
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
        
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
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
            #if !os(macOS)
            if trackingService.trackingPermissionStatus == .authorizedWhenInUse {
                issues.append("Permission: 'When In Use' (limited)")
            } else {
                issues.append("Permission: Not granted")
            }
            #else
            issues.append("Permission: Not granted")
            #endif
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
        case .authorizedAlways: return "Always Allow"
        #if !os(macOS)
        case .authorizedWhenInUse: return "When In Use"
        #endif
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Set"
        @unknown default: return "Unknown"
        }
    }

    private var permissionStatus: DiagnosticStatus {
        switch trackingService.trackingPermissionStatus {
        case .authorizedAlways: return .good
        #if !os(macOS)
        case .authorizedWhenInUse: return .warning
        #endif
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
                .accessibilityHidden(true)
                .font(.title2)
                .foregroundStyle(isHealthy ? .green : .orange)
                .scaleEffect(pulse ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isHealthy ? "All Systems Go" : "Issues Detected")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(message)
                    .font(.caption)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isHealthy
            ? "System Health: All Systems Go. Ready for tracking."
            : "System Health: Issues Detected. \(issues.joined(separator: ", "))")
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
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(status.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(cleanValueForAccessibility(value))")
    }
    
    private func cleanValueForAccessibility(_ value: String) -> String {
        // Remove emoji/symbols from accessibility labels
        return value
            .replacingOccurrences(of: "✅", with: "")
            .replacingOccurrences(of: "⚠️", with: "")
            .replacingOccurrences(of: "❌", with: "")
            .trimmingCharacters(in: .whitespaces)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(value)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Color.brandPrimary)
            }
            
            Text(detail)
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
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
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
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
                    .accessibilityHidden(true)
                Text(title)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            
            ForEach(tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("→")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text(tip)
                        .font(.caption)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
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
