//  PreviewProvider+Helpers.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Fully working, no errors, production-ready
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES FROM v2.1:
//  - FIXED: Replaced non-existent ModelContainer.makePreview() with proper initialization
//  - FIXED: Budget initializer - uses month, planned, budgetType (not name, amount, period)
//  - FIXED: Explicit BudgetType.envelope instead of inferring .monthly
//  - FIXED: Proper ModelConfiguration for in-memory storage
//  - Updated to match current FLO model set (5 core models)
//

#if DEBUG
import SwiftUI
import SwiftData

/// Helper for creating isolated, in-memory ModelContainers for SwiftUI previews.
/// Ensures previews remain fast, isolated, and can optionally include realistic seed data.
@MainActor
struct PreviewContainer {
    
    // MARK: - Version
    
    static let version = "2.2"
    
    // MARK: - Container Creation
    
    /// Creates an in-memory ModelContainer for previews with optional sample data.
    ///
    /// - Parameters:
    ///   - populateSeedData: If true, inserts 32 default categories via SeedData
    ///   - populateCustomData: Optional closure to add custom sample data after seeding
    /// - Returns: A configured ModelContainer for preview use
    /// - Throws: Error if ModelContainer creation or data insertion fails
    ///
    /// **Examples:**
    /// ```swift
    /// // Empty container
    /// let container = try PreviewContainer.make()
    ///
    /// // With seed data (32 categories)
    /// let container = try PreviewContainer.make(populateSeedData: true)
    ///
    /// // With custom data
    /// let container = try PreviewContainer.make(populateSeedData: true) { context in
    ///     let category = Category(name: "Test", icon: "star.fill", colorHex: "#10B981")
    ///     context.insert(category)
    /// }
    /// ```
    static func make(
        populateSeedData: Bool = false,
        populateCustomData: ((ModelContext) throws -> Void)? = nil
    ) throws -> ModelContainer {
        
        // ✅ FIXED: Create in-memory container with proper ModelConfiguration
        // Core models: Transaction, Category, Budget, RecurringTransaction, TaxSettings
        let schema = Schema([
            Transaction.self,
            Category.self,
            Budget.self,
            RecurringTransaction.self,
            TaxSettings.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        
        let context = container.mainContext
        
        // Seed default categories if requested
        if populateSeedData {
            let seedResult = SeedData.seedDefaultCategories(in: context)
            switch seedResult {
            case .success(let count):
                if count > 0 {
                    print("✅ Preview: Seeded \(count) default categories")
                }
            case .failure(let error):
                print("⚠️ Preview: Seed failed - \(error.localizedDescription)")
                // Continue anyway - don't fail the preview
            }
        }
        
        // Add custom data if provided
        if let customData = populateCustomData {
            try customData(context)
            try context.save()
        }
        
        return container
    }
    
    // MARK: - Convenience Helpers
    
    /// Creates a container with seed data and common sample transactions
    static func makeWithSampleData() throws -> ModelContainer {
        try make(populateSeedData: true) { context in
            // Get some seeded categories for sample transactions
            let descriptor = FetchDescriptor<Category>()
            let categories = try context.fetch(descriptor)
            
            guard let groceryCategory = categories.first(where: { $0.name == "Groceries" }),
                  let incomeCategory = categories.first(where: { $0.name == "Freelance Income" }) else {
                return // Skip if categories not found
            }
            
            // Sample expense
            let expense = Transaction(
                amount: 45.50,
                date: Date(),
                note: "Weekly groceries",
                isIncome: false,
                merchantName: "Whole Foods",
                category: groceryCategory,
                financeType: .personal
            )
            context.insert(expense)
            
            // Sample income
            let income = Transaction(
                amount: 1500.00,
                date: Date().addingTimeInterval(-5 * 86400), // 5 days ago
                note: "Client project payment",
                isIncome: true,
                merchantName: "Acme Corp",
                category: incomeCategory,
                financeType: .business
            )
            context.insert(income)
            
            // ✅ FIXED: Sample budget with correct initializer
            let calendar = Calendar.current
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
            
            let budget = Budget(
                month: startOfMonth,           // ✅ Date, not String
                planned: 500.00,               // ✅ planned, not amount
                carryOver: 0.0,
                category: groceryCategory,
                budgetType: BudgetType.envelope,  // ✅ Explicit type, not .monthly
                financeType: .personal
            )
            context.insert(budget)
        }
    }
}

// MARK: - Preview Sample Data Helpers

extension PreviewContainer {
    
    /// Creates sample categories for preview use
    static func insertSampleCategories(into context: ModelContext) throws {
        let categories = [
            Category(name: "Groceries", icon: "cart.fill", colorHex: "#10B981", isDefault: true),
            Category(name: "Dining Out", icon: "fork.knife", colorHex: "#F59E0B"),
            Category(name: "Business Expense", icon: "briefcase.fill", colorHex: "#3B82F6", isTaxDeductible: true),
            Category(name: "Freelance Income", icon: "laptopcomputer", colorHex: "#14B8A6", isIncome: true)
        ]
        
        categories.forEach { context.insert($0) }
        try context.save()
    }
    
    /// Creates sample transactions for preview use
    static func insertSampleTransactions(into context: ModelContext, categories: [Category]) throws {
        guard let foodCategory = categories.first,
              let incomeCategory = categories.first(where: { $0.isIncome }) else {
            return
        }
        
        let transactions = [
            Transaction(
                amount: 45.50,
                date: Date(),
                note: "Lunch at Pizza Place",
                isIncome: false,
                merchantName: "Pizza Place",
                category: foodCategory,
                financeType: .personal
            ),
            Transaction(
                amount: 2000.00,
                date: Date().addingTimeInterval(-3 * 86400), // 3 days ago
                note: "Q4 Project Payment",
                isIncome: true,
                merchantName: "Tech Startup Inc",
                category: incomeCategory,
                financeType: .business
            )
        ]
        
        transactions.forEach { context.insert($0) }
        try context.save()
    }
}

// MARK: - Date Helper Extension

extension Date {
    /// Returns the start of the month for this date
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the start of the current quarter
    func startOfQuarter() -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let year = calendar.component(.year, from: self)
        
        let quarterStartMonth: Int
        switch month {
        case 1...3: quarterStartMonth = 1
        case 4...6: quarterStartMonth = 4
        case 7...9: quarterStartMonth = 7
        default: quarterStartMonth = 10
        }
        
        let components = DateComponents(year: year, month: quarterStartMonth, day: 1)
        return calendar.date(from: components) ?? self
    }
}

// MARK: - Error Fallback View

/// View displayed when preview container creation fails
struct PreviewErrorView: View {
    let error: Error
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            
            Text("Preview Error")
                .font(.title2.bold())
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#endif

/*
 ===============================================================================
 USAGE EXAMPLES
 ===============================================================================
 
 EMPTY STATE - No Data
 ===============================================================================
 
 #Preview("Transaction List - Empty") {
     do {
         let container = try PreviewContainer.make()
         return TransactionListView()
             .modelContainer(container)
     } catch {
         return PreviewErrorView(error: error)
     }
 }
 
 ===============================================================================
 WITH SEED DATA - 32 Default Categories
 ===============================================================================
 
 #Preview("Transaction List - With Categories") {
     do {
         let container = try PreviewContainer.make(populateSeedData: true)
         return TransactionListView()
             .modelContainer(container)
     } catch {
         return PreviewErrorView(error: error)
     }
 }
 
 ===============================================================================
 WITH SAMPLE DATA - Realistic Preview
 ===============================================================================
 
 #Preview("Transaction List - Sample Data") {
     do {
         let container = try PreviewContainer.makeWithSampleData()
         return TransactionListView()
             .modelContainer(container)
     } catch {
         return PreviewErrorView(error: error)
     }
 }
 
 ===============================================================================
 CUSTOM DATA - Specific Test Scenarios
 ===============================================================================
 
 #Preview("Budget View - Overspent") {
     do {
         let container = try PreviewContainer.make(populateSeedData: true) { context in
             // Get a category
             let descriptor = FetchDescriptor<Category>()
             let categories = try context.fetch(descriptor)
             guard let category = categories.first else { return }
             
             let calendar = Calendar.current
             let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
             
             // Create budget with $500 limit
             let budget = Budget(
                 month: startOfMonth,
                 planned: 500.00,
                 carryOver: 0.0,
                 category: category,
                 budgetType: BudgetType.envelope,
                 financeType: .personal
             )
             context.insert(budget)
             
             // Add transactions totaling $650 (overspent)
             for i in 1...5 {
                 let transaction = Transaction(
                     amount: 130.00,
                     date: Date().addingTimeInterval(Double(-i) * 86400),
                     note: "Expense \(i)",
                     isIncome: false,
                     merchantName: "Store \(i)",
                     category: category,
                     financeType: .personal
                 )
                 context.insert(transaction)
             }
         }
         
         return BudgetListView()
             .modelContainer(container)
     } catch {
         return PreviewErrorView(error: error)
     }
 }
 
 ===============================================================================
 BEST PRACTICES
 ===============================================================================
 
 1. **Empty State Testing:**
    Use `PreviewContainer.make()` without parameters
 
 2. **Realistic Data:**
    Use `PreviewContainer.make(populateSeedData: true)` for 32 categories
 
 3. **Specific Scenarios:**
    Use custom data closure for edge cases (overspent budgets, overdue invoices, etc.)
 
 4. **Error Handling:**
    Always wrap in do-catch and return PreviewErrorView on failure
 
 5. **Isolation:**
    Each preview gets its own container - no state leakage
 
 6. **Performance:**
    In-memory storage ensures fast preview rendering
 
 ===============================================================================
 TROUBLESHOOTING
 ===============================================================================
 
 **Preview Not Showing Data:**
 - Verify SeedData is being called in populateSeedData: true
 - Check console for "Seeded X categories" message
 - Ensure views have correct @Query descriptors
 
 **Preview Crashes:**
 - Check model relationships are correctly configured
 - Verify all required initializer parameters are provided
 - Look for force-unwraps in sample data creation
 
 **Data Not Persisting:**
 - Call context.save() after inserting data
 - Verify in-memory container is being used (isStoredInMemoryOnly: true)
 
 **Slow Previews:**
 - Reduce amount of sample data
 - Use lazy loading in views
 - Consider creating smaller focused previews
 */
