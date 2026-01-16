//  PasscodeEntryView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Passcode entry view for unlocking the app
//
//  ENHANCEMENTS v3.0:
//  - Number button press animations with scale and color effects
//  - Dot fill animations with spring physics
//  - Enhanced shake animation on incorrect passcode
//  - Success celebration with sequential haptics
//  - Lockout countdown with pulsing effect
//  - Biometric button hover state
//  - Smooth transitions between states
//

import SwiftUI
import Combine

struct PasscodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = BiometricAuthService.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    @State private var passcode = ""
    @State private var isError = false
    @State private var isShaking = false
    @State private var attempts = 0
    @State private var isLocked = false
    @State private var lockoutEndTime: Date?
    @State private var timerCancellable: AnyCancellable?
    
    // Animation States
    @State private var headerOpacity: Double = 0
    @State private var headerScale: CGFloat = 0.9
    @State private var dotsVisible = false
    @State private var keypadOpacity: Double = 0
    @State private var pressedButton: Int? = nil
    @State private var lockoutPulse = false
    @State private var successScale: CGFloat = 1.0
    
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 60
    
    // Callback for when user wants to go back to biometric screen
    var onDismiss: (() -> Void)?
    
    // Use stored length from PasscodeService
    private var passcodeLength: Int {
        passcodeService.getPasscodeLength()
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AppConstants.primaryColor)
                        .symbolEffect(.bounce, value: isError)
                    
                    Text("Enter Passcode")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    if isLocked, let endTime = lockoutEndTime {
                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .scaleEffect(lockoutPulse ? 1.1 : 1.0)
                            
                            Text("Too many attempts")
                                .font(.caption)
                                .foregroundStyle(.red)
                            
                            Text("Try again in \(timeRemaining(until: endTime))")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else if isError {
                        Text("Incorrect Passcode")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .scaleEffect(headerScale)
                .opacity(headerOpacity)
                
                // Passcode Dots - uses dynamic length
                HStack(spacing: 20) {
                    ForEach(0..<passcodeLength, id: \.self) { index in
                        PasscodeDot(
                            isFilled: index < passcode.count,
                            isError: isError,
                            delay: Double(index) * 0.05
                        )
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(passcode.count) of \(passcodeLength) digits entered")
                .offset(x: isShaking ? -10 : 0)
                .animation(isShaking ? .easeInOut(duration: 0.05).repeatCount(4, autoreverses: true) : .default, value: isShaking)
                .scaleEffect(successScale)
                .opacity(dotsVisible ? 1 : 0)
                
                // Number Pad
                VStack(spacing: 20) {
                    ForEach([1, 4, 7], id: \.self) { row in
                        HStack(spacing: 30) {
                            ForEach(row..<row+3, id: \.self) { number in
                                NumberPadButton(
                                    number: number,
                                    isPressed: pressedButton == number,
                                    isDisabled: isLocked
                                ) {
                                    addDigit(number)
                                }
                            }
                        }
                    }
                    
                    // Bottom Row: Back/Biometric, 0, Delete
                    HStack(spacing: 30) {
                        // Back to biometric or empty
                        if authService.isBiometricAvailable && authService.biometricEnabled {
                            BiometricButton(
                                icon: biometricIcon,
                                isDisabled: isLocked
                            ) {
                                HapticService.play(.medium)
                                onDismiss?()
                            }
                            .accessibilityLabel(authService.biometricType == .faceID ? "Use Face ID" : "Use Touch ID")
                        } else {
                            Color.clear.frame(width: 70, height: 70)
                        }
                        
                        // Zero Button
                        NumberPadButton(
                            number: 0,
                            isPressed: pressedButton == 0,
                            isDisabled: isLocked
                        ) {
                            addDigit(0)
                        }
                        
                        // Delete Button
                        DeleteButton(isDisabled: passcode.isEmpty || isLocked) {
                            deleteLastDigit()
                        }
                    }
                }
                .opacity(keypadOpacity)
            }
        }
        .onAppear {
            animateEntrance()
            startLockoutTimer()
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            dotsVisible = true
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
            keypadOpacity = 1.0
        }
        
        // Start lockout pulse if needed
        if isLocked {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                lockoutPulse = true
            }
        }
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
    
    // MARK: - Actions
    
    private func addDigit(_ digit: Int) {
        guard !isLocked else { return }
        guard passcode.count < passcodeLength else { return }
        
        // Button press animation
        pressedButton = digit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pressedButton = nil
        }
        
        HapticService.play(.medium)
        
        passcode += "\(digit)"
        
        if passcode.count == passcodeLength {
            verifyPasscode()
        }
    }
    
    private func deleteLastDigit() {
        guard !passcode.isEmpty else { return }
        
        HapticService.play(.medium)
        
        passcode.removeLast()
    }
    
    private func verifyPasscode() {
        if passcodeService.verifyPasscode(passcode) {
            // Success
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Success scale animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                successScale = 1.15
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    successScale = 1.0
                }
                
                // Celebration haptic
                HapticService.play(.heavy)
            }
            
            // Reset attempts
            attempts = 0
            
            // Clear passcode from memory
            passcode = ""
            
            // Mark as authenticated - NO biometric prompt!
            authService.markAuthenticated()
            
            #if DEBUG
            print("✅ Passcode verified, user authenticated")
            #endif
            
        } else {
            // Failed
            attempts += 1
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            // Show error
            withAnimation(.spring(response: 0.3)) {
                isError = true
            }
            
            // Shake animation
            shakeAnimation()
            
            // Clear passcode
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                passcode = ""
                
                withAnimation {
                    isError = false
                }
            }
            
            // Check if should lock out
            if attempts >= maxAttempts {
                isLocked = true
                lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
                
                // Start pulse animation
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    lockoutPulse = true
                }
                
                #if DEBUG
                print("🔒 Too many failed attempts. Locked for \(lockoutDuration) seconds")
                #endif
            }
        }
    }
    
    private func shakeAnimation() {
        withAnimation(.easeInOut(duration: 0.05).repeatCount(4, autoreverses: true)) {
            isShaking = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation {
                isShaking = false
            }
        }
    }
    
    private func startLockoutTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if let end = self.lockoutEndTime, Date() >= end {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isLocked = false
                        self.lockoutEndTime = nil
                        self.attempts = 0
                        self.lockoutPulse = false
                    }
                }
            }
    }
    
    private func timeRemaining(until endTime: Date) -> String {
        let remaining = max(0, Int(endTime.timeIntervalSinceNow))
        let minutes = remaining / 60
        let seconds = remaining % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Passcode Dot

private struct PasscodeDot: View {
    let isFilled: Bool
    let isError: Bool
    let delay: Double
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(isFilled ? (isError ? Color.red : AppConstants.primaryColor) : Color.white.opacity(0.3))
            .frame(width: 16, height: 16)
            .scaleEffect(scale)
            .onChange(of: isFilled) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5).delay(delay)) {
                        scale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }
            }
    }
}

// MARK: - Number Pad Button

private struct NumberPadButton: View {
    let number: Int
    let isPressed: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.title)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(isPressed ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .accessibilityLabel("\(number)")
        .disabled(isDisabled)
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Biometric Button

private struct BiometricButton: View {
    let icon: String
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(AppConstants.primaryColor)
                .frame(width: 70, height: 70)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .disabled(isDisabled)
    }
}

// MARK: - Delete Button

private struct DeleteButton: View {
    let isDisabled: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
            action()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 70, height: 70)
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .accessibilityLabel("Delete")
        .accessibilityHint("Removes last digit")
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#Preview {
    PasscodeEntryView()
}
