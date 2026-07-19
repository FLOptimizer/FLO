//  NavigationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.2 - Build 10 Navigation Rewrite
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.2:
//  ✅ FIXED: AppTab.keyboardShortcut (Cmd+1–9 for the Navigate menu) was gated
//           `#if os(macOS)`, so it was absent under Mac Catalyst and the
//           Navigate menu in FLOApp couldn't build for Catalyst. Now also
//           compiled for targetEnvironment(macCatalyst).
//
//  CHANGES v2.1:
//  ✅ ADDED: NavigationDestination now conforms to Identifiable (id: Self) so it
//           can drive SwiftUI `.sheet(item:)` — used by SettingsView v5.2 to
//           present detail destinations as sheets on portrait iPhone.
//
//  CHANGES v2.0 (Build 10):
//  ✅ REWRITE: AppTab enum expanded to 11 alphabetical tabs (was 5)
//  ✅ REMOVED: "More" tab — all features now first-class sidebar items
//  ✅ ADDED: String rawValues (was Int) for cleaner deep linking
//  ✅ ADDED: Emoji property for landscape sidebar icons
//  ✅ ADDED: Keyboard shortcut support for macOS (Cmd+1-9)
//  ✅ ADDED: Portrait tabs subset (5 most-used for iPhone portrait)
//  ✅ UPDATED: Deep link paths for new tab structure
//  ✅ PRESERVED: All entity navigation, sheet presentation, notification handling
//
//  Previous: v1.4 — Sonnet 4.5 Corruption Fix
//

import SwiftUI
import Combine

// MARK: - Tab Definition

/// All app tabs — alphabetical, used for sidebar and navigation.
/// Portrait mode shows a 5-tab subset; landscape/macOS shows all 11.
enum AppTab: String, CaseIterable, Identifiable {
    case accounts
    case assistant
    case budgets
    case clients
    case dashboard
    case debtAccelerator
    case invoices
    case mileage
    case receipts
    case reports
    case settings
    case tax
    case transactions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .accounts:     return "Accounts"
        case .assistant:    return "My Assistant"
        case .budgets:      return "Budgets"
        case .clients:      return "Clients"
        case .dashboard:        return "Dashboard"
        case .debtAccelerator:  return "Debt Accelerator"
        case .invoices:         return "Invoices"
        case .mileage:      return "Mileage"
        case .receipts:     return "Receipts"
        case .reports:      return "Reports"
        case .settings:     return "Settings"
        case .tax:          return "Tax"
        case .transactions: return "Transactions"
        }
    }

    var icon: String {
        switch self {
        case .accounts:     return "building.columns"
        case .assistant:    return "bubble.left.and.text.bubble.right"
        case .budgets:      return "chart.bar.fill"
        case .clients:      return "person.2.fill"
        case .dashboard:        return "chart.line.uptrend.xyaxis"
        case .debtAccelerator:  return "chart.line.downtrend.xyaxis"
        case .invoices:         return "doc.text.fill"
        case .mileage:      return "car.fill"
        case .receipts:     return "doc.text.magnifyingglass"
        case .reports:      return "chart.bar.doc.horizontal"
        case .settings:     return "gearshape.fill"
        case .tax:          return "building.columns.fill"
        case .transactions: return "creditcard.fill"
        }
    }

    var emoji: String {
        switch self {
        case .accounts:     return "🏦"
        case .assistant:    return "💬"
        case .budgets:      return "📈"
        case .clients:      return "👥"
        case .dashboard:        return "📊"
        case .debtAccelerator:  return "💳"
        case .invoices:         return "📋"
        case .mileage:      return "🚗"
        case .receipts:     return "🧾"
        case .reports:      return "📑"
        case .settings:     return "⚙️"
        case .tax:          return "🏛️"
        case .transactions: return "💳"
        }
    }

    /// Deep link path component
    var pathComponent: String { rawValue }

    /// Initialize from deep link path (supports legacy "more/*" paths)
    init?(pathComponent: String) {
        switch pathComponent.lowercased() {
        case "accounts":                        self = .accounts
        case "assistant":                       self = .assistant
        case "budgets":                         self = .budgets
        case "clients":                         self = .clients
        case "dashboard", "home":               self = .dashboard
        case "debtaccelerator", "debt":         self = .debtAccelerator
        case "invoices":                        self = .invoices
        case "mileage":                         self = .mileage
        case "receipts":                        self = .receipts
        case "reports":                         self = .reports
        case "settings":                        self = .settings
        case "tax":                             self = .tax
        case "transactions", "expenses":        self = .transactions
        default:                                return nil
        }
    }

    /// The 5 tabs shown in iPhone portrait TabView.
    static let portraitTabs: [AppTab] = [
        .dashboard, .transactions, .budgets, .invoices
    ]

    // Available on native macOS AND Mac Catalyst. The menu-bar commands that
    // consume this live in FLOApp; under Catalyst `os(macOS)` is false, so the
    // shortcut must also be exposed via targetEnvironment(macCatalyst) or the
    // Navigate menu fails to build.
    #if os(macOS) || targetEnvironment(macCatalyst)
    /// Keyboard shortcut: Cmd+1 through Cmd+9 for first 9 tabs.
    var keyboardShortcut: KeyEquivalent? {
        guard let index = AppTab.allCases.firstIndex(of: self), index < 9 else { return nil }
        return KeyEquivalent(Character("\(index + 1)"))
    }
    #endif
}

// MARK: - Navigation Destination

/// Represents a specific destination within the app
enum NavigationDestination: Hashable, Identifiable {
    /// Enables `.sheet(item:)` presentation (portrait Settings detail routing).
    /// Safe because the enum is already Hashable.
    var id: Self { self }

    // Dashboard
    case dashboard

    // Transactions
    case transactionList
    case transactionDetail(id: UUID)
    case addTransaction(isIncome: Bool)

    // Budgets
    case budgetList
    case budgetDetail(id: UUID)
    case createBudget
    case recurringList

    // Debt Accelerator
    case debtAcceleratorDashboard
    case debtAcceleratorDetail(id: UUID)
    case createDebtPlan

    // Invoices
    case invoiceList
    case invoiceDetail(id: UUID)
    case createInvoice

    // Clients
    case clientList
    case clientDetail(id: UUID)

    // Mileage
    case mileageTracking
    case mileageTripDetail(id: UUID)

    // Accounts
    case accounts
    case accountDetail(id: UUID)
    case addAccount
    case addLinkedCard(accountId: UUID)
    case reconcileAccount(accountId: UUID)

    // Invoices - Zone 3 sub-layers
    case editInvoice(id: UUID)
    case markInvoiceSent(id: UUID)
    case markInvoicePaid(id: UUID)

    // Clients - Zone 3 sub-layers
    case editClient(id: UUID)

    // Receipts
    case receiptScanner
    case receiptStorage
    case receiptMatchingQueue

    // Reports
    case reports
    case yearEndChecklist

    // Settings
    case settings
    case categories
    case subscription
    case settingsAppearance
    case settingsNotifications
    case settingsSecurity
    case settingsDataStorage
    case settingsBusinessProfile
    case settingsEditProfile
    case settingsAbout
    case settingsSubscription
    case settingsCategories
    case settingsBackup
    case settingsReceiptStorage
    case settingsEULA
    case settingsHelpCenter
    case settingsPrivacyPolicy
    case settingsTaxDisclaimer
    case settingsTermsOfService

    // Tax
    case taxOverview
    case taxDeductions
    case taxBusinessSummary
    case taxDepreciationSchedule
    case taxCarryforwardRegister
    case taxFilingChecklist
    case taxYearEndClosing
    case taxCPAExport
    case taxJurisdictions

    // Tax — Phase 3: Intelligence
    case taxBasisAlerts
    case taxEstimatedPayments
    case taxNAICSCodes
    case taxMultiYearComparison

    // Tax — Phase 4: Partner Integration
    case taxPreparerChecklist

    // Settings — Tools (v6.5: orphaned MoreView items)
    case debtCalculator
    case cashFlowForecast
    // recurringList already declared in Budgets section above
    case invoiceSettings
    case csvImport
    case householdSettings
}

// MARK: - Deep Link

/// Parsed deep link structure
struct DeepLink {
    let tab: AppTab
    let destination: NavigationDestination?
    let entityId: UUID?

    /// Parse a URL into a DeepLink
    /// Supports: flo://transactions/detail?id=xxx
    /// Also supports legacy: flo://more/mileage → flo://mileage
    static func parse(url: URL) -> DeepLink? {
        guard url.scheme == "flo" || url.scheme == "finance ledger optimizer" else {
            return nil
        }

        // Get path components
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard let first = pathComponents.first else { return nil }

        // Legacy "more/*" path support → redirect to new first-class tabs
        if first.lowercased() == "more" && pathComponents.count > 1 {
            let subPath = pathComponents[1].lowercased()
            if let tab = AppTab(pathComponent: subPath) {
                // Re-parse with the sub-path as the first component
                let newComponents = Array(pathComponents.dropFirst())
                let newPath = newComponents.joined(separator: "/")
                if let newURL = URL(string: "flo://\(newPath)?\(url.query ?? "")") {
                    return parse(url: newURL)
                }
                return DeepLink(tab: tab, destination: nil, entityId: nil)
            }
        }

        guard let tab = AppTab(pathComponent: first) else {
            return nil
        }

        // Parse action/id from remaining path
        var destination: NavigationDestination? = nil
        var entityId: UUID? = nil

        // Check for ID in query parameters
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let idString = queryItems.first(where: { $0.name == "id" })?.value,
               let id = UUID(uuidString: idString) {
                entityId = id
            }
        }

        // Parse destination from path
        if pathComponents.count > 1 {
            let action = pathComponents[1].lowercased()

            switch (tab, action) {
            case (.transactions, "add"):
                let isIncome = url.query?.contains("income=true") ?? false
                destination = .addTransaction(isIncome: isIncome)
            case (.transactions, "detail"):
                if let id = entityId {
                    destination = .transactionDetail(id: id)
                }
            case (.invoices, "create"):
                destination = .createInvoice
            case (.invoices, "detail"):
                if let id = entityId {
                    destination = .invoiceDetail(id: id)
                }
            case (.budgets, "create"):
                destination = .createBudget
            case (.budgets, "detail"):
                if let id = entityId {
                    destination = .budgetDetail(id: id)
                }
            case (.clients, "detail"):
                if let id = entityId {
                    destination = .clientDetail(id: id)
                }
            case (.mileage, "detail"):
                if let id = entityId {
                    destination = .mileageTripDetail(id: id)
                }
            case (.accounts, "detail"):
                if let id = entityId {
                    destination = .accountDetail(id: id)
                }
            default:
                break
            }
        }

        return DeepLink(tab: tab, destination: destination, entityId: entityId)
    }
}

// MARK: - Navigation Service

@MainActor
final class NavigationService: ObservableObject {

    // MARK: - Singleton

    static let shared = NavigationService()

    // MARK: - Published Properties

    /// Currently selected tab
    @Published var selectedTab: AppTab = .dashboard

    /// Selected detail item (for Zone 3 in landscape/macOS)
    @Published var selectedDetail: NavigationDestination?

    /// Pending navigation (set before view appears)
    @Published private(set) var pendingDestination: NavigationDestination?

    // MARK: - Unsaved Changes Guard (v3.14)
    //
    // Editors in Zone 3 report their dirty state here. When a caller requests
    // a navigation while `hasUnsavedChanges` is true, the guard stores the
    // target in `pendingUnsavedNavigation` instead of applying it, the parent
    // shows a confirmation dialog, and the user chooses Discard (apply) or
    // Keep Editing (cancel). Prevents silent loss of in-flight edits when the
    // user clicks away from a partially-edited entity.

    /// True when the currently-displayed detail editor has unsaved edits.
    /// Editors set this via `.onChange(of: isDirty)`; they MUST clear it on
    /// save, cancel, and disappear so the next editor starts clean.
    @Published var hasUnsavedChanges: Bool = false

    /// A navigation that was requested while `hasUnsavedChanges` was true and
    /// is waiting on user confirmation. Wrapped in a struct so `.target == nil`
    /// (meaning "clear detail") remains a distinct, resumable intent.
    @Published var pendingUnsavedNavigation: PendingNavigation? = nil

    struct PendingNavigation: Equatable {
        let target: NavigationDestination?
    }

    /// My Assistant shared context (Zone 2 writes, Zone 3 reads)
    let assistantContext = AssistantContext()

    /// Sheet presentation states
    @Published var showingAddTransaction = false
    @Published var showingReceiptScanner = false
    @Published var showingCreateInvoice = false
    @Published var showingCreateBudget = false
    @Published var showingMoveMoney = false

    /// Build 10: Signal TransactionListView to open the To Review segment
    @Published var openTransactionReviewSection = false

    /// Pre-filled data for sheets
    @Published var addTransactionIsIncome = false
    @Published var showingGlobalSearch = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        #if DEBUG
        print("🧭 NavigationService initialized (v2.2 — 13 tabs)")
        #endif
    }

    // MARK: - Tab Navigation

    /// Navigate to a specific tab
    func navigateTo(_ tab: AppTab) {
        guard selectedTab != tab else { return }

        HapticService.play(.selection)
        selectedTab = tab

        #if DEBUG
        print("🧭 Navigated to tab: \(tab.title)")
        #endif

        trackNavigation(to: tab)
    }

    /// Navigate to tab and then to a specific detail
    func navigateTo(_ tab: AppTab, destination: NavigationDestination) {
        selectedTab = tab
        HapticService.play(.selection)

        // Small delay to ensure tab switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.selectedDetail = destination
        }

        #if DEBUG
        print("🧭 Navigated to tab: \(tab.title), destination: \(destination)")
        #endif
    }

    // MARK: - Unsaved-Changes-Aware Navigation (v3.14)

    /// Preferred entry point for Zone 2 row taps and other sidebar-driven
    /// navigations into Zone 3. Honors the unsaved-changes guard:
    /// - if the current editor is clean → applies immediately
    /// - if dirty and the requested target differs from current →
    ///   stores the request in `pendingUnsavedNavigation` so the UI can
    ///   show the confirmation prompt. Does NOT change `selectedDetail`.
    func requestDetailNavigation(to target: NavigationDestination?) {
        if hasUnsavedChanges && selectedDetail != nil && selectedDetail != target {
            pendingUnsavedNavigation = PendingNavigation(target: target)
        } else {
            selectedDetail = target
        }
    }

    /// User confirmed discarding unsaved edits. Apply the pending navigation
    /// and clear both the pending record and the dirty flag. Safe no-op if
    /// there is no pending navigation.
    func discardUnsavedAndNavigate() {
        guard let pending = pendingUnsavedNavigation else { return }
        hasUnsavedChanges = false
        selectedDetail = pending.target
        pendingUnsavedNavigation = nil
    }

    /// User chose to keep editing. Drop the pending request; the current
    /// editor stays visible with its dirty state intact.
    func cancelPendingUnsavedNavigation() {
        pendingUnsavedNavigation = nil
    }

    // MARK: - Entity-Specific Navigation

    func openInvoice(id: UUID) {
        navigateTo(.invoices, destination: .invoiceDetail(id: id))
    }

    func openTransaction(id: UUID) {
        navigateTo(.transactions, destination: .transactionDetail(id: id))
    }

    func openBudget(id: UUID) {
        navigateTo(.budgets, destination: .budgetDetail(id: id))
    }

    func openClient(id: UUID) {
        navigateTo(.clients, destination: .clientDetail(id: id))
    }

    func openMileageTrip(id: UUID) {
        navigateTo(.mileage, destination: .mileageTripDetail(id: id))
    }

    func openAccount(id: UUID) {
        navigateTo(.accounts, destination: .accountDetail(id: id))
    }

    /// Build 10: Navigate to Transactions tab and open the To Review segment
    func openTransactionReview() {
        selectedTab = .transactions
        HapticService.play(.selection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.openTransactionReviewSection = true
        }
    }

    // MARK: - Quick Actions

    func showAddTransaction(isIncome: Bool = false) {
        addTransactionIsIncome = isIncome
        showingAddTransaction = true
        HapticService.play(.medium)
    }

    func showReceiptScanner() {
        showingReceiptScanner = true
        HapticService.play(.medium)
    }

    func showCreateInvoice() {
        showingCreateInvoice = true
        HapticService.play(.medium)
    }

    func showCreateBudget() {
        showingCreateBudget = true
        HapticService.play(.medium)
    }

    func showMoveMoney() {
        showingMoveMoney = true
        HapticService.play(.medium)
    }

    func showMileageTracking() {
        navigateTo(.mileage)
    }

    func showSettings() {
        navigateTo(.settings)
    }

    func showGlobalSearch() {
        showingGlobalSearch = true
        HapticService.play(.medium)
    }

    func showReceiptStorage() {
        navigateTo(.receipts)
    }

    // MARK: - Deep Link Handling

    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        guard let deepLink = DeepLink.parse(url: url) else {
            #if DEBUG
            print("🧭 Could not parse deep link: \(url)")
            #endif
            return false
        }

        #if DEBUG
        print("🧭 Handling deep link: \(url)")
        print("   Tab: \(deepLink.tab.title)")
        print("   Destination: \(String(describing: deepLink.destination))")
        #endif

        if let destination = deepLink.destination {
            navigateTo(deepLink.tab, destination: destination)
        } else {
            navigateTo(deepLink.tab)
        }

        HapticService.play(.medium)
        return true
    }

    /// Handle push notification userInfo
    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "invoice_overdue", "invoice_paid":
            if let idString = userInfo["invoice_id"] as? String,
               let id = UUID(uuidString: idString) {
                openInvoice(id: id)
            }
        case "budget_exceeded":
            if let idString = userInfo["budget_id"] as? String,
               let id = UUID(uuidString: idString) {
                openBudget(id: id)
            }
        case "tax_deadline":
            navigateTo(.tax)
        case "mileage_trip_complete":
            if let idString = userInfo["trip_id"] as? String,
               let id = UUID(uuidString: idString) {
                openMileageTrip(id: id)
            }
        case "receipt_ready":
            navigateTo(.receipts)
        case "debt_payment_reminder":
            navigateTo(.debtAccelerator)
        default:
            navigateTo(.dashboard)
        }

        #if DEBUG
        print("🧭 Handled notification: \(type)")
        #endif
    }

    // MARK: - Analytics Hook

    private func trackNavigation(to tab: AppTab) {
        // FUTURE: Analytics integration planned for post-launch
    }
}

// MARK: - View Extension

extension View {
    @MainActor
    func withNavigationService() -> some View {
        self.environmentObject(NavigationService.shared)
    }
}
