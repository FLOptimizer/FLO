//  Category.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 — Add badgeLabel & color aliases to TaxTreatment
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Category model with tax treatment classification for multi-source income support.
//
//  CHANGES IN v2.3:
//  ✅ ADDED: TaxTreatment.badgeLabel — alias for displayName (used by badge views)
//  ✅ ADDED: TaxTreatment.color — alias for badgeColor (used by badge/foreground views)
//  ✅ FIX: Resolves 22 build errors across AddCategoryView, EditCategoryView,
//          TaxSettingsView, and CategoryManagementView
//
//  CHANGES IN v2.2:
//  ✅ ADDED: TaxTreatment enum — controls how income categories affect tax calculations
//  ✅ ADDED: TaxOwner enum — distinguishes primary user, spouse, or joint income
//  ✅ ADDED: isBusiness: Bool — explicit business vs. personal flag for all categories
//  ✅ ADDED: estimatedWithholdingRate: Double? — for W-2 categories, employer withholding %
//  ✅ UPDATED: init() accepts new properties with backward-compatible defaults
//  ✅ UPDATED: Preview categories include all new properties
//  ✅ NOTE: SwiftData handles lightweight migration automatically for these additions
//
//  CHANGES IN v2.1:
//  — Production-ready with correct bidirectional relationships
//
//  SWIFTDATA NOTES:
//  — TaxTreatment and TaxOwner store as String (rawValue) — native SwiftData support
//  — estimatedWithholdingRate is Optional<Double> — stores nil when not applicable
//  — isBusiness is Bool with default false — lightweight migration safe
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Tax Treatment Enum

/// Controls how an income category is handled during tax calculations.
/// Only applies to income categories; expense categories use isTaxDeductible instead.
enum TaxTreatment: String, Codable, CaseIterable {
    
    /// Self-employment / 1099 income.
    /// Subject to SE tax (15.3%) AND federal/state income tax brackets.
    /// Default for freelance, gig, and contract income.
    case selfEmployment = "selfEmployment"
    
    /// W-2 income where employer withholds taxes.
    /// Counted for income tax bracket stacking but excluded from SE tax.
    /// Estimated withholding is credited against quarterly payment due.
    case w2WithholdingPaid = "w2WithholdingPaid"
    
    /// Passive income — rental, dividends, partnership distributions.
    /// Counted for income tax brackets. NOT subject to SE tax.
    case passiveIncome = "passiveIncome"
    
    /// Tax-exempt income — Roth distributions, HSA reimbursements, gifts, insurance payouts.
    /// Completely excluded from all tax calculations.
    case taxExempt = "taxExempt"
    
    // MARK: - Display Properties
    
    /// Short label shown in category pickers and badges.
    var displayName: String {
        switch self {
        case .selfEmployment:    return "Self-Employed / 1099"
        case .w2WithholdingPaid: return "W-2 / Employer Withholds"
        case .passiveIncome:     return "Passive / Investment"
        case .taxExempt:         return "Tax Exempt"
        }
    }
    
    /// Plain-language explanation shown in Add/Edit category help text.
    var description: String {
        switch self {
        case .selfEmployment:
            return "Freelance, gig, or contract work where you track and pay your own taxes."
        case .w2WithholdingPaid:
            return "A job or employer that withholds taxes from your paycheck. Reduces quarterly payments owed."
        case .passiveIncome:
            return "Rental income, dividends, or investment gains. No self-employment tax applies."
        case .taxExempt:
            return "Not subject to tax — Roth withdrawals, HSA reimbursements, gifts, insurance payouts."
        }
    }
    
    /// SF Symbol used in pickers and badges.
    var icon: String {
        switch self {
        case .selfEmployment:    return "briefcase.fill"
        case .w2WithholdingPaid: return "building.columns.fill"
        case .passiveIncome:     return "chart.line.uptrend.xyaxis"
        case .taxExempt:         return "checkmark.shield.fill"
        }
    }
    
    /// Accent color for badges (dark-mode compatible semantic colors via hex).
    var badgeColor: Color {
        switch self {
        case .selfEmployment:    return Color(flowHex: "#14B8A6")  // Teal — brand primary
        case .w2WithholdingPaid: return Color(flowHex: "#3B82F6")  // Blue
        case .passiveIncome:     return Color(flowHex: "#8B5CF6")  // Purple
        case .taxExempt:         return Color(flowHex: "#64748B")  // Slate
        }
    }
    
    /// Alias for displayName — used by badge labels in category rows and summary views.
    var badgeLabel: String { displayName }
    
    /// Alias for badgeColor — used by foregroundStyle/background modifiers in views.
    var color: Color { badgeColor }
}

// MARK: - Tax Owner Enum

/// Identifies which person's tax situation an income category belongs to.
/// Allows married couples or side-giggers to track income streams separately
/// while still computing the correct household bracket for MFJ filers.
enum TaxOwner: String, Codable, CaseIterable {
    
    /// The primary FLO account holder.
    case primary = "primary"
    
    /// The spouse / second earner (for married filers tracking combined finances).
    case spouse = "spouse"
    
    /// Joint or household income not attributable to one person.
    case joint = "joint"
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .primary: return "Mine"
        case .spouse:  return "Spouse's"
        case .joint:   return "Joint / Shared"
        }
    }
    
    var description: String {
        switch self {
        case .primary: return "Your own income — applied to your SE tax and bracket calculations."
        case .spouse:  return "Your spouse's income — tracked separately, stacks into household tax bracket."
        case .joint:   return "Shared household income not tied to one person."
        }
    }
    
    var icon: String {
        switch self {
        case .primary: return "person.fill"
        case .spouse:  return "person.2.fill"
        case .joint:   return "house.fill"
        }
    }
}

// MARK: - Category Model

/// A category for organizing transactions, budgets, and recurring transactions.
/// v2.2 adds tax treatment classification for multi-source income support,
/// supporting freelancers with W-2 jobs, married couples with mixed income,
/// and anyone with passive or tax-exempt income streams.
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
    
    // MARK: - Behavior Flags
    
    /// If true, this category cannot be deleted (system defaults).
    var isDefault: Bool
    
    /// If true, this category is used for income transactions.
    var isIncome: Bool
    
    /// If true, expense transactions in this category may be tax-deductible.
    var isTaxDeductible: Bool
    
    /// If true, this is a business category; if false, it is personal.
    /// Combines with isIncome to produce 4 groupings:
    /// Business Income, Business Expense, Personal Income, Personal Expense.
    var isBusiness: Bool
    
    // MARK: - Tax Treatment (Income Categories)
    
    /// Raw string backing for taxTreatment — SwiftData Codable compatible.
    /// Defaults to "selfEmployment" (correct for most FLO users).
    var taxTreatmentRaw: String
    
    /// Typed accessor for taxTreatmentRaw.
    var taxTreatment: TaxTreatment {
        get { TaxTreatment(rawValue: taxTreatmentRaw) ?? .selfEmployment }
        set { taxTreatmentRaw = newValue.rawValue }
    }
    
    // MARK: - Tax Owner (Income Categories)
    
    /// Raw string backing for taxOwner — SwiftData Codable compatible.
    /// Defaults to "primary".
    var taxOwnerRaw: String
    
    /// Typed accessor for taxOwnerRaw.
    var taxOwner: TaxOwner {
        get { TaxOwner(rawValue: taxOwnerRaw) ?? .primary }
        set { taxOwnerRaw = newValue.rawValue }
    }
    
    // MARK: - W-2 Withholding Rate
    
    /// For W-2 income categories: estimated employer withholding rate as a decimal (0.0–1.0).
    /// Example: 0.22 means approximately 22% is withheld by the employer.
    /// Used to estimate how much quarterly tax has already been covered via paycheck withholding.
    /// Nil for non-W-2 categories.
    var estimatedWithholdingRate: Double?
    
    // MARK: - Relationships
    // NOTE: Category defines the inverse for all to-many relationships
    
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
        isTaxDeductible: Bool = false,
        isBusiness: Bool = false,
        taxTreatment: TaxTreatment = .selfEmployment,
        taxOwner: TaxOwner = .primary,
        estimatedWithholdingRate: Double? = nil
    ) {
        self.id = UUID()
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon = icon
        self.colorHex = Self.normalizeColorHex(colorHex)
        self.isDefault = isDefault
        self.isIncome = isIncome
        self.isTaxDeductible = isTaxDeductible
        self.isBusiness = isBusiness
        self.taxTreatmentRaw = taxTreatment.rawValue
        self.taxOwnerRaw = taxOwner.rawValue
        self.estimatedWithholdingRate = estimatedWithholdingRate
    }
    
    // MARK: - Color Normalization
    
    /// Ensures consistent uppercase hex format with leading #.
    /// Falls back to Tailwind blue-500 (#3B82F6) if invalid.
    private static func normalizeColorHex(_ hex: String) -> String {
        var cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6,
              cleaned.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else {
            return "#3B82F6"
        }
        return "#\(cleaned)"
    }
    
    // MARK: - Computed Properties
    
    /// SwiftUI Color object from hex string.
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
    
    /// Whether this income category contributes to self-employment tax.
    var contributesToSETax: Bool {
        isIncome && taxTreatment == .selfEmployment
    }
    
    /// Whether this income category is entirely excluded from all tax calculations.
    var isExcludedFromTax: Bool {
        isIncome && taxTreatment == .taxExempt
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
            isIncome: false,
            isTaxDeductible: false,
            isBusiness: false
        )
    }
    
    @MainActor static var previewBusinessExpense: Category {
        Category(
            name: "Business Expenses",
            icon: "briefcase.fill",
            colorHex: "#3B82F6",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true
        )
    }
    
    @MainActor static var previewFreelanceIncome: Category {
        Category(
            name: "Freelance Income",
            icon: "laptopcomputer",
            colorHex: "#14B8A6",
            isDefault: false,
            isIncome: true,
            isBusiness: true,
            taxTreatment: .selfEmployment,
            taxOwner: .primary
        )
    }
    
    @MainActor static var previewSpouseW2: Category {
        Category(
            name: "Salary / Wages",
            icon: "banknote.fill",
            colorHex: "#22C55E",
            isDefault: false,
            isIncome: true,
            isBusiness: false,
            taxTreatment: .w2WithholdingPaid,
            taxOwner: .spouse,
            estimatedWithholdingRate: 0.22
        )
    }
    
    @MainActor static var previewInvestmentIncome: Category {
        Category(
            name: "Investment Income",
            icon: "chart.line.uptrend.xyaxis",
            colorHex: "#6366F1",
            isDefault: false,
            isIncome: true,
            isBusiness: false,
            taxTreatment: .passiveIncome,
            taxOwner: .primary
        )
    }
    
    @MainActor static var previewRent: Category {
        Category(
            name: "Rent",
            icon: "house.fill",
            colorHex: "#EF4444",
            isDefault: true,
            isIncome: false,
            isTaxDeductible: false,
            isBusiness: false
        )
    }
    
    @MainActor static var previewDefaultCategories: [Category] {
        [
            .previewGroceries,
            .previewRent,
            .previewFreelanceIncome,
            .previewBusinessExpense,
            .previewSpouseW2,
            .previewInvestmentIncome
        ]
    }
}
#endif
