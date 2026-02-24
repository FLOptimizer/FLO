//  CSVImportReviewView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.0 - Business/Personal Toggle Fix + Category Grouping + Bank Category Display
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.0:
//  ✅ FIXED: Segmented Picker uses Label instead of HStack — no more 4-segment bug
//  ✅ FIXED: Category picker now groups by Business / Personal sections with headers
//  ✅ ADDED: Bank-provided category shown in transaction row badge
//  ✅ ADDED: Merchant name (description) shown prominently in transaction row
//
//  CHANGES v1.3 - Dark Mode Optimization:
//  ✅ FIXED: L536 Color.gray → Color(.systemGray4) for import button background (adapts to dark mode)
//  ✅ FIXED: L685 Color.gray → .secondary for checkbox icon foregroundStyle (adapts to dark mode)
//  ✅ FIXED: L730 Color.gray.opacity(0.12) → Color(.systemGray4).opacity(0.12) for category badge background (adapts to dark mode)
//  ✅ FIXED: L732 Color.gray → .secondary for category badge foregroundStyle (adapts to dark mode)
//  ✅ FIXED: L749 Color.gray.opacity(0.12) → Color(.systemGray4).opacity(0.12) for finance type badge background (adapts to dark mode)
//  ✅ FIXED: L751 Color.gray → .secondary for finance type badge foregroundStyle (adapts to dark mode)
//
//  CHANGES v1.2 - Dynamic Type Verification:
//  ✅ FIXED: All Text() elements missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Import summary stats text (rows, transactions, skipped) - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Date range and profile name labels - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Bulk controls button labels - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Account picker button text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Skipped rows disclosure label - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Footer action button text - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Category picker transaction details - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Category list item names - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Transaction row merchant names - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Transaction row dates - lineLimit(1) + minimumScaleFactor(0.8)
//  ✅ FIXED: Transaction row amounts - lineLimit(1) + minimumScaleFactor(0.5)
//  ✅ FIXED: Transaction row category badges - lineLimit(1) + minimumScaleFactor(0.7)
//  ✅ FIXED: Transaction row badge text - lineLimit(1) + minimumScaleFactor(0.7)
//
//  CHANGES v1.1:
//  - Added screen announcement on appear with transaction count
//  - Full VoiceOver accessibility for all interactive elements
//  - Transaction rows with comprehensive accessibility labels
//  - Currency values spoken correctly
//  - Category picker sheet accessibility
//  - Success/error announcements for dynamic feedback
//
//  FEATURES:
//  - Import summary banner with stats
//  - Bulk controls (select all, hide duplicates, finance type, account)
//  - Transaction list with category assignment
//  - Duplicate detection highlighting
//  - Category quick-assign with "apply to same merchant" option
//  - Skipped rows disclosure
//  - Commit action with success state
//

import SwiftUI
import SwiftData

struct CSVImportReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var existingTransactions: [Transaction]
    @Query private var merchantMappings: [MerchantCategoryMapping]
    
    let importResult: CSVImportResult
    
    @State private var transactions: [CSVParsedTransaction]
    @State private var targetAccount: Account?
    @State private var defaultFinanceType: Transaction.FinanceType = .personal
    @State private var hideDuplicates: Bool = false
    @State private var showingCategoryPicker: Bool = false
    @State private var categoryPickerIndex: Int?
    @State private var isCommitting: Bool = false
    @State private var commitError: String?
    @State private var showingCommitSuccess: Bool = false
    @State private var committedCount: Int = 0
    @State private var viewAppeared: Bool = false
    
    init(importResult: CSVImportResult) {
        self.importResult = importResult
        _transactions = State(initialValue: importResult.transactions)
    }
    
    // MARK: - Computed Properties
    
    /// Transactions filtered by duplicate toggle
    var filteredTransactions: [CSVParsedTransaction] {
        if hideDuplicates {
            return transactions.filter { !$0.isDuplicate }
        }
        return transactions
    }
    
    /// Count of transactions that will be imported
    var selectedCount: Int {
        transactions.filter { $0.isSelected && (!$0.isDuplicate || !hideDuplicates) }.count
    }
    
    /// Whether all visible transactions are selected
    var allSelected: Bool {
        filteredTransactions.allSatisfy { $0.isSelected }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Section 1: Import Summary Banner
                    summaryBanner
                    
                    // Section 2: Bulk Controls Bar
                    bulkControlsBar
                    
                    // Section 3: Transaction List
                    transactionList
                    
                    // Section 4: Skipped Rows (if any)
                    skippedRowsSection
                }
                .padding(.bottom, 100) // Space for footer action bar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                footerActionBar
            }
            .sheet(isPresented: $showingCategoryPicker) {
                categoryPickerSheet
            }
            .alert("Import Complete", isPresented: $showingCommitSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Successfully imported \(committedCount) transactions")
            }
            .alert("Import Failed", isPresented: .constant(commitError != nil)) {
                Button("OK") {
                    commitError = nil
                }
            } message: {
                Text(commitError ?? "Unknown error")
            }
            .onAppear {
                // Step 1: Auto-categorize using learned merchant mappings
                transactions = CSVCategorizationService.shared.categorizeTransactions(
                    parsed: transactions,
                    merchantMappings: Array(merchantMappings),
                    categories: Array(categories)
                )
                
                // Step 2: Detect duplicates against existing transactions
                transactions = TransactionMatchingService.shared.findCSVDuplicates(
                    parsed: transactions,
                    existing: Array(existingTransactions)
                )
                
                // Step 3: Accessibility announcement
                AccessibilityAnnouncement.screenChanged(
                    "Import Review, \(transactions.count) transactions to review"
                )
                
                // Step 4: Entrance animation
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Commit Import
    
    private func commitImport() {
        isCommitting = true
        HapticService.play(.medium)
        
        let result = CSVImportCommitService.shared.commitImport(
            transactions: transactions,
            targetAccount: targetAccount,
            defaultFinanceType: defaultFinanceType,
            context: context
        )
        
        switch result {
        case .success(let count):
            committedCount = count
            HapticService.play(.success)
            AccessibilityAnnouncement.announce("Successfully imported \(count) transactions")
            showingCommitSuccess = true
        case .failure(let error):
            commitError = error.localizedDescription
            AccessibilityAnnouncement.announce("Import failed: \(error.localizedDescription)")
            HapticService.play(.error)
            isCommitting = false
        }
    }
    
    // MARK: - Section 1: Import Summary Banner
    
    private var summaryBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(Color.brandPrimaryText)
                    .accessibilityHidden(true)
                
                Text("Import Summary")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(importResult.totalRows)")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.brandPrimaryText)
                    Text("rows parsed")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("\(transactions.count)")
                        .font(.title3.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Color.brandPrimaryText)
                    Text("valid transactions")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
                
                if !importResult.skippedRows.isEmpty {
                    HStack {
                        Text("\(importResult.skippedRows.count)")
                            .font(.title3.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.orange)
                        Text("skipped")
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let dateRange = importResult.dateRange {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("\(dateRange.lowerBound, format: .dateTime.month().day().year()) – \(dateRange.upperBound, format: .dateTime.month().day().year())")
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "building.columns.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(importResult.detectedProfile?.displayName ?? "Manual Import")
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.brandPrimary.opacity(0.1))
        )
        .padding(.horizontal)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Section 2: Bulk Controls Bar
    
    private var bulkControlsBar: some View {
        VStack(spacing: 12) {
            // Row 1: Select All + Hide Duplicates
            HStack {
                Button {
                    HapticService.play(.light)
                    let newValue = !allSelected
                    for i in transactions.indices {
                        transactions[i].isSelected = newValue
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.brandPrimary)
                        Text(allSelected ? "Deselect All" : "Select All")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel(allSelected ? "Deselect all transactions" : "Select all transactions")
                .accessibilityHint("Toggles selection for all \(filteredTransactions.count) visible transactions")
                
                Spacer()
                
                // Only show hide duplicates if there are duplicates
                if transactions.contains(where: { $0.isDuplicate }) {
                    Toggle(isOn: $hideDuplicates) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash.fill")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text("Hide Duplicates")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.brandPrimary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("Hide duplicate transactions")
                    .accessibilityHint("Filters out transactions that match existing records")
                    .accessibilityValue(hideDuplicates ? "On" : "Off")
                    .onChange(of: hideDuplicates) { _, _ in
                        HapticService.play(.light)
                    }
                }
            }
            
            // Row 2: Finance Type + Account Picker
            HStack {
                // Finance Type Picker
                Picker("Finance Type", selection: $defaultFinanceType) {
                    ForEach(Transaction.FinanceType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Finance type for imported transactions")
                .onChange(of: defaultFinanceType) { _, newValue in
                    HapticService.play(.light)
                    transactions = CSVCategorizationService.shared.applyFinanceType(
                        to: transactions,
                        financeType: newValue
                    )
                }
                
                Spacer()
                
                // Account Picker
                if !accounts.isEmpty {
                    Menu {
                        Button("No Account") {
                            targetAccount = nil
                            HapticService.play(.light)
                        }
                        
                        Divider()
                        
                        ForEach(accounts) { account in
                            Button {
                                targetAccount = account
                                HapticService.play(.light)
                            } label: {
                                HStack {
                                    Text(account.name)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                    if targetAccount?.id == account.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "building.columns")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(targetAccount?.name ?? "Account")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Assign to account")
                    .accessibilityHint("All imported transactions will be added to this account")
                    .accessibilityValue(targetAccount?.name ?? "None selected")
                }
            }
        }
        .padding(.horizontal)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }
    
    // MARK: - Section 3: Transaction List
    
    private var transactionList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredTransactions.enumerated()), id: \.element.id) { displayIndex, txn in
                if let realIndex = transactions.firstIndex(where: { $0.id == txn.id }) {
                    CSVImportTransactionRow(
                        transaction: $transactions[realIndex],
                        onCategoryTap: {
                            categoryPickerIndex = realIndex
                            showingCategoryPicker = true
                        }
                    )
                    
                    if displayIndex < filteredTransactions.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .padding(.horizontal)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
    }
    
    // MARK: - Section 4: Skipped Rows
    
    private var skippedRowsSection: some View {
        Group {
            if !importResult.skippedRows.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(importResult.skippedRows, id: \.lineNumber) { row in
                            HStack(alignment: .top, spacing: 8) {
                                Text("Line \(row.lineNumber)")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                
                                Text(row.reason)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.7)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text("\(importResult.skippedRows.count) rows skipped")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .accessibilityLabel("\(importResult.skippedRows.count) rows were skipped during import")
                .accessibilityHint("Expand to see which rows failed and why")
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .opacity(viewAppeared ? 1 : 0.001)
                .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
            }
        }
    }
    
    // MARK: - Footer Action Bar
    
    private var footerActionBar: some View {
        VStack(spacing: 8) {
            Button {
                commitImport()
            } label: {
                HStack {
                    if isCommitting {
                        ProgressView()
                            .tint(.white)
                            .accessibilityLabel("Importing transactions, please wait")
                    } else {
                        Image(systemName: "square.and.arrow.down")
                            .accessibilityHidden(true)
                    }
                    Text("Import \(selectedCount) Transactions")
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(selectedCount > 0 ? Color.brandPrimary : Color(.systemGray4))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCount == 0 || isCommitting)
            .accessibilityLabel("Import \(selectedCount) transactions")
            .accessibilityHint("Saves selected transactions to your FLO account")
            
            Button("Cancel", role: .cancel) {
                HapticService.play(.light)
                dismiss()
            }
            .foregroundStyle(.secondary)
            .accessibilityLabel("Cancel import")
            .accessibilityHint("Discards all changes and returns to previous screen")
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Category Picker Sheet
    
    @State private var applyToSameMerchant: Bool = false
    
    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                if let index = categoryPickerIndex {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transactions[index].merchantName)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text(transactions[index].date, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transactions[index].amount, format: .currency(code: "USD"))
                                .font(.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(transactions[index].isIncome ? Color.brandAccent : Color(flowHex: "#EF4444"))
                        }
                    } header: {
                        Text("Transaction")
                    }
                    
                    Section {
                        Toggle("Apply to all with same merchant", isOn: $applyToSameMerchant)
                            .accessibilityLabel("Apply category to all transactions from \(transactions[index].merchantName)")
                            .accessibilityHint("Sets this category for every transaction with the same merchant name")
                            .onChange(of: applyToSameMerchant) { _, _ in
                                HapticService.play(.light)
                            }
                    }
                    
                    // Business Categories
                    if !categories.filter({ $0.isBusiness }).isEmpty {
                        Section {
                            ForEach(categories.filter { $0.isBusiness }) { category in
                                Button {
                                    selectCategory(category, at: index)
                                } label: {
                                    categoryRow(category: category, selectedID: transactions[index].suggestedCategory?.id)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                            }
                        } header: {
                            Label("Business", systemImage: "briefcase.fill")
                        }
                    }
                    
                    // Personal Categories
                    if !categories.filter({ !$0.isBusiness }).isEmpty {
                        Section {
                            ForEach(categories.filter { !$0.isBusiness }) { category in
                                Button {
                                    selectCategory(category, at: index)
                                } label: {
                                    categoryRow(category: category, selectedID: transactions[index].suggestedCategory?.id)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                            }
                        } header: {
                            Label("Personal", systemImage: "person.fill")
                        }
                    }
                }
            }
            .navigationTitle("Change Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingCategoryPicker = false
                    }
                }
            }
            .onAppear {
                AccessibilityAnnouncement.screenChanged("Select Category")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func categoryRow(category: Category, selectedID: UUID?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(flowHex: category.colorHex).opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(Color(flowHex: category.colorHex))
            }
            .accessibilityHidden(true)
            
            Text(category.name)
                .font(.body)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
            
            Spacer()
            
            if selectedID == category.id {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color.brandPrimary)
                    .accessibilityHidden(true)
            }
        }
    }
    
    private func selectCategory(_ category: Category, at index: Int) {
        if applyToSameMerchant {
            let merchant = transactions[index].merchantName
            for i in transactions.indices {
                if transactions[i].merchantName == merchant {
                    transactions[i].suggestedCategory = category
                }
            }
        } else {
            transactions[index].suggestedCategory = category
        }
        showingCategoryPicker = false
        applyToSameMerchant = false
        HapticService.play(.medium)
    }
}
// MARK: - CSV Import Transaction Row

struct CSVImportTransactionRow: View {
    @Binding var transaction: CSVParsedTransaction
    let onCategoryTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                HapticService.play(.light)
                transaction.isSelected.toggle()
            } label: {
                Image(systemName: transaction.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(transaction.isSelected ? Color.brandPrimary : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                // Date and merchant
                HStack(spacing: 8) {
                    Text(transaction.date, format: .dateTime.month().day().year(.twoDigits))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                    
                    Text(transaction.merchantName)
                        .font(.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                // Badges row
                HStack(spacing: 6) {
                    // Category chip
                    Button {
                        onCategoryTap()
                    } label: {
                        HStack(spacing: 4) {
                            if let category = transaction.suggestedCategory {
                                Image(systemName: category.icon)
                                    .font(.caption2)
                                Text(category.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            } else {
                                Image(systemName: "questionmark.circle")
                                    .font(.caption2)
                                Text("Uncategorized")
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(transaction.suggestedCategory.map { Color(flowHex: $0.colorHex).opacity(0.12) } ?? Color(.systemGray4).opacity(0.12))
                        )
                        .foregroundStyle(transaction.suggestedCategory.map { Color(flowHex: $0.colorHex) } ?? .secondary)
                    }
                    .accessibilityHint("Double tap to change category")
                    
                    // Finance type badge
                    HStack(spacing: 2) {
                        Image(systemName: transaction.suggestedFinanceType.icon)
                            .font(.caption2)
                        Text(String(transaction.suggestedFinanceType.displayName.prefix(1)))
                            .font(.caption2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(transaction.suggestedFinanceType == .business ? Color.blue.opacity(0.12) : Color(.systemGray4).opacity(0.12))
                    )
                    .foregroundStyle(transaction.suggestedFinanceType == .business ? Color.blue : .secondary)
                    .accessibilityHidden(true)
                    
                    // Bank-provided category badge (if available)
                    if let bankCat = transaction.bankCategory {
                        HStack(spacing: 2) {
                            Image(systemName: "building.columns")
                                .font(.caption2)
                            Text(bankCat)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray4).opacity(0.12))
                        )
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Bank category: \(bankCat)")
                    }
                    
                    // Duplicate badge
                    if transaction.isDuplicate {
                        HStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("Dup \(Int(transaction.duplicateMatchScore * 100))%")
                                .font(.caption2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.orange.opacity(0.12))
                        )
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Possible duplicate, \(Int(transaction.duplicateMatchScore * 100)) percent match")
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text(transaction.amount, format: .currency(code: "USD"))
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(transaction.isIncome ? Color.brandAccent : Color(flowHex: "#EF4444"))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let amount = AccessibilityFormatters.spokenCurrency(transaction.amount)
            let type = transaction.isIncome ? "income" : "expense"
            let date = AccessibilityFormatters.spokenDate(transaction.date)
            let category = transaction.suggestedCategory?.name ?? "Uncategorized"
            let finance = transaction.suggestedFinanceType.displayName
            let bankCat = transaction.bankCategory.map { ", Bank category: \($0)" } ?? ""
            let duplicate = transaction.isDuplicate
                ? ", Possible duplicate, \(Int(transaction.duplicateMatchScore * 100)) percent match"
                : ""
            let selected = transaction.isSelected ? "Selected" : "Not selected"
            
            return "\(selected). \(transaction.merchantName), \(type), \(amount), \(date), \(category), \(finance)\(bankCat)\(duplicate)"
        }())
        .accessibilityAddTraits(transaction.isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Double tap to toggle selection")
        .accessibilityAction(named: "Change category") {
            onCategoryTap()
        }
    }
}
