//  ModelContainer_Shared.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 5.8 - LinkedCard Schema (card-to-account linking)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
// Centralized ModelContainer factory with shared schema definition
// Eliminates duplication and ensures consistency across app, previews, and tests
//
// CHANGES FROM v5.3:
// ✅ Added Bill.self, BillPayment.self, Vendor.self for the Bills feature
// ✅ Now 25 total models (up from 22)
// ✅ FIXED: Recovery branch was missing RecurringPaymentLog.self (omitted in v5.3) —
//    if migration ever fell into the recovery path it would have crashed on next launch
//
// CHANGES FROM v5.1:
// ✅ Schema change: BusinessProfile now has relationships to Account, TaxSettings, Invoice
// ✅ Account gains businessProfile optional relationship
// ✅ TaxSettings gains businessProfile optional relationship
// ✅ Invoice gains businessProfile optional relationship
// ✅ NOTE: Fresh install migration — auto-creates BusinessProfile from existing data
//
// CHANGES FROM v4.8:
// ✅ Enabled CloudKit sync: cloudKitDatabase: .automatic in shared() container
// ✅ All 20 models now CloudKit-compatible (no @Attribute(.unique), all defaults set)
// ✅ Preview/test containers remain .none (no CloudKit in tests)
// ✅ SwiftData handles all CloudKit mirroring via NSPersistentCloudKitContainer
//
// CHANGES FROM v4.7:
// ✅ Added Household.self and HouseholdMember.self for household sharing
// ✅ Now 20 total models (up from 18)
//
// CHANGES FROM v4.6:
// ✅ Added BalanceAnchor.self for anchor-based balance reconciliation
// ✅ Now 18 total models (up from 17)
// ✅ Supports CSV import reconciliation (Issue #3)
//
// CHANGES FROM v4.5:
// ✅ Added Transfer.self and RecurringTransfer.self
// ✅ Now 17 total models (up from 15)
// ✅ Supports new "Move Money" feature with double-entry transfers
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
// ✅ Originally disabled CloudKit sync with cloudKitDatabase: .none
// ✅ Re-enabled in v5.0 after making all models CloudKit-compatible

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
        
        // CloudKit sync ENABLED — all 20 models are now CloudKit-compatible
        // Models have: inline defaults on all stored properties, no @Attribute(.unique)
        // SwiftData handles CloudKit mirroring automatically via NSPersistentCloudKitContainer
        let config = ModelConfiguration(url: storeURL, cloudKitDatabase: .automatic)
        
        do {
            // Create ModelContainer with ALL 25 models
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
                Transfer.self,             // ✅ Added in v4.6 for Move Money feature
                RecurringTransfer.self,    // ✅ Added in v4.6 for recurring transfers
                BalanceAnchor.self,        // ✅ Added in v4.7 for reconciliation
                Household.self,            // ✅ Added in v4.8 for household sharing
                HouseholdMember.self,      // ✅ Added in v4.8 for household sharing
                AssistantMessage.self,     // ✅ Added in v5.1 for My Assistant
                RecurringPaymentLog.self,  // ✅ Added in v5.3 for payment tracking
                Vendor.self,               // ✅ Added in v5.4 for Bills feature
                Bill.self,                 // ✅ Added in v5.4 for Bills feature
                BillPayment.self,          // ✅ Added in v5.4 for Bills feature
                PartnerAllocation.self,    // ✅ Added in v5.5 for tax prep
                DepreciableAsset.self,     // ✅ Added in v5.5 for depreciation tracking
                TaxCarryforward.self,      // ✅ Added in v5.5 for carryforward register
                EntityJurisdiction.self,   // ✅ Added in v5.6 for jurisdiction tracking
                DebtAcceleratorPlan.self,  // ✅ Added in v5.7 for Debt Accelerator
                ScheduledPayment.self,     // ✅ Added in v5.7 for Debt Accelerator
                LinkedCard.self,           // ✅ Added in v5.8 for card-to-account linking
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
            
            // Try again with fresh store — MUST stay in sync with the primary
            // ModelContainer call above. Missing models here will crash on next launch.
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
                Transfer.self,             // ✅ Added in v4.6
                RecurringTransfer.self,    // ✅ Added in v4.6
                BalanceAnchor.self,        // ✅ Added in v4.7
                Household.self,            // ✅ Added in v4.8
                HouseholdMember.self,      // ✅ Added in v4.8
                AssistantMessage.self,     // ✅ Added in v5.1
                RecurringPaymentLog.self,  // ✅ Added in v5.3 (was missing from recovery in v5.3 — fixed in v5.4)
                Vendor.self,               // ✅ Added in v5.4 for Bills feature
                Bill.self,                 // ✅ Added in v5.4 for Bills feature
                BillPayment.self,          // ✅ Added in v5.4 for Bills feature
                PartnerAllocation.self,    // ✅ Added in v5.5 for tax prep
                DepreciableAsset.self,     // ✅ Added in v5.5 for depreciation tracking
                TaxCarryforward.self,      // ✅ Added in v5.5 for carryforward register
                EntityJurisdiction.self,   // ✅ Added in v5.6 for jurisdiction tracking
                DebtAcceleratorPlan.self,  // ✅ Added in v5.7 for Debt Accelerator
                ScheduledPayment.self,     // ✅ Added in v5.7 for Debt Accelerator
                LinkedCard.self,           // ✅ Added in v5.8 for card-to-account linking
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
                Transfer.self,             // ✅ Added in v4.6 for Move Money feature
                RecurringTransfer.self,    // ✅ Added in v4.6 for recurring transfers
                BalanceAnchor.self,        // ✅ Added in v4.7 for reconciliation
                Household.self,            // ✅ Added in v4.8 for household sharing
                HouseholdMember.self,      // ✅ Added in v4.8 for household sharing
                AssistantMessage.self,     // ✅ Added in v5.1 for My Assistant
                RecurringPaymentLog.self,  // ✅ Added in v5.3 for payment tracking
                Vendor.self,               // ✅ Added in v5.4 for Bills feature
                Bill.self,                 // ✅ Added in v5.4 for Bills feature
                BillPayment.self,          // ✅ Added in v5.4 for Bills feature
                PartnerAllocation.self,    // ✅ Added in v5.5 for tax prep
                DepreciableAsset.self,     // ✅ Added in v5.5 for depreciation tracking
                TaxCarryforward.self,      // ✅ Added in v5.5 for carryforward register
                EntityJurisdiction.self,   // ✅ Added in v5.6 for jurisdiction tracking
                DebtAcceleratorPlan.self,  // ✅ Added in v5.7 for Debt Accelerator
                ScheduledPayment.self,     // ✅ Added in v5.7 for Debt Accelerator
                LinkedCard.self,           // ✅ Added in v5.8 for card-to-account linking
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
