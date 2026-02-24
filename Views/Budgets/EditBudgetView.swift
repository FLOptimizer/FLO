//  EditBudgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5 - Dynamic Type verification: lineLimit + minimumScaleFactor on all text
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
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
     
    let budget: Budget
     
    @State private var amount: String
    @State private var carryOver: String
    @State private var viewAppeared = false
                     
    init(budget: Budget) {
        self.budget = budget
        _amount = State(initialValue: String(format: "%.2f", budget.planned))
        _carryOver = State(initialValue: String(format: "%.2f", budget.carryOver))
    }
     
    var body: some View {
        NavigationStack {
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
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        HapticService.play(.light)
                        dismiss()
                    }
                    // v2.4: VoiceOver
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Double tap to discard changes")
                }
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
    }
    
    // MARK: - Sections
    
    private var categorySection: some View {
        Section("Category") {
            if let category = budget.category {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color(flowHex: category.colorHex))
                        .frame(width: 32)
                        // v2.4: Decorative
                        .accessibilityHidden(true)
                    
                    Text(category.name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    Spacer()
                    
                    Text(budget.financeType == .business ? "🏢" : "👤")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                // v2.4: Combined accessible label
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(category.name), \(budget.financeType == .business ? "Business" : "Personal") budget")
            }
        }
    }
    
    private var monthSection: some View {
        Section("Month") {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.brandPrimary)
                    // v2.4: Decorative
                    .accessibilityHidden(true)
                
                Text(budget.month, format: .dateTime.month(.wide).year())
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            // v2.4: VoiceOver
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Budget month: \(budget.month.formatted(.dateTime.month(.wide).year()))")
        }
    }
    
    private var amountSection: some View {
        Section("Budget Amount") {
            HStack {
                Text("$")
                    .font(.title2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                    // v2.4: Decorative
                    .accessibilityHidden(true)
                
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    // v2.4: VoiceOver
                    .accessibilityLabel("Budget amount in dollars")
                    .accessibilityHint("Enter the monthly spending limit for this category")
            }
            .padding(.vertical, 4)
        }
    }
    
    private var carryOverSection: some View {
        Section {
            HStack {
                Text("$")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.secondary)
                    // v2.4: Decorative
                    .accessibilityHidden(true)
                
                TextField("0.00", text: $carryOver)
                    .keyboardType(.decimalPad)
                    // v2.4: VoiceOver
                    .accessibilityLabel("Carry over amount in dollars")
                    .accessibilityHint("Unused funds rolled over from the previous month")
            }
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
            let plannedAmount = Double(amount) ?? 0
            let carryOverAmount = Double(carryOver) ?? 0
            let total = plannedAmount + carryOverAmount
            
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
    
    // MARK: - Validation
    
    private var isValid: Bool {
        guard !amount.isEmpty else { return false }
        guard let amt = Double(amount), amt > 0 else { return false }
        guard let carry = Double(carryOver), carry >= 0 else { return false }
        return true
    }
     
    // MARK: - Actions
    
    private func save() {
        guard let amt = Double(amount), amt > 0,
              let carry = Double(carryOver), carry >= 0 else {
            return
        }
         
        budget.planned = amt
        budget.carryOver = carry
        
        do {
            try context.save()
            HapticService.play(.success)
            // v2.4: Announce save
            let categoryName = budget.category?.name ?? "budget"
            AccessibilityAnnouncement.announce("\(categoryName) budget updated")
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
    
    return EditBudgetView(budget: budget)
        .modelContainer(container)
}
