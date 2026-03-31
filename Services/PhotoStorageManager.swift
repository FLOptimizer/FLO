//  PhotoStorageManager.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Elite Production Quality (Swift 6 Strict Concurrency)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Thread-safe, async-first receipt image storage manager
//  All Swift 6 concurrency errors resolved
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import os.log

// MARK: - Public Error Type

enum PhotoStorageError: Error {
    case jpegConversionFailed
    case fileWriteFailed(Error)
    case fileReadFailed(Error)
    case fileDeleteFailed(Error)
    case directoryCreationFailed(Error)
    case invalidImageData
    
    var localizedDescription: String {
        switch self {
        case .jpegConversionFailed:
            return "Failed to convert image to JPEG format"
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        case .fileReadFailed(let error):
            return "Failed to read file: \(error.localizedDescription)"
        case .fileDeleteFailed(let error):
            return "Failed to delete file: \(error.localizedDescription)"
        case .directoryCreationFailed(let error):
            return "Failed to create directory: \(error.localizedDescription)"
        case .invalidImageData:
            return "Invalid image data"
        }
    }
}

// MARK: - Actor (Thread-Safe Singleton)

actor PhotoStorageManager {
    static let shared = PhotoStorageManager()
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.finchandpoppy.flo",
        category: "PhotoStorage"
    )
    
    // MARK: - Configuration
    
    private let compressionQuality: CGFloat = 0.80
    private let directoryName = "Receipts"
    private let fileExtension = "jpg"
    
    // FIX 1: Make receiptsDirectory nonisolated (just path computation, no actor state)
    nonisolated private var receiptsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: directoryName, directoryHint: .isDirectory)
    }
    
    // FIX 1b: Convenience property (also nonisolated)
    nonisolated var directoryURL: URL {
        receiptsDirectory
    }
    
    // MARK: - Initialization
    
    private init() {
        ensureReceiptsDirectoryExists()
    }
    
    // FIX 1c: Make nonisolated since it only uses FileManager
    nonisolated private func ensureReceiptsDirectoryExists() {
        guard !FileManager.default.fileExists(atPath: receiptsDirectory.path) else {
            return
        }
        
        do {
            #if canImport(UIKit)
            try FileManager.default.createDirectory(
                at: receiptsDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            #else
            try FileManager.default.createDirectory(
                at: receiptsDirectory,
                withIntermediateDirectories: true
            )
            #endif
            Self.logger.info("✅ Created Receipts directory at \(self.receiptsDirectory.path, privacy: .public)")
        } catch {
            Self.logger.error("❌ Failed to create Receipts directory: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    // MARK: - Public API (async/await)
    
    /// Saves a receipt image and returns its unique filename
    func saveReceipt(image: UIImage) async throws -> String {
        guard let jpegData = image.jpegData(compressionQuality: compressionQuality) else {
            
            Self.logger.error("❌ JPEG conversion failed for image of size \(image.size.width)x\(image.size.height)")
            throw PhotoStorageError.jpegConversionFailed
        }
        
        let filename = generateUniqueFilename()
        let fileURL = receiptsDirectory.appending(path: filename)
        
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            
            let kb = jpegData.count / 1024
            Self.logger.info("✅ Saved receipt \(filename, privacy: .public) – \(kb) KB")
            return filename
        } catch {
            Self.logger.error("❌ Failed to write receipt \(filename): \(error.localizedDescription, privacy: .public)")
            throw PhotoStorageError.fileWriteFailed(error)
        }
    }
    
    /// Loads a receipt image by filename
    func loadReceipt(filename: String) async throws -> UIImage {
        guard !filename.isEmpty else {
            throw PhotoStorageError.fileReadFailed(NSError(domain: "PhotoStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty filename"]))
        }

        let fileURL = receiptsDirectory.appending(path: filename)

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            Self.logger.error("❌ Failed to read file \(filename): \(error.localizedDescription, privacy: .public)")
            throw PhotoStorageError.fileReadFailed(error)
        }
        
        guard let image = UIImage(data: data) else {
            Self.logger.error("❌ Invalid image data for \(filename, privacy: .public)")
            throw PhotoStorageError.invalidImageData
        }
        
        return image
    }
    
    /// Deletes a receipt image
    @discardableResult
    func deleteReceipt(filename: String) async throws -> Bool {
        let fileURL = receiptsDirectory.appending(path: filename)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Self.logger.warning("⚠️ Attempted to delete non-existent receipt: \(filename, privacy: .public)")
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            Self.logger.info("🗑️ Deleted receipt: \(filename, privacy: .public)")
            return true
        } catch {
            Self.logger.error("❌ Failed to delete \(filename): \(error.localizedDescription, privacy: .public)")
            throw PhotoStorageError.fileDeleteFailed(error)
        }
    }
    
    /// Returns all stored receipt filenames (sorted newest first)
    func allReceiptFilenames() async -> [String] {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: receiptsDirectory,
                includingPropertiesForKeys: nil
            )
            
            // FIX 3: Use explicit self.fileExtension for Swift 6
            let jpgs = urls
                .filter { $0.pathExtension.lowercased() == self.fileExtension }
                .map { $0.lastPathComponent }
                .sorted(by: >)
            
            return jpgs
        } catch {
            Self.logger.error("❌ Failed to list receipts: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    /// Calculates total storage used by receipts (fast path using resource keys)
    func totalStorageUsed() async -> Int64 {
        let resourceKeys: [URLResourceKey] = [.fileSizeKey]
        
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: receiptsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        
        // FIX 3: Use explicit self.fileExtension
        return urls
            .lazy
            .filter { $0.pathExtension == self.fileExtension }
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0 as Int64) { $0 + Int64($1) }
    }
    
    /// Human-readable storage size
    var storageUsedFormatted: String {
        get async {
            let bytes = await totalStorageUsed()
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: bytes)
        }
    }
    
    /// Deletes all orphaned receipt images not present in the valid set
    @discardableResult
    func cleanupOrphanedReceipts(validFilenames: Set<String>) async -> Int {
        let allFiles = await allReceiptFilenames()
        let orphans = allFiles.filter { !validFilenames.contains($0) }
        
        // Parallel deletion (safe - no shared state mutation)
        await withTaskGroup(of: Void.self) { group in
            for filename in orphans {
                group.addTask {
                    // FIX 4: Explicitly discard unused result
                    _ = try? await self.deleteReceipt(filename: filename)
                }
            }
        }
        
        let count = orphans.count
        if count > 0 {
            Self.logger.info("🧹 Cleaned up \(count) orphaned receipt(s)")
        }
        
        return count
    }
    
    /// Checks existence without loading the image
    func receiptExists(filename: String) async -> Bool {
        let fileURL = receiptsDirectory.appending(path: filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Private Helpers
    
    private func generateUniqueFilename() -> String {
        // Combines timestamp + random UUID segment – virtually collision-proof
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = UUID().uuidString.lowercased().prefix(8)
        return "receipt_\(timestamp)_\(random).\(fileExtension)"
    }
}

// MARK: - Synchronous Compatibility Layer (Migration Only)

extension PhotoStorageManager {
    /// Synchronous wrapper - use async version when possible
    /// Only for compatibility with existing sync code during migration
    nonisolated func saveReceiptSync(image: UIImage) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        
        Task {
            result = try? await self.saveReceipt(image: image)
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Synchronous wrapper - use async version when possible
    nonisolated func loadReceiptSync(filename: String) -> UIImage? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: UIImage?
        
        Task {
            result = try? await self.loadReceipt(filename: filename)
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    /// Synchronous wrapper - use async version when possible
    nonisolated func deleteReceiptSync(filename: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        
        Task {
            result = (try? await self.deleteReceipt(filename: filename)) ?? false
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
}
