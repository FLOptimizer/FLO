//  TransferSummaryCard.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.4 - Simplified Previews
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  Dashboard card showing recent transfer activity and YTD equity summary.
//  Helps freelancers track money movement between business and personal accounts.
//
//  CHANGES v1.4 - Preview Fixes:
//  ✅ FIXED: Simplified #Preview macros to avoid Swift 5.9+ closure issues
//  ✅ REMOVED: Complex preview setup that caused "Type '()' cannot conform to 'View'" errors
//
//  CHANGES v1.3 - Preview Fixes:
//  ✅ FIXED: Account init parameter order (currentBalance before financeType)
//
//  CHANGES v1.2 - Preview Fixes:
//  ✅ FIXED: Removed explicit 'return' statements from #Preview macros (Swift 5.9+ requirement)
//
//  CHANGES v1.1 - Bug Fixes:
//  ✅ REMOVED: Duplicate TransferRowCompact struct (already in TransferRowView.swift)
//  ✅ REMOVED: Duplicate TransferType extension for icon/color (already in Transfer.swift)
//  ✅ FIXED: Uses TransferRowCompact from TransferRowView.swift
//  ✅ FIXED: Uses Color(flowHex:) for TransferType colors
//  ✅ FIXED: Preview uses .federalIRS instead of .federal
//
//  FEATURES:
//  ✅ Last 3 transfers in compact format
//  ✅ YTD Owner's Draws and Capital Contributions summary
//  ✅ Quick action button to create new transfer
//  ✅ Empty state with illustration and call-to-action
//  ✅ Tappable card navigates to full MoveMoneyView
//  ✅ Entrance animations with staggered transfer rows
//  ✅ Full haptic feedback on all interactions
//  ✅ Complete VoiceOver accessibility
//  ✅ Dark mode support with semantic colors
//  ✅ Dynamic Type with lineLimit + minimumScaleFactor
//
//  DESIGN:
//  - Matches existing dashboard card styling (rounded corners, shadow, background)
//  - Uses Color.brandPrimary for accents
//  - Compact height similar to BudgetOverviewCard
//  - Maximum of 3 recent transfers to keep card concise
//

import SwiftUI
import FLODesignSystem
import SwiftData

struct TransferSummaryCard: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Transfer.date, order: .reverse) private var allTransfers: [Transfer]
    
    @Binding var showMoveMoneyView: Bool
    
    // Animation states
    @State private var cardOpacity: Double = 0
    @State private var cardOffset: CGFloat = 20
    @State private var rowsVisible = false
    @State private var summaryVisible = false
    
    // Recent transfers (max 3)
    private var recentTransfers: [Transfer] {
        Array(allTransfers.prefix(3))
    }
    
    // YTD calculations
    private var ytdDraws: Double {
        TransferService.shared.calculateYTDDraws(context: modelContext)
    }
    
    private var ytdContributions: Double {
        TransferService.shared.calculateYTDContributions(context: modelContext)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            if recentTransfers.isEmpty {
                emptyState
            } else {
                transfersList
                
                Divider()
                
                ytdSummary
            }
        }
        .background(Color.floSecondarySystemBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(cardOpacity)
        .offset(y: cardOffset)
        .onAppear {
            animateEntrance()
        }
        .onTapGesture {
            HapticService.play(.light)
            showMoveMoneyView = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Transfer activity card")
        .accessibilityHint("Double tap to view all transfers and move money")
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.brandPrimary)
                .accessibilityHidden(true)
            
            Text("Move Money")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            Button {
                HapticService.play(.medium)
                showMoveMoneyView = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityLabel("Create new transfer")
            .accessibilityHint("Opens form to move money between accounts")
        }
        .padding()
    }
    
    // MARK: - Transfers List
    
    private var transfersList: some View {
        VStack(spacing: 0) {
            ForEach(Array(recentTransfers.enumerated()), id: \.element.id) { index, transfer in
                // Uses TransferRowCompact from TransferRowView.swift
                TransferRowCompact(transfer: transfer)
                    .opacity(rowsVisible ? 1 : 0)
                    .offset(x: rowsVisible ? 0 : 20)
                    .animation(
                        FLOAnimation.standard.delay(Double(index) * 0.05),
                        value: rowsVisible
                    )
                
                if transfer.id != recentTransfers.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
    }
    
    // MARK: - YTD Summary
    
    private var ytdSummary: some View {
        HStack(spacing: 20) {
            // Owner's Draws
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .accessibilityHidden(true)
                    
                    Text("YTD Draws")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Text(ytdDraws.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Year to date owner's draws: \(ytdDraws.formatted(.currency(code: "USD")))")
            
            Spacer()
            
            // Capital Contributions
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.left.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)
                    
                    Text("YTD Contributions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Text(ytdContributions.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.teal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Year to date capital contributions: \(ytdContributions.formatted(.currency(code: "USD")))")
        }
        .padding()
        .opacity(summaryVisible ? 1 : 0)
        .offset(y: summaryVisible ? 0 : 10)
        .animation(FLOAnimation.standard.delay(0.2), value: summaryVisible)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            // Illustration
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.brandPrimary)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                Text("Track Your Money Movement")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
                
                Text("Move money between business and personal accounts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                HapticService.play(.medium)
                showMoveMoneyView = true
            } label: {
                Text("Get Started")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.brandPrimary)
                    .cornerRadius(8)
            }
            .accessibilityLabel("Get started with transfers")
            .accessibilityHint("Opens form to create your first transfer")
        }
        .padding(.vertical, 24)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        withAnimation(FLOAnimation.standard) {
            cardOpacity = 1
            cardOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(FLOAnimation.standard) {
                rowsVisible = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(FLOAnimation.standard) {
                summaryVisible = true
            }
        }
    }
}

// NOTE: TransferRowCompact is defined in TransferRowView.swift
// NOTE: TransferType.icon and .color are defined in Transfer.swift

// MARK: - Preview

#Preview("Empty State") {
    TransferSummaryCard(showMoveMoneyView: .constant(false))
        .padding()
        .modelContainer(for: [Transfer.self, Account.self, RecurringTransfer.self], inMemory: true)
}

#Preview("Dark Mode") {
    TransferSummaryCard(showMoveMoneyView: .constant(false))
        .padding()
        .background(Color.floSystemBackground)
        .modelContainer(for: [Transfer.self, Account.self, RecurringTransfer.self], inMemory: true)
        .preferredColorScheme(.dark)
}
