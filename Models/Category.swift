//  Category.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.1 – Production-ready with correct bidirectional relationships
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Category model with validation, computed properties, and inverse relationships
//

import Foundation
import SwiftData
import SwiftUI

/// A category for organizing transactions, budgets, and recurring transactions.
/// Categories can be marked as default (non-deletable), income/expense, and tax-deductible.
@Model
final class Category {
    
    // MARK: - Identifiers
    @Attribute(.unique) private(set) var id: UUID
    
    // MARK: - Core Properties
    /// Display name for this category.
    var name: String
    
    /// SF Symbol name for icon display.
    var icon: String
    
    /// Hex color code (format: #RRGGBB) for UI theming.
    var colorHex: String
    
    // MARK: - Category Behavior Flags
    /// If true, this category cannot be deleted (e.g., system defaults).
    var isDefault: Bool
    
    /// If true, this category is typically used for income transactions.
    var isIncome: Bool
    
    /// If true, transactions in this category may be tax-deductible.
    var isTaxDeductible: Bool
    
    // MARK: - Relationships
    // NOTE: Category defines the inverse for all "to-many" relationships
    
    /// All transactions using this category.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []
    
    /// All budgets associated with this category.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget] = []
    
    /// All recurring transactions using this category.
    @Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.category)
    var recurringTransactions: [RecurringTransaction] = []
    
    // MARK: - Initialization
    
    init(
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#3B82F6",
        isDefault: Bool = false,
        isIncome: Bool = false,
        isTaxDeductible: Bool = false
    ) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.colorHex = Self.normalizeColorHex(colorHex)
        self.isDefault = isDefault
        self.isIncome = isIncome
        self.isTaxDeductible = isTaxDeductible
    }
    
    // MARK: - Color Normalization

    /// Ensures consistent uppercase hex format with leading #.
    /// Falls back to Tailwind blue-500 (#3B82F6) if invalid.
    private static func normalizeColorHex(_ hex: String) -> String {
        var cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        
        // Remove any existing # symbols
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        
        // Validate 6-character hex format
        guard cleaned.count == 6,
              cleaned.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else {
            return "#3B82F6"
        }
        
        // Add # prefix
        return "#\(cleaned)"
    }
    
    // MARK: - Computed Properties
    
    /// SwiftUI Color object from hex string.
    /// Note: Uses existing Color extension in your project
    var color: Color {
        Color(flowHex: colorHex)
    }
    
    /// Safe display name with fallback.
    var displayName: String {
        name.isEmpty ? "Uncategorized" : name
    }
    
    /// Total number of transactions in this category.
    var transactionCount: Int {
        transactions.count
    }
    
    /// Total number of budgets using this category.
    var budgetCount: Int {
        budgets.count
    }
    
    /// Whether this category is actively being used.
    var isInUse: Bool {
        !transactions.isEmpty || !budgets.isEmpty || !recurringTransactions.isEmpty
    }
}

// MARK: - Protocol Conformances

extension Category: Identifiable { }

extension Category: Equatable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        lhs.id == rhs.id
    }
}

extension Category: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Preview Support

#if DEBUG
extension Category {
    @MainActor static var previewGroceries: Category {
        Category(
            name: "Groceries",
            icon: "cart.fill",
            colorHex: "#10B981",
            isDefault: true,
            isTaxDeductible: false
        )
    }
    
    @MainActor static var previewBusinessExpense: Category {
        Category(
            name: "Business Expenses",
            icon: "briefcase.fill",
            colorHex: "#3B82F6",
            isDefault: false,
            isTaxDeductible: true
        )
    }
    
    @MainActor static var previewIncome: Category {
        Category(
            name: "Freelance Income",
            icon: "dollarsign.circle.fill",
            colorHex: "#10B981",
            isDefault: false,
            isIncome: true
        )
    }
    
    @MainActor static var previewRent: Category {
        Category(
            name: "Rent",
            icon: "house.fill",
            colorHex: "#EF4444",
            isDefault: true,
            isTaxDeductible: false
        )
    }
    
    @MainActor static var previewDefaultCategories: [Category] {
        [
            .previewGroceries,
            .previewRent,
            .previewIncome,
            .previewBusinessExpense
        ]
    }
}
#endif
