//  SeedData.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.6 - Added Gas category
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.6:
//  ✅ Added "Gas" category to defaults (fuelpump.fill, orange, tax deductible)
//  ✅ migrateCategories() now adds missing default categories for existing users
//
//  CHANGES FROM v2.5:
//  ✅ migrateCategories() now removes duplicate categories
//  ✅ Keeps the first category, deletes subsequent duplicates with same name
//
//  CHANGES FROM v2.4:
//  ✅ Added migrateCategories() to fix icons in existing data
//  ✅ Migrates "doc.badge.fill" -> "signature" for existing users
//
//  CHANGES FROM v2.3:
//  ✅ FIXED: Changed "doc.badge.fill" to "signature" for Contract Work category
//  ✅ "doc.badge.fill" is not a valid SF Symbol
//
//  CHANGES FROM v2.2:
//  ✅ More vibrant, visually distinct colors for each category
//  ✅ Better contrast between similar categories
//  ✅ Improved icon selections for clarity
//  ✅ Colors now match the colorful aesthetic of MoreView
//
//  MODEL ASSUMPTIONS:
//  - Category model must have: name, icon, colorHex, isDefault, isIncome, isTaxDeductible
//  - Optional properties that enhance functionality: sortOrder (Int)
//  - Business/personal classification is encoded in category names
//
//  TAX DEDUCTIBILITY NOTES:
//  Categories marked as tax deductible are commonly deductible for self-employed
//  individuals. Users should consult a tax professional for specific situations.
//

import SwiftData
import Foundation

@MainActor
struct SeedData {
    
    // MARK: - Version Management
    
    static let version = "2.4"
    
    private static let versionKey = "com.finchandpoppy.flo.seeddata.version"
    
    /// Get the currently seeded version from UserDefaults
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
            case .fetchFailed(let error):
                return "Failed to fetch existing categories: \(error.localizedDescription)"
            case .saveFailed(let error):
                return "Failed to save seed data: \(error.localizedDescription)"
            case .contextInvalid:
                return "Invalid ModelContext provided"
            case .migrationFailed(let message):
                return "Migration failed: \(message)"
            }
        }
    }
    
    // MARK: - Default Category Configuration
    
    private struct DefaultCategory {
        let name: String
        let icon: String
        let colorHex: String
        let isIncome: Bool
        let isTaxDeductible: Bool
        let sortOrder: Int
    }
    
    // MARK: - Predefined Categories (v2.2 - Enhanced Colors)
    //
    // COLOR PALETTE - Each category has a DISTINCT color:
    // Teal:     14B8A6 (brand primary)
    // Green:    22C55E, 10B981, 84CC16
    // Blue:     3B82F6, 0EA5E9, 06B6D4
    // Purple:   8B5CF6, A855F7, 7C3AED
    // Indigo:   6366F1, 4F46E5
    // Pink:     EC4899, F472B6
    // Rose:     F43F5E, FB7185
    // Red:      EF4444, DC2626
    // Orange:   F97316, EA580C
    // Amber:    F59E0B, D97706
    // Yellow:   EAB308
    // Slate:    64748B, 475569
    //
    
    private static let defaults: [DefaultCategory] = [
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Business Expense Categories (Tax Deductible)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        DefaultCategory(
            name: "Office Supplies",
            icon: "pencil.and.ruler.fill",
            colorHex: "F59E0B",  // Amber - stands out
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 1
        ),
        DefaultCategory(
            name: "Software & Subscriptions",
            icon: "app.badge.fill",
            colorHex: "8B5CF6",  // Purple
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 2
        ),
        DefaultCategory(
            name: "Professional Services",
            icon: "briefcase.fill",
            colorHex: "3B82F6",  // Blue
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 3
        ),
        DefaultCategory(
            name: "Marketing & Advertising",
            icon: "megaphone.fill",
            colorHex: "EC4899",  // Pink
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 4
        ),
        DefaultCategory(
            name: "Business Travel",
            icon: "airplane",
            colorHex: "06B6D4",  // Cyan
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 5
        ),
        DefaultCategory(
            name: "Meals & Entertainment (Business)",
            icon: "fork.knife",
            colorHex: "F97316",  // Orange
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 6
        ),
        DefaultCategory(
            name: "Education & Training",
            icon: "book.fill",
            colorHex: "6366F1",  // Indigo
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 7
        ),
        DefaultCategory(
            name: "Equipment & Tools",
            icon: "wrench.and.screwdriver.fill",
            colorHex: "64748B",  // Slate
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 8
        ),
        DefaultCategory(
            name: "Internet & Phone (Business)",
            icon: "wifi",
            colorHex: "0EA5E9",  // Sky blue
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 9
        ),
        DefaultCategory(
            name: "Insurance (Business)",
            icon: "shield.lefthalf.filled",
            colorHex: "10B981",  // Emerald
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 10
        ),
        DefaultCategory(
            name: "Rent/Lease (Business)",
            icon: "building.2.fill",
            colorHex: "7C3AED",  // Violet
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 11
        ),
        DefaultCategory(
            name: "Utilities (Business)",
            icon: "bolt.fill",
            colorHex: "EAB308",  // Yellow
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 12
        ),
        DefaultCategory(
            name: "Contract Labor",
            icon: "person.2.fill",
            colorHex: "14B8A6",  // Teal (brand)
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 13
        ),
        DefaultCategory(
            name: "Bank Fees & Interest",
            icon: "building.columns.fill",
            colorHex: "EF4444",  // Red
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 14
        ),
        DefaultCategory(
            name: "Legal & Accounting",
            icon: "doc.text.fill",
            colorHex: "475569",  // Slate dark
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 15
        ),
        DefaultCategory(
            name: "Gas",
            icon: "fuelpump.fill",
            colorHex: "F97316",  // Orange
            isIncome: false,
            isTaxDeductible: true,
            sortOrder: 16
        ),
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Personal Expense Categories
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        DefaultCategory(
            name: "Groceries",
            icon: "cart.fill",
            colorHex: "22C55E",  // Green
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 101
        ),
        DefaultCategory(
            name: "Dining Out",
            icon: "fork.knife.circle.fill",
            colorHex: "F97316",  // Orange
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 102
        ),
        DefaultCategory(
            name: "Transportation",
            icon: "car.fill",
            colorHex: "3B82F6",  // Blue
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 103
        ),
        DefaultCategory(
            name: "Housing",
            icon: "house.fill",
            colorHex: "8B5CF6",  // Purple
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 104
        ),
        DefaultCategory(
            name: "Utilities (Personal)",
            icon: "lightbulb.fill",
            colorHex: "EAB308",  // Yellow
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 105
        ),
        DefaultCategory(
            name: "Healthcare",
            icon: "cross.case.fill",
            colorHex: "EF4444",  // Red
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 106
        ),
        DefaultCategory(
            name: "Entertainment",
            icon: "tv.fill",
            colorHex: "A855F7",  // Fuchsia
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 107
        ),
        DefaultCategory(
            name: "Shopping",
            icon: "bag.fill",
            colorHex: "EC4899",  // Pink
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 108
        ),
        DefaultCategory(
            name: "Personal Care",
            icon: "sparkles",
            colorHex: "F472B6",  // Pink light
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 109
        ),
        DefaultCategory(
            name: "Gifts & Donations",
            icon: "gift.fill",
            colorHex: "F43F5E",  // Rose
            isIncome: false,
            isTaxDeductible: false,
            sortOrder: 110
        ),
        
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Income Categories
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        
        DefaultCategory(
            name: "Client Payments",
            icon: "dollarsign.circle.fill",
            colorHex: "10B981",  // Emerald
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 201
        ),
        DefaultCategory(
            name: "Freelance Income",
            icon: "laptopcomputer",
            colorHex: "14B8A6",  // Teal (brand)
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 202
        ),
        DefaultCategory(
            name: "Contract Work",
            icon: "signature",  // FIXED: Was "doc.badge.fill" (invalid)
            colorHex: "3B82F6",  // Blue
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 203
        ),
        DefaultCategory(
            name: "Salary/Wages",
            icon: "banknote.fill",
            colorHex: "22C55E",  // Green
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 204
        ),
        DefaultCategory(
            name: "Investment Income",
            icon: "chart.line.uptrend.xyaxis",
            colorHex: "6366F1",  // Indigo
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 205
        ),
        DefaultCategory(
            name: "Side Gig",
            icon: "star.fill",
            colorHex: "F59E0B",  // Amber
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 206
        ),
        DefaultCategory(
            name: "Refunds & Reimbursements",
            icon: "arrow.uturn.backward.circle.fill",
            colorHex: "06B6D4",  // Cyan
            isIncome: true,
            isTaxDeductible: false,
            sortOrder: 207
        ),
    ]
    
    // MARK: - Public Seeding Methods
    
    /// Seeds default categories if needed, with migration support.
    /// Idempotent - safe to call multiple times.
    ///
    /// - Parameter context: The ModelContext to seed
    /// - Returns: Result with count of categories seeded or error
    static func seedDefaultCategories(in context: ModelContext) -> Result<Int, SeedError> {
        do {
            // Check if migration is needed
            if let seededVer = seededVersion, seededVer != version {
                // Version mismatch - could migrate here in future
                print("⚠️ SeedData: Version mismatch (seeded: \(seededVer), current: \(version))")
            }
            
            // Check if categories already exist
            let fetchDescriptor = FetchDescriptor<Category>()
            let existingCount = try context.fetchCount(fetchDescriptor)
            
            guard existingCount == 0 else {
                // Already seeded - return success with 0 count
                return .success(0)
            }
            
            // Insert all default categories
            for defaultCategory in defaults {
                let category = Category(
                    name: defaultCategory.name,
                    icon: defaultCategory.icon,
                    colorHex: defaultCategory.colorHex,
                    isDefault: true,
                    isIncome: defaultCategory.isIncome,
                    isTaxDeductible: defaultCategory.isTaxDeductible
                )
                
                context.insert(category)
            }
            
            // Save all changes
            try context.save()
            
            // Record seeded version
            seededVersion = version
            
            return .success(defaults.count)
            
        } catch {
            let descriptor = String(describing: error)
            
            if descriptor.contains("fetch") || descriptor.contains("Fetch") {
                return .failure(.fetchFailed(error))
            } else {
                return .failure(.saveFailed(error))
            }
        }
    }
    
    /// Async variant for use in Task contexts
    static func seedDefaultCategoriesAsync(in context: ModelContext) async -> Result<Int, SeedError> {
        return seedDefaultCategories(in: context)
    }
    
    /// Checks if seeding is needed without performing it
    static func needsSeeding(in context: ModelContext) -> Bool {
        do {
            let fetchDescriptor = FetchDescriptor<Category>()
            let count = try context.fetchCount(fetchDescriptor)
            return count == 0
        } catch {
            return true
        }
    }
    
    // MARK: - Testing Utilities
    
    #if DEBUG
    /// Clears all categories from the database. FOR TESTING ONLY.
    static func clearAllCategories(in context: ModelContext) throws {
        let fetchDescriptor = FetchDescriptor<Category>()
        let categories = try context.fetch(fetchDescriptor)
        
        for category in categories {
            context.delete(category)
        }
        
        try context.save()
        seededVersion = nil
        
        print("🧹 SeedData: Cleared \(categories.count) categories for testing")
    }
    #endif
    
    // MARK: - Migration Functions
    
    /// Migrates existing categories to fix known issues.
    /// Call this on app launch to ensure data is up to date.
    ///
    /// Currently fixes:
    /// - "doc.badge.fill" -> "signature" (invalid SF Symbol)
    /// - Removes duplicate categories (keeps the first one)
    /// - Adds missing default categories (e.g., "Gas")
    static func migrateCategories(in context: ModelContext) {
        // Icon migrations: old invalid icon -> new valid icon
        let iconMigrations: [String: String] = [
            "doc.badge.fill": "signature"  // Contract Work category
        ]
        
        // Categories that may be missing from older installs
        let missingCategoryChecks: [(name: String, icon: String, colorHex: String, isIncome: Bool, isTaxDeductible: Bool)] = [
            ("Gas", "fuelpump.fill", "F97316", false, true)
        ]
        
        do {
            let fetchDescriptor = FetchDescriptor<Category>()
            let categories = try context.fetch(fetchDescriptor)
            
            var migratedCount = 0
            var duplicatesRemoved = 0
            var categoriesAdded = 0
            
            // Track seen category names to detect duplicates
            var seenNames: Set<String> = []
            var categoriesToDelete: [Category] = []
            
            for category in categories {
                // Fix invalid icons
                if let newIcon = iconMigrations[category.icon] {
                    let oldIcon = category.icon
                    category.icon = newIcon
                    migratedCount += 1
                    print("🔄 SeedData: Migrated '\(category.name)' icon: \(oldIcon) -> \(newIcon)")
                }
                
                // Check for duplicates
                if seenNames.contains(category.name) {
                    categoriesToDelete.append(category)
                    duplicatesRemoved += 1
                } else {
                    seenNames.insert(category.name)
                }
            }
            
            // Delete duplicate categories
            for category in categoriesToDelete {
                print("🗑️ SeedData: Removing duplicate category: '\(category.name)'")
                context.delete(category)
            }
            
            // Add missing default categories
            for check in missingCategoryChecks {
                if !seenNames.contains(check.name) {
                    let newCategory = Category(
                        name: check.name,
                        icon: check.icon,
                        colorHex: check.colorHex,
                        isDefault: true,
                        isIncome: check.isIncome,
                        isTaxDeductible: check.isTaxDeductible
                    )
                    context.insert(newCategory)
                    categoriesAdded += 1
                    print("➕ SeedData: Added missing category: '\(check.name)'")
                }
            }
            
            if migratedCount > 0 || duplicatesRemoved > 0 || categoriesAdded > 0 {
                try context.save()
                if migratedCount > 0 {
                    print("✅ SeedData: Migrated \(migratedCount) category icon(s)")
                }
                if duplicatesRemoved > 0 {
                    print("✅ SeedData: Removed \(duplicatesRemoved) duplicate category(ies)")
                }
                if categoriesAdded > 0 {
                    print("✅ SeedData: Added \(categoriesAdded) missing category(ies)")
                }
            }
        } catch {
            print("❌ SeedData: Migration failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Analytics Helpers
    
    static var businessExpenseCount: Int {
        defaults.filter { !$0.isIncome && $0.name.contains("Business") }.count
    }
    
    static var personalExpenseCount: Int {
        defaults.filter { !$0.isIncome && !$0.name.contains("Business") }.count
    }
    
    static var incomeCount: Int {
        defaults.filter { $0.isIncome }.count
    }
    
    static var taxDeductibleCount: Int {
        defaults.filter { $0.isTaxDeductible }.count
    }
}

// MARK: - Color Reference
/*
 ┌─────────────────────────────────────────────────────────────┐
 │ FLO CATEGORY COLOR PALETTE v2.4                             │
 ├─────────────────────────────────────────────────────────────┤
 │ BUSINESS EXPENSES                                           │
 │ ├─ Office Supplies      F59E0B  Amber                       │
 │ ├─ Software             8B5CF6  Purple                      │
 │ ├─ Professional Svc     3B82F6  Blue                        │
 │ ├─ Marketing            EC4899  Pink                        │
 │ ├─ Business Travel      06B6D4  Cyan                        │
 │ ├─ Meals (Business)     F97316  Orange                      │
 │ ├─ Education            6366F1  Indigo                      │
 │ ├─ Equipment            64748B  Slate                       │
 │ ├─ Internet/Phone       0EA5E9  Sky                         │
 │ ├─ Insurance            10B981  Emerald                     │
 │ ├─ Rent/Lease           7C3AED  Violet                      │
 │ ├─ Utilities (Biz)      EAB308  Yellow                      │
 │ ├─ Contract Labor       14B8A6  Teal (brand)                │
 │ ├─ Bank Fees            EF4444  Red                         │
 │ └─ Legal/Accounting     475569  Slate Dark                  │
 ├─────────────────────────────────────────────────────────────┤
 │ PERSONAL EXPENSES                                           │
 │ ├─ Groceries            22C55E  Green                       │
 │ ├─ Dining Out           F97316  Orange                      │
 │ ├─ Transportation       3B82F6  Blue                        │
 │ ├─ Housing              8B5CF6  Purple                      │
 │ ├─ Utilities (Personal) EAB308  Yellow                      │
 │ ├─ Healthcare           EF4444  Red                         │
 │ ├─ Entertainment        A855F7  Fuchsia                     │
 │ ├─ Shopping             EC4899  Pink                        │
 │ ├─ Personal Care        F472B6  Pink Light                  │
 │ └─ Gifts & Donations    F43F5E  Rose                        │
 ├─────────────────────────────────────────────────────────────┤
 │ INCOME                                                      │
 │ ├─ Client Payments      10B981  Emerald                     │
 │ ├─ Freelance Income     14B8A6  Teal (brand)                │
 │ ├─ Contract Work        3B82F6  Blue (icon: signature)      │
 │ ├─ Salary/Wages         22C55E  Green                       │
 │ ├─ Investment Income    6366F1  Indigo                      │
 │ ├─ Side Gig             F59E0B  Amber                       │
 │ └─ Refunds              06B6D4  Cyan                        │
 └─────────────────────────────────────────────────────────────┘
 */
