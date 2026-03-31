//  QuickExpenseView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Removed iOS-only TextField modifiers for watchOS
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  UX DESIGN:
//  Goal: Add an expense in under 5 seconds.
//  Flow: Amount → Category → Business/Personal → Confirm
//
//  AMOUNT ENTRY:
//  - Preset grid: $5, $10, $20, $50, $100, Custom
//  - Custom opens system decimal pad
//  - Presets are the fastest path (single tap)
//
//  CATEGORY PICKER:
//  - Shows top 6 most-used categories from snapshot
//  - "Other" option files as uncategorized (recategorize on iPhone)
//  - Vertical list with icons for fast scanning
//
//  BUSINESS/PERSONAL:
//  - Single toggle, defaults to most common from recent history
//
//  CONFIRMATION:
//  - Shows amount + category + type
//  - Checkmark button sends to iPhone
//  - Haptic feedback on success
//

import SwiftUI
import WatchKit

struct QuickExpenseView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    
    // MARK: - State
    
    @State private var currentStep: ExpenseStep = .amount
    @State private var selectedAmount: Double = 0
    @State private var customAmount: String = ""
    @State private var selectedCategory: WatchCategory?
    @State private var isBusiness = false
    @State private var note: String = ""
    @State private var isSending = false
    @State private var showSuccess = false
    
    // MARK: - Preset Amounts
    
    private let presetAmounts: [(String, Double)] = [
        ("$5", 5),
        ("$10", 10),
        ("$20", 20),
        ("$50", 50),
        ("$100", 100),
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .amount:
                    amountView
                case .category:
                    categoryView
                case .confirm:
                    confirmView
                case .success:
                    successView
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Step 1: Amount
    
    private var amountView: some View {
        ScrollView {
            VStack(spacing: 6) {
                // Preset amount grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 6) {
                    ForEach(presetAmounts, id: \.1) { label, amount in
                        Button(action: {
                            selectedAmount = amount
                            currentStep = .category
                            WKInterfaceDevice.current().play(.click)
                        }) {
                            Text(label)
                                .font(.body)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Custom amount button
                    Button(action: {
                        selectedAmount = 0
                        currentStep = .category // Will use custom entry
                    }) {
                        Text("Other")
                            .font(.body)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                // Custom amount entry (always visible for flexibility)
                HStack {
                    Text("$")
                        .foregroundColor(.secondary)
                    TextField("0.00", text: $customAmount)
                        // Note: keyboardType and multilineTextAlignment are iOS-only
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal, 4)
                
                if !customAmount.isEmpty, let amount = Double(customAmount), amount > 0 {
                    Button(action: {
                        selectedAmount = amount
                        currentStep = .category
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        Label("Continue", systemImage: "arrow.right")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.top, 4)
        }
    }
    
    // MARK: - Step 2: Category
    
    private var categoryView: some View {
        ScrollView {
            VStack(spacing: 4) {
                // Amount header
                Text(formatCurrency(selectedAmount))
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.bottom, 4)
                
                // Top categories from snapshot
                let categories = session.snapshot?.quickCategories ?? []
                
                ForEach(categories) { cat in
                    Button(action: {
                        selectedCategory = cat
                        isBusiness = cat.isBusiness
                        currentStep = .confirm
                        WKInterfaceDevice.current().play(.click)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: cat.icon)
                                .font(.caption)
                                .frame(width: 20)
                                .foregroundColor(.blue)
                            
                            Text(cat.name)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            if cat.isBusiness {
                                Text("BIZ")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(3)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // "Other" fallback
                Button(action: {
                    selectedCategory = nil
                    currentStep = .confirm
                    WKInterfaceDevice.current().play(.click)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .frame(width: 20)
                            .foregroundColor(.gray)
                        
                        Text("Other")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // Back button
                Button(action: {
                    currentStep = .amount
                }) {
                    Text("Back")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Step 3: Confirm
    
    private var confirmView: some View {
        VStack(spacing: 8) {
            // Amount
            Text(formatCurrency(selectedAmount))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.red)
            
            // Category
            HStack(spacing: 4) {
                if let cat = selectedCategory {
                    Image(systemName: cat.icon)
                        .font(.caption2)
                    Text(cat.name)
                        .font(.caption)
                } else {
                    Text("Uncategorized")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Business/Personal toggle
            Toggle(isOn: $isBusiness) {
                Text(isBusiness ? "Business" : "Personal")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .tint(.orange)
            .padding(.horizontal, 4)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                // Cancel
                Button(action: {
                    resetForm()
                    WKInterfaceDevice.current().play(.click)
                }) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // Confirm
                Button(action: {
                    submitExpense()
                }) {
                    if isSending {
                        ProgressView()
                            .frame(width: 44, height: 44)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                            .frame(width: 44, height: 44)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
        .padding()
    }
    
    // MARK: - Step 4: Success
    
    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)
            
            Text("Expense Saved")
                .font(.headline)
            
            Text(formatCurrency(selectedAmount))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Add Another") {
                resetForm()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
        .onAppear {
            // Auto-return to amount screen after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if currentStep == .success {
                    resetForm()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func submitExpense() {
        isSending = true
        
        let payload = WatchCommand.AddExpensePayload(
            amount: selectedAmount,
            categoryId: selectedCategory?.id ?? UUID(), // UUID() for uncategorized
            isBusiness: isBusiness,
            note: nil,
            date: Date()
        )
        
        Task {
            let success = await session.sendCommand(.addExpense(payload))
            
            isSending = false
            
            if success {
                WKInterfaceDevice.current().play(.success)
                currentStep = .success
            } else {
                WKInterfaceDevice.current().play(.failure)
                // Stay on confirm screen so user can retry
            }
        }
    }
    
    private func resetForm() {
        currentStep = .amount
        selectedAmount = 0
        customAmount = ""
        selectedCategory = nil
        isBusiness = false
        note = ""
        isSending = false
        showSuccess = false
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }
}

// MARK: - Step Enum

private enum ExpenseStep {
    case amount
    case category
    case confirm
    case success
}

#Preview {
    QuickExpenseView()
        .environmentObject(WatchSessionManager.shared)
}
