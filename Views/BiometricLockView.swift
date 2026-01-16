//  BiometricLockView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Lock screen with biometric and passcode authentication
//
//  ENHANCEMENTS v3.0:
//  - Animated lock icon with pulse effect on appear
//  - Haptic feedback on authentication attempts
//  - Smooth transition animations between states
//  - Button press scale effects
//  - Success unlock animation with celebration haptic
//  - Error state shake animation
//  - Biometric button glow effect
//

import SwiftUI

struct BiometricLockView: View {
    @ObservedObject private var authService = BiometricAuthService.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    @State private var showPasscodeEntry = false
    @State private var biometricFailed = false
    @State private var hasAttemptedAuth = false
    
    // Animation States
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var iconPulse = false
    @State private var biometricButtonScale: CGFloat = 1.0
    @State private var passcodeButtonScale: CGFloat = 1.0
    @State private var unlockButtonScale: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var glowOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            if showPasscodeEntry {
                // Show passcode entry view
                PasscodeEntryView(onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        showPasscodeEntry = false
                    }
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Show biometric prompt
                VStack(spacing: 32) {
                    // App Icon with animations
                    ZStack {
                        // Glow effect
                        Circle()
                            .fill(Color.teal.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .blur(radius: 20)
                            .opacity(glowOpacity)
                            .scaleEffect(iconPulse ? 1.2 : 1.0)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.teal)
                            .scaleEffect(iconScale)
                            .scaleEffect(iconPulse ? 1.05 : 1.0)
                    }
                    .opacity(iconOpacity)
                    .offset(x: shakeOffset)
                    
                    // Title
                    Text("FLO")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)
                    
                    // Subtitle
                    Text(biometricFailed ? "Authentication Failed" : "Unlock to Continue")
                        .font(.headline)
                        .foregroundStyle(biometricFailed ? .red : .white.opacity(0.7))
                        .opacity(titleOpacity)
                        .animation(.easeInOut(duration: 0.2), value: biometricFailed)
                    
                    // Biometric Button (only show if biometrics available)
                    if authService.isBiometricAvailable && authService.biometricEnabled {
                        Button {
                            triggerBiometricAuth()
                        } label: {
                            VStack(spacing: 12) {
                                ZStack {
                                    // Button glow
                                    Circle()
                                        .fill(Color.teal.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                        .blur(radius: 10)
                                        .opacity(glowOpacity)
                                    
                                    Image(systemName: biometricIcon)
                                        .font(.system(size: 50))
                                        .foregroundStyle(.teal)
                                }
                                
                                Text(biometricText)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }
                            .padding(32)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .scaleEffect(biometricButtonScale)
                        }
                        .padding(.top, 20)
                        .opacity(buttonOpacity)
                    }
                    
                    // Passcode Option (always show if passcode is set)
                    if passcodeService.hasPasscode() {
                                            Button {
                            HapticService.play(.medium)
                            
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                passcodeButtonScale = 0.95
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    passcodeButtonScale = 1.0
                                }
                            }
                            
                            withAnimation(.spring(response: 0.3)) {
                                showPasscodeEntry = true
                            }
                        } label: {
                            Text("Use Passcode")
                                .font(.headline)
                                .foregroundStyle(.teal)
                                .padding()
                                .scaleEffect(passcodeButtonScale)
                        }
                        .opacity(buttonOpacity)
                    }
                    
                    // If security is disabled, show unlock button
                    if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                        Button {
                            HapticService.play(.medium)
                            
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                unlockButtonScale = 0.95
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    unlockButtonScale = 1.0
                                }
                            }
                            
                            authService.markAuthenticated()
                        } label: {
                            Text("Unlock")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.teal)
                                )
                                .scaleEffect(unlockButtonScale)
                        }
                        .opacity(buttonOpacity)
                    }
                }
            }
        }
        .onAppear {
            animateEntrance()
            
            // Auto-unlock if both biometric and passcode are disabled
            if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                authService.markAuthenticated()
                return
            }
            
            // Only auto-trigger biometrics once on appear
            if !hasAttemptedAuth && authService.biometricEnabled && authService.isBiometricAvailable {
                hasAttemptedAuth = true
                // Small delay to let the view settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    authenticateWithBiometrics()
                }
            }
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Icon entrance
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            iconScale = 1.0
            iconOpacity = 1.0
        }
        
        // Title fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
            titleOpacity = 1.0
        }
        
        // Buttons fade in
        withAnimation(.easeOut(duration: 0.4).delay(0.4)) {
            buttonOpacity = 1.0
        }
        
        // Start glow animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            glowOpacity = 0.6
        }
        
        // Start pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
            iconPulse = true
        }
    }
    
    private func triggerShake() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
            shakeOffset = 10
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            shakeOffset = 0
        }
    }
    
    private func triggerBiometricAuth() {
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            biometricButtonScale = 0.95
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                biometricButtonScale = 1.0
            }
        }
        
        authenticateWithBiometrics()
    }
    
    // MARK: - Helper Properties
    
    private var biometricIcon: String {
        switch authService.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock.fill"
        }
    }
    
    private var biometricText: String {
        switch authService.biometricType {
        case .faceID:
            return "Unlock with Face ID"
        case .touchID:
            return "Unlock with Touch ID"
        default:
            return "Unlock"
        }
    }
    
    // MARK: - Authentication
    
    private func authenticateWithBiometrics() {
        // Use the centralized service - NO duplicate LAContext!
        authService.authenticateWithBiometrics { success in
            if success {
                // Success haptic celebration
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Secondary celebration haptic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    HapticService.play(.heavy)
                }
                
                biometricFailed = false
                // Auth service already set isAuthenticated = true
                
                #if DEBUG
                print("✅ Biometric authentication successful")
                #endif
                
            } else {
                // Failure
                triggerShake()
                biometricFailed = true
                
                // Clear error after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        biometricFailed = false
                    }
                }
                
                #if DEBUG
                print("❌ Biometric authentication failed")
                #endif
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BiometricLockView()
}

#Preview("Failed State") {
    BiometricLockView()
}
