//  BatchCategorizationView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Batch Merchant Categorization UI
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  PURPOSE:
//  Groups transactions by merchant name and lets users assign a category
//  to all transactions from a given merchant at once. Essential for users
//  importing hundreds of bank transactions that need categorization.
//
//  FEATURES v1.0:
//  ✅ Groups transactions by normalized merchant name
//  ✅ Shows transaction count + total amount per merchant
//  ✅ Tap merchant → category picker → batch update
//  ✅ Toggle to show only uncategorized merchants
//  ✅ Search merchants by name
//  ✅ Creates MerchantCategoryMapping for future auto-categorization
//  ✅ Full VoiceOver accessibility support
//  ✅ Progress indicator during batch updates
//

import SwiftUI
import SwiftData

struct BatchCategorizationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]
    @Query(sort: \Category.name) private var categories: [Category]

    @StateObject private var service = BatchCategorizationService.shared

    @State private var merchantGroups: [MerchantGroup] = []
    @State private var searchText = ""
    @State private var showUncategorizedOnly = true
    @State private var selectedMerchant: MerchantGroup?
    @State private var showingCategoryPicker = false
    @State private var categorizedCount = 0
    @State private var lastCategorizedMerchant: String?

    var body: some View {
        NavigationStack {
            Group {
                if merchantGroups.isEmpty {
                    emptyState
                } else {
                    merchantList
                }
            }
            .navigationTitle("Batch Categorize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close batch categorization")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $showUncategorizedOnly) {
                        Image(systemName: showUncategorizedOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(showUncategorizedOnly ? "Showing uncategorized only" : "Showing all merchants")
                    .accessibilityHint("Double tap to toggle between all merchants and uncategorized only")
                }
            }
            .searchable(text: $searchText, prompt: "Search merchants")
            .onChange(of: showUncategorizedOnly) { _, _ in
                refreshGroups()
            }
            .onChange(of: allTransactions.count) { _, _ in
                refreshGroups()
            }
            .sheet(isPresented: $showingCategoryPicker) {
                if let merchant = selectedMerchant {
                    categoryPickerSheet(for: merchant)
                }
            }
            .onAppear {
                refreshGroups()
                AccessibilityAnnouncement.screenChanged("Batch Categorize. \(merchantGroups.count) merchant groups.")
            }
        }
    }

    // MARK: - Merchant List

    private var merchantList: some View {
        List {
            // Summary header
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(filteredGroups.count) Merchant Groups")
                            .font(.headline)
                        if categorizedCount > 0 {
                            Text("\(categorizedCount) transactions categorized this session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if showUncategorizedOnly {
                        Text("Uncategorized")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                .accessibilityElement(children: .combine)
            }

            // Merchant rows
            ForEach(filteredGroups) { group in
                merchantRow(for: group)
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Merchant Row

    private func merchantRow(for group: MerchantGroup) -> some View {
        Button {
            HapticService.play(.light)
            selectedMerchant = group
            showingCategoryPicker = true
        } label: {
            HStack(spacing: 12) {
                // Merchant icon
                Image(systemName: group.currentCategory != nil ? "checkmark.circle.fill" : "tag.circle")
                    .font(.title2)
                    .foregroundStyle(group.currentCategory != nil ? .green : Color.brandPrimary)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                // Merchant info
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.merchantName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label("\(group.transactionCount)", systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(AppConstants.currencyFormatter.string(from: NSNumber(value: group.totalAmount)) ?? "$\(group.totalAmount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let catName = group.currentCategoryName {
                            Text(catName)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.7))
                                .clipShape(Capsule())
                        } else if group.hasMultipleCategories {
                            Text("Mixed")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.7))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.merchantName), \(group.transactionCount) transactions, total \(AppConstants.currencyFormatter.string(from: NSNumber(value: group.totalAmount)) ?? "")")
        .accessibilityHint("Double tap to assign a category to all \(group.merchantName) transactions")
    }

    // MARK: - Category Picker Sheet

    private func categoryPickerSheet(for merchant: MerchantGroup) -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Categorize: \(merchant.merchantName)")
                            .font(.headline)
                        Text("\(merchant.transactionCount) transactions will be updated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("BUSINESS") {
                    ForEach(expenseCategories.filter { $0.isBusiness }.sorted { $0.name < $1.name }) { category in
                        Button {
                            applyCategory(category, to: merchant)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Color(flowHex: category.colorHex))
                                    .frame(width: 24)
                                    .accessibilityHidden(true)

                                Text(category.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if merchant.currentCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandPrimary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel(category.name)
                        .accessibilityHint("Double tap to categorize all \(merchant.merchantName) transactions as \(category.name)")
                    }
                }

                Section("PERSONAL") {
                    ForEach(expenseCategories.filter { !$0.isBusiness }.sorted { $0.name < $1.name }) { category in
                        Button {
                            applyCategory(category, to: merchant)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(Color(flowHex: category.colorHex))
                                    .frame(width: 24)
                                    .accessibilityHidden(true)

                                Text(category.name)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if merchant.currentCategory?.id == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.brandPrimary)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel(category.name)
                        .accessibilityHint("Double tap to categorize all \(merchant.merchantName) transactions as \(category.name)")
                    }
                }

                if !incomeCategories.isEmpty {
                    Section("Income Categories") {
                        ForEach(incomeCategories) { category in
                            Button {
                                applyCategory(category, to: merchant)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: category.icon)
                                        .foregroundStyle(Color(flowHex: category.colorHex))
                                        .frame(width: 24)
                                        .accessibilityHidden(true)

                                    Text(category.name)
                                        .foregroundStyle(.primary)

                                    Spacer()
                                }
                            }
                            .accessibilityLabel(category.name)
                        }
                    }
                }
            }
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showingCategoryPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("All Categorized!")
                .font(.headline)

            Text(showUncategorizedOnly
                 ? "All transactions have been categorized. Toggle the filter to see all merchants."
                 : "No transactions with merchant names found.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Computed Properties

    private var filteredGroups: [MerchantGroup] {
        guard !searchText.isEmpty else { return merchantGroups }
        let lowered = searchText.lowercased()
        return merchantGroups.filter {
            $0.merchantName.localizedCaseInsensitiveContains(lowered)
        }
    }

    private var expenseCategories: [Category] {
        categories.filter { !($0.isIncome) }
    }

    private var incomeCategories: [Category] {
        categories.filter { $0.isIncome }
    }

    // MARK: - Actions

    private func refreshGroups() {
        merchantGroups = service.groupTransactionsByMerchant(
            allTransactions,
            uncategorizedOnly: showUncategorizedOnly
        )
    }

    private func applyCategory(_ category: Category, to merchant: MerchantGroup) {
        let count = service.categorizeAll(
            merchantName: merchant.normalizedName,
            category: category,
            transactions: allTransactions,
            context: context
        )

        categorizedCount += count
        lastCategorizedMerchant = merchant.merchantName

        HapticService.play(.success)
        showingCategoryPicker = false

        // Refresh groups to reflect changes
        refreshGroups()

        // Announce to VoiceOver
        AccessibilityAnnouncement.announce(
            "Categorized \(count) \(merchant.merchantName) transactions as \(category.name)"
        )
    }
}
