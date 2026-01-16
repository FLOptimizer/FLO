//  ColorSchemeSystem.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Color scheme management system
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI

// MARK: - Color Scheme Definition

struct FLOColorScheme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let emoji: String
    
    // Core brand colors
    let primary: String          // Main brand color
    let primaryDark: String      // Darker variant
    let accent: String           // Success/positive actions
    let warning: String          // Warnings
    let error: String            // Errors/negative
    
    // Semantic colors
    let income: String           // Income transactions
    let expense: String          // Expense transactions
    let business: String         // Business category
    let personal: String         // Personal category
    
    // UI colors
    let background: String       // Light background
    let cardBackground: String   // Card/elevated surfaces
    let textPrimary: String      // Primary text
    let textSecondary: String    // Secondary text
    
    static func == (lhs: FLOColorScheme, rhs: FLOColorScheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Available Color Schemes

extension FLOColorScheme {
    
    // 1. ORIGINAL TEAL (Default)
    static let originalTeal = FLOColorScheme(
        id: "teal",
        name: "Ocean Teal",
        description: "FLO's signature color scheme - fresh, professional, and growth-oriented",
        emoji: "🌊",
        primary: "14B8A6",
        primaryDark: "0D9488",
        accent: "10B981",
        warning: "F59E0B",
        error: "EF4444",
        income: "10B981",
        expense: "EF4444",
        business: "14B8A6",
        personal: "3B82F6",
        background: "F9FAFB",
        cardBackground: "FFFFFF",
        textPrimary: "1F2937",
        textSecondary: "6B7280"
    )
    
    // 2. NATURE GROWTH (Greens)
    static let natureGrowth = FLOColorScheme(
        id: "nature",
        name: "Nature Growth",
        description: "Earthy greens symbolizing prosperity and natural financial growth",
        emoji: "🌿",
        primary: "3CB371",        // Medium Sea Green
        primaryDark: "228B22",    // Forest Green
        accent: "93C572",         // Pistachio
        warning: "BB9135",        // Dark Goldenrod
        error: "CD5C5C",          // Indian Red
        income: "93C572",         // Pistachio
        expense: "CD5C5C",        // Indian Red
        business: "228B22",       // Forest Green
        personal: "8FBC8F",       // Dark Sea Green
        background: "F5F7F4",
        cardBackground: "FFFFFF",
        textPrimary: "2C3E2F",
        textSecondary: "5C6B5E"
    )
    
    // 3. WARM PROSPERITY (Golds/Warm Neutrals)
    static let warmProsperity = FLOColorScheme(
        id: "warm",
        name: "Warm Prosperity",
        description: "Rich golds and warm tones evoking abundance and success",
        emoji: "✨",
        primary: "BB9135",        // Dark Goldenrod
        primaryDark: "8B6914",    // Darker Gold
        accent: "EDCF8E",         // Peach Yellow
        warning: "F58BC0",        // Persian Pink
        error: "C55A5A",          // Warm Red
        income: "EDCF8E",         // Peach Yellow
        expense: "C55A5A",        // Warm Red
        business: "BB9135",       // Dark Goldenrod
        personal: "A0785A",       // Mocha
        background: "FAF8F5",
        cardBackground: "FFFFFF",
        textPrimary: "2A2B2A",
        textSecondary: "5C5754"
    )
    
    // 4. OCEAN BLUE (Professional Blues)
    static let oceanBlue = FLOColorScheme(
        id: "ocean",
        name: "Ocean Blue",
        description: "Trustworthy blues creating calm confidence in your finances",
        emoji: "🌌",
        primary: "3066BE",        // Medium Blue
        primaryDark: "090C9B",    // Dark Blue
        accent: "60A5FA",         // Sky Blue
        warning: "FBBF24",        // Amber
        error: "F87171",          // Light Red
        income: "60A5FA",         // Sky Blue
        expense: "F87171",        // Light Red
        business: "090C9B",       // Dark Blue
        personal: "B4C5E4",       // Light Blue
        background: "F8FAFC",
        cardBackground: "FFFFFF",
        textPrimary: "1E293B",
        textSecondary: "64748B"
    )
    
    // 5. SUNSET AMBER (Warm Optimism)
    static let sunsetAmber = FLOColorScheme(
        id: "sunset",
        name: "Sunset Amber",
        description: "Warm sunset tones inspiring optimism and positive momentum",
        emoji: "🌅",
        primary: "F97316",        // Orange
        primaryDark: "EA580C",    // Dark Orange
        accent: "FBBF24",         // Amber
        warning: "F59E0B",        // Yellow
        error: "DC2626",          // Red
        income: "FBBF24",         // Amber
        expense: "DC2626",        // Red
        business: "F97316",       // Orange
        personal: "FB923C",       // Light Orange
        background: "FFFBF5",
        cardBackground: "FFFFFF",
        textPrimary: "1C1917",
        textSecondary: "57534E"
    )
    
    // 6. MODERN MINIMALIST (Sophisticated Grays)
    static let modernMinimalist = FLOColorScheme(
        id: "minimal",
        name: "Modern Minimal",
        description: "Clean, sophisticated neutrals with strategic pops of color",
        emoji: "⚡",
        primary: "404040",        // Charcoal
        primaryDark: "262626",    // Darker Charcoal
        accent: "10B981",         // Emerald (accent pop)
        warning: "F59E0B",        // Amber
        error: "EF4444",          // Red
        income: "10B981",         // Emerald
        expense: "EF4444",        // Red
        business: "404040",       // Charcoal
        personal: "737373",       // Medium Gray
        background: "FAFAFA",
        cardBackground: "FFFFFF",
        textPrimary: "171717",
        textSecondary: "737373"
    )
    
    // All available schemes
    static let allSchemes: [FLOColorScheme] = [
        .originalTeal,
        .natureGrowth,
        .warmProsperity,
        .oceanBlue,
        .sunsetAmber,
        .modernMinimalist
    ]
}

// MARK: - Color Scheme Manager

@Observable
class ColorSchemeManager {
    static let shared = ColorSchemeManager()
    
    private(set) var currentScheme: FLOColorScheme {
        didSet {
            saveCurrentScheme()
        }
    }
    
    private init() {
        // Load saved scheme or use default
        if let savedID = UserDefaults.standard.string(forKey: "selectedColorScheme"),
           let scheme = FLOColorScheme.allSchemes.first(where: { $0.id == savedID }) {
            currentScheme = scheme
        } else {
            currentScheme = .originalTeal
        }
    }
    
    func selectScheme(_ scheme: FLOColorScheme) {
        currentScheme = scheme
    }
    
    private func saveCurrentScheme() {
        UserDefaults.standard.set(currentScheme.id, forKey: "selectedColorScheme")
    }
    
    // Convenience accessors for current colors
    var primary: Color { Color.flow(currentScheme.primary) }
    var primaryDark: Color { Color.flow(currentScheme.primaryDark) }
    var accent: Color { Color.flow(currentScheme.accent) }
    var warning: Color { Color.flow(currentScheme.warning) }
    var error: Color { Color.flow(currentScheme.error) }
    var income: Color { Color.flow(currentScheme.income) }
    var expense: Color { Color.flow(currentScheme.expense) }
    var business: Color { Color.flow(currentScheme.business) }
    var personal: Color { Color.flow(currentScheme.personal) }
    var background: Color { Color.flow(currentScheme.background) }
    var cardBackground: Color { Color.flow(currentScheme.cardBackground) }
    var textPrimary: Color { Color.flow(currentScheme.textPrimary) }
    var textSecondary: Color { Color.flow(currentScheme.textSecondary) }
}

// MARK: - Environment Key

struct ColorSchemeManagerKey: EnvironmentKey {
    static let defaultValue = ColorSchemeManager.shared
}

extension EnvironmentValues {
    var colorSchemeManager: ColorSchemeManager {
        get { self[ColorSchemeManagerKey.self] }
        set { self[ColorSchemeManagerKey.self] = newValue }
    }
}
