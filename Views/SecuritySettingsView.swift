//  SecuritySettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
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
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
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
                                    impactMedium.impactOccurred()
                                    authService.setBiometricEnabled(true)
                                    notificationFeedback.notificationOccurred(.success)
                                } else {
                                    if passcodeService.hasPasscode() {
                                        impactLight.impactOccurred()
                                        authService.setBiometricEnabled(false)
                                    } else {
                                        impactHeavy.impactOccurred()
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
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
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
                        }
                        
                        Button {
                            impactMedium.impactOccurred()
                            showingChangePasscode = true
                        } label: {
                            Label("Change Passcode", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            impactHeavy.impactOccurred()
                            showingRemovePasscodeAlert = true
                        } label: {
                            Label("Remove Passcode", systemImage: "trash")
                        }
                    } else {
                        Button {
                            impactMedium.impactOccurred()
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
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                
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
                } footer: {
                    if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                        Text("Enable \(authService.biometricTypeString) or set a passcode to protect your financial data")
                            .foregroundStyle(.orange)
                    }
                }
                .opacity(viewAppeared ? 1 : 0)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
            }
            .navigationTitle("Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPasscodeSetup) {
                PasscodeSetupView(isChanging: false) {
                    showingPasscodeSetup = false
                    notificationFeedback.notificationOccurred(.success)
                }
            }
            .sheet(isPresented: $showingChangePasscode) {
                PasscodeSetupView(isChanging: true) {
                    showingChangePasscode = false
                    notificationFeedback.notificationOccurred(.success)
                }
            }
            .alert("Remove Passcode?", isPresented: $showingRemovePasscodeAlert) {
                Button("Cancel", role: .cancel) {
                    impactLight.impactOccurred()
                }
                Button("Remove", role: .destructive) {
                    passcodeService.removePasscode()
                    notificationFeedback.notificationOccurred(.success)
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
                    impactLight.impactOccurred()
                }
                Button("Set Up Passcode") {
                    impactMedium.impactOccurred()
                    showingPasscodeSetup = true
                }
                Button("Disable Anyway", role: .destructive) {
                    authService.setBiometricEnabled(false)
                    notificationFeedback.notificationOccurred(.warning)
                }
            } message: {
                Text("Without \(authService.biometricTypeString) or a passcode, anyone with access to your device can open FLO. Consider setting up a passcode first.")
            }
            .onAppear {
                prepareHaptics()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationFeedback.prepare()
    }
    
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
