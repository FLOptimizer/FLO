//  SeedDataService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Fixed to match actual model initializers
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  DEBUG ONLY - Generates realistic test data for all models
//
//  COVERAGE:
//  ✅ BusinessProfile - Company info for invoices
//  ✅ TaxSettings - Filing status, rates, reminders
//  ✅ Accounts - Checking, savings, credit cards, PayPal, cash
//  ✅ Categories - Business & personal (income & expense)
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
    
    /// Seeds ALL data models with realistic test data
    func seedAllData(context: ModelContext) async {
        print("🌱 Starting comprehensive data seed...")
        
        // Order matters - some models depend on others
        let businessProfile = seedBusinessProfile(context: context)
        let _ = seedTaxSettings(context: context)
        let categories = seedCategories(context: context)
        let accounts = seedAccounts(context: context)
        let clients = seedClients(context: context)
        
        // These depend on the above
        seedTransactions(context: context, categories: categories, accounts: accounts)
        seedInvoices(context: context, clients: clients, businessProfile: businessProfile)
        seedMileageTrips(context: context)
        seedReceipts(context: context)
        seedBudgets(context: context, categories: categories)
        seedRecurringTransactions(context: context, categories: categories, accounts: accounts)
        
        // Save everything
        do {
            try context.save()
            print("✅ Seed data saved successfully!")
        } catch {
            print("❌ Failed to save seed data: \(error)")
        }
    }
    
    // MARK: - Reset All Data
    
    /// Deletes ALL data from the database
    func resetAllData(context: ModelContext) async {
        print("🗑️ Resetting all data...")
        
        // Delete in reverse dependency order
        deleteAll(ReceiptData.self, context: context)
        deleteAll(MileageTrip.self, context: context)
        deleteAll(InvoicePayment.self, context: context)
        deleteAll(InvoiceItem.self, context: context)
        deleteAll(Invoice.self, context: context)
        deleteAll(Transaction.self, context: context)
        deleteAll(RecurringTransaction.self, context: context)
        deleteAll(Budget.self, context: context)
        deleteAll(Client.self, context: context)
        deleteAll(Account.self, context: context)
        deleteAll(Category.self, context: context)
        deleteAll(TaxSettings.self, context: context)
        deleteAll(BusinessProfile.self, context: context)
        
        do {
            try context.save()
            print("✅ All data reset successfully!")
        } catch {
            print("❌ Failed to reset data: \(error)")
        }
    }
    
    private func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) {
        do {
            let items = try context.fetch(FetchDescriptor<T>())
            for item in items {
                context.delete(item)
            }
            print("   Deleted \(items.count) \(String(describing: T.self)) items")
        } catch {
            print("   ⚠️ Failed to delete \(String(describing: T.self)): \(error)")
        }
    }
    
    // MARK: - Business Profile
    
    @discardableResult
    func seedBusinessProfile(context: ModelContext) -> BusinessProfile {
        print("   📋 Seeding BusinessProfile...")
        
        // Delete existing profiles first
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
        
        // Delete existing settings first
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
        
        // Business Checking (Primary)
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
        
        // Tax Savings Account
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
        
        // Business Credit Card
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
        
        // PayPal Business
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
        
        // Petty Cash
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
        
        // Personal Checking (for comparison)
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
        
        for account in accounts {
            context.insert(account)
        }
        
        return accounts
    }
    
    // MARK: - Categories
    
    @discardableResult
    func seedCategories(context: ModelContext) -> [Category] {
        print("   📁 Seeding Categories...")
        
        var categories: [Category] = []
        
        // Business Income Categories
        let businessIncomeCategories: [(String, String, String)] = [
            ("Consulting Income", "briefcase.fill", "#10B981"),
            ("Product Sales", "shippingbox.fill", "#3B82F6"),
            ("Affiliate Income", "link.circle.fill", "#8B5CF6"),
            ("Refunds Received", "arrow.uturn.backward.circle.fill", "#06B6D4"),
        ]
        
        for (name, icon, colorHex) in businessIncomeCategories {
            let category = Category(
                name: name,
                icon: icon,
                colorHex: colorHex,
                isDefault: false,
                isIncome: true,
                isTaxDeductible: false
            )
            categories.append(category)
            context.insert(category)
        }
        
        // Business Expense Categories (Tax Deductible)
        let businessExpenseCategories: [(String, String, String)] = [
            ("Office Supplies", "paperclip", "#F59E0B"),
            ("Software & Subscriptions", "app.badge.fill", "#6366F1"),
            ("Professional Services", "person.2.fill", "#EC4899"),
            ("Marketing & Advertising", "megaphone.fill", "#F97316"),
            ("Travel", "airplane", "#0EA5E9"),
            ("Meals & Entertainment", "fork.knife", "#EF4444"),
            ("Equipment", "desktopcomputer", "#8B5CF6"),
            ("Education & Training", "book.fill", "#14B8A6"),
            ("Insurance", "shield.fill", "#64748B"),
            ("Bank & Payment Fees", "creditcard.fill", "#78716C"),
            ("Utilities", "bolt.fill", "#FBBF24"),
            ("Rent & Lease", "building.2.fill", "#A855F7"),
            ("Vehicle Expenses", "car.fill", "#22C55E"),
            ("Phone & Internet", "wifi", "#3B82F6"),
            ("Shipping & Postage", "shippingbox.fill", "#F97316"),
            ("Contractors", "person.badge.clock.fill", "#EC4899"),
            ("Home Office", "house.fill", "#14B8A6"),
        ]
        
        for (name, icon, colorHex) in businessExpenseCategories {
            let category = Category(
                name: name,
                icon: icon,
                colorHex: colorHex,
                isDefault: false,
                isIncome: false,
                isTaxDeductible: true
            )
            categories.append(category)
            context.insert(category)
        }
        
        // Personal Categories
        let personalCategories: [(String, String, String, Bool)] = [
            ("Salary", "dollarsign.circle.fill", "#10B981", true),
            ("Groceries", "cart.fill", "#F59E0B", false),
            ("Dining Out", "fork.knife", "#EF4444", false),
            ("Entertainment", "tv.fill", "#8B5CF6", false),
            ("Shopping", "bag.fill", "#EC4899", false),
            ("Healthcare", "heart.fill", "#EF4444", false),
            ("Personal Care", "figure.walk", "#06B6D4", false),
            ("Gifts", "gift.fill", "#F97316", false),
            ("Transportation", "car.fill", "#3B82F6", false),
        ]
        
        for (name, icon, colorHex, isIncome) in personalCategories {
            let category = Category(
                name: name,
                icon: icon,
                colorHex: colorHex,
                isDefault: false,
                isIncome: isIncome,
                isTaxDeductible: false
            )
            categories.append(category)
            context.insert(category)
        }
        
        return categories
    }
    
    // MARK: - Clients
    
    @discardableResult
    func seedClients(context: ModelContext) -> [Client] {
        print("   👥 Seeding Clients...")
        
        let clientsData: [(String, String, String, String?, String?)] = [
            ("TechStart Inc", "Sarah Johnson", "sarah@techstart.io", "(555) 234-5678", "Great client, always pays on time"),
            ("Green Valley Farms", "Mike Chen", "mike@greenvalley.com", "(555) 345-6789", "Quarterly consulting contract"),
            ("Urban Design Co", "Emily Rodriguez", "emily@urbandesign.co", "(555) 456-7890", "Ongoing web development"),
            ("Summit Financial", "David Kim", "david.kim@summitfin.com", "(555) 567-8901", "Financial software project"),
            ("Bright Ideas Marketing", "Lisa Thompson", "lisa@brightideas.agency", "(555) 678-9012", nil),
            ("CloudNine Solutions", "James Wilson", "james@cloudnine.tech", "(555) 789-0123", "Monthly retainer - $2,500/mo"),
            ("Oceanview Properties", "Maria Garcia", "maria@oceanview.realty", "(555) 890-1234", "Website redesign project"),
            ("Peak Performance Gym", "Chris Brown", "chris@peakgym.fit", "(555) 901-2345", "Mobile app development"),
        ]
        
        var clients: [Client] = []
        
        for (company, contact, email, phone, notes) in clientsData {
            let client = Client(
                name: company,
                contactName: contact,
                email: email
            )
            client.phone = phone
            client.notes = notes
            clients.append(client)
            context.insert(client)
        }
        
        return clients
    }
    
    // MARK: - Transactions
    
    func seedTransactions(context: ModelContext, categories: [Category], accounts: [Account]) {
        print("   💳 Seeding Transactions...")
        
        let calendar = Calendar.current
        let now = Date()
        
        // Get specific categories
        let consultingIncome = categories.first { $0.name == "Consulting Income" }
        let productSales = categories.first { $0.name == "Product Sales" }
        let officeSupplies = categories.first { $0.name == "Office Supplies" }
        let software = categories.first { $0.name == "Software & Subscriptions" }
        let travel = categories.first { $0.name == "Travel" }
        let meals = categories.first { $0.name == "Meals & Entertainment" }
        let marketing = categories.first { $0.name == "Marketing & Advertising" }
        let equipment = categories.first { $0.name == "Equipment" }
        let phone = categories.first { $0.name == "Phone & Internet" }
        let contractors = categories.first { $0.name == "Contractors" }
        let groceries = categories.first { $0.name == "Groceries" }
        let dining = categories.first { $0.name == "Dining Out" }
        let homeOffice = categories.first { $0.name == "Home Office" }
        
        let checking = accounts.first { $0.name == "Business Checking" }
        let creditCard = accounts.first { $0.name == "Business Visa" }
        let paypal = accounts.first { $0.name == "PayPal Business" }
        let personalChecking = accounts.first { $0.name == "Personal Checking" }
        
        var transactionCount = 0
        
        // Generate 3 months of transactions
        for monthOffset in 0..<3 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            
            let year = calendar.component(.year, from: monthDate)
            let month = calendar.component(.month, from: monthDate)
            
            // Income transactions (3-5 per month)
            let incomeCount = Int.random(in: 3...5)
            for i in 0..<incomeCount {
                let day = min(28, (i + 1) * 5 + Int.random(in: 0...3))
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                
                let isConsulting = i % 2 == 0
                let clientNames = ["TechStart Inc", "Summit Financial", "CloudNine Solutions", "Urban Design Co"]
                
                let transaction = Transaction(
                    amount: isConsulting ? Double.random(in: 2500...8500).rounded() : Double.random(in: 500...2000).rounded(),
                    date: date,
                    note: isConsulting ? "Consulting services - \(clientNames.randomElement()!)" : "Digital product sale",
                    isIncome: true,
                    merchantName: isConsulting ? clientNames.randomElement()! : "Gumroad",
                    category: isConsulting ? consultingIncome : productSales,
                    financeType: .business,
                    account: Bool.random() ? checking : paypal
                )
                context.insert(transaction)
                transactionCount += 1
            }
            
            // Business expense transactions (15-25 per month)
            let expenseData: [(Category?, String, ClosedRange<Double>, Account?, Transaction.FinanceType)] = [
                (software, "Adobe Creative Cloud", 54.99...54.99, creditCard, .business),
                (software, "GitHub Pro", 7.00...7.00, creditCard, .business),
                (software, "Slack", 12.50...12.50, creditCard, .business),
                (software, "Zoom Pro", 15.99...15.99, creditCard, .business),
                (software, "AWS", 45.00...150.00, creditCard, .business),
                (software, "Notion", 10.00...10.00, creditCard, .business),
                (officeSupplies, "Amazon", 25.00...150.00, creditCard, .business),
                (officeSupplies, "Staples", 30.00...80.00, creditCard, .business),
                (phone, "Verizon", 85.00...85.00, checking, .business),
                (phone, "Comcast Internet", 79.99...79.99, checking, .business),
                (meals, "Starbucks", 5.50...12.00, creditCard, .business),
                (meals, "Client Lunch", 45.00...120.00, creditCard, .business),
                (marketing, "Google Ads", 100.00...500.00, creditCard, .business),
                (marketing, "Facebook Ads", 50.00...200.00, creditCard, .business),
                (travel, "Uber", 15.00...45.00, creditCard, .business),
                (travel, "Delta Airlines", 250.00...600.00, creditCard, .business),
                (contractors, "Freelancer Payment", 500.00...2000.00, checking, .business),
                (equipment, "Apple Store", 99.00...500.00, creditCard, .business),
                (homeOffice, "IKEA", 150.00...400.00, creditCard, .business),
                // Personal expenses
                (groceries, "Whole Foods", 80.00...200.00, personalChecking, .personal),
                (dining, "Restaurant", 40.00...100.00, personalChecking, .personal),
            ]
            
            let expenseCount = Int.random(in: 15...25)
            for i in 0..<expenseCount {
                let day = min(28, Int.random(in: 1...28))
                guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                
                let expense = expenseData[i % expenseData.count]
                let amount = Double(Int(Double.random(in: expense.2) * 100)) / 100.0
                
                let transaction = Transaction(
                    amount: amount,
                    date: date,
                    note: "",
                    isIncome: false,
                    merchantName: expense.1,
                    category: expense.0,
                    financeType: expense.4,
                    account: expense.3
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
        
        // Create various invoice statuses
        let invoiceConfigs: [(Int, InvoiceStatus, Int, Bool)] = [
            // (daysAgo, status, paymentTermsDays, hasPaid)
            (-45, .paid, 30, true),
            (-30, .paid, 30, true),
            (-25, .paid, 15, true),
            (-20, .sent, 30, false),
            (-40, .overdue, 30, false),
            (-10, .sent, 30, false),
            (-5, .draft, 30, false),
            (-3, .sent, 15, false),
        ]
        
        var invoiceCount = 0
        
        for (index, config) in invoiceConfigs.enumerated() {
            let client = clients[index % clients.count]
            let issueDate = calendar.date(byAdding: .day, value: config.0, to: now)!
            let dueDate = calendar.date(byAdding: .day, value: config.2, to: issueDate)!
            
            let invoice = Invoice(
                invoiceNumber: "INV-\(invoiceNumber)",
                client: client,
                issueDate: issueDate,
                dueDate: dueDate,
                status: config.1,
                paymentTerms: "Net \(config.2)",
                taxRate: 0.0,
                discountAmount: 0.0,
                notes: "Thank you for your business!"
            )
            
            context.insert(invoice)
            
            // Add line items using InvoiceItem
            let lineItemOptions: [(String, Double, Int)] = [
                ("Consulting Services", Double.random(in: 150...250), Int.random(in: 8...40)),
                ("Project Management", Double.random(in: 100...150), Int.random(in: 4...16)),
                ("Technical Documentation", Double.random(in: 75...125), Int.random(in: 2...8)),
            ]
            
            let itemCount = Int.random(in: 1...3)
            
            for i in 0..<itemCount {
                let item = lineItemOptions[i % lineItemOptions.count]
                let invoiceItem = InvoiceItem(
                    invoice: invoice,
                    itemDescription: item.0,
                    quantity: Double(item.2),
                    unitPrice: Double(Int(item.1 * 100)) / 100.0
                )
                context.insert(invoiceItem)
                invoice.items.append(invoiceItem)
            }
            
            // Add payment for paid invoices using the Invoice's addPayment method
            if config.3 {
                let paymentDate = calendar.date(byAdding: .day, value: config.2 - 5, to: issueDate)!
                let paymentMethods: [PaymentMethod] = [.bankTransfer, .check, .creditCard]
                
                invoice.addPayment(
                    amount: invoice.totalAmount,
                    date: paymentDate,
                    paymentMethod: paymentMethods.randomElement()!,
                    notes: "Payment received"
                )
            }
            
            invoiceNumber += 1
            invoiceCount += 1
        }
        
        print("      Created \(invoiceCount) invoices")
    }
    
    // MARK: - Mileage Trips
    
    func seedMileageTrips(context: ModelContext) {
        print("   🚗 Seeding MileageTrips...")
        
        let calendar = Calendar.current
        let now = Date()
        
        // Austin, TX area coordinates for realistic data
        let homeOffice = (lat: 30.2672, lon: -97.7431)  // Downtown Austin
        let clientSite1 = (lat: 30.3074, lon: -97.7534) // North Austin
        let clientSite2 = (lat: 30.2241, lon: -97.7694) // South Austin
        let airport = (lat: 30.1975, lon: -97.6664)     // Austin Airport
        let officeStore = (lat: 30.2850, lon: -97.7384) // Office Depot area
        let bank = (lat: 30.2700, lon: -97.7500)        // Downtown bank
        
        let tripData: [(startLat: Double, startLon: Double, endLat: Double, endLon: Double,
                        startAddr: String, endAddr: String, miles: Double, purpose: TripPurpose,
                        isBusiness: Bool, daysAgo: Int)] = [
            // Business trips
            (homeOffice.lat, homeOffice.lon, clientSite1.lat, clientSite1.lon,
             "Home Office", "TechStart Inc HQ", 12.4, .clientVisit, true, 2),
            (clientSite1.lat, clientSite1.lon, homeOffice.lat, homeOffice.lon,
             "TechStart Inc HQ", "Home Office", 12.4, .clientVisit, true, 2),
            (homeOffice.lat, homeOffice.lon, clientSite2.lat, clientSite2.lon,
             "Home Office", "Downtown Austin", 8.2, .clientMeeting, true, 5),
            (clientSite2.lat, clientSite2.lon, homeOffice.lat, homeOffice.lon,
             "Downtown Austin", "Home Office", 8.5, .clientMeeting, true, 5),
            (homeOffice.lat, homeOffice.lon, officeStore.lat, officeStore.lon,
             "Home Office", "Office Depot", 5.3, .suppliesPickup, true, 7),
            (officeStore.lat, officeStore.lon, homeOffice.lat, homeOffice.lon,
             "Office Depot", "Home Office", 5.3, .suppliesPickup, true, 7),
            (homeOffice.lat, homeOffice.lon, airport.lat, airport.lon,
             "Home Office", "Austin Airport", 18.7, .businessMeeting, true, 10),
            (airport.lat, airport.lon, homeOffice.lat, homeOffice.lon,
             "Austin Airport", "Home Office", 25.4, .businessMeeting, true, 12),
            (homeOffice.lat, homeOffice.lon, bank.lat, bank.lon,
             "Home Office", "Chase Bank", 3.4, .bankingErrand, true, 20),
            // Personal trips
            (homeOffice.lat, homeOffice.lon, 30.2900, -97.7600,
             "Home", "Grocery Store", 3.2, .personal, false, 8),
            (30.2900, -97.7600, homeOffice.lat, homeOffice.lon,
             "Grocery Store", "Home", 3.2, .personal, false, 8),
            (homeOffice.lat, homeOffice.lon, 30.3000, -97.7300,
             "Home", "Gym", 4.1, .personal, false, 15),
        ]
        
        var tripCount = 0
        
        for trip in tripData {
            let tripDate = calendar.date(byAdding: .day, value: -trip.daysAgo, to: now)!
            let hour = Int.random(in: 8...17)
            let minute = Int.random(in: 0...59)
            let startTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tripDate)!
            let duration = (trip.miles / 30.0) * 3600
            let endTime = startTime.addingTimeInterval(duration)
            
            let mileageTrip = MileageTrip(
                startDate: startTime,
                endDate: endTime,
                startLatitude: trip.startLat,
                startLongitude: trip.startLon,
                endLatitude: trip.endLat,
                endLongitude: trip.endLon,
                startAddress: trip.startAddr,
                endAddress: trip.endAddr,
                distanceMiles: trip.miles,
                purpose: trip.purpose,
                isBusinessTrip: trip.isBusiness,
                notes: trip.isBusiness ? "Business travel" : nil,
                isManualEntry: true
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
            ("Staples", 87.43, 3, true),
            ("Amazon", 156.99, 5, true),
            ("Apple Store", 299.00, 8, false),
            ("Office Depot", 45.67, 12, true),
            ("Best Buy", 89.99, 15, false),
            ("Costco", 234.56, 18, true),
            ("Home Depot", 67.89, 22, false),
            ("Target", 123.45, 25, true),
            ("Uber Eats", 34.56, 4, false),
            ("DoorDash", 28.99, 9, false),
        ]
        
        var receiptCount = 0
        
        for (merchant, amount, daysAgo, isMatched) in receiptData {
            let receiptDate = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            
            let receipt = ReceiptData(
                merchantName: merchant,
                totalAmount: amount,
                date: receiptDate,
                rawOCRText: "Sample OCR text for \(merchant)"
            )
            receipt.matchStatus = isMatched ? .manualMatch : .unmatched
            receipt.matchedDate = isMatched ? receiptDate : nil
            receipt.notes = isMatched ? "Matched to transaction" : "Pending review"
            receipt.businessPercentage = 100.0
            receipt.isTaxDeductible = true
            
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
            ("Marketing & Advertising", 750.00, .business),
            ("Office Supplies", 200.00, .business),
            ("Meals & Entertainment", 400.00, .business),
            ("Travel", 1500.00, .business),
            ("Phone & Internet", 200.00, .business),
            ("Groceries", 600.00, .personal),
            ("Dining Out", 300.00, .personal),
        ]
        
        let now = Date()
        
        var budgetCount = 0
        
        for (categoryName, limit, financeType) in budgetData {
            if let category = categories.first(where: { $0.name == categoryName }) {
                let budget = Budget(
                    month: now,
                    planned: limit,
                    carryOver: 0.0,
                    category: category,
                    account: nil,
                    budgetType: .envelope,
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
        
        let software = categories.first { $0.name == "Software & Subscriptions" }
        let phone = categories.first { $0.name == "Phone & Internet" }
        let insurance = categories.first { $0.name == "Insurance" }
        let consultingIncome = categories.first { $0.name == "Consulting Income" }
        
        let checking = accounts.first { $0.name == "Business Checking" }
        let creditCard = accounts.first { $0.name == "Business Visa" }
        
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now)!
        
        let recurringData: [(String, Double, RecurrenceFrequency, Category?, Account?, Bool)] = [
            ("Adobe Creative Cloud", 54.99, .monthly, software, creditCard, false),
            ("GitHub Pro", 7.00, .monthly, software, creditCard, false),
            ("Slack", 12.50, .monthly, software, creditCard, false),
            ("Zoom Pro", 15.99, .monthly, software, creditCard, false),
            ("Notion", 10.00, .monthly, software, creditCard, false),
            ("Verizon Wireless", 85.00, .monthly, phone, checking, false),
            ("Comcast Internet", 79.99, .monthly, phone, checking, false),
            ("Business Insurance", 150.00, .monthly, insurance, checking, false),
            ("CloudNine Retainer", 2500.00, .monthly, consultingIncome, checking, true),
            ("TechStart Monthly", 1500.00, .monthly, consultingIncome, checking, true),
        ]
        
        var recurringCount = 0
        
        for (name, amount, frequency, category, account, isIncome) in recurringData {
            let recurring = RecurringTransaction(
                amount: amount,
                merchantName: name,
                note: isIncome ? "Monthly retainer payment" : "Monthly subscription",
                isIncome: isIncome,
                financeType: .business,
                frequency: frequency,
                startDate: startDate,
                endDate: nil,
                category: category,
                account: account,
                isActive: true
            )
            
            context.insert(recurring)
            recurringCount += 1
        }
        
        print("      Created \(recurringCount) recurring transactions")
    }
    
    // MARK: - Data Counts
    
    /// Get counts of all data types for display
    func getDataCounts(context: ModelContext) -> [(String, Int)] {
        var counts: [(String, Int)] = []
        
        counts.append(("Business Profile", (try? context.fetchCount(FetchDescriptor<BusinessProfile>())) ?? 0))
        counts.append(("Tax Settings", (try? context.fetchCount(FetchDescriptor<TaxSettings>())) ?? 0))
        counts.append(("Accounts", (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0))
        counts.append(("Categories", (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0))
        counts.append(("Clients", (try? context.fetchCount(FetchDescriptor<Client>())) ?? 0))
        counts.append(("Transactions", (try? context.fetchCount(FetchDescriptor<Transaction>())) ?? 0))
        counts.append(("Invoices", (try? context.fetchCount(FetchDescriptor<Invoice>())) ?? 0))
        counts.append(("Mileage Trips", (try? context.fetchCount(FetchDescriptor<MileageTrip>())) ?? 0))
        counts.append(("Receipts", (try? context.fetchCount(FetchDescriptor<ReceiptData>())) ?? 0))
        counts.append(("Budgets", (try? context.fetchCount(FetchDescriptor<Budget>())) ?? 0))
        counts.append(("Recurring", (try? context.fetchCount(FetchDescriptor<RecurringTransaction>())) ?? 0))
        
        return counts
    }
    
    /// Get total count of all records
    func getTotalCount(context: ModelContext) -> Int {
        getDataCounts(context: context).reduce(0) { $0 + $1.1 }
    }
}

#endif
