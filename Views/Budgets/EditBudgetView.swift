//  EditBudgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.8 - Editable Category/Month + Done Button Fix
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.8 - Editable Category/Month + Done Button Fix:
//  ✅ FIXED: Two "Done" buttons on keyboard — both CurrencyInputFields had their own
//           keyboard toolbar Done button. Now uses showDoneButton:false on both fields
//           and a single Form-level keyboard toolbar Done button.
//  ✅ ADDED: Category is now editable via Picker (was read-only display)
//  ✅ ADDED: Month is now editable via Picker with ±12 month range (was read-only display)
//  ✅ ADDED: @Query for categories to populate the category picker
//  ✅ UPDATED: save() now persists category and month changes
//
//  CHANGES v2.7 - Navigation Fix + Delete:
//  ✅ FIXED: Removed nested NavigationStack — view is pushed via NavigationLink from
//           BudgetListView which already provides a NavigationStack. The nested stack
//           caused duplicate navigation bars (multiple "Done" buttons).
//  ✅ REMOVED: Cancel toolbar button — system back button handles dismissal in push nav.
//  ✅ ADDED: Delete Budget section at bottom of form
//  ✅ ADDED: Confirmation alert before deletion
//  ✅ ADDED: VoiceOver accessible delete button with label and hint
//
//  CHANGES v2.6 - Penny-Up Currency Input:
//  ✅ REPLACED: Old TextField + String amount with CurrencyInputField component
//  ✅ REPLACED: Old TextField + String carryOver with CurrencyInputField component
//  ✅ CHANGED: amount and carryOver state from String to Double
//  ✅ UPDATED: isValid, save(), and summarySection to use Doubles directly
//
//  CHANGES v2.5 - Dynamic Type Verification:
//  ✅ FIXED: Category name text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Finance type emoji missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Month display text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Budget amount dollar sign missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Carry over dollar sign missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Section footer text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Total budget labels missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Total budget value missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.4:
//  ✅ ADDED: Category display accessible with combined label + finance type
//  ✅ ADDED: Month display accessible with spoken date
//  ✅ ADDED: Budget amount field labeled with $ hidden
//  ✅ ADDED: Carry over field labeled with explanation hint
//  ✅ ADDED: Total available summary accessible with spoken currency
//  ✅ ADDED: Cancel/Save toolbar buttons labeled with dynamic hints
//  ✅ ADDED: Screen change announcement on appear
//  ✅ ADDED: Save success/failure announced
//  ✅ ADDED: Decorative icons hidden
//  ✅ ADDED: isSummaryElement trait on total
//
//  CHANGES v2.3:
//  - Comprehensive haptic preparation
//  - Section entrance animations
//  - Value content transitions
//  - Cancel/save button haptics
//

import SwiftUI
import SwiftData
  
struct EditBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name) private var categories: [Category]  // v2.8

    let budget: Budget

    @State private var amount: Double
    @State private var carryOver: Double
    @State private var selectedCategory: Category?  // v2.8: Editable category
    @State private var selectedMonth: Date           // v2.8: Editable month
    @State private var viewAppeared = false
    @State private var showingDeleteConfirmation = false

    /// Expense categories only (exclude income categories)
    private var filteredCategories: [Category] {
        categories.filter { !$0.isIncome }
    }

    /// Month options: ±12 months from today
    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        guard let currentMonth = calendar.date(from: components) else { return [] }

        return (-12...12).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: currentMonth)
        }
    }

    init(budget: Budget) {
        self.budget = budget
        _amount = State(initialValue: budget.planned)
        _carryOver = State(initialValue: budget.carryOver)
        _selectedCategory = State(initialValue: budget.category)
        _selectedMonth = State(initialValue: budget.month)
    }
     
    var body: some View {
        Form {
            categorySection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.05), value: viewAppeared)

            monthSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)

            amountSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.15), value: viewAppeared)

            carryOverSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)

            summarySection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.25), value: viewAppeared)

            deleteSection
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 10)
                .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
        }
        .navigationTitle("Edit Budget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    HapticService.play(.medium)
                    save()
                }
                .disabled(!isValid)
                // v2.4: VoiceOver
                .accessibilityLabel("Save budget")
                .accessibilityHint(isValid ? "Double tap to save your changes" : "Enter a valid amount greater than zero to enable saving")
            }
            // v2.8: Single keyboard Done button (replaces per-field Done buttons)
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
        }
        .alert("Delete Budget?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteBudget()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove this budget. This action cannot be undone.")
        }
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                viewAppeared = true
            }
            // v2.4: Announce screen
            let categoryName = budget.category?.name ?? "Unknown"
            AccessibilityAnnouncement.screenChanged("Edit Budget: \(categoryName)")
        }
    }
    
    // MARK: - Sections
    
    private var categorySection: some View {
        Section("Category") {
            Picker("Category", selection: $selectedCategory) {
                Text("Select category").tag(Category?.none)
                ForEach(filteredCategories) { cat in
                    Label(cat.name, systemImage: cat.icon)
                        .tag(Optional(cat))
                }
            }
            .accessibilityLabel("Budget category")
            .accessibilityHint("Double tap to change the category for this budget")
        }
    }
    
    private var monthSection: some View {
        Section("Month") {
            Picker("Month", selection: $selectedMonth) {
                ForEach(monthOptions, id: \.self) { date in
                    Text(date, format: .dateTime.month(.wide).year())
                        .tag(date)
                }
            }
            .accessibilityLabel("Budget month")
            .accessibilityHint("Double tap to change the month for this budget")
        }
    }
    
    private var amountSection: some View {
        Section("Budget Amount") {
            CurrencyInputField(
                amount: $amount,
                accessibilityLabelText: "Budget amount",
                showDoneButton: false  // v2.8: Single Done button at Form level
            )
        }
    }

    private var carryOverSection: some View {
        Section {
            CurrencyInputField(
                amount: $carryOver,
                accessibilityLabelText: "Carry over amount",
                showDoneButton: false  // v2.8: Single Done button at Form level
            )
        } header: {
            Text("Carry Over from Previous Month")
        } footer: {
            Text("Unused funds from previous months")
                .font(.caption)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    private var summarySection: some View {
        Section("Total Available") {
            let total = amount + carryOver
            
            HStack {
                Text("Total Budget")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text(total.formatted(.currency(code: "USD")))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(Color.brandPrimary)
                    .contentTransition(.numericText())
            }
            // v2.4: Total accessible with spoken currency
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total available budget: \(AccessibilityFormatters.spokenCurrency(total))")
            .accessibilityAddTraits(.isSummaryElement)
        }
    }
    
    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                HapticService.play(.warning)
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Label("Delete Budget", systemImage: "trash")
                    Spacer()
                }
            }
            .accessibilityLabel("Delete budget")
            .accessibilityHint("Double tap to permanently delete this budget")
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        selectedCategory != nil && amount > 0 && carryOver >= 0
    }

    // MARK: - Actions

    private func deleteBudget() {
        context.delete(budget)

        do {
            try context.save()
            HapticService.play(.success)
            let categoryName = budget.category?.name ?? "budget"
            AccessibilityAnnouncement.announce("\(categoryName) budget deleted")
            dismiss()
        } catch {
            HapticService.play(.error)
            AccessibilityAnnouncement.announce("Failed to delete budget")
            print("Failed to delete budget: \(error)")
        }
    }

    private func save() {
        guard let category = selectedCategory, amount > 0, carryOver >= 0 else { return }

        budget.planned = amount
        budget.carryOver = carryOver
        budget.category = category      // v2.8
        budget.month = selectedMonth     // v2.8

        do {
            try context.save()
            HapticService.play(.success)
            // v2.4: Announce save
            AccessibilityAnnouncement.announce("\(category.name) budget updated")
            dismiss()
        } catch {
            HapticService.play(.error)
            // v2.4: Announce failure
            AccessibilityAnnouncement.announce("Failed to save budget")
            print("Failed to save budget: \(error)")
        }
    }
}

// MARK: - Preview

#Preview("Edit Budget") {
    let container = try! ModelContainer(
        for: Budget.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    let groceries = Category(
        name: "Groceries",
        icon: "cart.fill",
        colorHex: "10B981",
        isIncome: false
    )
    context.insert(groceries)
    
    let budget = Budget(
        month: Date(),
        planned: 500.0,
        category: groceries,
        financeType: .personal
    )
    context.insert(budget)
    
    return NavigationStack {
        EditBudgetView(budget: budget)
    }
    .modelContainer(container)
}
