//  CameraPermissionHelper.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Contextual camera permission handling
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Apple Guideline 5.1.1 Compliant:
//  - No pre-permission screens with escape buttons
//  - Requests permission directly when user initiates camera action
//  - Handles denied state gracefully with Settings redirect
//

import SwiftUI
import AVFoundation

// MARK: - Camera Permission Status

enum CameraPermissionStatus {
    case authorized
    case notDetermined
    case denied
    case restricted
    
    var canProceed: Bool {
        self == .authorized
    }
    
    var needsRequest: Bool {
        self == .notDetermined
    }
    
    var needsSettings: Bool {
        self == .denied || self == .restricted
    }
}

// MARK: - Camera Permission Helper

@MainActor
struct CameraPermissionHelper {
    
    /// Check current camera permission status
    static func checkPermission() -> CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .denied
        }
    }
    
    /// Request camera permission (async)
    /// Returns true if permission was granted
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Open device Settings app to FLO's settings page
    static func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    #if canImport(UIKit)
    /// Show alert directing user to Settings when camera access is denied
    static func showSettingsAlert(on viewController: UIViewController? = nil) {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "FLO needs camera access to scan receipts. Please enable it in Settings.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            openSettings()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Find the topmost view controller to present the alert
        if let vc = viewController {
            vc.present(alert, animated: true)
        } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost presented controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(alert, animated: true)
        }
    }
    #else
    /// Show alert directing user to Settings when camera access is denied (macOS)
    static func showSettingsAlert() {
        let alert = NSAlert()
        alert.messageText = "Camera Access Required"
        alert.informativeText = "FLO needs camera access to scan receipts. Please enable it in System Settings."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }
    #endif
}

// MARK: - SwiftUI View Modifier

/// A view modifier that handles camera permission before showing a camera view
struct CameraPermissionModifier: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var showingCamera: Bool
    @State private var showingSettingsAlert = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { _, shouldPresent in
                if shouldPresent {
                    handleCameraRequest()
                }
            }
            .alert("Camera Access Required", isPresented: $showingSettingsAlert) {
                Button("Open Settings") {
                    CameraPermissionHelper.openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FLO needs camera access to scan receipts. Please enable it in Settings.")
            }
    }
    
    private func handleCameraRequest() {
        let status = CameraPermissionHelper.checkPermission()
        
        switch status {
        case .authorized:
            // Permission already granted - show camera
            showingCamera = true
            isPresented = false
            
        case .notDetermined:
            // Need to request permission
            Task {
                let granted = await CameraPermissionHelper.requestPermission()
                await MainActor.run {
                    if granted {
                        showingCamera = true
                    }
                    // If not granted, user saw the system dialog and declined
                    // Don't show another alert - they made their choice
                    isPresented = false
                }
            }
            
        case .denied, .restricted:
            // Permission was denied previously - show settings alert
            showingSettingsAlert = true
            isPresented = false
        }
    }
}

// MARK: - View Extension

extension View {
    /// Handles camera permission before presenting a camera view
    /// - Parameters:
    ///   - isPresented: Binding that triggers the permission check
    ///   - showingCamera: Binding that controls the actual camera presentation
    func cameraPermission(
        isPresented: Binding<Bool>,
        showingCamera: Binding<Bool>
    ) -> some View {
        modifier(CameraPermissionModifier(
            isPresented: isPresented,
            showingCamera: showingCamera
        ))
    }
}

// MARK: - Simpler Async Handler

extension CameraPermissionHelper {
    /// Handle camera permission flow and return whether to proceed
    /// Use this for simpler integration without view modifiers
    static func handleCameraAccess() async -> CameraAccessResult {
        let status = checkPermission()
        
        switch status {
        case .authorized:
            return .proceed
            
        case .notDetermined:
            let granted = await requestPermission()
            return granted ? .proceed : .denied
            
        case .denied, .restricted:
            return .needsSettings
        }
    }
}

enum CameraAccessResult {
    case proceed
    case denied
    case needsSettings
}
