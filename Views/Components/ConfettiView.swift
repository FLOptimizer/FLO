//  ConfettiView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed duplicate extension conflicts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ FIXED: Removed duplicate Color.init(hex:) - uses FLO's Color extensions
//  ✅ FIXED: Uses Color.brandPrimary, Color.incomeGreen, etc.
//
//  PURPOSE:
//  Animated confetti particle effect for success celebrations.
//  Used in CelebrationOverlayView for invoice payments and income transactions.
//
//  ACCESSIBILITY:
//  - Respects Reduce Motion: Falls straight without rotation when enabled
//  - Respects user preference: Celebrations can be disabled in Appearance settings
//  - Pure visual decoration: Does not convey essential information
//
//  USAGE:
//  ConfettiView(isActive: $showConfetti)
//      .allowsHitTesting(false)
//

import SwiftUI

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let shape: ConfettiShape
    let size: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let fallSpeed: Double
    let horizontalDrift: CGFloat
    
    enum ConfettiShape: CaseIterable {
        case circle
        case rectangle
        case star
        case sparkle
        
        var systemImage: String? {
            switch self {
            case .star: return "star.fill"
            case .sparkle: return "sparkle"
            default: return nil
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @Binding var isActive: Bool
    
    /// Number of confetti particles
    var particleCount: Int = 40
    
    /// Duration of the animation
    var duration: Double = 2.0
    
    /// Brand colors for confetti - uses FLO's color system
    private var confettiColors: [Color] {
        [
            Color.brandPrimary,      // Teal
            Color.incomeGreen,       // Success Green
            Color.brandPrimaryDark,  // Dark Teal
            Color.brandWarning,      // Gold/Orange
            Color.yellow,            // Light Gold
            Color.indigo,            // Indigo accent
        ]
    }
    
    @State private var particles: [ConfettiParticle] = []
    @State private var animationProgress: CGFloat = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("celebrationsEnabled") private var celebrationsEnabled = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(
                        particle: particle,
                        progress: animationProgress,
                        containerHeight: geometry.size.height,
                        reduceMotion: reduceMotion
                    )
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue && celebrationsEnabled {
                    startConfetti(in: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    
    // MARK: - Particle Generation
    
    private func startConfetti(in size: CGSize) {
        // Generate particles
        particles = (0..<particleCount).map { _ in
            ConfettiParticle(
                color: confettiColors.randomElement() ?? .teal,
                shape: ConfettiParticle.ConfettiShape.allCases.randomElement() ?? .circle,
                size: CGFloat.random(in: 6...12),
                startX: CGFloat.random(in: 0...size.width),
                startY: -20,
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: 180...720),
                fallSpeed: Double.random(in: 0.8...1.2),
                horizontalDrift: CGFloat.random(in: -30...30)
            )
        }
        
        // Animate
        animationProgress = 0
        
        if reduceMotion {
            // Reduced motion: instant appear, then fade
            withAnimation(.easeOut(duration: 0.3)) {
                animationProgress = 0.3
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animationProgress = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isActive = false
                particles = []
            }
        } else {
            // Full animation
            withAnimation(.linear(duration: duration)) {
                animationProgress = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                isActive = false
                particles = []
            }
        }
    }
}

// MARK: - Individual Particle View

private struct ParticleView: View {
    let particle: ConfettiParticle
    let progress: CGFloat
    let containerHeight: CGFloat
    let reduceMotion: Bool
    
    private var yOffset: CGFloat {
        if reduceMotion {
            // Reduced motion: appear in place, no fall
            return containerHeight * 0.3
        }
        return progress * containerHeight * particle.fallSpeed
    }
    
    private var xOffset: CGFloat {
        if reduceMotion {
            return 0
        }
        return sin(progress * .pi * 2) * particle.horizontalDrift
    }
    
    private var rotation: Double {
        if reduceMotion {
            return 0
        }
        return particle.rotation + (progress * particle.rotationSpeed)
    }
    
    private var opacity: Double {
        if progress > 0.7 {
            return Double(1.0 - ((progress - 0.7) / 0.3))
        }
        return 1.0
    }
    
    var body: some View {
        particleShape
            .position(
                x: particle.startX + xOffset,
                y: particle.startY + yOffset
            )
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
    }
    
    @ViewBuilder
    private var particleShape: some View {
        switch particle.shape {
        case .circle:
            Circle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size)
            
        case .rectangle:
            Rectangle()
                .fill(particle.color)
                .frame(width: particle.size * 0.6, height: particle.size)
            
        case .star, .sparkle:
            if let systemImage = particle.shape.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: particle.size))
                    .foregroundStyle(particle.color)
            }
        }
    }
}

// MARK: - Preview

#Preview("Confetti Active") {
    struct PreviewWrapper: View {
        @State private var isActive = false
        
        var body: some View {
            ZStack {
                Color.black.opacity(0.3)
                
                ConfettiView(isActive: $isActive)
                
                Button("Trigger Confetti") {
                    isActive = true
                }
                .buttonStyle(.borderedProminent)
            }
            .ignoresSafeArea()
        }
    }
    
    return PreviewWrapper()
}
