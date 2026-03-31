//  FLOIconSystem.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Custom branded iconography system
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Custom SwiftUI Path-based icon components that give FLO a distinctive
//  visual identity. Follows the EmptyStateIllustrations.swift pattern:
//  - Custom Shape structs with normalized coordinates
//  - Dark mode adaptation via @Environment(\.colorScheme)
//  - Brand colors from Color.brandPrimary etc.
//  - .accessibilityHidden(true) on all decorative icons
//
//  COMPONENTS:
//  - FLOIcon enum: Catalog of 12 icon types
//  - 12 custom Shape structs for Path-based rendering
//  - FLOBrandedIcon: Wrapper with gradient background + sizing
//  - FLOCardHeader: Standardized dashboard card header component

import SwiftUI

// MARK: - Icon Catalog

/// All custom FLO icon types with their Shape mapping.
enum FLOIcon: String, CaseIterable {
    case dashboard
    case transactions
    case budgets
    case invoices
    case mileage
    case tax
    case receipt
    case accounts
    case clients
    case quickAction
    case moveMoney
    case expense
    case income

    /// Returns the custom Shape for this icon.
    @ViewBuilder
    func shape() -> some View {
        switch self {
        case .dashboard:    FLODashboardIconShape()
        case .transactions: FLOTransactionsIconShape()
        case .budgets:      FLOBudgetsIconShape()
        case .invoices:     FLOInvoicesIconShape()
        case .mileage:      FLOMileageIconShape()
        case .tax:          FLOTaxIconShape()
        case .receipt:      FLOReceiptIconShape()
        case .accounts:     FLOAccountsIconShape()
        case .clients:      FLOClientsIconShape()
        case .quickAction:  FLOQuickActionIconShape()
        case .moveMoney:    FLOMoveMoneyIconShape()
        case .expense:      FLOExpenseIconShape()
        case .income:       FLOIncomeIconShape()
        }
    }
}

// MARK: - Icon Sizing

enum FLOIconSize {
    case small   // 24pt — inline/compact
    case medium  // 32pt — card headers
    case large   // 48pt — quick action buttons

    var dimension: CGFloat {
        switch self {
        case .small:  return 24
        case .medium: return 32
        case .large:  return 48
        }
    }

    /// Scale factor for the inner icon relative to the container.
    var iconScale: CGFloat {
        switch self {
        case .small:  return 0.55
        case .medium: return 0.55
        case .large:  return 0.50
        }
    }
}

// MARK: - Branded Icon Container

/// Wraps a custom FLO icon shape in a branded container with gradient
/// background, subtle ring, and micro shadow. This is the primary component
/// for rendering custom icons throughout the app.
struct FLOBrandedIcon: View {
    let icon: FLOIcon
    var size: FLOIconSize = .medium
    var color: Color = .brandPrimary

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Gradient circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(colorScheme == .dark ? 0.18 : 0.14),
                            color.opacity(colorScheme == .dark ? 0.08 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle inner ring
            Circle()
                .strokeBorder(
                    color.opacity(colorScheme == .dark ? 0.20 : 0.12),
                    lineWidth: 0.5
                )

            // The custom icon shape
            icon.shape()
                .frame(
                    width: size.dimension * size.iconScale,
                    height: size.dimension * size.iconScale
                )
                .foregroundStyle(color)
        }
        .frame(width: size.dimension, height: size.dimension)
        .shadow(
            color: color.opacity(colorScheme == .dark ? 0.12 : 0.08),
            radius: size == .large ? 3 : 2,
            y: 1
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Card Header Component

/// Standardized dashboard card header, replacing the ad-hoc HStack pattern
/// found across all dashboard cards. Provides consistent icon + title layout
/// with an optional trailing view.
struct FLOCardHeader<Trailing: View>: View {
    let icon: FLOIcon
    let title: String
    var iconColor: Color = .brandPrimary
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: FLOIcon,
        title: String,
        iconColor: Color = .brandPrimary,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            FLOBrandedIcon(icon: icon, size: .medium, color: iconColor)

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            trailing()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(title)
    }
}

/// Convenience initializer for headers with no trailing content.
extension FLOCardHeader where Trailing == EmptyView {
    init(
        icon: FLOIcon,
        title: String,
        iconColor: Color = .brandPrimary
    ) {
        self.icon = icon
        self.title = title
        self.iconColor = iconColor
        self.trailing = { EmptyView() }
    }
}

// MARK: - Custom Icon Shapes

// Each shape draws within a normalized rect using Path. Designed to be
// recognizable at 12-24pt inner size (the .iconScale portion of the container).
// All use .fill by default via .foregroundStyle on the parent.

/// Dashboard: Smooth upward trend curve with terminal dot.
/// Represents growth and financial overview.
struct FLODashboardIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Trend line curve
            var line = Path()
            line.move(to: CGPoint(x: w * 0.05, y: h * 0.78))
            line.addQuadCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.45),
                control: CGPoint(x: w * 0.30, y: h * 0.70)
            )
            line.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.12),
                control: CGPoint(x: w * 0.68, y: h * 0.22)
            )

            context.stroke(
                line,
                with: .foreground,
                style: StrokeStyle(lineWidth: w * 0.10, lineCap: .round, lineJoin: .round)
            )

            // Terminal dot at peak
            let dotSize = w * 0.16
            let dotRect = CGRect(
                x: w * 0.88 - dotSize / 2,
                y: h * 0.12 - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(Circle().path(in: dotRect), with: .foreground)

            // Small base line
            var baseLine = Path()
            baseLine.move(to: CGPoint(x: w * 0.05, y: h * 0.92))
            baseLine.addLine(to: CGPoint(x: w * 0.95, y: h * 0.92))
            context.stroke(
                baseLine,
                with: .foreground,
                style: StrokeStyle(lineWidth: w * 0.06, lineCap: .round)
            )
        }
    }
}

/// Transactions: Three ledger lines with diagonal flow arrow.
/// Represents a list of financial entries with movement.
struct FLOTransactionsIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.07

            // Three horizontal ledger lines
            for (i, yFrac) in [0.25, 0.50, 0.75].enumerated() {
                var line = Path()
                let xStart: CGFloat = i == 1 ? 0.25 : 0.12
                line.move(to: CGPoint(x: w * xStart, y: h * yFrac))
                line.addLine(to: CGPoint(x: w * 0.88, y: h * yFrac))
                context.stroke(
                    line,
                    with: .foreground,
                    style: StrokeStyle(lineWidth: lineW, lineCap: .round)
                )
            }

            // Small dots at line starts (bullet points)
            for yFrac in [0.25, 0.50, 0.75] {
                let dotSize = w * 0.10
                let dotRect = CGRect(
                    x: w * 0.04,
                    y: h * yFrac - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                context.fill(Circle().path(in: dotRect), with: .foreground)
            }
        }
    }
}

/// Budgets: Donut chart with exploded segment.
/// Represents budget allocation and tracking.
struct FLOBudgetsIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let center = CGPoint(x: w * 0.5, y: h * 0.5)
            let outerR = min(w, h) * 0.45
            let innerR = outerR * 0.50
            let strokeW = outerR - innerR

            // Segment 1: 0° to 140° (main segment)
            var seg1 = Path()
            seg1.addArc(center: center, radius: outerR - strokeW / 2,
                        startAngle: .degrees(-90), endAngle: .degrees(50),
                        clockwise: false)
            context.stroke(
                seg1, with: .foreground,
                style: StrokeStyle(lineWidth: strokeW, lineCap: .butt)
            )

            // Segment 2: 145° to 240° (medium)
            var seg2 = Path()
            seg2.addArc(center: center, radius: outerR - strokeW / 2,
                        startAngle: .degrees(55), endAngle: .degrees(160),
                        clockwise: false)
            context.stroke(
                seg2, with: .foreground,
                style: StrokeStyle(lineWidth: strokeW, lineCap: .butt)
            )

            // Segment 3: 245° to 355° (exploded — offset outward)
            let explodeAngle = Angle.degrees(235) // midpoint of segment
            let explodeOffset: CGFloat = w * 0.05
            let offsetCenter = CGPoint(
                x: center.x + CGFloat(Foundation.cos(explodeAngle.radians)) * explodeOffset,
                y: center.y + CGFloat(Foundation.sin(explodeAngle.radians)) * explodeOffset
            )
            var seg3 = Path()
            seg3.addArc(center: offsetCenter, radius: outerR - strokeW / 2,
                        startAngle: .degrees(165), endAngle: .degrees(305),
                        clockwise: false)
            context.stroke(
                seg3, with: .foreground,
                style: StrokeStyle(lineWidth: strokeW, lineCap: .butt)
            )
        }
    }
}

/// Invoices: Document with folded corner and text lines.
/// Represents professional invoicing.
struct FLOInvoicesIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.06
            let foldSize = w * 0.22

            // Document outline with folded corner
            var doc = Path()
            doc.move(to: CGPoint(x: w * 0.15, y: h * 0.05))
            doc.addLine(to: CGPoint(x: w * 0.85 - foldSize, y: h * 0.05))
            doc.addLine(to: CGPoint(x: w * 0.85, y: h * 0.05 + foldSize))
            doc.addLine(to: CGPoint(x: w * 0.85, y: h * 0.95))
            doc.addLine(to: CGPoint(x: w * 0.15, y: h * 0.95))
            doc.closeSubpath()

            context.stroke(
                doc, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Corner fold triangle
            var fold = Path()
            fold.move(to: CGPoint(x: w * 0.85 - foldSize, y: h * 0.05))
            fold.addLine(to: CGPoint(x: w * 0.85 - foldSize, y: h * 0.05 + foldSize))
            fold.addLine(to: CGPoint(x: w * 0.85, y: h * 0.05 + foldSize))
            context.stroke(
                fold, with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.7, lineCap: .round, lineJoin: .round)
            )

            // Dollar sign
            let dollarCenter = CGPoint(x: w * 0.50, y: h * 0.52)
            let dollarH = h * 0.28

            // S-curve of dollar sign
            var sCurve = Path()
            sCurve.move(to: CGPoint(x: dollarCenter.x + w * 0.10, y: dollarCenter.y - dollarH * 0.30))
            sCurve.addQuadCurve(
                to: CGPoint(x: dollarCenter.x, y: dollarCenter.y),
                control: CGPoint(x: dollarCenter.x - w * 0.12, y: dollarCenter.y - dollarH * 0.20)
            )
            sCurve.addQuadCurve(
                to: CGPoint(x: dollarCenter.x - w * 0.10, y: dollarCenter.y + dollarH * 0.30),
                control: CGPoint(x: dollarCenter.x + w * 0.12, y: dollarCenter.y + dollarH * 0.20)
            )
            context.stroke(
                sCurve, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Vertical line through dollar sign
            var vLine = Path()
            vLine.move(to: CGPoint(x: dollarCenter.x, y: dollarCenter.y - dollarH * 0.45))
            vLine.addLine(to: CGPoint(x: dollarCenter.x, y: dollarCenter.y + dollarH * 0.45))
            context.stroke(
                vLine, with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.7, lineCap: .round)
            )
        }
    }
}

/// Mileage: Converging road perspective with center line.
/// Represents driving and distance tracking.
struct FLOMileageIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.07

            // Left road edge
            var leftEdge = Path()
            leftEdge.move(to: CGPoint(x: w * 0.05, y: h * 0.95))
            leftEdge.addLine(to: CGPoint(x: w * 0.42, y: h * 0.10))
            context.stroke(
                leftEdge, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Right road edge
            var rightEdge = Path()
            rightEdge.move(to: CGPoint(x: w * 0.95, y: h * 0.95))
            rightEdge.addLine(to: CGPoint(x: w * 0.58, y: h * 0.10))
            context.stroke(
                rightEdge, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Dashed center line
            let dashSegments: [(CGFloat, CGFloat)] = [
                (0.85, 0.70), (0.60, 0.45), (0.35, 0.20)
            ]
            for (startY, endY) in dashSegments {
                var dash = Path()
                let startX = w * 0.50
                let endX = w * 0.50
                dash.move(to: CGPoint(x: startX, y: h * startY))
                dash.addLine(to: CGPoint(x: endX, y: h * endY))
                context.stroke(
                    dash, with: .foreground,
                    style: StrokeStyle(lineWidth: lineW * 0.7, lineCap: .round)
                )
            }

            // Distance marker dot at vanishing point
            let dotSize = w * 0.12
            let dotRect = CGRect(
                x: w * 0.50 - dotSize / 2,
                y: h * 0.05,
                width: dotSize,
                height: dotSize
            )
            context.fill(Circle().path(in: dotRect), with: .foreground)
        }
    }
}

/// Tax: Shield outline with percent symbol.
/// Represents tax protection and compliance.
struct FLOTaxIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.07

            // Shield outline
            var shield = Path()
            shield.move(to: CGPoint(x: w * 0.50, y: h * 0.04))
            shield.addQuadCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.25),
                control: CGPoint(x: w * 0.25, y: h * 0.04)
            )
            shield.addLine(to: CGPoint(x: w * 0.12, y: h * 0.55))
            shield.addQuadCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.96),
                control: CGPoint(x: w * 0.12, y: h * 0.82)
            )
            shield.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.55),
                control: CGPoint(x: w * 0.88, y: h * 0.82)
            )
            shield.addLine(to: CGPoint(x: w * 0.88, y: h * 0.25))
            shield.addQuadCurve(
                to: CGPoint(x: w * 0.50, y: h * 0.04),
                control: CGPoint(x: w * 0.75, y: h * 0.04)
            )

            context.stroke(
                shield, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Percent sign inside shield
            let pCenter = CGPoint(x: w * 0.50, y: h * 0.48)

            // Diagonal line
            var diag = Path()
            diag.move(to: CGPoint(x: pCenter.x - w * 0.12, y: pCenter.y + h * 0.14))
            diag.addLine(to: CGPoint(x: pCenter.x + w * 0.12, y: pCenter.y - h * 0.14))
            context.stroke(
                diag, with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.8, lineCap: .round)
            )

            // Top-left dot
            let dotR = w * 0.06
            context.fill(
                Circle().path(in: CGRect(
                    x: pCenter.x - w * 0.12 - dotR,
                    y: pCenter.y - h * 0.10 - dotR,
                    width: dotR * 2, height: dotR * 2
                )),
                with: .foreground
            )

            // Bottom-right dot
            context.fill(
                Circle().path(in: CGRect(
                    x: pCenter.x + w * 0.12 - dotR,
                    y: pCenter.y + h * 0.10 - dotR,
                    width: dotR * 2, height: dotR * 2
                )),
                with: .foreground
            )
        }
    }
}

/// Receipt: Rectangle with zigzag torn bottom edge and text lines.
/// Represents receipt scanning and management.
struct FLOReceiptIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.06

            // Receipt body with zigzag bottom
            var receipt = Path()
            receipt.move(to: CGPoint(x: w * 0.15, y: h * 0.05))
            receipt.addLine(to: CGPoint(x: w * 0.85, y: h * 0.05))
            receipt.addLine(to: CGPoint(x: w * 0.85, y: h * 0.80))

            // Zigzag bottom edge
            let zigCount = 5
            let zigWidth = (w * 0.70) / CGFloat(zigCount)
            for i in 0..<zigCount {
                let xBase = w * 0.85 - CGFloat(i) * zigWidth
                let peak = i % 2 == 0 ? h * 0.88 : h * 0.80
                receipt.addLine(to: CGPoint(x: xBase - zigWidth / 2, y: peak))
                receipt.addLine(to: CGPoint(x: xBase - zigWidth, y: h * 0.80))
            }

            receipt.addLine(to: CGPoint(x: w * 0.15, y: h * 0.80))
            receipt.closeSubpath()

            context.stroke(
                receipt, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Text lines inside
            for yFrac in [0.28, 0.42, 0.56] {
                var textLine = Path()
                textLine.move(to: CGPoint(x: w * 0.28, y: h * yFrac))
                textLine.addLine(to: CGPoint(x: w * 0.72, y: h * yFrac))
                context.stroke(
                    textLine, with: .foreground,
                    style: StrokeStyle(lineWidth: lineW * 0.7, lineCap: .round)
                )
            }
        }
    }
}

/// Accounts: Two overlapping cards with chip on front card.
/// Represents multi-account management.
struct FLOAccountsIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.06
            let cornerR = w * 0.08

            // Back card (offset up-left)
            let backRect = CGRect(x: w * 0.05, y: h * 0.05, width: w * 0.72, height: h * 0.55)
            context.stroke(
                RoundedRectangle(cornerRadius: cornerR).path(in: backRect),
                with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.7)
            )

            // Front card (offset down-right)
            let frontRect = CGRect(x: w * 0.22, y: h * 0.35, width: w * 0.72, height: h * 0.55)

            // Fill front card background to occlude back card
            context.fill(
                RoundedRectangle(cornerRadius: cornerR).path(in: frontRect),
                with: .color(.clear)
            )

            context.stroke(
                RoundedRectangle(cornerRadius: cornerR).path(in: frontRect),
                with: .foreground,
                style: StrokeStyle(lineWidth: lineW)
            )

            // Chip on front card
            let chipRect = CGRect(
                x: frontRect.minX + w * 0.08,
                y: frontRect.minY + h * 0.12,
                width: w * 0.14,
                height: h * 0.10
            )
            context.stroke(
                RoundedRectangle(cornerRadius: w * 0.02).path(in: chipRect),
                with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.6)
            )

            // Horizontal line on front card (magnetic stripe)
            var stripe = Path()
            stripe.move(to: CGPoint(x: frontRect.minX + w * 0.08, y: frontRect.maxY - h * 0.14))
            stripe.addLine(to: CGPoint(x: frontRect.maxX - w * 0.08, y: frontRect.maxY - h * 0.14))
            context.stroke(
                stripe, with: .foreground,
                style: StrokeStyle(lineWidth: lineW * 0.6, lineCap: .round)
            )
        }
    }
}

/// Clients: Two overlapping person silhouettes.
/// Represents client management and relationships.
struct FLOClientsIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Back person (smaller, offset left)
            let backHeadR = w * 0.12
            let backHeadCenter = CGPoint(x: w * 0.35, y: h * 0.28)
            context.fill(
                Circle().path(in: CGRect(
                    x: backHeadCenter.x - backHeadR,
                    y: backHeadCenter.y - backHeadR,
                    width: backHeadR * 2, height: backHeadR * 2
                )),
                with: .foreground
            )

            // Back shoulders
            var backShoulders = Path()
            backShoulders.move(to: CGPoint(x: w * 0.12, y: h * 0.72))
            backShoulders.addQuadCurve(
                to: CGPoint(x: w * 0.58, y: h * 0.72),
                control: CGPoint(x: w * 0.35, y: h * 0.44)
            )
            context.fill(backShoulders, with: .foreground)

            // Front person (larger, offset right)
            let frontHeadR = w * 0.15
            let frontHeadCenter = CGPoint(x: w * 0.62, y: h * 0.24)
            context.fill(
                Circle().path(in: CGRect(
                    x: frontHeadCenter.x - frontHeadR,
                    y: frontHeadCenter.y - frontHeadR,
                    width: frontHeadR * 2, height: frontHeadR * 2
                )),
                with: .foreground
            )

            // Front shoulders
            var frontShoulders = Path()
            frontShoulders.move(to: CGPoint(x: w * 0.34, y: h * 0.78))
            frontShoulders.addQuadCurve(
                to: CGPoint(x: w * 0.90, y: h * 0.78),
                control: CGPoint(x: w * 0.62, y: h * 0.46)
            )
            context.fill(frontShoulders, with: .foreground)
        }
    }
}

/// Quick Action: Lightning bolt.
/// Represents speed and quick access to features.
struct FLOQuickActionIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var bolt = Path()
            bolt.move(to: CGPoint(x: w * 0.55, y: h * 0.02))
            bolt.addLine(to: CGPoint(x: w * 0.25, y: h * 0.48))
            bolt.addLine(to: CGPoint(x: w * 0.50, y: h * 0.48))
            bolt.addLine(to: CGPoint(x: w * 0.42, y: h * 0.98))
            bolt.addLine(to: CGPoint(x: w * 0.75, y: h * 0.48))
            bolt.addLine(to: CGPoint(x: w * 0.52, y: h * 0.48))
            bolt.closeSubpath()

            context.fill(bolt, with: .foreground)
        }
    }
}

/// Move Money: Two curved exchange arrows forming a cycle.
/// Represents transfers between accounts.
struct FLOMoveMoneyIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.08

            // Top arrow (left to right)
            var topArc = Path()
            topArc.addArc(
                center: CGPoint(x: w * 0.50, y: h * 0.45),
                radius: w * 0.30,
                startAngle: .degrees(-170),
                endAngle: .degrees(-10),
                clockwise: false
            )
            context.stroke(
                topArc, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Top arrowhead (right side)
            var topArrow = Path()
            let topTip = CGPoint(x: w * 0.78, y: h * 0.32)
            topArrow.move(to: CGPoint(x: topTip.x - w * 0.12, y: topTip.y - h * 0.06))
            topArrow.addLine(to: topTip)
            topArrow.addLine(to: CGPoint(x: topTip.x - w * 0.04, y: topTip.y + h * 0.12))
            context.stroke(
                topArrow, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Bottom arrow (right to left)
            var bottomArc = Path()
            bottomArc.addArc(
                center: CGPoint(x: w * 0.50, y: h * 0.55),
                radius: w * 0.30,
                startAngle: .degrees(10),
                endAngle: .degrees(170),
                clockwise: false
            )
            context.stroke(
                bottomArc, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Bottom arrowhead (left side)
            var bottomArrow = Path()
            let bottomTip = CGPoint(x: w * 0.22, y: h * 0.68)
            bottomArrow.move(to: CGPoint(x: bottomTip.x + w * 0.12, y: bottomTip.y + h * 0.06))
            bottomArrow.addLine(to: bottomTip)
            bottomArrow.addLine(to: CGPoint(x: bottomTip.x + w * 0.04, y: bottomTip.y - h * 0.12))
            context.stroke(
                bottomArrow, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

/// Expense: Downward arrow into tray/container.
/// Represents money going out.
struct FLOExpenseIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.08

            // Downward arrow shaft
            var shaft = Path()
            shaft.move(to: CGPoint(x: w * 0.50, y: h * 0.05))
            shaft.addLine(to: CGPoint(x: w * 0.50, y: h * 0.52))
            context.stroke(
                shaft, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Arrowhead
            var arrowhead = Path()
            arrowhead.move(to: CGPoint(x: w * 0.30, y: h * 0.38))
            arrowhead.addLine(to: CGPoint(x: w * 0.50, y: h * 0.56))
            arrowhead.addLine(to: CGPoint(x: w * 0.70, y: h * 0.38))
            context.stroke(
                arrowhead, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Tray/container (U-shape)
            var tray = Path()
            tray.move(to: CGPoint(x: w * 0.12, y: h * 0.60))
            tray.addLine(to: CGPoint(x: w * 0.12, y: h * 0.88))
            tray.addQuadCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.88),
                control: CGPoint(x: w * 0.12, y: h * 0.98)
            )
            // Use simple corner instead
            tray = Path()
            tray.move(to: CGPoint(x: w * 0.12, y: h * 0.60))
            tray.addLine(to: CGPoint(x: w * 0.12, y: h * 0.90))
            tray.addLine(to: CGPoint(x: w * 0.88, y: h * 0.90))
            tray.addLine(to: CGPoint(x: w * 0.88, y: h * 0.60))
            context.stroke(
                tray, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

/// Income icon — upward arrow rising from a tray (inverse of expense)
struct FLOIncomeIconShape: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let lineW = w * 0.08

            // Upward arrow shaft
            var shaft = Path()
            shaft.move(to: CGPoint(x: w * 0.50, y: h * 0.56))
            shaft.addLine(to: CGPoint(x: w * 0.50, y: h * 0.10))
            context.stroke(
                shaft, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round)
            )

            // Arrowhead pointing up
            var arrowhead = Path()
            arrowhead.move(to: CGPoint(x: w * 0.30, y: h * 0.26))
            arrowhead.addLine(to: CGPoint(x: w * 0.50, y: h * 0.08))
            arrowhead.addLine(to: CGPoint(x: w * 0.70, y: h * 0.26))
            context.stroke(
                arrowhead, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )

            // Tray/container (U-shape)
            var tray = Path()
            tray.move(to: CGPoint(x: w * 0.12, y: h * 0.60))
            tray.addLine(to: CGPoint(x: w * 0.12, y: h * 0.90))
            tray.addLine(to: CGPoint(x: w * 0.88, y: h * 0.90))
            tray.addLine(to: CGPoint(x: w * 0.88, y: h * 0.60))
            context.stroke(
                tray, with: .foreground,
                style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

// MARK: - Preview Gallery

#Preview("FLO Icon System — All Icons") {
    ScrollView {
        VStack(spacing: 24) {
            Text("FLO Icon System")
                .font(.title2.bold())
                .padding(.top)

            // All icons at large size
            Text("Large (48pt) — Quick Actions")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(FLOIcon.allCases, id: \.self) { icon in
                    VStack(spacing: 4) {
                        FLOBrandedIcon(icon: icon, size: .large)
                        Text(icon.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // All icons at medium size
            Text("Medium (32pt) — Card Headers")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(FLOIcon.allCases, id: \.self) { icon in
                    VStack(spacing: 4) {
                        FLOBrandedIcon(icon: icon, size: .medium)
                        Text(icon.rawValue)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            // All icons at small size
            Text("Small (24pt) — Inline")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(FLOIcon.allCases, id: \.self) { icon in
                    FLOBrandedIcon(icon: icon, size: .small)
                }
            }
            .padding(.horizontal)

            Divider()

            // Colored variants
            Text("Colored Variants (Large)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                FLOBrandedIcon(icon: .expense, size: .large, color: .red)
                FLOBrandedIcon(icon: .invoices, size: .large, color: .brandPrimary)
                FLOBrandedIcon(icon: .moveMoney, size: .large, color: .purple)
                FLOBrandedIcon(icon: .mileage, size: .large, color: .orange)
                FLOBrandedIcon(icon: .receipt, size: .large, color: .blue)
            }

            Divider()

            // Card header examples
            Text("FLOCardHeader Examples")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                FLOCardHeader(icon: .dashboard, title: "Dashboard")
                Divider()
                FLOCardHeader(icon: .budgets, title: "Budget Overview") {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
                FLOCardHeader(icon: .tax, title: "Tax Estimate")
            }
            .background(Color.floSecondarySystemBackground)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.bottom, 40)
    }
}

#Preview("FLO Icons — Dark Mode") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(FLOIcon.allCases, id: \.self) { icon in
                VStack(spacing: 4) {
                    FLOBrandedIcon(icon: icon, size: .large)
                    Text(icon.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
