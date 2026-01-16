//  ReceiptScannerService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed conditional downcast warning
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  Basic receipt scanning service using Apple Vision Framework
//

import Foundation
import Vision
import UIKit

class ReceiptScannerService {
    static let shared = ReceiptScannerService()
    
    private init() {}
    
    // MARK: - Receipt Scanning
    
    /// Scan receipt image and extract text using Vision Framework
    func scanReceiptSafe(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ReceiptScanError.invalidImage
        }
        
        return try await Task.detached {
            // All Vision operations happen in this isolated context
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true
            
            try handler.perform([request])
            
            // FIX: Removed unnecessary "as? [VNRecognizedTextObservation]" downcast
            // The results property of VNRecognizeTextRequest is already typed as [VNRecognizedTextObservation]?
            // So we only need to unwrap the optional, not downcast it
            guard let observations = request.results else {
                throw ReceiptScanError.ocrFailed
            }
            
            return observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            .joined(separator: "\n")
        }.value
    }
}

// MARK: - Errors

enum ReceiptScanError: LocalizedError {
    case invalidImage
    case ocrFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image is invalid"
        case .ocrFailed:
            return "Failed to extract text from receipt"
        }
    }
}
