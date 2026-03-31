//  RecentTransactionsView.swift (Watch)
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Recent Transactions for Apple Watch
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  TARGET MEMBERSHIP:
//  ✅ FLOWatch (watchOS app target)
//
//  Read-only list of recent transactions.
//  Available to all tiers.
//

import SwiftUI

struct RecentTransactionsView: View {
    
    @EnvironmentObject var session: WatchSessionManager
    
    private var transactions: [WatchTransaction] {
        session.snapshot?.recentTransactions ?? []
    }
    
    var body: some View {
        List {
            if transactions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("No recent transactions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(transactions) { txn in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Image(systemName: txn.categoryIcon)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            
                            Text(txn.merchantName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(txn.formattedAmount)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(txn.isIncome ? .green : .primary)
                        }
                        
                        HStack(spacing: 6) {
                            Text(txn.categoryName)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            if txn.isBusiness {
                                Text("BIZ")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(2)
                            }
                            
                            Spacer()
                            
                            Text(txn.date, style: .date)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Transactions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        RecentTransactionsView()
            .environmentObject(WatchSessionManager.shared)
    }
}
