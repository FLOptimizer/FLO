//  SidebarView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 1 sidebar for landscape iPhone, iPad, and macOS.
//  Grouped sections: Dashboard (home) | Money | Clients | Business | Settings
//  Step 12: Decoupled List selection to fix "Publishing changes from within view updates"
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppTab

    // Intermediate state decouples List selection from @Published binding.
    @State private var listSelection: AppTab?

    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var useSymbolIcons: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    // MARK: - Grouped Tab Sections

    /// Dashboard stands alone at the top — it's the home screen
    private static let homeSection: [AppTab] = [.dashboard]

    /// AI assistant
    private static let assistantSection: [AppTab] = [.assistant]

    /// Core money management
    private static let moneySection: [AppTab] = [.accounts, .budgets, .receipts, .transactions]

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

            // Money
            Section("Money") {
                ForEach(Self.moneySection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Clients & Invoicing
            Section("Clients") {
                ForEach(Self.clientsSection) { tab in
                    sidebarRow(for: tab).tag(tab)
                }
            }

            // Business Tools
            Section("Business") {
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
        .navigationTitle("FLO")
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
        #if os(macOS)
        .frame(minWidth: 200)
        #endif
    }

    // MARK: - Row

    private func sidebarRow(for tab: AppTab) -> some View {
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
