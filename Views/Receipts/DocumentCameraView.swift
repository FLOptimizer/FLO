//  DocumentCameraView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Document camera wrapper for VisionKit scanner
//
//  CHANGES v2.3 - Dynamic Type Verification:
//  ✅ FIXED: Preview headline text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Preview caption text missing lineLimit + minimumScaleFactor
//  ✅ VERIFIED: VisionKit provides native accessibility for camera controls
//
//  CHANGES v2.2:
//  - Fixed MainActor isolation for HapticService calls (Swift 6 compliance)
//  - Wrapped haptic calls in Task { @MainActor in } for delegate methods
//
//  CHANGES v2.1:
//  - Migrated all haptic feedback to HapticService singleton
//  - Removed local UINotificationFeedbackGenerator instances
//
//  ENHANCEMENTS v2.0:
//  - Success haptic feedback on scan completion
//  - Error haptic on scan failure
//  - Cancel haptic feedback
//  - Console logging for debugging
//

import SwiftUI
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView
        
        init(_ parent: DocumentCameraView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                #if DEBUG
                print("📷 Document scan completed with 0 pages")
                #endif
                
                // Light haptic for empty scan
                Task { @MainActor in
                    HapticService.shared.mediumImpact()
                }
                
                parent.dismiss()
                return
            }
            
            // Success haptic
            Task { @MainActor in
                HapticService.shared.success()
                
                // Secondary celebration haptic
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                HapticService.shared.mediumImpact()
            }
            
            // Get the first scanned page
            let image = scan.imageOfPage(at: 0)
            parent.image = image
            
            #if DEBUG
            print("📷 Document scan successful: \(scan.pageCount) page(s)")
            print("   Image size: \(image.size.width) x \(image.size.height)")
            #endif
            
            parent.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            // Light haptic for cancel
            Task { @MainActor in
                HapticService.shared.mediumImpact()
            }
            
            #if DEBUG
            print("📷 Document scan cancelled by user")
            #endif
            
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            // Error haptic
            Task { @MainActor in
                HapticService.shared.error()
            }
            
            #if DEBUG
            print("âŒ Document Camera Error: \(error.localizedDescription)")
            #endif
            
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    // DocumentCameraView requires a camera and cannot be previewed in simulator
    VStack {
        Text("Document Camera")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        Text("Camera preview not available in simulator")
            .font(.caption)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.secondary)
    }
}
