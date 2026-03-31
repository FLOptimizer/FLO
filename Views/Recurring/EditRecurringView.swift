//  EditRecurringView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5 - Penny-Up Currency Input
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.5 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ CHANGED: Amount state from String to Double (initialized from recurringTransaction.amount)
//  ✅ REMOVED: String-to-Double parsing in isValid and save()
//  ✅ UPDATED: All validation/save logic to use Double amount directly
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (X mark emoji)
//
//  CHANGES v2.4:
//  ✅ FIXED: UTF-8 mojibake — restored correct Unicode characters (X mark emoji)
//
//  CHANGES FROM v2.2:
//  ✅ Haptic feedback on all picker changes
//  ✅ Haptic on toggle changes
//  ✅ Section entrance animations
//  ✅ Save/Cancel/Delete button haptics
//  ✅ End date conditional animation
//
//  PREVIOUS (v2.2):
//  - Fixed RecurrenceFrequency enum

import SwiftUI
import SwiftData

struct EditRecurringView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Category.name) private var categories: [Category]
    
    let recurringTransaction: RecurringTransaction
    
    @State private var amount: Double
    @State private var merchantName: String
    @State private var isIncome: Bool
    @State private var selectedCategory: Category?
    @State private var frequency: RecurrenceFrequency
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var financeType: Transaction.FinanceType
    @State private var isActive: Bool
    @State private var showingDeleteAlert = false
    @State private var viewAppeared = false
    
    // Haptic Generators
                        
    init(recurringTransaction: RecurringTransaction) {
        self.recurringTransaction = recurringTransaction
        _amount = State(initialValue: recurringTransaction.amount)
        _merchantName = State(initialValue: recurringTransaction.merchantName)
        _isIncome = State(initialValue: recurringTransaction.isIncome)
        _selectedCategory = State(initialValue: recurringTransaction.category)
        _frequency = State(initialValue: recurringTransaction.frequency)
        _startDate = State(initialValue: recurringTransaction.startDate)
        _hasEndDate = State(initialValue: recurringTransaction.endDate != nil)
        _endDate = State(initialValue: recurringTransaction.endDate ?? Date())
        _financeType = State(initialValue: recurringTransaction.financeType)
        _isActive = State(initialValue: recurringTransaction.isActive)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                typeSection
                detailsSection
                frequencySection
                startDateSection
                endDateSection
                categorySection
                statusSection
                deleteSection
            }
            .navigationTitle("Edit Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        #if canImport(UIKit)
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                        #endif
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    .accessibilityLabel("Cancel editing")
                    .accessibilityHint("Discard changes and go back")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticService.play(.medium)
                        save()
                    }
                    .disabled(!isValid)
                    .accessibilityHint("Saves changes to recurring transaction")
                }
            }
            .alert("Delete Recurring Transaction", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    HapticService.play(.light)
                }
                Button("Delete", role: .destructive) {
                    deleteRecurring()
                }
            } message: {
                Text("Are you sure you want to delete this recurring transaction? This will not affect any transactions already created.")
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Edit recurring transaction")
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
        
    // MARK: - Sections
    
    private var typeSection: some View {
        Section {
            Picker("Type", selection: $isIncome) {
                Label("Expense", systemImage: "arrow.up.circle.fill")
                    .tag(false)
                Label("Income", systemImage: "arrow.down.circle.fill")
                    .tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: isIncome) { _, _ in
                HapticService.play(.selection)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)
    }
    
    private var detailsSection: some View {
        Section("Details") {
            TextField("Merchant Name", text: $merchantName)

            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Recurring amount"
            )
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }
    
    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Frequency", selection: $frequency) {
                ForEach(RecurrenceFrequency.allCases, id: \.self) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .onChange(of: frequency) { _, _ in
                HapticService.play(.selection)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)
    }
    
    private var startDateSection: some View {
        Section("Start Date") {
            DatePicker("Starts", selection: $startDate, displayedComponents: .date)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }
    
    private var endDateSection: some View {
        Section {
            Toggle("Set End Date", isOn: $hasEndDate)
                .onChange(of: hasEndDate) { _, _ in
                    HapticService.play(.light)
                }
            
            if hasEndDate {
                DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasEndDate)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)
    }
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("None").tag(Category?.none)
                
                if isIncome {
                    ForEach(organizedIncomeCategories) { category in
                        categoryLabel(for: category)
                    }
                } else {
                    Section(header: Text("BUSINESS")) {
                        ForEach(organizedBusinessCategories) { category in
                            categoryLabel(for: category)
                        }
                    }
                    
                    Section(header: Text("PERSONAL")) {
                        ForEach(organizedPersonalCategories) { category in
                            categoryLabel(for: category)
                        }
                    }
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                HapticService.play(.selection)
            }
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
    }
    
    private func categoryLabel(for category: Category) -> some View {
        Label {
            Text(category.name)
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(Color(flowHex: category.colorHex))
        }
        .tag(Optional(category))
    }
    
    private var statusSection: some View {
        Section {
            Toggle("Active", isOn: $isActive)
                .onChange(of: isActive) { _, _ in
                    HapticService.play(.light)
                }
        } footer: {
            Text("Inactive recurring transactions will not generate new transactions")
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.35), value: viewAppeared)
    }
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                HapticService.play(.heavy)
                showingDeleteAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Recurring Transaction")
                    Spacer()
                }
            }
            .accessibilityHint("Shows confirmation before deleting")
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.4), value: viewAppeared)
    }
    
    // MARK: - Computed Properties
    
    private var filteredCategories: [Category] {
        categories.filter { $0.isIncome == isIncome }
    }
    
    private var organizedIncomeCategories: [Category] {
        categories
            .filter { $0.isIncome == true }
            .sorted { $0.name < $1.name }
    }
    
    private var organizedBusinessCategories: [Category] {
        categories
            .filter { !$0.isIncome && $0.isBusiness }
            .sorted { $0.name < $1.name }
    }

    private var organizedPersonalCategories: [Category] {
        categories
            .filter { !$0.isIncome && !$0.isBusiness }
            .sorted { $0.name < $1.name }
    }
    
    private var isValid: Bool {
        guard !merchantName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard amount > 0 else { return false }
        return true
    }
    
    // MARK: - Actions
    
    private func save() {
        let amt = amount
        guard amt > 0 else { return }

        let trimmedName = merchantName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        recurringTransaction.amount = amt
        recurringTransaction.merchantName = trimmedName
        recurringTransaction.isIncome = isIncome
        recurringTransaction.frequency = frequency
        recurringTransaction.startDate = startDate
        recurringTransaction.endDate = hasEndDate ? endDate : nil
        recurringTransaction.category = selectedCategory
        recurringTransaction.financeType = financeType
        recurringTransaction.isActive = isActive
        
        do {
            try context.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            print("❌ Failed to save recurring transaction: \(error)")
            HapticService.play(.error)
        }
    }
    
    private func deleteRecurring() {
        context.delete(recurringTransaction)
        
        do {
            try context.save()
            HapticService.play(.success)
            dismiss()
        } catch {
            print("❌ Failed to delete recurring transaction: \(error)")
            HapticService.play(.error)
        }
    }
}

// MARK: - Preview

#Preview("Edit Recurring - Netflix") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: RecurringTransaction.self, Category.self,
        configurations: config
    )
    
    let context = container.mainContext
    
    let category = Category(
        name: "Subscriptions",
        icon: "tv",
        colorHex: "3B82F6",
        isIncome: false
    )
    context.insert(category)
    
    let recurring = RecurringTransaction(
        amount: 15.99,
        merchantName: "Netflix",
        note: "Streaming",
        isIncome: false,
        financeType: .personal,
        frequency: .monthly,
        startDate: Date(),
        category: category,
        isActive: true
    )
    context.insert(recurring)
    
    return EditRecurringView(recurringTransaction: recurring)
        .modelContainer(container)
}
