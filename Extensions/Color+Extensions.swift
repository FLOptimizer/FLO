//  Color+Extensions.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 — Build 10 dark mode canvas tokens and semantic colors
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.0 (Build 10):
//  - Added adaptive canvas/surface tokens for premium dark mode
//  - canvas: #07070D dark / systemBackground light
//  - surface: #0F0F18 dark / secondarySystemGroupedBackground light
//  - cardGlass: white 4% dark / white 60% light
//  - cardBorder: white 8% dark / black 6% light
//  - semanticGlow: brand teal glow in dark mode, clear in light
//
//  CHANGES v3.4:
//  - Removed floBackground, floCardBackground, floTextPrimary, floTextSecondary
//  - Use SwiftUI semantic colors (.primary, .secondary, Color(.systemBackground)) instead
//
//  CHANGES v3.3:
//  - brandPrimaryText now uses dynamic UIColor adapting to light/dark mode
//

import SwiftUI
#if canImport(UIKit)
import UIKit

/// Cross-platform SwiftUI Image initializer from platform image type
extension SwiftUI.Image {
    init(platformImage: UIImage) {
        self.init(uiImage: platformImage)
    }
}
#else
import AppKit

/// Cross-platform image typealias so UIImage references compile on macOS
typealias UIImage = NSImage

extension NSImage {
    /// Compatibility shim: NSImage equivalent of UIImage.jpegData(compressionQuality:)
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }

    /// Compatibility shim: NSImage equivalent of UIImage.cgImage
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

/// Cross-platform SwiftUI Image initializer from platform image type
extension SwiftUI.Image {
    init(platformImage: NSImage) {
        self.init(nsImage: platformImage)
    }
}
#endif

extension Color {
    
    // MARK: - Accessible Text Colors (WCAG AA Compliant)
    
    /// Dynamic teal for text that meets WCAG AA 4.5:1 contrast ratio in both light and dark modes
    /// Light mode: #0D7377 (dark teal) on white → 5.2:1 contrast
    /// Dark mode:  #4FDDD0 (light teal) on #1C1C1E → 8.5:1 contrast
    /// Use this instead of brandPrimary when coloring text
    #if canImport(UIKit)
    static let brandPrimaryText = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.31, green: 0.87, blue: 0.82, alpha: 1.0)  // #4FDDD0
            : UIColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1.0)  // #0D7377
    })
    #else
    static let brandPrimaryText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.31, green: 0.87, blue: 0.82, alpha: 1.0)
            : NSColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1.0)
    })
    #endif
    
    // MARK: - Dynamic Brand Colors (from selected scheme)
    
    static var brandPrimary: Color {
        ColorSchemeManager.shared.primary
    }
    
    static var brandPrimaryDark: Color {
        ColorSchemeManager.shared.primaryDark
    }
    
    static var brandAccent: Color {
        ColorSchemeManager.shared.accent
    }
    
    static var brandWarning: Color {
        ColorSchemeManager.shared.warning
    }
    
    static var brandError: Color {
        ColorSchemeManager.shared.error
    }
    
    // MARK: - Dynamic Semantic Colors
    
    static var incomeGreen: Color {
        ColorSchemeManager.shared.income
    }
    
    static var expenseRed: Color {
        ColorSchemeManager.shared.expense
    }
    
    static var businessColor: Color {
        ColorSchemeManager.shared.business
    }
    
    static var personalColor: Color {
        ColorSchemeManager.shared.personal
    }
    
    // MARK: - Canvas & Surface Tokens (Build 10 Dark Mode)

    #if canImport(UIKit)
    /// Premium dark canvas background — deep navy-black in dark mode, system white in light
    static let floCanvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.027, green: 0.027, blue: 0.051, alpha: 1.0)  // #07070D
            : .systemBackground
    })

    /// Elevated surface — sidebar/card background. Slightly lighter than canvas in dark mode
    static let floSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.059, blue: 0.094, alpha: 1.0)  // #0F0F18
            : .secondarySystemGroupedBackground
    })

    /// Glass card fill — translucent overlay for card backgrounds
    static let floCardGlass = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.04)
            : UIColor.white.withAlphaComponent(0.60)
    })

    /// Glass card border — subtle edge definition
    static let floCardBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.06)
    })

    /// Semantic glow color — brand teal for dark mode ambient glow, clear in light mode
    static let floSemanticGlow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 0.15)  // teal 15%
            : UIColor.clear
    })
    #else
    /// Premium dark canvas background — adapts via NSAppearance on macOS
    static let floCanvas = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.027, green: 0.027, blue: 0.051, alpha: 1.0)
            : .windowBackgroundColor
    })

    static let floSurface = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.059, green: 0.059, blue: 0.094, alpha: 1.0)
            : .controlBackgroundColor
    })

    static let floCardGlass = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.04)
            : NSColor.white.withAlphaComponent(0.60)
    })

    static let floCardBorder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white.withAlphaComponent(0.08)
            : NSColor.black.withAlphaComponent(0.06)
    })

    static let floSemanticGlow = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 0.15)
            : NSColor.clear
    })
    #endif

    // MARK: - Cross-Platform System Colors

    /// Cross-platform systemBackground equivalent
    static var floSystemBackground: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Cross-platform systemGroupedBackground equivalent
    static var floSystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(.systemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Cross-platform secondarySystemGroupedBackground equivalent
    static var floSecondarySystemGroupedBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Cross-platform secondarySystemBackground equivalent
    static var floSecondarySystemBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Cross-platform tertiarySystemBackground equivalent
    static var floTertiarySystemBackground: Color {
        #if canImport(UIKit)
        Color(.tertiarySystemBackground)
        #else
        Color(nsColor: .underPageBackgroundColor)
        #endif
    }

    /// Card/section background that matches Form .grouped section row backgrounds.
    /// On macOS dark: matches the elevated row fill used by grouped Form sections.
    /// On iOS: uses secondarySystemGroupedBackground (standard grouped row fill).
    static var floSystemGroupedSectionBackground: Color {
        #if canImport(UIKit)
        Color(.secondarySystemGroupedBackground)
        #else
        // macOS grouped Form section rows use an elevated surface
        // that sits between windowBackgroundColor and controlBackgroundColor
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 0.11, alpha: 1.0)  // Matches grouped form row in dark mode
                : NSColor.controlBackgroundColor
        })
        #endif
    }

    // MARK: - Legacy Brand Colors (for backward compatibility)
    // These are now deprecated in favor of dynamic colors above
    
    @available(*, deprecated, message: "Use Color.brandPrimary instead")
    static let brandTeal       = Color(flowHex: "14B8A6")      // #14B8A6
    
    @available(*, deprecated, message: "Use Color.brandPrimaryDark instead")
    static let brandTealDark   = Color(flowHex: "0D9488")      // #0D9488
    
    @available(*, deprecated, message: "Use Color.brandAccent instead")
    static let brandSuccess    = Color(flowHex: "10B981")      // #10B981
    
    // MARK: - Hex Initializer (no conflict with Apple's iOS 17+ init)
    
    init(flowHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard hex.count == 6 || hex.count == 8,
              Scanner(string: hex).scanHexInt64(&int) else {
            print("Invalid hex: '\(hex)' → falling back to .gray")
            self = .gray
            return
        }
        
        let r = Double((int >> (hex.count == 8 ? 24 : 16)) & 0xFF) / 255.0
        let g = Double((int >> (hex.count == 8 ? 16 : 8))  & 0xFF) / 255.0
        let b = Double((int >> (hex.count == 8 ? 8  : 0))  & 0xFF) / 255.0
        let a = hex.count == 8 ? Double(int & 0xFF) / 255.0 : 1.0
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
    
    static func flow(_ hex: String) -> Color {
        Color(flowHex: hex)
    }
    
    // MARK: - RGB (0-255) convenience
    
    init(r: Int, g: Int, b: Int, opacity: Double = 1.0) {
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: opacity)
    }
    
    // MARK: - True Lighten / Darken

    #if canImport(UIKit)
    func lighter(by amount: Double = 0.2) -> Color {
        UIColor(self).floAdjust(by: abs(amount)).floColor
    }

    func darker(by amount: Double = 0.2) -> Color {
        UIColor(self).floAdjust(by: -abs(amount)).floColor
    }
    #else
    func lighter(by amount: Double = 0.2) -> Color {
        NSColor(self).floAdjust(by: abs(amount)).floColor
    }

    func darker(by amount: Double = 0.2) -> Color {
        NSColor(self).floAdjust(by: -abs(amount)).floColor
    }
    #endif
}

// MARK: - Platform Color helpers for HSB adjustments

#if canImport(UIKit)
private extension UIColor {
    func floAdjust(by percentage: Double) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h,
                       saturation: s,
                       brightness: min(max(b * CGFloat(1 + percentage), 0), 1),
                       alpha: a)
    }
    var floColor: Color { Color(self) }
}
#else
private extension NSColor {
    func floAdjust(by percentage: Double) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h,
                       saturation: s,
                       brightness: min(max(b * CGFloat(1 + percentage), 0), 1),
                       alpha: a)
    }
    var floColor: Color { Color(nsColor: self) }
}
#endif

// MARK: - Preview (fully working with all schemes)

#Preview("FLO Color Schemes") {
    ScrollView {
        VStack(alignment: .leading, spacing: 32) {
            Text("FLO Color Schemes")
                .font(.largeTitle).bold()
                .padding(.bottom, 8)
            
            ForEach(FLOColorScheme.allSchemes) { scheme in
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(scheme.emoji)
                            .font(.title)
                        Text(scheme.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text(scheme.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        swatch(Color.flow(scheme.primary), name: "Primary")
                        swatch(Color.flow(scheme.primaryDark), name: "Primary Dark")
                        swatch(Color.flow(scheme.accent), name: "Accent")
                        swatch(Color.flow(scheme.income), name: "Income")
                        swatch(Color.flow(scheme.expense), name: "Expense")
                        swatch(Color.flow(scheme.business), name: "Business")
                    }
                }
                .padding()
                .background(Color.flow(scheme.background))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                
                Divider()
                    .padding(.vertical, 8)
            }
        }
        .padding()
    }
}

// MARK: - Preview Helpers

@ViewBuilder
private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
        VStack(spacing: 12) { content() }
    }
}

@ViewBuilder
private func swatch(_ color: Color, name: String, hex: String = "") -> some View {
    VStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(height: 60)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.15), lineWidth: 1))
            .shadow(radius: 1)
        
        VStack(spacing: 2) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            if !hex.isEmpty {
                Text(hex)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }
}
