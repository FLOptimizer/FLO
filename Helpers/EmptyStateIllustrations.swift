//  EmptyStateIllustrations.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: InvoicesIllustration dollar sign missing lineLimit + minimumScaleFactor
//  ✅ FIXED: AccountsIllustration dollar sign missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview labels missing lineLimit + minimumScaleFactor
//  ℹ️  NOTE: Shape dimensions intentionally NOT changed (decorative illustrations)
//
//  CHANGES v1.1:
//  - Added AccountsIllustration
//
//  Pure SwiftUI vector illustrations for empty states.
//  Uses brand colors from ColorSchemeSystem for automatic dark mode.
//  Respects reduce motion via @Environment(\.accessibilityReduceMotion).
//
//  Illustrations:
//  ✅ DashboardIllustration - Rising bar chart with trend line
//  ✅ TransactionsIllustration - Wallet with floating receipt
//  ✅ InvoicesIllustration - Document with dollar badge
//  ✅ MileageIllustration - Road with car and mile markers
//  ✅ BudgetsIllustration - Envelope with coins
//  ✅ ClientsIllustration - Overlapping contact cards
//

import SwiftUI

// MARK: - Shared Constants

private enum IllustrationConstants {
    static let height: CGFloat = 140
    static let width: CGFloat = 200
}

// MARK: - 1. Dashboard Illustration
/// Rising bar chart with upward trend line and subtle glow

struct DashboardIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    private let barHeights: [CGFloat] = [0.3, 0.45, 0.35, 0.55, 0.5, 0.7, 0.85]
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.15),
                            Color.brandPrimary.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 100)
                .offset(y: 10)
            
            // Bar chart
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(barHeights.enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandPrimary.opacity(0.4 + height * 0.6),
                                    Color.brandPrimary.opacity(0.2 + height * 0.3)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: 18,
                            height: appeared ? height * 90 : (reduceMotion ? height * 90 : 4)
                        )
                        .animation(
                            reduceMotion ? .none :
                                .spring(response: 0.6, dampingFraction: 0.7)
                                .delay(Double(index) * 0.08),
                            value: appeared
                        )
                }
            }
            .frame(height: 95, alignment: .bottom)
            
            // Trend line
            TrendLineShape()
                .trim(from: 0, to: appeared ? 1 : (reduceMotion ? 1 : 0))
                .stroke(
                    Color.brandAccent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 160, height: 70)
                .offset(y: -10)
                .animation(
                    reduceMotion ? .none :
                        .easeOut(duration: 0.8).delay(0.5),
                    value: appeared
                )
            
            // Trend dot
            Circle()
                .fill(Color.brandAccent)
                .frame(width: 8, height: 8)
                .shadow(color: Color.brandAccent.opacity(0.5), radius: 4)
                .offset(x: 72, y: -42)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.4, dampingFraction: 0.6).delay(1.2),
                    value: appeared
                )
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Custom shape for the upward trend line
private struct TrendLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let points: [(CGFloat, CGFloat)] = [
            (0.0, 0.8), (0.15, 0.65), (0.28, 0.72),
            (0.42, 0.5), (0.56, 0.55), (0.72, 0.3),
            (0.88, 0.15), (1.0, 0.05)
        ]
        
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0 * w, y: first.1 * h))
        
        for i in 1..<points.count {
            let current = points[i]
            let previous = points[i - 1]
            let midX = (previous.0 + current.0) / 2 * w
            path.addQuadCurve(
                to: CGPoint(x: current.0 * w, y: current.1 * h),
                control: CGPoint(x: midX, y: previous.1 * h)
            )
        }
        
        return path
    }
}

// MARK: - 2. Transactions Illustration
/// Wallet shape with a floating receipt and scattered coins

struct TransactionsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 170, height: 90)
                .offset(y: 15)
            
            // Wallet body
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.25),
                            Color.brandPrimary.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.brandPrimary.opacity(0.3), lineWidth: 1.5)
                )
                .offset(y: 10)
            
            // Wallet flap
            WalletFlapShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandPrimaryDark.opacity(0.35),
                            Color.brandPrimary.opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 104, height: 30)
                .offset(y: -17)
            
            // Card peeking out
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandAccent.opacity(0.5),
                            Color.brandAccent.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 70, height: 44)
                .rotationEffect(.degrees(-3))
                .offset(x: 2, y: -2)
            
            // Floating receipt
            ReceiptShape()
                .fill(colorScheme == .dark
                      ? Color.white.opacity(0.12)
                      : Color.white.opacity(0.9))
                .frame(width: 44, height: 58)
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                .overlay(
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.brandPrimary.opacity(0.2))
                                .frame(width: 28, height: 3)
                        }
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.brandAccent.opacity(0.4))
                            .frame(width: 20, height: 3)
                    }
                    .offset(y: -2)
                )
                .offset(
                    x: 50,
                    y: appeared ? -30 : (reduceMotion ? -30 : -10)
                )
                .rotationEffect(.degrees(appeared ? 8 : (reduceMotion ? 8 : 0)))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.7, dampingFraction: 0.65).delay(0.3),
                    value: appeared
                )
            
            // Scattered coins
            CoinDot(size: 12, opacity: 0.6)
                .offset(x: -55, y: -25)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
                .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.6).delay(0.5), value: appeared)
            
            CoinDot(size: 9, opacity: 0.45)
                .offset(x: -65, y: 5)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
                .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.6).delay(0.65), value: appeared)
            
            CoinDot(size: 10, opacity: 0.5)
                .offset(x: 65, y: 30)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
                .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.6).delay(0.55), value: appeared)
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Small coin circle with brand gradient
private struct CoinDot: View {
    let size: CGFloat
    let opacity: Double
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.brandAccent.opacity(opacity),
                        Color.brandPrimary.opacity(opacity * 0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .shadow(color: Color.brandAccent.opacity(0.3), radius: 3)
    }
}

/// Wallet flap curved shape
private struct WalletFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.4))
        path.addQuadCurve(
            to: CGPoint(x: w, y: h * 0.4),
            control: CGPoint(x: w * 0.5, y: -h * 0.2)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        
        return path
    }
}

/// Receipt with torn bottom edge
private struct ReceiptShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let zigCount = 6
        let zigHeight: CGFloat = 4
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - zigHeight))
        
        // Zigzag bottom
        let segmentWidth = w / CGFloat(zigCount)
        for i in 0..<zigCount {
            let x1 = w - CGFloat(i) * segmentWidth - segmentWidth * 0.5
            let x2 = w - CGFloat(i + 1) * segmentWidth
            let y1 = (i % 2 == 0) ? h : h - zigHeight
            let y2 = (i % 2 == 0) ? h - zigHeight : h
            path.addLine(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - 3. Invoices Illustration
/// Document with dollar badge and status indicator

struct InvoicesIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPrimary.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 170, height: 90)
                .offset(y: 15)
            
            // Back document (shadow)
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(0.06)
                      : Color.gray.opacity(0.2))
                .frame(width: 80, height: 100)
                .rotationEffect(.degrees(6))
                .offset(x: 5, y: 5)
            
            // Main document
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark
                      ? Color.white.opacity(0.1)
                      : Color.white)
                .frame(width: 80, height: 100)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                .overlay(
                    VStack(alignment: .leading, spacing: 6) {
                        // Header bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.brandPrimary.opacity(0.3))
                            .frame(width: 50, height: 5)
                        
                        // Lines
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary.opacity(0.1))
                                .frame(width: CGFloat(55 - i * 8), height: 3)
                        }
                        
                        Spacer()
                        
                        // Amount line
                        HStack(spacing: 4) {
                            Spacer()
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.brandAccent.opacity(0.4))
                                .frame(width: 35, height: 5)
                        }
                    }
                    .padding(12)
                )
            
            // Dollar badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.brandPrimary.opacity(0.4), radius: 6, y: 2)
                
                Text("$")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
            }
            .offset(x: 38, y: -38)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.5, dampingFraction: 0.6).delay(0.4),
                value: appeared
            )
            
            // Floating checkmark
            ZStack {
                Circle()
                    .fill(Color.incomeGreen.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.incomeGreen)
            }
            .offset(x: -48, y: 30)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.5, dampingFraction: 0.6).delay(0.7),
                value: appeared
            )
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

// MARK: - 4. Mileage Illustration
/// Road perspective with car silhouette and mile markers

struct MileageIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPrimary.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 90
                    )
                )
                .frame(width: 190, height: 100)
                .offset(y: 10)
            
            // Road surface
            RoadShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.primary.opacity(0.08),
                            Color.primary.opacity(0.04)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 180, height: 100)
                .offset(y: 15)
            
            // Dashed center line
            RoadCenterLine()
                .stroke(
                    Color.brandPrimary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .frame(width: 4, height: 80)
                .offset(y: -5)
                .opacity(appeared ? 1 : (reduceMotion ? 1 : 0))
                .animation(
                    reduceMotion ? .none : .easeIn(duration: 0.5).delay(0.2),
                    value: appeared
                )
            
            // Mile markers
            ForEach(0..<3, id: \.self) { i in
                MileMarker()
                    .offset(
                        x: -70 + CGFloat(i) * 60,
                        y: 30 - CGFloat(i) * 15
                    )
                    .scaleEffect(0.7 + CGFloat(i) * 0.15)
                    .opacity(appeared ? (0.4 + Double(i) * 0.2) : (reduceMotion ? (0.4 + Double(i) * 0.2) : 0))
                    .animation(
                        reduceMotion ? .none :
                            .easeOut(duration: 0.4).delay(0.3 + Double(i) * 0.15),
                        value: appeared
                    )
            }
            
            // Car silhouette
            CarShape()
                .fill(
                    LinearGradient(
                        colors: [Color.brandPrimary, Color.brandPrimaryDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 48, height: 22)
                .shadow(color: Color.brandPrimary.opacity(0.3), radius: 6, y: 3)
                .offset(
                    x: appeared ? 0 : (reduceMotion ? 0 : -40),
                    y: 15
                )
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.8, dampingFraction: 0.7).delay(0.2),
                    value: appeared
                )
            
            // Speed lines
            ForEach(0..<2, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: appeared ? 20 : (reduceMotion ? 20 : 0), height: 2)
                    .offset(x: -40, y: CGFloat(12 + i * 8))
                    .animation(
                        reduceMotion ? .none :
                            .easeOut(duration: 0.3).delay(0.9 + Double(i) * 0.1),
                        value: appeared
                    )
            }
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Perspective road shape (trapezoid)
private struct RoadShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.25, y: 0))
        path.addLine(to: CGPoint(x: w * 0.75, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()
        
        return path
    }
}

/// Vertical center line for road
private struct RoadCenterLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        return path
    }
}

/// Simple mile marker post
private struct MileMarker: View {
    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.brandPrimary.opacity(0.3))
                .frame(width: 14, height: 10)
            Rectangle()
                .fill(Color.primary.opacity(0.15))
                .frame(width: 3, height: 14)
        }
    }
}

/// Simple car body silhouette
private struct CarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Body
        path.move(to: CGPoint(x: w * 0.05, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.2))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.2),
            control: CGPoint(x: w * 0.5, y: 0)
        )
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.65))
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.65))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.95, y: h * 0.9),
            control: CGPoint(x: w, y: h * 0.75)
        )
        path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.9))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.05, y: h * 0.65),
            control: CGPoint(x: 0, y: h * 0.75)
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 5. Budgets Illustration
/// Envelope with coin and pie chart segment

struct BudgetsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPrimary.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 170, height: 90)
                .offset(y: 15)
            
            // Envelope body
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandPrimary.opacity(0.2),
                            Color.brandPrimary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 110, height: 72)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1.5)
                )
                .offset(y: 10)
            
            // Envelope flap (triangle)
            EnvelopeFlapShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.brandPrimaryDark.opacity(0.3),
                            Color.brandPrimary.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 110, height: 40)
                .offset(y: -16)
            
            // Mini pie chart
            ZStack {
                Circle()
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.white.opacity(0.9))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                
                // Pie segments
                PieSegment(startAngle: .degrees(-90), endAngle: .degrees(60))
                    .fill(Color.brandPrimary.opacity(0.6))
                    .frame(width: 32, height: 32)
                
                PieSegment(startAngle: .degrees(60), endAngle: .degrees(180))
                    .fill(Color.brandAccent.opacity(0.5))
                    .frame(width: 32, height: 32)
                
                PieSegment(startAngle: .degrees(180), endAngle: .degrees(270))
                    .fill(Color.brandPrimary.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                // Center hole
                Circle()
                    .fill(colorScheme == .dark
                          ? Color.white.opacity(0.08)
                          : Color.white.opacity(0.9))
                    .frame(width: 14, height: 14)
            }
            .offset(x: 48, y: -28)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.3))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.5, dampingFraction: 0.65).delay(0.35),
                value: appeared
            )
            
            // Floating coins
            CoinStack(count: 3)
                .offset(x: -52, y: 15)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.5))
                .opacity(appeared ? 1 : (reduceMotion ? 1 : 0))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.5),
                    value: appeared
                )
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Envelope flap (downward-pointing triangle)
private struct EnvelopeFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Pie chart segment
private struct PieSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

/// Stack of coin discs
private struct CoinStack: View {
    let count: Int
    
    var body: some View {
        VStack(spacing: -3) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandAccent.opacity(0.5 - Double(i) * 0.1),
                                Color.brandPrimary.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 22, height: 8)
                    .overlay(
                        Capsule()
                            .stroke(Color.brandAccent.opacity(0.3), lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - 6. Clients Illustration
/// Overlapping contact cards with avatar placeholders

struct ClientsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPrimary.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 170, height: 90)
                .offset(y: 15)
            
            // Back card
            ContactCard(lineWidths: [35, 28], avatarOpacity: 0.15)
                .rotationEffect(.degrees(-8))
                .offset(x: -18, y: 8)
                .opacity(appeared ? 0.6 : (reduceMotion ? 0.6 : 0))
                .animation(
                    reduceMotion ? .none : .easeOut(duration: 0.4).delay(0.1),
                    value: appeared
                )
            
            // Middle card
            ContactCard(lineWidths: [40, 30], avatarOpacity: 0.25)
                .rotationEffect(.degrees(3))
                .offset(x: 8, y: -2)
                .opacity(appeared ? 0.8 : (reduceMotion ? 0.8 : 0))
                .animation(
                    reduceMotion ? .none : .easeOut(duration: 0.4).delay(0.25),
                    value: appeared
                )
            
            // Front card
            ContactCard(lineWidths: [38, 25], avatarOpacity: 0.4)
                .offset(x: -5, y: -12)
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.9))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.5, dampingFraction: 0.7).delay(0.4),
                    value: appeared
                )
            
            // Plus badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimaryDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.brandPrimary.opacity(0.4), radius: 4, y: 2)
                
                Image(systemName: "plus")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .offset(x: 50, y: -35)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.4, dampingFraction: 0.6).delay(0.7),
                value: appeared
            )
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Single contact card with avatar circle and text lines
private struct ContactCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let lineWidths: [CGFloat]
    let avatarOpacity: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(colorScheme == .dark
                  ? Color.white.opacity(0.12)
                  : Color.white)
            .frame(width: 90, height: 65)
            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.brandPrimary.opacity(colorScheme == .dark ? 0.25 : 0.1), lineWidth: 1)
            )
            .overlay(
                HStack(spacing: 8) {
                    // Avatar circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandPrimary.opacity(max(avatarOpacity, 0.25)),
                                    Color.brandPrimary.opacity(max(avatarOpacity * 0.6, 0.15))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.brandPrimary.opacity(max(avatarOpacity * 2, 0.5)))
                        )

                    // Text lines
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, width in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.12))
                                .frame(width: width, height: 4)
                        }
                    }
                }
                .padding(.horizontal, 10)
            )
    }
}

// MARK: - 7. Accounts Illustration
/// Bank building with floating account cards and balance indicator

struct AccountsIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            // Background glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.brandPrimary.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 5,
                        endRadius: 80
                    )
                )
                .frame(width: 170, height: 90)
                .offset(y: 15)
            
            // Bank building base
            VStack(spacing: 0) {
                // Pediment (triangle roof)
                BankPedimentShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.brandPrimaryDark.opacity(0.35),
                                Color.brandPrimary.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 90, height: 22)
                
                // Columns area
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.brandPrimary.opacity(0.25),
                                        Color.brandPrimary.opacity(0.15)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 8, height: 40)
                    }
                }
                .padding(.horizontal, 12)
                .frame(width: 90)
                
                // Foundation
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: 96, height: 8)
            }
            .offset(y: 5)
            
            // Floating account card (left)
            AccountCardShape(width: 52, height: 34, hasChip: true)
                .offset(x: -58, y: -15)
                .rotationEffect(.degrees(-6))
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.5))
                .opacity(appeared ? 1 : (reduceMotion ? 1 : 0))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.6, dampingFraction: 0.65).delay(0.3),
                    value: appeared
                )
            
            // Floating account card (right)
            AccountCardShape(width: 52, height: 34, hasChip: false)
                .offset(x: 58, y: -8)
                .rotationEffect(.degrees(5))
                .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0.5))
                .opacity(appeared ? 1 : (reduceMotion ? 1 : 0))
                .animation(
                    reduceMotion ? .none :
                        .spring(response: 0.6, dampingFraction: 0.65).delay(0.45),
                    value: appeared
                )
            
            // Balance badge
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.brandPrimary, Color.brandPrimaryDark],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 44, height: 22)
                    .shadow(color: Color.brandPrimary.opacity(0.4), radius: 4, y: 2)
                
                HStack(spacing: 2) {
                    Text("$")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    // Balance bars
                    HStack(spacing: 1.5) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(Color.white.opacity(0.7))
                                .frame(width: 3, height: CGFloat(4 + i * 3))
                        }
                    }
                }
                .foregroundStyle(.white)
            }
            .offset(x: 0, y: -42)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.4, dampingFraction: 0.6).delay(0.6),
                value: appeared
            )
            
            // Shield checkmark (security)
            ZStack {
                Circle()
                    .fill(Color.incomeGreen.opacity(0.2))
                    .frame(width: 22, height: 22)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.incomeGreen)
            }
            .offset(x: 52, y: 35)
            .scaleEffect(appeared ? 1 : (reduceMotion ? 1 : 0))
            .animation(
                reduceMotion ? .none :
                    .spring(response: 0.5, dampingFraction: 0.6).delay(0.75),
                value: appeared
            )
        }
        .frame(width: IllustrationConstants.width, height: IllustrationConstants.height)
        .accessibilityHidden(true)
        .onAppear { appeared = true }
    }
}

/// Bank pediment (triangle with base)
private struct BankPedimentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        
        return path
    }
}

/// Mini account/credit card
private struct AccountCardShape: View {
    @Environment(\.colorScheme) private var colorScheme
    let width: CGFloat
    let height: CGFloat
    let hasChip: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(colorScheme == .dark
                  ? Color.white.opacity(0.1)
                  : Color.white)
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .overlay(
                VStack(alignment: .leading, spacing: 3) {
                    if hasChip {
                        // EMV chip
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.brandAccent.opacity(0.4))
                            .frame(width: 10, height: 7)
                    } else {
                        // Bank icon
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.2))
                            .frame(width: 10, height: 10)
                    }
                    
                    Spacer()
                    
                    // Card number dots
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.primary.opacity(0.15))
                                .frame(width: 3, height: 3)
                        }
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 12, height: 3)
                    }
                }
                .padding(6)
            )
    }
}

// MARK: - Preview Gallery

#Preview("All Illustrations - Light") {
    ScrollView {
        VStack(spacing: 32) {
            Group {
                Text("Dashboard")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                DashboardIllustration()
                
                Text("Transactions")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                TransactionsIllustration()
                
                Text("Invoices")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                InvoicesIllustration()
            }
            
            Group {
                Text("Mileage")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                MileageIllustration()
                
                Text("Budgets")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                BudgetsIllustration()
                
                Text("Clients")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                ClientsIllustration()
                
                Text("Accounts")
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                AccountsIllustration()
            }
        }
        .padding()
    }
}

#Preview("All Illustrations - Dark") {
    ScrollView {
        VStack(spacing: 32) {
            DashboardIllustration()
            TransactionsIllustration()
            InvoicesIllustration()
            MileageIllustration()
            BudgetsIllustration()
            ClientsIllustration()
            AccountsIllustration()
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
