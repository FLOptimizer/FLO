//  ContentView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 4.0 - Spotlight deep link handling for CoreSpotlight search results
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TAB ORDER:
//  1. Dashboard (overview)
//  2. Transactions (most frequent action)
//  3. Budgets (includes Recurring as sub-tab)
//  4. Invoices (weekly check)
//  5. More (Clients, Mileage, Settings)
//
//  CHANGES v3.9:
//  ✅ ADDED: VoiceOver accessibility labels on all tab items
//  ✅ ADDED: Accessibility hints for tab navigation
//  ✅ ADDED: Screen change announcements on tab switch
//  ✅ ADDED: Lock screen accessibility announcement
//  ✅ ADDED: VoiceOver notification when sheets present/dismiss
//
//  PREVIOUS (v3.8):
//  - Removed duplicate onboarding presentation
//

import SwiftUI
import SwiftData
import CoreSpotlight

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authService: BiometricAuthService
    @ObservedObject private var navigation = NavigationService.shared
    
    // Theme picker support
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    
    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil  // system
        }
    }
    
    init() {
        // Configure tab bar appearance to be opaque (not see-through)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // FIXED v3.6: Use authService.isSecurityEnabled for consistency
            // This matches the check used in handleScenePhaseChange for locking
            if !authService.isAuthenticated && authService.isSecurityEnabled {
                LockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    // v3.9: Announce lock screen to VoiceOver
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("App locked")
                    .accessibilityAddTraits(.isModal)
            } else {
                mainTabView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(FLOAnimation.standard, value: authService.isAuthenticated)
        .onChange(of: scenePhase) { oldValue, newValue in
            handleScenePhaseChange(newValue)
        }
        .onChange(of: navigation.selectedTab) { oldValue, newValue in
            // Haptic feedback handled by NavigationService
            #if DEBUG
            if oldValue != newValue {
                print("[Tab] Changed: \(oldValue.title) -> \(newValue.title)")
            }
            #endif
            
            // v3.9: Announce tab change to VoiceOver users
            AccessibilityAnnouncement.screenChanged(newValue.title)
        }
        .preferredColorScheme(colorScheme)
        // Deep link handling
        .onOpenURL { url in
            handleDeepLink(url)
        }
        // Spotlight search result handling
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightActivity(activity)
        }
        // Quick action sheets
        .sheet(isPresented: $navigation.showingAddTransaction) {
            AddTransactionView()
        }
        .sheet(isPresented: $navigation.showingReceiptScanner) {
            SmartReceiptScanningView()
        }
        .sheet(isPresented: $navigation.showingCreateInvoice) {
            CreateInvoiceView()
        }
        .sheet(isPresented: $navigation.showingCreateBudget) {
            CreateBudgetView(month: Date())
        }
        // NOTE: Onboarding is handled in FLOApp.swift, NOT here
        // This prevents the "only presenting a single sheet" error
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $navigation.selectedTab) {
            // Tab 1: Dashboard - Daily overview
            DashboardView()
                .tabItem {
                    Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.icon)
                }
                .tag(AppTab.dashboard)
                // v3.9: VoiceOver label for dashboard tab
                .accessibilityLabel("Dashboard")
                .accessibilityHint("View your financial overview, balances, and quick actions")
            
            // Tab 2: Transactions - Most frequent action (center position)
            TransactionListView()
                .tabItem {
                    Label(AppTab.transactions.title, systemImage: AppTab.transactions.icon)
                }
                .tag(AppTab.transactions)
                // v3.9: VoiceOver label for transactions tab
                .accessibilityLabel("Transactions")
                .accessibilityHint("View and manage your income and expenses")
            
            // Tab 3: Budgets - Includes Recurring as sub-tab
            BudgetListView()
                .tabItem {
                    Label(AppTab.budgets.title, systemImage: AppTab.budgets.icon)
                }
                .tag(AppTab.budgets)
                // v3.9: VoiceOver label for budgets tab
                .accessibilityLabel("Budgets")
                .accessibilityHint("Manage your budgets and recurring transactions")
            
            // Tab 4: Invoices - Weekly check
            InvoiceListView()
                .tabItem {
                    Label(AppTab.invoices.title, systemImage: AppTab.invoices.icon)
                }
                .tag(AppTab.invoices)
                // v3.9: VoiceOver label for invoices tab
                .accessibilityLabel("Invoices")
                .accessibilityHint("Create and track invoices for your clients")
            
            // Tab 5: More - Everything else (Clients, Mileage, Settings)
            MoreView()
                .tabItem {
                    Label(AppTab.more.title, systemImage: AppTab.more.icon)
                }
                .tag(AppTab.more)
                // v3.9: VoiceOver label for more tab
                .accessibilityLabel("More")
                .accessibilityHint("Access clients, mileage tracking, reports, and settings")
        }
        .tint(Color.brandPrimary)
    }
    
    // MARK: - Deep Link Handler
    
    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("[DeepLink] Received: \(url)")
        #endif
        
        // Only handle if authenticated or no security enabled
        guard authService.isAuthenticated || !authService.isSecurityEnabled else {
            #if DEBUG
            print("[DeepLink] Deferred - app locked")
            #endif
            // Could store pending deep link to handle after auth
            return
        }
        
        navigation.handleDeepLink(url)
    }
    
    // MARK: - Spotlight Handler
    
    /// Handle tap on a Spotlight search result.
    /// Resolves the CSSearchableItem identifier to a deep link URL
    /// and navigates to the corresponding detail view.
    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            #if DEBUG
            print("[Spotlight] No identifier in activity")
            #endif
            return
        }
        
        #if DEBUG
        print("[Spotlight] Tapped result: \(identifier)")
        #endif
        
        guard let url = SpotlightIndexingService.shared.deepLinkURL(for: identifier) else {
            #if DEBUG
            print("[Spotlight] Could not resolve deep link for: \(identifier)")
            #endif
            return
        }
        
        handleDeepLink(url)
    }
    
    // MARK: - Scene Phase Handler
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background (if security is enabled)
            if authService.isSecurityEnabled {
                authService.logout()
                #if DEBUG
                print("[Security] App locked (went to background)")
                #endif
            }
        case .active:
            // Refresh biometric status when becoming active
            authService.refreshBiometricStatus()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(BiometricAuthService.shared)
        .modelContainer(for: [Transaction.self, Budget.self, Invoice.self, Client.self])
}
