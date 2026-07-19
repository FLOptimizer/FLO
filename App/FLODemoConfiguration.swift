//  FLODemoConfiguration.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Simulator-only data-safety guard
//
//  CHANGES v1.1:
//  ⛔️ CRITICAL: configure() now hard-refuses on a physical device
//     (#if !targetEnvironment(simulator) → return). Demo mode wipes + seeds
//     data; running the scheme on a real device destroyed real CloudKit data.
//     Also disabled the DEMO_* launch args in FLO.xcscheme by default.
//
//  Version 1.0 - Demo Video Recording Support
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Configures the app for automated demo video recording.
//  Handles launch arguments from FLODemoTests to set up
//  consistent demo data, skip auth, and control onboarding state.
//
//  TARGET: FLO (main app target) — NOT FLOUITests
//
//  LAUNCH ARGUMENTS:
//  DEMO_MODE           — Seeds demo data and enables demo configuration
//  DEMO_SKIP_AUTH      — Bypasses Face ID / passcode lock screen
//  DEMO_SKIP_ONBOARDING — Skips onboarding, goes straight to main app
//  DEMO_SHOW_ONBOARDING — Forces onboarding to show (even if completed before)
//  DEMO_CLEAN_STATE    — Resets all data before seeding
//  DEMO_PREMIUM_TIER   — Simulates Premium subscription
//  DEMO_PRO_TIER       — Simulates Pro subscription
//

import Foundation
import SwiftData

// MARK: - Demo Configuration

/// Detects and manages demo mode for video recording.
/// Call `DemoConfiguration.configure()` from FLOApp.setupApp()
/// when `UI_TESTING` or `DEMO_MODE` is present in launch arguments.
@MainActor
struct DemoConfiguration {
    
    /// Whether the app was launched in demo recording mode
    static var isDemoMode: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_MODE")
    }
    
    /// Whether to skip biometric/passcode authentication
    static var shouldSkipAuth: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_SKIP_AUTH")
    }
    
    /// Whether to skip onboarding (go straight to dashboard)
    static var shouldSkipOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_SKIP_ONBOARDING")
    }
    
    /// Whether to force-show onboarding (for onboarding video)
    static var shouldShowOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_SHOW_ONBOARDING")
    }
    
    /// Whether to wipe all data before seeding
    static var shouldCleanState: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_CLEAN_STATE")
    }
    
    /// Whether to simulate Premium tier
    static var shouldSimulatePremium: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_PREMIUM_TIER")
    }
    
    /// Whether to simulate Pro tier
    static var shouldSimulatePro: Bool {
        ProcessInfo.processInfo.arguments.contains("DEMO_PRO_TIER")
    }
    
    // MARK: - Configure
    
    /// Main entry point — call from FLOApp.setupApp() or .onAppear
    /// Applies all demo configuration based on launch arguments.
    static func configure(context: ModelContext) async {
        guard isDemoMode else { return }

        // ⛔️ DATA-SAFETY GUARD (added after running this scheme on a physical
        // device wiped real, CloudKit-synced user data):
        // Demo mode performs DESTRUCTIVE operations — resetAllData() + seed.
        // It must NEVER run on a real device, which holds real user data.
        // `#if DEBUG` is insufficient: a device Debug build from Xcode is still
        // DEBUG. Gate on the simulator at compile time so the destructive path
        // does not even exist in a device binary.
        #if !targetEnvironment(simulator)
        print("⛔️ DEMO_MODE requested on a physical device — refusing for data safety.")
        return
        #endif

        print("🎬 ═══════════════════════════════════════")
        print("🎬 DEMO MODE ACTIVE — Configuring for video recording")
        print("🎬 ═══════════════════════════════════════")
        
        // 1. Handle onboarding state
        if shouldSkipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            print("🎬 Onboarding: SKIPPED")
        } else if shouldShowOnboarding {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            print("🎬 Onboarding: FORCED to show")
        }
        
        // 2. Handle auth bypass
        if shouldSkipAuth {
            // BiometricAuthService checks for UI_TESTING arg already,
            // but we ensure the passcode is also cleared for demos
            UserDefaults.standard.set(false, forKey: "isPasscodeEnabled")
            UserDefaults.standard.set(false, forKey: "isBiometricEnabled")
            print("🎬 Authentication: BYPASSED")
        }
        
        // 3. Set demo user profile
        UserDefaults.standard.set("Alex Rivera", forKey: "userName")
        UserDefaults.standard.set("alex@riveradesign.co", forKey: "userEmail")
        print("🎬 Demo persona: Alex Rivera (Freelance Designer)")
        
        // 4. Clean state if requested
        if shouldCleanState {
            #if DEBUG
            await SeedDataService.shared.resetAllData(context: context)
            print("🎬 Data: RESET to clean state")
            #endif
        }
        
        // 5. Seed demo data
        #if DEBUG
        await SeedDataService.shared.seedAllData(context: context)
        print("🎬 Demo data: SEEDED")
        // Views that loaded before this async seed finished (e.g. the Dashboard's
        // .task fetch) would otherwise show empty state until a manual toggle.
        NotificationCenter.default.post(name: .demoDataSeeded, object: nil)
        #endif
        
        // 6. Handle subscription tier simulation
        if shouldSimulatePro {
            // SubscriptionManager can check launch args for tier override
            print("🎬 Subscription: PRO tier simulated")
        } else if shouldSimulatePremium {
            print("🎬 Subscription: PREMIUM tier simulated")
        } else {
            print("🎬 Subscription: Using current tier")
        }
        
        // 7. Disable mileage auto-tracking (we don't want GPS popups in demos)
        UserDefaults.standard.set(false, forKey: "mileageSetupCompleted")
        UserDefaults.standard.set(false, forKey: "mileageTrackingEnabled")
        UserDefaults.standard.set(false, forKey: "mileage.isTrackingActive")
        print("🎬 Mileage auto-tracking: DISABLED (manual demos only)")
        
        print("🎬 ═══════════════════════════════════════")
        print("🎬 DEMO CONFIGURATION COMPLETE")
        print("🎬 ═══════════════════════════════════════")
    }
}

// MARK: - Integration Point
//
// Add to FLOApp.swift setupApp() method:
//
//   private func setupApp() {
//       let context = ModelContext(container)
//
//       // Demo mode configuration (video recording)
//       if DemoConfiguration.isDemoMode {
//           Task { @MainActor in
//               await DemoConfiguration.configure(context: context)
//           }
//           return  // Skip normal setup when in demo mode
//       }
//
//       // ... existing setup code ...
//   }
//
// And in SubscriptionManager, add tier override:
//
//   var currentTier: SubscriptionTier {
//       #if DEBUG
//       if ProcessInfo.processInfo.arguments.contains("DEMO_PRO_TIER") {
//           return .pro
//       }
//       if ProcessInfo.processInfo.arguments.contains("DEMO_PREMIUM_TIER") {
//           return .premium
//       }
//       #endif
//       return _currentTier
//   }
