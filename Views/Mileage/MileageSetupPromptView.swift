//  MileageSetupPromptView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.6 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.6 - Dynamic Type Verification:
//  ✅ FIXED: "Set Up Mileage Tracking" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Setup description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Privacy First" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Privacy description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "For best results" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Tip description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Full tracking enabled!" status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Limited mode" status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Limited Tracking Mode" title missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Limited mode description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "What this means:" header missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Limited mode row text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Settings button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: "Continue with Limited Mode" button text missing lineLimit + minimumScaleFactor
//
//  CHANGES v1.4:
//  ✅ Decorative header icons hidden from VoiceOver
//  ✅ Privacy note icon hidden, row combined
//  ✅ Status indicators combined with spoken labels
//  ✅ Limited mode rows combined for VoiceOver
//
//  CHANGES v1.3:
//  ✅ FIXED: Multiple sheets presenting simultaneously
//  ✅ Limited mode explanation now embedded in this view
//  ✅ Removed showingLimitedModeSheet binding (no longer needed)
//  ✅ Single sheet handles entire setup flow
//
//  PREVIOUS (v1.2):
//  - Changed "Enable Tracking" button to "Continue" per Apple guideline 5.1.1
//  - Removed "Maybe Later" skip button
//
//  This view is shown when user visits Mileage Tracking without completing setup.
//  This is now the ONLY entry point for mileage setup (removed from onboarding).

import SwiftUI
import CoreLocation

struct MileageSetupPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: MileageSetupLocationManager
    
    let onSetupComplete: () -> Void
    
    @State private var hasRequestedPermission = false
    @State private var hasRequestedAlways = false
    @State private var showingLimitedModeContent = false
    
    var body: some View {
        Group {
            if showingLimitedModeContent {
                limitedModeContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                setupContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingLimitedModeContent)
        .onChange(of: locationManager.authorizationStatus) { oldValue, newValue in
            handleAuthorizationChange(from: oldValue, to: newValue)
        }
    }
    
    // MARK: - Setup Content
    
    private var setupContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "car.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)
                
                Text("Set Up Mileage Tracking")
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                
                Text("To track trips automatically, FLO needs location access.")
                    .font(.body)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 32)
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Mileage tracking setup")
            }
            
            // Privacy note
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy First")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your location data never leaves your device.")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Tip
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    Text("For best results")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
                
                Text("Select \"Always Allow\" when prompted to record trips even when FLO is in the background.")
                    .font(.subheadline)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Status indicator (if permission already granted)
            if locationManager.authorizationStatus == .authorizedAlways {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                    Text("Full tracking enabled!")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
            }
            #if !os(macOS)
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("Limited mode - upgrade for background tracking")
                        .font(.subheadline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .accessibilityElement(children: .combine)
            }
            #endif
            
            // Main action button - NO skip option per Apple guideline 5.1.1
            Button {
                HapticService.play(.medium)
                requestLocationPermission()
            } label: {
                HStack {
                    Image(systemName: buttonIcon)
                        .accessibilityHidden(true)
                    Text(buttonTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonColor)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
            
            // Note: "Maybe Later" / skip button removed per Apple guideline 5.1.1
            // Users must proceed to the iOS permission dialog
        }
    }
    
    // MARK: - Limited Mode Content (Embedded)
    
    private var limitedModeContent: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                }
                .accessibilityHidden(true)
                
                Text("Limited Tracking Mode")
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                
                Text("Without \"Always Allow\", FLO can only track trips while the app is open on your screen.")
                    .font(.body)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 24)
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Limited tracking mode")
            }
            
            // What this means
            VStack(alignment: .leading, spacing: 12) {
                Text("What this means:")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                limitedModeRow(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    text: "No automatic trip detection"
                )
                
                limitedModeRow(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    text: "Tracking stops when app is backgrounded"
                )
                
                limitedModeRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    text: "Manual trip entry still works"
                )
            }
            .padding()
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    HapticService.play(.medium)
                    openSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .accessibilityHidden(true)
                        Text("Open Phone Settings")
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .cornerRadius(12)
                }
                
                Button {
                    HapticService.play(.light)
                    onSetupComplete()
                } label: {
                    Text("Continue with Limited Mode")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private func limitedModeRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Button Properties
    
    private var buttonIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        #if !os(macOS)
        case .authorizedWhenInUse:
            return "gearshape.fill"
        #endif
        case .denied, .restricted:
            return "gearshape.fill"
        default:
            return "location.fill"
        }
    }

    private var buttonTitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "All Set - Continue"
        #if !os(macOS)
        case .authorizedWhenInUse:
            return "Open Phone Settings"
        #endif
        case .denied, .restricted:
            return "Open Phone Settings"
        default:
            return "Continue"
        }
    }

    private var buttonColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        #if !os(macOS)
        case .authorizedWhenInUse:
            return .orange
        #endif
        case .denied, .restricted:
            return .orange
        default:
            return Color.brandPrimary
        }
    }
    
    // MARK: - Actions
    
    private func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            hasRequestedPermission = true
            locationManager.requestWhenInUseAuthorization()

        #if !os(macOS)
        case .authorizedWhenInUse:
            openSettings()
        #endif

        case .authorizedAlways:
            HapticService.play(.success)
            onSetupComplete()
            
        case .denied, .restricted:
            openSettings()
            
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    private func handleAuthorizationChange(from oldValue: CLAuthorizationStatus, to newValue: CLAuthorizationStatus) {
        guard hasRequestedPermission else { return }
        
        switch newValue {
        case .authorizedAlways:
            HapticService.play(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onSetupComplete()
            }
            
        #if !os(macOS)
        case .authorizedWhenInUse:
            if oldValue == .notDetermined {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasRequestedAlways = true
                    locationManager.requestAlwaysAuthorization()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if locationManager.authorizationStatus == .authorizedWhenInUse {
                        withAnimation {
                            showingLimitedModeContent = true
                        }
                    }
                }
            }
        #endif
            
        case .denied, .restricted:
            withAnimation {
                showingLimitedModeContent = true
            }
            
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    MileageSetupPromptView(
        locationManager: MileageSetupLocationManager(),
        onSetupComplete: {}
    )
}
