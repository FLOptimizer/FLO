//  SeedData.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 — Comprehensive granular category expansion (Build 8)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v4.0:
//  ✅ EXPANDED: 37 defaults → 142 defaults (48 biz exp, 60 personal exp, 16 biz inc, 18 personal inc)
//  ✅ REMOVED: 5 generic categories from defaults (replaced by granular):
//             Insurance (Business), Utilities (Business), Transportation, Utilities (Personal), Healthcare
//  ✅ ADDED: Granular utilities (Electric, Gas/Natural Gas, Water & Sewer) — business + personal pairs
//  ✅ ADDED: Granular vehicle (Gas, Vehicle Insurance/Maintenance, Parking & Tolls) — business side
//  ✅ ADDED: Granular transportation (Gas/Fuel, Car Insurance/Payment/Maintenance, etc.) — personal side
//  ✅ ADDED: Granular insurance (General Liability, Health SE, Property) — business side
//  ✅ ADDED: Granular insurance (Health Premiums, Dental/Vision, Life, Disability, Renter's) — personal
//  ✅ ADDED: Granular health (Doctor, Prescriptions, Dental, Vision, Therapy, HSA/FSA) — personal
//  ✅ ADDED: 16 business income categories (was 4), 18 personal income (was 3)
//  ✅ ADDED: Family, Financial, Lifestyle personal expense subcategories
//  ✅ ADDED: Schedule C line mappings on all new business expenses
//  ✅ ADDED: v4.0 migration — adds all new categories for existing users (name-match guard)
//
//  MODEL ASSUMPTIONS:
//  - Category model v3.0+: name, icon, colorHex, isDefault, isIncome, isTaxDeductible,
//    isBusiness, taxTreatment, taxOwner, estimatedWithholdingRate, scheduleCLine
//

import SwiftData
import Foundation

@MainActor
struct SeedData {

    // MARK: - Version Management

    static let version = "4.1"

    private static let versionKey                = "com.finchandpoppy.flo.seeddata.version"
    private static let iconMigrationKey          = "com.finchandpoppy.flo.seeddata.iconmigrationv24"       // v3.12 perf
    private static let missingCategoriesKey      = "com.finchandpoppy.flo.seeddata.missingcategoriesv40"   // v3.14: full-defaults restore
    private static let taxTreatmentMigrationKey  = "com.finchandpoppy.flo.seeddata.taxtreatmentv27"
    private static let scheduleCMigrationKey     = "com.finchandpoppy.flo.seeddata.schedulecv30"
    private static let plaidIncomeFixKey          = "com.finchandpoppy.flo.seeddata.plaidincomefixv312"
    private static let granularCategoriesV40Key  = "com.finchandpoppy.flo.seeddata.granularcategoriesv40"
    private static let militaryVAEducationV41Key = "com.finchandpoppy.flo.seeddata.milVAeduv41"
    private static let legacyBusinessFixKey      = "com.finchandpoppy.flo.seeddata.legacybizfixv42"

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

    // MARK: - Default Category Configuration (v3.0 — added scheduleCLine)

    private struct DefaultCategory {
        let name: String
        let icon: String
        let colorHex: String
        let isIncome: Bool
        let isTaxDeductible: Bool
        let sortOrder: Int
        // v2.7 fields
        let isBusiness: Bool
        let taxTreatment: TaxTreatment
        let taxOwner: TaxOwner
        // v3.0 field
        let scheduleCLine: ScheduleCLine?
    }

    // MARK: - Predefined Categories (v4.0 — 142 defaults, granular coverage)

    private static let defaults: [DefaultCategory] = [

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Business Expense Categories (48 total — all tax deductible)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Office & Operations ──
        DefaultCategory(name: "Office Supplies", icon: "pencil.and.ruler.fill", colorHex: "F59E0B",
            isIncome: false, isTaxDeductible: true, sortOrder: 1,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line18_officeExpense),
        DefaultCategory(name: "Software & Subscriptions", icon: "app.badge.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: true, sortOrder: 2,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Professional Services", icon: "person.crop.rectangle.fill", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: true, sortOrder: 3,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line17_legalProfessional),
        DefaultCategory(name: "Marketing & Advertising", icon: "megaphone.fill", colorHex: "EC4899",
            isIncome: false, isTaxDeductible: true, sortOrder: 4,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line8_advertising),
        DefaultCategory(name: "Education & Training", icon: "book.fill", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: true, sortOrder: 5,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Equipment & Tools", icon: "wrench.and.screwdriver.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: true, sortOrder: 6,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line13_depreciation),
        DefaultCategory(name: "Supplies", icon: "shippingbox.fill", colorHex: "D97706",
            isIncome: false, isTaxDeductible: true, sortOrder: 7,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line22_supplies),
        DefaultCategory(name: "Inventory / COGS", icon: "archivebox.fill", colorHex: "F59E0B",
            isIncome: false, isTaxDeductible: true, sortOrder: 8,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Shipping & Postage", icon: "shippingbox.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: true, sortOrder: 9,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Domain & Hosting", icon: "globe", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: true, sortOrder: 10,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Internet & Phone (Biz)", icon: "wifi", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: true, sortOrder: 11,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line25_utilities),
        DefaultCategory(name: "Printing & Copying", icon: "printer.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: true, sortOrder: 12,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Cleaning & Janitorial", icon: "sparkles", colorHex: "84CC16",
            isIncome: false, isTaxDeductible: true, sortOrder: 13,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Research & Development", icon: "magnifyingglass", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: true, sortOrder: 14,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),

        // ── People ──
        DefaultCategory(name: "Contract Labor", icon: "person.2.fill", colorHex: "14B8A6",
            isIncome: false, isTaxDeductible: true, sortOrder: 15,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line11_contractLabor),
        DefaultCategory(name: "Employee Wages", icon: "dollarsign.circle.fill", colorHex: "22C55E",
            isIncome: false, isTaxDeductible: true, sortOrder: 16,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line26_wages),
        DefaultCategory(name: "Employee Benefits", icon: "person.3.fill", colorHex: "10B981",
            isIncome: false, isTaxDeductible: true, sortOrder: 17,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line14_employeeBenefits),
        DefaultCategory(name: "Pension / Profit-Sharing", icon: "chart.pie.fill", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: true, sortOrder: 18,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line19_pensionProfitShare),
        DefaultCategory(name: "Commissions & Fees", icon: "percent", colorHex: "FB7185",
            isIncome: false, isTaxDeductible: true, sortOrder: 19,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line10_commissionsAndFees),

        // ── Travel & Meals ──
        DefaultCategory(name: "Business Travel", icon: "airplane", colorHex: "06B6D4",
            isIncome: false, isTaxDeductible: true, sortOrder: 20,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line24a_travel),
        DefaultCategory(name: "Meals & Entertainment", icon: "fork.knife", colorHex: "F97316",
            isIncome: false, isTaxDeductible: true, sortOrder: 21,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line24b_meals),
        DefaultCategory(name: "Conferences & Events", icon: "ticket.fill", colorHex: "A855F7",
            isIncome: false, isTaxDeductible: true, sortOrder: 22,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Client Gifts", icon: "gift.fill", colorHex: "EC4899",
            isIncome: false, isTaxDeductible: true, sortOrder: 23,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),

        // ── Property & Rent ──
        DefaultCategory(name: "Rent/Lease (Business)", icon: "building.2.fill", colorHex: "7C3AED",
            isIncome: false, isTaxDeductible: true, sortOrder: 24,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line20b_rentProperty),
        DefaultCategory(name: "Rent (Equipment/Vehicles)", icon: "car.2.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: true, sortOrder: 25,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line20a_rentEquipment),
        DefaultCategory(name: "Repairs & Maintenance", icon: "hammer.fill", colorHex: "84CC16",
            isIncome: false, isTaxDeductible: true, sortOrder: 26,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line21_repairsMaintenance),
        DefaultCategory(name: "Depreciation (Section 179)", icon: "chart.bar.xaxis.ascending", colorHex: "475569",
            isIncome: false, isTaxDeductible: true, sortOrder: 27,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line13_depreciation),
        DefaultCategory(name: "Business Use of Home", icon: "house.circle.fill", colorHex: "14B8A6",
            isIncome: false, isTaxDeductible: true, sortOrder: 28,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line30_businessUseOfHome),
        DefaultCategory(name: "Uniforms & Work Clothing", icon: "tshirt.fill", colorHex: "7C3AED",
            isIncome: false, isTaxDeductible: true, sortOrder: 29,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),

        // ── Utilities — Granular (dual-use with personal) ──
        DefaultCategory(name: "Electric (Business)", icon: "bolt.fill", colorHex: "EAB308",
            isIncome: false, isTaxDeductible: true, sortOrder: 30,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line25_utilities),
        DefaultCategory(name: "Gas / Natural Gas (Business)", icon: "flame.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: true, sortOrder: 31,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line25_utilities),
        DefaultCategory(name: "Water & Sewer (Business)", icon: "drop.fill", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: true, sortOrder: 32,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line25_utilities),

        // ── Vehicle — Granular ──
        DefaultCategory(name: "Gas", icon: "fuelpump.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: true, sortOrder: 33,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line9_carAndTruck),
        DefaultCategory(name: "Vehicle Insurance (Business)", icon: "car.circle.fill", colorHex: "10B981",
            isIncome: false, isTaxDeductible: true, sortOrder: 34,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line15_insurance),
        DefaultCategory(name: "Vehicle Maintenance (Business)", icon: "wrench.and.screwdriver.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: true, sortOrder: 35,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line21_repairsMaintenance),
        DefaultCategory(name: "Parking & Tolls (Business)", icon: "parkingsign", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: true, sortOrder: 36,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line9_carAndTruck),

        // ── Insurance — Granular ──
        DefaultCategory(name: "General Liability Insurance", icon: "shield.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: true, sortOrder: 37,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line15_insurance),
        DefaultCategory(name: "Health Insurance (Self-Employed)", icon: "heart.text.square.fill", colorHex: "EF4444",
            isIncome: false, isTaxDeductible: true, sortOrder: 38,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line15_insurance),
        DefaultCategory(name: "Property Insurance (Business)", icon: "building.fill", colorHex: "475569",
            isIncome: false, isTaxDeductible: true, sortOrder: 39,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line15_insurance),

        // ── Legal, Financial & Taxes ──
        DefaultCategory(name: "Legal & Accounting", icon: "doc.text.fill", colorHex: "475569",
            isIncome: false, isTaxDeductible: true, sortOrder: 40,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line17_legalProfessional),
        DefaultCategory(name: "Legal Fees", icon: "scale.3d", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: true, sortOrder: 41,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line17_legalProfessional),
        DefaultCategory(name: "Accounting & Bookkeeping", icon: "doc.text.magnifyingglass", colorHex: "10B981",
            isIncome: false, isTaxDeductible: true, sortOrder: 42,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line17_legalProfessional),
        DefaultCategory(name: "Bank Fees & Interest", icon: "building.columns.fill", colorHex: "EF4444",
            isIncome: false, isTaxDeductible: true, sortOrder: 43,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Taxes & Licenses", icon: "checkmark.seal.fill", colorHex: "DC2626",
            isIncome: false, isTaxDeductible: true, sortOrder: 44,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line23_taxesAndLicenses),
        DefaultCategory(name: "Interest Expense", icon: "percent", colorHex: "EF4444",
            isIncome: false, isTaxDeductible: true, sortOrder: 45,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line16b_mortgageOther),
        DefaultCategory(name: "Dues & Memberships", icon: "person.3.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: true, sortOrder: 46,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Bad Debt / Write-offs", icon: "xmark.circle.fill", colorHex: "78716C",
            isIncome: false, isTaxDeductible: true, sortOrder: 47,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),
        DefaultCategory(name: "Miscellaneous (Business)", icon: "ellipsis.circle.fill", colorHex: "78716C",
            isIncome: false, isTaxDeductible: true, sortOrder: 48,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: .line27a_otherExpenses),

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Personal Expense Categories (60 total — not deductible)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // ── Food & Dining ──
        DefaultCategory(name: "Groceries", icon: "cart.fill", colorHex: "22C55E",
            isIncome: false, isTaxDeductible: false, sortOrder: 101,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Dining Out", icon: "fork.knife.circle.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: false, sortOrder: 102,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Coffee & Snacks", icon: "cup.and.saucer.fill", colorHex: "D97706",
            isIncome: false, isTaxDeductible: false, sortOrder: 103,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Alcohol & Bars", icon: "wineglass.fill", colorHex: "7C3AED",
            isIncome: false, isTaxDeductible: false, sortOrder: 104,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Housing ──
        DefaultCategory(name: "Housing", icon: "house.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: false, sortOrder: 105,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Home Insurance", icon: "house.and.flag.fill", colorHex: "10B981",
            isIncome: false, isTaxDeductible: false, sortOrder: 106,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Property Taxes", icon: "building.columns.fill", colorHex: "DC2626",
            isIncome: false, isTaxDeductible: false, sortOrder: 107,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "HOA / Condo Fees", icon: "building.fill", colorHex: "7C3AED",
            isIncome: false, isTaxDeductible: false, sortOrder: 108,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Home Maintenance & Repairs", icon: "hammer.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: false, sortOrder: 109,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Lawn & Garden", icon: "leaf.fill", colorHex: "22C55E",
            isIncome: false, isTaxDeductible: false, sortOrder: 110,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Home Furnishings", icon: "sofa.fill", colorHex: "F59E0B",
            isIncome: false, isTaxDeductible: false, sortOrder: 111,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Utilities — Granular (dual-use with business) ──
        DefaultCategory(name: "Electric", icon: "bolt.fill", colorHex: "EAB308",
            isIncome: false, isTaxDeductible: false, sortOrder: 112,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Gas / Natural Gas", icon: "flame.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: false, sortOrder: 113,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Water & Sewer", icon: "drop.fill", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: false, sortOrder: 114,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Trash & Recycling", icon: "trash.fill", colorHex: "84CC16",
            isIncome: false, isTaxDeductible: false, sortOrder: 115,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Internet (Home)", icon: "wifi", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: false, sortOrder: 116,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Phone (Personal)", icon: "phone.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: false, sortOrder: 117,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Transportation — Granular ──
        DefaultCategory(name: "Gas / Fuel", icon: "fuelpump.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: false, sortOrder: 118,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Car Insurance", icon: "car.circle.fill", colorHex: "10B981",
            isIncome: false, isTaxDeductible: false, sortOrder: 119,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Car Payment", icon: "car.fill", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: false, sortOrder: 120,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Car Maintenance & Repairs", icon: "wrench.and.screwdriver.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: false, sortOrder: 121,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Parking & Tolls", icon: "parkingsign", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: false, sortOrder: 122,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Public Transit", icon: "bus.fill", colorHex: "06B6D4",
            isIncome: false, isTaxDeductible: false, sortOrder: 123,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Rideshare (Uber/Lyft)", icon: "figure.wave", colorHex: "A855F7",
            isIncome: false, isTaxDeductible: false, sortOrder: 124,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Car Registration & DMV", icon: "doc.text.fill", colorHex: "475569",
            isIncome: false, isTaxDeductible: false, sortOrder: 125,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Insurance — Personal ──
        DefaultCategory(name: "Health Insurance Premiums", icon: "heart.text.square.fill", colorHex: "EF4444",
            isIncome: false, isTaxDeductible: false, sortOrder: 126,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Dental & Vision Insurance", icon: "eye.fill", colorHex: "F472B6",
            isIncome: false, isTaxDeductible: false, sortOrder: 127,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Life Insurance", icon: "shield.lefthalf.filled", colorHex: "475569",
            isIncome: false, isTaxDeductible: false, sortOrder: 128,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Disability Insurance", icon: "figure.roll", colorHex: "78716C",
            isIncome: false, isTaxDeductible: false, sortOrder: 129,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Renter's / Umbrella Insurance", icon: "umbrella.fill", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: false, sortOrder: 130,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Health & Medical — Granular ──
        DefaultCategory(name: "Doctor & Specialist Visits", icon: "stethoscope", colorHex: "EF4444",
            isIncome: false, isTaxDeductible: false, sortOrder: 131,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Prescriptions & Pharmacy", icon: "pills.fill", colorHex: "F43F5E",
            isIncome: false, isTaxDeductible: false, sortOrder: 132,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Dental Care", icon: "mouth.fill", colorHex: "EC4899",
            isIncome: false, isTaxDeductible: false, sortOrder: 133,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Vision & Eye Care", icon: "eyeglasses", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: false, sortOrder: 134,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Therapy & Counseling", icon: "brain.head.profile", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: false, sortOrder: 135,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "HSA / FSA Contributions", icon: "cross.case.fill", colorHex: "14B8A6",
            isIncome: false, isTaxDeductible: false, sortOrder: 136,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Family & Kids ──
        DefaultCategory(name: "Childcare", icon: "figure.and.child.holdinghands", colorHex: "EC4899",
            isIncome: false, isTaxDeductible: false, sortOrder: 137,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Tuition & School Fees", icon: "graduationcap.fill", colorHex: "3B82F6",
            isIncome: false, isTaxDeductible: false, sortOrder: 138,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Kids' Activities & Sports", icon: "figure.run", colorHex: "22C55E",
            isIncome: false, isTaxDeductible: false, sortOrder: 139,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "College Savings (529)", icon: "banknote.fill", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: false, sortOrder: 140,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Elder Care / Parent Support", icon: "figure.2.arms.open", colorHex: "78716C",
            isIncome: false, isTaxDeductible: false, sortOrder: 141,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Pet Expenses", icon: "pawprint.fill", colorHex: "F97316",
            isIncome: false, isTaxDeductible: false, sortOrder: 142,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Financial ──
        DefaultCategory(name: "Retirement Contributions (IRA/401k)", icon: "chart.line.uptrend.xyaxis", colorHex: "14B8A6",
            isIncome: false, isTaxDeductible: false, sortOrder: 143,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Emergency Fund / Savings", icon: "dollarsign.arrow.circlepath", colorHex: "22C55E",
            isIncome: false, isTaxDeductible: false, sortOrder: 144,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Loan Payments", icon: "banknote.fill", colorHex: "64748B",
            isIncome: false, isTaxDeductible: false, sortOrder: 145,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Taxes Paid", icon: "building.columns.fill", colorHex: "0EA5E9",
            isIncome: false, isTaxDeductible: false, sortOrder: 146,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Alimony (Paid)", icon: "arrow.up.circle.fill", colorHex: "78716C",
            isIncome: false, isTaxDeductible: false, sortOrder: 147,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Child Support (Paid)", icon: "figure.2.and.child.holdinghands", colorHex: "78716C",
            isIncome: false, isTaxDeductible: false, sortOrder: 148,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ── Lifestyle ──
        DefaultCategory(name: "Entertainment", icon: "tv.fill", colorHex: "A855F7",
            isIncome: false, isTaxDeductible: false, sortOrder: 149,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Shopping", icon: "bag.fill", colorHex: "EC4899",
            isIncome: false, isTaxDeductible: false, sortOrder: 150,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Clothing & Apparel", icon: "tshirt.fill", colorHex: "A855F7",
            isIncome: false, isTaxDeductible: false, sortOrder: 151,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Personal Care", icon: "sparkles", colorHex: "F472B6",
            isIncome: false, isTaxDeductible: false, sortOrder: 152,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Haircut & Grooming", icon: "scissors", colorHex: "F472B6",
            isIncome: false, isTaxDeductible: false, sortOrder: 153,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Fitness & Wellness", icon: "figure.run", colorHex: "10B981",
            isIncome: false, isTaxDeductible: false, sortOrder: 154,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Subscriptions (Personal)", icon: "play.rectangle.fill", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: false, sortOrder: 155,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Vacation & Travel (Personal)", icon: "airplane", colorHex: "06B6D4",
            isIncome: false, isTaxDeductible: false, sortOrder: 156,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Hobbies", icon: "paintbrush.fill", colorHex: "F59E0B",
            isIncome: false, isTaxDeductible: false, sortOrder: 157,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Books & Education (Personal)", icon: "book.fill", colorHex: "6366F1",
            isIncome: false, isTaxDeductible: false, sortOrder: 158,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Gifts & Donations", icon: "gift.fill", colorHex: "F43F5E",
            isIncome: false, isTaxDeductible: false, sortOrder: 159,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Charity & Donations", icon: "hands.sparkles.fill", colorHex: "8B5CF6",
            isIncome: false, isTaxDeductible: false, sortOrder: 160,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Business Income Categories (16 total)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // Self-employment / 1099 income — subject to SE tax
        DefaultCategory(name: "Client Payments", icon: "dollarsign.circle.fill", colorHex: "10B981",
            isIncome: true, isTaxDeductible: false, sortOrder: 201,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Freelance Income", icon: "laptopcomputer", colorHex: "14B8A6",
            isIncome: true, isTaxDeductible: false, sortOrder: 202,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Contract Work", icon: "signature", colorHex: "3B82F6",
            isIncome: true, isTaxDeductible: false, sortOrder: 203,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Consulting Income", icon: "briefcase.fill", colorHex: "10B981",
            isIncome: true, isTaxDeductible: false, sortOrder: 204,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Product Sales", icon: "shippingbox.fill", colorHex: "3B82F6",
            isIncome: true, isTaxDeductible: false, sortOrder: 205,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Side Gig", icon: "star.fill", colorHex: "F59E0B",
            isIncome: true, isTaxDeductible: false, sortOrder: 206,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Affiliate Income", icon: "link.circle.fill", colorHex: "8B5CF6",
            isIncome: true, isTaxDeductible: false, sortOrder: 207,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Commission Income", icon: "percent", colorHex: "22C55E",
            isIncome: true, isTaxDeductible: false, sortOrder: 208,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Service Revenue", icon: "briefcase.fill", colorHex: "3B82F6",
            isIncome: true, isTaxDeductible: false, sortOrder: 209,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Resale / Wholesale", icon: "shippingbox.fill", colorHex: "F97316",
            isIncome: true, isTaxDeductible: false, sortOrder: 210,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Sponsorship Income", icon: "star.circle.fill", colorHex: "FBBF24",
            isIncome: true, isTaxDeductible: false, sortOrder: 211,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Grants & Awards", icon: "trophy.fill", colorHex: "F59E0B",
            isIncome: true, isTaxDeductible: false, sortOrder: 212,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // Passive business income
        DefaultCategory(name: "Rental Income (Business)", icon: "building.fill", colorHex: "F97316",
            isIncome: true, isTaxDeductible: false, sortOrder: 213,
            isBusiness: true, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Royalties", icon: "music.note.list", colorHex: "EC4899",
            isIncome: true, isTaxDeductible: false, sortOrder: 214,
            isBusiness: true, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Interest Income (Business)", icon: "percent", colorHex: "10B981",
            isIncome: true, isTaxDeductible: false, sortOrder: 215,
            isBusiness: true, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // Tax exempt business income
        DefaultCategory(name: "Refunds Received", icon: "arrow.uturn.backward.circle.fill", colorHex: "06B6D4",
            isIncome: true, isTaxDeductible: false, sortOrder: 216,
            isBusiness: true, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),

        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        // MARK: Personal Income Categories (18 total)
        // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        // W-2 income — employer withholds; no SE tax
        DefaultCategory(name: "Salary/Wages", icon: "banknote.fill", colorHex: "22C55E",
            isIncome: true, isTaxDeductible: false, sortOrder: 251,
            isBusiness: false, taxTreatment: .w2WithholdingPaid, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Spouse's Salary / W-2", icon: "person.2.fill", colorHex: "22C55E",
            isIncome: true, isTaxDeductible: false, sortOrder: 252,
            isBusiness: false, taxTreatment: .w2WithholdingPaid, taxOwner: .spouse, scheduleCLine: nil),
        DefaultCategory(name: "Bonus Income", icon: "sparkles", colorHex: "F97316",
            isIncome: true, isTaxDeductible: false, sortOrder: 253,
            isBusiness: false, taxTreatment: .w2WithholdingPaid, taxOwner: .primary, scheduleCLine: nil),

        // Self-employment personal income
        DefaultCategory(name: "Side Hustle Income", icon: "star.fill", colorHex: "F59E0B",
            isIncome: true, isTaxDeductible: false, sortOrder: 254,
            isBusiness: false, taxTreatment: .selfEmployment, taxOwner: .primary, scheduleCLine: nil),

        // Passive income — no SE tax, no withholding
        DefaultCategory(name: "Investment Income", icon: "chart.line.uptrend.xyaxis", colorHex: "6366F1",
            isIncome: true, isTaxDeductible: false, sortOrder: 255,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Interest Income (Savings)", icon: "percent", colorHex: "14B8A6",
            isIncome: true, isTaxDeductible: false, sortOrder: 256,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Dividend Income", icon: "chart.bar.fill", colorHex: "6366F1",
            isIncome: true, isTaxDeductible: false, sortOrder: 257,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Capital Gains", icon: "chart.line.uptrend.xyaxis", colorHex: "22C55E",
            isIncome: true, isTaxDeductible: false, sortOrder: 258,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Rental Income (Personal)", icon: "building.fill", colorHex: "A855F7",
            isIncome: true, isTaxDeductible: false, sortOrder: 259,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Retirement Income", icon: "banknote.fill", colorHex: "F59E0B",
            isIncome: true, isTaxDeductible: false, sortOrder: 260,
            isBusiness: false, taxTreatment: .passiveIncome, taxOwner: .primary, scheduleCLine: nil),

        // Tax exempt — excluded from all calculations
        DefaultCategory(name: "Refunds & Reimbursements", icon: "arrow.uturn.backward.circle.fill", colorHex: "06B6D4",
            isIncome: true, isTaxDeductible: false, sortOrder: 261,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Disability Income", icon: "heart.text.square.fill", colorHex: "EF4444",
            isIncome: true, isTaxDeductible: false, sortOrder: 262,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Social Security", icon: "person.badge.shield.checkmark.fill", colorHex: "3B82F6",
            isIncome: true, isTaxDeductible: false, sortOrder: 263,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Alimony (Received)", icon: "arrow.down.circle.fill", colorHex: "8B5CF6",
            isIncome: true, isTaxDeductible: false, sortOrder: 264,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Child Support (Received)", icon: "figure.2.and.child.holdinghands", colorHex: "06B6D4",
            isIncome: true, isTaxDeductible: false, sortOrder: 265,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Gift / Inheritance", icon: "gift.fill", colorHex: "EC4899",
            isIncome: true, isTaxDeductible: false, sortOrder: 266,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Insurance Payouts", icon: "shield.lefthalf.filled", colorHex: "0EA5E9",
            isIncome: true, isTaxDeductible: false, sortOrder: 267,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Tax Refund", icon: "arrow.uturn.backward.circle.fill", colorHex: "10B981",
            isIncome: true, isTaxDeductible: false, sortOrder: 268,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),

        // v4.1: Military, VA, & Education — tax-exempt income categories
        DefaultCategory(name: "Military Retirement Pay", icon: "shield.checkered", colorHex: "475569",
            isIncome: true, isTaxDeductible: false, sortOrder: 269,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "VA Disability", icon: "cross.circle.fill", colorHex: "DC2626",
            isIncome: true, isTaxDeductible: false, sortOrder: 270,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Pell Grant", icon: "graduationcap.fill", colorHex: "3B82F6",
            isIncome: true, isTaxDeductible: false, sortOrder: 271,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "GI Bill / Education Benefits", icon: "book.circle.fill", colorHex: "6366F1",
            isIncome: true, isTaxDeductible: false, sortOrder: 272,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
        DefaultCategory(name: "Scholarships & Fellowships", icon: "medal.fill", colorHex: "F59E0B",
            isIncome: true, isTaxDeductible: false, sortOrder: 273,
            isBusiness: false, taxTreatment: .taxExempt, taxOwner: .primary, scheduleCLine: nil),
    ]

    // MARK: - Public Seeding

    /// Seeds default categories if none exist. Idempotent — safe to call multiple times.
    @discardableResult
    static func seedDefaultCategories(in context: ModelContext) -> Result<Int, SeedError> {
        do {
            let existing = try context.fetch(FetchDescriptor<Category>())
            guard existing.isEmpty else {
                return .success(0) // Already seeded
            }
        } catch {
            return .failure(.fetchFailed(error))
        }

        var count = 0
        for dc in defaults {
            let category = Category(
                name: dc.name,
                icon: dc.icon,
                colorHex: dc.colorHex,
                isDefault: true,
                isIncome: dc.isIncome,
                isTaxDeductible: dc.isTaxDeductible,
                isBusiness: dc.isBusiness,
                taxTreatment: dc.taxTreatment,
                taxOwner: dc.taxOwner,
                scheduleCLine: dc.scheduleCLine
            )
            context.insert(category)
            count += 1
        }

        do {
            try context.save()
            seededVersion = version
            print("✅ SeedData v\(version): Seeded \(count) default categories")
            return .success(count)
        } catch {
            return .failure(.saveFailed(error))
        }
    }

    // MARK: - Migration

    /// Runs all pending migrations. Idempotent — safe to call on every app launch.
    ///
    /// v2.4: "doc.badge.fill" → "signature" (invalid SF Symbol fix)
    /// v2.5: Removes duplicate categories (keeps first)
    /// v2.6: Adds missing "Gas" category
    /// v2.7: Back-fills isBusiness and taxTreatment for pre-v2.7 installs (runs once)
    /// v3.0: Back-fills scheduleCLine and adds 4 new categories for pre-v3.0 installs (runs once)
    /// v4.0: Adds ~105 granular categories for existing users (runs once)
    static func migrateCategories(in context: ModelContext) {
        let iconMigrations: [String: String] = [
            "doc.badge.fill": "signature",       // v2.4
            "car.badge.checkmark": "car.circle.fill",  // v4.0: invalid SF Symbol fix
        ]

        // Quick unconditional icon fix — catches icons from any prior migration
        // Only touches categories with known-bad icons; runs every launch but is O(n) cheap.
        do {
            let allCats = try context.fetch(FetchDescriptor<Category>())
            for cat in allCats {
                if let replacement = iconMigrations[cat.icon] {
                    cat.icon = replacement
                    print("🔄 SeedData: Fixed icon '\(cat.icon)' for '\(cat.name)'")
                }
            }
        } catch { /* non-fatal — guarded migrations below will catch anything missed */ }

        // v3.14: The previous "missing category" pass hardcoded 5 specific names.
        // It's now replaced by a walk of the full `defaults` array below — any
        // default that isn't present locally gets restored. Names already on
        // device (defaults or user-created with overlapping names) are left
        // untouched, so user customizations stay intact.

        do {
            let categories = try context.fetch(FetchDescriptor<Category>())
            var migratedCount    = 0
            var duplicatesRemoved = 0
            var categoriesAdded  = 0

            // ── v2.5+: Duplicate removal (always runs, relationship-safe) ──
            //
            // Pre-v3.13 this was gated by `iconMigrationKey` and ran once per
            // device — duplicates that accumulated AFTER that (CloudKit sync
            // races, re-install cycles) were stuck forever.
            //
            // v3.13.1 CRITICAL FIX: before v3.13.1 this deleted duplicate
            // Categories directly. Category→Budget and Category→RecurringTransaction
            // use `.cascade` delete rules, so each duplicate deletion silently
            // destroyed the user's Budgets and RecurringTransactions (and the
            // RecurringTransaction cascade took its generated Transactions with
            // it). One beta user lost 10+ budgets and 9 recurring templates.
            //
            // The safe pattern is: find the keeper (first occurrence by name),
            // re-point every Budget / RecurringTransaction / Transaction / Bill /
            // Vendor that references a duplicate to the keeper, SAVE to persist
            // the new pointers, and only then delete the duplicate Categories.
            var keepersByName: [String: Category] = [:]
            var toDelete: [Category] = []
            var budgetsReassigned = 0
            var recurringReassigned = 0
            var transactionsReassigned = 0
            var billsReassigned = 0
            var vendorsReassigned = 0

            for category in categories {
                if let keeper = keepersByName[category.name] {
                    // Budgets — CASCADE delete rule, MUST reassign or they die.
                    if let budgets = category.budgets {
                        for budget in budgets where budget.category !== keeper {
                            budget.category = keeper
                            budgetsReassigned += 1
                        }
                    }
                    // Recurring transactions — CASCADE, and their delete further
                    // cascades to generated Transactions. Reassignment is critical.
                    if let recurrings = category.recurringTransactions {
                        for r in recurrings where r.category !== keeper {
                            r.category = keeper
                            recurringReassigned += 1
                        }
                    }
                    // Transactions — NULLIFY, but reassigning preserves their
                    // classification rather than orphaning them.
                    if let txns = category.transactions {
                        for t in txns where t.category !== keeper {
                            t.category = keeper
                            transactionsReassigned += 1
                        }
                    }
                    // Bills — NULLIFY, reassigned for the same reason.
                    if let bills = category.bills {
                        for b in bills where b.category !== keeper {
                            b.category = keeper
                            billsReassigned += 1
                        }
                    }
                    // Vendors — NULLIFY, reassigned for the same reason.
                    if let vendors = category.defaultForVendors {
                        for v in vendors where v.defaultCategory !== keeper {
                            v.defaultCategory = keeper
                            vendorsReassigned += 1
                        }
                    }
                    toDelete.append(category)
                    duplicatesRemoved += 1
                } else {
                    keepersByName[category.name] = category
                }
            }

            // Persist reassignments BEFORE any delete — otherwise a crash or
            // early return mid-loop could leave stale pointers whose cascade
            // rule fires on next launch and destroys the data we just saved.
            if !toDelete.isEmpty {
                do {
                    try context.save()
                } catch {
                    print("❌ SeedData: Failed to save reassignments before dedup — ABORTING to avoid data loss: \(error)")
                    // Bail out of dedup entirely. The duplicates remain but no
                    // data is destroyed; user can retry next launch.
                    return
                }
            }

            for cat in toDelete {
                print("🗑️ SeedData: Removing duplicate '\(cat.name)' (relationships reassigned to keeper)")
                context.delete(cat)
            }
            if duplicatesRemoved > 0 {
                print("🔄 SeedData: Reassigned \(budgetsReassigned) budget(s), \(recurringReassigned) recurring txn(s), \(transactionsReassigned) transaction(s), \(billsReassigned) bill(s), \(vendorsReassigned) vendor(s) before deletion")
            }

            // Mark the one-shot icon-migration flag so earlier versions of the
            // app on this device don't re-run the (now redundant) legacy icon
            // pass. Kept for backward compat with the existing UserDefaults key.
            if !UserDefaults.standard.bool(forKey: iconMigrationKey) {
                UserDefaults.standard.set(true, forKey: iconMigrationKey)
            }

            // ── v3.14: Restore any missing default categories ──
            //
            // Walks the full `defaults` array (147 entries) and re-inserts any
            // whose name isn't present locally. Pre-v3.14 this only checked 5
            // hardcoded names (Gas, Commissions & Fees, Repairs & Maintenance,
            // Taxes & Licenses, Supplies); a user who lost defaults beyond that
            // set — e.g. via the dedup-cascade incident on April 23 — had no
            // path to recover them. Now any missing default name is restored
            // with its correct icon, color, isBusiness, isIncome,
            // taxTreatment, taxOwner, and Schedule C line.
            //
            // Guarded by `missingCategoriesKey` (bumped from v26 to v40 so it
            // runs exactly once for every existing install). User-created
            // categories and any defaults already present are left untouched.
            if !UserDefaults.standard.bool(forKey: missingCategoriesKey) {
                // After dedup, keepersByName holds every surviving category by name.
                let seenNames = Set(keepersByName.keys)
                var restoredNames: [String] = []
                for dc in defaults {
                    guard !seenNames.contains(dc.name) else { continue }
                    let newCat = Category(
                        name:            dc.name,
                        icon:             dc.icon,
                        colorHex:        dc.colorHex,
                        isDefault:       true,
                        isIncome:        dc.isIncome,
                        isTaxDeductible: dc.isTaxDeductible,
                        isBusiness:      dc.isBusiness,
                        taxTreatment:    dc.taxTreatment,
                        taxOwner:        dc.taxOwner,
                        scheduleCLine:   dc.scheduleCLine
                    )
                    context.insert(newCat)
                    categoriesAdded += 1
                    restoredNames.append(dc.name)
                    print("➕ SeedData: Restored missing default '\(dc.name)'")
                }

                if categoriesAdded > 0 {
                    print("✅ SeedData v4: Restored \(categoriesAdded) missing default categor\(categoriesAdded == 1 ? "y" : "ies")")
                } else {
                    print("✅ SeedData v4: All \(defaults.count) default categories already present")
                }

                UserDefaults.standard.set(true, forKey: missingCategoriesKey)
            }

            // ── v2.7: Back-fill isBusiness and taxTreatment ───────────
            if !UserDefaults.standard.bool(forKey: taxTreatmentMigrationKey) {

                var businessByName: [String: Bool]          = [:]
                var treatmentByName: [String: TaxTreatment] = [:]

                for dc in defaults {
                    businessByName[dc.name]  = dc.isBusiness
                    treatmentByName[dc.name] = dc.taxTreatment
                }

                let postDeleteCategories = try context.fetch(FetchDescriptor<Category>())
                var taxMigrated = 0

                for category in postDeleteCategories {
                    var changed = false

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

                UserDefaults.standard.set(true, forKey: taxTreatmentMigrationKey)

                if taxMigrated > 0 {
                    migratedCount += taxMigrated
                    print("✅ SeedData v2.7: Back-filled \(taxMigrated) category classification(s)")
                } else {
                    print("✅ SeedData v2.7: Tax treatment migration — no changes needed")
                }
            }

            // ── v3.0: Back-fill scheduleCLine ─────────────────────────
            //
            // Maps known default category names to their correct Schedule C line.
            // Only runs once per device (guarded by UserDefaults flag).
            // User-created categories are left untouched (nil scheduleCLine).
            if !UserDefaults.standard.bool(forKey: scheduleCMigrationKey) {

                var scheduleCByName: [String: ScheduleCLine] = [:]
                for dc in defaults {
                    if let line = dc.scheduleCLine {
                        scheduleCByName[dc.name] = line
                    }
                }

                let allCategories = try context.fetch(FetchDescriptor<Category>())
                var scheduleCMigrated = 0

                for category in allCategories {
                    if let line = scheduleCByName[category.name],
                       category.scheduleCLine != line {
                        category.scheduleCLine = line
                        scheduleCMigrated += 1
                        print("🔄 SeedData v3.0: Assigned \(line.badgeLabel) to '\(category.name)'")
                    }
                }

                UserDefaults.standard.set(true, forKey: scheduleCMigrationKey)

                if scheduleCMigrated > 0 {
                    migratedCount += scheduleCMigrated
                    print("✅ SeedData v3.0: Back-filled \(scheduleCMigrated) Schedule C line(s)")
                } else {
                    print("✅ SeedData v3.0: Schedule C migration — no changes needed")
                }
            }

            // ── v3.12: Fix Plaid transaction income/expense inversion ──
            //
            // Build 7 had a bug where Transaction.fromPlaid() used `amount > 0`
            // to set isIncome, but Plaid convention is positive = expense,
            // negative = income. This flips isIncome on all Plaid-imported
            // transactions so expenses show as expenses and income as income.
            // Runs once per device (UserDefaults guard).
            if !UserDefaults.standard.bool(forKey: plaidIncomeFixKey) {
                let allTransactions = try context.fetch(FetchDescriptor<Transaction>())
                let plaidTransactions = allTransactions.filter { $0.importSource == .plaid }

                if !plaidTransactions.isEmpty {
                    var flipped = 0

                    for transaction in plaidTransactions {
                        transaction.isIncome = !transaction.isIncome
                        flipped += 1
                    }

                    migratedCount += flipped
                    print("✅ SeedData v3.12: Flipped isIncome on \(flipped) Plaid transaction(s)")
                } else {
                    print("✅ SeedData v3.12: No Plaid transactions to fix")
                }

                UserDefaults.standard.set(true, forKey: plaidIncomeFixKey)
            }

            // ── v4.0: Add granular categories for existing users ────
            //
            // Build 8 expanded defaults from 37 → 142 categories.
            // This adds any default category that doesn't already exist by name.
            // Existing categories (including old generics like "Transportation",
            // "Healthcare", "Utilities (Personal)") are left untouched —
            // users can keep them or delete them at their discretion.
            //
            // Also fixes car.badge.checkmark → car.circle.fill (invalid SF Symbol)
            // on categories that may have been created with the bad icon.
            if !UserDefaults.standard.bool(forKey: granularCategoriesV40Key) {

                let allCats = try context.fetch(FetchDescriptor<Category>())
                var existingNames = Set<String>()
                for cat in allCats {
                    existingNames.insert(cat.name)
                    // Fix invalid SF Symbol that may have been seeded before this fix
                    if cat.icon == "car.badge.checkmark" {
                        cat.icon = "car.circle.fill"
                        migratedCount += 1
                        print("🔄 SeedData v4.0: Fixed icon for '\(cat.name)'")
                    }
                }

                var v4Added = 0
                for dc in defaults where !existingNames.contains(dc.name) {
                    let cat = Category(
                        name:            dc.name,
                        icon:            dc.icon,
                        colorHex:        dc.colorHex,
                        isDefault:       true,
                        isIncome:        dc.isIncome,
                        isTaxDeductible: dc.isTaxDeductible,
                        isBusiness:      dc.isBusiness,
                        taxTreatment:    dc.taxTreatment,
                        taxOwner:        dc.taxOwner,
                        scheduleCLine:   dc.scheduleCLine
                    )
                    context.insert(cat)
                    v4Added += 1
                }

                UserDefaults.standard.set(true, forKey: granularCategoriesV40Key)

                if v4Added > 0 {
                    categoriesAdded += v4Added
                    print("✅ SeedData v4.0: Added \(v4Added) granular categories for existing user")
                } else {
                    print("✅ SeedData v4.0: All categories already present")
                }
            }

            // ── v4.1: Add military, VA, & education categories ────────
            //
            // Build 9 adds 5 tax-exempt income categories for military/VA/education
            // users whose income was being incorrectly taxed by the CPA report.
            if !UserDefaults.standard.bool(forKey: militaryVAEducationV41Key) {

                let allCats41 = try context.fetch(FetchDescriptor<Category>())
                var existingNames41 = Set<String>()
                for cat in allCats41 { existingNames41.insert(cat.name) }

                let newV41Categories: [(name: String, icon: String, colorHex: String, sortOrder: Int)] = [
                    ("Military Retirement Pay", "shield.checkered",   "475569", 269),
                    ("VA Disability",           "cross.circle.fill",  "DC2626", 270),
                    ("Pell Grant",              "graduationcap.fill",  "3B82F6", 271),
                    ("GI Bill / Education Benefits", "book.circle.fill", "6366F1", 272),
                    ("Scholarships & Fellowships",   "medal.fill",     "F59E0B", 273),
                ]

                var v41Added = 0
                for entry in newV41Categories where !existingNames41.contains(entry.name) {
                    let cat = Category(
                        name:            entry.name,
                        icon:            entry.icon,
                        colorHex:        entry.colorHex,
                        isDefault:       true,
                        isIncome:        true,
                        isTaxDeductible: false,
                        isBusiness:      false,
                        taxTreatment:    .taxExempt,
                        taxOwner:        .primary,
                        scheduleCLine:   nil
                    )
                    context.insert(cat)
                    v41Added += 1
                }

                UserDefaults.standard.set(true, forKey: militaryVAEducationV41Key)

                if v41Added > 0 {
                    categoriesAdded += v41Added
                    print("✅ SeedData v4.1: Added \(v41Added) military/VA/education categories")
                } else {
                    print("✅ SeedData v4.1: All military/VA/education categories already present")
                }
            }

            // ── v4.2: Fix isBusiness on legacy generic categories ─────
            //
            // Pre-Build-8 seeds created generic "Insurance", "Utilities",
            // "Internet & Phone" as business expenses but with isBusiness = false
            // (the flag didn't exist yet / defaulted to false).
            // The v2.7 migration didn't fix them because those names were replaced
            // by granular entries in the `defaults` array and no longer matched.
            // This marks them correctly so they stop appearing in Personal lists.
            if !UserDefaults.standard.bool(forKey: legacyBusinessFixKey) {

                let legacyBusinessNames: Set<String> = [
                    "Insurance", "Utilities", "Internet & Phone",
                    "Vehicle Expenses", "Transportation"
                ]

                let allCats42 = try context.fetch(FetchDescriptor<Category>())
                var legacyFixed = 0

                for cat in allCats42 {
                    if legacyBusinessNames.contains(cat.name) && !cat.isBusiness && !cat.isIncome {
                        cat.isBusiness = true
                        cat.isTaxDeductible = true
                        legacyFixed += 1
                        print("🔄 SeedData v4.2: Fixed isBusiness for legacy '\(cat.name)'")
                    }
                }

                UserDefaults.standard.set(true, forKey: legacyBusinessFixKey)

                if legacyFixed > 0 {
                    migratedCount += legacyFixed
                    print("✅ SeedData v4.2: Fixed \(legacyFixed) legacy business category(ies)")
                } else {
                    print("✅ SeedData v4.2: No legacy business categories to fix")
                }
            }

            // ── Save if anything changed ──────────────────────────────
            if migratedCount > 0 || duplicatesRemoved > 0 || categoriesAdded > 0 {
                try context.save()
                if duplicatesRemoved > 0 { print("✅ SeedData: Removed \(duplicatesRemoved) duplicate(s)") }
                if categoriesAdded > 0   { print("✅ SeedData: Added \(categoriesAdded) new category/categories") }
                if migratedCount > 0     { print("✅ SeedData: Migrated \(migratedCount) category/categories") }
            } else {
                print("✅ SeedData: No migration needed")
            }

        } catch {
            print("❌ SeedData migration failed: \(error.localizedDescription)")
        }
    }
}
