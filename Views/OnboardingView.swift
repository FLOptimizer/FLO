//  OnboardingView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Fixed All Mileage Setup Issues
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ Fixed Page 3 "Location access..." text hidden behind nav buttons
//  ✅ Fixed "Upgrade to Always Allow" button not working after user declines
//  ✅ iOS only shows Always prompt ONCE - now directs to Settings after decline
//  ✅ Button text changes to "Open Phone Settings" after Always is declined
//  ✅ Added buttonIcon computed property for dynamic icon updates
//
//  PREVIOUS (v2.1):
//  - Fixed "Skip for Now" button hidden behind page indicator dots
//  - Fixed timing issue with Limited Mode sheet showing prematurely
//
//  Beautiful first-time user experience with feature highlights and permissions

import SwiftUI
import LocalAuthentication
import CoreLocation
import AVFoundation
import UserNotifications

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("mileageSetupCompleted") private var mileageSetupCompleted = false
    
    @State private var currentPage = 0
    @State private var showingPermissionDeniedAlert = false
    @State private var showingLimitedModeSheet = false
    
    @StateObject private var mileageLocationManager = MileageSetupLocationManager()
    
    private let totalPages = 5  // Welcome, Features, Permissions, Mileage Setup, Get Started
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(flowHex: "14B8A6").opacity(0.1),
                    Color(flowHex: "0D9488").opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                if currentPage < totalPages - 1 {
                    HStack {
                        Spacer()
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundStyle(Color(flowHex: "14B8A6"))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePageView()
                        .tag(0)
                    
                    FeaturesPageView()
                        .tag(1)
                    
                    PermissionsPageView(
                        showingDeniedAlert: $showingPermissionDeniedAlert
                    )
                        .tag(2)
                    
                    MileageSetupPageView(
                        locationManager: mileageLocationManager,
                        showingLimitedModeSheet: $showingLimitedModeSheet,
                        onSetupComplete: {
                            mileageSetupCompleted = true
                            withAnimation {
                                currentPage = 4
                            }
                        },
                        onSkip: {
                            withAnimation {
                                currentPage = 4
                            }
                        }
                    )
                        .tag(3)
                    
                    GetStartedPageView(
                        completeAction: completeOnboarding
                    )
                        .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack(spacing: 20) {
                    // Back button
                    if currentPage > 0 {
                        Button {
                            withAnimation {
                                currentPage -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Next/Get Started button (hide on mileage setup page - it has its own buttons)
                    if currentPage < totalPages - 1 && currentPage != 3 {
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(flowHex: "14B8A6"))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .alert("Permission Denied", isPresented: $showingPermissionDeniedAlert) {
            Button("Settings", role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You can enable permissions later in Phone Settings → FLO")
        }
        .sheet(isPresented: $showingLimitedModeSheet) {
            LimitedModeExplanationView(
                onOpenSettings: {
                    showingLimitedModeSheet = false
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                onContinue: {
                    showingLimitedModeSheet = false
                    mileageSetupCompleted = true
                    withAnimation {
                        currentPage = 4
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Welcome Page

struct WelcomePageView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App icon placeholder (or use actual icon)
            ZStack {
                Circle()
                    .fill(Color(flowHex: "14B8A6"))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(flowHex: "14B8A6").opacity(0.3), radius: 20)
            
            VStack(spacing: 12) {
                Text("Welcome to FLO")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Finance Ledger Optimizer")
                    .font(.title3)
                    .foregroundStyle(Color(flowHex: "14B8A6"))
            }
            
            VStack(spacing: 16) {
                Text("Take control of your business finances")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                
                Text("Track expenses, estimate taxes, manage invoices, and stay organized—all from your iPhone.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 30)
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Page

struct FeaturesPageView: View {
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Text("Everything You Need")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Powerful features for freelancers and small businesses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            VStack(spacing: 20) {
                OnboardingFeatureRow(
                    icon: "chart.bar.fill",
                    iconColor: Color(flowHex: "14B8A6"),
                    title: "Smart Tax Estimates",
                    description: "Know what you owe before tax season arrives"
                )
                
                OnboardingFeatureRow(
                    icon: "camera.fill",
                    iconColor: .blue,
                    title: "Receipt Scanning",
                    description: "Snap photos and auto-categorize expenses with AI"
                )
                
                OnboardingFeatureRow(
                    icon: "doc.text.fill",
                    iconColor: .purple,
                    title: "Professional Invoicing",
                    description: "Create and send beautiful PDF invoices to clients"
                )
                
                OnboardingFeatureRow(
                    icon: "car.fill",
                    iconColor: .orange,
                    title: "Mileage Tracking",
                    description: "Automatic GPS tracking for tax deductions"
                )
                
                OnboardingFeatureRow(
                    icon: "chart.pie.fill",
                    iconColor: .green,
                    title: "Budget Management",
                    description: "Envelope-style budgets with automatic rollover"
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// MARK: - Permissions Page

struct PermissionsPageView: View {
    @Binding var showingDeniedAlert: Bool
    @State private var cameraGranted = false
    @State private var notificationsGranted = false
    @State private var biometricsGranted = false
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color(flowHex: "14B8A6"))
                    .padding(.bottom, 10)
                
                Text("Quick Setup")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("FLO needs a few permissions to work its magic")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 30)
            
            ScrollView {
                VStack(spacing: 14) {
                    // Camera
                    OnboardingPermissionCard(
                        icon: "camera.fill",
                        title: "Camera Access",
                        description: "Scan receipts and capture expense photos",
                        isGranted: $cameraGranted,
                        action: requestCameraPermission
                    )
                    
                    // Notifications
                    OnboardingPermissionCard(
                        icon: "bell.badge.fill",
                        title: "Notifications",
                        description: "Get reminders for tax deadlines and invoices",
                        isGranted: $notificationsGranted,
                        action: requestNotificationPermission
                    )
                    
                    // Biometrics
                    OnboardingPermissionCard(
                        icon: "faceid",
                        title: "Face ID / Touch ID",
                        description: "Secure your financial data with biometrics",
                        isGranted: $biometricsGranted,
                        action: requestBiometricPermission
                    )
                }
                .padding(.horizontal)
            }
            
            Text("Location access is set up on the next screen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 80) // Extra padding to clear navigation buttons
        }
        .onAppear {
            checkExistingPermissions()
        }
    }
    
    // MARK: - Permission Checks
    
    private func checkExistingPermissions() {
        // Check camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraGranted = (cameraStatus == .authorized)
        
        // Check notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsGranted = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    // MARK: - Permission Requests
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                withAnimation {
                    cameraGranted = granted
                    if !granted {
                        showingDeniedAlert = true
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                withAnimation {
                    notificationsGranted = granted
                    if !granted {
                        showingDeniedAlert = true
                    }
                }
            }
        }
    }
    
    private func requestBiometricPermission() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Secure access to FLO") { success, _ in
                DispatchQueue.main.async {
                    withAnimation {
                        biometricsGranted = success
                    }
                }
            }
        } else {
            // Biometrics not available
            withAnimation {
                biometricsGranted = false
            }
        }
    }
}

// MARK: - Mileage Setup Page (NEW in v2.0)

struct MileageSetupPageView: View {
    @ObservedObject var locationManager: MileageSetupLocationManager
    @Binding var showingLimitedModeSheet: Bool
    let onSetupComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var hasRequestedPermission = false
    @State private var hasRequestedAlways = false // Track if we've already asked for Always
    @State private var isWaitingForAlwaysResponse = false
    
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "car.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 12) {
                Text("Automatic Mileage Tracking")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Track business miles automatically while you drive—even when FLO is in the background.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Info card
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(Color(flowHex: "14B8A6"))
                        .frame(width: 24)
                    
                    Text("Why choose \"Always Allow\"?")
                        .font(.headline)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    MileageSetupBullet(text: "Records trips with app in background")
                    MileageSetupBullet(text: "No need to manually start tracking")
                    MileageSetupBullet(text: "Battery-optimized GPS tracking")
                    MileageSetupBullet(text: "Your location stays on your device")
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            
            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color(flowHex: "14B8A6"))
                Text("Your location data never leaves your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Buttons - added extra bottom padding to clear page dots
            VStack(spacing: 12) {
                Button {
                    impactMedium.impactOccurred()
                    requestLocationPermission()
                } label: {
                    HStack {
                        Image(systemName: buttonIcon)
                        Text(buttonTitle)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(buttonColor)
                    .cornerRadius(12)
                }
                .disabled(locationManager.authorizationStatus == .authorizedAlways)
                
                Button {
                    onSkip()
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 30) // Extra padding to clear page indicator dots
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .onChange(of: locationManager.authorizationStatus) { oldValue, newValue in
            handleAuthorizationChange(from: oldValue, to: newValue)
        }
    }
    
    private var buttonIcon: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "checkmark.circle.fill"
        case .authorizedWhenInUse:
            return hasRequestedAlways ? "gearshape.fill" : "location.fill"
        case .denied, .restricted:
            return "gearshape.fill"
        default:
            return "location.fill"
        }
    }
    
    private var buttonTitle: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "Tracking Enabled ✓"
        case .authorizedWhenInUse:
            // If we already asked for Always and they declined, direct to Settings
            return hasRequestedAlways ? "Open Phone Settings" : "Upgrade to Always Allow"
        case .denied, .restricted:
            return "Open Phone Settings"
        default:
            return "Enable Mileage Tracking"
        }
    }
    
    private var buttonColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return .green
        case .authorizedWhenInUse:
            return .orange
        case .denied, .restricted:
            return .red
        default:
            return Color(flowHex: "14B8A6")
        }
    }
    
    private func requestLocationPermission() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            // First time - request "When In Use" first (iOS requires this)
            hasRequestedPermission = true
            locationManager.requestWhenInUseAuthorization()
            
        case .authorizedWhenInUse:
            if hasRequestedAlways {
                // Already asked for Always and user declined - go to Settings
                openSettings()
            } else {
                // Haven't asked for Always yet - request it now
                isWaitingForAlwaysResponse = true
                hasRequestedAlways = true
                locationManager.requestAlwaysAuthorization()
            }
            
        case .authorizedAlways:
            // Already have Always - complete setup
            notificationFeedback.notificationOccurred(.success)
            onSetupComplete()
            
        case .denied, .restricted:
            // Need to go to settings
            openSettings()
            
        @unknown default:
            break
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func handleAuthorizationChange(from oldValue: CLAuthorizationStatus, to newValue: CLAuthorizationStatus) {
        guard hasRequestedPermission else { return }
        
        switch newValue {
        case .authorizedAlways:
            // Perfect! User chose Always Allow
            isWaitingForAlwaysResponse = false
            notificationFeedback.notificationOccurred(.success)
            onSetupComplete()
            
        case .authorizedWhenInUse:
            // User chose "While Using App"
            if oldValue == .notDetermined {
                // Just got "When In Use" from first prompt - now request Always
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isWaitingForAlwaysResponse = true
                    hasRequestedAlways = true
                    locationManager.requestAlwaysAuthorization()
                }
            } else if isWaitingForAlwaysResponse {
                // User declined the "Always Allow" prompt
                isWaitingForAlwaysResponse = false
                showingLimitedModeSheet = true
            }
            
        case .denied, .restricted:
            // User denied - show limited mode explanation
            isWaitingForAlwaysResponse = false
            showingLimitedModeSheet = true
            
        default:
            break
        }
    }
}

// MARK: - Mileage Setup Bullet Point

struct MileageSetupBullet: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(flowHex: "14B8A6"))
                .font(.subheadline)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Limited Mode Explanation View

struct LimitedModeExplanationView: View {
    let onOpenSettings: () -> Void
    let onContinue: () -> Void
    
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                }
                
                Text("Limited Tracking Mode")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text("You selected \"While Using App\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            
            // What this means
            VStack(alignment: .leading, spacing: 16) {
                Text("This means:")
                    .font(.headline)
                
                LimitedModeRow(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    text: "Trips won't record when FLO is closed"
                )
                
                LimitedModeRow(
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    text: "You'll need to keep the app open while driving"
                )
                
                LimitedModeRow(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    text: "You can change this anytime in Phone Settings → FLO → Location"
                )
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    impactMedium.impactOccurred()
                    onOpenSettings()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Open Phone Settings")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(flowHex: "14B8A6"))
                    .cornerRadius(12)
                }
                
                Button {
                    onContinue()
                } label: {
                    Text("Continue with Limited Mode")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Limited Mode Row

struct LimitedModeRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.subheadline)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Get Started Page

struct GetStartedPageView: View {
    let completeAction: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Success icon
            ZStack {
                Circle()
                    .fill(Color(flowHex: "14B8A6").opacity(0.2))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(Color(flowHex: "14B8A6"))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(flowHex: "14B8A6").opacity(0.3), radius: 20)
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("Start tracking your business finances with FLO")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            VStack(spacing: 12) {
                QuickTipRow(
                    icon: "plus.circle.fill",
                    text: "Add your first transaction to get started"
                )
                
                QuickTipRow(
                    icon: "camera.fill",
                    text: "Tap the camera icon to scan a receipt"
                )
                
                QuickTipRow(
                    icon: "gearshape.fill",
                    text: "Visit Settings to customize categories and tax info"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Get Started button
            Button {
                completeAction()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(flowHex: "14B8A6"))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Mileage Setup Location Manager

class MileageSetupLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

// MARK: - Supporting Views

struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct OnboardingPermissionCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isGranted ? Color.green.opacity(0.15) : Color(flowHex: "14B8A6").opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isGranted ? .green : Color(flowHex: "14B8A6"))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Button {
                    action()
                } label: {
                    if isGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else {
                        Text("Enable")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color(flowHex: "14B8A6"))
                            .cornerRadius(8)
                    }
                }
                .disabled(isGranted)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct QuickTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: "14B8A6"))
                .frame(width: 30)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
