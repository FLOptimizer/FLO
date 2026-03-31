//  SeedDataService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Expanded categories for comprehensive financial tracking
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  DEBUG ONLY — Generates realistic test data for all models
//
//  CHANGES v1.4:
//  ✅ ADDED: 31 new categories across all four sections
//  ✅ ADDED: Business Income — Rental Income, Royalties, Commission Income, Sponsorship Income
//  ✅ ADDED: Business Expenses — Legal Fees, Accounting & Bookkeeping, Licenses & Permits,
//            Dues & Memberships, Domain & Hosting, Inventory / COGS, Repairs & Maintenance,
//            Interest Expense, Client Gifts, Conferences & Events, Bad Debt / Write-offs
//  ✅ ADDED: Personal Income — Disability Income, Retirement Income, Social Security,
//            Alimony (Received), Child Support (Received)
//  ✅ ADDED: Personal Expenses — Rent / Mortgage, Utilities (Home), Childcare, Pet Expenses,
//            Subscriptions (Personal), Fitness & Wellness, Charity & Donations, Loan Payments,
//            Taxes Paid, Alimony (Paid), Child Support (Paid)
//  ✅ NOTE: All categories now have isDefault: false — users can delete any category
//
//  CHANGES v1.3:
//  ✅ FIXED: Crash when deleting data while views are still rendering
//  ✅ ADDED: Yielding to main actor between deletions to allow UI updates
//  ✅ ADDED: Proper dependency order for deletions (children before parents)
//  ✅ ADDED: MerchantCategoryMapping deletion support
//
//  CHANGES IN v1.2:
//  ✅ FIXED: businessIncomeCategories loop now passes isBusiness: true and correct taxTreatment
//            — Consulting Income, Product Sales, Affiliate Income → .selfEmployment
//            — Refunds Received → .taxExempt (returns of already-taxed money)
//  ✅ FIXED: businessExpenseCategories loop now passes isBusiness: true
//            (previously defaulted to false, landing all business expenses in Personal section)
//  ✅ FIXED: personalCategories loop now passes isBusiness: false explicitly
//            — Salary (personal W-2 income) → taxTreatment: .w2WithholdingPaid
//            — All other personal entries remain .selfEmployment placeholder (expenses)
//  ✅ UPDATED: seedCategories() tuple definitions expanded from 3-tuple to 5-tuple
//             for income categories to carry (name, icon, colorHex, taxTreatment, isBusiness)
//  ✅ PRESERVED: All other seed data unchanged (accounts, transactions, invoices,
//               mileage trips, receipts, budgets, recurring transactions)
//
//  COVERAGE:
//  ✅ BusinessProfile - Company info for invoices
//  ✅ TaxSettings - Filing status, rates, reminders
//  ✅ Accounts - Checking, savings, credit cards, PayPal, cash
//  ✅ Categories - Business & personal (income & expense), now correctly classified
//  ✅ Clients - Sample client list with contact info
//  ✅ Transactions - 3 months of income & expenses
//  ✅ Invoices - Draft, sent, paid, overdue statuses
//  ✅ InvoicePayments - Partial and full payments
//  ✅ MileageTrips - Business & personal trips
//  ✅ ReceiptData - Sample receipts (matched & unmatched)
//  ✅ Budgets - Monthly budgets by category
//  ✅ RecurringTransactions - Subscriptions & recurring income
//

import Foundation
import SwiftData

#if DEBUG

@MainActor
class SeedDataService {

    static let shared = SeedDataService()
    private init() {}

    // MARK: - Main Seed Function

    func seedAllData(context: ModelContext) async {
        print("🌱 Starting comprehensive data seed...")

        let businessProfile = seedBusinessProfile(context: context)
        let _ = seedTaxSettings(context: context)
        let categories = seedCategories(context: context)
        let accounts   = seedAccounts(context: context)
        let clients    = seedClients(context: context)

        seedTransactions(context: context, categories: categories, accounts: accounts)
        seedInvoices(context: context, clients: clients, businessProfile: businessProfile)
        seedMileageTrips(context: context)
        seedReceipts(context: context)
        seedBudgets(context: context, categories: categories)
        seedRecurringTransactions(context: context, categories: categories, accounts: accounts)

        do {
            try context.save()
            print("✅ Seed data saved successfully!")
        } catch {
            print("❌ Failed to save seed data: \(error)")
        }
    }

    // MARK: - Reset All Data (Safe Version v1.3)
    
    /// Safely resets all data with proper UI handling.
    /// Deletes in dependency order and yields between deletions to allow UI updates.
    ///
    /// - Parameter context: The ModelContext to delete from
    func resetAllData(context: ModelContext) async {
        print("🗑️ Resetting all data (safe mode)...")
        
        // Step 1: Delete child objects first (those with relationships to parents)
        // This ordering prevents orphaned references and SwiftData relationship issues
        
        // Receipts (leaf node)
        await deleteAllSafely(ReceiptData.self, context: context)
        
        // Invoice payments (depend on Invoice)
        await deleteAllSafely(InvoicePayment.self, context: context)
        
        // Invoice items (depend on Invoice)
        await deleteAllSafely(InvoiceItem.self, context: context)
        
        // Invoices (depend on Client)
        await deleteAllSafely(Invoice.self, context: context)
        
        // Transactions (depend on Account, Category, RecurringTransaction)
        await deleteAllSafely(Transaction.self, context: context)
        
        // Mileage trips (standalone)
        await deleteAllSafely(MileageTrip.self, context: context)
        
        // Recurring transactions (may link to Category, Account)
        await deleteAllSafely(RecurringTransaction.self, context: context)
        
        // Budgets (may reference Category)
        await deleteAllSafely(Budget.self, context: context)
        
        // Clients (parent of Invoices — already deleted above)
        await deleteAllSafely(Client.self, context: context)
        
        // Accounts (parent of Transactions — already deleted above)
        await deleteAllSafely(Account.self, context: context)
        
        // Categories (parent of Transactions — already deleted above)
        await deleteAllSafely(Category.self, context: context)
        
        // Merchant mappings (standalone, used by CSV import)
        await deleteAllSafely(MerchantCategoryMapping.self, context: context)
        
        // Settings (standalone)
        await deleteAllSafely(TaxSettings.self, context: context)
        await deleteAllSafely(BusinessProfile.self, context: context)

        // Step 2: Final save
        do {
            try context.save()
            print("✅ All data reset successfully!")
        } catch {
            print("❌ Failed to save after reset: \(error)")
        }
    }
    
    /// Safely deletes all instances of a model type with yielding for UI updates
    private func deleteAllSafely<T: PersistentModel>(_ type: T.Type, context: ModelContext) async {
        do {
            let items = try context.fetch(FetchDescriptor<T>())
            let count = items.count
            
            // Delete all items
            for item in items {
                context.delete(item)
            }
            
            // Yield to allow SwiftUI to process the deletions
            // This gives views a chance to update before we continue
            await Task.yield()
            
            print("   Deleted \(count) \(String(describing: T.self)) items")
        } catch {
            print("   ⚠️ Failed to delete \(String(describing: T.self)): \(error)")
        }
    }
    
    // Legacy synchronous delete (kept for backward compatibility in seeders)
    private func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) {
        do {
            let items = try context.fetch(FetchDescriptor<T>())
            for item in items { context.delete(item) }
            print("   Deleted \(items.count) \(String(describing: T.self)) items")
        } catch {
            print("   ⚠️ Failed to delete \(String(describing: T.self)): \(error)")
        }
    }

    // MARK: - Business Profile

    @discardableResult
    func seedBusinessProfile(context: ModelContext) -> BusinessProfile {
        print("   📋 Seeding BusinessProfile...")
        deleteAll(BusinessProfile.self, context: context)

        let profile = BusinessProfile(
            businessName: "Acme Consulting LLC",
            email: "jordan@acmeconsulting.com",
            contactName: "Jordan Smith",
            phone: "(555) 123-4567",
            address: "123 Main Street, Suite 400",
            city: "Austin",
            state: "TX",
            zipCode: "78701",
            country: "USA",
            website: "https://acmeconsulting.com",
            taxId: "12-3456789"
        )

        context.insert(profile)
        return profile
    }

    // MARK: - Tax Settings

    @discardableResult
    func seedTaxSettings(context: ModelContext) -> TaxSettings {
        print("   💰 Seeding TaxSettings...")
        deleteAll(TaxSettings.self, context: context)

        let settings = TaxSettings(
            state: "TX",
            filingStatus: .single,
            customFederalRate: nil,
            customStateRate: nil,
            includeSelfEmploymentTax: true,
            selfEmploymentTaxRate: 0.153,
            enableQuarterlyReminders: true,
            reminderDaysBefore: 14,
            priorYearTaxLiability: 18500.00,
            isHighEarner: false
        )

        context.insert(settings)
        return settings
    }

    // MARK: - Accounts

    @discardableResult
    func seedAccounts(context: ModelContext) -> [Account] {
        print("   🏦 Seeding Accounts...")

        var accounts: [Account] = []

        let checking = Account(
            name: "Business Checking",
            accountType: .checking,
            isPrimary: true,
            isActive: true,
            notes: "Main business account",
            showOnDashboard: true,
            currentBalance: 12458.32,
            startingBalance: 5000.00,
            financeType: .business,
            lastFourDigits: "4567",
            institutionName: "First National Bank",
            colorHex: "#14B8A6"
        )
        accounts.append(checking)

        let savings = Account(
            name: "Tax Savings",
            accountType: .savings,
            isPrimary: false,
            isActive: true,
            notes: "Quarterly tax reserve",
            showOnDashboard: true,
            currentBalance: 8500.00,
            startingBalance: 2000.00,
            financeType: .business,
            lastFourDigits: "7890",
            institutionName: "First National Bank",
            colorHex: "#10B981"
        )
        accounts.append(savings)

        let creditCard = Account(
            name: "Business Visa",
            accountType: .creditCard,
            isPrimary: false,
            isActive: true,
            notes: "2% cash back on all purchases",
            showOnDashboard: true,
            currentBalance: -2340.67,
            startingBalance: 0.0,
            financeType: .business,
            lastFourDigits: "1234",
            institutionName: "Chase",
            colorHex: "#EF4444",
            creditLimit: 15000.00,
            apr: 19.99,
            minimumPaymentPercent: 2.0,
            minimumPaymentFloor: 25.0,
            statementCloseDay: 15,
            paymentDueDay: 10
        )
        accounts.append(creditCard)

        let paypal = Account(
            name: "PayPal Business",
            accountType: .paypal,
            isPrimary: false,
            isActive: true,
            notes: "International client payments",
            showOnDashboard: true,
            currentBalance: 1245.00,
            startingBalance: 0.0,
            financeType: .business,
            lastFourDigits: nil,
            institutionName: "PayPal",
            colorHex: "#3B82F6"
        )
        accounts.append(paypal)

        let cash = Account(
            name: "Petty Cash",
            accountType: .cash,
            isPrimary: false,
            isActive: true,
            notes: "Small office expenses",
            showOnDashboard: false,
            currentBalance: 150.00,
            startingBalance: 200.00,
            financeType: .business,
            lastFourDigits: nil,
            institutionName: nil,
            colorHex: "#F59E0B"
        )
        accounts.append(cash)

        let personalChecking = Account(
            name: "Personal Checking",
            accountType: .checking,
            isPrimary: false,
            isActive: true,
            notes: "Personal expenses only",
            showOnDashboard: false,
            currentBalance: 3250.00,
            startingBalance: 1000.00,
            financeType: .personal,
            lastFourDigits: "9999",
            institutionName: "Chase",
            colorHex: "#8B5CF6"
        )
        accounts.append(personalChecking)

        for account in accounts { context.insert(account) }
        return accounts
    }

    // MARK: - Categories (v2.0 — Comprehensive 127-category expansion)
    //
    // Build 8: Granular categories for year-end tracking.
    // - Utilities, transportation, healthcare, insurance broken into sub-categories
    // - Dual-use pairs for home office / split expenses (business + personal counterparts)
    // - Schedule C line mappings on all business expenses
    // - 10 new personal income + 4 new business income categories

    @discardableResult
    func seedCategories(context: ModelContext) -> [Category] {
        print("   📁 Seeding Categories...")

        var categories: [Category] = []

        // ══════════════════════════════════════════════════════════════════════
        // BUSINESS INCOME (12 categories)
        // ══════════════════════════════════════════════════════════════════════
        //
        // Tuple: (name, icon, colorHex, taxTreatment)
        //
        let businessIncomeCategories: [(String, String, String, TaxTreatment)] = [
            ("Consulting Income",       "briefcase.fill",                    "#10B981", .selfEmployment),
            ("Product Sales",           "shippingbox.fill",                  "#3B82F6", .selfEmployment),
            ("Affiliate Income",        "link.circle.fill",                  "#8B5CF6", .selfEmployment),
            ("Refunds Received",        "arrow.uturn.backward.circle.fill",  "#06B6D4", .taxExempt),
            ("Rental Income",           "building.fill",                     "#F97316", .passiveIncome),
            ("Royalties",               "music.note.list",                   "#EC4899", .passiveIncome),
            ("Commission Income",       "percent",                           "#22C55E", .selfEmployment),
            ("Sponsorship Income",      "star.circle.fill",                  "#FBBF24", .selfEmployment),
            // Build 8 additions
            ("Grants & Awards",         "trophy.fill",                       "#F59E0B", .selfEmployment),
            ("Interest Income (Business)", "percent",                        "#10B981", .selfEmployment),
            ("Service Revenue",         "briefcase.fill",                    "#3B82F6", .selfEmployment),
            ("Resale / Wholesale",      "shippingbox.fill",                  "#F97316", .selfEmployment),
        ]

        for (name, icon, colorHex, taxTreatment) in businessIncomeCategories {
            let category = Category(
                name:            name,
                icon:            icon,
                colorHex:        colorHex,
                isDefault:       false,
                isIncome:        true,
                isTaxDeductible: false,
                isBusiness:      true,
                taxTreatment:    taxTreatment,
                taxOwner:        .primary
            )
            categories.append(category)
            context.insert(category)
        }

        // ══════════════════════════════════════════════════════════════════════
        // BUSINESS EXPENSES (46 categories, all tax deductible)
        // ══════════════════════════════════════════════════════════════════════
        //
        // Tuple: (name, icon, colorHex, scheduleCLine)
        //
        // Generics REMOVED in Build 8 and replaced with granular:
        //   "Insurance" → General Liability, Health (Self-Employed), Property
        //   "Utilities" → Electric, Gas/Natural Gas, Water & Sewer (Business)
        //   "Vehicle Expenses" → Gas/Fuel, Vehicle Insurance, Vehicle Maintenance, Parking/Tolls
        //
        let businessExpenseCategories: [(String, String, String, ScheduleCLine?)] = [
            // ── Office & Operations ──
            ("Office Supplies",             "paperclip",                   "#F59E0B", .line18_officeExpense),
            ("Software & Subscriptions",    "app.badge.fill",              "#6366F1", .line27a_otherExpenses),
            ("Professional Services",       "person.2.fill",               "#EC4899", .line17_legalProfessional),
            ("Marketing & Advertising",     "megaphone.fill",              "#F97316", .line8_advertising),
            ("Equipment",                   "desktopcomputer",             "#8B5CF6", .line13_depreciation),
            ("Education & Training",        "book.fill",                   "#14B8A6", .line27a_otherExpenses),
            ("Bank & Payment Fees",         "creditcard.fill",             "#78716C", .line27a_otherExpenses),
            ("Shipping & Postage",          "shippingbox.fill",            "#F97316", .line27a_otherExpenses),
            ("Domain & Hosting",            "globe",                       "#3B82F6", .line27a_otherExpenses),
            ("Inventory / COGS",            "archivebox.fill",             "#F59E0B", .line27a_otherExpenses),
            ("Printing & Copying",          "printer.fill",                "#64748B", .line27a_otherExpenses),
            ("Cleaning & Janitorial",       "sparkles",                    "#84CC16", .line27a_otherExpenses),
            ("Uniforms & Work Clothing",    "tshirt.fill",                 "#7C3AED", .line27a_otherExpenses),
            ("Research & Development",      "magnifyingglass",             "#3B82F6", .line27a_otherExpenses),

            // ── People ──
            ("Contractors",                 "person.badge.clock.fill",     "#EC4899", .line11_contractLabor),
            ("Employee Wages",              "dollarsign.circle.fill",      "#22C55E", .line26_wages),
            ("Employee Benefits",           "person.3.fill",               "#10B981", .line14_employeeBenefits),
            ("Pension / Profit-Sharing",    "chart.pie.fill",              "#6366F1", .line19_pensionProfitShare),
            ("Commissions & Fees Paid",     "percent",                     "#F59E0B", .line10_commissionsAndFees),

            // ── Travel & Meals ──
            ("Travel",                      "airplane",                    "#0EA5E9", .line24a_travel),
            ("Meals & Entertainment",       "fork.knife",                  "#EF4444", .line24b_meals),
            ("Conferences & Events",        "ticket.fill",                 "#A855F7", .line27a_otherExpenses),
            ("Client Gifts",               "gift.fill",                    "#EC4899", .line27a_otherExpenses),

            // ── Property & Rent ──
            ("Rent & Lease",                "building.2.fill",             "#A855F7", .line20b_rentProperty),
            ("Rent (Equipment/Vehicles)",   "car.2.fill",                  "#8B5CF6", .line20a_rentEquipment),
            ("Repairs & Maintenance",       "wrench.and.screwdriver.fill", "#64748B", .line21_repairsMaintenance),
            ("Depreciation (Section 179)",  "chart.bar.xaxis.ascending",   "#475569", .line13_depreciation),

            // ── Home Office ──
            ("Home Office",                 "house.fill",                  "#14B8A6", .line30_businessUseOfHome),
            ("Business Use of Home",        "house.circle.fill",           "#14B8A6", .line30_businessUseOfHome),

            // ── Utilities (granular, dual-use with personal) ──
            ("Electric (Business)",         "bolt.fill",                   "#EAB308", .line25_utilities),
            ("Gas / Natural Gas (Business)","flame.fill",                  "#F97316", .line25_utilities),
            ("Water & Sewer (Business)",    "drop.fill",                   "#0EA5E9", .line25_utilities),
            ("Phone & Internet",            "wifi",                        "#3B82F6", .line25_utilities),

            // ── Vehicle (granular, dual-use with personal) ──
            ("Gas / Fuel (Business)",       "fuelpump.fill",               "#F97316", .line9_carAndTruck),
            ("Vehicle Insurance (Business)","car.circle.fill",         "#10B981", .line15_insurance),
            ("Vehicle Maintenance (Business)", "wrench.and.screwdriver.fill", "#64748B", .line21_repairsMaintenance),
            ("Parking & Tolls (Business)",  "parkingsign",                 "#0EA5E9", .line9_carAndTruck),

            // ── Insurance (granular) ──
            ("General Liability Insurance", "shield.fill",                 "#64748B", .line15_insurance),
            ("Health Insurance (Self-Employed)", "heart.text.square.fill", "#EF4444", .line15_insurance),
            ("Property Insurance (Business)", "building.fill",             "#475569", .line15_insurance),

            // ── Legal, Financial & Taxes ──
            ("Legal Fees",                  "scale.3d",                    "#6366F1", .line17_legalProfessional),
            ("Accounting & Bookkeeping",    "doc.text.magnifyingglass",    "#10B981", .line17_legalProfessional),
            ("Licenses & Permits",          "checkmark.seal.fill",         "#0EA5E9", .line23_taxesAndLicenses),
            ("Interest Expense",            "percent",                     "#EF4444", .line16b_mortgageOther),
            ("Dues & Memberships",          "person.3.fill",               "#8B5CF6", .line27a_otherExpenses),
            ("Bad Debt / Write-offs",       "xmark.circle.fill",           "#78716C", .line27a_otherExpenses),
            ("Miscellaneous (Business)",    "ellipsis.circle.fill",        "#78716C", .line27a_otherExpenses),
        ]

        for (name, icon, colorHex, scheduleCLine) in businessExpenseCategories {
            let category = Category(
                name:            name,
                icon:            icon,
                colorHex:        colorHex,
                isDefault:       false,
                isIncome:        false,
                isTaxDeductible: true,
                isBusiness:      true,
                taxTreatment:    .selfEmployment,
                taxOwner:        .primary,
                scheduleCLine:   scheduleCLine
            )
            categories.append(category)
            context.insert(category)
        }

        // ══════════════════════════════════════════════════════════════════════
        // PERSONAL INCOME (16 categories)
        // ══════════════════════════════════════════════════════════════════════
        //
        // Tuple: (name, icon, colorHex, taxTreatment, taxOwner)
        //
        let personalIncomeCategories: [(String, String, String, TaxTreatment, TaxOwner)] = [
            ("Salary",                      "dollarsign.circle.fill",              "#10B981", .w2WithholdingPaid, .primary),
            ("Disability Income",           "heart.text.square.fill",              "#EF4444", .taxExempt,         .primary),
            ("Retirement Income",           "banknote.fill",                       "#F59E0B", .passiveIncome,     .primary),
            ("Social Security",             "person.badge.shield.checkmark.fill",  "#3B82F6", .taxExempt,         .primary),
            ("Alimony (Received)",          "arrow.down.circle.fill",              "#8B5CF6", .taxExempt,         .primary),
            ("Child Support (Received)",    "figure.2.and.child.holdinghands",     "#06B6D4", .taxExempt,         .primary),
            // Build 8 additions
            ("Spouse's Salary / W-2",       "person.2.fill",                       "#22C55E", .w2WithholdingPaid, .spouse),
            ("Side Hustle Income",          "star.fill",                           "#F59E0B", .selfEmployment,    .primary),
            ("Interest Income (Savings)",   "percent",                             "#14B8A6", .passiveIncome,     .primary),
            ("Dividend Income",             "chart.bar.fill",                      "#6366F1", .passiveIncome,     .primary),
            ("Capital Gains",               "chart.line.uptrend.xyaxis",           "#22C55E", .passiveIncome,     .primary),
            ("Rental Income (Personal)",    "building.fill",                       "#A855F7", .passiveIncome,     .primary),
            ("Gift / Inheritance",          "gift.fill",                           "#EC4899", .taxExempt,         .primary),
            ("Insurance Payouts",           "shield.lefthalf.filled",              "#0EA5E9", .taxExempt,         .primary),
            ("Tax Refund",                  "arrow.uturn.backward.circle.fill",    "#10B981", .taxExempt,         .primary),
            ("Military Retirement Pay",    "shield.checkered",                    "#475569", .taxExempt,         .primary),
            ("VA Disability",              "cross.circle.fill",                   "#DC2626", .taxExempt,         .primary),
            ("Pell Grant",                 "graduationcap.fill",                  "#3B82F6", .taxExempt,         .primary),
            ("GI Bill / Education Benefits","book.circle.fill",                   "#6366F1", .taxExempt,         .primary),
            ("Scholarships & Fellowships", "medal.fill",                          "#F59E0B", .taxExempt,         .primary),
            ("Bonus Income",               "sparkles",                             "#F97316", .w2WithholdingPaid, .primary),
        ]

        for (name, icon, colorHex, taxTreatment, taxOwner) in personalIncomeCategories {
            let category = Category(
                name:            name,
                icon:            icon,
                colorHex:        colorHex,
                isDefault:       false,
                isIncome:        true,
                isTaxDeductible: false,
                isBusiness:      false,
                taxTreatment:    taxTreatment,
                taxOwner:        taxOwner
            )
            categories.append(category)
            context.insert(category)
        }

        // ══════════════════════════════════════════════════════════════════════
        // PERSONAL EXPENSES (53 categories)
        // ══════════════════════════════════════════════════════════════════════
        //
        // Tuple: (name, icon, colorHex)
        //
        // Generics REMOVED in Build 8 and replaced with granular:
        //   "Utilities (Home)" → Electric, Gas/Natural Gas, Water & Sewer, Trash, Internet, Phone
        //   "Transportation"   → Gas/Fuel, Car Insurance, Car Payment, Car Maintenance, etc.
        //   "Healthcare"       → Doctor, Prescriptions, Dental, Vision, Therapy
        //
        let personalExpenseCategories: [(String, String, String)] = [
            // ── Food & Dining ──
            ("Groceries",                   "cart.fill",                        "#F59E0B"),
            ("Dining Out",                  "fork.knife",                       "#EF4444"),
            ("Coffee & Snacks",             "cup.and.saucer.fill",              "#D97706"),
            ("Alcohol & Bars",              "wineglass.fill",                   "#7C3AED"),

            // ── Housing ──
            ("Rent / Mortgage",             "house.fill",                       "#A855F7"),
            ("Home Insurance",              "house.and.flag.fill",              "#10B981"),
            ("Property Taxes",              "building.columns.fill",            "#DC2626"),
            ("HOA / Condo Fees",            "building.fill",                    "#7C3AED"),
            ("Home Maintenance & Repairs",  "hammer.fill",                      "#64748B"),
            ("Lawn & Garden",               "leaf.fill",                        "#22C55E"),
            ("Home Furnishings",            "sofa.fill",                        "#F59E0B"),

            // ── Utilities (granular, dual-use with business) ──
            ("Electric",                    "bolt.fill",                        "#EAB308"),
            ("Gas / Natural Gas",           "flame.fill",                       "#F97316"),
            ("Water & Sewer",               "drop.fill",                        "#0EA5E9"),
            ("Trash & Recycling",           "trash.fill",                       "#84CC16"),
            ("Internet (Home)",             "wifi",                             "#3B82F6"),
            ("Phone (Personal)",            "phone.fill",                       "#8B5CF6"),

            // ── Transportation (granular) ──
            ("Gas / Fuel",                  "fuelpump.fill",                    "#F97316"),
            ("Car Insurance",               "car.circle.fill",              "#10B981"),
            ("Car Payment",                 "car.fill",                         "#3B82F6"),
            ("Car Maintenance & Repairs",   "wrench.and.screwdriver.fill",      "#64748B"),
            ("Parking & Tolls",             "parkingsign",                      "#6366F1"),
            ("Public Transit",              "bus.fill",                         "#06B6D4"),
            ("Rideshare (Uber/Lyft)",       "figure.wave",                      "#A855F7"),
            ("Car Registration & DMV",      "doc.text.fill",                    "#475569"),

            // ── Insurance (personal) ──
            ("Health Insurance Premiums",   "heart.text.square.fill",           "#EF4444"),
            ("Dental & Vision Insurance",   "eye.fill",                         "#F472B6"),
            ("Life Insurance",              "shield.lefthalf.filled",           "#475569"),
            ("Disability Insurance",        "figure.roll",                      "#78716C"),
            ("Renter's / Umbrella Insurance", "umbrella.fill",                  "#0EA5E9"),

            // ── Health & Medical (granular) ──
            ("Doctor & Specialist Visits",  "stethoscope",                      "#EF4444"),
            ("Prescriptions & Pharmacy",    "pills.fill",                       "#F43F5E"),
            ("Dental Care",                 "mouth.fill",                       "#EC4899"),
            ("Vision & Eye Care",           "eyeglasses",                       "#8B5CF6"),
            ("Therapy & Counseling",        "brain.head.profile",               "#6366F1"),
            ("HSA / FSA Contributions",     "cross.case.fill",                  "#14B8A6"),

            // ── Family & Kids ──
            ("Childcare",                   "figure.and.child.holdinghands",    "#EC4899"),
            ("Tuition & School Fees",       "graduationcap.fill",               "#3B82F6"),
            ("Kids' Activities & Sports",   "figure.run",                       "#22C55E"),
            ("College Savings (529)",       "banknote.fill",                    "#6366F1"),
            ("Elder Care / Parent Support", "figure.2.arms.open",               "#78716C"),
            ("Pet Expenses",                "pawprint.fill",                    "#F97316"),

            // ── Financial ──
            ("Retirement Contributions (IRA/401k)", "chart.line.uptrend.xyaxis", "#14B8A6"),
            ("Emergency Fund / Savings",    "dollarsign.arrow.circlepath",      "#22C55E"),
            ("Loan Payments",               "banknote.fill",                    "#64748B"),
            ("Taxes Paid",                  "building.columns.fill",            "#0EA5E9"),
            ("Alimony (Paid)",              "arrow.up.circle.fill",             "#78716C"),
            ("Child Support (Paid)",        "figure.2.and.child.holdinghands",  "#78716C"),

            // ── Lifestyle ──
            ("Entertainment",               "tv.fill",                          "#8B5CF6"),
            ("Shopping",                    "bag.fill",                          "#EC4899"),
            ("Clothing & Apparel",          "tshirt.fill",                       "#A855F7"),
            ("Personal Care",               "figure.walk",                      "#06B6D4"),
            ("Haircut & Grooming",          "scissors",                          "#F472B6"),
            ("Fitness & Wellness",          "figure.run",                        "#10B981"),
            ("Subscriptions (Personal)",    "play.rectangle.fill",               "#6366F1"),
            ("Vacation & Travel (Personal)","airplane",                          "#06B6D4"),
            ("Hobbies",                     "paintbrush.fill",                   "#F59E0B"),
            ("Books & Education (Personal)","book.fill",                         "#6366F1"),
            ("Gifts",                       "gift.fill",                          "#F97316"),
            ("Charity & Donations",         "hands.sparkles.fill",               "#8B5CF6"),
        ]

        for (name, icon, colorHex) in personalExpenseCategories {
            let category = Category(
                name:            name,
                icon:            icon,
                colorHex:        colorHex,
                isDefault:       false,
                isIncome:        false,
                isTaxDeductible: false,
                isBusiness:      false,
                taxTreatment:    .selfEmployment,
                taxOwner:        .primary
            )
            categories.append(category)
            context.insert(category)
        }

        print("      Created \(categories.count) categories (expected 127)")
        return categories
    }

    // MARK: - Clients

    @discardableResult
    func seedClients(context: ModelContext) -> [Client] {
        print("   👥 Seeding Clients...")

        let clientsData: [(String, String, String, String?, String?)] = [
            ("TechStart Inc",          "Sarah Johnson",  "sarah@techstart.io",        "(555) 234-5678", "Great client, always pays on time"),
            ("Green Valley Farms",     "Mike Chen",      "mike@greenvalley.com",      "(555) 345-6789", "Quarterly consulting contract"),
            ("Urban Design Co",        "Emily Rodriguez","emily@urbandesign.co",      "(555) 456-7890", "Ongoing web development"),
            ("Summit Financial",       "David Kim",      "david.kim@summitfin.com",   "(555) 567-8901", "Financial software project"),
            ("Bright Ideas Marketing", "Lisa Thompson",  "lisa@brightideas.agency",   "(555) 678-9012", nil),
            ("CloudNine Solutions",    "James Wilson",   "james@cloudnine.tech",      "(555) 789-0123", "Monthly retainer - $2,500/mo"),
            ("Oceanview Properties",   "Maria Garcia",   "maria@oceanview.realty",    "(555) 890-1234", "Website redesign project"),
            ("Peak Performance Gym",   "Chris Brown",    "chris@peakgym.fit",         "(555) 901-2345", "Mobile app development"),
        ]

        var clients: [Client] = []

        for (company, contact, email, phone, notes) in clientsData {
            let client = Client(
                name:        company,
                contactName: contact,
                email:       email,
                phone:       phone,
                notes:       notes
            )
            context.insert(client)
            clients.append(client)
        }

        print("      Created \(clients.count) clients")
        return clients
    }

    // MARK: - Transactions

    func seedTransactions(context: ModelContext, categories: [Category], accounts: [Account]) {
        print("   💳 Seeding Transactions...")

        let calendar = Calendar.current
        let now = Date()
        var transactionCount = 0

        // Resolve category references
        let consulting   = categories.first { $0.name == "Consulting Income" }
        let productSales = categories.first { $0.name == "Product Sales" }
        let software     = categories.first { $0.name == "Software & Subscriptions" }
        let officeSupplies = categories.first { $0.name == "Office Supplies" }
        let phone        = categories.first { $0.name == "Phone & Internet" }
        let meals        = categories.first { $0.name == "Meals & Entertainment" }
        let marketing    = categories.first { $0.name == "Marketing & Advertising" }
        let travel       = categories.first { $0.name == "Travel" }
        let contractors  = categories.first { $0.name == "Contractors" }
        let equipment    = categories.first { $0.name == "Equipment" }
        let homeOffice   = categories.first { $0.name == "Home Office" }
        let groceries    = categories.first { $0.name == "Groceries" }
        let dining       = categories.first { $0.name == "Dining Out" }

        let checking        = accounts.first { $0.name == "Business Checking" }
        let creditCard      = accounts.first { $0.name == "Business Visa" }
        let paypal          = accounts.first { $0.name == "PayPal Business" }
        let personalChecking = accounts.first { $0.name == "Personal Checking" }

        // Seed 3 months of transactions
        for monthOffset in 0..<3 {
            let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
            let year  = calendar.component(.year, from: monthDate)
            let month = calendar.component(.month, from: monthDate)

            // Income transactions (4-8 per month)
            let incomeData: [(Category?, String, ClosedRange<Double>, Account?)] = [
                (consulting,   "TechStart Inc - Invoice",        2500.00...8000.00, checking),
                (consulting,   "CloudNine Solutions - Retainer", 2500.00...2500.00, checking),
                (consulting,   "Green Valley Farms - Consulting",1500.00...4000.00, paypal),
                (productSales, "Product License Sale",            250.00...1200.00, checking),
                (consulting,   "Urban Design Co - Development",  3000.00...6000.00, checking),
                (consulting,   "Summit Financial - Advisory",    1800.00...4500.00, paypal),
            ]

            let incomeCount = Int.random(in: 4...8)
            for i in 0..<incomeCount {
                let day = min(28, Int.random(in: 1...28))
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }

                let income = incomeData[i % incomeData.count]
                let amount = Double(Int(Double.random(in: income.2) * 100)) / 100.0

                let transaction = Transaction(
                    amount:      amount,
                    date:        date,
                    note:        "",
                    isIncome:    true,
                    merchantName: income.1,
                    category:    income.0,
                    financeType: .business,
                    account:     income.3
                )
                context.insert(transaction)
                transactionCount += 1
            }

            // Business expense transactions (15-25 per month)
            let expenseData: [(Category?, String, ClosedRange<Double>, Account?, Transaction.FinanceType)] = [
                (software,      "Adobe Creative Cloud", 54.99...54.99,   creditCard,      .business),
                (software,      "GitHub Pro",           7.00...7.00,     creditCard,      .business),
                (software,      "Slack",                12.50...12.50,   creditCard,      .business),
                (software,      "Zoom Pro",             15.99...15.99,   creditCard,      .business),
                (software,      "AWS",                  45.00...150.00,  creditCard,      .business),
                (software,      "Notion",               10.00...10.00,   creditCard,      .business),
                (officeSupplies,"Amazon",               25.00...150.00,  creditCard,      .business),
                (officeSupplies,"Staples",              30.00...80.00,   creditCard,      .business),
                (phone,         "Verizon",              85.00...85.00,   checking,        .business),
                (phone,         "Comcast Internet",     79.99...79.99,   checking,        .business),
                (meals,         "Starbucks",            5.50...12.00,    creditCard,      .business),
                (meals,         "Client Lunch",         45.00...120.00,  creditCard,      .business),
                (marketing,     "Google Ads",           100.00...500.00, creditCard,      .business),
                (marketing,     "Facebook Ads",         50.00...200.00,  creditCard,      .business),
                (travel,        "Uber",                 15.00...45.00,   creditCard,      .business),
                (travel,        "Delta Airlines",       250.00...600.00, creditCard,      .business),
                (contractors,   "Freelancer Payment",   500.00...2000.00,checking,        .business),
                (equipment,     "Apple Store",          99.00...500.00,  creditCard,      .business),
                (homeOffice,    "IKEA",                 150.00...400.00, creditCard,      .business),
                // Personal
                (groceries,     "Whole Foods",          80.00...200.00,  personalChecking,.personal),
                (dining,        "Restaurant",           40.00...100.00,  personalChecking,.personal),
            ]

            let expenseCount = Int.random(in: 15...25)
            for i in 0..<expenseCount {
                let day = min(28, Int.random(in: 1...28))
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }

                let expense = expenseData[i % expenseData.count]
                let amount  = Double(Int(Double.random(in: expense.2) * 100)) / 100.0

                let transaction = Transaction(
                    amount:      amount,
                    date:        date,
                    note:        "",
                    isIncome:    false,
                    merchantName: expense.1,
                    category:    expense.0,
                    financeType: expense.4,
                    account:     expense.3
                )
                context.insert(transaction)
                transactionCount += 1
            }
        }

        print("      Created \(transactionCount) transactions")
    }

    // MARK: - Invoices

    func seedInvoices(context: ModelContext, clients: [Client], businessProfile: BusinessProfile?) {
        print("   📄 Seeding Invoices...")
        guard !clients.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()
        var invoiceNumber = 1001

        let invoiceConfigs: [(Int, InvoiceStatus, Int, Bool)] = [
            (-45, .paid,    30, true),
            (-30, .paid,    30, true),
            (-25, .paid,    15, true),
            (-20, .sent,    30, false),
            (-40, .overdue, 30, false),
            (-10, .sent,    30, false),
            (-5,  .draft,   30, false),
            (-3,  .sent,    15, false),
        ]

        var invoiceCount = 0

        for (index, config) in invoiceConfigs.enumerated() {
            let client    = clients[index % clients.count]
            let issueDate = calendar.date(byAdding: .day, value: config.0, to: now)!
            let dueDate   = calendar.date(byAdding: .day, value: config.2, to: issueDate)!

            let invoice = Invoice(
                invoiceNumber: "INV-\(invoiceNumber)",
                client:        client,
                issueDate:     issueDate,
                dueDate:       dueDate,
                status:        config.1,
                paymentTerms:  "Net \(config.2)",
                taxRate:       0.0,
                discountAmount: 0.0,
                notes:         "Thank you for your business!"
            )

            context.insert(invoice)

            let lineItemOptions: [(String, Double, Int)] = [
                ("Consulting Services",       Double.random(in: 150...250), Int.random(in: 8...40)),
                ("Project Management",        Double.random(in: 100...150), Int.random(in: 4...16)),
                ("Technical Documentation",   Double.random(in: 75...125),  Int.random(in: 2...8)),
            ]

            let itemCount = Int.random(in: 1...3)
            for i in 0..<itemCount {
                let item = lineItemOptions[i % lineItemOptions.count]
                let invoiceItem = InvoiceItem(
                    invoice:         invoice,
                    itemDescription: item.0,
                    quantity:        Double(item.2),
                    unitPrice:       Double(Int(item.1 * 100)) / 100.0
                )
                context.insert(invoiceItem)
                if invoice.items != nil {
                    invoice.items?.append(invoiceItem)
                } else {
                    invoice.items = [invoiceItem]
                }
            }

            if config.3 {
                let paymentDate    = calendar.date(byAdding: .day, value: config.2 - 5, to: issueDate)!
                let paymentMethods: [PaymentMethod] = [.bankTransfer, .check, .creditCard]
                invoice.addPayment(
                    amount:        invoice.totalAmount,
                    date:          paymentDate,
                    paymentMethod: paymentMethods.randomElement()!,
                    notes:         "Payment received"
                )
            }

            invoiceNumber += 1
            invoiceCount  += 1
        }

        print("      Created \(invoiceCount) invoices")
    }

    // MARK: - Mileage Trips

    func seedMileageTrips(context: ModelContext) {
        print("   🚗 Seeding MileageTrips...")

        let calendar = Calendar.current
        let now = Date()

        let homeOffice  = (lat: 30.2672, lon: -97.7431)
        let clientSite1 = (lat: 30.3074, lon: -97.7534)
        let clientSite2 = (lat: 30.2241, lon: -97.7694)
        let airport     = (lat: 30.1975, lon: -97.6664)
        let officeStore = (lat: 30.2850, lon: -97.7384)
        let bank        = (lat: 30.2700, lon: -97.7500)

        let tripData: [(startLat: Double, startLon: Double, endLat: Double, endLon: Double,
                        startAddr: String, endAddr: String, miles: Double, purpose: TripPurpose,
                        isBusiness: Bool, daysAgo: Int)] = [
            (homeOffice.lat,  homeOffice.lon,  clientSite1.lat, clientSite1.lon, "Home Office", "TechStart Inc HQ",  12.4, .clientVisit,    true,  2),
            (clientSite1.lat, clientSite1.lon, homeOffice.lat,  homeOffice.lon,  "TechStart Inc HQ", "Home Office", 12.4, .clientVisit,    true,  2),
            (homeOffice.lat,  homeOffice.lon,  clientSite2.lat, clientSite2.lon, "Home Office", "Downtown Austin",    8.2, .clientMeeting,  true,  5),
            (clientSite2.lat, clientSite2.lon, homeOffice.lat,  homeOffice.lon,  "Downtown Austin", "Home Office",   8.5, .clientMeeting,  true,  5),
            (homeOffice.lat,  homeOffice.lon,  officeStore.lat, officeStore.lon, "Home Office", "Office Depot",       5.3, .suppliesPickup, true,  7),
            (officeStore.lat, officeStore.lon, homeOffice.lat,  homeOffice.lon,  "Office Depot", "Home Office",      5.3, .suppliesPickup, true,  7),
            (homeOffice.lat,  homeOffice.lon,  airport.lat,     airport.lon,     "Home Office", "Austin Airport",    18.7, .businessMeeting,true, 10),
            (airport.lat,     airport.lon,     homeOffice.lat,  homeOffice.lon,  "Austin Airport", "Home Office",   25.4, .businessMeeting,true, 12),
            (homeOffice.lat,  homeOffice.lon,  bank.lat,        bank.lon,        "Home Office", "Chase Bank",         3.4, .bankingErrand,  true, 20),
            // Personal
            (homeOffice.lat,  homeOffice.lon,  30.2900,         -97.7600,        "Home", "Grocery Store",            3.2, .personal,       false, 8),
            (30.2900,         -97.7600,        homeOffice.lat,  homeOffice.lon,  "Grocery Store", "Home",            3.2, .personal,       false, 8),
            (homeOffice.lat,  homeOffice.lon,  30.3000,         -97.7300,        "Home", "Gym",                      4.1, .personal,       false, 15),
        ]

        var tripCount = 0

        for trip in tripData {
            let tripDate  = calendar.date(byAdding: .day, value: -trip.daysAgo, to: now)!
            let hour      = Int.random(in: 8...17)
            let minute    = Int.random(in: 0...59)
            let startTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tripDate)!
            let duration  = (trip.miles / 30.0) * 3600
            let endTime   = startTime.addingTimeInterval(duration)

            let mileageTrip = MileageTrip(
                startDate:       startTime,
                endDate:         endTime,
                startLatitude:   trip.startLat,
                startLongitude:  trip.startLon,
                endLatitude:     trip.endLat,
                endLongitude:    trip.endLon,
                startAddress:    trip.startAddr,
                endAddress:      trip.endAddr,
                distanceMiles:   trip.miles,
                purpose:         trip.purpose,
                isBusinessTrip:  trip.isBusiness,
                notes:           trip.isBusiness ? "Business travel" : nil,
                isManualEntry:   true
            )

            context.insert(mileageTrip)
            tripCount += 1
        }

        print("      Created \(tripCount) mileage trips")
    }

    // MARK: - Receipts

    func seedReceipts(context: ModelContext) {
        print("   🧾 Seeding Receipts...")

        let calendar = Calendar.current
        let now = Date()

        let receiptData: [(String, Double, Int, Bool)] = [
            ("Staples",     87.43,  3,  true),
            ("Amazon",      156.99, 5,  true),
            ("Apple Store", 299.00, 8,  false),
            ("Office Depot",45.67,  12, true),
            ("Best Buy",    89.99,  15, false),
            ("Costco",      234.56, 18, true),
            ("Home Depot",  67.89,  22, false),
            ("Target",      123.45, 25, true),
            ("Uber Eats",   34.56,  4,  false),
            ("DoorDash",    28.99,  9,  false),
        ]

        var receiptCount = 0

        for (merchant, amount, daysAgo, isMatched) in receiptData {
            let receiptDate = calendar.date(byAdding: .day, value: -daysAgo, to: now)!

            let receipt = ReceiptData(
                merchantName: merchant,
                totalAmount:  amount,
                date:         receiptDate,
                rawOCRText:   "Sample OCR text for \(merchant)"
            )
            receipt.matchStatus       = isMatched ? .manualMatch : .unmatched
            receipt.matchedDate       = isMatched ? receiptDate : nil
            receipt.notes             = isMatched ? "Matched to transaction" : "Pending review"
            receipt.businessPercentage = 100.0
            receipt.isTaxDeductible   = true

            context.insert(receipt)
            receiptCount += 1
        }

        print("      Created \(receiptCount) receipts")
    }

    // MARK: - Budgets

    func seedBudgets(context: ModelContext, categories: [Category]) {
        print("   📊 Seeding Budgets...")

        let budgetData: [(String, Double, Transaction.FinanceType)] = [
            ("Software & Subscriptions", 250.00, .business),
            ("Marketing & Advertising",  750.00, .business),
            ("Office Supplies",          200.00, .business),
            ("Meals & Entertainment",    400.00, .business),
            ("Travel",                   1500.00,.business),
            ("Phone & Internet",         200.00, .business),
            ("Groceries",                600.00, .personal),
            ("Dining Out",               300.00, .personal),
        ]

        let now = Date()
        var budgetCount = 0

        for (categoryName, limit, financeType) in budgetData {
            if let category = categories.first(where: { $0.name == categoryName }) {
                let budget = Budget(
                    month:       now,
                    planned:     limit,
                    carryOver:   0.0,
                    category:    category,
                    account:     nil,
                    budgetType:  .envelope,
                    financeType: financeType
                )
                context.insert(budget)
                budgetCount += 1
            }
        }

        print("      Created \(budgetCount) budgets")
    }

    // MARK: - Recurring Transactions

    func seedRecurringTransactions(context: ModelContext, categories: [Category], accounts: [Account]) {
        print("   🔄 Seeding RecurringTransactions...")

        let software        = categories.first { $0.name == "Software & Subscriptions" }
        let phone           = categories.first { $0.name == "Phone & Internet" }
        let insurance       = categories.first { $0.name == "Insurance" }
        let consultingIncome = categories.first { $0.name == "Consulting Income" }

        let checking   = accounts.first { $0.name == "Business Checking" }
        let creditCard = accounts.first { $0.name == "Business Visa" }

        let calendar  = Calendar.current
        let now       = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now)!

        let recurringData: [(String, Double, RecurrenceFrequency, Category?, Account?, Bool)] = [
            ("Adobe Creative Cloud", 54.99,  .monthly, software,        creditCard, false),
            ("GitHub Pro",           7.00,   .monthly, software,        creditCard, false),
            ("Slack",                12.50,  .monthly, software,        creditCard, false),
            ("Zoom Pro",             15.99,  .monthly, software,        creditCard, false),
            ("Notion",               10.00,  .monthly, software,        creditCard, false),
            ("Verizon Wireless",     85.00,  .monthly, phone,           checking,   false),
            ("Comcast Internet",     79.99,  .monthly, phone,           checking,   false),
            ("Business Insurance",   150.00, .monthly, insurance,       checking,   false),
            ("CloudNine Retainer",   2500.00,.monthly, consultingIncome,checking,   true),
            ("TechStart Monthly",    1500.00,.monthly, consultingIncome,checking,   true),
        ]

        var recurringCount = 0

        for (name, amount, frequency, category, account, isIncome) in recurringData {
            let recurring = RecurringTransaction(
                amount:      amount,
                merchantName: name,
                note:        isIncome ? "Monthly retainer payment" : "Monthly subscription",
                isIncome:    isIncome,
                financeType: .business,
                frequency:   frequency,
                startDate:   startDate,
                endDate:     nil,
                category:    category,
                account:     account,
                isActive:    true
            )
            context.insert(recurring)
            recurringCount += 1
        }

        print("      Created \(recurringCount) recurring transactions")
    }

    // MARK: - Data Counts

    func getDataCounts(context: ModelContext) -> [(String, Int)] {
        var counts: [(String, Int)] = []
        counts.append(("Business Profile", (try? context.fetchCount(FetchDescriptor<BusinessProfile>())) ?? 0))
        counts.append(("Tax Settings",     (try? context.fetchCount(FetchDescriptor<TaxSettings>()))     ?? 0))
        counts.append(("Accounts",         (try? context.fetchCount(FetchDescriptor<Account>()))         ?? 0))
        counts.append(("Categories",       (try? context.fetchCount(FetchDescriptor<Category>()))        ?? 0))
        counts.append(("Clients",          (try? context.fetchCount(FetchDescriptor<Client>()))          ?? 0))
        counts.append(("Transactions",     (try? context.fetchCount(FetchDescriptor<Transaction>()))     ?? 0))
        counts.append(("Invoices",         (try? context.fetchCount(FetchDescriptor<Invoice>()))         ?? 0))
        counts.append(("Mileage Trips",    (try? context.fetchCount(FetchDescriptor<MileageTrip>()))     ?? 0))
        counts.append(("Receipts",         (try? context.fetchCount(FetchDescriptor<ReceiptData>()))     ?? 0))
        counts.append(("Budgets",          (try? context.fetchCount(FetchDescriptor<Budget>()))          ?? 0))
        counts.append(("Recurring",        (try? context.fetchCount(FetchDescriptor<RecurringTransaction>())) ?? 0))
        return counts
    }

    func getTotalCount(context: ModelContext) -> Int {
        getDataCounts(context: context).reduce(0) { $0 + $1.1 }
    }
}

#endif
