//  BillFormView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Manual bill entry / edit
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Form for creating or editing a Bill. Mirrors CreateInvoiceView's structure
//  but pared down to bills' simpler shape (single amount, no line items, no
//  client contact info, due date OR Upon Receipt).
//

import SwiftUI
import SwiftData

struct BillFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { $0.isActive }, sort: \Account.name)
    private var accounts: [Account]
    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Vendor.name) private var vendors: [Vendor]

    /// nil for create, non-nil to edit
    let editingBill: Bill?

    // Form state
    @State private var vendorName: String = ""
    @State private var amount: Double = 0
    @State private var dueDate: Date = Date().addingTimeInterval(7 * 86400)
    @State private var isUponReceipt: Bool = false
    @State private var note: String = ""
    @State private var financeType: Transaction.FinanceType = .personal
    @State private var selectedCategory: Category?
    @State private var selectedAccount: Account?

    @State private var showingVendorPicker = false
    @State private var saveError: Error?
    @State private var showingSaveError = false

    init(editingBill: Bill? = nil) {
        self.editingBill = editingBill
    }

    private var isEditing: Bool { editingBill != nil }

    private var isValid: Bool {
        !vendorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && amount > 0
            && (isUponReceipt || dueDate > .distantPast)
    }

    var body: some View {
        NavigationStack {
            Form {
                vendorSection
                amountSection
                dueDateSection
                detailsSection
                noteSection
            }
            .navigationTitle(isEditing ? "Edit Bill" : "New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.heavy)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        save()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .sheet(isPresented: $showingVendorPicker) {
                VendorPickerView(selectedName: $vendorName, vendors: vendors)
            }
            .alert("Couldn't save bill", isPresented: $showingSaveError, presenting: saveError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.localizedDescription)
            }
            .onAppear(perform: loadEditingState)
        }
        .floMacSheetFrame()
    }

    // MARK: - Sections

    private var vendorSection: some View {
        Section("Vendor") {
            HStack {
                TextField("Vendor name", text: $vendorName)
                    .textInputAutocapitalization(.words)
                if !vendors.isEmpty {
                    Button {
                        HapticService.play(.light)
                        showingVendorPicker = true
                    } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private var amountSection: some View {
        Section("Amount") {
            CurrencyInputField(amount: $amount, font: .title2)
                .padding(.vertical, 4)
        }
    }

    private var dueDateSection: some View {
        Section("Due Date") {
            Toggle("Upon Receipt", isOn: $isUponReceipt)
                .onChange(of: isUponReceipt) { _, newValue in
                    HapticService.play(.light)
                    if newValue { hideKeyboard() }
                }
            if !isUponReceipt {
                DatePicker("Due", selection: $dueDate, displayedComponents: .date)
            } else {
                Text("Bill will appear in Upcoming with no fixed date and is treated as overdue 24 hours after creation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    /// Deduplicated expense categories (dedup BEFORE business/personal split)
    private var uniqueExpenseCategories: [Category] {
        let expense = categories.filter { !$0.isIncome }.sorted { $0.name < $1.name }
        var seen = Set<String>()
        return expense.filter { seen.insert($0.name).inserted }
    }

    /// Expense categories filtered by current financeType selection
    private var filteredCategories: [Category] {
        financeType == .business
            ? uniqueExpenseCategories.filter { $0.isBusiness }
            : uniqueExpenseCategories.filter { !$0.isBusiness }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Classification", selection: $financeType) {
                Text("Business").tag(Transaction.FinanceType.business)
                Text("Personal").tag(Transaction.FinanceType.personal)
            }
            .pickerStyle(.segmented)

            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Category?.none)
                ForEach(filteredCategories, id: \.id) { category in
                    Label(category.name, systemImage: category.icon)
                        .tag(Category?.some(category))
                }
            }

            Picker("Pay From", selection: $selectedAccount) {
                Text("Default").tag(Account?.none)
                ForEach(accounts.filter { $0.isActive && $0.includeInTransactions }, id: \.id) { account in
                    Text(account.name).tag(Account?.some(account))
                }
            }
        }
    }

    private var noteSection: some View {
        Section("Note") {
            TextField("Optional note", text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    // MARK: - Actions

    private func loadEditingState() {
        guard let bill = editingBill else { return }
        vendorName = bill.vendorName
        amount = bill.amount
        if let due = bill.dueDate {
            dueDate = due
        }
        isUponReceipt = bill.isUponReceipt
        note = bill.note
        financeType = bill.financeType
        selectedCategory = bill.category
        selectedAccount = bill.account
    }

    private func save() {
        do {
            if let bill = editingBill {
                try BillService.shared.updateBill(
                    bill,
                    vendorName: vendorName,
                    amount: amount,
                    dueDate: isUponReceipt ? .some(nil) : .some(dueDate),
                    isUponReceipt: isUponReceipt,
                    note: note,
                    financeType: financeType,
                    category: .some(selectedCategory),
                    account: .some(selectedAccount),
                    context: modelContext
                )
            } else {
                try BillService.shared.createBill(
                    vendorName: vendorName,
                    amount: amount,
                    dueDate: isUponReceipt ? nil : dueDate,
                    isUponReceipt: isUponReceipt,
                    note: note,
                    financeType: financeType,
                    category: selectedCategory,
                    account: selectedAccount,
                    context: modelContext
                )
            }
            HapticService.play(.success)
            dismiss()
        } catch {
            HapticService.play(.error)
            saveError = error
            showingSaveError = true
        }
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
        #endif
    }
}

// MARK: - Vendor Picker

private struct VendorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedName: String
    let vendors: [Vendor]

    @State private var query = ""

    private var filtered: [Vendor] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return vendors }
        return vendors.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.id) { vendor in
                Button {
                    selectedName = vendor.name
                    HapticService.play(.light)
                    dismiss()
                } label: {
                    HStack {
                        Text(vendor.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        if vendor.name == selectedName {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search vendors")
            .navigationTitle("Select Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .floMacSheetFrame(minWidth: 420, minHeight: 480)
    }
}

#if DEBUG
#Preview("New Bill") {
    BillFormView()
        .modelContainer(ModelContainer.preview())
}
#Preview("Edit Bill") {
    BillFormView(editingBill: Bill.previewPending)
        .modelContainer(ModelContainer.preview())
}
#endif
