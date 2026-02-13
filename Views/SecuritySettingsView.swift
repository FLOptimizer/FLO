//  SecuritySettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Accessibility audit (Sprint 6b)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ Full VoiceOver accessibility coverage
//  ✅ Screen change announcement on appear
//  ✅ Passcode status row: checkmark hidden, combined with spoken status
//  ✅ Security status row: combined with spoken protection status
//  ✅ Fixed garbled UTF-8 characters
//
//  CHANGES v1.1:
//  ✅ Haptic feedback on toggle changes
//  ✅ Haptic on button taps
//  ✅ Section entrance animations
//  ✅ Security status icon animation
//  ✅ Checkmark animation
//
//  PREVIOUS (v1.0):
//  - Basic security settings for passcode and biometrics

import SwiftUI

struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = BiometricAuthService.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    @State private var showingPasscodeSetup = false
    @State private var showingChangePasscode = false
    @State private var showingRemovePasscodeAlert = false
    @State private var showingDisableBiometricAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                        
    var body: some View {
        NavigationStack {
            List {
                // Biometric Section
                if authService.isBiometricAvailable {
                    Section {
                        Toggle(isOn: Binding(
                            get: { authService.biometricEnabled },
                            set: { newValue in
                                if newValue {
                                    HapticService.play(.medium)
                                    authService.setBiometricEnabled(true)
                                    HapticService.play(.success)
                                } else {
                                    if passcodeService.hasPasscode() {
                                        HapticService.play(.light)
                                        authService.setBiometricEnabled(false)
                                    } else {
                                        HapticService.play(.heavy)
                                        showingDisableBiometricAlert = true
                                    }
                                }
                            }
                        )) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(authService.biometricTypeString)
                                    Text("Quick unlock with \(authService.biometricTypeString)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: biometricIcon)
                                    .foregroundStyle(AppConstants.primaryColor)
                            }
                        }
                    } header: {
                        Text("Biometric Authentication")
                    } footer: {
                        Text("Use \(authService.biometricTypeString) to quickly unlock FLO")
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                }
                
                // Passcode Section
                Section {
                    if passcodeService.hasPasscode() {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Passcode")
                                    Text("\(passcodeService.getPasscodeLength())-digit passcode enabled")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(AppConstants.primaryColor)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .symbolEffect(.bounce, value: viewAppeared)
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .combine)
                        
                        Button {
                            HapticService.play(.medium)
                            showingChangePasscode = true
                        } label: {
                            Label("Change Passcode", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            HapticService.play(.heavy)
                            showingRemovePasscodeAlert = true
                        } label: {
                            Label("Remove Passcode", systemImage: "trash")
                        }
                    } else {
                        Button {
                            HapticService.play(.medium)
                            showingPasscodeSetup = true
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set Up Passcode")
                                    Text("Add a backup unlock method")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "lock.badge.plus")
                                    .foregroundStyle(AppConstants.primaryColor)
                            }
                        }
                    }
                } header: {
                    Text("Passcode")
                } footer: {
                    if passcodeService.hasPasscode() {
                        Text("Passcode can be used as an alternative to \(authService.biometricTypeString)")
                    } else {
                        Text("Set a passcode for an alternative unlock method")
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
                
                // Security Status Section
                Section {
                    HStack {
                        Label("Security Status", systemImage: "shield.fill")
                        Spacer()
                        if authService.biometricEnabled || passcodeService.hasPasscode() {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                                    .symbolEffect(.bounce, value: viewAppeared)
                                Text("Protected")
                                    .foregroundStyle(.green)
                                    .font(.subheadline)
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundStyle(.orange)
                                    .symbolEffect(.pulse, value: viewAppeared)
                                Text("Not Protected")
                                    .foregroundStyle(.orange)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Security status: \(authService.biometricEnabled || passcodeService.hasPasscode() ? "Protected" : "Not protected")")
                } footer: {
                    if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                        Text("Enable \(authService.biometricTypeString) or set a passcode to protect your financial data")
                            .foregroundStyle(.orange)
                    }
                }
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPasscodeSetup) {
                PasscodeSetupView(isChanging: false) {
                    showingPasscodeSetup = false
                    HapticService.play(.success)
                }
            }
            .sheet(isPresented: $showingChangePasscode) {
                PasscodeSetupView(isChanging: true) {
                    showingChangePasscode = false
                    HapticService.play(.success)
                }
            }
            .alert("Remove Passcode?", isPresented: $showingRemovePasscodeAlert) {
                Button("Cancel", role: .cancel) {
                    HapticService.play(.light)
                }
                Button("Remove", role: .destructive) {
                    passcodeService.removePasscode()
                    HapticService.play(.success)
                }
            } message: {
                if authService.biometricEnabled {
                    Text("You can still use \(authService.biometricTypeString) to unlock the app.")
                } else {
                    Text("Your app will no longer be protected. Anyone with access to your device can open FLO.")
                }
            }
            .alert("Disable \(authService.biometricTypeString)?", isPresented: $showingDisableBiometricAlert) {
                Button("Cancel", role: .cancel) {
                    HapticService.play(.light)
                }
                Button("Set Up Passcode") {
                    HapticService.play(.medium)
                    showingPasscodeSetup = true
                }
                Button("Disable Anyway", role: .destructive) {
                    authService.setBiometricEnabled(false)
                    HapticService.play(.warning)
                }
            } message: {
                Text("Without \(authService.biometricTypeString) or a passcode, anyone with access to your device can open FLO. Consider setting up a passcode first.")
            }
            .onAppear {
                                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Security settings")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Computed Properties
    
    private var biometricIcon: String {
        switch authService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.shield.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    SecuritySettingsView()
}
