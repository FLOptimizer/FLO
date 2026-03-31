//  AppleAuthService.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Sign In with Apple identity service.
//  Manages Apple ID authentication, Keychain token storage,
//  and credential state monitoring. Independent from BiometricAuthService
//  (device unlock) and PasscodeService (passcode vault).
//
//  Sign In with Apple = IDENTITY (who you are)
//  Biometrics/Passcode = DEVICE SECURITY (locking the app)
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import AuthenticationServices
import Security

@MainActor
final class AppleAuthService: ObservableObject {
    static let shared = AppleAuthService()

    // MARK: - Published State

    @Published private(set) var isSignedIn: Bool = false
    @Published private(set) var userIdentifier: String?
    @Published private(set) var fullName: String?
    @Published private(set) var email: String?
    @Published private(set) var authorizationState: AuthState = .unknown

    enum AuthState: String {
        case unknown
        case authorized
        case revoked
        case notFound
    }

    // MARK: - Keychain Constants

    private let keychainService = "com.finchandpoppy.flo"
    private let userIDAccount = "appleUserIdentifier"
    private let fullNameAccount = "appleFullName"
    private let emailAccount = "appleEmail"
    private let authCodeAccount = "appleAuthorizationCode"
    private let appInitializedKey = "appleAuth.appInitialized"

    // MARK: - Initialization

    private init() {
        loadStoredCredentials()
        registerForRevocationNotification()
    }

    // MARK: - Handle Sign In with Apple Result

    /// Called after a successful Sign In with Apple authorization.
    /// Extracts credentials, stores in Keychain, syncs to AppStorage.
    func handleAuthorization(_ authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            #if DEBUG
            print("[AppleAuth] Received non-Apple ID credential, ignoring")
            #endif
            return
        }

        let userID = credential.user

        // Store user identifier (always provided)
        saveToKeychain(value: userID, account: userIDAccount)

        // Store authorization code for potential token revocation
        if let authCodeData = credential.authorizationCode,
           let authCode = String(data: authCodeData, encoding: .utf8) {
            saveToKeychain(value: authCode, account: authCodeAccount)
        }

        // Name and email are ONLY provided on FIRST authorization.
        // On subsequent sign-ins, these are nil. Don't overwrite with nil.
        if let nameComponents = credential.fullName {
            let name = [nameComponents.givenName, nameComponents.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            if !name.isEmpty {
                saveToKeychain(value: name, account: fullNameAccount)
                fullName = name
                // Sync to AppStorage
                UserDefaults.standard.set(name, forKey: "userName")
            }
        }

        if let providedEmail = credential.email {
            saveToKeychain(value: providedEmail, account: emailAccount)
            email = providedEmail
            // Sync to AppStorage
            UserDefaults.standard.set(providedEmail, forKey: "userEmail")
        }

        // Update published state
        userIdentifier = userID
        isSignedIn = true
        authorizationState = .authorized

        // Mark app as initialized for reinstall detection
        UserDefaults.standard.set(true, forKey: appInitializedKey)

        #if DEBUG
        print("[AppleAuth] Sign in successful — userID: \(userID.prefix(8))...")
        print("[AppleAuth] Name: \(fullName ?? "(from previous sign-in)"), Email: \(email ?? "(from previous sign-in)")")
        #endif
    }

    // MARK: - Credential State Check

    /// Verify the Apple ID is still authorized. Call on app launch.
    func checkCredentialState() async {
        guard let storedUserID = readFromKeychain(account: userIDAccount) else {
            authorizationState = .notFound
            isSignedIn = false
            return
        }

        do {
            let state = try await ASAuthorizationAppleIDProvider().credentialState(forUserID: storedUserID)

            switch state {
            case .authorized:
                authorizationState = .authorized
                isSignedIn = true
                userIdentifier = storedUserID
                // Load name/email from Keychain
                fullName = readFromKeychain(account: fullNameAccount)
                email = readFromKeychain(account: emailAccount)
                #if DEBUG
                print("[AppleAuth] Credential state: authorized")
                #endif

            case .revoked:
                authorizationState = .revoked
                signOut()
                #if DEBUG
                print("[AppleAuth] Credential state: revoked — signing out")
                #endif

            case .notFound:
                authorizationState = .notFound
                signOut()
                #if DEBUG
                print("[AppleAuth] Credential state: not found — signing out")
                #endif

            default:
                authorizationState = .unknown
                #if DEBUG
                print("[AppleAuth] Credential state: unknown (\(state.rawValue))")
                #endif
            }
        } catch {
            #if DEBUG
            print("[AppleAuth] Failed to check credential state: \(error.localizedDescription)")
            #endif
            // Don't sign out on error — could be a network issue
            authorizationState = .unknown
        }
    }

    // MARK: - Sign Out

    /// Clears auth state but preserves AppStorage name/email (user may want to keep those).
    func signOut() {
        deleteFromKeychain(account: userIDAccount)
        deleteFromKeychain(account: authCodeAccount)
        // Keep name/email in Keychain as fallback

        userIdentifier = nil
        isSignedIn = false
        authorizationState = .notFound

        #if DEBUG
        print("[AppleAuth] Signed out — local identity cleared")
        #endif
    }

    // MARK: - Account Deletion

    /// Full account deletion per App Store Guidelines 5.1.1(v).
    /// Clears all Keychain entries, AppStorage values, and attempts token revocation.
    func deleteAccount() async {
        // Attempt token revocation with Apple
        await revokeTokenWithApple()

        // Clear all Keychain entries
        deleteFromKeychain(account: userIDAccount)
        deleteFromKeychain(account: fullNameAccount)
        deleteFromKeychain(account: emailAccount)
        deleteFromKeychain(account: authCodeAccount)

        // Clear AppStorage
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: appInitializedKey)

        // Reset published state
        userIdentifier = nil
        fullName = nil
        email = nil
        isSignedIn = false
        authorizationState = .notFound

        #if DEBUG
        print("[AppleAuth] Account deleted — all credentials and profile data cleared")
        #endif
    }

    // MARK: - Token Revocation

    /// Attempt to revoke the app's access with Apple's REST endpoint.
    private func revokeTokenWithApple() async {
        guard let authCode = readFromKeychain(account: authCodeAccount) else {
            #if DEBUG
            print("[AppleAuth] No authorization code stored — skipping revocation")
            #endif
            return
        }

        // Note: Full token revocation requires a client_secret (JWT signed with your private key)
        // which is typically done server-side. For client-only apps, clearing local credentials
        // and the user revoking from Apple ID settings is the standard approach.
        #if DEBUG
        print("[AppleAuth] Token revocation: client-side credentials cleared. User should also revoke from Settings > Apple ID > Sign-In & Security > Apps Using Your Apple ID")
        #endif

        _ = authCode // Suppress unused warning — stored for future server-side revocation
    }

    // MARK: - Private: Load Stored Credentials

    private func loadStoredCredentials() {
        // Reinstall detection (same pattern as PasscodeService)
        let hasStoredUserID = readFromKeychain(account: userIDAccount) != nil
        let appWasInitialized = UserDefaults.standard.bool(forKey: appInitializedKey)

        if !appWasInitialized && hasStoredUserID {
            // App was reinstalled — Keychain persists but UserDefaults doesn't.
            // Re-verify credential state rather than blindly trusting stored data.
            #if DEBUG
            print("[AppleAuth] Detected possible reinstall — will re-verify credentials on launch")
            #endif
            UserDefaults.standard.set(true, forKey: appInitializedKey)
            // Don't set isSignedIn — let checkCredentialState() validate
            return
        }

        if !appWasInitialized {
            // Fresh install
            UserDefaults.standard.set(true, forKey: appInitializedKey)
            return
        }

        // Normal launch — load stored credentials
        if let storedUserID = readFromKeychain(account: userIDAccount) {
            userIdentifier = storedUserID
            fullName = readFromKeychain(account: fullNameAccount)
            email = readFromKeychain(account: emailAccount)
            isSignedIn = true

            #if DEBUG
            print("[AppleAuth] Loaded stored credentials — userID: \(storedUserID.prefix(8))...")
            #endif
        }
    }

    // MARK: - Private: Credential Revocation Notification

    private func registerForRevocationNotification() {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                #if DEBUG
                print("[AppleAuth] Credential revocation notification received")
                #endif
                self?.signOut()
            }
        }
    }

    // MARK: - Keychain Helpers

    private func saveToKeychain(value: String, account: String) {
        // Delete existing entry first
        deleteFromKeychain(account: account)

        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        #if DEBUG
        if status != errSecSuccess {
            print("[AppleAuth] Keychain save failed for \(account): \(status)")
        }
        #endif
    }

    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
