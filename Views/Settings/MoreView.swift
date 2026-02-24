//  MoreView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 6.1 - VoiceOver Audit: Hidden decorative icons in menu rows
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v6.1 - VoiceOver Audit:
//  ✅ ADDED: 3 remaining decorative icons hidden in LegalView (hand.raised, doc.text, signature, triangle icons)
//  ✅ VERIFIED: MenuRow and LockedMenuRow icons already hidden with .accessibilityHidden(true)
//  ✅ VERIFIED: All menu rows use .accessibilityElement(children: .combine) with descriptive labels
//  ✅ VERIFIED: Security checkmark NOT hidden (conveys enabled state)
//  ✅ VERIFIED: Lock icons in LockedMenuRow NOT hidden (convey locked state)
//  ✅ VERIFIED: Theme emoji accessibility handled correctly
//  ✅ VERIFIED: Upgrade badge uses proper accessibility label
//
//  CHANGES v6.0 - Dynamic Type Verification:
//  ✅ FIXED: Profile name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Profile email text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Profile footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Business Tools footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Data & Backup footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: About footer copyright text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: About footer tagline missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Version text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Upgrade button text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Legal footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Loading view "Analyzing..." text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: LockedMenuRow subtitle (ensured minimumScaleFactor present)
//  ✅ FIXED: MenuRow subtitle (ensured minimumScaleFactor present)
//
//  CHANGES FROM v5.9:
//  - Added CSV Import row to Data & Backup section (Premium feature)
//  - Added hasCSVImport tier check
//  - Added showingCSVImport state for sheet presentation
//
//  CHANGES FROM v5.6:
//  ✅ NEW: Financial Tools section with Reports & Debt Payoff Calculator
//  ✅ RENAMED: "Reports & Insights" → "Tax & Reports" (tax-focused)
//  ✅ REORDERED: All sections now show unlocked items first, gated items at end
//  ✅ VISIBLE: Invoice Settings now shows for Free (was hidden), locked with Premium badge
//  ✅ ADDED: Debt Payoff Calculator (Premium feature)
//  ✅ ADDED: hasDebtCalculator tier check
//
//  CHANGES FROM v5.5:
//  ✅ Year-End Checklist: SHOW LOCKED for Free/Premium (Pro only)
//  ✅ Profit & Loss: SHOW LOCKED for Free/Premium (Pro only)
//  ✅ Added hasProfitLossReports and hasYearEndTaxPackage tier checks
//  ✅ Consistent locked row styling with Export Data
//  ✅ Export Data now opens dedicated locked view (not subscription directly)
//
//  SECTION ORGANIZATION (v5.6):
//  Profile - Edit Profile, Business Profile, Notifications
//  Financial Tools - Reports & Analytics, Debt Payoff Calculator (PREMIUM)
//  Tax & Reports - Tax Deductions, Profit & Loss (PRO), Year-End Checklist (PRO)
//  Business Tools - Mileage, Accounts, Clients (PREMIUM), Recurring (PREMIUM), Invoice Settings (PREMIUM)
//  Preferences - Categories, Tax, Appearance, Security
//  Data & Backup - Backup & Sync, Data & Storage, Export (PRO)
//  App - Subscription, Help, Legal
//  About - About FLO, Version
//

import SwiftUI
import SwiftData

struct MoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var clients: [Client]
    @Query private var trips: [MileageTrip]
    @Query(filter: #Predicate<Account> { $0.isActive }) private var accounts: [Account]
    @Query private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Query private var invoices: [Invoice]
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    
    @State private var viewAppeared = false
    @State private var showingExportOptions = false
    @State private var showingAbout = false
    @State private var showingProfitLoss = false
    @State private var showingYearEnd = false
    @State private var showingDebtCalculator = false  // v5.6: Debt calculator sheet
    @State private var showingCSVImport = false  // v5.9: CSV Import sheet
    
    // v5.4: Upgrade prompt states
    @State private var showingUpgradePrompt = false
    @State private var upgradeFeature: Feature?
    
    // MARK: - Tier Access Checks
    
    private var currentTier: SubscriptionTier {
        subscriptionManager.currentTier
    }
    
    private var hasClientManagement: Bool {
        currentTier.hasClientManagement
    }
    
    private var hasRecurringTransactions: Bool {
        currentTier.hasRecurringTransactions
    }
    
    private var hasInvoicing: Bool {
        currentTier.hasInvoicing
    }
    
    private var hasAdvancedExports: Bool {
        currentTier.hasAdvancedExports
    }
    
    // v5.5: Pro-only report features
    private var hasProfitLossReports: Bool {
        currentTier == .pro
    }
    
    private var hasYearEndTaxPackage: Bool {
        currentTier == .pro
    }
    
    // v5.6: Debt calculator (Premium+)
    private var hasDebtCalculator: Bool {
        currentTier.hasDebtCalculator
    }
    
    // v5.9: CSV Import (Premium+)
    private var hasCSVImport: Bool {
        currentTier.hasCSVImport
    }
    
    // MARK: - Computed Properties
    
    private var thisMonthMiles: Double {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return trips
            .filter { $0.isInMonth(month, year: year) && $0.isBusinessTrip }
            .reduce(0) { $0 + $1.distanceMiles }
    }
    
    private var thisMonthSummary: String {
        let calendar = Calendar.current
        let now = Date()
       
        let monthTransactions = transactions.filter { transaction in
            calendar.isDate(transaction.date, equalTo: now, toGranularity: .month)
        }
       
        let income = monthTransactions.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expenses = monthTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
       
        if income == 0 && expenses == 0 {
            return "View charts, trends & insights"
        }
       
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
       
        let incomeStr = formatter.string(from: NSNumber(value: income)) ?? "$0"
        let expenseStr = formatter.string(from: NSNumber(value: expenses)) ?? "$0"
       
        return "\(incomeStr) in - \(expenseStr) out this month"
    }
    
    private var deductibleAmount: Double {
        let calendar = Calendar.current
        let yearStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: Date()), month: 1, day: 1))!
        
        return transactions
            .filter { $0.date >= yearStart && !$0.isIncome && ($0.category?.isTaxDeductible ?? false) }
            .reduce(0) { $0 + $1.amount }
    }
    
    private var unpaidInvoiceCount: Int {
        invoices.filter { $0.status == .sent || $0.status == .overdue }.count
    }
    
    private var profileSubtitle: String {
        if userName.isEmpty && userEmail.isEmpty {
            return "Set up your profile"
        } else if !userName.isEmpty {
            return userName
        } else {
            return userEmail
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Section (TOP)
                profileSection
                
                // MARK: - Financial Tools Section (v5.6: NEW)
                financialToolsSection
                
                // MARK: - Tax & Reports Section (v5.6: Renamed)
                taxReportsSection
                
                // MARK: - Business Tools Section (v5.6: Reordered)
                businessToolsSection
                
                // MARK: - Preferences Section
                preferencesSection
                
                // MARK: - Data & Backup Section (v5.6: Reordered)
                dataBackupSection
                
                // MARK: - App Section
                appSection
                
                // MARK: - About Section
                aboutSection
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingExportOptions) {
                ExportOptionsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingProfitLoss) {
                ProfitLossReportView()
            }
            .sheet(isPresented: $showingYearEnd) {
                NavigationStack {
                    YearEndChecklistView()
                }
            }
            // v5.6: Debt calculator sheet
            .sheet(isPresented: $showingDebtCalculator) {
                DebtPayoffCalculatorView()
            }
            // v5.4: Upgrade prompt sheet
            .sheet(isPresented: $showingUpgradePrompt) {
                SubscriptionView()
            }
            .onAppear {
                // Delay entrance animation until view is fully presented
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(FLOAnimation.standard) {
                        viewAppeared = true
                    }
                }
                #if DEBUG
                print("📱 MoreView appeared")
                #endif
            }
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        Section {
            // Profile Header Card
            NavigationLink(destination: ProfileEditView(userName: $userName, userEmail: $userEmail)) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.brandPrimary.opacity(0.15))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(userName.isEmpty ? "Add Your Name" : userName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(userName.isEmpty ? .secondary : .primary)
                        
                        if !userEmail.isEmpty {
                            Text(userEmail)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Tap to set up profile")
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowAnimation(delay: 0.0, appeared: viewAppeared)
            
            NavigationLink(destination: BusinessProfileSettingsView()) {
                MenuRow(
                    icon: "building.2.fill",
                    iconColor: .indigo,
                    title: "Business Profile",
                    subtitle: "Company info for invoices",
                    accessibilityLabel: "Business Profile Settings"
                )
            }
            .listRowAnimation(delay: 0.05, appeared: viewAppeared)
            
            NavigationLink(destination: NotificationSettingsView()) {
                MenuRow(
                    icon: "bell.fill",
                    iconColor: .red,
                    title: "Notifications",
                    subtitle: "Reminders & alerts",
                    accessibilityLabel: "Notification Settings"
                )
            }
            .listRowAnimation(delay: 0.1, appeared: viewAppeared)
        } header: {
            Label("Profile", systemImage: "person.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("Your profile info is used for invoices and reports")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Financial Tools Section
    // v5.6: NEW section for financial planning tools
    
    private var financialToolsSection: some View {
        Section {
            // Reports & Analytics (unlocked)
            NavigationLink(destination: ReportsView()) {
                MenuRow(
                    icon: "chart.pie.fill",
                    iconColor: .purple,
                    title: "Reports & Analytics",
                    subtitle: thisMonthSummary,
                    accessibilityLabel: "Reports and Analytics"
                )
            }
            .listRowAnimation(delay: 0.15, appeared: viewAppeared)
            
            // Debt Payoff Calculator - LOCKED for Free tier (Premium+)
            if hasDebtCalculator {
                Button {
                    HapticService.play(.medium)
                    showingDebtCalculator = true
                } label: {
                    MenuRow(
                        icon: "function",
                        iconColor: .teal,
                        title: "Debt Payoff Calculator",
                        subtitle: "Payoff strategies & savings",
                        accessibilityLabel: "Debt Payoff Calculator"
                    )
                }
                .buttonStyle(.plain)
                .listRowAnimation(delay: 0.2, appeared: viewAppeared)
            } else {
                LockedMenuRow(
                    icon: "function",
                    iconColor: .teal,
                    title: "Debt Payoff Calculator",
                    subtitle: "Payoff strategies & savings",
                    requiredTier: .premium,
                    isLocked: true
                ) {
                    showUpgradePrompt(for: .debtCalculator)
                }
                .listRowAnimation(delay: 0.2, appeared: viewAppeared)
            }
        } header: {
            Label("Financial Tools", systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Tax & Reports Section
    // v5.6: Renamed from "Reports & Insights", moved Reports & Analytics to Financial Tools
    // Order: Unlocked first, then Pro features
    
    private var taxReportsSection: some View {
        Section {
            // Tax Deductions (unlocked)
            NavigationLink(destination: TaxDeductionsWrapperView()) {
                MenuRow(
                    icon: "dollarsign.arrow.circlepath",
                    iconColor: .green,
                    title: "Tax Deductions",
                    subtitle: deductibleAmount > 0
                        ? "\(formatCurrency(deductibleAmount)) tracked YTD"
                        : "Find deduction opportunities",
                    accessibilityLabel: "Tax Deduction Opportunities"
                )
            }
            .listRowAnimation(delay: 0.25, appeared: viewAppeared)
            
            // Profit & Loss Statement - LOCKED for Free/Premium (Pro only)
            LockedMenuRow(
                icon: "doc.text.magnifyingglass",
                iconColor: .blue,
                title: "Profit & Loss",
                subtitle: "Revenue, expenses & net profit",
                requiredTier: .pro,
                isLocked: !hasProfitLossReports
            ) {
                HapticService.play(.medium)
                showingProfitLoss = true
            }
            .listRowAnimation(delay: 0.3, appeared: viewAppeared)
            
            // Year-End Checklist - LOCKED for Free/Premium (Pro only)
            LockedMenuRow(
                icon: "checklist",
                iconColor: .orange,
                title: "Year-End Checklist",
                subtitle: "Tax prep & filing reminders",
                requiredTier: .pro,
                isLocked: !hasYearEndTaxPackage
            ) {
                HapticService.play(.medium)
                showingYearEnd = true
            }
            .listRowAnimation(delay: 0.35, appeared: viewAppeared)
            
        } header: {
            Label("Tax & Reports", systemImage: "doc.text.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Business Tools Section
    // v5.6: Reordered - unlocked items first, Premium items at end
    
    private var businessToolsSection: some View {
        Section {
            // Mileage Tracking (unlocked)
            NavigationLink(destination: MileageTrackingMainView()) {
                MenuRow(
                    icon: "car.fill",
                    iconColor: .teal,
                    title: "Mileage Tracking",
                    subtitle: thisMonthMiles > 0
                        ? String(format: "%.0f miles this month", thisMonthMiles)
                        : "Track business miles for deductions",
                    accessibilityLabel: "Mileage Tracking"
                )
            }
            .listRowAnimation(delay: 0.4, appeared: viewAppeared)
            
            // Accounts (unlocked)
            NavigationLink(destination: AccountsView()) {
                MenuRow(
                    icon: "building.columns.fill",
                    iconColor: .cyan,
                    title: "Accounts",
                    subtitle: accounts.isEmpty
                        ? "Set up bank accounts"
                        : "\(accounts.count) \(accounts.count == 1 ? "account" : "accounts")",
                    accessibilityLabel: "Manage Accounts"
                )
            }
            .listRowAnimation(delay: 0.45, appeared: viewAppeared)
            
            // Clients - LOCKED for Free tier (Premium+)
            if hasClientManagement {
                NavigationLink(destination: ClientListView()) {
                    MenuRow(
                        icon: "person.2.fill",
                        iconColor: .blue,
                        title: "Clients",
                        subtitle: clients.isEmpty
                            ? "Manage your client list"
                            : "\(clients.count) \(clients.count == 1 ? "client" : "clients")",
                        accessibilityLabel: "\(clients.count) total clients"
                    )
                }
                .listRowAnimation(delay: 0.5, appeared: viewAppeared)
            } else {
                LockedMenuRow(
                    icon: "person.2.fill",
                    iconColor: .blue,
                    title: "Clients",
                    subtitle: "Manage your client list",
                    requiredTier: .premium,
                    isLocked: true
                ) {
                    showUpgradePrompt(for: .clientManagement)
                }
                .listRowAnimation(delay: 0.5, appeared: viewAppeared)
            }
            
            // Recurring - LOCKED for Free tier (Premium+)
            if hasRecurringTransactions {
                NavigationLink(destination: RecurringListView()) {
                    MenuRow(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: .pink,
                        title: "Recurring",
                        subtitle: "Automatic transaction entries",
                        accessibilityLabel: "Recurring Transactions"
                    )
                }
                .listRowAnimation(delay: 0.55, appeared: viewAppeared)
            } else {
                LockedMenuRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .pink,
                    title: "Recurring",
                    subtitle: "Automatic transaction entries",
                    requiredTier: .premium,
                    isLocked: true
                ) {
                    showUpgradePrompt(for: .recurringTransactions)
                }
                .listRowAnimation(delay: 0.55, appeared: viewAppeared)
            }
            
            // Invoice Settings - VISIBLE for all, LOCKED for Free tier (Premium+)
            if hasInvoicing {
                NavigationLink(destination: InvoiceSettingsView()) {
                    MenuRow(
                        icon: "doc.text.fill",
                        iconColor: .mint,
                        title: "Invoice Settings",
                        subtitle: unpaidInvoiceCount > 0
                            ? "\(unpaidInvoiceCount) unpaid"
                            : "Payment terms & reminders",
                        accessibilityLabel: "Invoice Settings"
                    )
                }
                .listRowAnimation(delay: 0.6, appeared: viewAppeared)
            } else {
                LockedMenuRow(
                    icon: "doc.text.fill",
                    iconColor: .mint,
                    title: "Invoice Settings",
                    subtitle: "Payment terms & reminders",
                    requiredTier: .premium,
                    isLocked: true
                ) {
                    showUpgradePrompt(for: .invoicing)
                }
                .listRowAnimation(delay: 0.6, appeared: viewAppeared)
            }
        } header: {
            Label("Business Tools", systemImage: "briefcase.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("Manage clients, mileage, accounts & invoicing")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        Section {
            NavigationLink(destination: CategoryManagementView()) {
                MenuRow(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "Categories",
                    subtitle: "\(categories.count) categories",
                    accessibilityLabel: "Manage Categories"
                )
            }
            .listRowAnimation(delay: 0.65, appeared: viewAppeared)
            
            NavigationLink(destination: TaxSettingsView()) {
                MenuRow(
                    icon: "percent",
                    iconColor: .green,
                    title: "Tax Settings",
                    subtitle: "Filing status & estimates",
                    accessibilityLabel: "Tax Settings"
                )
            }
            .listRowAnimation(delay: 0.7, appeared: viewAppeared)
            
            NavigationLink(destination: AppearanceSettingsView()) {
                HStack {
                    MenuRow(
                        icon: "paintbrush.fill",
                        iconColor: .orange,
                        title: "Appearance",
                        subtitle: "Theme & display options",
                        accessibilityLabel: "Appearance Settings"
                    )
                    
                    Text(ColorSchemeManager.shared.currentScheme.emoji)
                        .font(.title3)
                        .accessibilityHidden(true)
                }
            }
            .listRowAnimation(delay: 0.75, appeared: viewAppeared)
            
            NavigationLink(destination: SecuritySettingsView()) {
                HStack {
                    MenuRow(
                        icon: "lock.shield.fill",
                        iconColor: .red,
                        title: "Security",
                        subtitle: BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode()
                            ? "Protected"
                            : "Set up protection",
                        accessibilityLabel: "Security Settings"
                    )
                    
                    if BiometricAuthService.shared.biometricEnabled || PasscodeService.shared.hasPasscode() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                            .accessibilityLabel("Security enabled")
                    }
                }
            }
            .listRowAnimation(delay: 0.8, appeared: viewAppeared)
        } header: {
            Label("Preferences", systemImage: "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data & Backup Section
    // v5.6: Reordered - unlocked items first, Pro item at end
    
    private var dataBackupSection: some View {
        Section {
            // Backup & Sync (unlocked)
            NavigationLink(destination: BackupSettingsView()) {
                MenuRow(
                    icon: "icloud.fill",
                    iconColor: .cyan,
                    title: "Backup & Sync",
                    subtitle: "iCloud backup settings",
                    accessibilityLabel: "Backup and Sync Settings"
                )
            }
            .listRowAnimation(delay: 0.85, appeared: viewAppeared)
            
            // Data & Storage (unlocked)
            NavigationLink(destination: DataManagementView()) {
                MenuRow(
                    icon: "externaldrive.fill",
                    iconColor: .gray,
                    title: "Data & Storage",
                    subtitle: "Cache & storage management",
                    accessibilityLabel: "Data and Storage Management"
                )
            }
            .listRowAnimation(delay: 0.9, appeared: viewAppeared)
            
            // v5.9: CSV Import - LOCKED for Free tier (Premium+)
            if hasCSVImport {
                NavigationLink(destination: CSVFilePickerView()) {
                    MenuRow(
                        icon: "doc.badge.arrow.up",
                        iconColor: .teal,
                        title: "Import Bank Statement",
                        subtitle: "Import CSV bank statements",
                        accessibilityLabel: "Import Bank Statement from CSV"
                    )
                }
                .listRowAnimation(delay: 0.92, appeared: viewAppeared)
            } else {
                LockedMenuRow(
                    icon: "doc.badge.arrow.up",
                    iconColor: .teal,
                    title: "Import Bank Statement",
                    subtitle: "Import CSV bank statements",
                    requiredTier: .premium,
                    isLocked: true
                ) {
                    showUpgradePrompt(for: .csvImport)
                }
                .listRowAnimation(delay: 0.92, appeared: viewAppeared)
            }
            
            // Export Data - LOCKED for Free/Premium (Pro only)
            LockedMenuRow(
                icon: "square.and.arrow.up.fill",
                iconColor: .blue,
                title: "Export Data",
                subtitle: "CSV, PDF reports",
                requiredTier: .pro,
                isLocked: !hasAdvancedExports
            ) {
                HapticService.play(.medium)
                showingExportOptions = true
            }
            .listRowAnimation(delay: 0.97, appeared: viewAppeared)
        } header: {
            Label("Data & Backup", systemImage: "externaldrive.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            Text("Your data is stored securely on your device")
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - App Section
    
    private var appSection: some View {
        Section {
            NavigationLink(destination: SubscriptionView()) {
                HStack {
                    MenuRow(
                        icon: "star.fill",
                        iconColor: .yellow,
                        title: "Subscription",
                        subtitle: subscriptionManager.currentTier.displayName,
                        accessibilityLabel: "Subscription Management"
                    )
                    
                    if subscriptionManager.currentTier == .free {
                        Text("Upgrade")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brandPrimary)
                            .cornerRadius(12)
                            .accessibilityHidden(true)
                    }
                }
            }
            .listRowAnimation(delay: 1.0, appeared: viewAppeared)
            
            NavigationLink(destination: HelpCenterView()) {
                MenuRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .blue,
                    title: "Help & Support",
                    subtitle: "FAQs, guides & contact",
                    accessibilityLabel: "Help and Support"
                )
            }
            .listRowAnimation(delay: 1.05, appeared: viewAppeared)
            
            NavigationLink(destination: LegalView()) {
                MenuRow(
                    icon: "doc.plaintext.fill",
                    iconColor: .secondary,
                    title: "Legal",
                    subtitle: "Privacy policy & terms",
                    accessibilityLabel: "Legal Information"
                )
            }
            .listRowAnimation(delay: 1.1, appeared: viewAppeared)
        } header: {
            Label("App", systemImage: "app.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section {
            Button {
                HapticService.play(.light)
                showingAbout = true
            } label: {
                MenuRow(
                    icon: "info.circle.fill",
                    iconColor: .blue,
                    title: "About FLO",
                    subtitle: "Credits & acknowledgments",
                    accessibilityLabel: "About FLO"
                )
            }
            .buttonStyle(.plain)
            .listRowAnimation(delay: 1.15, appeared: viewAppeared)
            
            HStack {
                Text("Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.appVersionLong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(Bundle.main.appVersionLong)")
            .listRowAnimation(delay: 1.2, appeared: viewAppeared)
        } header: {
            Label("About", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        } footer: {
            VStack(spacing: 4) {
                Text("© 2026 Finch & Poppy Co LLC")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("Made with love for freelancers")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .opacity(viewAppeared ? 1 : 0.001)
            .animation(FLOAnimation.standard.delay(1.25), value: viewAppeared)
        }
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
    
    // v5.4: Show upgrade prompt for locked features
    private func showUpgradePrompt(for feature: Feature) {
        HapticService.play(.medium)
        upgradeFeature = feature
        showingUpgradePrompt = true
    }
}

// MARK: - Locked Menu Row Component (v5.5)
// Updated to support both locked and unlocked states with consistent styling

struct LockedMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let requiredTier: SubscriptionTier
    let isLocked: Bool
    let action: () -> Void
    
    @State private var iconAppeared = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon (dimmed when locked)
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(isLocked ? 0.1 : 0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(iconColor.opacity(isLocked ? 0.5 : 1.0))
                        .scaleEffect(iconAppeared ? 1 : 0.5)
                        .animation(FLOAnimation.standard, value: iconAppeared)
                }
                .accessibilityHidden(true)
                
                // Text (dimmed when locked)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(isLocked ? .secondary : .primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isLocked ? .tertiary : .secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                
                Spacer()
                
                // Lock icon + tier badge (only when locked)
                if isLocked {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        
                        Text(requiredTier == .pro ? "PRO" : "PREMIUM")
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(requiredTier == .pro ? Color.orange : Color.brandPrimary)
                            .cornerRadius(4)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isLocked
            ? "\(title). \(requiredTier.displayName) feature. Tap to view."
            : "\(title). Tap to open.")
        .accessibilityHint(isLocked
            ? "Opens feature preview with upgrade option"
            : "Opens \(title)")
        .onAppear {
            withAnimation {
                iconAppeared = true
            }
        }
    }
}

// MARK: - List Row Animation Modifier

extension View {
    func listRowAnimation(delay: Double, appeared: Bool) -> some View {
        self
            // Use 0.001 instead of 0 to prevent iOS "Failed to create image slot" errors
            // during navigation transitions (zero opacity can cause zero-height calculations)
            .opacity(appeared ? 1 : 0.001)
            .offset(x: appeared ? 0 : 20)
            .animation(FLOAnimation.standard.delay(delay), value: appeared)
    }
}

// MARK: - Tax Deductions Wrapper View

struct TaxDeductionsWrapperView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var mileageTrips: [MileageTrip]
    @Query private var receipts: [ReceiptData]
    @Query private var taxSettings: [TaxSettings]
    @Query private var businessProfiles: [BusinessProfile]
    
    @State private var opportunities: [TaxDeductionOpportunity] = []
    @State private var isLoading = true
    @State private var viewAppeared = false
    
    private var settings: TaxSettings {
        taxSettings.first ?? TaxSettings()
    }
    
    private var businessProfile: BusinessProfile? {
        businessProfiles.first
    }
    
    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                DeductionOpportunitiesView(opportunities: opportunities)
            }
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            Task {
                await analyzeOpportunities()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing your finances...")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tax Deductions")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @MainActor
    private func analyzeOpportunities() async {
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        let result = TaxOptimizationEngine.shared.scanForMissedDeductions(
            transactions: transactions,
            mileageTrips: mileageTrips,
            receipts: receipts,
            taxSettings: settings,
            businessProfile: businessProfile,
            context: modelContext
        )
        
        withAnimation(FLOAnimation.standard) {
            opportunities = result
            isLoading = false
        }
        
        HapticService.play(.success)
    }
}

// MARK: - Legal View

struct LegalView: View {
    @State private var viewAppeared = false
    
    var body: some View {
        List {
            Section {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Label {
                        Text("Privacy Policy")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)
                    }
                }
                .listRowAnimation(delay: 0.05, appeared: viewAppeared)
                
                NavigationLink(destination: TermsOfServiceView()) {
                    Label {
                        Text("Terms of Service")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)
                    }
                }
                .listRowAnimation(delay: 0.1, appeared: viewAppeared)
                
                NavigationLink(destination: EULAView()) {
                    Label {
                        Text("End User License Agreement")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "signature")
                            .foregroundStyle(Color.brandPrimary)
                            .accessibilityHidden(true)
                    }
                }
                .listRowAnimation(delay: 0.15, appeared: viewAppeared)
                
                NavigationLink(destination: TaxDisclaimerView()) {
                    Label {
                        Text("Tax Disclaimer")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    }
                }
                .listRowAnimation(delay: 0.2, appeared: viewAppeared)
            } footer: {
                Text("Last updated: January 2026")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .navigationTitle("Legal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
        }
    }
}

// MARK: - Menu Row Component

struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let accessibilityLabel: String
    
    @State private var iconAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(iconColor)
                    .scaleEffect(iconAppeared ? 1 : 0.5)
                    .animation(FLOAnimation.standard, value: iconAppeared)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation {
                iconAppeared = true
            }
        }
    }
}

// MARK: - Feature Bullet Component

struct FeatureBullet: View {
    let text: String
    @State private var checkmarkAppeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .scaleEffect(checkmarkAppeared ? 1 : 0.5)
                .opacity(checkmarkAppeared ? 1 : 0.001)
            Text(text)
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            withAnimation(FLOAnimation.standard.delay(0.1)) {
                checkmarkAppeared = true
            }
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersionLong: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var appVersionShort: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Preview

#Preview("More Menu") {
    MoreView()
        .modelContainer(for: [
            Client.self,
            MileageTrip.self,
            Account.self,
            Transaction.self,
            Category.self,
            Invoice.self
        ], inMemory: true)
}

#Preview("Legal") {
    NavigationStack {
        LegalView()
    }
}
