//  PushNotificationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Push Notification Device Token Management
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Manages the device token lifecycle for APNs remote push notifications:
//  - Registers for remote notifications with iOS
//  - Converts raw device token Data to hex string
//  - Sends token to Supabase backend for storage
//  - Handles token refresh (re-registers if token changes)
//  - Unregisters token on disconnect/logout

import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// MARK: - Push Notification Service

@MainActor
final class PushNotificationService: ObservableObject {

    // MARK: - Singleton

    static let shared = PushNotificationService()
    private init() {
        self.urlSession = PushNotificationService.createURLSession()
    }

    // MARK: - Published State

    /// Current device token (hex string)
    @Published var deviceToken: String?

    /// Registration error if any
    @Published var registrationError: Error?

    /// Whether token has been sent to backend
    @Published var isRegisteredWithBackend = false

    // MARK: - Private

    private let urlSession: URLSession

    /// UserDefaults key for stored device token
    private let storedTokenKey = "push.deviceToken"

    /// UserDefaults key for tracking backend registration
    private let backendRegisteredKey = "push.backendRegistered"

    // MARK: - URL Session

    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }

    // MARK: - Registration

    /// Request remote notification registration with iOS
    /// Call this after notification permission is granted
    func registerForPushNotifications() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        NSApplication.shared.registerForRemoteNotifications()
        #endif

        #if DEBUG
        print("📱 Requested remote notification registration")
        #endif
    }

    /// Called by AppDelegate when iOS provides a device token
    func handleNewToken(_ tokenData: Data) {
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        let previousToken = UserDefaults.standard.string(forKey: storedTokenKey)

        deviceToken = tokenString
        registrationError = nil

        #if DEBUG
        print("📱 Device token received: \(tokenString.prefix(16))...")
        #endif

        // Only send to backend if token changed
        if tokenString != previousToken {
            UserDefaults.standard.set(tokenString, forKey: storedTokenKey)

            Task {
                await sendTokenToBackend(token: tokenString)
            }
        } else {
            isRegisteredWithBackend = UserDefaults.standard.bool(forKey: backendRegisteredKey)

            #if DEBUG
            print("📱 Device token unchanged, skipping backend update")
            #endif
        }
    }

    /// Called by AppDelegate when registration fails
    func handleRegistrationError(_ error: Error) {
        registrationError = error

        #if DEBUG
        print("❌ Remote notification registration failed: \(error.localizedDescription)")
        #endif
    }

    // MARK: - Backend Communication

    /// Send device token to Supabase backend for storage
    func sendTokenToBackend(token: String) async {
        let baseURL = PlaidConfiguration.backendBaseURL
        let anonKey = PlaidConfiguration.supabaseAnonKey
        let userId = getUserIdentifier()

        guard let url = URL(string: baseURL + "/device-register") else {
            #if DEBUG
            print("❌ Invalid device-register URL")
            #endif
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")

        let body: [String: Any] = [
            "deviceToken": token,
            "device_token": token,
            "platform": "ios",
            "bundleId": Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo"
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                #if DEBUG
                print("❌ Device token registration failed: HTTP \(statusCode)")
                #endif
                return
            }

            isRegisteredWithBackend = true
            UserDefaults.standard.set(true, forKey: backendRegisteredKey)

            #if DEBUG
            print("✅ Device token registered with backend")
            #endif

        } catch {
            #if DEBUG
            print("❌ Device token registration error: \(error.localizedDescription)")
            #endif
        }
    }

    /// Remove device token from backend (for logout/disconnect)
    func unregisterToken() async {
        guard let token = deviceToken ?? UserDefaults.standard.string(forKey: storedTokenKey) else {
            return
        }

        let baseURL = PlaidConfiguration.backendBaseURL
        let anonKey = PlaidConfiguration.supabaseAnonKey
        let userId = getUserIdentifier()

        guard let url = URL(string: baseURL + "/device-register") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(userId, forHTTPHeaderField: "X-User-ID")

        let body: [String: Any] = [
            "deviceToken": token,
            "device_token": token
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, _) = try await urlSession.data(for: request)

            isRegisteredWithBackend = false
            UserDefaults.standard.set(false, forKey: backendRegisteredKey)

            #if DEBUG
            print("✅ Device token unregistered from backend")
            #endif

        } catch {
            #if DEBUG
            print("⚠️ Device token unregistration error: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - User Identifier

    /// Same pattern as PlaidService.getUserIdentifier()
    private func getUserIdentifier() -> String {
        let key = "com.finchandpoppy.flo.userId"

        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
}
