//  ContentListView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 2 content router. (v1.1: content-column min width now also
//  applies on Mac Catalyst, not just native macOS.)
//  Dispatches to the correct list/main view based on the selected tab.
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI

struct ContentListView: View {
    let tab: AppTab

    var body: some View {
        Group {
            switch tab {
            case .accounts:
                AccountsView()
            case .assistant:
                AssistantView()
            case .budgets:
                BudgetListView()
            case .clients:
                ClientListView()
            case .dashboard:
                DashboardView()
            case .debtAccelerator:
                DebtAcceleratorDashboardView()
            case .invoices:
                InvoiceListView()
            case .mileage:
                MileageTrackingMainView()
            case .receipts:
                ReceiptsListView()
            case .reports:
                ReportsView()
            case .settings:
                SettingsView()
            case .tax:
                TaxSettingsView()
            case .transactions:
                TransactionListView()
            }
        }
        .navigationTitle(tab.title)
        #if os(macOS) || targetEnvironment(macCatalyst)
        .frame(minWidth: 340)
        #endif
    }
}

#if DEBUG
#Preview("Content - Dashboard") {
    NavigationStack {
        ContentListView(tab: .dashboard)
    }
}
#endif
