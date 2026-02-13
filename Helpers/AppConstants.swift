//  AppConstants.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Added EULA URL constant
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Crash-safe URLs, brand colors, and configuration values
//

import Foundation
import SwiftUI

/// Application-wide constants including colors, URLs, and configuration values.
/// Uses enum pattern to prevent instantiation.
enum AppConstants {
    
    // MARK: - Brand Colors (Teal Palette)
    
    /// Primary brand color - Teal 500
    static let primaryColor = Color(red: 0x14 / 255.0, green: 0xB8 / 255.0, blue: 0xA6 / 255.0)
    
    /// Secondary brand color - Teal 600
    static let secondaryColor = Color(red: 0x0D / 255.0, green: 0x94 / 255.0, blue: 0x88 / 255.0)
    
    /// Accent color - Green 500 (for income)
    static let accentColor = Color(red: 0x10 / 255.0, green: 0xB9 / 255.0, blue: 0x81 / 255.0)
    
    // MARK: - Text Colors
    
    /// Primary text color (adapts to light/dark mode)
    static let primaryText = Color.primary
    
    /// Secondary text color (muted)
    static let secondaryText = Color.secondary
    
    /// Tertiary text color (most muted)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    
    // MARK: - Background Colors
    
    /// Grouped background color (adapts to light/dark mode)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    
    // MARK: - URLs (Crash-Safe)

    /// Company website URL - guaranteed to be valid
    static let websiteURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/") else {
            fatalError("Invalid website URL - this should never happen")
        }
        return url
    }()

    /// GitHub repository URL - guaranteed to be valid
    static let githubURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/") else {
            fatalError("Invalid GitHub URL - this should never happen")
        }
        return url
    }()

    /// Support email URL - guaranteed to be valid
    static let supportEmailURL: URL = {
        guard let url = URL(string: "mailto:flo.financeapp@gmail.com") else {
            fatalError("Invalid support email URL - this should never happen")
        }
        return url
    }()

    /// Privacy policy URL - guaranteed to be valid
    static let privacyPolicyURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/privacy.html") else {
            fatalError("Invalid privacy policy URL - this should never happen")
        }
        return url
    }()

    /// Terms of service URL - guaranteed to be valid
    static let termsOfServiceURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/terms.html") else {
            fatalError("Invalid terms of service URL - this should never happen")
        }
        return url
    }()

    /// Legal disclaimer URL - guaranteed to be valid
    static let disclaimerURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/legal.html") else {
            fatalError("Invalid disclaimer URL - this should never happen")
        }
        return url
    }()

    /// End User License Agreement URL - guaranteed to be valid
    static let eulaURL: URL = {
        guard let url = URL(string: "https://floptimizer.github.io/FLO/eula.html") else {
            fatalError("Invalid EULA URL - this should never happen")
        }
        return url
    }()
    
    // MARK: - App Information
    
    /// Bundle identifier with fallback
    static let bundleIdentifier: String = {
        Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo"
    }()
    
    /// App version string
    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()
    
    /// Build number string
    static let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()
    
    /// Full version string (e.g., "1.0 (1)")
    static let fullVersionString: String = {
        "\(appVersion) (\(buildNumber))"
    }()
    
    // MARK: - Feature Flags
    
    /// Enable premium features (for future monetization)
    static let enablePremiumFeatures: Bool = false
    
    /// Enable debug logging
    static let enableDebugLogging: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Plaid Configuration
    
    /// Plaid environment (sandbox vs production)
    static let plaidEnvironment: PlaidEnvironment = {
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }()
    
    enum PlaidEnvironment: String {
        case sandbox = "sandbox"
        case development = "development"
        case production = "production"
    }
    
    // MARK: - Tax Configuration
    
    /// Default tax filing status
    static let defaultTaxFilingStatus: TaxFilingStatus = .single
    
    enum TaxFilingStatus: String, CaseIterable {
        case single = "single"
        case married = "married"
        case headOfHousehold = "headOfHousehold"
        
        var displayName: String {
            switch self {
            case .single:           return "Single"
            case .married:          return "Married Filing Jointly"
            case .headOfHousehold:  return "Head of Household"
            }
        }
    }
    
    // MARK: - Mileage Configuration
    
    /// Current IRS standard mileage rate (2026)
    static let currentIRSMileageRate: Double = 0.725
    
    /// Minimum trip distance to auto-track (miles)
    static let minimumAutoTrackDistance: Double = 0.5
    
    // MARK: - Budget Configuration
    
    /// Default budget warning threshold percentage
    static let defaultBudgetWarningThreshold: Double = 0.80 // 80%
    
    // MARK: - Date Formatting
    
    /// Standard date formatter for display
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Standard currency formatter
    static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
    
    // MARK: - Animation Durations
    
    /// Standard animation duration
    static let standardAnimationDuration: Double = 0.3
    
    /// Quick animation duration
    static let quickAnimationDuration: Double = 0.15
    
    /// Slow animation duration
    static let slowAnimationDuration: Double = 0.5
}

// MARK: - Sendable Conformance

extension AppConstants: Sendable { }
