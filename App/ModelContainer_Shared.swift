//  ModelContainer_Shared.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.5 - Fixed CloudKit validation in preview/testing containers
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
// Centralized ModelContainer factory with shared schema definition
// Eliminates duplication and ensures consistency across app, previews, and tests
//
// CHANGES FROM v4.4:
// ✅ Added cloudKitDatabase: .none to preview() container
// ✅ Fixes test failures when app has CloudKit entitlements
// ✅ SwiftData validates schema against CloudKit even for in-memory stores
//
// CHANGES FROM v4.3:
// ✅ Added ReceiptLineItem.self (was missing, caused test crashes)
// ✅ Now 15 total models
//
// CHANGES FROM v4.2:
// ✅ Added automatic recovery when migration fails
// ✅ Deletes old incompatible store and creates fresh one
// ✅ Prevents "Cannot migrate store in-place" crashes
//
// CHANGES FROM v4.1:
// ✅ Disabled CloudKit sync with cloudKitDatabase: .none
// ✅ CloudKit requires optional attributes, no unique constraints, relationship inverses
// ✅ Can re-enable later when models are CloudKit-ready

import SwiftData
import Foundation

extension ModelContainer {
    
    // MARK: - Production Container
    
    /// Creates the production-ready ModelContainer with custom App Group store URL.
    /// Uses the SAME custom store location as FLOApp v2.6.
    /// Suitable for app launch, widgets, and extensions.
    static func shared() throws -> ModelContainer {
        // CRITICAL: Use the SAME custom store URL as FLOApp v2.6
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.finchandpoppy.flo"
        ) else {
            throw NSError(
                domain: "FLO.ModelContainer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "App Group not configured"]
            )
        }
        
        // Use the same unique store name: FLOSwiftData.store
        let storeURL = groupURL.appendingPathComponent("FLOSwiftData.store")
        
        // IMPORTANT: Disable CloudKit sync - our models aren't CloudKit-compatible yet
        // CloudKit requires: all optional attributes, no unique constraints, all relationship inverses
        // We can enable this later when we make models CloudKit-ready
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        
        do {
            // Create ModelContainer with ALL 15 models
            return try ModelContainer(
                for: Transaction.self,
                Category.self,
                Budget.self,
                RecurringTransaction.self,
                TaxSettings.self,
                MileageTrip.self,
                Client.self,
                Invoice.self,
                InvoiceItem.self,
                BusinessProfile.self,
                MerchantCategoryMapping.self,
                ReceiptData.self,
                ReceiptLineItem.self,      // ✅ Added in v4.4 (was missing!)
                Account.self,
                InvoicePayment.self,
                configurations: config
            )
        } catch {
            // Migration failed - attempt recovery by deleting old store
            print("⚠️ ModelContainer migration failed: \(error)")
            print("🔄 Attempting recovery by deleting old store...")
            
            // Delete old store files
            let fileManager = FileManager.default
            let storeFiles = [
                storeURL,
                storeURL.appendingPathExtension("shm"),
                storeURL.appendingPathExtension("wal")
            ]
            
            for file in storeFiles {
                try? fileManager.removeItem(at: file)
            }
            
            // Also check for .store-shm and .store-wal variations
            let basePath = storeURL.path
            for suffix in ["-shm", "-wal"] {
                let path = basePath + suffix
                try? fileManager.removeItem(atPath: path)
            }
            
            print("✅ Old store files deleted, creating fresh container...")
            
            // Try again with fresh store
            return try ModelContainer(
                for: Transaction.self,
                Category.self,
                Budget.self,
                RecurringTransaction.self,
                TaxSettings.self,
                MileageTrip.self,
                Client.self,
                Invoice.self,
                InvoiceItem.self,
                BusinessProfile.self,
                MerchantCategoryMapping.self,
                ReceiptData.self,
                ReceiptLineItem.self,
                Account.self,
                InvoicePayment.self,
                configurations: config
            )
        }
    }
    
    // MARK: - Preview & Testing Container
    
    /// Creates an in-memory only container ideal for SwiftUI previews and unit tests.
    /// Data is never persisted to disk and is discarded when the container is deallocated.
    static func preview() -> ModelContainer {
        // IMPORTANT: Must explicitly disable CloudKit even for in-memory stores
        // Otherwise SwiftData validates schema against CloudKit requirements
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(
                for: Transaction.self,
                Category.self,
                Budget.self,
                RecurringTransaction.self,
                TaxSettings.self,
                MileageTrip.self,
                Client.self,
                Invoice.self,
                InvoiceItem.self,
                BusinessProfile.self,
                MerchantCategoryMapping.self,
                ReceiptData.self,
                ReceiptLineItem.self,      // ✅ Added in v4.4
                Account.self,
                InvoicePayment.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
    
    // MARK: - Test Container (Optional Helper)
    
    /// Convenience for tests that need a fresh in-memory container per test case.
    static func forTesting() -> ModelContainer {
        preview()
    }
}

// MARK: - Recommended Usage Examples
/*
 //CORRECT: Use in Widget Extensions
 struct FLOWidget: Widget {
     let container: ModelContainer
     
     init() {
         do {
             container = try ModelContainer.shared()
             print("Widget: Using shared FLOSwiftData.store")
         } catch {
             fatalError("Widget: Failed to create ModelContainer: \(error)")
         }
     }
     
     var body: some WidgetConfiguration {
         // ... widget configuration
     }
 }
 
 // CORRECT: Use in Service Classes
 class MyService {
     func updateData() async {
         do {
             let container = try ModelContainer.shared()
             let context = ModelContext(container)
             // ... perform operations
         } catch {
             print("❌ Service: Failed to access ModelContainer: \(error)")
         }
     }
 }
 
 // CORRECT: SwiftUI Previews
 #Preview("Light Mode") {
     ContentView()
         .environmentObject(BiometricAuthService.shared)
         .modelContainer(ModelContainer.preview())
         .preferredColorScheme(.light)
 }
 
 #Preview("Dark Mode") {
     ContentView()
         .environmentObject(BiometricAuthService.shared)
         .modelContainer(ModelContainer.preview())
         .preferredColorScheme(.dark)
 }
 
 // CORRECT: XCTest
 class FLOTests: XCTestCase {
     var container: ModelContainer!
     
     override func setUp() {
         super.setUp()
         container = ModelContainer.forTesting()
     }
     
     override func tearDown() {
         container = nil
         super.tearDown()
     }
 }
 
 // ❌ INCORRECT: Don't create ModelContainer without configuration
 // This will use default.store and cause conflicts:
 let badContainer = try ModelContainer(
     for: Transaction.self,
     Category.self,
     Budget.self
     // ... missing custom configuration!
 )
 
 // CORRECT: Always use the shared() method or explicit custom config
 let goodContainer = try ModelContainer.shared()
 */
