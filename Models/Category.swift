//  Category.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.0 — Add ScheduleCLine enum for IRS tax form mapping
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Category model with tax treatment classification and Schedule C line mapping.
//
//  CHANGES IN v3.0:
//  ✅ ADDED: ScheduleCLine enum — maps categories to IRS Schedule C (Form 1040) lines
//  ✅ ADDED: scheduleCLineRaw / scheduleCLine — optional property on Category model
//  ✅ ADDED: Computed helpers: formattedForReport, lineNumber, deductionRate
//  ✅ ADDED: Category.scheduleCLineDisplay — formatted string for report/badge display
//  ✅ NOTE: SwiftData handles lightweight migration automatically (new optional String)
//  ✅ NOTE: Existing categories will have nil scheduleCLine — fully backward compatible
//
//  CHANGES IN v2.3:
//  ✅ ADDED: TaxTreatment.badgeLabel — alias for displayName (used by badge views)
//  ✅ ADDED: TaxTreatment.color — alias for badgeColor (used by badge/foreground views)
//
//  CHANGES IN v2.2:
//  ✅ ADDED: TaxTreatment enum — controls how income categories affect tax calculations
//  ✅ ADDED: TaxOwner enum — distinguishes primary user, spouse, or joint income
//  ✅ ADDED: isBusiness: Bool — explicit business vs. personal flag for all categories
//  ✅ ADDED: estimatedWithholdingRate: Double? — for W-2 categories, employer withholding %
//
//  SWIFTDATA NOTES:
//  — ScheduleCLine stores as Optional<String> (rawValue) — lightweight migration safe
//  — TaxTreatment and TaxOwner store as String (rawValue) — native SwiftData support
//  — estimatedWithholdingRate is Optional<Double> — stores nil when not applicable
//  — isBusiness is Bool with default false — lightweight migration safe
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - IRS Schedule C Line Enum

/// Maps a category to its corresponding IRS Schedule C (Form 1040) expense line.
/// Used by reports to generate a line-by-line tax deduction breakdown for CPAs.
///
/// Reference: IRS Schedule C (Profit or Loss From Business) — 2025/2026
/// Each case includes the official line number and IRS description.
enum ScheduleCLine: String, Codable, CaseIterable, Comparable {

    // ── Income Lines ──────────────────────────────────────────
    case line1_grossReceipts       = "line1"
    case line6_otherIncome         = "line6"

    // ── Expense Lines ─────────────────────────────────────────
    case line8_advertising         = "line8"
    case line9_carAndTruck         = "line9"
    case line10_commissionsAndFees = "line10"
    case line11_contractLabor      = "line11"
    case line12_depletion          = "line12"
    case line13_depreciation       = "line13"
    case line14_employeeBenefits   = "line14"
    case line15_insurance          = "line15"
    case line16a_mortgageBanks     = "line16a"
    case line16b_mortgageOther     = "line16b"
    case line17_legalProfessional  = "line17"
    case line18_officeExpense      = "line18"
    case line19_pensionProfitShare = "line19"
    case line20a_rentEquipment     = "line20a"
    case line20b_rentProperty      = "line20b"
    case line21_repairsMaintenance = "line21"
    case line22_supplies           = "line22"
    case line23_taxesAndLicenses   = "line23"
    case line24a_travel            = "line24a"
    case line24b_meals             = "line24b"
    case line25_utilities          = "line25"
    case line26_wages              = "line26"
    case line27a_otherExpenses     = "line27a"
    case line30_businessUseOfHome  = "line30"

    // MARK: - Sort Order (for Comparable)

    /// Numeric sort key extracted from the raw value for proper ordering.
    private var sortKey: Double {
        // Extract numeric portion: "line24b" → 24.2
        let digits = rawValue.replacingOccurrences(of: "line", with: "")
        if digits.hasSuffix("a") {
            return (Double(digits.dropLast()) ?? 0) + 0.1
        } else if digits.hasSuffix("b") {
            return (Double(digits.dropLast()) ?? 0) + 0.2
        }
        return Double(digits) ?? 0
    }

    static func < (lhs: ScheduleCLine, rhs: ScheduleCLine) -> Bool {
        lhs.sortKey < rhs.sortKey
    }

    // MARK: - Display Properties

    /// The IRS line number string (e.g., "Line 8", "Line 24b").
    var lineNumber: String {
        switch self {
        case .line1_grossReceipts:       return "Line 1"
        case .line6_otherIncome:         return "Line 6"
        case .line8_advertising:         return "Line 8"
        case .line9_carAndTruck:         return "Line 9"
        case .line10_commissionsAndFees: return "Line 10"
        case .line11_contractLabor:      return "Line 11"
        case .line12_depletion:          return "Line 12"
        case .line13_depreciation:       return "Line 13"
        case .line14_employeeBenefits:   return "Line 14"
        case .line15_insurance:          return "Line 15"
        case .line16a_mortgageBanks:     return "Line 16a"
        case .line16b_mortgageOther:     return "Line 16b"
        case .line17_legalProfessional:  return "Line 17"
        case .line18_officeExpense:      return "Line 18"
        case .line19_pensionProfitShare: return "Line 19"
        case .line20a_rentEquipment:     return "Line 20a"
        case .line20b_rentProperty:      return "Line 20b"
        case .line21_repairsMaintenance: return "Line 21"
        case .line22_supplies:           return "Line 22"
        case .line23_taxesAndLicenses:   return "Line 23"
        case .line24a_travel:            return "Line 24a"
        case .line24b_meals:             return "Line 24b"
        case .line25_utilities:          return "Line 25"
        case .line26_wages:              return "Line 26"
        case .line27a_otherExpenses:     return "Line 27a"
        case .line30_businessUseOfHome:  return "Line 30"
        }
    }

    /// Official IRS description for this line.
    var irsDescription: String {
        switch self {
        case .line1_grossReceipts:       return "Gross receipts or sales"
        case .line6_otherIncome:         return "Other income"
        case .line8_advertising:         return "Advertising"
        case .line9_carAndTruck:         return "Car and truck expenses"
        case .line10_commissionsAndFees: return "Commissions and fees"
        case .line11_contractLabor:      return "Contract labor"
        case .line12_depletion:          return "Depletion"
        case .line13_depreciation:       return "Depreciation and Section 179"
        case .line14_employeeBenefits:   return "Employee benefit programs"
        case .line15_insurance:          return "Insurance (other than health)"
        case .line16a_mortgageBanks:     return "Interest (mortgage, banks)"
        case .line16b_mortgageOther:     return "Interest (mortgage, other)"
        case .line17_legalProfessional:  return "Legal and professional services"
        case .line18_officeExpense:      return "Office expense"
        case .line19_pensionProfitShare: return "Pension and profit-sharing plans"
        case .line20a_rentEquipment:     return "Rent (vehicles, machinery, equipment)"
        case .line20b_rentProperty:      return "Rent (other business property)"
        case .line21_repairsMaintenance: return "Repairs and maintenance"
        case .line22_supplies:           return "Supplies (not in office expense)"
        case .line23_taxesAndLicenses:   return "Taxes and licenses"
        case .line24a_travel:            return "Travel"
        case .line24b_meals:             return "Deductible meals"
        case .line25_utilities:          return "Utilities"
        case .line26_wages:              return "Wages"
        case .line27a_otherExpenses:     return "Other expenses"
        case .line30_businessUseOfHome:  return "Business use of home"
        }
    }

    /// Combined display: "Line 8 — Advertising"
    var displayName: String {
        "\(lineNumber) — \(irsDescription)"
    }

    /// Short badge label for compact UI: "Ln 8"
    var badgeLabel: String {
        lineNumber.replacingOccurrences(of: "Line ", with: "Ln ")
    }

    /// Formatted string for PDF reports: "Line 8 - Advertising"
    var formattedForReport: String {
        "\(lineNumber) - \(irsDescription)"
    }

    /// Default deduction percentage for this line (1.0 = 100%, 0.5 = 50%).
    /// Used as the default; users can override via businessPercentage on individual transactions.
    var defaultDeductionRate: Double {
        switch self {
        case .line24b_meals: return 0.50  // Business meals are 50% deductible
        default:             return 1.00  // Most lines are 100% deductible
        }
    }

    /// Whether this is an income line (Lines 1, 6) vs. expense line.
    var isIncomeLine: Bool {
        switch self {
        case .line1_grossReceipts, .line6_otherIncome: return true
        default: return false
        }
    }

    /// Only expense lines — used for picker in Add/Edit Category views.
    static var expenseLines: [ScheduleCLine] {
        allCases.filter { !$0.isIncomeLine }.sorted()
    }

    /// Common expense lines most relevant for freelancers — shown first in pickers.
    static var commonExpenseLines: [ScheduleCLine] {
        [
            .line8_advertising,
            .line9_carAndTruck,
            .line11_contractLabor,
            .line13_depreciation,
            .line15_insurance,
            .line17_legalProfessional,
            .line18_officeExpense,
            .line20b_rentProperty,
            .line24a_travel,
            .line24b_meals,
            .line25_utilities,
            .line27a_otherExpenses,
        ]
    }
}

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
/// v3.0 adds IRS Schedule C line mapping for CPA-ready tax reports.
/// v2.2 adds tax treatment classification for multi-source income support.
@Model
final class Category {

    // MARK: - Identifiers
    private(set) var id: UUID = UUID()

    // MARK: - Core Properties

    /// Display name for this category.
    var name: String = ""

    /// SF Symbol name for icon display.
    var icon: String = "folder.fill"

    /// Hex color code (format: #RRGGBB) for UI theming.
    var colorHex: String = "#3B82F6"

    // MARK: - Behavior Flags

    /// If true, this category cannot be deleted (system defaults).
    var isDefault: Bool = false

    /// If true, this category is used for income transactions.
    var isIncome: Bool = false

    /// If true, expense transactions in this category may be tax-deductible.
    var isTaxDeductible: Bool = false

    /// If true, this is a business category; if false, it is personal.
    /// Combines with isIncome to produce 4 groupings:
    /// Business Income, Business Expense, Personal Income, Personal Expense.
    var isBusiness: Bool = false

    // MARK: - Tax Treatment (Income Categories)

    /// Raw string backing for taxTreatment — SwiftData Codable compatible.
    /// Defaults to "selfEmployment" (correct for most FLO users).
    var taxTreatmentRaw: String = TaxTreatment.selfEmployment.rawValue

    /// Typed accessor for taxTreatmentRaw.
    var taxTreatment: TaxTreatment {
        get { TaxTreatment(rawValue: taxTreatmentRaw) ?? .selfEmployment }
        set { taxTreatmentRaw = newValue.rawValue }
    }

    // MARK: - Tax Owner (Income Categories)

    /// Raw string backing for taxOwner — SwiftData Codable compatible.
    /// Defaults to "primary".
    var taxOwnerRaw: String = TaxOwner.primary.rawValue

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

    // MARK: - IRS Schedule C Line (v3.0)

    /// Raw string backing for scheduleCLine — SwiftData Codable compatible.
    /// nil for personal expense categories and income categories.
    /// Set automatically for default business categories; user-assignable for custom categories.
    var scheduleCLineRaw: String?

    /// Typed accessor for scheduleCLineRaw.
    /// Returns nil for categories that don't map to a Schedule C line.
    var scheduleCLine: ScheduleCLine? {
        get {
            guard let raw = scheduleCLineRaw else { return nil }
            return ScheduleCLine(rawValue: raw)
        }
        set { scheduleCLineRaw = newValue?.rawValue }
    }

    // MARK: - Relationships
    // NOTE: Category defines the inverse for all to-many relationships

    /// All transactions using this category.
    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    /// All budgets associated with this category.
    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]?

    /// All recurring transactions using this category.
    @Relationship(deleteRule: .cascade, inverse: \RecurringTransaction.category)
    var recurringTransactions: [RecurringTransaction]?

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
        estimatedWithholdingRate: Double? = nil,
        scheduleCLine: ScheduleCLine? = nil
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
        self.scheduleCLineRaw = scheduleCLine?.rawValue
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
        (transactions ?? []).count
    }

    /// Total number of budgets using this category.
    var budgetCount: Int {
        (budgets ?? []).count
    }

    /// Whether this category is actively being used.
    var isInUse: Bool {
        !(transactions ?? []).isEmpty || !(budgets ?? []).isEmpty || !(recurringTransactions ?? []).isEmpty
    }

    /// Whether this income category contributes to self-employment tax.
    var contributesToSETax: Bool {
        isIncome && taxTreatment == .selfEmployment
    }

    /// Whether this income category is entirely excluded from all tax calculations.
    var isExcludedFromTax: Bool {
        isIncome && taxTreatment == .taxExempt
    }

    // MARK: - Schedule C Computed Properties (v3.0)

    /// Formatted Schedule C line display for badges and lists.
    /// Returns nil if no Schedule C line is assigned.
    /// Example: "Ln 18 — Office expense"
    var scheduleCLineDisplay: String? {
        scheduleCLine?.displayName
    }

    /// Short badge text for compact display (e.g., "Ln 18").
    /// Returns nil if no Schedule C line is assigned.
    var scheduleCBadge: String? {
        scheduleCLine?.badgeLabel
    }

    /// The default deduction rate for this category's Schedule C line.
    /// Returns 1.0 (100%) if no line is assigned or for most lines.
    /// Returns 0.5 (50%) for Line 24b (meals).
    var defaultDeductionRate: Double {
        scheduleCLine?.defaultDeductionRate ?? 1.0
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
            name: "Office Supplies",
            icon: "pencil.and.ruler.fill",
            colorHex: "#3B82F6",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true,
            scheduleCLine: .line18_officeExpense
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
            taxOwner: .primary,
            scheduleCLine: .line1_grossReceipts
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

    @MainActor static var previewAdvertising: Category {
        Category(
            name: "Advertising & Marketing",
            icon: "megaphone.fill",
            colorHex: "#F59E0B",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true,
            scheduleCLine: .line8_advertising
        )
    }

    @MainActor static var previewBusinessMeals: Category {
        Category(
            name: "Business Meals",
            icon: "fork.knife.circle.fill",
            colorHex: "#F97316",
            isDefault: false,
            isIncome: false,
            isTaxDeductible: true,
            isBusiness: true,
            scheduleCLine: .line24b_meals
        )
    }

    @MainActor static var previewDefaultCategories: [Category] {
        [
            .previewGroceries,
            .previewRent,
            .previewFreelanceIncome,
            .previewBusinessExpense,
            .previewSpouseW2,
            .previewInvestmentIncome,
            .previewAdvertising,
            .previewBusinessMeals
        ]
    }
}
#endif
