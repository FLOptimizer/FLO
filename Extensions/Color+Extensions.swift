//  Color+Extensions.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.2 - Added accessible text color for WCAG AA compliance
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v3.2:
//  - Added brandPrimaryText for WCAG AA 4.5:1 contrast ratio compliance
//  - Use for teal text on white/light backgrounds
//

import SwiftUI

extension Color {
    
    // MARK: - Accessible Text Colors (WCAG AA Compliant)
    
    /// Darker teal for text that meets WCAG AA 4.5:1 contrast ratio on white backgrounds
    /// Use this instead of brandPrimary when coloring text
    static let brandPrimaryText = Color(flowHex: "0D7377")
    
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
    
    // MARK: - Dynamic UI Colors (FLO-prefixed to avoid conflicts)
    
    static var floBackground: Color {
        ColorSchemeManager.shared.background
    }
    
    static var floCardBackground: Color {
        ColorSchemeManager.shared.cardBackground
    }
    
    static var floTextPrimary: Color {
        ColorSchemeManager.shared.textPrimary
    }
    
    static var floTextSecondary: Color {
        ColorSchemeManager.shared.textSecondary
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
    
    func lighter(by amount: Double = 0.2) -> Color {
        UIColor(self).lighter(by: amount).color
    }
    
    func darker(by amount: Double = 0.2) -> Color {
        UIColor(self).darker(by: amount).color
    }
}

// MARK: - UIColor helpers for real HSB adjustments

private extension UIColor {
    func lighter(by percentage: Double) -> UIColor { adjust(by: abs(percentage)) }
    func darker(by percentage: Double) -> UIColor { adjust(by: -abs(percentage)) }
    
    func adjust(by percentage: Double) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h,
                       saturation: s,
                       brightness: min(max(b * CGFloat(1 + percentage), 0), 1),
                       alpha: a)
    }
    
    var color: Color { Color(self) }
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
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
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
