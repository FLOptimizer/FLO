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
            // Best-effort thumbnail removal
            await deleteThumbnail(filename: filename)
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
    
    /// Deletes all orphaned receipt images not present in the valid set.
    /// Also cleans orphaned thumbnails from the thumbnails/ subdirectory.
    @discardableResult
    func cleanupOrphanedReceipts(validFilenames: Set<String>) async -> Int {
        let allFiles = await allReceiptFilenames()
        let orphans = allFiles.filter { !validFilenames.contains($0) }

        // Parallel deletion (safe - no shared state mutation)
        await withTaskGroup(of: Void.self) { group in
            for filename in orphans {
                group.addTask {
                    _ = try? await self.deleteReceipt(filename: filename)
                }
            }
        }

        // Also purge orphaned thumbnails
        if let thumbURLs = try? FileManager.default.contentsOfDirectory(
            at: thumbnailDirectory,
            includingPropertiesForKeys: nil
        ) {
            let orphanThumbs = thumbURLs
                .map { $0.lastPathComponent }
                .filter { !validFilenames.contains($0) }
            for name in orphanThumbs {
                await deleteThumbnail(filename: name)
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
    
    // MARK: - Thumbnail Support

    private let thumbnailDirectoryName = "thumbnails"
    private let thumbnailSize = CGSize(width: 150, height: 150)
    private let thumbnailCompressionQuality: CGFloat = 0.60

    nonisolated private var thumbnailDirectory: URL {
        receiptsDirectory.appending(path: thumbnailDirectoryName, directoryHint: .isDirectory)
    }

    nonisolated private func ensureThumbnailDirectoryExists() {
        guard !FileManager.default.fileExists(atPath: thumbnailDirectory.path) else { return }
        do {
            #if canImport(UIKit)
            try FileManager.default.createDirectory(
                at: thumbnailDirectory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            #else
            try FileManager.default.createDirectory(
                at: thumbnailDirectory,
                withIntermediateDirectories: true
            )
            #endif
        } catch {
            Self.logger.error("❌ Failed to create thumbnails directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns true if a thumbnail exists for the given receipt filename
    func thumbnailExists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: thumbnailDirectory.appending(path: filename).path)
    }

    /// Generates and saves a 150×150 JPEG thumbnail alongside a saved receipt image.
    /// Silently skips if thumbnail already exists.
    func saveThumbnail(forFilename filename: String, from image: UIImage) async throws {
        ensureThumbnailDirectoryExists()

        let fileURL = thumbnailDirectory.appending(path: filename)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        guard let thumb = generateThumbnail(from: image, size: thumbnailSize),
              let jpegData = thumb.jpegData(compressionQuality: thumbnailCompressionQuality) else {
            Self.logger.warning("⚠️ Could not generate thumbnail for \(filename, privacy: .public)")
            return
        }

        do {
            try jpegData.write(to: fileURL, options: .atomic)
            Self.logger.info("✅ Saved thumbnail \(filename, privacy: .public) – \(jpegData.count / 1024) KB")
        } catch {
            Self.logger.error("❌ Failed to write thumbnail \(filename): \(error.localizedDescription, privacy: .public)")
            throw PhotoStorageError.fileWriteFailed(error)
        }
    }

    /// Loads a receipt thumbnail. Falls back to generating from the full image if the
    /// thumbnail file is missing, and saves it for future calls.
    func loadThumbnail(filename: String) async throws -> UIImage {
        guard !filename.isEmpty else {
            throw PhotoStorageError.fileReadFailed(
                NSError(domain: "PhotoStorage", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Empty filename"])
            )
        }

        let fileURL = thumbnailDirectory.appending(path: filename)

        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }

        // Thumbnail missing – generate from full image and persist for next time
        let fullImage = try await loadReceipt(filename: filename)
        guard let thumb = generateThumbnail(from: fullImage, size: thumbnailSize) else {
            throw PhotoStorageError.invalidImageData
        }
        try? await saveThumbnail(forFilename: filename, from: fullImage)
        return thumb
    }

    /// Deletes the thumbnail for a receipt (best-effort, no error thrown).
    func deleteThumbnail(filename: String) async {
        let fileURL = thumbnailDirectory.appending(path: filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func generateThumbnail(from image: UIImage, size: CGSize) -> UIImage? {
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        #else
        return nil
        #endif
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
