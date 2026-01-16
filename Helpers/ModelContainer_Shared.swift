//  ModelContainer+Shared.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 - Added Account and InvoicePayment models for payment tracking
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
// Centralized ModelContainer factory with shared schema definition
// Eliminates duplication and ensures consistency across app, previews, and tests
//
// CHANGES FROM v3.0:
// ✅ Added Account model for bank/payment account tracking (15 total models now)
// ✅ Added InvoicePayment model for partial payment support
// ✅ Maintains custom "FLOSwiftData.store" location
// ✅ Works with App Groups for widget data sharing

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
        let config = ModelConfiguration(url: storeURL)
        
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
            ReminderRecord.self,
            BusinessProfile.self,
            MerchantCategoryMapping.self,
            ReceiptData.self,
            Account.self,              // ✅ Added in v4.0
            InvoicePayment.self,       // ✅ Added in v4.0
            configurations: config
        )
    }
    
    // MARK: - Preview & Testing Container
    
    /// Creates an in-memory only container to ideal for SwiftUI previews and unit tests.
    /// Data is never persisted to disk and is discarded when the container is deallocated.
    static func preview() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Transaction.self,
            Category.self,
            Budget.self,
            RecurringTransaction.self,
            TaxSettings.self,
            MileageTrip.self,
            Client.self,
            Invoice.self,
            InvoiceItem.self,
            ReminderRecord.self,
            BusinessProfile.self,
            MerchantCategoryMapping.self,
            ReceiptData.self,
            Account.self,              // ✅ Added in v4.0
            InvoicePayment.self,       // ✅ Added in v4.0
            configurations: config
        )
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
