//  SuccessCheckmarkView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed duplicate extension conflicts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ FIXED: Removed duplicate Color.init(hex:) - uses FLO's Color extensions
//  ✅ FIXED: Uses Color.brandPrimary, Color.incomeGreen
//
//  PURPOSE:
//  Animated checkmark that draws a circle then checkmark inside.
//  Used in CelebrationOverlayView for success confirmations.
//
//  ACCESSIBILITY:
//  - Respects Reduce Motion: Instant appear without draw animation
//  - Respects user preference: Celebrations can be disabled in Appearance settings
//  - VoiceOver: Announces completion via parent view
//
//  USAGE:
//  SuccessCheckmarkView(isAnimating: $showSuccess, size: 80)
//

import SwiftUI

// MARK: - Success Checkmark View

struct SuccessCheckmarkView: View {
    @Binding var isAnimating: Bool
    
    /// Size of the checkmark circle
    var size: CGFloat = 80
    
    /// Circle stroke color (brand teal) - uses FLO's color system
    var circleColor: Color = Color.brandPrimary
    
    /// Checkmark stroke color (success green) - uses FLO's color system
    var checkColor: Color = Color.incomeGreen
    
    /// Stroke width
    var strokeWidth: CGFloat = 4
    
    /// Animation durations
    var circleDuration: Double = 0.3
    var checkDuration: Double = 0.25
    var checkDelay: Double = 0.15
    
    @State private var circleProgress: CGFloat = 0
    @State private var checkProgress: CGFloat = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    
    var body: some View {
        ZStack {
            // Circle
            Circle()
                .trim(from: 0, to: circleProgress)
                .stroke(
                    circleColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            
            // Checkmark
            CheckmarkShape()
                .trim(from: 0, to: checkProgress)
                .stroke(
                    checkColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size * 0.45, height: size * 0.35)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onChange(of: isAnimating) { _, newValue in
            if newValue && celebrationsEnabled {
                animate()
            } else if !newValue {
                reset()
            }
        }
        .accessibilityHidden(true)
    }
    
    // MARK: - Animation
    
    private func animate() {
        if reduceMotion {
            // Instant appear for reduced motion
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 1
                scale = 1
                circleProgress = 1
                checkProgress = 1
            }
        } else {
            // Full animated sequence
            
            // Initial scale and fade in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                opacity = 1
                scale = 1
            }
            
            // Draw circle
            withAnimation(.easeOut(duration: circleDuration)) {
                circleProgress = 1
            }
            
            // Draw checkmark after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + circleDuration + checkDelay) {
                withAnimation(.easeOut(duration: checkDuration)) {
                    checkProgress = 1
                }
                
                // Bounce effect when complete
                DispatchQueue.main.asyncAfter(deadline: .now() + checkDuration) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                        scale = 1.1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            scale = 1.0
                        }
                    }
                }
            }
        }
    }
    
    private func reset() {
        circleProgress = 0
        checkProgress = 0
        scale = 0.8
        opacity = 0
    }
}

// MARK: - Checkmark Shape

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Checkmark path: starts bottom-left of check, goes to bottom point, then up-right
        let startPoint = CGPoint(x: rect.minX, y: rect.midY)
        let midPoint = CGPoint(x: rect.width * 0.35, y: rect.maxY)
        let endPoint = CGPoint(x: rect.maxX, y: rect.minY)
        
        path.move(to: startPoint)
        path.addLine(to: midPoint)
        path.addLine(to: endPoint)
        
        return path
    }
}

// MARK: - Previews

#Preview("Animated Checkmark") {
    struct PreviewWrapper: View {
        @State private var isAnimating = false
        
        var body: some View {
            VStack(spacing: 40) {
                SuccessCheckmarkView(isAnimating: $isAnimating, size: 100)
                
                Button("Animate") {
                    isAnimating = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimating = true
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}

#Preview("Different Sizes") {
    HStack(spacing: 30) {
        SuccessCheckmarkView(isAnimating: .constant(true), size: 40)
        SuccessCheckmarkView(isAnimating: .constant(true), size: 60)
        SuccessCheckmarkView(isAnimating: .constant(true), size: 80)
        SuccessCheckmarkView(isAnimating: .constant(true), size: 100)
    }
    .padding()
}
