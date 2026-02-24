//  FLOCoreShortcuts.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Core Siri Shortcuts: Expense, Receipt, Tax Estimate
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ "Hey Siri, add an expense in FLO"
//  ✅ "Hey Siri, scan a receipt in FLO"
//  ✅ "Hey Siri, what's my tax estimate in FLO"
//  ✅ Tier-aware: Free → basic scanner, Premium+ → Smart Receipt Scanner
//  ✅ Tax estimate returns quarterly data via Siri dialog (Premium+)
//
//  NOTE: These intents are registered in FLOShortcutsProvider
//  (defined in MileageShortcuts.swift)
//

import AppIntents
import SwiftUI
import SwiftData

// MARK: - Add Expense Intent

/// Siri intent to quickly add a new expense
@available(iOS 16.0, *)
struct AddExpenseIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Add Expense"
    static var description = IntentDescription("Quickly log a new expense or income transaction")
    
    /// Must open the app to show the transaction form
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Navigate to Add Transaction screen
        let nav = NavigationService.shared
        nav.addTransactionIsIncome = false
        nav.showingAddTransaction = true
        
        return .result(dialog: "Opening expense entry.")
    }
}

// MARK: - Add Income Intent

/// Siri intent to quickly add income
@available(iOS 16.0, *)
struct AddIncomeIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Add Income"
    static var description = IntentDescription("Quickly log a new income transaction")
    
    /// Must open the app to show the transaction form
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Navigate to Add Transaction screen with income pre-selected
        let nav = NavigationService.shared
        nav.addTransactionIsIncome = true
        nav.showingAddTransaction = true
        
        return .result(dialog: "Opening income entry.")
    }
}

// MARK: - Scan Receipt Intent

/// Siri intent to open the receipt scanner
/// Routes to Smart Receipt Scanner (Premium+) or basic capture (Free)
@available(iOS 16.0, *)
struct ScanReceiptIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Scan Receipt"
    static var description = IntentDescription("Open the camera to scan and save a receipt")
    
    /// Must open the app to use camera
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // NavigationService.showingReceiptScanner opens SmartReceiptScanningView
        // which works for all tiers. Premium+ gets full AI parsing features;
        // Free tier gets core scanning with limited account assignment.
        let nav = NavigationService.shared
        nav.showingReceiptScanner = true
        
        return .result(dialog: "Opening receipt scanner.")
    }
}

// MARK: - Check Tax Estimate Intent

/// Siri intent to check current quarterly tax estimate
/// Returns data via dialog for Premium+ users without opening app
@available(iOS 16.0, *)
struct CheckTaxEstimateIntent: AppIntent {
    
    static var title: LocalizedStringResource = "Check Tax Estimate"
    static var description = IntentDescription("See your estimated quarterly tax payment")
    
    /// Premium+ users get dialog without opening app
    /// Free users get prompted to upgrade
    static var openAppWhenRun: Bool = false
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let tier = SubscriptionManager.shared.currentTier
        
        // Free tier: prompt to upgrade
        guard tier.hasTaxEstimates else {
            return .result(dialog: "Tax estimates are available with FLO Premium. Open the app to learn more about upgrading.")
        }
        
        // Premium+: Calculate and return the estimate
        // Get current year transactions for estimate
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        
        // Access SwiftData context using the shared container
        guard let container = try? ModelContainer.shared() else {
            return .result(dialog: "I couldn't access your financial data. Please open the app to check your tax estimate.")
        }
        
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= startOfYear },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        guard let transactions = try? context.fetch(descriptor) else {
            return .result(dialog: "I couldn't load your transactions. Please open the app to check your tax estimate.")
        }
        
        let businessIncome = transactions
            .filter { $0.financeType == .business && $0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let businessExpenses = transactions
            .filter { $0.financeType == .business && !$0.isIncome }
            .reduce(0.0) { $0 + $1.amount }
        
        let netProfit = businessIncome - businessExpenses
        
        // Calculate which quarter we're in
        let quarter = (calendar.component(.month, from: now) - 1) / 3 + 1
        
        if netProfit <= 0 {
            return .result(dialog: "Based on your year-to-date data, your net business income is negative, so no estimated tax is due for Q\(quarter).")
        }
        
        // Simplified SE tax + income tax estimate
        let seTaxRate = 0.153  // 15.3% self-employment tax
        let estimatedIncomeTaxRate = 0.22  // Approximate marginal rate
        let seTax = netProfit * 0.9235 * seTaxRate  // 92.35% of net earnings
        let incomeTax = netProfit * estimatedIncomeTaxRate
        let totalAnnual = seTax + incomeTax
        let quarterlyPayment = totalAnnual / 4.0
        
        let formatted = String(format: "$%.0f", quarterlyPayment)
        let profitFormatted = String(format: "$%.0f", netProfit)
        
        return .result(dialog: "Based on \(profitFormatted) net business income year-to-date, your estimated Q\(quarter) payment is approximately \(formatted). Open the app for a detailed breakdown.")
    }
}
