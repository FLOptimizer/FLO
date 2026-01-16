//  ContentView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 3.3.1 - Fixed scope issues with private members
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  TAB ORDER:
//  1. Dashboard (overview)
//  2. Transactions (most frequent action)
//  3. Budgets (includes Recurring as sub-tab)
//  4. Invoices (weekly check)
//  5. More (Clients, Mileage, Settings)
//
//  CHANGES v3.3.1:
//  ✅ FIXED: Moved private members outside of body (scope error)
//  ✅ FIXED: ZStack brace placement
//
//  CHANGES v3.3:
//  ✅ Haptic feedback on tab switches (selection feedback)
//  ✅ Smooth spring animation for unlock transition
//  ✅ Tab selection state tracking
//  ✅ Prepared haptics on appear for responsiveness

import SwiftUI
import SwiftData

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authService: BiometricAuthService
    @ObservedObject private var passcodeService = PasscodeService.shared
    
    // Theme picker support
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"
    
    // Tab selection for haptic feedback
    @State private var selectedTab: Tab = .dashboard
    
    // Haptic generator
    private let selectionFeedback = UISelectionFeedbackGenerator()
    
    // Tab enum for type safety
    enum Tab: Int, CaseIterable {
        case dashboard = 0
        case transactions = 1
        case budgets = 2
        case invoices = 3
        case more = 4
        
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
    }
    
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
            if !authService.isAuthenticated && (authService.biometricEnabled || PasscodeService.shared.isPasscodeEnabled) {
                LockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                mainTabView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authService.isAuthenticated)
        .onChange(of: scenePhase) { oldValue, newValue in
            handleScenePhaseChange(newValue)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback on tab change
            selectionFeedback.selectionChanged()
        }
        .onAppear {
            // Prepare haptics for responsiveness
            selectionFeedback.prepare()
        }
        .preferredColorScheme(colorScheme)
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard - Daily overview
            DashboardView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)
            
            // Tab 2: Transactions - Most frequent action (center position)
            TransactionListView()
                .tabItem {
                    Label(Tab.transactions.title, systemImage: Tab.transactions.icon)
                }
                .tag(Tab.transactions)
            
            // Tab 3: Budgets - Includes Recurring as sub-tab
            BudgetListView()
                .tabItem {
                    Label(Tab.budgets.title, systemImage: Tab.budgets.icon)
                }
                .tag(Tab.budgets)
            
            // Tab 4: Invoices - Weekly check
            InvoiceListView()
                .tabItem {
                    Label(Tab.invoices.title, systemImage: Tab.invoices.icon)
                }
                .tag(Tab.invoices)
            
            // Tab 5: More - Everything else (Clients, Mileage, Settings)
            MoreView()
                .tabItem {
                    Label(Tab.more.title, systemImage: Tab.more.icon)
                }
                .tag(Tab.more)
        }
        .tint(Color.brandPrimary)
    }
    
    // MARK: - Scene Phase Handler
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock the app when going to background (if security is enabled)
            if authService.isSecurityEnabled {
                authService.logout()
                #if DEBUG
                print("🔒 App locked (went to background)")
                #endif
            }
        case .active:
            // Refresh biometric status when becoming active
            authService.refreshBiometricStatus()
            // Prepare haptics when app becomes active
            selectionFeedback.prepare()
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
