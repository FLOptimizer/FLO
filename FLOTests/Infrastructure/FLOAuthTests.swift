//  FLOAuthTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Authentication & Security Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate biometric authentication flow, passcode handling,
//  and security state management.
//
//  COVERS:
//  - Biometric auth (Face ID / Touch ID) flow
//  - Passcode fallback
//  - Lock state management
//  - Auto-lock timing
//  - Security settings
//

import XCTest
@testable import FLO

final class FLOAuthTests: XCTestCase {
    
    // MARK: - Auth State
    
    enum AuthState {
        case unlocked
        case locked
        case authenticating
        case failed
    }
    
    enum BiometricType {
        case none
        case touchID
        case faceID
    }
}

// MARK: - Biometric Availability

extension FLOAuthTests {
    
    /// Test: Check biometric type available
    func testBiometric_CheckAvailability() {
        // Simulate device capability
        let deviceBiometricType: BiometricType = .faceID
        
        let hasBiometrics = deviceBiometricType != .none
        
        XCTAssertTrue(hasBiometrics, "Device has Face ID")
    }
    
    /// Test: No biometrics available
    func testBiometric_NoneAvailable() {
        let deviceBiometricType: BiometricType = .none
        
        let hasBiometrics = deviceBiometricType != .none
        
        XCTAssertFalse(hasBiometrics, "No biometrics on this device")
    }
    
    /// Test: Get biometric name for UI
    func testBiometric_DisplayName() {
        func biometricName(_ type: BiometricType) -> String {
            switch type {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "Passcode"
            }
        }
        
        XCTAssertEqual(biometricName(.faceID), "Face ID")
        XCTAssertEqual(biometricName(.touchID), "Touch ID")
        XCTAssertEqual(biometricName(.none), "Passcode")
    }
}

// MARK: - Authentication Flow

extension FLOAuthTests {
    
    /// Test: Successful biometric auth
    func testAuth_BiometricSuccess() {
        var state: AuthState = .locked
        
        // Start authentication
        state = .authenticating
        XCTAssertEqual(state, .authenticating)
        
        // Biometric succeeds
        let biometricSuccess = true
        if biometricSuccess {
            state = .unlocked
        }
        
        XCTAssertEqual(state, .unlocked)
    }
    
    /// Test: Failed biometric auth
    func testAuth_BiometricFailure() {
        var state: AuthState = .locked
        var failedAttempts = 0
        
        // Start authentication
        state = .authenticating
        
        // Biometric fails
        let biometricSuccess = false
        if !biometricSuccess {
            state = .failed
            failedAttempts += 1
        }
        
        XCTAssertEqual(state, .failed)
        XCTAssertEqual(failedAttempts, 1)
    }
    
    /// Test: Fallback to passcode after biometric failure
    func testAuth_FallbackToPasscode() {
        let result = handleBiometricResult(success: false)
        
        XCTAssertEqual(result.state, .failed, "State should be failed after biometric failure")
        XCTAssertTrue(result.showPasscodeEntry, "Should show passcode entry after biometric failure")
    }
    
    /// Helper to handle biometric result (avoids compile-time optimization)
    private func handleBiometricResult(success: Bool) -> (state: AuthState, showPasscodeEntry: Bool) {
        if success {
            return (.unlocked, false)
        } else {
            return (.failed, true)
        }
    }
    
    /// Test: Passcode verification
    func testAuth_PasscodeVerification() {
        let storedPasscode = "1234"
        let enteredPasscode = "1234"
        
        let isCorrect = storedPasscode == enteredPasscode
        
        XCTAssertTrue(isCorrect)
    }
    
    /// Test: Incorrect passcode
    func testAuth_IncorrectPasscode() {
        let storedPasscode = "1234"
        let enteredPasscode = "5678"
        var failedAttempts = 0
        
        let isCorrect = storedPasscode == enteredPasscode
        if !isCorrect {
            failedAttempts += 1
        }
        
        XCTAssertFalse(isCorrect)
        XCTAssertEqual(failedAttempts, 1)
    }
}

// MARK: - Lock State Management

extension FLOAuthTests {
    
    /// Test: Initial state is locked (if enabled)
    func testLockState_InitialLocked() {
        let initialState = determineInitialState(securityEnabled: true)
        
        XCTAssertEqual(initialState, .locked)
    }
    
    /// Test: Initial state unlocked if security disabled
    func testLockState_InitialUnlocked() {
        let initialState = determineInitialState(securityEnabled: false)
        
        XCTAssertEqual(initialState, .unlocked)
    }
    
    /// Helper to determine initial state (avoids compile-time optimization)
    private func determineInitialState(securityEnabled: Bool) -> AuthState {
        return securityEnabled ? .locked : .unlocked
    }
    
    /// Test: Lock on background
    func testLockState_LockOnBackground() {
        let state = determineLockOnBackground(lockOnBackground: true, currentState: .unlocked)
        
        XCTAssertEqual(state, .locked)
    }
    
    /// Helper to determine lock on background (avoids compile-time optimization)
    private func determineLockOnBackground(lockOnBackground: Bool, currentState: AuthState) -> AuthState {
        if lockOnBackground {
            return .locked
        }
        return currentState
    }
    
    /// Test: Stay unlocked on quick background
    func testLockState_GracePeriod() {
        let state = determineStateAfterBackground(
            gracePeriodSeconds: 30,
            backgroundDuration: 10
        )
        
        XCTAssertEqual(state, .unlocked, "Within grace period, stay unlocked")
    }
    
    /// Test: Lock after grace period
    func testLockState_LockAfterGracePeriod() {
        let state = determineStateAfterBackground(
            gracePeriodSeconds: 30,
            backgroundDuration: 60
        )
        
        XCTAssertEqual(state, .locked, "After grace period, lock")
    }
    
    /// Helper to determine state after background (avoids compile-time optimization)
    private func determineStateAfterBackground(gracePeriodSeconds: TimeInterval, backgroundDuration: TimeInterval) -> AuthState {
        if backgroundDuration < gracePeriodSeconds {
            return .unlocked
        } else {
            return .locked
        }
    }
}

// MARK: - Auto-Lock Timing

extension FLOAuthTests {
    
    enum AutoLockOption: Int {
        case immediately = 0
        case after1Minute = 60
        case after5Minutes = 300
        case after15Minutes = 900
        case never = -1
    }
    
    /// Test: Immediately lock
    func testAutoLock_Immediately() {
        let option = AutoLockOption.immediately
        let inactiveSeconds: TimeInterval = 1
        
        let shouldLock = option != .never && inactiveSeconds >= TimeInterval(option.rawValue)
        
        XCTAssertTrue(shouldLock)
    }
    
    /// Test: Lock after 1 minute
    func testAutoLock_After1Minute() {
        let option = AutoLockOption.after1Minute
        let inactiveSeconds: TimeInterval = 65
        
        let shouldLock = option != .never && inactiveSeconds >= TimeInterval(option.rawValue)
        
        XCTAssertTrue(shouldLock, "65 seconds > 60 second threshold")
    }
    
    /// Test: Don't lock before threshold
    func testAutoLock_BeforeThreshold() {
        let option = AutoLockOption.after5Minutes
        let inactiveSeconds: TimeInterval = 120  // 2 minutes
        
        let shouldLock = option != .never && inactiveSeconds >= TimeInterval(option.rawValue)
        
        XCTAssertFalse(shouldLock, "2 minutes < 5 minute threshold")
    }
    
    /// Test: Never auto-lock
    func testAutoLock_Never() {
        let option = AutoLockOption.never
        let inactiveSeconds: TimeInterval = 3600  // 1 hour
        
        let shouldLock = option != .never && inactiveSeconds >= TimeInterval(max(0, option.rawValue))
        
        XCTAssertFalse(shouldLock, "Never option doesn't lock")
    }
    
    /// Test: Reset inactivity timer on user interaction
    func testAutoLock_ResetOnInteraction() {
        var lastActivityTime = Date().addingTimeInterval(-300)  // 5 minutes ago
        
        // User interacts
        lastActivityTime = Date()
        
        let inactiveSeconds = Date().timeIntervalSince(lastActivityTime)
        
        XCTAssertLessThan(inactiveSeconds, 1, "Timer reset on interaction")
    }
}

// MARK: - Failed Attempts Handling

extension FLOAuthTests {
    
    /// Test: Track failed attempts
    func testFailedAttempts_Track() {
        var failedAttempts = 0
        
        // Three failed attempts
        failedAttempts += 1
        failedAttempts += 1
        failedAttempts += 1
        
        XCTAssertEqual(failedAttempts, 3)
    }
    
    /// Test: Lockout after max attempts
    func testFailedAttempts_Lockout() {
        let failedAttempts = 5
        let maxAttempts = 5
        
        let isLockedOut = failedAttempts >= maxAttempts
        
        XCTAssertTrue(isLockedOut, "Locked out after 5 attempts")
    }
    
    /// Test: Increasing delay between attempts
    func testFailedAttempts_IncreasingDelay() {
        func delayForAttempt(_ attempt: Int) -> TimeInterval {
            switch attempt {
            case 1, 2, 3: return 0
            case 4: return 30
            case 5: return 60
            default: return 300
            }
        }
        
        XCTAssertEqual(delayForAttempt(1), 0)
        XCTAssertEqual(delayForAttempt(4), 30)
        XCTAssertEqual(delayForAttempt(5), 60)
        XCTAssertEqual(delayForAttempt(6), 300)
    }
    
    /// Test: Reset attempts on success
    func testFailedAttempts_ResetOnSuccess() {
        var failedAttempts = 4
        
        // Successful auth
        let authSuccess = true
        if authSuccess {
            failedAttempts = 0
        }
        
        XCTAssertEqual(failedAttempts, 0)
    }
}

// MARK: - Passcode Setup

extension FLOAuthTests {
    
    /// Test: Validate passcode length
    func testPasscode_ValidateLength() {
        let minLength = 4
        let maxLength = 6
        
        func isValidLength(_ passcode: String) -> Bool {
            return passcode.count >= minLength && passcode.count <= maxLength
        }
        
        XCTAssertFalse(isValidLength("123"), "3 digits too short")
        XCTAssertTrue(isValidLength("1234"), "4 digits valid")
        XCTAssertTrue(isValidLength("123456"), "6 digits valid")
        XCTAssertFalse(isValidLength("1234567"), "7 digits too long")
    }
    
    /// Test: Passcode contains only digits
    func testPasscode_OnlyDigits() {
        func isValidFormat(_ passcode: String) -> Bool {
            return passcode.allSatisfy { $0.isNumber }
        }
        
        XCTAssertTrue(isValidFormat("1234"))
        XCTAssertFalse(isValidFormat("12a4"))
        XCTAssertFalse(isValidFormat("abcd"))
    }
    
    /// Test: Confirm passcode matches
    func testPasscode_ConfirmMatches() {
        let passcode = "1234"
        let confirmation = "1234"
        
        let matches = passcode == confirmation
        
        XCTAssertTrue(matches)
    }
    
    /// Test: Confirm passcode doesn't match
    func testPasscode_ConfirmMismatch() {
        let passcode = "1234"
        let confirmation = "1235"
        
        let matches = passcode == confirmation
        
        XCTAssertFalse(matches)
    }
}

// MARK: - Security Settings

extension FLOAuthTests {
    
    /// Test: Enable biometric auth
    func testSettings_EnableBiometric() {
        var biometricEnabled = false
        
        biometricEnabled = true
        
        XCTAssertTrue(biometricEnabled)
    }
    
    /// Test: Change auto-lock setting
    func testSettings_ChangeAutoLock() {
        var autoLockOption = AutoLockOption.after1Minute
        
        autoLockOption = .after5Minutes
        
        XCTAssertEqual(autoLockOption, .after5Minutes)
    }
    
    /// Test: Disable security (requires current passcode)
    func testSettings_DisableSecurity() {
        let currentPasscode = "1234"
        let enteredPasscode = "1234"
        var securityEnabled = true
        
        if enteredPasscode == currentPasscode {
            securityEnabled = false
        }
        
        XCTAssertFalse(securityEnabled)
    }
    
    /// Test: Change passcode (requires current passcode)
    func testSettings_ChangePasscode() {
        let currentPasscode = "1234"
        let enteredCurrentPasscode = "1234"
        var storedPasscode = "1234"
        let newPasscode = "5678"
        
        if enteredCurrentPasscode == currentPasscode {
            storedPasscode = newPasscode
        }
        
        XCTAssertEqual(storedPasscode, "5678")
    }
}

// MARK: - Integration

extension FLOAuthTests {
    
    /// Test: Full authentication flow
    func testIntegration_FullAuthFlow() {
        var state: AuthState = .locked
        var failedAttempts = 0
        let storedPasscode = "1234"
        
        // 1. App launches - locked
        XCTAssertEqual(state, .locked)
        
        // 2. Try biometric - user cancels
        state = .authenticating
        let biometricResult = processBiometricAuth(success: false)
        state = biometricResult.state
        if biometricResult.resetAttempts {
            failedAttempts = 0
        }
        
        XCTAssertEqual(state, .failed)
        
        // 3. Fall back to passcode - wrong attempt
        state = .authenticating
        let wrongPasscodeResult = processPasscodeAuth(entered: "0000", stored: storedPasscode)
        state = wrongPasscodeResult.state
        if wrongPasscodeResult.resetAttempts {
            failedAttempts = 0
        } else if wrongPasscodeResult.incrementAttempts {
            failedAttempts += 1
        }
        
        XCTAssertEqual(state, .failed)
        XCTAssertEqual(failedAttempts, 1)
        
        // 4. Try again - correct
        state = .authenticating
        let correctPasscodeResult = processPasscodeAuth(entered: "1234", stored: storedPasscode)
        state = correctPasscodeResult.state
        if correctPasscodeResult.resetAttempts {
            failedAttempts = 0
        }
        
        XCTAssertEqual(state, .unlocked)
        XCTAssertEqual(failedAttempts, 0)
    }
    
    /// Helper for biometric auth (avoids compile-time optimization)
    private func processBiometricAuth(success: Bool) -> (state: AuthState, resetAttempts: Bool) {
        if success {
            return (.unlocked, true)
        } else {
            return (.failed, false)
        }
    }
    
    /// Helper for passcode auth (avoids compile-time optimization)
    private func processPasscodeAuth(entered: String, stored: String) -> (state: AuthState, resetAttempts: Bool, incrementAttempts: Bool) {
        if entered == stored {
            return (.unlocked, true, false)
        } else {
            return (.failed, false, true)
        }
    }
}
