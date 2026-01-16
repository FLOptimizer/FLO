//  MileageSetupPromptView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed Always Permission Flow
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Track if Always permission was already requested
//  ✅ Direct to Settings if user previously declined Always
//  ✅ iOS only shows Always prompt once - subsequent taps go to Settings
//
//  PREVIOUS (v1.0):
//  Shown when user visits Mileage Tracking without completing setup
//  This is the "Option B" fallback for users who:
//  - Skipped mileage setup during onboarding
//  - Upgraded to Premium/Pro after initial onboarding
//  - Haven't granted location permission yet

import SwiftUI
import CoreLocation

struct MileageSetupPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager: MileageSetupLocationManager
    @Binding var showingLimitedModeSheet: Bool
    
    let onSetupComplete: () -> Void
    let onSkipForNow: () -> Void
    
    @State private var hasRequestedPermission = false
    @State private var hasRequestedAlways = false
    
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "car.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                }
                
                Text("Set Up Mileage Tracking")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text("To track trips automatically, FLO needs location access.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 32)
            
            // Privacy note
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color(flowHex: "14B8A6"))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy First")
                        .font(.headline)
                    Text("Your location data never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Tip
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("For best results")
                        .font(.subheadline.bold())
                }
                
                Text("Select \"Always Allow\" when prompted to record trips even when FLO is in the background.")
                    .font(.subheadline)
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
                    Text("Full tracking enabled!")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else if locationManager.authorizationStatus == .authorizedWhenInUse {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Limited mode - upgrade for background tracking")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    impactMedium.impactOccurred()
                    requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: buttonIcon)
                        Text(buttonTitle)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonColor)
                    .cornerRadius(12)
                }
                
                Button {
                    onSkipForNow()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onChange(of: locationManager.authorizationStatus) { oldValue, newValue in
            handleAuthorizationChange(from: oldValue, to: newValue)
        }
    }
    
    private var buttonIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        case .authorizedWhenInUse:
            return "gearshape.fill" // Always go to settings for When In Use
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
        case .authorizedWhenInUse:
            return "Open Phone Settings"
        case .denied, .restricted:
            return "Open Phone Settings"
        default:
            return "Enable Tracking"
        }
    }
    
    private var buttonColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse, .denied, .restricted:
            return .orange
        default:
            return Color(flowHex: "14B8A6")
        }
    }
    
    private func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            hasRequestedPermission = true
            locationManager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse:
            // Always direct to Settings - iOS only shows Always prompt once
            // and by the time they reach this fallback view, they likely already declined
            openSettings()
            
        case .authorizedAlways:
            notificationFeedback.notificationOccurred(.success)
            onSetupComplete()
            
        case .denied, .restricted:
            openSettings()
            
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func handleAuthorizationChange(from oldValue: CLAuthorizationStatus, to newValue: CLAuthorizationStatus) {
        guard hasRequestedPermission else { return }
        
        switch newValue {
        case .authorizedAlways:
            notificationFeedback.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onSetupComplete()
            }
            
        case .authorizedWhenInUse:
            if oldValue == .notDetermined {
                // Just got When In Use - try requesting Always
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    hasRequestedAlways = true
                    locationManager.requestAlwaysAuthorization()
                }
                
                // Check after delay if they declined Always
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if locationManager.authorizationStatus == .authorizedWhenInUse {
                        showingLimitedModeSheet = true
                    }
                }
            }
            
        case .denied, .restricted:
            showingLimitedModeSheet = true
            
        default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    MileageSetupPromptView(
        locationManager: MileageSetupLocationManager(),
        showingLimitedModeSheet: .constant(false),
        onSetupComplete: {},
        onSkipForNow: {}
    )
}
