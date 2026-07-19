//  GlobalSearchView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 — Catalyst searchable · Global search across all data types
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//

import SwiftUI
import SwiftData

struct GlobalSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false

    enum SearchResultType: String, CaseIterable {
        case transaction, account, invoice, client, recurring, mileage, bill, business

        var displayName: String {
            switch self {
            case .transaction: return "Transactions"
            case .account: return "Accounts"
            case .invoice: return "Invoices"
            case .client: return "Clients"
            case .recurring: return "Recurring"
            case .mileage: return "Mileage"
            case .bill: return "Bills"
            case .business: return "Businesses"
            }
        }
    }

    struct SearchResult: Identifiable {
        let id: UUID
        let type: SearchResultType
        let title: String
        let subtitle: String
        let icon: String
        let iconColor: Color
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    emptyState
                } else if searchResults.isEmpty && !isSearching {
                    noResultsState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(macOS) || targetEnvironment(macCatalyst)
            .searchable(text: $searchText, prompt: "Search transactions, accounts, invoices…")
            #else
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions, accounts, invoices…")
            #endif
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Search FLO", systemImage: "magnifyingglass")
        } description: {
            Text("Search across all your transactions, accounts, invoices, clients, and more.")
        }
    }

    // MARK: - No Results

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No results for \"\(searchText)\". Try a different search term.")
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            let grouped = Dictionary(grouping: searchResults, by: { $0.type })
            ForEach(SearchResultType.allCases, id: \.self) { type in
                if let results = grouped[type], !results.isEmpty {
                    Section(type.displayName) {
                        ForEach(results) { result in
                            Button {
                                navigateToResult(result)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: result.icon)
                                        .font(.body)
                                        .foregroundStyle(result.iconColor)
                                        .frame(width: 28, height: 28)
                                        .background(result.iconColor.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        var results: [SearchResult] = []

        // Transactions
        if let transactions = try? modelContext.fetch(FetchDescriptor<Transaction>()) {
            let matches = transactions.filter {
                $0.merchantName.localizedCaseInsensitiveContains(trimmed) ||
                $0.note.localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .transaction,
                    title: $0.displayName,
                    subtitle: "\($0.amount.formatted(.currency(code: "USD"))) · \($0.date.formatted(date: .abbreviated, time: .omitted))",
                    icon: "creditcard.fill",
                    iconColor: .blue
                )
            }
        }

        // Accounts
        if let accounts = try? modelContext.fetch(FetchDescriptor<Account>()) {
            let matches = accounts.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                ($0.institutionName ?? "").localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .account,
                    title: $0.name,
                    subtitle: "\($0.accountType.displayName) · \($0.currentBalance.formatted(.currency(code: "USD")))",
                    icon: "building.columns.fill",
                    iconColor: .teal
                )
            }
        }

        // Invoices
        if let invoices = try? modelContext.fetch(FetchDescriptor<Invoice>()) {
            let matches = invoices.filter {
                $0.invoiceNumber.localizedCaseInsensitiveContains(trimmed) ||
                ($0.notes ?? "").localizedCaseInsensitiveContains(trimmed) ||
                ($0.client?.name ?? "").localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .invoice,
                    title: "Invoice \($0.invoiceNumber.isEmpty ? String($0.id.uuidString.prefix(8)) : $0.invoiceNumber)",
                    subtitle: "\($0.client?.name ?? "No client") · \($0.totalAmount.formatted(.currency(code: "USD")))",
                    icon: "doc.text.fill",
                    iconColor: .green
                )
            }
        }

        // Clients
        if let clients = try? modelContext.fetch(FetchDescriptor<Client>()) {
            let matches = clients.filter {
                $0.name.localizedCaseInsensitiveContains(trimmed) ||
                ($0.contactName ?? "").localizedCaseInsensitiveContains(trimmed) ||
                ($0.email ?? "").localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .client,
                    title: $0.name,
                    subtitle: $0.contactName ?? $0.email ?? "Client",
                    icon: "person.fill",
                    iconColor: .orange
                )
            }
        }

        // Recurring Transactions
        if let recurring = try? modelContext.fetch(FetchDescriptor<RecurringTransaction>()) {
            let matches = recurring.filter {
                $0.merchantName.localizedCaseInsensitiveContains(trimmed) ||
                $0.note.localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .recurring,
                    title: $0.merchantName.isEmpty ? "Recurring" : $0.merchantName,
                    subtitle: "\($0.amount.formatted(.currency(code: "USD"))) · \($0.frequency.displayName)",
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: .purple
                )
            }
        }

        // Mileage Trips
        if let trips = try? modelContext.fetch(FetchDescriptor<MileageTrip>()) {
            let matches = trips.filter {
                ($0.startAddress ?? "").localizedCaseInsensitiveContains(trimmed) ||
                ($0.endAddress ?? "").localizedCaseInsensitiveContains(trimmed) ||
                ($0.notes ?? "").localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .mileage,
                    title: "\($0.startAddress ?? "Start") → \($0.endAddress ?? "End")",
                    subtitle: "\(String(format: "%.1f", $0.distanceMiles)) mi · \($0.startDate.formatted(date: .abbreviated, time: .omitted))",
                    icon: "car.fill",
                    iconColor: .cyan
                )
            }
        }

        // Bills
        if let bills = try? modelContext.fetch(FetchDescriptor<Bill>()) {
            let matches = bills.filter {
                $0.vendorName.localizedCaseInsensitiveContains(trimmed) ||
                $0.note.localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .bill,
                    title: $0.vendorName.isEmpty ? "Bill" : $0.vendorName,
                    subtitle: "\($0.amount.formatted(.currency(code: "USD"))) · \(($0.dueDate ?? Date()).formatted(date: .abbreviated, time: .omitted))",
                    icon: "calendar.badge.clock",
                    iconColor: .red
                )
            }
        }

        // Business Profiles
        if let businesses = try? modelContext.fetch(FetchDescriptor<BusinessProfile>()) {
            let matches = businesses.filter {
                $0.businessName.localizedCaseInsensitiveContains(trimmed) ||
                $0.email.localizedCaseInsensitiveContains(trimmed)
            }.prefix(5)
            results += matches.map {
                SearchResult(
                    id: $0.id,
                    type: .business,
                    title: $0.businessName,
                    subtitle: $0.businessType.displayName,
                    icon: "briefcase.fill",
                    iconColor: .brandPrimary
                )
            }
        }

        searchResults = results
        isSearching = false
    }

    // MARK: - Navigation

    private func navigateToResult(_ result: SearchResult) {
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch result.type {
            case .transaction:
                NavigationService.shared.openTransaction(id: result.id)
            case .account:
                NavigationService.shared.openAccount(id: result.id)
            case .invoice:
                NavigationService.shared.openInvoice(id: result.id)
            case .client:
                NavigationService.shared.openClient(id: result.id)
            case .recurring:
                NavigationService.shared.selectedTab = .transactions
            case .mileage:
                NavigationService.shared.selectedTab = .mileage
            case .bill:
                NavigationService.shared.selectedTab = .transactions
            case .business:
                NavigationService.shared.selectedTab = .settings
            }
        }
    }
}

#Preview {
    GlobalSearchView()
        .modelContainer(ModelContainer.preview())
}
