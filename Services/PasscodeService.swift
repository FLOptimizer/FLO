//  PasscodeService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Added passcode length persistence
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Secure passcode management using Keychain
//  FIXES: Passcode length is now persisted and retrievable
//

import Foundation
import Security
import CommonCrypto

final class PasscodeService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = PasscodeService()
    
    // MARK: - Published Properties
    @Published var isPasscodeEnabled: Bool = false
    @Published private(set) var passcodeLength: Int = 6
    
    // MARK: - Keychain Keys
    private let service = "com.finchandpoppy.flo"
    private let passcodeAccount = "userPasscode"
    private let passcodeEnabledKey = "passcodeEnabled"
    private let passcodeLengthKey = "passcodeLength"
    
    // MARK: - Initialization
    
    private init() {
        // Load enabled state and length from UserDefaults
        self.isPasscodeEnabled = UserDefaults.standard.bool(forKey: passcodeEnabledKey)
        self.passcodeLength = UserDefaults.standard.integer(forKey: passcodeLengthKey)
        
        // Default to 6 if not set
        if self.passcodeLength == 0 {
            self.passcodeLength = 6
        }
        
        #if DEBUG
        print("🔐 PasscodeService initialized - enabled: \(isPasscodeEnabled), length: \(passcodeLength)")
        #endif
    }
    
    // MARK: - Passcode Management
    
    /// Check if a passcode is currently set
    func hasPasscode() -> Bool {
        return getPasscodeFromKeychain() != nil
    }
    
    /// Get the stored passcode length
    func getPasscodeLength() -> Int {
        return passcodeLength
    }
    
    /// Set a new passcode with specified length
    func setPasscode(_ passcode: String) -> Bool {
        // Validate passcode (must be 4 or 6 digits)
        guard isValidPasscode(passcode) else {
            #if DEBUG
            print("❌ Invalid passcode format - must be 4 or 6 digits")
            #endif
            return false
        }
        
        // Hash the passcode before storing
        guard let hashedPasscode = hashPasscode(passcode) else {
            #if DEBUG
            print("❌ Failed to hash passcode")
            #endif
            return false
        }
        
        // Remove existing passcode if any
        removePasscodeFromKeychain()
        
        // Store new passcode in keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passcodeAccount,
            kSecValueData as String: hashedPasscode.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            #if DEBUG
            print("✅ Passcode set successfully (length: \(passcode.count))")
            #endif
            
            DispatchQueue.main.async {
                self.isPasscodeEnabled = true
                self.passcodeLength = passcode.count
            }
            
            // Persist settings
            UserDefaults.standard.set(true, forKey: passcodeEnabledKey)
            UserDefaults.standard.set(passcode.count, forKey: passcodeLengthKey)
            
            return true
        } else {
            #if DEBUG
            print("❌ Failed to save passcode: \(status)")
            #endif
            return false
        }
    }
    
    /// Verify a passcode
    func verifyPasscode(_ passcode: String) -> Bool {
        guard let storedHash = getPasscodeFromKeychain() else {
            #if DEBUG
            print("❌ No passcode stored")
            #endif
            return false
        }
        
        guard let inputHash = hashPasscode(passcode) else {
            #if DEBUG
            print("❌ Failed to hash input passcode")
            #endif
            return false
        }
        
        let verified = inputHash == storedHash
        
        #if DEBUG
        print(verified ? "✅ Passcode verified" : "❌ Passcode incorrect")
        #endif
        
        return verified
    }
    
    /// Change existing passcode (requires current passcode)
    func changePasscode(current: String, new: String) -> Bool {
        guard verifyPasscode(current) else {
            #if DEBUG
            print("❌ Current passcode incorrect")
            #endif
            return false
        }
        
        return setPasscode(new)
    }
    
    /// Remove passcode completely
    func removePasscode() {
        removePasscodeFromKeychain()
        
        DispatchQueue.main.async {
            self.isPasscodeEnabled = false
        }
        
        UserDefaults.standard.set(false, forKey: passcodeEnabledKey)
        // Keep the length setting for next time
        
        #if DEBUG
        print("✅ Passcode removed")
        #endif
    }
    
    // MARK: - Private Helpers
    
    private func removePasscodeFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passcodeAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func getPasscodeFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: passcodeAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let passcode = String(data: data, encoding: .utf8) {
            return passcode
        }
        
        return nil
    }
    
    private func hashPasscode(_ passcode: String) -> String? {
        guard let data = passcode.data(using: .utf8) else {
            return nil
        }
        
        // Use SHA256 for hashing
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func isValidPasscode(_ passcode: String) -> Bool {
        // Must be 4 or 6 digits
        let validLengths = [4, 6]
        guard validLengths.contains(passcode.count) else {
            return false
        }
        
        // Must be all digits
        return passcode.allSatisfy { $0.isNumber }
    }
}
