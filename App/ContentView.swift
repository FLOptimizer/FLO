//  ContentView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 5.0 - Build 10 Adaptive Navigation
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v5.0 (Build 10):
//  ✅ REWRITE: Adaptive layout — portrait TabView / landscape+macOS NavigationSplitView
//  ✅ ADDED: Three-zone navigation (Sidebar → Content → Detail)
//  ✅ ADDED: 11 first-class tabs replacing 5+More structure
//  ✅ ADDED: iPhone landscape sidebar with emoji icons
//  ✅ ADDED: macOS NavigationSplitView with full text sidebar
//  ✅ PRESERVED: Lock screen, deep links, Spotlight, scene phase, sheets, accessibility
//
//  Previous: v4.0 — Spotlight deep link handling

import SwiftUI
import FLODesignSystem
import SwiftData
import CoreSpotlight

@MainActor
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authService: BiometricAuthService
    @ObservedObject private var navigation = NavigationService.shared

    // Layout detection
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Build 10 Step 11: iPad sidebar persistence — keep sidebar visible on wide screens
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    // Navigation path for content column — reset on tab change to clear Zone 3
    @State private var contentPath = NavigationPath()

    // Theme picker support
    @AppStorage("preferredColorScheme") private var preferredColorScheme = "system"

    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// Use landscape/split layout on macOS or when horizontalSizeClass is regular (iPad/landscape iPhone)
    private var useSplitLayout: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    #if !os(macOS)
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    #endif

    // MARK: - Body

    var body: some View {
        ZStack {
            if !authService.isAuthenticated && authService.isSecurityEnabled {
                LockView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("App locked")
                    .accessibilityAddTraits(.isModal)
            } else {
                if useSplitLayout {
                    landscapeLayout
                        .transition(.opacity)
                } else {
                    portraitTabView
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
        }
        .animation(FLOAnimation.standard, value: authService.isAuthenticated)
        .onChange(of: scenePhase) { _, newValue in
            handleScenePhaseChange(newValue)
        }
        .onChange(of: navigation.selectedTab) { oldValue, newValue in
            guard oldValue != newValue else { return }
            // Defer to next run loop to avoid "Publishing changes from within view updates"
            // when NavigationSplitView triggers content column re-layout during selection change
            DispatchQueue.main.async {
                #if DEBUG
                print("[Tab] Changed: \(oldValue.title) -> \(newValue.title)")
                #endif

                // Clear Zone 3 detail so it returns to the contextual summary panel
                navigation.selectedDetail = nil
                contentPath = NavigationPath()

                AccessibilityAnnouncement.screenChanged(newValue.title)
            }
        }
        .preferredColorScheme(colorScheme)
        .onOpenURL { url in
            handleDeepLink(url)
        }
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
    }

    // MARK: - Portrait Tab View (iPhone Portrait)

    private var portraitTabView: some View {
        TabView(selection: $navigation.selectedTab) {
            ForEach(AppTab.portraitTabs) { tab in
                ContentListView(tab: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
                    .accessibilityLabel(tab.title)
            }
        }
        .tint(Color.brandPrimary)
    }

    // MARK: - Landscape / macOS Layout (Three-Zone NavigationSplitView)

    private var landscapeLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $navigation.selectedTab)
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } content: {
            NavigationStack(path: $contentPath) {
                ContentListView(tab: navigation.selectedTab)
            }
            .id(navigation.selectedTab)
            .navigationSplitViewColumnWidth(ideal: 480)
            .floColumnBackground()
        } detail: {
            DetailView(destination: navigation.selectedDetail, selectedTab: navigation.selectedTab)
                .navigationSplitViewColumnWidth(ideal: 360)
                .floColumnBackground()
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 1)
                        .ignoresSafeArea()
                }
        }
        .tint(Color.brandPrimary)
        #if os(macOS)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    navigation.showAddTransaction()
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle")
                }
                .help("Add a new transaction (Cmd+N)")

                Button {
                    navigation.showReceiptScanner()
                } label: {
                    Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                }
                .help("Scan a receipt")

                Button {
                    navigation.showCreateInvoice()
                } label: {
                    Label("New Invoice", systemImage: "doc.text.fill")
                }
                .help("Create a new invoice")
            }
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }

    // MARK: - Deep Link Handler

    private func handleDeepLink(_ url: URL) {
        #if DEBUG
        print("[DeepLink] Received: \(url)")
        #endif

        guard authService.isAuthenticated || !authService.isSecurityEnabled else {
            #if DEBUG
            print("[DeepLink] Deferred - app locked")
            #endif
            return
        }

        navigation.handleDeepLink(url)
    }

    // MARK: - Spotlight Handler

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
            if authService.isSecurityEnabled {
                authService.logout()
                #if DEBUG
                print("[Security] App locked (went to background)")
                #endif
            }
        case .active:
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
