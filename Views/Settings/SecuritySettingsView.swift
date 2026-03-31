//  SecuritySettingsView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - Fixed invalid SF Symbol
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.5:
//  ✅ FIXED: Invalid SF Symbol "lock.badge.plus" → "key.fill" (symbol doesn't exist)
//
//  CHANGES v1.4 - VoiceOver Audit:
//  ✅ ADDED: Biometric icon (Face ID/Touch ID) hidden from VoiceOver (text describes it)
//  ✅ ADDED: Lock icon in passcode status hidden (text describes status)
//  ✅ ADDED: Lock badge plus icon in "Set Up Passcode" hidden (text describes action)
//  ✅ ADDED: Pencil icon in "Change Passcode" button hidden (text describes action)
//  ✅ ADDED: Trash icon in "Remove Passcode" button hidden (text describes action)
//  ✅ ADDED: Shield icons in Security Status hidden (spoken status describes it)
//  ✅ ADDED: Biometric toggle hint explaining what it does
//  ✅ VERIFIED: Checkmark icon already hidden
//  ✅ VERIFIED: Screen change announcement already present
//
//  CHANGES v1.3 - Dynamic Type Verification:
//  ✅ FIXED: Biometric toggle label text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Biometric toggle description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Passcode status text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Passcode length description text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Security status "Protected"/"Not Protected" text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section footer text missing lineLimit + minimumScaleFactor
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
            ScrollView {
                VStack(spacing: 16) {
                    ProfileHeaderCard(
                        icon: "lock.shield.fill",
                        title: "Security & Privacy",
                        subtitle: "Manage authentication and app protection",
                        color: .brandPrimary
                    )

                    // Biometric Section
                    if authService.isBiometricAvailable {
                        ProfileSectionCard(title: "Biometric Authentication") {
                            ProfileToggleRow(
                                icon: biometricIcon,
                                label: authService.biometricTypeString,
                                isOn: Binding(
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
                                ),
                                subtitle: "Quick unlock with \(authService.biometricTypeString)",
                                iconColor: .brandPrimary
                            )
                            .accessibilityHint("Enables \(authService.biometricTypeString) to unlock FLO")

                            ProfileFooterNote(
                                icon: biometricIcon,
                                text: "Use \(authService.biometricTypeString) to quickly unlock FLO"
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                        }
                        .opacity(viewAppeared ? 1 : 0.001)
                        .offset(y: viewAppeared ? 0 : 10)
                        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
                    }

                    // Passcode Section
                    ProfileSectionCard(title: "Passcode") {
                        if passcodeService.hasPasscode() {
                            HStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.body)
                                    .foregroundStyle(Color.brandPrimary)
                                    .frame(width: 24, alignment: .center)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Passcode")
                                        .font(.body)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    Text("\(passcodeService.getPasscodeLength())-digit passcode enabled")
                                        .font(.caption)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .symbolEffect(.bounce, value: viewAppeared)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .accessibilityElement(children: .combine)

                            ProfileActionRow(icon: "pencil", label: "Change Passcode", style: .branded) {
                                HapticService.play(.medium)
                                showingChangePasscode = true
                            }

                            ProfileActionRow(icon: "trash", label: "Remove Passcode", style: .destructive) {
                                HapticService.play(.heavy)
                                showingRemovePasscodeAlert = true
                            }
                        } else {
                            ProfileActionRow(icon: "key.fill", label: "Set Up Passcode", style: .branded) {
                                HapticService.play(.medium)
                                showingPasscodeSetup = true
                            }
                        }

                        ProfileFooterNote(
                            icon: "info.circle",
                            text: passcodeService.hasPasscode()
                                ? "Passcode can be used as an alternative to \(authService.biometricTypeString)"
                                : "Set a passcode for an alternative unlock method"
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

                    // Security Status Section
                    ProfileSectionCard(title: "Security Status") {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.fill")
                                .font(.body)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 24, alignment: .center)
                                .accessibilityHidden(true)

                            Text("Security Status")
                                .font(.body)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            Spacer()

                            if authService.biometricEnabled || passcodeService.hasPasscode() {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(.green)
                                        .symbolEffect(.bounce, value: viewAppeared)
                                        .accessibilityHidden(true)
                                    Text("Protected")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.green)
                                        .font(.subheadline)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .foregroundStyle(.orange)
                                        .symbolEffect(.pulse, value: viewAppeared)
                                        .accessibilityHidden(true)
                                    Text("Not Protected")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(.orange)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Security status: \(authService.biometricEnabled || passcodeService.hasPasscode() ? "Protected" : "Not protected")")

                        if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                            ProfileFooterNote(
                                icon: "exclamationmark.triangle",
                                text: "Enable \(authService.biometricTypeString) or set a passcode to protect your financial data"
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 4)
                        }
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
                }
                .padding(16)
            }
            .navigationTitle("Security")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
