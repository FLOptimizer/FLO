//  FLOInvoiceClipApp.swift
//  FLO Invoice Clip
//
//  Version 1.0 - App Clip Invoice Generator
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Lightweight App Clip entry point for quick invoice generation.
//  Users can create and share invoices without installing the full app.
//  Invoked via QR code, NFC tag, or App Clip link.
//
//  APP CLIP CONSTRAINTS:
//  - Must be ≤15MB
//  - 8-hour data retention after last launch
//  - Limited background processing
//  - No in-app purchases
//  - Shared SwiftData container with main app via App Group

import SwiftUI
import SwiftData

@main
struct FLOInvoiceClipApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Invoice.self,
                InvoiceItem.self,
                InvoicePayment.self,
                Client.self,
                Account.self,
                Transaction.self,
            ])

            let config = ModelConfiguration(
                "FLO",
                schema: schema,
                groupContainer: .identifier("group.com.finchandpoppy.flo")
            )

            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            QuickInvoiceView()
                .modelContainer(modelContainer)
        }
    }
}
