//  MoreTabView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 — Receipts opens the receipt list; Cash Flow Forecast &
//                Household Sharing surfaced as top-level, portrait-safe Tools
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.2:
//  ✅ ADDED: Recurring Transactions to the Tools section (moved off Settings → Tools
//           as part of the IA cleanup — Settings is for config, not feature access).
//
//  CHANGES v1.1:
//  ✅ FIXED: Receipts row now pushes ReceiptListView (list of saved receipts, with a
//           nav-bar scan button) instead of dropping straight into the scanner.
//  ✅ ADDED: "Tools" section with Cash Flow Forecast & Household Sharing — presented
//           as sheets because both views own their navigation context. Sheets are
//           layout-agnostic and work in portrait, unlike the Settings → Tools
//           selectedDetail routing which silently fails on portrait iPhone.
//

import SwiftUI

struct MoreTabView: View {
    @ObservedObject private var navigation = NavigationService.shared

    @State private var showingCashFlowForecast = false
    @State private var showingHouseholdSharing = false
    @State private var showingRecurring = false

    var body: some View {
        NavigationStack {
            List {
                Section("Features") {
                    NavigationLink {
                        AccountsView()
                            .navigationTitle(AppTab.accounts.title)
                    } label: {
                        Label("Accounts", systemImage: "building.columns")
                    }

                    NavigationLink {
                        DebtAcceleratorDashboardView()
                            .navigationTitle(AppTab.debtAccelerator.title)
                    } label: {
                        Label("Debt Accelerator", systemImage: "chart.line.downtrend.xyaxis")
                    }

                    NavigationLink {
                        MileageTrackingMainView()
                            .navigationTitle(AppTab.mileage.title)
                    } label: {
                        Label("Mileage", systemImage: "car.fill")
                    }

                    NavigationLink {
                        ReceiptListView(embedInOwnStack: false, showScanButton: true)
                    } label: {
                        Label("Receipts", systemImage: "doc.text.viewfinder")
                    }

                    NavigationLink {
                        ReportsView()
                            .navigationTitle(AppTab.reports.title)
                    } label: {
                        Label("Reports", systemImage: "chart.bar.doc.horizontal")
                    }

                    NavigationLink {
                        EventsListView()
                    } label: {
                        Label("Events", systemImage: "airplane")
                    }

                    NavigationLink {
                        TaxSettingsView()
                            .navigationTitle(AppTab.tax.title)
                    } label: {
                        Label("Tax", systemImage: "building.columns.fill")
                    }

                    NavigationLink {
                        AssistantView()
                            .navigationTitle(AppTab.assistant.title)
                    } label: {
                        Label("My Assistant", systemImage: "bubble.left.and.text.bubble.right")
                    }

                    NavigationLink {
                        ClientListView()
                            .navigationTitle(AppTab.clients.title)
                    } label: {
                        Label("Clients", systemImage: "person.2.fill")
                    }
                }

                Section("Tools") {
                    moreToolButton(
                        title: "Cash Flow Forecast",
                        systemImage: "chart.line.uptrend.xyaxis.circle"
                    ) {
                        showingCashFlowForecast = true
                    }

                    moreToolButton(
                        title: "Household Sharing",
                        systemImage: "person.2.circle.fill"
                    ) {
                        showingHouseholdSharing = true
                    }

                    moreToolButton(
                        title: "Recurring Transactions",
                        systemImage: "arrow.triangle.2.circlepath"
                    ) {
                        showingRecurring = true
                    }
                }

                Section("App") {
                    NavigationLink {
                        SettingsView()
                            .navigationTitle(AppTab.settings.title)
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("More")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .sheet(isPresented: $showingCashFlowForecast) {
                CashFlowForecastView()
            }
            .sheet(isPresented: $showingHouseholdSharing) {
                NavigationStack {
                    HouseholdSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showingHouseholdSharing = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingRecurring) {
                RecurringListView()
            }
        }
    }

    /// Full-width tappable row that presents a self-contained feature as a sheet.
    /// Used instead of NavigationLink for views that bring their own navigation
    /// context (so they can't be pushed without doubling the nav bar) and to stay
    /// portrait-safe.
    @ViewBuilder
    private func moreToolButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticService.play(.light)
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    MoreTabView()
}
#endif
