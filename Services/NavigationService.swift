//  NavigationService.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Sonnet 4.5 Corruption Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.4:
//  ✅ FIXED: Removed duplicate code blocks introduced by Sonnet 4.5
//  ✅ FIXED: Removed duplicate openTransaction/openBudget/openClient methods
//  ✅ FIXED: Removed duplicate "Deep Link Handling" MARK section
//  ✅ FIXED: Restored all mojibake characters to proper Unicode
//
//  CHANGES v1.3:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters
//
//  CHANGES v1.2:
//  - Added client + accounts deep link routes for Spotlight
//
//  Centralized navigation service for programmatic navigation,
//  deep linking, and push notification handling.
//
//  FEATURES:
//  ✅ Tab selection from anywhere in the app
//  ✅ Per-tab navigation paths for drill-down
//  ✅ Deep link URL handling (flo://)
//  ✅ Push notification navigation
//  ✅ Entity-specific navigation (invoice, transaction, etc.)
//  ✅ HapticService integration
//  ✅ Analytics-ready hooks
//
//  USAGE:
//  - NavigationService.shared.navigateTo(.invoices)
//  - NavigationService.shared.openInvoice(id: invoice.id)
//  - NavigationService.shared.handleDeepLink(url)
//

import SwiftUI
import Combine

// MARK: - Tab Definition

/// App tabs - mirrored from ContentView for shared access
enum AppTab: Int, CaseIterable, Identifiable, Codable {
    case dashboard = 0
    case transactions = 1
    case budgets = 2
    case invoices = 3
    case more = 4
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .transactions: return "Transactions"
        case .budgets: return "Budgets"
        case .invoices: return "Invoices"
        case .more: return "More"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .transactions: return "list.bullet.rectangle"
        case .budgets: return "chart.bar.fill"
        case .invoices: return "doc.text.fill"
        case .more: return "ellipsis"
        }
    }
    
    /// Deep link path component
    var pathComponent: String {
        switch self {
        case .dashboard: return "dashboard"
        case .transactions: return "transactions"
        case .budgets: return "budgets"
        case .invoices: return "invoices"
        case .more: return "more"
        }
    }
    
    /// Initialize from deep link path
    init?(pathComponent: String) {
        switch pathComponent.lowercased() {
        case "dashboard", "home": self = .dashboard
        case "transactions", "expenses": self = .transactions
        case "budgets": self = .budgets
        case "invoices": self = .invoices
        case "more", "settings": self = .more
        default: return nil
        }
    }
}

// MARK: - Navigation Destination

/// Represents a specific destination within the app
enum NavigationDestination: Hashable {
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
    
    // Invoices
    case invoiceList
    case invoiceDetail(id: UUID)
    case createInvoice
    case clientList
    case clientDetail(id: UUID)
    
    // More
    case mileageTracking
    case mileageTripDetail(id: UUID)
    case accounts
    case categories
    case settings
    case reports
    case yearEndChecklist
    case subscription
    
    // Receipts
    case receiptScanner
    case receiptStorage
    case receiptMatchingQueue
}

// MARK: - Deep Link

/// Parsed deep link structure
struct DeepLink {
    let tab: AppTab
    let destination: NavigationDestination?
    let entityId: UUID?
    
    /// Parse a URL into a DeepLink
    /// Supports: flo://invoices/detail?id=xxx
    static func parse(url: URL) -> DeepLink? {
        guard url.scheme == "flo" || url.scheme == "finance ledger optimizer" else {
            return nil
        }
        
        // Get path components
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        
        guard let first = pathComponents.first,
              let tab = AppTab(pathComponent: first) else {
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
            case (.more, "mileage"):
                destination = .mileageTracking
            case (.more, "settings"):
                destination = .settings
            case (.more, "receipts"):
                destination = .receiptScanner
            case (.more, "clients"):
                // flo://more/clients or flo://more/clients/detail?id=xxx
                if pathComponents.count > 2 && pathComponents[2].lowercased() == "detail",
                   let id = entityId {
                    destination = .clientDetail(id: id)
                } else {
                    destination = .clientList
                }
            case (.more, "accounts"):
                destination = .accounts
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
    
    /// Navigation paths for each tab (for NavigationStack drill-down)
    @Published var dashboardPath = NavigationPath()
    @Published var transactionsPath = NavigationPath()
    @Published var budgetsPath = NavigationPath()
    @Published var invoicesPath = NavigationPath()
    @Published var morePath = NavigationPath()
    
    /// Pending navigation (set before view appears)
    @Published private(set) var pendingDestination: NavigationDestination?
    
    /// Sheet presentation states
    @Published var showingAddTransaction = false
    @Published var showingReceiptScanner = false
    @Published var showingCreateInvoice = false
    @Published var showingCreateBudget = false
    @Published var showingMoveMoney = false
    
    /// Pre-filled data for sheets
    @Published var addTransactionIsIncome = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        #if DEBUG
        print("🧭 NavigationService initialized")
        #endif
    }
    
    // MARK: - Tab Navigation
    
    /// Navigate to a specific tab
    func navigateTo(_ tab: AppTab, shouldClearPath: Bool = false) {
        // Skip if already on this tab
        guard selectedTab != tab || shouldClearPath else { return }
        
        HapticService.play(.selection)
        
        // Clear navigation path if requested
        if shouldClearPath {
            resetPath(for: tab)
        }
        
        selectedTab = tab
        
        #if DEBUG
        print("🧭 Navigated to tab: \(tab.title)")
        #endif
        
        // Analytics hook
        trackNavigation(to: tab)
    }
    
    /// Navigate to tab and then to a specific destination
    func navigateTo(_ tab: AppTab, destination: NavigationDestination) {
        navigateTo(tab, shouldClearPath: true)
        
        // Small delay to ensure tab switch completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.push(destination)
        }
    }
    
    // MARK: - Stack Navigation
    
    /// Push a destination onto the current tab's navigation stack
    func push(_ destination: NavigationDestination) {
        HapticService.play(.light)
        
        switch selectedTab {
        case .dashboard:
            dashboardPath.append(destination)
        case .transactions:
            transactionsPath.append(destination)
        case .budgets:
            budgetsPath.append(destination)
        case .invoices:
            invoicesPath.append(destination)
        case .more:
            morePath.append(destination)
        }
        
        #if DEBUG
        print("🧭 Pushed destination: \(destination)")
        #endif
    }
    
    /// Pop to root of current tab
    func popToRoot() {
        HapticService.play(.light)
        resetPath(for: selectedTab)
    }
    
    /// Clear navigation path for a specific tab
    private func resetPath(for tab: AppTab) {
        switch tab {
        case .dashboard:
            dashboardPath = NavigationPath()
        case .transactions:
            transactionsPath = NavigationPath()
        case .budgets:
            budgetsPath = NavigationPath()
        case .invoices:
            invoicesPath = NavigationPath()
        case .more:
            morePath = NavigationPath()
        }
    }
    
    /// Get the navigation path for the current tab
    func currentPath() -> Binding<NavigationPath> {
        switch selectedTab {
        case .dashboard:
            return Binding(get: { self.dashboardPath }, set: { self.dashboardPath = $0 })
        case .transactions:
            return Binding(get: { self.transactionsPath }, set: { self.transactionsPath = $0 })
        case .budgets:
            return Binding(get: { self.budgetsPath }, set: { self.budgetsPath = $0 })
        case .invoices:
            return Binding(get: { self.invoicesPath }, set: { self.invoicesPath = $0 })
        case .more:
            return Binding(get: { self.morePath }, set: { self.morePath = $0 })
        }
    }
    
    // MARK: - Entity-Specific Navigation
    
    /// Open a specific invoice
    func openInvoice(id: UUID) {
        navigateTo(.invoices, destination: .invoiceDetail(id: id))
        
        #if DEBUG
        print("🧭 Opening invoice: \(id)")
        #endif
    }
    
    /// Open a specific transaction
    func openTransaction(id: UUID) {
        navigateTo(.transactions, destination: .transactionDetail(id: id))
        
        #if DEBUG
        print("🧭 Opening transaction: \(id)")
        #endif
    }
    
    /// Open a specific budget
    func openBudget(id: UUID) {
        navigateTo(.budgets, destination: .budgetDetail(id: id))
        
        #if DEBUG
        print("🧭 Opening budget: \(id)")
        #endif
    }
    
    /// Open a specific client
    func openClient(id: UUID) {
        navigateTo(.invoices, destination: .clientDetail(id: id))
        
        #if DEBUG
        print("🧭 Opening client: \(id)")
        #endif
    }
    
    /// Open a specific mileage trip
    func openMileageTrip(id: UUID) {
        navigateTo(.more, destination: .mileageTripDetail(id: id))
        
        #if DEBUG
        print("🧭 Opening mileage trip: \(id)")
        #endif
    }
    
    // MARK: - Quick Actions
    
    /// Show add transaction sheet
    func showAddTransaction(isIncome: Bool = false) {
        addTransactionIsIncome = isIncome
        showingAddTransaction = true
        HapticService.play(.medium)
        
        #if DEBUG
        print("🧭 Showing add transaction (income: \(isIncome))")
        #endif
    }
    
    /// Show receipt scanner sheet
    func showReceiptScanner() {
        showingReceiptScanner = true
        HapticService.play(.medium)
        
        #if DEBUG
        print("🧭 Showing receipt scanner")
        #endif
    }
    
    /// Show create invoice sheet
    func showCreateInvoice() {
        showingCreateInvoice = true
        HapticService.play(.medium)
        
        #if DEBUG
        print("🧭 Showing create invoice")
        #endif
    }
    
    /// Show create budget sheet
    func showCreateBudget() {
        showingCreateBudget = true
        HapticService.play(.medium)
        
        #if DEBUG
        print("🧭 Showing create budget")
        #endif
    }
    
    /// Show move money sheet
    func showMoveMoney() {
        showingMoveMoney = true
        HapticService.play(.medium)
        
        #if DEBUG
        print("🧭 Showing Move Money")
        #endif
    }
    
    /// Navigate to mileage tracking
    func showMileageTracking() {
        navigateTo(.more, destination: .mileageTracking)
    }
    
    /// Navigate to settings
    func showSettings() {
        navigateTo(.more, destination: .settings)
    }
    
    /// Navigate to receipt storage
    func showReceiptStorage() {
        navigateTo(.more, destination: .receiptStorage)
    }
    
    // MARK: - Deep Link Handling
    
    /// Handle an incoming deep link URL
    /// - Returns: true if the URL was handled
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
        print("   Entity ID: \(String(describing: deepLink.entityId))")
        #endif
        
        // Navigate to tab
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
        // Extract navigation data from notification payload
        guard let type = userInfo["type"] as? String else { return }
        
        switch type {
        case "invoice_overdue":
            if let idString = userInfo["invoice_id"] as? String,
               let id = UUID(uuidString: idString) {
                openInvoice(id: id)
            }
            
        case "invoice_paid":
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
            navigateTo(.more, destination: .settings)
            
        case "mileage_trip_complete":
            if let idString = userInfo["trip_id"] as? String,
               let id = UUID(uuidString: idString) {
                openMileageTrip(id: id)
            }
            
        case "receipt_ready":
            navigateTo(.more, destination: .receiptMatchingQueue)
            
        default:
            navigateTo(.dashboard)
        }
        
        #if DEBUG
        print("🧭 Handled notification: \(type)")
        #endif
    }
    
    // MARK: - Analytics Hook
    
    private func trackNavigation(to tab: AppTab) {
        // TODO: Integrate with analytics service when added
        // Analytics.shared.track("tab_selected", properties: ["tab": tab.title])
    }
}

// MARK: - View Extension

extension View {
    /// Convenience for injecting NavigationService as environment object
    /// Use this at the app root level
    @MainActor
    func withNavigationService() -> some View {
        self.environmentObject(NavigationService.shared)
    }
}

// MARK: - Usage Examples

/*
 // === BASIC TAB NAVIGATION ===
 
 NavigationService.shared.navigateTo(.invoices)
 
 // === OPEN SPECIFIC ENTITY ===
 
 // From a notification or widget:
 NavigationService.shared.openInvoice(id: invoice.id)
 NavigationService.shared.openTransaction(id: transaction.id)
 
 // === QUICK ACTIONS ===
 
 NavigationService.shared.showAddTransaction(isIncome: false)
 NavigationService.shared.showReceiptScanner()
 NavigationService.shared.showCreateInvoice()
 
 // === DEEP LINKING ===
 
 // In your App's onOpenURL:
 .onOpenURL { url in
     NavigationService.shared.handleDeepLink(url)
 }
 
 // Supported URLs:
 // flo://dashboard
 // flo://transactions
 // flo://transactions/add?income=false
 // flo://transactions/detail?id=xxx
 // flo://invoices
 // flo://invoices/create
 // flo://invoices/detail?id=xxx
 // flo://budgets
 // flo://budgets/create
 // flo://more/mileage
 // flo://more/settings
 // flo://more/clients
 // flo://more/clients/detail?id=xxx
 // flo://more/accounts
 
 // === PUSH NOTIFICATION ===
 
 // In your notification handler:
 NavigationService.shared.handleNotification(userInfo: response.notification.request.content.userInfo)
 
 // Expected payload format:
 // {
 //   "type": "invoice_overdue",
 //   "invoice_id": "xxx-xxx-xxx"
 // }
 
 // === IN VIEWS ===
 
 struct MyView: View {
     @ObservedObject var navigation = NavigationService.shared
     // OR
     @EnvironmentObject var navigation: NavigationService
     
     var body: some View {
         Button("Go to Invoices") {
             navigation.navigateTo(.invoices)
         }
     }
 }
 
 // === INTEGRATE WITH CONTENTVIEW ===
 
 // Replace ContentView's local tab state with NavigationService:
 
 TabView(selection: $navigation.selectedTab) {
     DashboardView()
         .tag(AppTab.dashboard)
     // ...
 }
 */
