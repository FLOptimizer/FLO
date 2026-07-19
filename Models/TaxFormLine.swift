//  TaxFormLine.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 — Multi-form IRS tax line mapping
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Extends FLO's tax awareness beyond Schedule C to cover Form 1065 (partnerships),
//  Schedule F (farms), and Schedule E (rental). Works alongside the existing
//  ScheduleCLine enum — fully backward compatible.
//
//  The ExpenseConcept enum maps shared expense categories across all forms,
//  enabling a single category to resolve to the correct form line based on
//  the business type.
//

import Foundation

// MARK: - Tax Form Type

/// Identifies which IRS form a tax line belongs to.
enum TaxFormType: String, Codable, CaseIterable, Identifiable {
    case scheduleC  = "scheduleC"
    case form1065   = "form1065"
    case scheduleF  = "scheduleF"
    case scheduleE  = "scheduleE"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scheduleC: return "Schedule C"
        case .form1065:  return "Form 1065"
        case .scheduleF: return "Schedule F"
        case .scheduleE: return "Schedule E"
        }
    }

    var formTitle: String {
        switch self {
        case .scheduleC: return "Profit or Loss From Business"
        case .form1065:  return "U.S. Return of Partnership Income"
        case .scheduleF: return "Profit or Loss From Farming"
        case .scheduleE: return "Supplemental Income and Loss"
        }
    }

    /// Maps from BusinessType to the correct form type.
    static func formType(for businessType: BusinessType) -> TaxFormType {
        switch businessType {
        case .soleProprietorship, .other: return .scheduleC
        case .llc, .partnership:          return .form1065
        case .farm:                       return .scheduleF
        case .rentalProperty:             return .scheduleE
        }
    }
}

// MARK: - Tax Form Line

/// Unified tax form line mapping covering Schedule C, Form 1065, Schedule F, and Schedule E.
/// Each case encodes both the form type and specific line number.
///
/// Raw values use a prefix convention: "schC_", "1065_", "schF_", "schE_"
/// This allows a single `taxFormLineRaw: String?` field on Category to identify
/// both the form and the line.
enum TaxFormLine: String, Codable, CaseIterable, Comparable, Identifiable {

    var id: String { rawValue }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: Schedule C Lines (Profit or Loss From Business)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Income
    case schC_line1_grossReceipts       = "schC_line1"
    case schC_line6_otherIncome         = "schC_line6"

    // Expenses
    case schC_line8_advertising         = "schC_line8"
    case schC_line9_carAndTruck         = "schC_line9"
    case schC_line10_commissionsAndFees = "schC_line10"
    case schC_line11_contractLabor      = "schC_line11"
    case schC_line12_depletion          = "schC_line12"
    case schC_line13_depreciation       = "schC_line13"
    case schC_line14_employeeBenefits   = "schC_line14"
    case schC_line15_insurance          = "schC_line15"
    case schC_line16a_mortgageBanks     = "schC_line16a"
    case schC_line16b_mortgageOther     = "schC_line16b"
    case schC_line17_legalProfessional  = "schC_line17"
    case schC_line18_officeExpense      = "schC_line18"
    case schC_line19_pensionProfitShare = "schC_line19"
    case schC_line20a_rentEquipment     = "schC_line20a"
    case schC_line20b_rentProperty      = "schC_line20b"
    case schC_line21_repairsMaintenance = "schC_line21"
    case schC_line22_supplies           = "schC_line22"
    case schC_line23_taxesAndLicenses   = "schC_line23"
    case schC_line24a_travel            = "schC_line24a"
    case schC_line24b_meals             = "schC_line24b"
    case schC_line25_utilities          = "schC_line25"
    case schC_line26_wages              = "schC_line26"
    case schC_line27a_otherExpenses     = "schC_line27a"
    case schC_line30_businessUseOfHome  = "schC_line30"

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: Form 1065 Lines (U.S. Return of Partnership Income)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Income
    case f1065_line1a_grossReceipts       = "1065_line1a"
    case f1065_line4_ordinaryGainLoss     = "1065_line4"
    case f1065_line7_otherIncome          = "1065_line7"

    // Deductions
    case f1065_line9_salariesWages        = "1065_line9"
    case f1065_line10_guaranteedPayments  = "1065_line10"
    case f1065_line11_repairsMaintenance  = "1065_line11"
    case f1065_line12_badDebts            = "1065_line12"
    case f1065_line13_rentProperty        = "1065_line13"
    case f1065_line14_taxesAndLicenses    = "1065_line14"
    case f1065_line15_interest            = "1065_line15"
    case f1065_line16a_depreciation       = "1065_line16a"
    case f1065_line17_depletion           = "1065_line17"
    case f1065_line18_retirement          = "1065_line18"
    case f1065_line19_employeeBenefits    = "1065_line19"
    case f1065_line20_otherDeductions     = "1065_line20"

    // Cost of Goods Sold (Form 1125-A)
    case f1065_cogs                       = "1065_cogs"

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: Schedule F Lines (Profit or Loss From Farming)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Income
    case schF_line1a_salesLivestock       = "schF_line1a"
    case schF_line2_coopDistributions     = "schF_line2"
    case schF_line3a_agPayments           = "schF_line3a"
    case schF_line4a_cccLoans             = "schF_line4a"
    case schF_line5a_cropInsurance        = "schF_line5a"
    case schF_line6_customHire            = "schF_line6"
    case schF_line8_otherFarmIncome       = "schF_line8"

    // Expenses
    case schF_line10_carAndTruck          = "schF_line10"
    case schF_line11_chemicals            = "schF_line11"
    case schF_line12_conservation         = "schF_line12"
    case schF_line13_customHire           = "schF_line13"
    case schF_line14_depreciation         = "schF_line14"
    case schF_line15_employeeBenefits     = "schF_line15"
    case schF_line16_feed                 = "schF_line16"
    case schF_line17_fertilizers          = "schF_line17"
    case schF_line18_freight              = "schF_line18"
    case schF_line19_fuel                 = "schF_line19"
    case schF_line20_insurance            = "schF_line20"
    case schF_line21a_mortgageInterest    = "schF_line21a"
    case schF_line21b_otherInterest       = "schF_line21b"
    case schF_line22_labor                = "schF_line22"
    case schF_line23_pension              = "schF_line23"
    case schF_line24a_rentEquipment       = "schF_line24a"
    case schF_line24b_rentProperty        = "schF_line24b"
    case schF_line25_repairsMaintenance   = "schF_line25"
    case schF_line26_seeds                = "schF_line26"
    case schF_line27_storage              = "schF_line27"
    case schF_line28_supplies             = "schF_line28"
    case schF_line29_taxesLicenses        = "schF_line29"
    case schF_line30_utilities            = "schF_line30"
    case schF_line31_vet                  = "schF_line31"
    case schF_line32a_otherExpenses       = "schF_line32a"

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: Schedule E Lines (Supplemental Income and Loss)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // Income
    case schE_line3_rents                 = "schE_line3"
    case schE_line4_royalties             = "schE_line4"

    // Expenses
    case schE_line5_advertising           = "schE_line5"
    case schE_line6_auto                  = "schE_line6"
    case schE_line7_cleaning              = "schE_line7"
    case schE_line8_commissions           = "schE_line8"
    case schE_line9_insurance             = "schE_line9"
    case schE_line10_legal                = "schE_line10"
    case schE_line11_management           = "schE_line11"
    case schE_line12_mortgage             = "schE_line12"
    case schE_line13_otherInterest        = "schE_line13"
    case schE_line14_repairs              = "schE_line14"
    case schE_line15_supplies             = "schE_line15"
    case schE_line16_taxes                = "schE_line16"
    case schE_line17_utilities            = "schE_line17"
    case schE_line18_depreciation         = "schE_line18"
    case schE_line19_other                = "schE_line19"

    // MARK: - Comparable

    private var sortKey: (Int, Double) {
        let formOrder: Int
        switch formType {
        case .scheduleC: formOrder = 0
        case .form1065:  formOrder = 1
        case .scheduleF: formOrder = 2
        case .scheduleE: formOrder = 3
        }

        // Extract numeric portion from raw value after prefix
        let lineString = rawValue
            .replacingOccurrences(of: "schC_line", with: "")
            .replacingOccurrences(of: "1065_line", with: "")
            .replacingOccurrences(of: "1065_cogs", with: "99")
            .replacingOccurrences(of: "schF_line", with: "")
            .replacingOccurrences(of: "schE_line", with: "")

        if lineString.hasSuffix("a") {
            return (formOrder, (Double(lineString.dropLast()) ?? 0) + 0.1)
        } else if lineString.hasSuffix("b") {
            return (formOrder, (Double(lineString.dropLast()) ?? 0) + 0.2)
        }
        return (formOrder, Double(lineString) ?? 0)
    }

    static func < (lhs: TaxFormLine, rhs: TaxFormLine) -> Bool {
        let l = lhs.sortKey, r = rhs.sortKey
        if l.0 != r.0 { return l.0 < r.0 }
        return l.1 < r.1
    }

    // MARK: - Properties

    /// Which IRS form this line belongs to.
    var formType: TaxFormType {
        if rawValue.hasPrefix("schC_") { return .scheduleC }
        if rawValue.hasPrefix("1065_") { return .form1065 }
        if rawValue.hasPrefix("schF_") { return .scheduleF }
        if rawValue.hasPrefix("schE_") { return .scheduleE }
        return .scheduleC
    }

    /// IRS line number string (e.g., "Line 8", "Line 16a").
    var lineNumber: String {
        switch self {
        // Schedule C
        case .schC_line1_grossReceipts:       return "Line 1"
        case .schC_line6_otherIncome:         return "Line 6"
        case .schC_line8_advertising:         return "Line 8"
        case .schC_line9_carAndTruck:         return "Line 9"
        case .schC_line10_commissionsAndFees: return "Line 10"
        case .schC_line11_contractLabor:      return "Line 11"
        case .schC_line12_depletion:          return "Line 12"
        case .schC_line13_depreciation:       return "Line 13"
        case .schC_line14_employeeBenefits:   return "Line 14"
        case .schC_line15_insurance:          return "Line 15"
        case .schC_line16a_mortgageBanks:     return "Line 16a"
        case .schC_line16b_mortgageOther:     return "Line 16b"
        case .schC_line17_legalProfessional:  return "Line 17"
        case .schC_line18_officeExpense:      return "Line 18"
        case .schC_line19_pensionProfitShare: return "Line 19"
        case .schC_line20a_rentEquipment:     return "Line 20a"
        case .schC_line20b_rentProperty:      return "Line 20b"
        case .schC_line21_repairsMaintenance: return "Line 21"
        case .schC_line22_supplies:           return "Line 22"
        case .schC_line23_taxesAndLicenses:   return "Line 23"
        case .schC_line24a_travel:            return "Line 24a"
        case .schC_line24b_meals:             return "Line 24b"
        case .schC_line25_utilities:          return "Line 25"
        case .schC_line26_wages:              return "Line 26"
        case .schC_line27a_otherExpenses:     return "Line 27a"
        case .schC_line30_businessUseOfHome:  return "Line 30"

        // Form 1065
        case .f1065_line1a_grossReceipts:      return "Line 1a"
        case .f1065_line4_ordinaryGainLoss:    return "Line 4"
        case .f1065_line7_otherIncome:         return "Line 7"
        case .f1065_line9_salariesWages:       return "Line 9"
        case .f1065_line10_guaranteedPayments: return "Line 10"
        case .f1065_line11_repairsMaintenance: return "Line 11"
        case .f1065_line12_badDebts:           return "Line 12"
        case .f1065_line13_rentProperty:       return "Line 13"
        case .f1065_line14_taxesAndLicenses:   return "Line 14"
        case .f1065_line15_interest:           return "Line 15"
        case .f1065_line16a_depreciation:      return "Line 16a"
        case .f1065_line17_depletion:          return "Line 17"
        case .f1065_line18_retirement:         return "Line 18"
        case .f1065_line19_employeeBenefits:   return "Line 19"
        case .f1065_line20_otherDeductions:    return "Line 20"
        case .f1065_cogs:                      return "COGS"

        // Schedule F
        case .schF_line1a_salesLivestock:     return "Line 1a"
        case .schF_line2_coopDistributions:   return "Line 2"
        case .schF_line3a_agPayments:         return "Line 3a"
        case .schF_line4a_cccLoans:           return "Line 4a"
        case .schF_line5a_cropInsurance:      return "Line 5a"
        case .schF_line6_customHire:          return "Line 6"
        case .schF_line8_otherFarmIncome:     return "Line 8"
        case .schF_line10_carAndTruck:        return "Line 10"
        case .schF_line11_chemicals:          return "Line 11"
        case .schF_line12_conservation:       return "Line 12"
        case .schF_line13_customHire:         return "Line 13"
        case .schF_line14_depreciation:       return "Line 14"
        case .schF_line15_employeeBenefits:   return "Line 15"
        case .schF_line16_feed:              return "Line 16"
        case .schF_line17_fertilizers:       return "Line 17"
        case .schF_line18_freight:           return "Line 18"
        case .schF_line19_fuel:              return "Line 19"
        case .schF_line20_insurance:         return "Line 20"
        case .schF_line21a_mortgageInterest: return "Line 21a"
        case .schF_line21b_otherInterest:    return "Line 21b"
        case .schF_line22_labor:             return "Line 22"
        case .schF_line23_pension:           return "Line 23"
        case .schF_line24a_rentEquipment:    return "Line 24a"
        case .schF_line24b_rentProperty:     return "Line 24b"
        case .schF_line25_repairsMaintenance: return "Line 25"
        case .schF_line26_seeds:             return "Line 26"
        case .schF_line27_storage:           return "Line 27"
        case .schF_line28_supplies:          return "Line 28"
        case .schF_line29_taxesLicenses:     return "Line 29"
        case .schF_line30_utilities:         return "Line 30"
        case .schF_line31_vet:               return "Line 31"
        case .schF_line32a_otherExpenses:    return "Line 32a"

        // Schedule E
        case .schE_line3_rents:        return "Line 3"
        case .schE_line4_royalties:    return "Line 4"
        case .schE_line5_advertising:  return "Line 5"
        case .schE_line6_auto:         return "Line 6"
        case .schE_line7_cleaning:     return "Line 7"
        case .schE_line8_commissions:  return "Line 8"
        case .schE_line9_insurance:    return "Line 9"
        case .schE_line10_legal:       return "Line 10"
        case .schE_line11_management:  return "Line 11"
        case .schE_line12_mortgage:    return "Line 12"
        case .schE_line13_otherInterest: return "Line 13"
        case .schE_line14_repairs:     return "Line 14"
        case .schE_line15_supplies:    return "Line 15"
        case .schE_line16_taxes:       return "Line 16"
        case .schE_line17_utilities:   return "Line 17"
        case .schE_line18_depreciation: return "Line 18"
        case .schE_line19_other:       return "Line 19"
        }
    }

    /// Official IRS description for this line.
    var irsDescription: String {
        switch self {
        // Schedule C
        case .schC_line1_grossReceipts:       return "Gross receipts or sales"
        case .schC_line6_otherIncome:         return "Other income"
        case .schC_line8_advertising:         return "Advertising"
        case .schC_line9_carAndTruck:         return "Car and truck expenses"
        case .schC_line10_commissionsAndFees: return "Commissions and fees"
        case .schC_line11_contractLabor:      return "Contract labor"
        case .schC_line12_depletion:          return "Depletion"
        case .schC_line13_depreciation:       return "Depreciation and Section 179"
        case .schC_line14_employeeBenefits:   return "Employee benefit programs"
        case .schC_line15_insurance:          return "Insurance (other than health)"
        case .schC_line16a_mortgageBanks:     return "Interest (mortgage, banks)"
        case .schC_line16b_mortgageOther:     return "Interest (mortgage, other)"
        case .schC_line17_legalProfessional:  return "Legal and professional services"
        case .schC_line18_officeExpense:      return "Office expense"
        case .schC_line19_pensionProfitShare: return "Pension and profit-sharing plans"
        case .schC_line20a_rentEquipment:     return "Rent (vehicles, machinery, equipment)"
        case .schC_line20b_rentProperty:      return "Rent (other business property)"
        case .schC_line21_repairsMaintenance: return "Repairs and maintenance"
        case .schC_line22_supplies:           return "Supplies (not in office expense)"
        case .schC_line23_taxesAndLicenses:   return "Taxes and licenses"
        case .schC_line24a_travel:            return "Travel"
        case .schC_line24b_meals:             return "Deductible meals"
        case .schC_line25_utilities:          return "Utilities"
        case .schC_line26_wages:              return "Wages"
        case .schC_line27a_otherExpenses:     return "Other expenses"
        case .schC_line30_businessUseOfHome:  return "Business use of home"

        // Form 1065
        case .f1065_line1a_grossReceipts:      return "Gross receipts or sales"
        case .f1065_line4_ordinaryGainLoss:    return "Ordinary gain (loss)"
        case .f1065_line7_otherIncome:         return "Other income (loss)"
        case .f1065_line9_salariesWages:       return "Salaries and wages"
        case .f1065_line10_guaranteedPayments: return "Guaranteed payments to partners"
        case .f1065_line11_repairsMaintenance: return "Repairs and maintenance"
        case .f1065_line12_badDebts:           return "Bad debts"
        case .f1065_line13_rentProperty:       return "Rent"
        case .f1065_line14_taxesAndLicenses:   return "Taxes and licenses"
        case .f1065_line15_interest:           return "Interest"
        case .f1065_line16a_depreciation:      return "Depreciation"
        case .f1065_line17_depletion:          return "Depletion"
        case .f1065_line18_retirement:         return "Retirement plans, etc."
        case .f1065_line19_employeeBenefits:   return "Employee benefit programs"
        case .f1065_line20_otherDeductions:    return "Other deductions"
        case .f1065_cogs:                      return "Cost of goods sold (Form 1125-A)"

        // Schedule F
        case .schF_line1a_salesLivestock:     return "Sales of livestock and other resale items"
        case .schF_line2_coopDistributions:   return "Cooperative distributions"
        case .schF_line3a_agPayments:         return "Agricultural program payments"
        case .schF_line4a_cccLoans:           return "CCC loans reported under election"
        case .schF_line5a_cropInsurance:      return "Crop insurance proceeds"
        case .schF_line6_customHire:          return "Custom hire (machine work) income"
        case .schF_line8_otherFarmIncome:     return "Other farm income"
        case .schF_line10_carAndTruck:        return "Car and truck expenses"
        case .schF_line11_chemicals:          return "Chemicals"
        case .schF_line12_conservation:       return "Conservation expenses"
        case .schF_line13_customHire:         return "Custom hire (machine work)"
        case .schF_line14_depreciation:       return "Depreciation and Section 179"
        case .schF_line15_employeeBenefits:   return "Employee benefit programs"
        case .schF_line16_feed:              return "Feed"
        case .schF_line17_fertilizers:       return "Fertilizers and lime"
        case .schF_line18_freight:           return "Freight and trucking"
        case .schF_line19_fuel:              return "Gasoline, fuel, and oil"
        case .schF_line20_insurance:         return "Insurance (other than health)"
        case .schF_line21a_mortgageInterest: return "Interest (mortgage)"
        case .schF_line21b_otherInterest:    return "Interest (other)"
        case .schF_line22_labor:             return "Labor hired"
        case .schF_line23_pension:           return "Pension and profit-sharing plans"
        case .schF_line24a_rentEquipment:    return "Rent (vehicles, machinery, equipment)"
        case .schF_line24b_rentProperty:     return "Rent (other property)"
        case .schF_line25_repairsMaintenance: return "Repairs and maintenance"
        case .schF_line26_seeds:             return "Seeds and plants"
        case .schF_line27_storage:           return "Storage and warehousing"
        case .schF_line28_supplies:          return "Supplies"
        case .schF_line29_taxesLicenses:     return "Taxes"
        case .schF_line30_utilities:         return "Utilities"
        case .schF_line31_vet:               return "Veterinary, breeding, and medicine"
        case .schF_line32a_otherExpenses:    return "Other farm expenses"

        // Schedule E
        case .schE_line3_rents:        return "Rents received"
        case .schE_line4_royalties:    return "Royalties received"
        case .schE_line5_advertising:  return "Advertising"
        case .schE_line6_auto:         return "Auto and travel"
        case .schE_line7_cleaning:     return "Cleaning and maintenance"
        case .schE_line8_commissions:  return "Commissions"
        case .schE_line9_insurance:    return "Insurance"
        case .schE_line10_legal:       return "Legal and other professional fees"
        case .schE_line11_management:  return "Management fees"
        case .schE_line12_mortgage:    return "Mortgage interest paid"
        case .schE_line13_otherInterest: return "Other interest"
        case .schE_line14_repairs:     return "Repairs"
        case .schE_line15_supplies:    return "Supplies"
        case .schE_line16_taxes:       return "Taxes"
        case .schE_line17_utilities:   return "Utilities"
        case .schE_line18_depreciation: return "Depreciation expense or depletion"
        case .schE_line19_other:       return "Other"
        }
    }

    /// Combined display: "Line 8 — Advertising"
    var displayName: String {
        "\(lineNumber) — \(irsDescription)"
    }

    /// Short badge label: "Ln 8"
    var badgeLabel: String {
        lineNumber.replacingOccurrences(of: "Line ", with: "Ln ")
    }

    /// Formatted for PDF reports: "Line 8 - Advertising"
    var formattedForReport: String {
        "\(lineNumber) - \(irsDescription)"
    }

    /// Default deduction rate. 1.0 = 100%, 0.5 = 50% (meals).
    var defaultDeductionRate: Double {
        switch self {
        case .schC_line24b_meals: return 0.50
        default:                 return 1.00
        }
    }

    /// Whether this is an income line vs. expense line.
    var isIncomeLine: Bool {
        switch self {
        case .schC_line1_grossReceipts, .schC_line6_otherIncome,
             .f1065_line1a_grossReceipts, .f1065_line4_ordinaryGainLoss, .f1065_line7_otherIncome,
             .schF_line1a_salesLivestock, .schF_line2_coopDistributions, .schF_line3a_agPayments,
             .schF_line4a_cccLoans, .schF_line5a_cropInsurance, .schF_line6_customHire, .schF_line8_otherFarmIncome,
             .schE_line3_rents, .schE_line4_royalties:
            return true
        default:
            return false
        }
    }

    /// Filter to expense lines only for a given form type.
    static func expenseLines(for formType: TaxFormType) -> [TaxFormLine] {
        allCases.filter { $0.formType == formType && !$0.isIncomeLine }.sorted()
    }

    /// Filter to income lines only for a given form type.
    static func incomeLines(for formType: TaxFormType) -> [TaxFormLine] {
        allCases.filter { $0.formType == formType && $0.isIncomeLine }.sorted()
    }

    /// All lines for a given form type.
    static func lines(for formType: TaxFormType) -> [TaxFormLine] {
        allCases.filter { $0.formType == formType }.sorted()
    }
}

// MARK: - Expense Concept (Cross-Form Mapping)

/// Maps shared expense/income concepts across IRS forms.
/// A single business category (e.g., "Advertising") can resolve to the correct
/// form line based on the business type.
enum ExpenseConcept: String, CaseIterable, Identifiable {

    var id: String { rawValue }

    // Income concepts
    case grossReceipts
    case otherIncome

    // Shared expense concepts
    case advertising
    case carAndTruck
    case commissionsAndFees
    case contractLabor
    case depletion
    case depreciation
    case employeeBenefits
    case insurance
    case interestMortgage
    case interestOther
    case legalProfessional
    case officeExpense
    case pension
    case rentEquipment
    case rentProperty
    case repairsMaintenance
    case supplies
    case taxesAndLicenses
    case travel
    case meals
    case utilities
    case wages
    case otherExpenses
    case businessUseOfHome
    case costOfGoodsSold

    // Farm-specific concepts
    case chemicals
    case conservation
    case customHire
    case feed
    case fertilizers
    case freight
    case fuel
    case seeds
    case storage
    case veterinary

    // Rental-specific concepts
    case cleaning
    case management

    /// Human-readable display name.
    var displayName: String {
        switch self {
        case .grossReceipts:      return "Gross Receipts / Sales"
        case .otherIncome:        return "Other Income"
        case .advertising:        return "Advertising"
        case .carAndTruck:        return "Car & Truck"
        case .commissionsAndFees: return "Commissions & Fees"
        case .contractLabor:      return "Contract Labor"
        case .depletion:          return "Depletion"
        case .depreciation:       return "Depreciation"
        case .employeeBenefits:   return "Employee Benefits"
        case .insurance:          return "Insurance"
        case .interestMortgage:   return "Interest (Mortgage)"
        case .interestOther:      return "Interest (Other)"
        case .legalProfessional:  return "Legal & Professional"
        case .officeExpense:      return "Office Expense"
        case .pension:            return "Pension / Profit-Sharing"
        case .rentEquipment:      return "Rent (Equipment)"
        case .rentProperty:       return "Rent (Property)"
        case .repairsMaintenance: return "Repairs & Maintenance"
        case .supplies:           return "Supplies"
        case .taxesAndLicenses:   return "Taxes & Licenses"
        case .travel:             return "Travel"
        case .meals:              return "Meals"
        case .utilities:          return "Utilities"
        case .wages:              return "Wages"
        case .otherExpenses:      return "Other Expenses"
        case .businessUseOfHome:  return "Business Use of Home"
        case .costOfGoodsSold:    return "Cost of Goods Sold"
        case .chemicals:          return "Chemicals"
        case .conservation:       return "Conservation"
        case .customHire:         return "Custom Hire (Machine Work)"
        case .feed:               return "Feed"
        case .fertilizers:        return "Fertilizers & Lime"
        case .freight:            return "Freight & Trucking"
        case .fuel:               return "Fuel & Oil"
        case .seeds:              return "Seeds & Plants"
        case .storage:            return "Storage & Warehousing"
        case .veterinary:         return "Veterinary & Breeding"
        case .cleaning:           return "Cleaning & Maintenance"
        case .management:         return "Management Fees"
        }
    }

    /// Returns the correct TaxFormLine for this concept on the given form type.
    /// Returns nil if the concept doesn't apply to the form (e.g., "feed" on Schedule C).
    func taxFormLine(for formType: TaxFormType) -> TaxFormLine? {
        switch (self, formType) {

        // Gross Receipts / Income
        case (.grossReceipts, .scheduleC): return .schC_line1_grossReceipts
        case (.grossReceipts, .form1065):  return .f1065_line1a_grossReceipts
        case (.grossReceipts, .scheduleF): return .schF_line1a_salesLivestock
        case (.grossReceipts, .scheduleE): return .schE_line3_rents
        case (.otherIncome, .scheduleC):   return .schC_line6_otherIncome
        case (.otherIncome, .form1065):    return .f1065_line7_otherIncome
        case (.otherIncome, .scheduleF):   return .schF_line8_otherFarmIncome
        case (.otherIncome, .scheduleE):   return .schE_line4_royalties

        // Shared Expense Concepts
        case (.advertising, .scheduleC):        return .schC_line8_advertising
        case (.advertising, .scheduleE):        return .schE_line5_advertising
        case (.advertising, .form1065):         return .f1065_line20_otherDeductions
        case (.advertising, .scheduleF):        return .schF_line32a_otherExpenses

        case (.carAndTruck, .scheduleC):        return .schC_line9_carAndTruck
        case (.carAndTruck, .scheduleF):        return .schF_line10_carAndTruck
        case (.carAndTruck, .scheduleE):        return .schE_line6_auto
        case (.carAndTruck, .form1065):         return .f1065_line20_otherDeductions

        case (.commissionsAndFees, .scheduleC): return .schC_line10_commissionsAndFees
        case (.commissionsAndFees, .scheduleE): return .schE_line8_commissions
        case (.commissionsAndFees, .form1065):  return .f1065_line20_otherDeductions
        case (.commissionsAndFees, .scheduleF): return .schF_line32a_otherExpenses

        case (.contractLabor, .scheduleC):      return .schC_line11_contractLabor
        case (.contractLabor, .form1065):       return .f1065_line20_otherDeductions
        case (.contractLabor, .scheduleF):      return .schF_line22_labor
        case (.contractLabor, .scheduleE):      return .schE_line19_other

        case (.depletion, .scheduleC):          return .schC_line12_depletion
        case (.depletion, .form1065):           return .f1065_line17_depletion
        case (.depletion, .scheduleE):          return .schE_line18_depreciation
        case (.depletion, .scheduleF):          return .schF_line32a_otherExpenses

        case (.depreciation, .scheduleC):       return .schC_line13_depreciation
        case (.depreciation, .form1065):        return .f1065_line16a_depreciation
        case (.depreciation, .scheduleF):       return .schF_line14_depreciation
        case (.depreciation, .scheduleE):       return .schE_line18_depreciation

        case (.employeeBenefits, .scheduleC):   return .schC_line14_employeeBenefits
        case (.employeeBenefits, .form1065):    return .f1065_line19_employeeBenefits
        case (.employeeBenefits, .scheduleF):   return .schF_line15_employeeBenefits
        case (.employeeBenefits, .scheduleE):   return .schE_line19_other

        case (.insurance, .scheduleC):          return .schC_line15_insurance
        case (.insurance, .form1065):           return .f1065_line20_otherDeductions
        case (.insurance, .scheduleF):          return .schF_line20_insurance
        case (.insurance, .scheduleE):          return .schE_line9_insurance

        case (.interestMortgage, .scheduleC):   return .schC_line16a_mortgageBanks
        case (.interestMortgage, .form1065):    return .f1065_line15_interest
        case (.interestMortgage, .scheduleF):   return .schF_line21a_mortgageInterest
        case (.interestMortgage, .scheduleE):   return .schE_line12_mortgage

        case (.interestOther, .scheduleC):      return .schC_line16b_mortgageOther
        case (.interestOther, .form1065):       return .f1065_line15_interest
        case (.interestOther, .scheduleF):      return .schF_line21b_otherInterest
        case (.interestOther, .scheduleE):      return .schE_line13_otherInterest

        case (.legalProfessional, .scheduleC):  return .schC_line17_legalProfessional
        case (.legalProfessional, .form1065):   return .f1065_line20_otherDeductions
        case (.legalProfessional, .scheduleF):  return .schF_line32a_otherExpenses
        case (.legalProfessional, .scheduleE):  return .schE_line10_legal

        case (.officeExpense, .scheduleC):      return .schC_line18_officeExpense
        case (.officeExpense, .form1065):       return .f1065_line20_otherDeductions
        case (.officeExpense, .scheduleF):      return .schF_line28_supplies
        case (.officeExpense, .scheduleE):      return .schE_line15_supplies

        case (.pension, .scheduleC):            return .schC_line19_pensionProfitShare
        case (.pension, .form1065):             return .f1065_line18_retirement
        case (.pension, .scheduleF):            return .schF_line23_pension
        case (.pension, .scheduleE):            return .schE_line19_other

        case (.rentEquipment, .scheduleC):      return .schC_line20a_rentEquipment
        case (.rentEquipment, .form1065):       return .f1065_line13_rentProperty
        case (.rentEquipment, .scheduleF):      return .schF_line24a_rentEquipment
        case (.rentEquipment, .scheduleE):      return .schE_line19_other

        case (.rentProperty, .scheduleC):       return .schC_line20b_rentProperty
        case (.rentProperty, .form1065):        return .f1065_line13_rentProperty
        case (.rentProperty, .scheduleF):       return .schF_line24b_rentProperty
        case (.rentProperty, .scheduleE):       return .schE_line19_other

        case (.repairsMaintenance, .scheduleC): return .schC_line21_repairsMaintenance
        case (.repairsMaintenance, .form1065):  return .f1065_line11_repairsMaintenance
        case (.repairsMaintenance, .scheduleF): return .schF_line25_repairsMaintenance
        case (.repairsMaintenance, .scheduleE): return .schE_line14_repairs

        case (.supplies, .scheduleC):           return .schC_line22_supplies
        case (.supplies, .form1065):            return .f1065_line20_otherDeductions
        case (.supplies, .scheduleF):           return .schF_line28_supplies
        case (.supplies, .scheduleE):           return .schE_line15_supplies

        case (.taxesAndLicenses, .scheduleC):   return .schC_line23_taxesAndLicenses
        case (.taxesAndLicenses, .form1065):    return .f1065_line14_taxesAndLicenses
        case (.taxesAndLicenses, .scheduleF):   return .schF_line29_taxesLicenses
        case (.taxesAndLicenses, .scheduleE):   return .schE_line16_taxes

        case (.travel, .scheduleC):             return .schC_line24a_travel
        case (.travel, .form1065):              return .f1065_line20_otherDeductions
        case (.travel, .scheduleF):             return .schF_line32a_otherExpenses
        case (.travel, .scheduleE):             return .schE_line6_auto

        case (.meals, .scheduleC):              return .schC_line24b_meals
        case (.meals, .form1065):               return .f1065_line20_otherDeductions
        case (.meals, .scheduleF):              return .schF_line32a_otherExpenses
        case (.meals, .scheduleE):              return .schE_line19_other

        case (.utilities, .scheduleC):          return .schC_line25_utilities
        case (.utilities, .form1065):           return .f1065_line20_otherDeductions
        case (.utilities, .scheduleF):          return .schF_line30_utilities
        case (.utilities, .scheduleE):          return .schE_line17_utilities

        case (.wages, .scheduleC):              return .schC_line26_wages
        case (.wages, .form1065):               return .f1065_line9_salariesWages
        case (.wages, .scheduleF):              return .schF_line22_labor
        case (.wages, .scheduleE):              return .schE_line19_other

        case (.otherExpenses, .scheduleC):      return .schC_line27a_otherExpenses
        case (.otherExpenses, .form1065):       return .f1065_line20_otherDeductions
        case (.otherExpenses, .scheduleF):      return .schF_line32a_otherExpenses
        case (.otherExpenses, .scheduleE):      return .schE_line19_other

        case (.businessUseOfHome, .scheduleC):  return .schC_line30_businessUseOfHome
        case (.businessUseOfHome, _):           return nil

        case (.costOfGoodsSold, .form1065):     return .f1065_cogs
        case (.costOfGoodsSold, _):             return nil

        // Farm-specific
        case (.chemicals, .scheduleF):    return .schF_line11_chemicals
        case (.conservation, .scheduleF): return .schF_line12_conservation
        case (.customHire, .scheduleF):   return .schF_line13_customHire
        case (.feed, .scheduleF):         return .schF_line16_feed
        case (.fertilizers, .scheduleF):  return .schF_line17_fertilizers
        case (.freight, .scheduleF):      return .schF_line18_freight
        case (.fuel, .scheduleF):         return .schF_line19_fuel
        case (.seeds, .scheduleF):        return .schF_line26_seeds
        case (.storage, .scheduleF):      return .schF_line27_storage
        case (.veterinary, .scheduleF):   return .schF_line31_vet

        // Rental-specific
        case (.cleaning, .scheduleE):     return .schE_line7_cleaning
        case (.management, .scheduleE):   return .schE_line11_management

        // Concepts that don't apply to this form → nil
        default: return nil
        }
    }
}

// MARK: - ScheduleCLine ↔ TaxFormLine Bridge

extension ScheduleCLine {

    /// Converts this Schedule C line to the equivalent TaxFormLine.
    var asTaxFormLine: TaxFormLine {
        switch self {
        case .line1_grossReceipts:       return .schC_line1_grossReceipts
        case .line6_otherIncome:         return .schC_line6_otherIncome
        case .line8_advertising:         return .schC_line8_advertising
        case .line9_carAndTruck:         return .schC_line9_carAndTruck
        case .line10_commissionsAndFees: return .schC_line10_commissionsAndFees
        case .line11_contractLabor:      return .schC_line11_contractLabor
        case .line12_depletion:          return .schC_line12_depletion
        case .line13_depreciation:       return .schC_line13_depreciation
        case .line14_employeeBenefits:   return .schC_line14_employeeBenefits
        case .line15_insurance:          return .schC_line15_insurance
        case .line16a_mortgageBanks:     return .schC_line16a_mortgageBanks
        case .line16b_mortgageOther:     return .schC_line16b_mortgageOther
        case .line17_legalProfessional:  return .schC_line17_legalProfessional
        case .line18_officeExpense:      return .schC_line18_officeExpense
        case .line19_pensionProfitShare: return .schC_line19_pensionProfitShare
        case .line20a_rentEquipment:     return .schC_line20a_rentEquipment
        case .line20b_rentProperty:      return .schC_line20b_rentProperty
        case .line21_repairsMaintenance: return .schC_line21_repairsMaintenance
        case .line22_supplies:           return .schC_line22_supplies
        case .line23_taxesAndLicenses:   return .schC_line23_taxesAndLicenses
        case .line24a_travel:            return .schC_line24a_travel
        case .line24b_meals:             return .schC_line24b_meals
        case .line25_utilities:          return .schC_line25_utilities
        case .line26_wages:              return .schC_line26_wages
        case .line27a_otherExpenses:     return .schC_line27a_otherExpenses
        case .line30_businessUseOfHome:  return .schC_line30_businessUseOfHome
        }
    }

    /// Maps this Schedule C line to the equivalent ExpenseConcept for cross-form translation.
    var expenseConcept: ExpenseConcept? {
        switch self {
        case .line1_grossReceipts:       return .grossReceipts
        case .line6_otherIncome:         return .otherIncome
        case .line8_advertising:         return .advertising
        case .line9_carAndTruck:         return .carAndTruck
        case .line10_commissionsAndFees: return .commissionsAndFees
        case .line11_contractLabor:      return .contractLabor
        case .line12_depletion:          return .depletion
        case .line13_depreciation:       return .depreciation
        case .line14_employeeBenefits:   return .employeeBenefits
        case .line15_insurance:          return .insurance
        case .line16a_mortgageBanks:     return .interestMortgage
        case .line16b_mortgageOther:     return .interestOther
        case .line17_legalProfessional:  return .legalProfessional
        case .line18_officeExpense:      return .officeExpense
        case .line19_pensionProfitShare: return .pension
        case .line20a_rentEquipment:     return .rentEquipment
        case .line20b_rentProperty:      return .rentProperty
        case .line21_repairsMaintenance: return .repairsMaintenance
        case .line22_supplies:           return .supplies
        case .line23_taxesAndLicenses:   return .taxesAndLicenses
        case .line24a_travel:            return .travel
        case .line24b_meals:             return .meals
        case .line25_utilities:          return .utilities
        case .line26_wages:              return .wages
        case .line27a_otherExpenses:     return .otherExpenses
        case .line30_businessUseOfHome:  return .businessUseOfHome
        }
    }
}
