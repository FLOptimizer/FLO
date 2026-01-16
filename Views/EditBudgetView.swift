//  EditBudgetView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.3 - Enhanced haptics and micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.3:
//  ✅ Comprehensive haptic preparation
//  ✅ Section entrance animations
//  ✅ Value content transitions
//  ✅ Cancel/save button haptics
//
//  PREVIOUS (v2.2):
//  - Positive amount validation, haptic feedback

import SwiftUI
import SwiftData
  
struct EditBudgetView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
     
    let budget: Budget
     
    @State private var amount: String
    @State private var carryOver: String
    @State private var viewAppeared = false
    
    // Haptic Generators
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()
     
    init(budget: Budget) {
        self.budget = budget
        _amount = State(initialValue: String(format: "%.2f", budget.planned))
        _carryOver = State(initialValue: String(format: "%.2f", budget.carryOver))
    }
     
    var body: some View {
        NavigationStack {
            Form {
                categorySection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05), value: viewAppeared)
                
                monthSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: viewAppeared)
                
                amountSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: viewAppeared)
                
                carryOverSection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: viewAppeared)
                
                summarySection
                    .opacity(viewAppeared ? 1 : 0)
                    .offset(y: viewAppeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: viewAppeared)
            }
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        impactLight.impactOccurred()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        impactMedium.impactOccurred()
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                prepareHaptics()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    viewAppeared = true
                }
            }
        }
    }
    
    // MARK: - Haptic Preparation
    
    private func prepareHaptics() {
        selectionFeedback.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Sections
    
    private var categorySection: some View {
        Section("Category") {
            if let category = budget.category {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundStyle(Color(flowHex: category.colorHex))
                        .frame(width: 32)
                    
                    Text(category.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(budget.financeType == .business ? "🏢" : "👤")
                }
            }
        }
    }
    
    private var monthSection: some View {
        Section("Month") {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(AppConstants.primaryColor)
                Text(budget.month, format: .dateTime.month(.wide).year())
                    .font(.headline)
            }
        }
    }
    
    private var amountSection: some View {
        Section("Budget Amount") {
            HStack {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                TextField("0.00", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(.title2)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var carryOverSection: some View {
        Section {
            HStack {
                Text("$")
                    .foregroundStyle(.secondary)
                
                TextField("0.00", text: $carryOver)
                    .keyboardType(.decimalPad)
            }
        } header: {
            Text("Carry Over from Previous Month")
        } footer: {
            Text("Unused funds from previous months")
                .font(.caption)
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
                Spacer()
                Text(total.formatted(.currency(code: "USD")))
                    .font(.headline)
                    .foregroundStyle(AppConstants.primaryColor)
                    .contentTransition(.numericText())
            }
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
            notificationFeedback.notificationOccurred(.success)
            dismiss()
        } catch {
            notificationFeedback.notificationOccurred(.error)
            print("❌ Failed to save budget: \(error)")
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
