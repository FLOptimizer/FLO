//  ReceiptImageView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 - Enhanced with Haptics & Micro-Animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Full-screen receipt viewer with smooth pinch-to-zoom, panning, and double-tap gestures
//
//  ENHANCEMENTS v3.0:
//  - Haptic feedback on zoom gestures (pinch and double-tap)
//  - Smooth entrance animation with fade and scale
//  - Haptic pulses at zoom boundaries (min/max)
//  - Double-tap zoom with satisfying haptic
//  - Pan boundaries with soft haptic feedback
//  - Loading state animation for image loading
//  - Error state with shake animation
//

import SwiftUI

// MARK: - Gesture State Manager

final class ZoomState: ObservableObject {
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    
    var lastScale: CGFloat = 1.0
    var lastOffset: CGSize = .zero
    
    func reset() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    func commitScale() {
        lastScale = scale
    }
    
    func commitOffset() {
        lastOffset = offset
    }
}

// MARK: - Main View

struct ReceiptImageView: View {
    let imagePath: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var zoomState = ZoomState()
    @State private var showLoadError = false
    
    // Animation States
    @State private var viewOpacity: Double = 0
    @State private var imageScale: CGFloat = 0.9
    @State private var isLoading = true
    @State private var errorShake = false
    @State private var zoomIndicatorOpacity: Double = 0
    @State private var currentZoomText = "1.0×"
    
    // MARK: - Image Loading
    
    private var uiImage: UIImage? {
        PhotoStorageManager.shared.loadReceiptSync(filename: imagePath)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = uiImage {
                    ZoomableImageView(
                        image: image,
                        zoomState: zoomState,
                        onZoomChange: handleZoomChange
                    )
                    .scaleEffect(imageScale)
                    .opacity(viewOpacity)
                    .onAppear {
                        animateImageEntrance()
                    }
                } else {
                    NoImagePlaceholder(isShaking: errorShake)
                        .opacity(viewOpacity)
                        .onAppear {
                            showLoadError = true
                            triggerErrorAnimation()
                        }
                }
                
                // Zoom indicator overlay
                if zoomIndicatorOpacity > 0 {
                    zoomIndicator
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Receipt")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                  
                        HapticService.play(.medium)
                        
                        withAnimation(.easeOut(duration: 0.25)) {
                            viewOpacity = 0
                            imageScale = 0.9
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                }
                
                // Reset zoom button
                if zoomState.scale > 1.0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            resetZoom()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: zoomState.scale > 1.0)
            .alert("Unable to Load Receipt", isPresented: $showLoadError) {
                Button("OK", role: .cancel) {
                
                    HapticService.play(.medium)
                }
            } message: {
                Text("The receipt image could not be loaded. It may have been deleted or corrupted.")
            }
            .onChange(of: imagePath) { _, _ in
                zoomState.reset()
                animateImageEntrance()
            }
        }
    }
    
    // MARK: - Zoom Indicator
    
    private var zoomIndicator: some View {
        VStack {
            Spacer()
            
            Text(currentZoomText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
                .opacity(zoomIndicatorOpacity)
            
            Spacer().frame(height: 40)
        }
    }
    
    // MARK: - Animations
    
    private func animateImageEntrance() {
        isLoading = false
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            viewOpacity = 1.0
            imageScale = 1.0
        }
    }
    
    private func triggerErrorAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            viewOpacity = 1.0
        }
        
        // Shake animation
        withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
            errorShake = true
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            errorShake = false
        }
    }
    
    private func handleZoomChange(_ newScale: CGFloat, hitBoundary: Bool) {
        currentZoomText = String(format: "%.1f×", newScale)
        
        // Show zoom indicator
        withAnimation(.easeOut(duration: 0.15)) {
            zoomIndicatorOpacity = 1.0
        }
        
        // Hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                zoomIndicatorOpacity = 0
            }
        }
        
        // Boundary haptic
        if hitBoundary {
          
            HapticService.play(.medium)
        }
    }
    
    private func resetZoom() {
     
        HapticService.play(.medium)
        
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            zoomState.reset()
        }
        
        currentZoomText = "1.0×"
        withAnimation(.easeOut(duration: 0.15)) {
            zoomIndicatorOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                zoomIndicatorOpacity = 0
            }
        }
    }
}

// MARK: - Zoomable Image View

private struct ZoomableImageView: View {
    let image: UIImage
    @ObservedObject var zoomState: ZoomState
    var onZoomChange: ((CGFloat, Bool) -> Void)?
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let doubleTapScale: CGFloat = 2.5
    
    @GestureState private var magnificationAmount: CGFloat = 1.0
    @GestureState private var dragAmount: CGSize = .zero
    
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(zoomState.scale * magnificationAmount, anchor: .center)
                .offset(
                    x: zoomState.offset.width + dragAmount.width,
                    y: zoomState.offset.height + dragAmount.height
                )
                .frame(width: size.width, height: size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(doubleTapGesture(in: size))
                .gesture(
                    zoomState.scale > minScale ?
                    dragGesture(in: size) : nil
                )
                .simultaneousGesture(magnificationGesture(in: size))
                .animation(.interactiveSpring(), value: zoomState.offset)
                .animation(.interactiveSpring(), value: zoomState.scale)
                .accessibilityLabel("Receipt image")
                .accessibilityHint(accessibilityHintText)
                .accessibilityAddTraits(.isImage)
                .accessibilityZoomAction { action in
                    switch action.direction {
                    case .zoomIn:
                        let newScale = min(zoomState.scale * 1.5, maxScale)
                        let hitBoundary = newScale == maxScale
                        
                      
                        HapticService.play(.medium)
                        
                        withAnimation {
                            zoomState.scale = newScale
                            zoomState.commitScale()
                        }
                        
                        onZoomChange?(newScale, hitBoundary)
                        
                    case .zoomOut:
                        let newScale = max(zoomState.scale / 1.5, minScale)
                        let hitBoundary = newScale == minScale
                        
                   
                        HapticService.play(.medium)
                        
                        withAnimation {
                            zoomState.scale = newScale
                            zoomState.commitScale()
                            if newScale == minScale {
                                zoomState.offset = .zero
                                zoomState.commitOffset()
                            }
                        }
                        
                        onZoomChange?(newScale, hitBoundary)
                    }
                }
        }
    }
    
    // MARK: - Accessibility
    
    private var accessibilityHintText: String {
        if zoomState.scale == 1.0 {
            return "Double tap to zoom in. Pinch to zoom."
        } else {
            return "Currently zoomed \(String(format: "%.1f", zoomState.scale))×. Double tap to zoom out."
        }
    }
    
    // MARK: - Gestures
    
    private func magnificationGesture(in size: CGSize) -> some Gesture {
        MagnificationGesture()
            .updating($magnificationAmount) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let newScale = zoomState.scale * value
                let clampedScale = min(max(newScale, minScale), maxScale)
                let hitBoundary = clampedScale == minScale || clampedScale == maxScale
                
                // Haptic feedback
              
                HapticService.play(.medium)
                
                withAnimation(FLOAnimation.quickEase) {
                    zoomState.scale = clampedScale
                    clampOffset(in: size)
                }
                zoomState.commitScale()
                
                onZoomChange?(clampedScale, hitBoundary)
            }
    }
    
    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .updating($dragAmount) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                withAnimation(FLOAnimation.quickEase) {
                    zoomState.offset.width += value.translation.width
                    zoomState.offset.height += value.translation.height
                    clampOffset(in: size)
                }
                zoomState.commitOffset()
            }
    }
    
    private func doubleTapGesture(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                // Haptic feedback for double-tap zoom
          
                HapticService.play(.medium)
                
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    if zoomState.scale > minScale {
                        // Zoom out - reset
                        zoomState.reset()
                        onZoomChange?(1.0, true)
                    } else {
                        // Zoom in to center
                        zoomState.scale = doubleTapScale
                        zoomState.lastScale = doubleTapScale
                        zoomState.offset = .zero
                        zoomState.lastOffset = .zero
                        onZoomChange?(doubleTapScale, false)
                    }
                }
            }
    }
    
    // MARK: - Bounds Clamping
    
    private func clampOffset(in size: CGSize) {
        // Clamp scale first
        if zoomState.scale < minScale {
            zoomState.scale = minScale
            zoomState.lastScale = minScale
        } else if zoomState.scale > maxScale {
            zoomState.scale = maxScale
            zoomState.lastScale = maxScale
        }
        
        // Calculate maximum allowed offset based on zoom level
        let scaledWidth = size.width * zoomState.scale
        let scaledHeight = size.height * zoomState.scale
        let maxOffsetX = max((scaledWidth - size.width) / 2, 0)
        let maxOffsetY = max((scaledHeight - size.height) / 2, 0)
        
        // Check if hitting boundaries for haptic
        let previousOffset = zoomState.offset
        
        // Clamp offset
        zoomState.offset.width = min(maxOffsetX, max(-maxOffsetX, zoomState.offset.width))
        zoomState.offset.height = min(maxOffsetY, max(-maxOffsetY, zoomState.offset.height))
        
        // Haptic if hit boundary
        if previousOffset != zoomState.offset &&
           (abs(zoomState.offset.width) == maxOffsetX || abs(zoomState.offset.height) == maxOffsetY) {
            
            HapticService.play(.medium)
        }
        
        zoomState.lastOffset = zoomState.offset
    }
}

// MARK: - Placeholder

private struct NoImagePlaceholder: View {
    var isShaking: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "receipt")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.4))
                .symbolEffect(.bounce, options: .speed(0.5))
            
            Text("Receipt Not Found")
                .font(.title2.bold())
                .foregroundStyle(.white.opacity(0.8))
            
            Text("The image may have been deleted or is corrupted.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .offset(x: isShaking ? -10 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Receipt image not available")
    }
}

// MARK: - Preview

#Preview("Valid Image") {
    NavigationStack {
        ReceiptImageView(imagePath: "sample-receipt.jpg")
    }
}

#Preview("Missing Image") {
    NavigationStack {
        ReceiptImageView(imagePath: "non-existent.jpg")
    }
}
