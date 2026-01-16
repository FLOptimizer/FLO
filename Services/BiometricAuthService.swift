//  BiometricAuthService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Centralized biometric authentication with single LAContext
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Biometric authentication service with Face ID/Touch ID support
//  FIXES: Multiple Face ID prompts by centralizing all auth through this service
//

import Foundation
import LocalAuthentication
import Combine

final class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    // MARK: - Published Properties
    @Published private(set) var isAuthenticated = false
    @Published var biometricEnabled = false
    @Published private(set) var biometricType: LABiometryType = .none
    @Published private(set) var isBiometricAvailable = false
    
    // MARK: - Private
    private let biometricKey = "com.finchandpoppy.flo.biometricEnabled"
    private var lastAuthAttempt = Date.distantPast
    private let minAuthInterval: TimeInterval = 2.0 // Increased to prevent rapid-fire prompts
    private var isAuthenticating = false // Prevent concurrent auth attempts
    
    private init() {
        loadSettings()
        evaluateBiometricAvailability()
    }
    
    // MARK: - Public API
    
    /// Refresh biometric availability status (call when app becomes active)
    func refreshBiometricStatus() {
        evaluateBiometricAvailability()
    }
    
    /// Perform biometric authentication - THIS IS THE ONLY METHOD THAT SHOULD TRIGGER FACE ID
    func authenticateWithBiometrics(completion: @escaping (Bool) -> Void) {
        // Prevent concurrent authentication attempts
        guard !isAuthenticating else {
            #if DEBUG
            print("⚠️ Authentication already in progress, skipping")
            #endif
            completion(false)
            return
        }
        
        // Rate limiting: prevent spam tapping
        let timeSinceLastAttempt = Date().timeIntervalSince(lastAuthAttempt)
        guard timeSinceLastAttempt > minAuthInterval else {
            #if DEBUG
            print("⚠️ Rate limited - wait \(minAuthInterval - timeSinceLastAttempt)s")
            #endif
            completion(false)
            return
        }
        
        isAuthenticating = true
        lastAuthAttempt = Date()
        
        // Create a fresh context for each authentication
        let context = LAContext()
        context.localizedCancelTitle = "Use Passcode"
        
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.isAuthenticated = false
                #if DEBUG
                print("❌ Biometric not available: \(error?.localizedDescription ?? "Unknown")")
                #endif
                completion(false)
            }
            return
        }
        
        // Dynamic reason string based on biometric type
        let reason = "Unlock FLO"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isAuthenticating = false
                
                if success {
                    self.isAuthenticated = true
                    #if DEBUG
                    print("✅ Biometric authentication successful")
                    #endif
                } else {
                    self.isAuthenticated = false
                    if let error = authError {
                        #if DEBUG
                        print("❌ Biometric authentication failed: \(error.localizedDescription)")
                        #endif
                    }
                }
                completion(success)
            }
        }
    }
    
    /// Mark as authenticated (for passcode unlock - NO biometric prompt)
    func markAuthenticated() {
        DispatchQueue.main.async {
            self.isAuthenticated = true
            #if DEBUG
            print("✅ Marked as authenticated (passcode)")
            #endif
        }
    }
    
    /// Log out / revoke current authentication
    func logout() {
        DispatchQueue.main.async {
            self.isAuthenticated = false
            #if DEBUG
            print("🔒 Logged out")
            #endif
        }
    }
    
    /// Toggle biometric preference
    func setBiometricEnabled(_ enabled: Bool) {
        biometricEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: biometricKey)
        
        // If user disables biometrics and no passcode, automatically authenticate
        if !enabled && !PasscodeService.shared.hasPasscode() {
            isAuthenticated = true
        }
        
        #if DEBUG
        print("🔐 Biometric enabled: \(enabled)")
        #endif
    }
    
    // MARK: - Internal (for settings display)
    
    var biometricTypeString: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometrics"
        @unknown default:
            return "Biometrics"
        }
    }
    
    /// Check if any security is enabled (biometric OR passcode)
    var isSecurityEnabled: Bool {
        return biometricEnabled || PasscodeService.shared.hasPasscode()
    }
    
    // MARK: - Private Helpers
    
    private func loadSettings() {
        biometricEnabled = UserDefaults.standard.bool(forKey: biometricKey)
    }
    
    private func evaluateBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        DispatchQueue.main.async {
            self.isBiometricAvailable = canEvaluate
            self.biometricType = context.biometryType
            
            #if DEBUG
            if let error = error {
                print("⚠️ Biometric policy error: \(error.localizedDescription)")
            } else {
                print("✅ Biometric available: \(canEvaluate), type: \(self.biometricTypeString)")
            }
            #endif
        }
    }
}
