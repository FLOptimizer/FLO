//  RecentTransactionsCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1.1 - Accessibility: text clipping prevention for Dynamic Type
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  FEATURES:
//  ✅ Compact transaction row display
//  ✅ Mode-aware theming
//  ✅ Icon-only finance type indicator
//  ✅ Navigation to transaction detail
//  ✅ Full accessibility support
//
//  CHANGES v1.1 - Accessibility Audit:
//  ✅ Header list icon hidden from VoiceOver
//  ✅ Header text marked with isHeader trait
//  ✅ Category icon hidden (info in label)
//  ✅ Finance type icon hidden (info in label)
//  ✅ Bullet separators hidden from VoiceOver
//  ✅ Transaction row hint for navigation
//

import SwiftUI
import SwiftData

struct RecentTransactionsCard: View {
    let transactions: [Transaction]
    let financeMode: FinanceMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundStyle(modeColor)
                    .accessibilityHidden(true)
                
                Text(headerTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                NavigationLink {
                    TransactionListView()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("View all transactions")
            }
            .padding()
            
            Divider()
            
            // Transaction Items
            VStack(spacing: 0) {
                ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                    NavigationLink {
                        EditTransactionView(transaction: transaction)
                    } label: {
                        TransactionRowCompact(transaction: transaction)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if transaction.id != transactions.last?.id {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private var modeColor: Color {
        financeMode.color
    }
    
    private var headerTitle: String {
        switch financeMode {
        case .business: return "Recent Business"
        case .personal: return "Recent Personal"
        case .all: return "Recent Transactions"
        }
    }
}

// MARK: - Transaction Row Compact

struct TransactionRowCompact: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Category Icon - colorful based on category
            categoryIcon
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // Finance type badge (icon only)
                    Image(systemName: transaction.financeType == .business ? "briefcase.fill" : "person.fill")
                        .font(.caption2)
                        .foregroundStyle(transaction.financeType == .business ? Color.businessColor : Color.personalColor)
                        .accessibilityHidden(true)
                    
                    if let category = transaction.category {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    
                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Amount - use abs() to prevent double minus signs
            HStack(spacing: 2) {
                Text(transaction.isIncome ? "+" : "-")
                    .font(.subheadline)
                    .foregroundStyle(transaction.isIncome ? Color.incomeGreen : Color.expenseRed)
                +
                Text(abs(transaction.amount), format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(transaction.isIncome ? Color.incomeGreen : Color.expenseRed)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transaction.merchantName), \(transaction.financeType == .business ? "business" : "personal"), \(transaction.isIncome ? "income" : "expense"), \(transaction.amount, format: .currency(code: "USD")), \(transaction.date, style: .date)")
        .accessibilityHint("Double tap to edit transaction")
    }
    
    @ViewBuilder
    private var categoryIcon: some View {
        if let category = transaction.category {
            // Colorful category icon
            ZStack {
                Circle()
                    .fill(Color(flowHex: category.colorHex).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: category.icon)
                    .foregroundStyle(Color(flowHex: category.colorHex))
                    .font(.caption)
            }
            .accessibilityHidden(true)
        } else {
            // Default income/expense icon
            ZStack {
                Circle()
                    .fill(transaction.isIncome ? Color.incomeGreen.opacity(0.15) : Color.expenseRed.opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.isIncome ? "arrow.down" : "arrow.up")
                    .foregroundStyle(transaction.isIncome ? Color.incomeGreen : Color.expenseRed)
                    .font(.caption)
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Preview

#Preview("Recent Transactions") {
    RecentTransactionsCardPreview()
}

private struct RecentTransactionsCardPreview: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Transaction.self, Category.self,
            configurations: config
        )
        
        let context = container.mainContext
        
        let groceries = Category(name: "Groceries", icon: "cart.fill", colorHex: "22C55E", isIncome: false)
        let clientPayment = Category(name: "Client Payment", icon: "dollarsign.circle.fill", colorHex: "14B8A6", isIncome: true)
        context.insert(groceries)
        context.insert(clientPayment)
        
        let transactions = [
            Transaction(amount: 5000, date: .now, note: "Website Design", isIncome: true, merchantName: "Acme Corp", category: clientPayment, financeType: .business, hasReceipt: true),
            Transaction(amount: 125.50, date: .now, note: "Office Supplies", isIncome: false, merchantName: "Staples", financeType: .business, hasReceipt: false),
            Transaction(amount: 42.99, date: .now, note: "Weekly Shopping", isIncome: false, merchantName: "Whole Foods", category: groceries, financeType: .personal, hasReceipt: true)
        ]
        
        transactions.forEach { context.insert($0) }
        
        return NavigationStack {
            RecentTransactionsCard(transactions: transactions, financeMode: .all)
                .padding()
        }
        .modelContainer(container)
    }
}
