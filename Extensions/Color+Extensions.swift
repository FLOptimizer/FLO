//  Color+Extensions.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.1 — App-only extensions (brand/canvas/hex/lighter/darker moved to FLODesignSystem)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  This file contains ONLY app-specific Color extensions that are NOT in the
//  FLODesignSystem package: floSemanticGlow, cross-platform system color wrappers,
//  and the cross-platform Image/NSImage compatibility shims.
//

import SwiftUI
import FLODesignSystem
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

    // MARK: - Hex Initializer (kept for Widget/Clip target compatibility)

    /// Initialize from hex string — kept here for Widget/Clip target compatibility.
    /// Static shorthand: `Color.flow("14B8A6")`
    static func flow(_ hex: String) -> Color { Color(flowHex: hex) }

    init(flowHex hex: String) {
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

    // MARK: - Canvas & Surface Bridges (delegating to FLODesignSystem)

    /// Bridge to FLOCanvasColors — keeps existing `Color.floCanvas` API working.
    static var floCanvas: Color { FLOCanvasColors.canvas }
    static var floSurface: Color { FLOCanvasColors.surface }
    static var floCardGlass: Color { FLOCanvasColors.cardGlass }
    static var floCardBorder: Color { FLOCanvasColors.cardBorder }

    // MARK: - Canvas & Surface Tokens (Build 10 Dark Mode)

    #if canImport(UIKit)
    /// Semantic glow color — brand teal for dark mode ambient glow, clear in light mode
    static let floSemanticGlow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.078, green: 0.722, blue: 0.651, alpha: 0.15)  // teal 15%
            : UIColor.clear
    })
    #else
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

}

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
                        swatch(Color(flowHex:scheme.primary), name: "Primary")
                        swatch(Color(flowHex:scheme.primaryDark), name: "Primary Dark")
                        swatch(Color(flowHex:scheme.accent), name: "Accent")
                        swatch(Color(flowHex:scheme.income), name: "Income")
                        swatch(Color(flowHex:scheme.expense), name: "Expense")
                        swatch(Color(flowHex:scheme.business), name: "Business")
                    }
                }
                .padding()
                .background(Color(flowHex:scheme.background))
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
