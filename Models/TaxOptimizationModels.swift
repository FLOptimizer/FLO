//  TaxOptimizationModels.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Shared Models for Tax Optimization
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Shared data models used by TaxOptimizationEngine and related views.
//  Extracted to separate file to avoid naming conflicts and improve clarity.
//

import Foundation

// MARK: - Deduction Opportunity

struct TaxDeductionOpportunity: Identifiable {
    let id: UUID
    let category: TaxDeductionCategory
    let title: String
    let description: String
    let estimatedSavings: Double
    let confidence: Double // 0.0 to 1.0
    let riskLevel: TaxRiskLevel
    let actionItems: [String]
    let irsCitation: String?
    let requiresProTier: Bool
    
    var priorityScore: Double {
        // Weighted score for sorting
        return estimatedSavings * confidence * (1.0 - riskLevel.scoreImpact)
    }
}

// MARK: - Year-End Checklist
// Note: TransactionTaxSavings is defined in TaxOptimizationEngine.swift
// since it needs to reference the Transaction model

struct TaxYearEndChecklist {
    var year: Int
    var isActive: Bool = false
    var items: [TaxChecklistItem] = []
    
    var totalPotentialSavings: Double {
        items.reduce(0) { $0 + $1.potentialSavings }
    }
    
    var completionPercentage: Double {
        guard !items.isEmpty else { return 0 }
        let completed = items.filter { $0.isCompleted }.count
        return Double(completed) / Double(items.count)
    }
}

// MARK: - Checklist Item

struct TaxChecklistItem: Identifiable {
    let id = UUID()
    let category: TaxChecklistCategory
    let title: String
    let description: String
    let potentialSavings: Double
    let priority: TaxChecklistPriority
    let deadline: Date
    let actionItems: [String]
    let riskLevel: TaxRiskLevel
    var isCompleted: Bool = false
}

// MARK: - Checklist Priority

enum TaxChecklistPriority: Int, Comparable {
    case low = 1
    case medium = 2
    case high = 3
    
    static func < (lhs: TaxChecklistPriority, rhs: TaxChecklistPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    var displayName: String {
        switch self {
        case .low: return "Optional"
        case .medium: return "Recommended"
        case .high: return "Important"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Checklist Category

enum TaxChecklistCategory: String {
    case reviewExpenses = "Review Expenses"
    case prepayExpenses = "Prepay Expenses"
    case retirement = "Retirement"
    case equipment = "Equipment"
    case entityStructure = "Entity Structure"
    case advancedStrategy = "Advanced Strategy"
    case incomeTiming = "Income Timing"
}

// MARK: - Audit Risk Assessment

struct TaxAuditRiskAssessment {
    let category: TaxDeductionCategory
    let riskLevel: TaxRiskLevel
    let riskScore: Double // 0.0 to 1.0
    let riskFactors: [String]
    let recommendations: [String]
}

// MARK: - Deduction Category

enum TaxDeductionCategory: String, CaseIterable {
    case homeOffice = "Home Office"
    case vehicle = "Vehicle"
    case healthInsurance = "Health Insurance"
    case retirement = "Retirement"
    case familyPayroll = "Family Payroll"
    case uncategorized = "Uncategorized"
    case depreciation = "Depreciation"
    case mealsEntertainment = "Meals & Entertainment"
    case augustaRule = "Augusta Rule"
    case qbiDeduction = "QBI Deduction"
    case travelExpenses = "Travel"
    case charitableContributions = "Charitable"
    case advertising = "Advertising"
    case insurance = "Insurance"
    case legalProfessional = "Legal & Professional"
    case officeSupplies = "Office Supplies"
    case phoneInternet = "Phone & Internet"
    case softwareSubscriptions = "Software"
    case contractLabor = "Contract Labor"
    case bankFees = "Bank Fees"
    case education = "Education"
    
    var displayName: String { rawValue }
    
    var emoji: String {
        switch self {
        case .homeOffice: return "🏠"
        case .vehicle: return "🚗"
        case .healthInsurance: return "🏥"
        case .retirement: return "💰"
        case .familyPayroll: return "👨‍👩‍👧"
        case .uncategorized: return "❓"
        case .depreciation: return "💻"
        case .mealsEntertainment: return "🍽️"
        case .augustaRule: return "🏡"
        case .qbiDeduction: return "📊"
        case .travelExpenses: return "✈️"
        case .charitableContributions: return "❤️"
        case .advertising: return "📢"
        case .insurance: return "🛡️"
        case .legalProfessional: return "⚖️"
        case .officeSupplies: return "📎"
        case .phoneInternet: return "📱"
        case .softwareSubscriptions: return "💾"
        case .contractLabor: return "🤝"
        case .bankFees: return "🏦"
        case .education: return "📚"
        }
    }
}

// MARK: - Risk Level

enum TaxRiskLevel: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .low: return "✅"
        case .medium: return "⚠️"
        case .high: return "🚨"
        }
    }
    
    var scoreImpact: Double {
        switch self {
        case .low: return 0.1
        case .medium: return 0.3
        case .high: return 0.5
        }
    }
}

// MARK: - Version History
/*
 Version 1.0 (Current):
 - Extracted from TaxOptimizationEngine.swift to avoid naming conflicts
 - All models prefixed with "Tax" to prevent ambiguity
 - Used by TaxOptimizationEngine, DeductionOpportunityCard, and related views
 
 Model Types:
 - TaxDeductionOpportunity: Main opportunity data structure
 - TransactionTaxSavings: Per-transaction savings calculation
 - TaxYearEndChecklist: Year-end planning checklist
 - TaxChecklistItem: Individual checklist action item
 - TaxAuditRiskAssessment: Risk analysis results
 - TaxDeductionCategory: Deduction category enum
 - TaxRiskLevel: Risk level enum
 - TaxChecklistCategory: Checklist category enum
 - TaxChecklistPriority: Priority level enum
 */
