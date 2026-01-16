//  PasscodeSetupView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Passcode setup and management screen
//
//  ENHANCEMENTS v3.0:
//  - Step progress indicator with animated transitions
//  - Number button press animations with spring physics
//  - Dot fill animations matching digit entry
//  - Success celebration with checkmark animation
//  - Error shake with haptic feedback
//  - Length selector animation
//  - Smooth step transitions
//

import SwiftUI

struct PasscodeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    @State private var step: SetupStep
    @State private var passcodeLength: Int
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var currentPasscode: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingLengthSelection = false
    
    // Animation States
    @State private var headerScale: CGFloat = 0.9
    @State private var headerOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var keypadOpacity: Double = 0
    @State private var pressedButton: Int? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var stepTransition = false
    @State private var showSuccessCheck = false
    @State private var lengthButtonScale: CGFloat = 1.0
    
    let isChanging: Bool
    let onComplete: (() -> Void)?
    
    init(isChanging: Bool, onComplete: (() -> Void)? = nil) {
        self.isChanging = isChanging
        self.onComplete = onComplete
        
        // Use stored length from service, or default to 6
        let storedLength = PasscodeService.shared.getPasscodeLength()
        self._passcodeLength = State(initialValue: storedLength > 0 ? storedLength : 6)
        
        if isChanging {
            self._step = State(initialValue: .enterCurrent)
        } else {
            self._step = State(initialValue: .enterNew)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Step Progress Indicator
                    if !isChanging {
                        stepProgressIndicator
                            .opacity(headerOpacity)
                    }
                    
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            if showSuccessCheck {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(AppConstants.primaryColor)
                                    .symbolEffect(.bounce, value: step)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSuccessCheck)
                        
                        Text(headerText)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .animation(.easeInOut(duration: 0.2), value: step)
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .scaleEffect(headerScale)
                    .opacity(headerOpacity)
                    
                    // Passcode Dots
                    HStack(spacing: 20) {
                        ForEach(0..<passcodeLength, id: \.self) { index in
                            PasscodeSetupDot(
                                isFilled: index < currentPasscodeInput.count,
                                index: index
                            )
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(currentPasscodeInput.count) of \(passcodeLength) digits entered")
                    .offset(x: shakeOffset)
                    .opacity(dotsOpacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: passcodeLength)
                    
                    Spacer()
                    
                    // Number Pad
                    VStack(spacing: 20) {
                        ForEach([1, 4, 7], id: \.self) { row in
                            HStack(spacing: 30) {
                                ForEach(row..<row+3, id: \.self) { number in
                                    SetupNumberButton(
                                        number: number,
                                        isPressed: pressedButton == number
                                    ) {
                                        addDigit(number)
                                    }
                                }
                            }
                        }
                        
                        // Bottom Row: Empty, 0, Delete
                        HStack(spacing: 30) {
                            Color.clear.frame(width: 70, height: 70)
                            
                            SetupNumberButton(
                                number: 0,
                                isPressed: pressedButton == 0
                            ) {
                                addDigit(0)
                            }
                            
                            Button {
                                deleteLastDigit()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, height: 70)
                            }
                            .accessibilityLabel("Delete")
                            .accessibilityHint("Removes last digit")
                            .disabled(currentPasscodeInput.isEmpty)
                        }
                    }
                    .opacity(keypadOpacity)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(isChanging ? "Change Passcode" : "Set Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        handleCancel()
                    }
                }
                
                if !isChanging && step == .enterNew {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                selectLength(4)
                            } label: {
                                HStack {
                                    Text("4 Digits")
                                    if passcodeLength == 4 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            
                            Button {
                                selectLength(6)
                            } label: {
                                HStack {
                                    Text("6 Digits")
                                    if passcodeLength == 6 {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "number.circle")
                                .foregroundStyle(AppConstants.primaryColor)
                                .scaleEffect(lengthButtonScale)
                        }
                        .accessibilityLabel("Change passcode length")
                    }
                }
            }
            .onAppear {
                animateEntrance()
            }
        }
    }
    
    // MARK: - Step Progress Indicator
    
    private var stepProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                Capsule()
                    .fill(stepIndex >= index ? AppConstants.primaryColor : Color.gray.opacity(0.3))
                    .frame(width: stepIndex == index ? 24 : 12, height: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: stepIndex)
            }
        }
    }
    
    private var stepIndex: Int {
        switch step {
        case .enterCurrent: return 0
        case .enterNew: return 0
        case .confirmNew: return 1
        }
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            headerScale = 1.0
            headerOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.15)) {
            dotsOpacity = 1.0
        }
        
        withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
            keypadOpacity = 1.0
        }
    }
    
    private func animateStepTransition() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            stepTransition = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stepTransition = false
        }
    }
    
    // MARK: - Computed Properties
    
    private var headerText: String {
        switch step {
        case .enterCurrent:
            return "Enter Current Passcode"
        case .enterNew:
            return "Enter New Passcode"
        case .confirmNew:
            return "Confirm New Passcode"
        }
    }
    
    private var currentPasscodeInput: String {
        switch step {
        case .enterCurrent:
            return currentPasscode
        case .enterNew:
            return passcode
        case .confirmNew:
            return confirmPasscode
        }
    }
    
    // MARK: - Actions
    
    private func selectLength(_ length: Int) {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            lengthButtonScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                lengthButtonScale = 1.0
            }
        }
        
        passcodeLength = length
        // Clear any entered digits when changing length
        passcode = ""
        confirmPasscode = ""
    }
    
    private func addDigit(_ digit: Int) {
        // Button press animation
        pressedButton = digit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pressedButton = nil
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        switch step {
        case .enterCurrent:
            guard currentPasscode.count < passcodeService.getPasscodeLength() else { return }
            currentPasscode += "\(digit)"
            if currentPasscode.count == passcodeService.getPasscodeLength() {
                verifyCurrentPasscode()
            }
            
        case .enterNew:
            guard passcode.count < passcodeLength else { return }
            passcode += "\(digit)"
            if passcode.count == passcodeLength {
                moveToConfirmation()
            }
            
        case .confirmNew:
            guard confirmPasscode.count < passcodeLength else { return }
            confirmPasscode += "\(digit)"
            if confirmPasscode.count == passcodeLength {
                verifyAndSavePasscode()
            }
        }
    }
    
    private func deleteLastDigit() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        switch step {
        case .enterCurrent:
            if !currentPasscode.isEmpty {
                currentPasscode.removeLast()
            }
        case .enterNew:
            if !passcode.isEmpty {
                passcode.removeLast()
            }
        case .confirmNew:
            if !confirmPasscode.isEmpty {
                confirmPasscode.removeLast()
            }
        }
    }
    
    private func verifyCurrentPasscode() {
        if passcodeService.verifyPasscode(currentPasscode) {
            // Success
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            animateStepTransition()
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                step = .enterNew
                currentPasscode = ""
            }
        } else {
            // Failed
            showErrorMessage("Incorrect passcode")
            triggerShake()
            currentPasscode = ""
        }
    }
    
    private func moveToConfirmation() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        animateStepTransition()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            step = .confirmNew
        }
    }
    
    private func verifyAndSavePasscode() {
        if passcode == confirmPasscode {
            // Success
            if passcodeService.setPasscode(passcode) {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Show success checkmark
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSuccessCheck = true
                }
                
                // Celebration haptic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let celebrationGenerator = UIImpactFeedbackGenerator(style: .heavy)
                    celebrationGenerator.impactOccurred()
                }
                
                // Clear passcodes from memory
                passcode = ""
                confirmPasscode = ""
                currentPasscode = ""
                
                #if DEBUG
                print("✅ Passcode set successfully")
                #endif
                
                // Dismiss after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    onComplete?()
                    dismiss()
                }
            } else {
                showErrorMessage("Failed to save passcode")
                resetToEnterNew()
            }
        } else {
            // Mismatch
            showErrorMessage("Passcodes don't match")
            resetToEnterNew()
        }
    }
    
    private func resetToEnterNew() {
        triggerShake()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                passcode = ""
                confirmPasscode = ""
                step = .enterNew
                showError = false
            }
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
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        withAnimation(.spring(response: 0.3)) {
            showError = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showError = false
            }
        }
    }
    
    private func handleCancel() {
        // Clear all passcodes from memory
        passcode = ""
        confirmPasscode = ""
        currentPasscode = ""
        
        onComplete?()
        dismiss()
    }
    
    // MARK: - Setup Step Enum
    
    enum SetupStep {
        case enterCurrent
        case enterNew
        case confirmNew
    }
}

// MARK: - Passcode Setup Dot

private struct PasscodeSetupDot: View {
    let isFilled: Bool
    let index: Int
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(isFilled ? AppConstants.primaryColor : Color.secondary.opacity(0.3))
            .frame(width: 16, height: 16)
            .scaleEffect(scale)
            .onChange(of: isFilled) { _, newValue in
                if newValue {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                        scale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                            scale = 1.0
                        }
                    }
                }
            }
    }
}

// MARK: - Setup Number Button

private struct SetupNumberButton: View {
    let number: Int
    let isPressed: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.title)
                .fontWeight(.medium)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(isPressed ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.2))
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .accessibilityLabel("\(number)")
        .animation(.spring(response: 0.15, dampingFraction: 0.6), value: isPressed)
    }
}

// MARK: - Preview

#Preview("New Passcode") {
    PasscodeSetupView(isChanging: false)
}

#Preview("Change Passcode") {
    PasscodeSetupView(isChanging: true)
}
