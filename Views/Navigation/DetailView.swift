//  DetailView.swift
//  FLO - Finance Ledger Optimizer
//
//  Build 10 — Zone 3 detail router.
//  Dispatches to the correct detail view based on NavigationDestination.
//  For UUID-based destinations, queries the model from SwiftData.
//  Shows a placeholder when no detail is selected (macOS/landscape).
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.

import SwiftUI
import SwiftData

struct DetailView: View {
    let destination: NavigationDestination?
    var selectedTab: AppTab = .dashboard

    var body: some View {
        if let destination {
            destinationView(for: destination)
        } else {
            summaryView(for: selectedTab)
        }
    }

    // MARK: - Contextual Summary Router

    @ViewBuilder
    private func summaryView(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DashboardSummaryPanel()
        case .transactions:
            TransactionSummaryPanel()
        case .budgets:
            BudgetSummaryPanel()
        case .invoices:
            InvoiceSummaryPanel()
        case .accounts:
            AccountSummaryPanel()
        case .assistant:
            AssistantDataPanel(context: NavigationService.shared.assistantContext)
        case .tax:
            TaxSummaryPanel()
        case .settings:
            SettingsSummaryPanel()
        default:
            GenericSummaryPanel(tab: tab)
        }
    }

    // MARK: - Destination Router

    @ViewBuilder
    private func destinationView(for dest: NavigationDestination) -> some View {
        switch dest {
        case .dashboard:
            DashboardView()

        // Transactions
        case .transactionList:
            TransactionListView()
        case .transactionDetail(let id):
            TransactionLookupView(id: id)
        case .addTransaction:
            AddTransactionView()

        // Budgets
        case .budgetList:
            BudgetListView()
        case .budgetDetail(let id):
            BudgetLookupView(id: id)
        case .createBudget:
            CreateBudgetView(month: Date())
        case .recurringList:
            RecurringListView()

        // Invoices
        case .invoiceList:
            InvoiceListView()
        case .invoiceDetail(let id):
            InvoiceLookupView(id: id)
        case .createInvoice:
            CreateInvoiceView()

        // Clients
        case .clientList:
            ClientListView()
        case .clientDetail(let id):
            ClientLookupView(id: id)

        // Mileage
        case .mileageTracking:
            MileageTrackingMainView()
        case .mileageTripDetail(let id):
            MileageTripLookupView(id: id)

        // Accounts
        case .accounts:
            AccountsView()
        case .accountDetail(let id):
            AccountLookupView(id: id)

        // Receipts
        case .receiptScanner, .receiptStorage, .receiptMatchingQueue:
            SmartReceiptScanningView()

        // Reports
        case .reports, .yearEndChecklist:
            ReportsView()

        // Settings
        case .settings, .categories, .subscription:
            SettingsView()
        case .settingsAppearance:
            AppearanceSettingsView()
        case .settingsNotifications:
            NotificationSettingsView()
        case .settingsSecurity:
            SecuritySettingsView()
        case .settingsDataStorage:
            DataManagementView()
        case .settingsBusinessProfile:
            BusinessProfileSettingsView()
        case .settingsEditProfile:
            AccountDetailsWrapper()
        case .settingsAbout:
            AboutView()
        case .settingsSubscription:
            SubscriptionView()
        case .settingsCategories:
            CategoryManagementView()
        case .settingsBackup:
            BackupSettingsView()
        case .settingsReceiptStorage:
            ReceiptStorageSettingsView()
        case .settingsEULA:
            EULAView()
        case .settingsHelpCenter:
            HelpCenterView()
        case .settingsPrivacyPolicy:
            PrivacyPolicyView()
        case .settingsTaxDisclaimer:
            TaxDisclaimerView()
        case .settingsTermsOfService:
            TermsOfServiceView()

        // Tax
        case .taxOverview, .taxDeductions:
            TaxSettingsView()
        }
    }

    // MARK: - Empty State

    // Build 10 Step 11: Enhanced empty state for iPad/macOS detail panel
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sidebar.squares.leading")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.quaternary)

            VStack(spacing: 6) {
                Text("Select an item")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("Choose a transaction, budget, or other item from the list to view details here.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No item selected. Choose an item from the list.")
    }
}

// MARK: - Account Details Wrapper
// Bridges @AppStorage to @Binding for AccountDetailsView routing from DetailView.

private struct AccountDetailsWrapper: View {
    @AppStorage("userName") private var userName = ""
    @AppStorage("userEmail") private var userEmail = ""
    @State private var showingSignOutAlert = false

    var body: some View {
        AccountDetailsView(
            userName: $userName,
            userEmail: $userEmail,
            showingSignOutAlert: $showingSignOutAlert
        )
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                AppleAuthService.shared.signOut()
                HapticService.play(.medium)
            }
        } message: {
            Text("Your data will remain on this device. You can sign in again anytime.")
        }
    }
}

// MARK: - SwiftData Lookup Views
// These query a model by UUID and present the appropriate detail view.

private struct TransactionLookupView: View {
    let id: UUID
    @Query private var results: [Transaction]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Transaction> { $0.id == id })
    }

    var body: some View {
        if let transaction = results.first {
            EditTransactionView(transaction: transaction)
        } else {
            DetailNotFoundView(type: "Transaction")
        }
    }
}

private struct BudgetLookupView: View {
    let id: UUID
    @Query private var results: [Budget]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Budget> { $0.id == id })
    }

    var body: some View {
        if let budget = results.first {
            EditBudgetView(budget: budget)
        } else {
            DetailNotFoundView(type: "Budget")
        }
    }
}

private struct InvoiceLookupView: View {
    let id: UUID
    @Query private var results: [Invoice]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Invoice> { $0.id == id })
    }

    var body: some View {
        if let invoice = results.first {
            InvoiceDetailView(invoice: invoice)
        } else {
            DetailNotFoundView(type: "Invoice")
        }
    }
}

private struct ClientLookupView: View {
    let id: UUID
    @Query private var results: [Client]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Client> { $0.id == id })
    }

    var body: some View {
        if let client = results.first {
            ClientDetailView(client: client)
        } else {
            DetailNotFoundView(type: "Client")
        }
    }
}

private struct MileageTripLookupView: View {
    let id: UUID
    @Query private var results: [MileageTrip]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<MileageTrip> { $0.id == id })
    }

    var body: some View {
        if let trip = results.first {
            MileageTripDetailView(trip: trip)
        } else {
            DetailNotFoundView(type: "Mileage Trip")
        }
    }
}

private struct AccountLookupView: View {
    let id: UUID
    @Query private var results: [Account]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Account> { $0.id == id })
    }

    var body: some View {
        if let account = results.first {
            EditAccountView(account: account)
        } else {
            DetailNotFoundView(type: "Account")
        }
    }
}

private struct DetailNotFoundView: View {
    let type: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.orange)

            Text("\(type) not found")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if DEBUG
#Preview("Detail - Dashboard Summary") {
    DetailView(destination: nil, selectedTab: .dashboard)
        .modelContainer(for: [Transaction.self, Budget.self, Invoice.self, Account.self])
}
#Preview("Detail - Empty") {
    DetailView(destination: nil, selectedTab: .settings)
}
#endif
