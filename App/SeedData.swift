//  SeedData.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.7 — isBusiness, taxTreatment, and taxOwner classification for all categories
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.7:
//  ✅ ADDED: DefaultCategory.isBusiness — true for all business expense/income categories
//  ✅ ADDED: DefaultCategory.taxTreatment — correct TaxTreatment for all income categories
//  ✅ ADDED: DefaultCategory.taxOwner — .primary for all defaults (user is sole earner)
//  ✅ UPDATED: All 33 DefaultCategory entries annotated with isBusiness + taxTreatment
//             Business expenses → isBusiness: true
//             Personal expenses → isBusiness: false
//             SE/gig income     → taxTreatment: .selfEmployment,    isBusiness: true
//             Salary/Wages      → taxTreatment: .w2WithholdingPaid, isBusiness: false
//             Investment Income → taxTreatment: .passiveIncome,     isBusiness: false
//             Refunds           → taxTreatment: .taxExempt,         isBusiness: false
//  ✅ UPDATED: seedDefaultCategories() passes isBusiness/taxTreatment/taxOwner to Category init
//  ✅ UPDATED: static let version = "2.7" (new installs get fully classified categories)
//  ✅ ADDED: migrateCategories() v2.7 block — back-fills isBusiness and taxTreatment
//            for existing users who installed before v2.7.
//            Guarded by UserDefaults key — runs exactly once per device.
//  ✅ UPDATED: Analytics helpers use isBusiness flag instead of name-based heuristics
//  ✅ UPDATED: Color reference comment updated with isBusiness and taxTreatment columns
//
//  CHANGES v2.6:
//  ✅ Added Gas category (fuelpump.fill, orange, tax deductible)
//  ✅ migrateCategories() adds missing default categories for existing users
//
//  CHANGES v2.5:
//  ✅ migrateCategories() removes duplicate categories
//
//  CHANGES v2.4:
//  ✅ migrateCategories() — "doc.badge.fill" -> "signature" icon migration
//
//  CHANGES v2.3:
//  ✅ FIXED: "doc.badge.fill" -> "signature" for Contract Work category
//
//  CHANGES v2.2:
//  ✅ More vibrant, visually distinct colors for each category
//
//  MODEL ASSUMPTIONS:
//  - Category model v2.2+: name, icon, colorHex, isDefault, isIncome, isTaxDeductible,
//    isBusiness, taxTreatment, taxOwner, estimatedWithholdingRate
//

import SwiftData
import Foundation

@MainActor
struct SeedData {

    // MARK: - Version Management

    static let version = "2.7"

    private static let versionKey           = "com.finchandpoppy.flo.seeddata.version"
    private static let taxTreatmentMigrationKey = "com.finchandpoppy.flo.seeddata.taxtreatmentv27"

    private static var seededVersion: String? {
        get { UserDefaults.standard.string(forKey: versionKey) }
        set { UserDefaults.standard.set(newValue, forKey: versionKey) }
    }

    // MARK: - Seed Errors

    enum SeedError: LocalizedError {
        case fetchFailed(Error)
        case saveFailed(Error)
        case contextInvalid
        case migrationFailed(String)

        var errorDescription: String? {
            switch self {
            case .fetchFailed(let e):    return "Failed to fetch existing categories: \(e.localizedDescription)"
            case .saveFailed(let e):     return "Failed to save seed data: \(e.localizedDescription)"
            case .contextInvalid:        return "Invalid ModelContext provided"
            case .migrationFailed(let m): return "Migration failed: \(m)"
            }
        }
    }

    // MARK: - Default Category Configuration (v2.7 — added isBusiness, taxTreatment, taxOwner)

    private struct DefaultCategory {
        let name: String
        let icon: String
        let colorHex: String
        let isIncome: Bool
        let isTaxDeductible: Bool
        let sortOrder: Int
        // v2.7 new fields
        let isBusiness: Bool
        let taxTreatment: TaxTreatment  // meaningful for income categories; .selfEmployment for expenses
        let taxOwner: TaxOwner          // .primary for all defaults
    }

    // MARK: - Predefined Categories (v2.7 — fully classified)
    //
    // COLOR PALETTE — each category has a DISTINCT color:
    // Teal: 14B8A6 (brand)  Green: 22C55E, 10B981, 84CC16
    // Blue: 3B82F6, 0EA5E9, 06B6D4  Purple: 8B5CF6, A855F7, 7C3AED
    // Indigo: 6366F1, 4F46E5  Pink: EC4899, F472B6  Rose: F43F5E, FB7185
    // Red: EF4444, DC2626  Orange: F97316, EA580C  Amber: F59E0B, D97706
    // Yellow: EAB308  Slate: 64748B, 475569
    //

    private static let defaults: [DefaultCategory] = [

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Business Expense Categories (isBusiness: true, tax deductible)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        DefaultCategory(
            name: "Office Supplies",
            icon: "pencil.and.ruler.fill",
            colorHex: "F59E0B",  // Amber
            isIncome: false, isTaxDeductible: true, sortOrder: 1,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Software & Subscriptions",
            icon: "app.badge.fill",
            colorHex: "8B5CF6",  // Purple
            isIncome: false, isTaxDeductible: true, sortOrder: 2,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Professional Services",
            icon: "briefcase.fill",
            colorHex: "3B82F6",  // Blue
            isIncome: false, isTaxDeductible: true, sortOrder: 3,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Marketing & Advertising",
            icon: "megaphone.fill",
            colorHex: "EC4899",  // Pink
            isIncome: false, isTaxDeductible: true, sortOrder: 4,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Business Travel",
            icon: "airplane",
            colorHex: "06B6D4",  // Cyan
            isIncome: false, isTaxDeductible: true, sortOrder: 5,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Meals & Entertainment (Business)",
            icon: "fork.knife",
            colorHex: "F97316",  // Orange
            isIncome: false, isTaxDeductible: true, sortOrder: 6,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Education & Training",
            icon: "book.fill",
            colorHex: "6366F1",  // Indigo
            isIncome: false, isTaxDeductible: true, sortOrder: 7,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Equipment & Tools",
            icon: "wrench.and.screwdriver.fill",
            colorHex: "64748B",  // Slate
            isIncome: false, isTaxDeductible: true, sortOrder: 8,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Internet & Phone (Business)",
            icon: "wifi",
            colorHex: "0EA5E9",  // Sky blue
            isIncome: false, isTaxDeductible: true, sortOrder: 9,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Insurance (Business)",
            icon: "shield.lefthalf.filled",
            colorHex: "10B981",  // Emerald
            isIncome: false, isTaxDeductible: true, sortOrder: 10,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Rent/Lease (Business)",
            icon: "building.2.fill",
            colorHex: "7C3AED",  // Violet
            isIncome: false, isTaxDeductible: true, sortOrder: 11,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Utilities (Business)",
            icon: "bolt.fill",
            colorHex: "EAB308",  // Yellow
            isIncome: false, isTaxDeductible: true, sortOrder: 12,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Contract Labor",
            icon: "person.2.fill",
            colorHex: "14B8A6",  // Teal (brand)
            isIncome: false, isTaxDeductible: true, sortOrder: 13,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Bank Fees & Interest",
            icon: "building.columns.fill",
            colorHex: "EF4444",  // Red
            isIncome: false, isTaxDeductible: true, sortOrder: 14,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Legal & Accounting",
            icon: "doc.text.fill",
            colorHex: "475569",  // Slate dark
            isIncome: false, isTaxDeductible: true, sortOrder: 15,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Gas",
            icon: "fuelpump.fill",
            colorHex: "F97316",  // Orange (added v2.6)
            isIncome: false, isTaxDeductible: true, sortOrder: 16,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Personal Expense Categories (isBusiness: false, not deductible)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        DefaultCategory(
            name: "Groceries",
            icon: "cart.fill",
            colorHex: "22C55E",  // Green
            isIncome: false, isTaxDeductible: false, sortOrder: 101,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Dining Out",
            icon: "fork.knife.circle.fill",
            colorHex: "F97316",  // Orange
            isIncome: false, isTaxDeductible: false, sortOrder: 102,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Transportation",
            icon: "car.fill",
            colorHex: "3B82F6",  // Blue
            isIncome: false, isTaxDeductible: false, sortOrder: 103,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Housing",
            icon: "house.fill",
            colorHex: "8B5CF6",  // Purple
            isIncome: false, isTaxDeductible: false, sortOrder: 104,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Utilities (Personal)",
            icon: "lightbulb.fill",
            colorHex: "EAB308",  // Yellow
            isIncome: false, isTaxDeductible: false, sortOrder: 105,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Healthcare",
            icon: "cross.case.fill",
            colorHex: "EF4444",  // Red
            isIncome: false, isTaxDeductible: false, sortOrder: 106,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Entertainment",
            icon: "tv.fill",
            colorHex: "A855F7",  // Fuchsia
            isIncome: false, isTaxDeductible: false, sortOrder: 107,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Shopping",
            icon: "bag.fill",
            colorHex: "EC4899",  // Pink
            isIncome: false, isTaxDeductible: false, sortOrder: 108,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Personal Care",
            icon: "sparkles",
            colorHex: "F472B6",  // Pink light
            isIncome: false, isTaxDeductible: false, sortOrder: 109,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Gifts & Donations",
            icon: "gift.fill",
            colorHex: "F43F5E",  // Rose
            isIncome: false, isTaxDeductible: false, sortOrder: 110,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary
        ),

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Income Categories (v2.7 — taxTreatment and isBusiness set correctly)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // SE income (gig / 1099 / self-employed) — subject to SE tax
        DefaultCategory(
            name: "Client Payments",
            icon: "dollarsign.circle.fill",
            colorHex: "10B981",  // Emerald
            isIncome: true, isTaxDeductible: false, sortOrder: 201,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Freelance Income",
            icon: "laptopcomputer",
            colorHex: "14B8A6",  // Teal (brand)
            isIncome: true, isTaxDeductible: false, sortOrder: 202,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Contract Work",
            icon: "signature",   // FIXED v2.3: was "doc.badge.fill" (invalid SF Symbol)
            colorHex: "3B82F6",  // Blue
            isIncome: true, isTaxDeductible: false, sortOrder: 203,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),
        DefaultCategory(
            name: "Side Gig",
            icon: "star.fill",
            colorHex: "F59E0B",  // Amber
            isIncome: true, isTaxDeductible: false, sortOrder: 206,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary
        ),

        // W-2 income — employer withholds; no SE tax
        // Salary/Wages is personal (isBusiness: false) — primary earner W-2 job
        DefaultCategory(
            name: "Salary/Wages",
            icon: "banknote.fill",
            colorHex: "22C55E",  // Green
            isIncome: true, isTaxDeductible: false, sortOrder: 204,
            isBusiness: false, taxTreatment: .w2WithholdingPaid, taxOwner: .primary
        ),

        // Passive income — no SE tax, no withholding
        DefaultCategory(
            name: "Investment Income",
            icon: "chart.line.uptrend.xyaxis",
            colorHex: "6366F1",  // Indigo
            isIncome: true, isTaxDeductible: false, sortOrder: 205,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary
        ),

        // Tax exempt — excluded from all calculations
        DefaultCategory(
            name: "Refunds & Reimbursements",
            icon: "arrow.uturn.backward.circle.fill",
            colorHex: "06B6D4",  // Cyan
            isIncome: true, isTaxDeductible: false, sortOrder: 207,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary
        ),
    ]

    // MARK: - Public Seeding

    /// Seeds default categories if none exist. Idempotent — safe to call multiple times.
    static func seedDefaultCategories(in context: ModelContext) -> Result<Int, SeedError> {
        do {
            if let seededVer = seededVersion, seededVer != version {
                print("⚠️ SeedData: Version mismatch (seeded: \(seededVer), current: \(version))")
            }

            let existingCount = try context.fetchCount(FetchDescriptor<Category>())
            guard existingCount == 0 else {
                return .success(0)  // Already seeded
            }

            for dc in defaults {
                let category = Category(
                    name:          dc.name,
                    icon:          dc.icon,
                    colorHex:      dc.colorHex,
                    isDefault:     true,
                    isIncome:      dc.isIncome,
                    isTaxDeductible: dc.isTaxDeductible,
                    isBusiness:    dc.isBusiness,     // v2.7
                    taxTreatment:  dc.taxTreatment,    // v2.7
                    taxOwner:      dc.taxOwner          // v2.7
                )
                context.insert(category)
            }

            try context.save()
            seededVersion = version
            return .success(defaults.count)

        } catch {
            let descriptor = String(describing: error)
            return descriptor.contains("fetch") || descriptor.contains("Fetch")
                ? .failure(.fetchFailed(error))
                : .failure(.saveFailed(error))
        }
    }

    /// Async variant for use in Task contexts
    static func seedDefaultCategoriesAsync(in context: ModelContext) async -> Result<Int, SeedError> {
        return seedDefaultCategories(in: context)
    }

    /// Checks if seeding is needed without performing it
    static func needsSeeding(in context: ModelContext) -> Bool {
        do {
            return try context.fetchCount(FetchDescriptor<Category>()) == 0
        } catch {
            return true
        }
    }

    // MARK: - Testing Utilities

    #if DEBUG
    static func clearAllCategories(in context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<Category>())
        for category in categories { context.delete(category) }
        try context.save()
        seededVersion = nil
        UserDefaults.standard.removeObject(forKey: taxTreatmentMigrationKey)
        print("🧹 SeedData: Cleared \(categories.count) categories for testing")
    }
    #endif

    // MARK: - Migration

    /// Migrates existing categories to fix known issues. Call on every app launch.
    ///
    /// v2.4: "doc.badge.fill" → "signature" (invalid SF Symbol fix)
    /// v2.5: Removes duplicate categories (keeps first)
    /// v2.6: Adds missing "Gas" category
    /// v2.7: Back-fills isBusiness and taxTreatment for pre-v2.7 installs (runs once)
    static func migrateCategories(in context: ModelContext) {
        let iconMigrations: [String: String] = [
            "doc.badge.fill": "signature"
        ]

        let missingCategoryChecks: [(name: String, icon: String, colorHex: String, isIncome: Bool, isTaxDeductible: Bool, isBusiness: Bool, taxTreatment: TaxTreatment)] = [
            ("Gas", "fuelpump.fill", "F97316", false, true, true, .selfEmployment)
        ]

        do {
            let categories = try context.fetch(FetchDescriptor<Category>())
            var migratedCount    = 0
            var duplicatesRemoved = 0
            var categoriesAdded  = 0

            // ── v2.4/v2.5: Icon fix + duplicate removal ───────────────
            var seenNames: Set<String> = []
            var toDelete: [Category]  = []

            for category in categories {
                if let newIcon = iconMigrations[category.icon] {
                    category.icon = newIcon
                    migratedCount += 1
                    print("🔄 SeedData: Fixed icon for '\(category.name)'")
                }
                if seenNames.contains(category.name) {
                    toDelete.append(category)
                    duplicatesRemoved += 1
                } else {
                    seenNames.insert(category.name)
                }
            }
            for cat in toDelete {
                print("🗑️ SeedData: Removing duplicate '\(cat.name)'")
                context.delete(cat)
            }

            // ── v2.6: Add missing default categories ──────────────────
            for check in missingCategoryChecks {
                if !seenNames.contains(check.name) {
                    let newCat = Category(
                        name:            check.name,
                        icon:            check.icon,
                        colorHex:        check.colorHex,
                        isDefault:       true,
                        isIncome:        check.isIncome,
                        isTaxDeductible: check.isTaxDeductible,
                        isBusiness:      check.isBusiness,
                        taxTreatment:    check.taxTreatment,
                        taxOwner:        .primary
                    )
                    context.insert(newCat)
                    categoriesAdded += 1
                    print("➕ SeedData: Added missing category '\(check.name)'")
                }
            }

            // ── v2.7: Back-fill isBusiness and taxTreatment ───────────
            //
            // Only runs once per device (guarded by UserDefaults flag).
            // Uses category name matching against the canonical defaults list so the
            // logic mirrors what new installs receive via seedDefaultCategories().
            //
            // Unknown categories (user-created) are left untouched.
            if !UserDefaults.standard.bool(forKey: taxTreatmentMigrationKey) {

                // Build lookup maps from the canonical defaults list
                var businessByName: [String: Bool]        = [:]
                var treatmentByName: [String: TaxTreatment] = [:]

                for dc in defaults {
                    businessByName[dc.name]  = dc.isBusiness
                    treatmentByName[dc.name] = dc.taxTreatment
                }

                // Re-fetch after potential deletes above
                let postDeleteCategories = try context.fetch(FetchDescriptor<Category>())
                var taxMigrated = 0

                for category in postDeleteCategories {
                    var changed = false

                    // Only update if the category matches a known default name.
                    // User-created categories keep whatever the user set (or the default false/SE).
                    if let isBiz = businessByName[category.name] {
                        if category.isBusiness != isBiz {
                            category.isBusiness = isBiz
                            changed = true
                        }
                    }
                    if let treatment = treatmentByName[category.name] {
                        if category.taxTreatment != treatment {
                            category.taxTreatment = treatment
                            changed = true
                        }
                    }

                    if changed {
                        taxMigrated += 1
                        print("🔄 SeedData v2.7: Updated classification for '\(category.name)'")
                    }
                }

                // Mark migration as done regardless of count
                UserDefaults.standard.set(true, forKey: taxTreatmentMigrationKey)

                if taxMigrated > 0 {
                    migratedCount += taxMigrated
                    print("✅ SeedData v2.7: Back-filled \(taxMigrated) category classification(s)")
                } else {
                    print("✅ SeedData v2.7: Tax treatment migration — no changes needed")
                }
            }

            // ── Save if anything changed ──────────────────────────────
            if migratedCount > 0 || duplicatesRemoved > 0 || categoriesAdded > 0 {
                try context.save()
                if duplicatesRemoved > 0 { print("✅ SeedData: Removed \(duplicatesRemoved) duplicate(s)") }
                if categoriesAdded  > 0 { print("✅ SeedData: Added \(categoriesAdded) missing category(ies)") }
            }

        } catch {
            print("❌ SeedData: Migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Analytics Helpers (v2.7 — uses isBusiness flag)

    static var businessExpenseCount: Int {
        defaults.filter { !$0.isIncome && $0.isBusiness }.count
    }

    static var personalExpenseCount: Int {
        defaults.filter { !$0.isIncome && !$0.isBusiness }.count
    }

    static var incomeCount: Int {
        defaults.filter { $0.isIncome }.count
    }

    static var taxDeductibleCount: Int {
        defaults.filter { $0.isTaxDeductible }.count
    }

    static var selfEmploymentIncomeCount: Int {
        defaults.filter { $0.isIncome && $0.taxTreatment == .selfEmployment }.count
    }

    static var w2IncomeCount: Int {
        defaults.filter { $0.isIncome && $0.taxTreatment == .w2WithholdingPaid }.count
    }

    static var passiveIncomeCount: Int {
        defaults.filter { $0.isIncome && $0.taxTreatment == .passiveIncome }.count
    }

    static var taxExemptIncomeCount: Int {
        defaults.filter { $0.isIncome && $0.taxTreatment == .taxExempt }.count
    }
}

// MARK: - Color + Classification Reference
/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ FLO CATEGORY CLASSIFICATION v2.7                                             │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ BUSINESS EXPENSES (isBusiness: true, taxDeductible: true)                    │
 │ ├─ Office Supplies          F59E0B  Amber                                     │
 │ ├─ Software & Subscriptions 8B5CF6  Purple                                   │
 │ ├─ Professional Services    3B82F6  Blue                                      │
 │ ├─ Marketing & Advertising  EC4899  Pink                                      │
 │ ├─ Business Travel          06B6D4  Cyan                                      │
 │ ├─ Meals & Entertainment    F97316  Orange                                    │
 │ ├─ Education & Training     6366F1  Indigo                                    │
 │ ├─ Equipment & Tools        64748B  Slate                                     │
 │ ├─ Internet & Phone (Biz)   0EA5E9  Sky                                       │
 │ ├─ Insurance (Business)     10B981  Emerald                                   │
 │ ├─ Rent/Lease (Business)    7C3AED  Violet                                    │
 │ ├─ Utilities (Business)     EAB308  Yellow                                    │
 │ ├─ Contract Labor           14B8A6  Teal (brand)                              │
 │ ├─ Bank Fees & Interest     EF4444  Red                                       │
 │ ├─ Legal & Accounting       475569  Slate Dark                                │
 │ └─ Gas                      F97316  Orange                                    │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ PERSONAL EXPENSES (isBusiness: false, taxDeductible: false)                  │
 │ ├─ Groceries                22C55E  Green                                     │
 │ ├─ Dining Out               F97316  Orange                                    │
 │ ├─ Transportation           3B82F6  Blue                                      │
 │ ├─ Housing                  8B5CF6  Purple                                    │
 │ ├─ Utilities (Personal)     EAB308  Yellow                                    │
 │ ├─ Healthcare               EF4444  Red                                       │
 │ ├─ Entertainment            A855F7  Fuchsia                                   │
 │ ├─ Shopping                 EC4899  Pink                                      │
 │ ├─ Personal Care            F472B6  Pink Light                                │
 │ └─ Gifts & Donations        F43F5E  Rose                                      │
 ├──────────────────────────────────────────────────────────────────────────────┤
 │ INCOME CATEGORIES (taxTreatment / isBusiness)                                │
 │ ├─ Client Payments          10B981  Emerald   selfEmployment  / business      │
 │ ├─ Freelance Income         14B8A6  Teal      selfEmployment  / business      │
 │ ├─ Contract Work            3B82F6  Blue      selfEmployment  / business      │
 │ ├─ Side Gig                 F59E0B  Amber     selfEmployment  / business      │
 │ ├─ Salary/Wages             22C55E  Green     w2WithholdingPaid / personal    │
 │ ├─ Investment Income        6366F1  Indigo    passiveIncome   / personal      │
 │ └─ Refunds & Reimb.         06B6D4  Cyan      taxExempt       / personal      │
 └──────────────────────────────────────────────────────────────────────────────┘
 */
