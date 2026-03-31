//  TransactionRow.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 2.5 - Build 10: Monospaced tabular figures for amounts
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v2.5 - Build 10:
//  ✅ UPDATED: Amount display uses monospaced design + monospacedDigit for alignment
//
//  CHANGES v2.4 - VoiceOver Audit:
//  ✅ ADDED: Category icon hidden from VoiceOver (decorative, text describes it)
//  ✅ ADDED: Receipt indicator icon hidden (accessibilityLabel on container already mentions "receipt attached")
//  ✅ VERIFIED: Currency amounts already have spoken format via AccessibilityFormatters.spokenCurrency
//  ✅ VERIFIED: Row already combines children into single VoiceOver element
//
//  CHANGES v2.3 - Dynamic Type Verification:
//  ✅ FIXED: Display name text already had lineLimit (verified)
//  ✅ FIXED: Transfer type badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Category badge text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Amount text missing lineLimit + minimumScaleFactor
//  ✅ FIXED: Date text missing lineLimit + minimumScaleFactor
//
//  CHANGES v2.1:
//  ✅ ADDED: accessibilityHint for row interaction guidance
//  ✅ ADDED: accessibilityValue with spoken currency amount
//  ✅ IMPROVED: accessibilityLabel uses AccessibilityFormatters.spokenCurrency
//  ✅ ADDED: Decorative category icon hidden (parent combine handles)
//
//  CHANGES v2.0:
//  ✅ Finance type badge now shows ICON ONLY (no text)
//  ✅ Migrated animations to FLOAnimation presets
//  ✅ Colorful category icons maintained
//  ✅ Improved visual hierarchy
//  ✅ Smaller, cleaner badge design
//
//  CHANGES v1.5:
//  ✅ Icon scale animation on appear
//  ✅ Amount value animation with contentTransition
//  ✅ Badge entrance animations
//  ✅ Receipt indicator pulse effect
//  ✅ Improved visual hierarchy with subtle shadows
//

import SwiftUI
import SwiftData

struct TransactionRow: View {
    let transaction: Transaction
    
    // Animation states
    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.8
    
    // Safe property access to prevent crash on deleted transactions
    private var safeFinanceType: Transaction.FinanceType {
        guard transaction.modelContext != nil else {
            return .personal
        }
        return transaction.financeType
    }
    
    private var isTransactionValid: Bool {
        transaction.modelContext != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
                .scaleEffect(iconScale)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isTransactionValid ? transaction.displayName : "")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    // v2.2: Transfer type badge
                    if isTransactionValid && transaction.isTransfer, let tType = transaction.transferType {
                        Text(tType.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(Color(hex: tType.colorHex))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: tType.colorHex).opacity(0.12))
                            .clipShape(Capsule())
                            .opacity(appeared ? 1 : 0.001)
                            .offset(x: appeared ? 0 : -5)
                    }
                    
                    if isTransactionValid, let category = transaction.category {
                        categoryBadge(category)
                            .opacity(appeared ? 1 : 0.001)
                            .offset(x: appeared ? 0 : -5)
                    }
                    
                    // Icon-only finance type badge
                    financeTypeIcon
                        .opacity(appeared ? 1 : 0.001)
                        .offset(x: appeared ? 0 : -5)
                    
                    if isTransactionValid && transaction.hasReceipt {
                        receiptIndicator
                            .opacity(appeared ? 1 : 0.001)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .accessibilityHidden(true)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(isTransactionValid ? transaction.formattedAmount : "")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(amountColor)
                    .contentTransition(.numericText())
                
                if isTransactionValid {
                    Text(transaction.date, style: .date)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(appeared ? 1 : 0.001)
            .offset(x: appeared ? 0 : 10)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        // v2.1: Add hint and value for better VoiceOver experience
        .accessibilityValue(isTransactionValid ? AccessibilityFormatters.spokenCurrency(transaction.amount) : "")
        .accessibilityHint("Double tap to edit")
        .onAppear {
            withAnimation(FLOAnimation.standard) {
                appeared = true
                iconScale = 1.0
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var categoryIcon: some View {
        if isTransactionValid && transaction.isTransfer {
            // Transfer icon - distinct purple styling
            let transferColor = Color(hex: transaction.transferType?.colorHex ?? "8B5CF6")
            Image(systemName: transaction.transferType?.icon ?? "arrow.left.arrow.right.circle.fill")
                .font(.title3)
                .foregroundStyle(transferColor)
                .frame(width: 40, height: 40)
                .background(transferColor.opacity(0.12))
                .clipShape(Circle())
                .shadow(color: transferColor.opacity(0.15), radius: 2, x: 0, y: 1)
        } else if isTransactionValid, let category = transaction.category {
            // Colorful category icon
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: category.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(flowHex: category.colorHex).opacity(0.12))
                .clipShape(Circle())
                .shadow(color: Color(flowHex: category.colorHex).opacity(0.15), radius: 2, x: 0, y: 1)
        } else {
            // Default income/expense icon
            let isIncome = isTransactionValid ? transaction.isIncome : false
            Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(isIncome ? Color.incomeGreen : Color.expenseRed)
                .frame(width: 40, height: 40)
                .background(isIncome ? Color.incomeGreen.opacity(0.12) : Color.expenseRed.opacity(0.12))
                .clipShape(Circle())
                .shadow(color: (isIncome ? Color.incomeGreen : Color.expenseRed).opacity(0.15), radius: 2, x: 0, y: 1)
        }
    }
    
    @ViewBuilder
    private func categoryBadge(_ category: Category) -> some View {
        Text(category.name)
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color(flowHex: category.colorHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(flowHex: category.colorHex).opacity(0.12))
            .clipShape(Capsule())
    }
    
    /// Icon-only finance type indicator (no text)
    @ViewBuilder
    private var financeTypeIcon: some View {
        let financeType = safeFinanceType
        Image(systemName: financeType.icon)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(financeTypeColor)
            .frame(width: 20, height: 20)
            .background(financeTypeColor.opacity(0.12))
            .clipShape(Circle())
            .accessibilityLabel(financeType.displayName)
    }
    
    @ViewBuilder
    private var receiptIndicator: some View {
        Image(systemName: "doc.text.fill")
            .font(.caption2)
            .foregroundStyle(Color.brandPrimaryText)
            .frame(width: 20, height: 20)
            .background(Color.brandPrimary.opacity(0.12))
            .clipShape(Circle())
            .accessibilityLabel("Has receipt")
    }
    
    // MARK: - Computed Properties
    
    private var amountColor: Color {
        guard isTransactionValid else { return .primary }
        if transaction.isTransfer {
            return Color(hex: transaction.transferType?.colorHex ?? "8B5CF6")
        }
        return transaction.isIncome ? Color.incomeGreen : Color.expenseRed
    }
    
    private var financeTypeColor: Color {
        switch safeFinanceType {
        case .business:
            return .businessColor
        case .personal:
            return .personalColor
        }
    }
    
    private var accessibilityLabel: String {
        guard isTransactionValid else { return "Transaction" }
        
        // v2.2: Handle transfer accessibility
        if transaction.isTransfer {
            let spokenAmount = AccessibilityFormatters.spokenCurrency(transaction.amount)
            let typeLabel = transaction.transferType?.displayName ?? "Transfer"
            return "\(typeLabel), \(spokenAmount), \(transaction.merchantName)"
        }
        
        // v2.1: Use spoken currency format for VoiceOver
        let spokenAmount = AccessibilityFormatters.spokenCurrency(transaction.amount)
        var label = "\(transaction.isIncome ? "Income" : "Expense"), \(spokenAmount)"
        
        if !transaction.merchantName.isEmpty {
            label += ", at \(transaction.merchantName)"
        }
        
        if let category = transaction.category {
            label += ", \(category.name)"
        }
        
        label += ", \(safeFinanceType.displayName)"
        
        if transaction.hasReceipt {
            label += ", receipt attached"
        }
        
        label += ", \(AccessibilityFormatters.spokenDate(transaction.date))"
        
        return label
    }
}

// MARK: - Preview

#Preview("Income with Receipt") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let clientPayment = Category(
        name: "Client Payment",
        icon: "dollarsign.circle.fill",
        colorHex: "14B8A6",
        isIncome: true
    )
    container.mainContext.insert(clientPayment)
    
    let transaction = Transaction(
        amount: 5000,
        date: .now,
        note: "Website Design Project",
        isIncome: true,
        merchantName: "Acme Corp",
        category: clientPayment,
        financeType: .business,
        hasReceipt: true
    )
    container.mainContext.insert(transaction)
    
    return List {
        TransactionRow(transaction: transaction)
    }
    .modelContainer(container)
}

#Preview("Expense with Category") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let supplies = Category(
        name: "Office Supplies",
        icon: "pencil.circle.fill",
        colorHex: "F59E0B",
        isIncome: false
    )
    container.mainContext.insert(supplies)
    
    let transaction = Transaction(
        amount: 125.50,
        date: .now,
        note: "Pens, Paper, Binders",
        isIncome: false,
        merchantName: "Staples",
        category: supplies,
        financeType: .business,
        hasReceipt: false
    )
    container.mainContext.insert(transaction)
    
    return List {
        TransactionRow(transaction: transaction)
    }
    .modelContainer(container)
}

#Preview("Personal Expense") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let groceries = Category(
        name: "Groceries",
        icon: "cart.fill",
        colorHex: "10B981",
        isIncome: false
    )
    container.mainContext.insert(groceries)
    
    let transaction = Transaction(
        amount: 42.99,
        date: .now,
        note: "Weekly shopping",
        isIncome: false,
        merchantName: "Whole Foods",
        category: groceries,
        financeType: .personal,
        hasReceipt: true
    )
    container.mainContext.insert(transaction)
    
    return List {
        TransactionRow(transaction: transaction)
    }
    .modelContainer(container)
}

#Preview("Multiple Transactions") {
    let container = try! ModelContainer(
        for: Transaction.self, Category.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let context = container.mainContext
    
    // Categories with different colors
    let clientPayment = Category(name: "Client Payment", icon: "dollarsign.circle.fill", colorHex: "14B8A6", isIncome: true)
    let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "10B981", isIncome: false)
    let supplies = Category(name: "Office Supplies", icon: "pencil.circle.fill", colorHex: "F59E0B", isIncome: false)
    let travel = Category(name: "Travel", icon: "airplane", colorHex: "8B5CF6", isIncome: false)
    let utilities = Category(name: "Utilities", icon: "bolt.fill", colorHex: "EF4444", isIncome: false)
    
    [clientPayment, groceries, supplies, travel, utilities].forEach { context.insert($0) }
    
    let transactions = [
        Transaction(amount: 5000, date: .now, note: "Website Design", isIncome: true, merchantName: "Acme Corp", category: clientPayment, financeType: .business, hasReceipt: true),
        Transaction(amount: 42.99, date: .now, note: "Weekly Shopping", isIncome: false, merchantName: "Whole Foods", category: groceries, financeType: .personal, hasReceipt: false),
        Transaction(amount: 125.50, date: .now, note: "Office Supplies", isIncome: false, merchantName: "Staples", category: supplies, financeType: .business, hasReceipt: true),
        Transaction(amount: 350, date: .now, note: "Flight to NYC", isIncome: false, merchantName: "Delta", category: travel, financeType: .business, hasReceipt: true),
        Transaction(amount: 89.50, date: .now, note: "Electric Bill", isIncome: false, merchantName: "Power Co", category: utilities, financeType: .personal, hasReceipt: false)
    ]
    
    transactions.forEach { context.insert($0) }
    
    return List {
        ForEach(transactions) { transaction in
            TransactionRow(transaction: transaction)
        }
    }
    .modelContainer(container)
}
