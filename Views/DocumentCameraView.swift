//  DocumentCameraView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Enhanced with Haptic Feedback
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Document camera wrapper for VisionKit scanner
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
                HapticService.play(.medium)
                
                parent.dismiss()
                return
            }
            
            // Success haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Secondary celebration haptic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticService.play(.medium)
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
            HapticService.play(.medium)
            
            #if DEBUG
            print("📷 Document scan cancelled by user")
            #endif
            
            parent.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            // Error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
            #if DEBUG
            print("❌ Document Camera Error: \(error.localizedDescription)")
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
        Text("Camera preview not available in simulator")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
