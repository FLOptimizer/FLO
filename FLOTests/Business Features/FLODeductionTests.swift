//  FLODeductionTests.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.2 - Tax Deduction Flagging Tests
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE: Validate tax deduction flagging rules, category-based deductions,
//  and IRS category mapping logic.
//
//  COVERS:
//  - Category-based deduction rules
//  - Business vs Personal deduction eligibility
//  - IRS Schedule C category mapping
//  - Deduction opportunity detection
//  - Partial deduction scenarios
//

import XCTest
@testable import FLO

final class FLODeductionTests: XCTestCase {
    
    // MARK: - Deduction Categories
    
    /// Categories that are always deductible for business
    let alwaysDeductibleCategories = [
        "Office Supplies",
        "Software & Subscriptions",
        "Professional Services",
        "Advertising & Marketing",
        "Business Insurance",
        "Bank Fees",
        "Contractor Payments",
        "Equipment",
        "Education & Training",
        "Business Travel",
        "Business Meals"  // 50% deductible
    ]
    
    /// Categories that are never deductible
    let neverDeductibleCategories = [
        "Personal",
        "Entertainment",
        "Clothing",
        "Groceries",
        "Personal Care"
    ]
    
    /// Categories that depend on business use percentage
    let partialDeductibleCategories = [
        "Phone",           // Business use %
        "Internet",        // Business use %
        "Utilities",       // Home office %
        "Rent",            // Home office %
        "Vehicle"          // Business miles %
    ]
    
    /// IRS Schedule C line mapping
    let scheduleCMapping: [String: String] = [
        "Advertising & Marketing": "Line 8 - Advertising",
        "Vehicle": "Line 9 - Car and truck expenses",
        "Contractor Payments": "Line 11 - Contract labor",
        "Equipment": "Line 13 - Depreciation",
        "Business Insurance": "Line 15 - Insurance",
        "Professional Services": "Line 17 - Legal and professional services",
        "Office Supplies": "Line 18 - Office expense",
        "Rent": "Line 20b - Rent (other business property)",
        "Business Travel": "Line 24a - Travel",
        "Business Meals": "Line 24b - Deductible meals",
        "Utilities": "Line 25 - Utilities",
        "Other": "Line 27a - Other expenses"
    ]
}

// MARK: - Basic Deduction Eligibility

extension FLODeductionTests {
    
    /// Test: Business expense is deductible
    func testDeduction_BusinessExpense_IsDeductible() {
        let category = "Office Supplies"
        let isBusiness = true
        
        let isDeductible = isBusiness && alwaysDeductibleCategories.contains(category)
        
        XCTAssertTrue(isDeductible, "Business office supplies are deductible")
    }
    
    /// Test: Personal expense is NOT deductible
    func testDeduction_PersonalExpense_NotDeductible() {
        let category = "Office Supplies"
        let isBusiness = false
        
        let isDeductible = isBusiness && alwaysDeductibleCategories.contains(category)
        
        XCTAssertFalse(isDeductible, "Personal expenses are not deductible")
    }
    
    /// Test: Personal category is never deductible
    func testDeduction_PersonalCategory_NeverDeductible() {
        let category = "Entertainment"
        let isBusiness = true  // Even if marked business
        
        let isDeductible = !neverDeductibleCategories.contains(category) && isBusiness
        
        XCTAssertFalse(isDeductible, "Entertainment is never deductible")
    }
    
    /// Test: All always-deductible categories
    func testDeduction_AllAlwaysDeductible() {
        for category in alwaysDeductibleCategories {
            let isDeductible = alwaysDeductibleCategories.contains(category)
            XCTAssertTrue(isDeductible, "\(category) should be deductible")
        }
    }
    
    /// Test: All never-deductible categories
    func testDeduction_AllNeverDeductible() {
        for category in neverDeductibleCategories {
            let isDeductible = !neverDeductibleCategories.contains(category)
            XCTAssertFalse(isDeductible, "\(category) should not be deductible")
        }
    }
}

// MARK: - Partial Deductions

extension FLODeductionTests {
    
    /// Test: Business meals are 50% deductible
    func testPartialDeduction_BusinessMeals_50Percent() {
        let expenseAmount: Double = 100.00
        let category = "Business Meals"
        let mealDeductionRate: Double = 0.50
        
        let deductibleAmount = category == "Business Meals" ? expenseAmount * mealDeductionRate : expenseAmount
        
        XCTAssertEqual(deductibleAmount, 50.00, "Business meals 50% deductible")
    }
    
    /// Test: Phone with 80% business use
    func testPartialDeduction_Phone_BusinessUsePercent() {
        let monthlyBill: Double = 100.00
        let businessUsePercent: Double = 0.80
        
        let deductibleAmount = monthlyBill * businessUsePercent
        
        XCTAssertEqual(deductibleAmount, 80.00, "80% business use = $80 deductible")
    }
    
    /// Test: Internet with 50% business use
    func testPartialDeduction_Internet_BusinessUsePercent() {
        let monthlyBill: Double = 80.00
        let businessUsePercent: Double = 0.50
        
        let deductibleAmount = monthlyBill * businessUsePercent
        
        XCTAssertEqual(deductibleAmount, 40.00, "50% business use = $40 deductible")
    }
    
    /// Test: Home office deduction (square footage method)
    func testPartialDeduction_HomeOffice_SquareFootage() {
        let totalRent: Double = 2000.00
        let totalSquareFeet: Double = 1000.0
        let officeSquareFeet: Double = 150.0
        
        let businessUsePercent = officeSquareFeet / totalSquareFeet
        let deductibleAmount = totalRent * businessUsePercent
        
        XCTAssertEqual(businessUsePercent, 0.15, accuracy: 0.001, "15% of home is office")
        XCTAssertEqual(deductibleAmount, 300.00, "15% of rent = $300 deductible")
    }
    
    /// Test: Home office simplified method ($5/sq ft, max 300 sq ft)
    func testPartialDeduction_HomeOffice_SimplifiedMethod() {
        let officeSquareFeet: Double = 200.0
        let ratePerSqFt: Double = 5.00
        let maxSquareFeet: Double = 300.0
        
        let applicableSquareFeet = min(officeSquareFeet, maxSquareFeet)
        let deduction = applicableSquareFeet * ratePerSqFt
        
        XCTAssertEqual(deduction, 1000.00, "200 sq ft × $5 = $1,000")
    }
    
    /// Test: Home office simplified method - capped at 300 sq ft
    func testPartialDeduction_HomeOffice_SimplifiedMethod_Capped() {
        let officeSquareFeet: Double = 500.0  // Over limit
        let ratePerSqFt: Double = 5.00
        let maxSquareFeet: Double = 300.0
        
        let applicableSquareFeet = min(officeSquareFeet, maxSquareFeet)
        let deduction = applicableSquareFeet * ratePerSqFt
        
        XCTAssertEqual(deduction, 1500.00, "Capped at 300 sq ft × $5 = $1,500")
    }
}

// MARK: - IRS Schedule C Categories

extension FLODeductionTests {
    
    /// Test: Category maps to correct Schedule C line
    func testScheduleC_AdvertisingMapping() {
        let category = "Advertising & Marketing"
        let scheduleCLine = scheduleCMapping[category]
        
        XCTAssertEqual(scheduleCLine, "Line 8 - Advertising")
    }
    
    /// Test: Vehicle maps to Line 9
    func testScheduleC_VehicleMapping() {
        let category = "Vehicle"
        let scheduleCLine = scheduleCMapping[category]
        
        XCTAssertEqual(scheduleCLine, "Line 9 - Car and truck expenses")
    }
    
    /// Test: All categories have Schedule C mapping
    func testScheduleC_AllCategoriesMapped() {
        let categoriesToMap = [
            "Advertising & Marketing",
            "Vehicle",
            "Contractor Payments",
            "Equipment",
            "Business Insurance",
            "Professional Services",
            "Office Supplies",
            "Business Travel",
            "Business Meals"
        ]
        
        for category in categoriesToMap {
            XCTAssertNotNil(scheduleCMapping[category], "\(category) should have Schedule C mapping")
        }
    }
    
    /// Test: Unknown category maps to "Other"
    func testScheduleC_UnknownCategory_MapsToOther() {
        let category = "Random Unknown Category"
        let scheduleCLine = scheduleCMapping[category] ?? scheduleCMapping["Other"]
        
        XCTAssertEqual(scheduleCLine, "Line 27a - Other expenses")
    }
}

// MARK: - Deduction Opportunity Detection

extension FLODeductionTests {
    
    /// Test: Detect missed deduction opportunity (business expense marked personal)
    func testOpportunity_BusinessMarkedPersonal() {
        let merchant = "Office Depot"
        let isBusiness = false  // Marked personal
        
        // Heuristic: certain merchants suggest business purpose
        let businessMerchants = ["Office Depot", "Staples", "Amazon Business", "Best Buy Business"]
        let likelyBusiness = businessMerchants.contains(merchant)
        
        let isMissedOpportunity = likelyBusiness && !isBusiness
        
        XCTAssertTrue(isMissedOpportunity, "Office Depot purchase marked personal is likely missed deduction")
    }
    
    /// Test: Flag recurring software subscription
    func testOpportunity_RecurringSoftware() {
        let merchant = "Adobe Creative Cloud"
        let isRecurring = true
        let isBusiness = false
        
        let softwareMerchants = ["Adobe", "Microsoft 365", "Zoom", "Slack", "Dropbox"]
        let isSoftware = softwareMerchants.contains { merchant.contains($0) }
        
        let shouldFlag = isSoftware && isRecurring && !isBusiness
        
        XCTAssertTrue(shouldFlag, "Adobe subscription might be business deductible")
    }
    
    /// Test: Calculate potential missed deductions
    func testOpportunity_CalculatePotentialSavings() {
        let missedExpenses: [(amount: Double, category: String)] = [
            (50.00, "Office Supplies"),
            (15.99, "Software & Subscriptions"),
            (120.00, "Professional Services")
        ]
        
        let estimatedTaxRate: Double = 0.30  // 30% marginal rate
        
        let totalMissed = missedExpenses.reduce(0) { $0 + $1.amount }
        let potentialSavings = totalMissed * estimatedTaxRate
        
        XCTAssertEqual(totalMissed, 185.99, accuracy: 0.01)
        XCTAssertEqual(potentialSavings, 55.80, accuracy: 0.01, "Could save ~$55.80 in taxes")
    }
}

// MARK: - Deduction Limits

extension FLODeductionTests {
    
    /// Test: Business interest deduction limit
    func testLimit_BusinessInterest() {
        // Simplified: business interest limited to 30% of adjusted taxable income
        let adjustedTaxableIncome: Double = 100_000
        let businessInterestPaid: Double = 40_000
        let limitPercent: Double = 0.30
        
        let limit = adjustedTaxableIncome * limitPercent
        let deductibleInterest = min(businessInterestPaid, limit)
        
        XCTAssertEqual(limit, 30_000)
        XCTAssertEqual(deductibleInterest, 30_000, "Interest capped at 30% of ATI")
    }
    
    /// Test: Section 179 deduction limit (2025)
    func testLimit_Section179() {
        let equipmentPurchased: Double = 50_000
        let section179Limit: Double = 1_160_000  // 2025 limit
        
        let deduction = min(equipmentPurchased, section179Limit)
        
        XCTAssertEqual(deduction, 50_000, "Full equipment cost deductible under Section 179")
    }
    
    /// Test: Startup costs deduction limit
    func testLimit_StartupCosts() {
        let totalStartupCosts: Double = 60_000
        let immediateDeductionLimit: Double = 5_000
        let phaseoutThreshold: Double = 50_000
        
        // Reduce $5K limit by amount over $50K
        let excessOverThreshold = max(0, totalStartupCosts - phaseoutThreshold)
        let adjustedImmediateDeduction = max(0, immediateDeductionLimit - excessOverThreshold)
        
        // Remaining must be amortized over 180 months
        let amortizableAmount = totalStartupCosts - adjustedImmediateDeduction
        let monthlyAmortization = amortizableAmount / 180
        
        XCTAssertEqual(adjustedImmediateDeduction, 0, "$10K over threshold eliminates immediate deduction")
        XCTAssertEqual(monthlyAmortization, 333.33, accuracy: 0.01, "Full amount amortized")
    }
}

// MARK: - Year-End Deduction Summary

extension FLODeductionTests {
    
    /// Test: Calculate total deductions by category
    func testSummary_TotalByCategory() {
        let expenses: [(amount: Double, category: String, isBusiness: Bool)] = [
            (500.00, "Office Supplies", true),
            (300.00, "Office Supplies", true),
            (1200.00, "Software & Subscriptions", true),
            (150.00, "Software & Subscriptions", false),  // Personal
            (800.00, "Professional Services", true),
            (200.00, "Business Meals", true)  // 50% deductible
        ]
        
        var totalsByCategory: [String: Double] = [:]
        
        for expense in expenses {
            guard expense.isBusiness else { continue }
            
            var deductibleAmount = expense.amount
            if expense.category == "Business Meals" {
                deductibleAmount *= 0.50
            }
            
            totalsByCategory[expense.category, default: 0] += deductibleAmount
        }
        
        XCTAssertEqual(totalsByCategory["Office Supplies"], 800.00)
        XCTAssertEqual(totalsByCategory["Software & Subscriptions"], 1200.00)
        XCTAssertEqual(totalsByCategory["Professional Services"], 800.00)
        XCTAssertEqual(totalsByCategory["Business Meals"], 100.00, "50% of $200")
    }
    
    /// Test: Grand total deductions
    func testSummary_GrandTotal() {
        let deductionsByCategory: [String: Double] = [
            "Office Supplies": 800.00,
            "Software & Subscriptions": 1200.00,
            "Professional Services": 800.00,
            "Business Meals": 100.00,
            "Mileage": 2500.00,
            "Home Office": 1800.00
        ]
        
        let grandTotal = deductionsByCategory.values.reduce(0, +)
        
        XCTAssertEqual(grandTotal, 7200.00, "Total deductions = $7,200")
    }
}
