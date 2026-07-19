//  SidebarView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 1 sidebar for landscape iPhone, iPad, and macOS.
//  Grouped sections: Dashboard (home) | Money | Clients | Business | Settings
//  Step 12: Decoupled List selection to fix "Publishing changes from within view updates"
//  Step 13 (v3.0 launch): Added iconOnly mode for 50pt landscape-iPhone strip.
//  Step 14 (Build 10): sidebar min width now also applies on Mac Catalyst.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppTab

    /// When true, renders a compact 50pt-wide icon-only column. Used on landscape iPhone.
    var iconOnly: Bool = false

    // Intermediate state decouples List selection from @Published binding.
    @State private var listSelection: AppTab?

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var useSymbolIcons: Bool {
        #if os(macOS)
        return true
        #else
        // Always use SF Symbols when in icon-only strip (emoji wouldn't read well at 50pt).
        if iconOnly { return true }
        return horizontalSizeClass == .regular
        #endif
    }

    // MARK: - Grouped Tab Sections

    /// Dashboard stands alone at the top — it's the home screen
    private static let homeSection: [AppTab] = [.dashboard]

    /// AI assistant
    private static let assistantSection: [AppTab] = [.assistant]

    /// Core money management
    private static let moneySection: [AppTab] = [.accounts, .budgets, .debtAccelerator, .receipts, .transactions]

    /// Client & invoicing
    private static let clientsSection: [AppTab] = [.clients, .invoices]

    /// Business tools
    private static let businessSection: [AppTab] = [.mileage, .reports, .tax]

    /// App settings
    private static let settingsSection: [AppTab] = [.settings]

    var body: some View {
        List(selection: $listSelection) {
            // Dashboard — separated at top
            Section {
                ForEach(Self.homeSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // My Assistant
            Section {
                ForEach(Self.assistantSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Money — hide header in icon-only mode (no room at 50pt)
            Section(iconOnly ? "" : "Money") {
                ForEach(Self.moneySection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Clients & Invoicing
            Section(iconOnly ? "" : "Clients") {
                ForEach(Self.clientsSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Business Tools
            Section(iconOnly ? "" : "Business") {
                ForEach(Self.businessSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Settings
            Section {
                ForEach(Self.settingsSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(iconOnly ? "" : "FLO")
        .onAppear {
            listSelection = selection
        }
        .onChange(of: listSelection) { _, newValue in
            guard let newValue, newValue != selection else { return }
            DispatchQueue.main.async {
                selection = newValue
            }
        }
        .onChange(of: selection) { _, newValue in
            if listSelection != newValue {
                listSelection = newValue
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: 200)
        #endif
    }

    // MARK: - Row

    @ViewBuilder
    private func sidebarRow(for tab: AppTab) -> some View {
        if iconOnly {
            // Icon-only row for 50pt landscape-iPhone strip
            Image(systemName: tab.icon)
                .font(.system(size: 20, weight: .regular))
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
                .accessibilityLabel(tab.title)
                .help(tab.title)
        } else {
            Label {
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            } icon: {
                if useSymbolIcons {
                    Image(systemName: tab.icon)
                } else {
                    Text(tab.emoji)
                }
            }
            .accessibilityLabel(tab.title)
        }
    }
}

#if DEBUG
#Preview("Sidebar") {
    NavigationSplitView {
        SidebarView(selection: .constant(.dashboard))
    } content: {
        Text("Content")
    } detail: {
        Text("Detail")
    }
}
#endif
