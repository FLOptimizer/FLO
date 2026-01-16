//  TransactionRow.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.5 - Enhanced micro-animations
//  Copyright © 2025 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.5:
//  ✅ Icon scale animation on appear
//  ✅ Amount value animation with contentTransition
//  ✅ Badge entrance animations
//  ✅ Receipt indicator pulse effect
//  ✅ Improved visual hierarchy with subtle shadows
//
//  PREVIOUS FIXES:
//  - Fixed expense color to use expenseRed
//  - Fixed crash when accessing financeType on deleted transaction
//  - Added safeFinanceType computed property with fallback

import SwiftUI
import SwiftData

struct TransactionRow: View {
    let transaction: Transaction
    
    // Animation states
    @State private var appeared = false
    @State private var iconScale: CGFloat = 0.8
    
    // v1.3: Safe property access to prevent crash on deleted transactions
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isTransactionValid ? transaction.displayName : "")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if isTransactionValid, let category = transaction.category {
                        categoryBadge(category)
                            .opacity(appeared ? 1 : 0)
                            .offset(x: appeared ? 0 : -5)
                    }
                    
                    financeTypeBadge
                        .opacity(appeared ? 1 : 0)
                        .offset(x: appeared ? 0 : -5)
                    
                    if isTransactionValid && transaction.hasReceipt {
                        receiptIndicator
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.5)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(isTransactionValid ? transaction.formattedAmount : "")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                
                if isTransactionValid {
                    Text(transaction.date, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(x: appeared ? 0 : 10)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
                iconScale = 1.0
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private var categoryIcon: some View {
        if isTransactionValid, let category = transaction.category {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(Color(flowHex: category.colorHex))
                .frame(width: 40, height: 40)
                .background(Color(flowHex: category.colorHex).opacity(0.1))
                .clipShape(Circle())
                .shadow(color: Color(flowHex: category.colorHex).opacity(0.2), radius: 2, x: 0, y: 1)
        } else {
            let isIncome = isTransactionValid ? transaction.isIncome : false
            Image(systemName: isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .font(.title3)
                .foregroundStyle(isIncome ? Color.incomeGreen : Color.expenseRed)
                .frame(width: 40, height: 40)
                .background(isIncome ? Color.incomeGreen.opacity(0.1) : Color.expenseRed.opacity(0.1))
                .clipShape(Circle())
                .shadow(color: (isIncome ? Color.incomeGreen : Color.expenseRed).opacity(0.2), radius: 2, x: 0, y: 1)
        }
    }
    
    @ViewBuilder
    private func categoryBadge(_ category: Category) -> some View {
        Text(category.name)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(Color(flowHex: category.colorHex))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(flowHex: category.colorHex).opacity(0.15))
            .clipShape(Capsule())
            .lineLimit(1)
    }
    
    @ViewBuilder
    private var financeTypeBadge: some View {
        let financeType = safeFinanceType
        HStack(spacing: 3) {
            Image(systemName: financeType.icon)
                .font(.system(size: 9))
            Text(financeType.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(financeTypeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(financeTypeColor.opacity(0.15))
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var receiptIndicator: some View {
        Image(systemName: "doc.text.fill")
            .font(.system(size: 10))
            .foregroundStyle(Color.brandPrimary)
            .padding(4)
            .background(Color.brandPrimary.opacity(0.15))
            .clipShape(Circle())
            .shadow(color: Color.brandPrimary.opacity(0.2), radius: 1, x: 0, y: 1)
    }
    
    // MARK: - Computed Properties
    
    private var amountColor: Color {
        guard isTransactionValid else { return .primary }
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
        
        var label = "\(transaction.isIncome ? "Income" : "Expense") of \(transaction.formattedAmount)"
        
        if !transaction.merchantName.isEmpty {
            label += " at \(transaction.merchantName)"
        }
        
        if let category = transaction.category {
            label += ", category \(category.name)"
        }
        
        label += ", \(safeFinanceType.displayName)"
        
        if transaction.hasReceipt {
            label += ", has receipt"
        }
        
        label += ", on \(transaction.date.formatted(date: .long, time: .omitted))"
        
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
