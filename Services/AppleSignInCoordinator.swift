//  AppleSignInCoordinator.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Coordinator for ASAuthorizationController delegate.
//  Bridges SwiftUI's SignInWithAppleButton to AppleAuthService.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import Foundation
import AuthenticationServices

/// Coordinates the Sign In with Apple authorization flow.
/// Owns the delegate lifecycle for ASAuthorizationController.
@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject {

    @Published var errorMessage: String?
    @Published var showingError: Bool = false

    /// Initiates the Sign In with Apple flow programmatically.
    /// Use this when you need more control than SignInWithAppleButton provides.
    func startSignInFlow() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.performRequests()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        Task { @MainActor in
            AppleAuthService.shared.handleAuthorization(authorization)
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        Task { @MainActor in
            let nsError = error as NSError

            // Don't show error for user cancellation
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue {
                #if DEBUG
                print("[AppleAuth] Sign in cancelled by user")
                #endif
                return
            }

            errorMessage = error.localizedDescription
            showingError = true
            HapticService.play(.error)

            #if DEBUG
            print("[AppleAuth] Sign in error: \(error.localizedDescription)")
            #endif
        }
    }
}
