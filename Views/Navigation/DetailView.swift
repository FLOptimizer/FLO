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
import FLODesignSystem

struct DetailView: View {
    let destination: NavigationDestination?
    var selectedTab: AppTab = .dashboard

    // v3.14: Observe the navigation service so the unsaved-changes confirmation
    // dialog re-renders when an editor requests navigation while dirty.
    @ObservedObject private var navigationService = NavigationService.shared

    var body: some View {
        Group {
            if let destination {
                destinationView(for: destination)
            } else {
                summaryView(for: selectedTab)
            }
        }
        // v3.14: Unsaved-changes guard. When an editor in Zone 3 (e.g.
        // EditAccountView) has `isDirty == true` and the sidebar requests a
        // navigation via `requestDetailNavigation`, the service stores the
        // target in `pendingUnsavedNavigation` instead of applying it. This
        // dialog then surfaces — user picks Discard (apply pending) or Keep
        // Editing (drop pending, stay put). Prevents silent loss of in-flight
        // edits when the user clicks another entity in the sidebar.
        .confirmationDialog(
            "Discard changes?",
            isPresented: Binding(
                get: { navigationService.pendingUnsavedNavigation != nil },
                set: { if !$0 { navigationService.cancelPendingUnsavedNavigation() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                navigationService.discardUnsavedAndNavigate()
            }
            Button("Keep Editing", role: .cancel) {
                navigationService.cancelPendingUnsavedNavigation()
            }
        } message: {
            Text("Your edits haven't been saved. If you leave now they'll be lost.")
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
        case .debtAccelerator:
            DebtSummaryPanel()
        case .mileage:
            MileageSummaryPanel()
        case .reports:
            ReportsSummaryPanel()
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
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            withAnimation(FLOAnimation.quick) {
                                NavigationService.shared.selectedDetail = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.caption.weight(.semibold))
                                Text("Back")
                            }
                            .foregroundStyle(Color.brandPrimary)
                        }
                    }
                }
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

        // Debt Accelerator
        case .debtAcceleratorDashboard:
            DebtAcceleratorDashboardView()
        case .debtAcceleratorDetail(let id):
            DebtPlanLookupView(id: id)
        case .createDebtPlan:
            CreateDebtPlanView()

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
        case .addAccount:
            AddAccountView(
                embedInNavigationStack: false,
                onCancel: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = nil
                    }
                },
                onSaved: { _ in
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = nil
                    }
                }
            )
        case .addLinkedCard(let accountId):
            AddLinkedCardLookupView(accountId: accountId)
        case .reconcileAccount(let accountId):
            ReconcileAccountLookupView(accountId: accountId)

        // Invoice sub-layers
        case .editInvoice(let id):
            EditInvoiceLookupView(id: id)
        case .markInvoiceSent(let id):
            MarkInvoiceSentLookupView(id: id)
        case .markInvoicePaid(let id):
            MarkInvoicePaidLookupView(id: id)

        // Client sub-layers
        case .editClient(let id):
            EditClientLookupView(id: id)

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
            BusinessListView()
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
        case .taxBusinessSummary:
            BusinessTaxSummaryView()
        case .taxDepreciationSchedule:
            DepreciationScheduleView()
        case .taxCarryforwardRegister:
            CarryforwardRegisterView()
        case .taxFilingChecklist:
            FilingChecklistView()
        case .taxYearEndClosing:
            YearEndClosingView()
        case .taxCPAExport:
            TaxExportView()
        case .taxJurisdictions:
            JurisdictionManagementView()

        // Tax — Phase 3
        case .taxBasisAlerts:
            BasisAlertsDashboardView()
        case .taxEstimatedPayments:
            EstimatedTaxDashboardView()
        case .taxNAICSCodes:
            NAICSCodeSuggestionView()
        case .taxMultiYearComparison:
            MultiYearComparisonView()

        // Tax — Phase 4
        case .taxPreparerChecklist:
            PreparerChecklistView()

        // Settings — Tools (v6.5)
        case .debtCalculator:
            DebtPayoffCalculatorView()
        case .cashFlowForecast:
            CashFlowForecastView()
        // .recurringList already handled in Budgets section above
        case .invoiceSettings:
            InvoiceSettingsView()
        case .csvImport:
            CSVFilePickerView()
        case .householdSettings:
            HouseholdSettingsView()
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
                .id(transaction.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
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
                .id(budget.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
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
                .id(invoice.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
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
                .id(client.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
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
                .id(trip.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Mileage Trip")
        }
    }
}

private struct DebtPlanLookupView: View {
    let id: UUID
    @Query private var results: [DebtAcceleratorPlan]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<DebtAcceleratorPlan> { $0.id == id })
    }

    var body: some View {
        if let plan = results.first {
            DebtAcceleratorDetailView(plan: plan)
                .id(plan.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            // No matching plan (e.g. plan deleted) — fall back to the overview.
            DebtAcceleratorDashboardView()
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
            EditAccountView(
                account: account,
                embedInNavigationStack: false,
                onCancel: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = nil
                    }
                },
                onSaved: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = nil
                    }
                }
            )
            // Critical: re-key on account.id so SwiftUI treats each selected
            // account as a new view identity. EditAccountView initializes its
            // @State from `account` exactly once; without this modifier, SwiftUI
            // reuses the view instance when the user switches accounts in the
            // sidebar and the stale @State gets written to the NEW account on
            // Save — silently renaming it. (Zone 2 → Zone 3 state-corruption bug.)
            .id(account.id)
        } else {
            DetailNotFoundView(type: "Account")
        }
    }
}

private struct AddLinkedCardLookupView: View {
    let accountId: UUID
    @Query private var results: [Account]

    init(accountId: UUID) {
        self.accountId = accountId
        _results = Query(filter: #Predicate<Account> { $0.id == accountId })
    }

    var body: some View {
        if let account = results.first {
            AddLinkedCardSheet(
                account: account,
                embedInNavigationStack: false,
                onCancel: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .accountDetail(id: accountId)
                    }
                }
            )
            .id(account.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Account")
        }
    }
}

private struct ReconcileAccountLookupView: View {
    let accountId: UUID
    @Query private var results: [Account]

    init(accountId: UUID) {
        self.accountId = accountId
        _results = Query(filter: #Predicate<Account> { $0.id == accountId })
    }

    var body: some View {
        if let account = results.first {
            ReconcileAccountView(
                account: account,
                embedInNavigationStack: false,
                onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .accountDetail(id: accountId)
                    }
                }
            )
            .id(account.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Account")
        }
    }
}

private struct EditInvoiceLookupView: View {
    let id: UUID
    @Query private var results: [Invoice]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Invoice> { $0.id == id })
    }

    var body: some View {
        if let invoice = results.first {
            EnhancedEditInvoiceView(
                invoice: invoice,
                embedInNavigationStack: false,
                onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .invoiceDetail(id: id)
                    }
                }
            )
            .id(invoice.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Invoice")
        }
    }
}

private struct MarkInvoiceSentLookupView: View {
    let id: UUID
    @Query private var results: [Invoice]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Invoice> { $0.id == id })
    }

    var body: some View {
        if let invoice = results.first {
            MarkAsSentView(
                invoice: invoice,
                embedInNavigationStack: false,
                onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .invoiceDetail(id: id)
                    }
                }
            )
            .id(invoice.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Invoice")
        }
    }
}

private struct MarkInvoicePaidLookupView: View {
    let id: UUID
    @Query private var results: [Invoice]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Invoice> { $0.id == id })
    }

    var body: some View {
        if let invoice = results.first {
            MarkAsPaidView(
                invoice: invoice,
                embedInNavigationStack: false,
                onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .invoiceDetail(id: id)
                    }
                }
            )
            .id(invoice.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Invoice")
        }
    }
}

private struct EditClientLookupView: View {
    let id: UUID
    @Query private var results: [Client]

    init(id: UUID) {
        self.id = id
        _results = Query(filter: #Predicate<Client> { $0.id == id })
    }

    var body: some View {
        if let client = results.first {
            EditClientView(
                client: client,
                embedInNavigationStack: false,
                onDismiss: {
                    withAnimation(FLOAnimation.quick) {
                        NavigationService.shared.selectedDetail = .clientDetail(id: id)
                    }
                }
            )
            .id(client.id)  // See AccountLookupView comment — prevents stale @State bleed across selections.
        } else {
            DetailNotFoundView(type: "Client")
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
