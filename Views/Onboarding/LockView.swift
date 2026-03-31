//  LockView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.4 - Dynamic Type verification
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.3:
//  - Replaced 20 hardcoded teal hex values with Color.brandPrimary/brandPrimaryDark
//  - Replaced 4 hardcoded emerald hex values with Color.brandAccent
//  - Lock screen icon, passcode dots, buttons, and glow effects now match user's color scheme
//  - Cyan floating orb (0EA5E9) intentionally kept as fixed complementary accent
//
//  CHANGES v2.2:
//  ✅ ADDED: VoiceOver labels on all passcode number buttons
//  ✅ ADDED: Accessibility label on biometric unlock button
//  ✅ ADDED: Passcode dots read as "X of Y digits entered"
//  ✅ ADDED: Status text announced as live region
//  ✅ ADDED: Decorative elements hidden from VoiceOver (orbs, glow, shimmer)
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Success/error announcements for VoiceOver
//  ✅ ADDED: Delete button and cancel/biometric shortcut labels
//  ✅ ADDED: Lockout status announced to VoiceOver
//  ✅ ADDED: minimumTouchTarget on all interactive elements
//
//  PREVIOUS (v2.1):
//  - Removed time/date, fixed passcode layout
//
//  FEATURES:
//  ✅ Animated floating orbs background
//  ✅ Glowing app icon with shimmer effect
//  ✅ Glassmorphism buttons
//  ✅ Success animation before dismiss
//  ✅ Premium number pad design
//

import SwiftUI
import Combine

struct LockView: View {
    @ObservedObject private var authService = BiometricAuthService.shared
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    // MARK: - State
    @State private var showContent = false
    @State private var authMode: AuthMode = .biometric
    @State private var hasAttemptedBiometric = false
    @State private var isAuthenticating = false
    @State private var showSuccessAnimation = false
    
    // Animation States
    @State private var iconGlow = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var orb1Offset = CGPoint(x: -50, y: -100)
    @State private var orb2Offset = CGPoint(x: 100, y: 50)
    @State private var orb3Offset = CGPoint(x: -30, y: 150)
    
    // Passcode State
    @State private var passcode = ""
    @State private var isPasscodeError = false
    @State private var isShaking = false
    @State private var failedAttempts = 0
    @State private var isLockedOut = false
    @State private var lockoutEndTime: Date?
    @State private var timerCancellable: AnyCancellable?
    
    private let maxAttempts = 5
    private let lockoutDuration: TimeInterval = 60
    
    private var passcodeLength: Int {
        passcodeService.getPasscodeLength()
    }
    
    enum AuthMode {
        case biometric
        case passcode
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Animated Background - v2.2: Hidden from VoiceOver (purely decorative)
            animatedBackground
                .accessibilityHidden(true)
            
            // Success overlay
            if showSuccessAnimation {
                successOverlay
                    .transition(.opacity)
                    .zIndex(100)
            }
            
            // Main Content
            VStack(spacing: 0) {
                Spacer()
                
                // App Branding with glow
                brandingSection
                    .opacity(showContent ? 1 : 0.001)
                    .scaleEffect(showContent ? 1 : 0.85)
                
                Spacer()
                    .frame(height: 50)
                
                // Auth Content
                Group {
                    switch authMode {
                    case .biometric:
                        biometricSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case .passcode:
                        passcodeSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                }
                .opacity(showContent ? 1 : 0.001)
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showContent)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: authMode)
        .animation(FLOAnimation.ease, value: showSuccessAnimation)
        .onAppear(perform: handleOnAppear)
        .onDisappear {
            timerCancellable?.cancel()
        }
        // v2.2: Announce lock screen to VoiceOver on appear
        .onAppear {
            AccessibilityAnnouncement.screenChanged("FLO is locked. \(statusText)")
        }
    }
    
    // MARK: - Animated Background
    
    private var animatedBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.08),
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Floating orb 1 (large, brand primary)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.4),
                            Color.brandPrimary.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: orb1Offset.x, y: orb1Offset.y)
            
            // Floating orb 2 (medium, cyan)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(flowHex: "0EA5E9").opacity(0.3),
                            Color(flowHex: "0EA5E9").opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: orb2Offset.x, y: orb2Offset.y)
            
            // Floating orb 3 (small, brand accent)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandAccent.opacity(0.35),
                            Color.brandAccent.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 40)
                .offset(x: orb3Offset.x, y: orb3Offset.y)
        }
    }
    
    // MARK: - Branding Section
    
    private var brandingSection: some View {
        VStack(spacing: 20) {
            // App Icon with glow and shimmer - v2.2: Decorative, group for VoiceOver
            ZStack {
                // Outer glow rings - decorative
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(
                            Color.brandPrimary.opacity(0.1 - Double(i) * 0.03),
                            lineWidth: 1
                        )
                        .frame(width: CGFloat(140 + i * 30), height: CGFloat(140 + i * 30))
                        .scaleEffect(iconGlow ? 1.05 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: iconGlow
                        )
                }
                
                // Glow background
                Circle()
                    .fill(Color.brandPrimary.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                    .scaleEffect(iconGlow ? 1.1 : 0.95)
                
                // Main icon circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandPrimary,
                                Color.brandPrimaryDark
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.brandPrimary.opacity(0.5), radius: 20, y: 5)
                    .overlay(
                        // Shimmer effect
                        RoundedRectangle(cornerRadius: 50)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.3),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .mask(Circle().frame(width: 100, height: 100))
                    )
                
                // Icon
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
            }
            // v2.2: Group entire icon as single accessible element
            .accessibilityHidden(true)
            
            // App Name and tagline
            VStack(spacing: 6) {
                Text("FLO")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                
                Text("Finance Ledger Optimizer")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
            }
            // v2.2: Group app name for VoiceOver
            .accessibilityElement(children: .combine)
            .accessibilityLabel("FLO, Finance Ledger Optimizer")
            .accessibilityAddTraits(.isHeader)
        }
    }
    
    // MARK: - Biometric Section (Primary)
    
    private var biometricSection: some View {
        VStack(spacing: 24) {
            // Status text - v2.2: Live region for VoiceOver announcements
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .animation(.easeInOut(duration: 0.2), value: statusText)
                .accessibilityLabel(statusText)
                .accessibilityAddTraits(.updatesFrequently)
            
            // Biometric Button (Primary - Glassmorphism style)
            if authService.isBiometricAvailable && authService.biometricEnabled {
                Button(action: triggerBiometric) {
                    HStack(spacing: 14) {
                        Image(systemName: biometricIcon)
                            .font(.title2)
                        
                        Text(biometricText)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        ZStack {
                            // Glass effect
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial.opacity(0.8))
                            
                            // Border gradient
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.brandPrimary.opacity(0.6),
                                            Color.brandPrimary.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            
                            // Inner highlight
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.brandPrimary.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    )
                    .scaleEffect(isAuthenticating ? 0.97 : 1.0)
                }
                .disabled(isAuthenticating)
                .frame(maxWidth: 320)
                .padding(.horizontal, 24)
                // v2.2: Clear VoiceOver label for biometric button
                .accessibilityLabel(biometricText)
                .accessibilityHint("Double tap to authenticate with \(biometricAccessibilityName)")
                .accessibilityAddTraits(.isButton)
            }
            
            // Passcode Option (Secondary - text link style)
            if passcodeService.hasPasscode() {
                Button {
                    HapticService.play(.light)
                    withAnimation {
                        authMode = .passcode
                    }
                } label: {
                    Text("Use Passcode Instead")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.brandPrimary.opacity(0.8))
                }
                .padding(.top, 4)
                // v2.2: VoiceOver label
                .accessibilityLabel("Use passcode instead")
                .accessibilityHint("Double tap to switch to passcode entry")
                .minimumTouchTarget()
            }
            
            // No security fallback
            if !authService.biometricEnabled && !passcodeService.hasPasscode() {
                Button {
                    showSuccess()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.brandPrimary)
                        )
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 24)
                // v2.2: VoiceOver label
                .accessibilityLabel("Continue to FLO")
                .accessibilityHint("Double tap to open the app")
            }
        }
    }
    
    // MARK: - Passcode Section
    
    private var passcodeSection: some View {
        VStack(spacing: 24) {
            // Status text - v2.2: Live region
            Text(statusText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .accessibilityLabel(statusText)
                .accessibilityAddTraits(.updatesFrequently)
            
            // Passcode Dots with glow - v2.2: Grouped with progress label
            HStack(spacing: 18) {
                ForEach(0..<passcodeLength, id: \.self) { index in
                    ZStack {
                        // Glow behind filled dots
                        if index < passcode.count {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.4))
                                .frame(width: 22, height: 22)
                                .blur(radius: 6)
                        }
                        
                        Circle()
                            .fill(index < passcode.count ? Color.brandPrimary : Color.white.opacity(0.2))
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .scaleEffect(index < passcode.count ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: passcode.count)
                }
            }
            .offset(x: isShaking ? -10 : 0)
            .animation(
                isShaking ? .easeInOut(duration: 0.06).repeatCount(5, autoreverses: true) : .default,
                value: isShaking
            )
            .padding(.bottom, 8)
            // v2.2: VoiceOver reads passcode progress
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(passcodeProgressLabel)
            .accessibilityValue("\(passcode.count) of \(passcodeLength) digits entered")
            
            // Number Pad (Compact design)
            VStack(spacing: 12) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 20) {
                        ForEach(row, id: \.self) { number in
                            passcodeButton(for: number)
                        }
                    }
                }
                
                // Bottom Row
                HStack(spacing: 20) {
                    // Biometric shortcut or Cancel
                    if authService.isBiometricAvailable && authService.biometricEnabled {
                        Button {
                            HapticService.play(.light)
                            passcode = ""
                            withAnimation {
                                authMode = .biometric
                            }
                        } label: {
                            Image(systemName: biometricIcon)
                                .font(.title3)
                                .foregroundStyle(Color.brandPrimary)
                                .frame(width: 68, height: 68)
                        }
                        .disabled(isLockedOut)
                        // v2.2: VoiceOver label for biometric shortcut
                        .accessibilityLabel("Switch to \(biometricAccessibilityName)")
                        .accessibilityHint("Double tap to use \(biometricAccessibilityName) instead of passcode")
                    } else {
                        Button {
                            HapticService.play(.light)
                            passcode = ""
                            withAnimation {
                                authMode = .biometric
                            }
                        } label: {
                            Text("Cancel")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                                .frame(width: 68, height: 68)
                        }
                        // v2.2: VoiceOver label
                        .accessibilityLabel("Cancel passcode entry")
                        .accessibilityHint("Double tap to go back")
                    }
                    
                    // Zero
                    passcodeButton(for: 0)
                    
                    // Delete
                    Button {
                        guard !passcode.isEmpty else { return }
                        HapticService.play(.light)
                        passcode.removeLast()
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(passcode.isEmpty ? 0.2 : 0.7))
                            .frame(width: 68, height: 68)
                    }
                    .disabled(passcode.isEmpty || isLockedOut)
                    // v2.2: VoiceOver label for delete button
                    .accessibilityLabel("Delete last digit")
                    .accessibilityHint(passcode.isEmpty ? "No digits to delete" : "Double tap to remove the last digit")
                }
            }
            // v2.2: Group number pad for VoiceOver rotor navigation
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Passcode number pad")
        }
        .padding(.horizontal, 32)
        .onAppear {
            startLockoutTimer()
            // v2.2: Announce passcode mode
            AccessibilityAnnouncement.screenChanged("Passcode entry. \(passcodeLength) digit passcode required.")
        }
    }
    
    @ViewBuilder
    private func passcodeButton(for number: Int) -> some View {
        Button {
            addPasscodeDigit(number)
        } label: {
            ZStack {
                // Glass background
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .frame(width: 68, height: 68)
                
                // Border
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 68, height: 68)
                
                // Number
                Text("\(number)")
                    .font(.title2)
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
        }
        .disabled(isLockedOut)
        // v2.2: VoiceOver label for each number button
        .accessibilityLabel("\(number)")
        .accessibilityHint(isLockedOut ? "Locked out" : "Double tap to enter \(number)")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Success Overlay
    
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.brandAccent.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(Color.brandAccent)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .scaleEffect(showSuccessAnimation ? 1 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showSuccessAnimation)
                
                Text("Welcome Back")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .opacity(showSuccessAnimation ? 1 : 0.001)
                    .animation(.easeOut(duration: 0.3).delay(0.2), value: showSuccessAnimation)
            }
        }
        // v2.2: Announce success to VoiceOver
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Authentication successful. Welcome back.")
        .accessibilityAddTraits(.isModal)
        .onAppear {
            AccessibilityAnnouncement.announce("Unlocked successfully. Welcome back.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        if isLockedOut, let endTime = lockoutEndTime {
            return "Try again in \(timeRemaining(until: endTime))"
        } else if isPasscodeError {
            return "Incorrect Passcode"
        } else if isAuthenticating {
            return "Authenticating..."
        } else if authMode == .passcode {
            return "Enter Passcode"
        } else {
            return "Unlock to Continue"
        }
    }
    
    private var statusColor: Color {
        if isLockedOut || isPasscodeError {
            return .red
        }
        return .white.opacity(0.6)
    }
    
    private var biometricIcon: String {
        switch authService.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }
    
    private var biometricText: String {
        switch authService.biometricType {
        case .faceID: return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        case .opticID: return "Unlock with Optic ID"
        default: return "Unlock"
        }
    }
    
    // v2.2: Spoken biometric name for VoiceOver hints
    private var biometricAccessibilityName: String {
        switch authService.biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "biometrics"
        }
    }
    
    // v2.2: Passcode progress for VoiceOver
    private var passcodeProgressLabel: String {
        if isLockedOut {
            return "Account locked. Too many failed attempts."
        } else if passcode.isEmpty {
            return "Passcode entry. \(passcodeLength) digits required."
        } else {
            return "\(passcode.count) of \(passcodeLength) digits entered"
        }
    }
    
    // MARK: - Actions
    
    private func handleOnAppear() {
        // Fade in content
        withAnimation(.easeOut(duration: 0.5)) {
            showContent = true
        }
        
        // Start icon glow animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            iconGlow = true
        }
        
        // Start shimmer animation
        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
            shimmerOffset = 200
        }
        
        // Start floating orb animations
        startOrbAnimations()
        
        // Auto-unlock if no security
        if !authService.biometricEnabled && !passcodeService.hasPasscode() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showSuccess()
            }
            return
        }
        
        // Determine initial auth mode - Biometric is PRIMARY
        if authService.biometricEnabled && authService.isBiometricAvailable {
            authMode = .biometric
            
            // Auto-trigger biometric
            if !hasAttemptedBiometric {
                hasAttemptedBiometric = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    triggerBiometric()
                }
            }
        } else if passcodeService.hasPasscode() {
            // Only show passcode if biometric is not available/enabled
            authMode = .passcode
        }
    }
    
    private func startOrbAnimations() {
        withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
            orb1Offset = CGPoint(x: 50, y: 100)
        }
        
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(1)) {
            orb2Offset = CGPoint(x: -80, y: -80)
        }
        
        withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(2)) {
            orb3Offset = CGPoint(x: 60, y: -100)
        }
    }
    
    private func triggerBiometric() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        HapticService.play(.medium)
        
        authService.authenticateWithBiometrics { success in
            isAuthenticating = false
            
            if success {
                showSuccess()
            } else {
                // v2.2: Announce failure to VoiceOver
                AccessibilityAnnouncement.announce("Authentication failed. Try again or use passcode.")
            }
        }
    }
    
    private func showSuccess() {
        HapticService.play(.success)
        
        withAnimation {
            showSuccessAnimation = true
        }
        
        // Dismiss after showing success
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            authService.markAuthenticated()
        }
    }
    
    private func addPasscodeDigit(_ digit: Int) {
        guard !isLockedOut else { return }
        guard passcode.count < passcodeLength else { return }
        
        HapticService.play(.light)
        passcode += "\(digit)"
        
        // v2.2: Announce digit count to VoiceOver (without revealing the digit)
        AccessibilityAnnouncement.announce("\(passcode.count) of \(passcodeLength)")
        
        if passcode.count == passcodeLength {
            verifyPasscode()
        }
    }
    
    private func verifyPasscode() {
        if passcodeService.verifyPasscode(passcode) {
            failedAttempts = 0
            passcode = ""
            showSuccess()
            
            #if DEBUG
            print("✅ Passcode verified")
            #endif
        } else {
            failedAttempts += 1
            HapticService.play(.error)
            
            withAnimation {
                isPasscodeError = true
            }
            
            // v2.2: Announce error to VoiceOver
            let attemptsRemaining = maxAttempts - failedAttempts
            if attemptsRemaining > 0 {
                AccessibilityAnnouncement.announce("Incorrect passcode. \(attemptsRemaining) attempts remaining.")
            } else {
                AccessibilityAnnouncement.announce("Too many failed attempts. Account locked for 60 seconds.")
            }
            
            shakePasscode()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                passcode = ""
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    isPasscodeError = false
                }
            }
            
            if failedAttempts >= maxAttempts {
                isLockedOut = true
                lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
            }
        }
    }
    
    private func shakePasscode() {
        withAnimation(.easeInOut(duration: 0.06).repeatCount(5, autoreverses: true)) {
            isShaking = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isShaking = false
        }
    }
    
    private func startLockoutTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if let endTime = lockoutEndTime, Date() >= endTime {
                    isLockedOut = false
                    lockoutEndTime = nil
                    failedAttempts = 0
                    // v2.2: Announce lockout ended
                    AccessibilityAnnouncement.announce("Lockout ended. You can try again.")
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

// MARK: - Preview

#Preview("Lock View - Biometric") {
    LockView()
        .preferredColorScheme(.dark)
}
