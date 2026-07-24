//  FLOColors.swift
//  FLODesignSystem
//
//  Shared color tokens for FLO across iOS, iPadOS, and macOS.
//  Extracted from ColorSchemeSystem.swift and Color+Extensions.swift (FLO 2.1).
//
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

// MARK: - Canvas & Surface Colors (Adaptive Light/Dark)

/// Core design tokens for the FLO canvas design language.
/// Adaptive to the active color scheme (light/dark) on iOS, iPadOS, and macOS.
public enum FLOCanvasColors {

    // MARK: Adaptive color helper

    /// Build a SwiftUI Color that resolves differently in light vs dark appearance.
    /// `dark` is the value used in dark mode; `light` is used in light mode.
    static func adaptive(light: (r: Double, g: Double, b: Double, a: Double),
                         dark:  (r: Double, g: Double, b: Double, a: Double)) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: CGFloat(dark.r),  green: CGFloat(dark.g),  blue: CGFloat(dark.b),  alpha: CGFloat(dark.a))
                : UIColor(red: CGFloat(light.r), green: CGFloat(light.g), blue: CGFloat(light.b), alpha: CGFloat(light.a))
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: CGFloat(dark.r),  green: CGFloat(dark.g),  blue: CGFloat(dark.b),  alpha: CGFloat(dark.a))
                : NSColor(red: CGFloat(light.r), green: CGFloat(light.g), blue: CGFloat(light.b), alpha: CGFloat(light.a))
        })
        #endif
    }

    // MARK: Surfaces

    /// Deep background — primary app background (the canvas behind cards).
    /// Light: #F2F2F7 (Apple systemGroupedBackground tint, so white cards read).
    /// Dark:  #07070D.
    public static let canvas = adaptive(
        light: (0.949, 0.949, 0.969, 1.0),                 // #F2F2F7
        dark:  (0.027, 0.027, 0.051, 1.0)                  // #07070D
    )

    /// Elevated surface — sidebar / card background that sits on top of canvas.
    /// Light: pure white (cards). Dark: #0F0F18.
    public static let surface = adaptive(
        light: (1.0, 1.0, 1.0, 1.0),                       // #FFFFFF
        dark:  (0.059, 0.059, 0.094, 1.0)                  // #0F0F18
    )

    /// Glass card fill — translucent card background.
    /// Light: black @ 4%. Dark: white @ 4%.
    public static let cardGlass = adaptive(
        light: (0.0, 0.0, 0.0, 0.04),
        dark:  (1.0, 1.0, 1.0, 0.04)
    )

    /// Glass card border.
    /// Light: black @ 10%. Dark: white @ 8%.
    public static let cardBorder = adaptive(
        light: (0.0, 0.0, 0.0, 0.10),
        dark:  (1.0, 1.0, 1.0, 0.08)
    )

    /// Hover/press state for interactive elements.
    /// Light: black @ 6%. Dark: white @ 7%.
    public static let surfaceHover = adaptive(
        light: (0.0, 0.0, 0.0, 0.06),
        dark:  (1.0, 1.0, 1.0, 0.07)
    )

    /// Semantic ambient glow — teal at 15% opacity in dark mode, clear in light mode.
    /// Used by FLOCardShadowModifier for dark canvas card separation.
    public static let semanticGlow = adaptive(
        light: (0.0,   0.0,   0.0,   0.0),                 // clear
        dark:  (0.078, 0.722, 0.651, 0.15)                 // teal @ 15%
    )

    // MARK: Text

    /// Text: primary.
    /// Light: #1C1C1E. Dark: #F5F5F7.
    public static let textPrimary = adaptive(
        light: (0.110, 0.110, 0.118, 1.0),                 // #1C1C1E
        dark:  (0.961, 0.961, 0.969, 1.0)                  // #F5F5F7
    )

    /// Text: secondary (medium emphasis).
    public static let textSecondary = adaptive(
        light: (0.110, 0.110, 0.118, 0.60),
        dark:  (0.961, 0.961, 0.969, 0.55)
    )

    /// Text: tertiary (dim/hint).
    public static let textTertiary = adaptive(
        light: (0.110, 0.110, 0.118, 0.40),
        dark:  (0.961, 0.961, 0.969, 0.30)
    )
}

// MARK: - Brand & Semantic Colors

/// Brand and semantic color tokens shared across all platforms.
public enum FLOSemanticColors {
    /// FLO brand teal — primary accent
    public static let teal = Color(hex: "14B8A6")

    /// Dark teal variant
    public static let tealDark = Color(hex: "0D9488")

    /// Income / positive values
    public static let income = Color(hex: "34D399")

    /// Expense / negative values
    public static let expense = Color(hex: "F87171")

    /// Warning state (near budget, upcoming deadline)
    public static let warning = Color(hex: "FBBF24")

    /// Error state
    public static let error = Color(hex: "EF4444")

    /// Success / positive action
    public static let success = Color(hex: "10B981")

    /// Secondary accent — blue
    public static let blue = Color(hex: "60A5FA")

    /// Tertiary accent — purple
    public static let purple = Color(hex: "A78BFA")
}

// MARK: - Category Tag Colors

/// Specific colors for expense/income category pill tags.
/// Each category has a distinct color for instant visual recognition.
public enum FLOCategoryColors {
    // Expense categories
    public static let diningOut = Color(hex: "DC2626")       // Red
    public static let entertainment = Color(hex: "DB2777")    // Pink
    public static let groceries = Color(hex: "059669")        // Green
    public static let health = Color(hex: "E11D48")           // Rose
    public static let housing = Color(hex: "475569")          // Slate
    public static let officeSupplies = Color(hex: "0891B2")   // Cyan
    public static let softwareTools = Color(hex: "6366F1")    // Indigo
    public static let transportation = Color(hex: "D97706")   // Amber
    public static let utilities = Color(hex: "CA8A04")        // Yellow
    public static let shopping = Color(hex: "7C3AED")         // Violet

    // Special categories
    public static let clientPayment = Color(hex: "14B8A6")    // Teal (brand)
    public static let transfer = Color(hex: "64748B")         // Gray

    // Coffee is special: brown background, gold text
    public static let coffeeBackground = Color(hex: "92400E") // Brown
    public static let coffeeText = Color(hex: "FBBF24")       // Gold

    /// Returns the tag background color for a given category name.
    /// Category names are case-insensitive.
    public static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "dining out", "restaurants":       return diningOut
        case "entertainment":                   return entertainment
        case "groceries":                       return groceries
        case "health", "healthcare":            return health
        case "housing", "rent", "mortgage":     return housing
        case "office supplies", "office":       return officeSupplies
        case "software & tools", "software":    return softwareTools
        case "transportation", "transit":       return transportation
        case "utilities":                       return utilities
        case "shopping", "shops":               return shopping
        case "client payment", "income":        return clientPayment
        case "transfer":                        return transfer
        case "coffee":                          return coffeeBackground
        default:                                return Color(hex: "64748B") // Default gray
        }
    }

    /// Returns the text color for a given category.
    /// Most categories use white text; coffee uses gold.
    public static func textColor(for category: String) -> Color {
        switch category.lowercased() {
        case "coffee":  return coffeeText
        default:        return .white
        }
    }
}

// MARK: - Color Scheme Definition (preserved from FLO 2.1)

/// A complete FLO color scheme with brand, semantic, and UI colors.
/// Preserved for backward compatibility with the 6 existing user-selectable schemes.
public struct FLOColorScheme: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let emoji: String

    // Core brand colors (hex strings)
    public let primary: String
    public let primaryDark: String
    public let accent: String
    public let warning: String
    public let error: String

    // Semantic colors (hex strings)
    public let income: String
    public let expense: String
    public let business: String
    public let personal: String

    // UI colors (hex strings)
    public let background: String
    public let cardBackground: String
    public let textPrimary: String
    public let textSecondary: String

    public static func == (lhs: FLOColorScheme, rhs: FLOColorScheme) -> Bool {
        lhs.id == rhs.id
    }

    public init(
        id: String, name: String, description: String, emoji: String,
        primary: String, primaryDark: String, accent: String,
        warning: String, error: String,
        income: String, expense: String, business: String, personal: String,
        background: String, cardBackground: String,
        textPrimary: String, textSecondary: String
    ) {
        self.id = id; self.name = name; self.description = description; self.emoji = emoji
        self.primary = primary; self.primaryDark = primaryDark; self.accent = accent
        self.warning = warning; self.error = error
        self.income = income; self.expense = expense
        self.business = business; self.personal = personal
        self.background = background; self.cardBackground = cardBackground
        self.textPrimary = textPrimary; self.textSecondary = textSecondary
    }
}

// MARK: - Predefined Color Schemes

extension FLOColorScheme {

    public static let originalTeal = FLOColorScheme(
        id: "teal", name: "Ocean Teal", description: "FLO's signature color scheme - fresh, professional, and growth-oriented", emoji: "🌊",
        primary: "14B8A6", primaryDark: "0D9488", accent: "10B981", warning: "F59E0B", error: "EF4444",
        income: "10B981", expense: "EF4444", business: "14B8A6", personal: "3B82F6",
        background: "F9FAFB", cardBackground: "FFFFFF", textPrimary: "1F2937", textSecondary: "6B7280"
    )

    public static let natureGrowth = FLOColorScheme(
        id: "nature", name: "Nature Growth", description: "Earthy greens symbolizing prosperity and natural financial growth", emoji: "🌿",
        primary: "3CB371", primaryDark: "228B22", accent: "93C572", warning: "BB9135", error: "CD5C5C",
        income: "93C572", expense: "CD5C5C", business: "228B22", personal: "8FBC8F",
        background: "F5F7F4", cardBackground: "FFFFFF", textPrimary: "2C3E2F", textSecondary: "5C6B5E"
    )

    public static let warmProsperity = FLOColorScheme(
        id: "warm", name: "Warm Prosperity", description: "Rich golds and warm tones evoking abundance and success", emoji: "✨",
        primary: "BB9135", primaryDark: "8B6914", accent: "EDCF8E", warning: "F58BC0", error: "C55A5A",
        income: "EDCF8E", expense: "C55A5A", business: "BB9135", personal: "A0785A",
        background: "FAF8F5", cardBackground: "FFFFFF", textPrimary: "2A2B2A", textSecondary: "5C5754"
    )

    public static let oceanBlue = FLOColorScheme(
        id: "ocean", name: "Ocean Blue", description: "Trustworthy blues creating calm confidence in your finances", emoji: "🌌",
        primary: "3066BE", primaryDark: "090C9B", accent: "60A5FA", warning: "FBBF24", error: "F87171",
        income: "60A5FA", expense: "F87171", business: "090C9B", personal: "B4C5E4",
        background: "F8FAFC", cardBackground: "FFFFFF", textPrimary: "1E293B", textSecondary: "64748B"
    )

    public static let sunsetAmber = FLOColorScheme(
        id: "sunset", name: "Sunset Amber", description: "Warm sunset tones inspiring optimism and positive momentum", emoji: "🌅",
        primary: "F97316", primaryDark: "EA580C", accent: "FBBF24", warning: "F59E0B", error: "DC2626",
        income: "FBBF24", expense: "DC2626", business: "F97316", personal: "FB923C",
        background: "FFFBF5", cardBackground: "FFFFFF", textPrimary: "1C1917", textSecondary: "57534E"
    )

    public static let modernMinimalist = FLOColorScheme(
        id: "minimal", name: "Modern Minimal", description: "Clean, sophisticated neutrals with strategic pops of color", emoji: "⚡",
        primary: "404040", primaryDark: "262626", accent: "10B981", warning: "F59E0B", error: "EF4444",
        income: "10B981", expense: "EF4444", business: "404040", personal: "737373",
        background: "FAFAFA", cardBackground: "FFFFFF", textPrimary: "171717", textSecondary: "737373"
    )

    /// All available schemes
    public static let allSchemes: [FLOColorScheme] = [
        .originalTeal, .natureGrowth, .warmProsperity,
        .oceanBlue, .sunsetAmber, .modernMinimalist
    ]
}

// MARK: - Color Scheme Manager

/// Manages the currently selected color scheme and provides Color accessors.
/// Singleton — access via `ColorSchemeManager.shared` or `@Environment(\.colorSchemeManager)`.
@Observable
public class ColorSchemeManager: @unchecked Sendable {
    public static let shared = ColorSchemeManager()

    public private(set) var currentScheme: FLOColorScheme {
        didSet { saveCurrentScheme() }
    }

    private init() {
        if let savedID = UserDefaults.standard.string(forKey: "selectedColorScheme"),
           let scheme = FLOColorScheme.allSchemes.first(where: { $0.id == savedID }) {
            currentScheme = scheme
        } else {
            currentScheme = .originalTeal
        }
    }

    public func selectScheme(_ scheme: FLOColorScheme) {
        currentScheme = scheme
    }

    private func saveCurrentScheme() {
        UserDefaults.standard.set(currentScheme.id, forKey: "selectedColorScheme")
    }

    // Convenience Color accessors
    public var primary: Color { Color(hex: currentScheme.primary) }
    public var primaryDark: Color { Color(hex: currentScheme.primaryDark) }
    public var accent: Color { Color(hex: currentScheme.accent) }
    public var warning: Color { Color(hex: currentScheme.warning) }
    public var error: Color { Color(hex: currentScheme.error) }
    public var income: Color { Color(hex: currentScheme.income) }
    public var expense: Color { Color(hex: currentScheme.expense) }
    public var business: Color { Color(hex: currentScheme.business) }
    public var personal: Color { Color(hex: currentScheme.personal) }
}

// MARK: - Environment Key

public struct ColorSchemeManagerKey: EnvironmentKey {
    public static let defaultValue = ColorSchemeManager.shared
}

extension EnvironmentValues {
    public var colorSchemeManager: ColorSchemeManager {
        get { self[ColorSchemeManagerKey.self] }
        set { self[ColorSchemeManagerKey.self] = newValue }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Initialize a Color from a hex string (6 or 8 characters, with or without #).
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard hex.count == 6 || hex.count == 8,
              Scanner(string: hex).scanHexInt64(&int) else {
            self = .gray
            return
        }

        let r = Double((int >> (hex.count == 8 ? 24 : 16)) & 0xFF) / 255.0
        let g = Double((int >> (hex.count == 8 ? 16 : 8))  & 0xFF) / 255.0
        let b = Double((int >> (hex.count == 8 ? 8  : 0))  & 0xFF) / 255.0
        let a = hex.count == 8 ? Double(int & 0xFF) / 255.0 : 1.0

        self.init(red: r, green: g, blue: b, opacity: a)
    }

    // NOTE: init(flowHex:) and Color.flow() live in the main app's Color+Extensions.swift
    // to avoid ambiguity with Widget/Clip targets that share model files.
    // Use Color(hex:) from this package for new code.
}

// MARK: - Dynamic Brand Color Accessors

extension Color {
    /// Dynamic brand primary — driven by selected color scheme
    public static var brandPrimary: Color {
        ColorSchemeManager.shared.primary
    }

    public static var brandPrimaryDark: Color {
        ColorSchemeManager.shared.primaryDark
    }

    public static var brandAccent: Color {
        ColorSchemeManager.shared.accent
    }

    public static var brandWarning: Color {
        ColorSchemeManager.shared.warning
    }

    public static var brandError: Color {
        ColorSchemeManager.shared.error
    }

    // Semantic
    public static var incomeGreen: Color {
        ColorSchemeManager.shared.income
    }

    public static var expenseRed: Color {
        ColorSchemeManager.shared.expense
    }

    public static var businessColor: Color {
        ColorSchemeManager.shared.business
    }

    public static var personalColor: Color {
        ColorSchemeManager.shared.personal
    }

    #if canImport(UIKit)
    /// WCAG AA compliant teal for text on both light and dark backgrounds.
    /// Light: #0D7377 (5.2:1 on white), Dark: #4FDDD0 (8.5:1 on dark bg)
    public static let brandPrimaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.31, green: 0.87, blue: 0.82, alpha: 1.0)
            : UIColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1.0)
    })
    #else
    /// macOS: teal text color (adapts via NSAppearance)
    public static let brandPrimaryText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.31, green: 0.87, blue: 0.82, alpha: 1.0)
            : NSColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1.0)
    })
    #endif
}

// MARK: - Color Utilities

extension Color {
    /// Initialize from RGB 0-255 values
    public init(r: Int, g: Int, b: Int, opacity: Double = 1.0) {
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: opacity)
    }

    #if canImport(UIKit)
    /// Lighten color by percentage (0.0-1.0)
    public func lighter(by amount: Double = 0.2) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: min(b * CGFloat(1 + amount), 1), alpha: a))
    }

    /// Darken color by percentage (0.0-1.0)
    public func darker(by amount: Double = 0.2) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: max(b * CGFloat(1 - amount), 0), alpha: a))
    }
    #endif
}
