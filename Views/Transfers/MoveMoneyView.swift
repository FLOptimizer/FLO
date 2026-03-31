//  MoveMoneyView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.0 - Move Money / Transfers View
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Main view for managing transfers between accounts.
//  Transfers are NOT income or expenses — they're movement of money.
//
//  FEATURES:
//  ✅ Balance summary header (Business vs Personal)
//  ✅ YTD equity metrics (Draws, Contributions)
//  ✅ Filter by transfer type
//  ✅ Swipe actions (edit, delete)
//  ✅ Empty state with illustration
//  ✅ Full haptics and animations
//  ✅ Complete VoiceOver accessibility
//  ✅ Dark mode support
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct MoveMoneyView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Transfer.date, order: .reverse) private var allTransfers: [Transfer]
    @Query(sort: \Account.name) private var accounts: [Account]
    
    // MARK: - State
    
    @State private var selectedFilter: TransferFilter = .all
    @State private var showingAddTransfer = false
    @State private var transferToEdit: Transfer?
    @State private var transferToDelete: Transfer?
    @State private var showDeleteConfirmation = false
    @State private var viewAppeared = false
    @State private var headerExpanded = true
    
    // MARK: - Computed Properties
    
    private var filteredTransfers: [Transfer] {
        switch selectedFilter {
        case .all:
            return allTransfers
        case .internal:
            return allTransfers.filter { $0.transferType == .internal }
        case .draws:
            return allTransfers.filter { $0.transferType == .ownersDraw }
        case .contributions:
            return allTransfers.filter { $0.transferType == .capitalContribution }
        case .debtPayments:
            return allTransfers.filter { $0.transferType == .debtPayment }
        case .taxPayments:
            return allTransfers.filter { $0.transferType == .taxPayment }
        }
    }
    
    private var businessBalance: Double {
        accounts
            .filter { $0.financeType == .business && $0.isActive }
            .reduce(0) { $0 + $1.currentBalance }
    }
    
    private var personalBalance: Double {
        accounts
            .filter { $0.financeType == .personal && $0.isActive }
            .reduce(0) { $0 + $1.currentBalance }
    }
    
    private var ytdDraws: Double {
        TransferService.shared.calculateYTDDraws(context: context)
    }
    
    private var ytdContributions: Double {
        TransferService.shared.calculateYTDContributions(context: context)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Section 1: Balance Summary Header
                    balanceSummaryHeader
                    
                    // Section 2: Filter Pills
                    filterPills
                    
                    // Section 3: Transfer List or Empty State
                    if filteredTransfers.isEmpty {
                        emptyState
                    } else {
                        transferList
                    }
                }
                .padding(.bottom, 100)
            }
            .background(Color.floSystemGroupedBackground)
            .navigationTitle("Move Money")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticService.play(.light)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityHint("Returns to previous screen")
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.play(.medium)
                        showingAddTransfer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.brandPrimary)
                    }
                    .accessibilityLabel("New transfer")
                    .accessibilityHint("Create a new transfer between accounts")
                }
            }
            .sheet(isPresented: $showingAddTransfer) {
                AddTransferView()
            }
            .sheet(item: $transferToEdit) { transfer in
                EditTransferView(transfer: transfer)
            }
            .alert("Delete Transfer?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    transferToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let transfer = transferToDelete {
                        deleteTransfer(transfer)
                    }
                    transferToDelete = nil
                }
            } message: {
                if let transfer = transferToDelete {
                    Text("This will reverse the \(transfer.formattedAmount) transfer and restore account balances.")
                }
            }
            .onAppear {
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Move Money, \(allTransfers.count) transfers")
            }
        }
    }
    
    // MARK: - Balance Summary Header
    
    private var balanceSummaryHeader: some View {
        VStack(spacing: 12) {
            // Balance Cards Row
            HStack(spacing: 12) {
                // Business Balance
                balanceCard(
                    title: "Business",
                    balance: businessBalance,
                    icon: "briefcase.fill",
                    color: "#3B82F6"
                )
                
                // Personal Balance
                balanceCard(
                    title: "Personal",
                    balance: personalBalance,
                    icon: "person.fill",
                    color: "#10B981"
                )
            }
            
            // YTD Metrics Row (collapsible)
            if headerExpanded {
                HStack(spacing: 12) {
                    ytdMetricCard(
                        title: "YTD Draws",
                        amount: ytdDraws,
                        icon: "arrow.up.right.circle.fill",
                        color: "#8B5CF6"
                    )
                    
                    ytdMetricCard(
                        title: "YTD Contributions",
                        amount: ytdContributions,
                        icon: "arrow.down.left.circle.fill",
                        color: "#14B8A6"
                    )
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Expand/Collapse Button
            Button {
                HapticService.play(.light)
                withAnimation(FLOAnimation.standard) {
                    headerExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(headerExpanded ? "Show Less" : "Show YTD Metrics")
                        .font(.caption)
                        .fontWeight(.medium)
                    Image(systemName: headerExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .accessibilityLabel(headerExpanded ? "Collapse metrics" : "Expand metrics")
        }
        .padding()
        .background(Color.floSecondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : -20)
        .animation(FLOAnimation.standard.delay(0.1), value: viewAppeared)
    }
    
    private func balanceCard(title: String, balance: Double, icon: String, color: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Color(flowHex: color))
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text(balance, format: .currency(code: "USD"))
                .font(.title3)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(flowHex: color).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) balance: \(AccessibilityFormatters.spokenCurrency(balance))")
    }
    
    private func ytdMetricCard(title: String, amount: Double, icon: String, color: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color(flowHex: color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(amount, format: .currency(code: "USD"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.floTertiarySystemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(AccessibilityFormatters.spokenCurrency(amount))")
    }
    
    // MARK: - Filter Pills
    
    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TransferFilter.allCases) { filter in
                    filterPill(filter)
                }
            }
            .padding(.horizontal)
        }
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.2), value: viewAppeared)
    }
    
    private func filterPill(_ filter: TransferFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)
        
        return Button {
            HapticService.play(.selection)
            withAnimation(FLOAnimation.quick) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = filter.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(filter.displayName)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                if count > 0 && filter != .all {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brandPrimary : Color.floSecondarySystemGroupedBackground)
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .accessibilityLabel("\(filter.displayName), \(count) transfers")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    
    private func countForFilter(_ filter: TransferFilter) -> Int {
        switch filter {
        case .all:           return allTransfers.count
        case .internal:      return allTransfers.filter { $0.transferType == .internal }.count
        case .draws:         return allTransfers.filter { $0.transferType == .ownersDraw }.count
        case .contributions: return allTransfers.filter { $0.transferType == .capitalContribution }.count
        case .debtPayments:  return allTransfers.filter { $0.transferType == .debtPayment }.count
        case .taxPayments:   return allTransfers.filter { $0.transferType == .taxPayment }.count
        }
    }
    
    // MARK: - Transfer List
    
    private var transferList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filteredTransfers.enumerated()), id: \.element.id) { index, transfer in
                TransferRowView(transfer: transfer)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticService.play(.light)
                        transferToEdit = transfer
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            HapticService.play(.heavy)
                            transferToDelete = transfer
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            HapticService.play(.medium)
                            transferToEdit = transfer
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .opacity(viewAppeared ? 1 : 0.001)
                    .offset(x: viewAppeared ? 0 : 20)
                    .animation(
                        FLOAnimation.standard.delay(0.3 + Double(index) * 0.03),
                        value: viewAppeared
                    )
                
                if index < filteredTransfers.count - 1 {
                    Divider()
                        .padding(.leading, 72)
                }
            }
        }
        .background(Color.floSecondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandPrimary)
            }
            .scaleEffect(viewAppeared ? 1 : 0.5)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3), value: viewAppeared)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button {
                HapticService.play(.medium)
                showingAddTransfer = true
            } label: {
                Label("New Transfer", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.brandPrimary)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .accessibilityHint("Create your first transfer between accounts")
        }
        .padding(.vertical, 60)
        .opacity(viewAppeared ? 1 : 0.001)
        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:           return "No Transfers Yet"
        case .internal:      return "No Internal Transfers"
        case .draws:         return "No Owner's Draws"
        case .contributions: return "No Capital Contributions"
        case .debtPayments:  return "No Debt Payments"
        case .taxPayments:   return "No Tax Payments"
        }
    }
    
    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all:
            return "Transfer money between your accounts. FLO tracks owner's draws, contributions, and payments separately from income and expenses."
        case .internal:
            return "Internal transfers move money between accounts of the same type (business to business, or personal to personal)."
        case .draws:
            return "Owner's draws are when you move money from your business to personal accounts. They're tracked for equity — not as expenses."
        case .contributions:
            return "Capital contributions are personal funds you add to your business. They increase your basis — not business income."
        case .debtPayments:
            return "Track payments to your credit cards and loans here. The charges were the expenses — payments just reduce your debt."
        case .taxPayments:
            return "Record your quarterly estimated tax payments here to track them against your tax liability."
        }
    }
    
    // MARK: - Actions
    
    private func deleteTransfer(_ transfer: Transfer) {
        let success = TransferService.shared.deleteTransfer(context: context, transfer: transfer)
        if success {
            HapticService.play(.success)
        } else {
            HapticService.play(.error)
        }
    }
}

// MARK: - Transfer Filter Enum

enum TransferFilter: String, CaseIterable, Identifiable {
    case all
    case `internal`
    case draws
    case contributions
    case debtPayments
    case taxPayments
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all:           return "All"
        case .internal:      return "Internal"
        case .draws:         return "Draws"
        case .contributions: return "Contributions"
        case .debtPayments:  return "Debt"
        case .taxPayments:   return "Tax"
        }
    }
    
    var icon: String? {
        switch self {
        case .all:           return nil
        case .internal:      return "arrow.left.arrow.right"
        case .draws:         return "arrow.up.right"
        case .contributions: return "arrow.down.left"
        case .debtPayments:  return "creditcard"
        case .taxPayments:   return "building.columns"
        }
    }
}

// MARK: - Preview

#Preview {
    MoveMoneyView()
        .modelContainer(for: [Transfer.self, Account.self], inMemory: true)
}
