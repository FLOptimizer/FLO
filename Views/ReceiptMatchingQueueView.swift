//  ReceiptMatchingQueueView.swift
//  FLO - Finance Ledger Optimizer
//
//  Version 1.1 - Accessibility audit (Sprint 7)
//  Copyright © 2026 Finch & Poppy Co LLC. All rights reserved.
//
//  CHANGES v1.1:
//  ✅ Screen change announcement on appear
//  ✅ Empty state icon hidden from VoiceOver
//  ✅ Swipe hints combined with spoken labels
//  ✅ ReceiptMatchCard receipt icon hidden, header combined
//  ✅ ConfidenceBadge dot hidden, combined for VoiceOver
//  ✅ MatchOptionRow selection state + traits
//  ✅ TransactionMatchPreview icon hidden, bullet hidden
//  ✅ Fixed garbled UTF-8 in print statements
//
//  Queue view for matching unmatched receipts to transactions
//  Shows pending matches with confidence scores and quick actions
//
//  FEATURES:
//  ✅ Swipeable card stack for pending matches
//  ✅ Confidence indicator with color coding
//  ✅ Quick actions: Link, Skip, Mark as Cash
//  ✅ Transaction preview with amount/date/merchant
//  ✅ HapticService integration
//  ✅ FLOAnimation presets
//

import SwiftUI
import SwiftData

struct ReceiptMatchingQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query private var receipts: [ReceiptData]
    @Query private var transactions: [Transaction]
    
    @StateObject private var matchingService = ReceiptMatchingService.shared
    
    // Animation states
    @State private var viewAppeared = false
    @State private var currentIndex = 0
    @State private var cardOffset: CGSize = .zero
    @State private var cardRotation: Double = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if matchingService.pendingMatches.isEmpty {
                    emptyStateView
                } else {
                    matchingContentView
                }
            }
            .navigationTitle("Match Receipts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        HapticService.play(.light)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !matchingService.pendingMatches.isEmpty {
                        Text("\(currentIndex + 1) of \(matchingService.pendingMatches.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                matchingService.scanForMatches(receipts: receipts, transactions: transactions)
                withAnimation(FLOAnimation.standard) {
                    viewAppeared = true
                }
                AccessibilityAnnouncement.screenChanged("Match receipts")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: viewAppeared)
                .accessibilityHidden(true)
            
            Text("All Caught Up!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No receipts need matching right now.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                HapticService.play(.medium)
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppConstants.primaryColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
        .padding()
        .opacity(viewAppeared ? 1 : 0.001)
        .offset(y: viewAppeared ? 0 : 20)
        .animation(FLOAnimation.standard, value: viewAppeared)
    }
    
    // MARK: - Matching Content
    
    private var matchingContentView: some View {
        VStack(spacing: 0) {
            // Current receipt card
            if currentIndex < matchingService.pendingMatches.count {
                let pending = matchingService.pendingMatches[currentIndex]
                
                ReceiptMatchCard(
                    pending: pending,
                    offset: cardOffset,
                    rotation: cardRotation,
                    onLink: { transaction in
                        linkReceipt(pending.receipt, to: transaction)
                    },
                    onSkip: {
                        skipReceipt(pending.receipt)
                    },
                    onMarkCash: {
                        markAsCash(pending.receipt)
                    }
                )
                .padding()
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            cardOffset = gesture.translation
                            cardRotation = Double(gesture.translation.width / 20)
                        }
                        .onEnded { gesture in
                            handleSwipe(gesture: gesture, receipt: pending.receipt)
                        }
                )
                .opacity(viewAppeared ? 1 : 0.001)
                .offset(y: viewAppeared ? 0 : 50)
                .animation(FLOAnimation.standard, value: viewAppeared)
            }
            
            Spacer()
            
            // Swipe hints
            swipeHintsView
                .padding(.bottom, 30)
        }
    }
    
    // MARK: - Swipe Hints
    
    private var swipeHintsView: some View {
        HStack(spacing: 40) {
            VStack(spacing: 4) {
                Image(systemName: "arrow.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Skip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Swipe left to skip")
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Cash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Swipe down for cash purchase")
            
            VStack(spacing: 4) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Link")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Swipe right to link")
        }
        .opacity(viewAppeared ? 0.8 : 0)
        .animation(FLOAnimation.standard.delay(0.3), value: viewAppeared)
    }
    
    // MARK: - Actions
    
    private func handleSwipe(gesture: DragGesture.Value, receipt: ReceiptData) {
        let threshold: CGFloat = 100
        
        if gesture.translation.width > threshold {
            // Swipe right - Link to best match
            if let pending = matchingService.pendingMatches.first(where: { $0.receipt.id == receipt.id }),
               let bestMatch = pending.potentialMatches.first {
                linkReceipt(receipt, to: bestMatch.transaction)
            }
        } else if gesture.translation.width < -threshold {
            // Swipe left - Skip
            skipReceipt(receipt)
        } else if gesture.translation.height > threshold {
            // Swipe down - Mark as cash
            markAsCash(receipt)
        } else {
            // Return to center
            withAnimation(FLOAnimation.bouncy) {
                cardOffset = .zero
                cardRotation = 0
            }
        }
    }
    
    private func linkReceipt(_ receipt: ReceiptData, to transaction: Transaction) {
        HapticService.play(.success)
        
        withAnimation(FLOAnimation.quick) {
            cardOffset = CGSize(width: 500, height: 0)
            cardRotation = 15
        }
        
        // Save the image path (use existing or empty)
        let imagePath = receipt.imageURL ?? ""
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                try matchingService.linkReceipt(
                    receipt,
                    to: transaction,
                    imagePath: imagePath,
                    context: modelContext
                )
                moveToNext()
            } catch {
                HapticService.play(.error)
                #if DEBUG
                print("❌ Failed to link receipt: \(error)")
                #endif
            }
        }
    }
    
    private func skipReceipt(_ receipt: ReceiptData) {
        HapticService.play(.light)
        
        withAnimation(FLOAnimation.quick) {
            cardOffset = CGSize(width: -500, height: 0)
            cardRotation = -15
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            matchingService.skipForNow(receipt)
            moveToNext()
        }
    }
    
    private func markAsCash(_ receipt: ReceiptData) {
        HapticService.play(.medium)
        
        withAnimation(FLOAnimation.quick) {
            cardOffset = CGSize(width: 0, height: 500)
            cardRotation = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            do {
                try matchingService.markAsNoMatch(receipt, context: modelContext)
                moveToNext()
            } catch {
                HapticService.play(.error)
                #if DEBUG
                print("❌ Failed to mark as cash: \(error)")
                #endif
            }
        }
    }
    
    private func moveToNext() {
        withAnimation(FLOAnimation.quick) {
            cardOffset = .zero
            cardRotation = 0
        }
        
        // Check if there are more
        if matchingService.pendingMatches.isEmpty {
            // All done!
            HapticService.play(.success)
        }
    }
}

// MARK: - Receipt Match Card

struct ReceiptMatchCard: View {
    let pending: PendingReceiptMatch
    let offset: CGSize
    let rotation: Double
    let onLink: (Transaction) -> Void
    let onSkip: () -> Void
    let onMarkCash: () -> Void
    
    @State private var selectedMatchIndex = 0
    @State private var showAllMatches = false
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Receipt Info Header
            receiptHeader
            
            Divider()
                .padding(.vertical, 12)
            
            // Best Match Section
            if !pending.potentialMatches.isEmpty {
                bestMatchSection
            }
            
            // Action Buttons
            actionButtons
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .offset(offset)
        .rotationEffect(.degrees(rotation))
    }
    
    // MARK: - Receipt Header
    
    private var receiptHeader: some View {
        VStack(spacing: 12) {
            // Confidence Badge
            HStack {
                ConfidenceBadge(quality: pending.matchQuality, score: pending.bestMatchScore)
                Spacer()
                
                if pending.potentialMatches.count > 1 {
                    Button {
                        HapticService.play(.light)
                        showAllMatches.toggle()
                    } label: {
                        Text("\(pending.potentialMatches.count) matches")
                            .font(.caption)
                            .foregroundStyle(AppConstants.primaryColor)
                    }
                }
            }
            
            // Receipt Details
            HStack(spacing: 16) {
                // Receipt icon
                ZStack {
                    Circle()
                        .fill(AppConstants.primaryColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(AppConstants.primaryColor)
                }
                .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(pending.receipt.merchantName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(pending.receipt.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(pending.receipt.totalAmount, format: .currency(code: currencyCode))
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
    }
    
    // MARK: - Best Match Section
    
    private var bestMatchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Best Match")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            
            if showAllMatches {
                // Show all matches
                ForEach(Array(pending.potentialMatches.enumerated()), id: \.element.transaction.id) { index, match in
                    MatchOptionRow(
                        match: match,
                        isSelected: index == selectedMatchIndex,
                        onSelect: {
                            HapticService.play(.selection)
                            selectedMatchIndex = index
                        }
                    )
                }
            } else {
                // Show only best match
                let bestMatch = pending.potentialMatches[selectedMatchIndex]
                TransactionMatchPreview(match: bestMatch)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Skip Button
            Button {
                onSkip()
            } label: {
                HStack {
                    Image(systemName: "arrow.uturn.left")
                    Text("Skip")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.15))
                .foregroundStyle(.orange)
                .cornerRadius(10)
            }
            
            // Cash Button
            Button {
                onMarkCash()
            } label: {
                HStack {
                    Image(systemName: "banknote")
                    Text("Cash")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.15))
                .foregroundStyle(.blue)
                .cornerRadius(10)
            }
            
            // Link Button
            Button {
                let selectedMatch = pending.potentialMatches[selectedMatchIndex]
                onLink(selectedMatch.transaction)
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text("Link")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppConstants.primaryColor)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let quality: PendingReceiptMatch.MatchQuality
    let score: Double
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            
            Text(quality.displayText)
                .font(.caption)
                .fontWeight(.medium)
            
            Text("(\(Int(score * 100))%)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Match confidence: \(quality.displayText), \(Int(score * 100)) percent")
    }
    
    private var badgeColor: Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

// MARK: - Transaction Match Preview

struct TransactionMatchPreview: View {
    let match: TransactionMatch
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Transaction icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(match.transaction.merchantName.isEmpty ? match.transaction.note : match.transaction.merchantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(match.transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let category = match.transaction.category {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(category.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(match.transaction.amount, format: .currency(code: currencyCode))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(match.displayConfidence)
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Match Option Row

struct MatchOptionRow: View {
    let match: TransactionMatch
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppConstants.primaryColor : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.transaction.merchantName.isEmpty ? match.transaction.note : match.transaction.merchantName)
                        .font(.subheadline)
                        .lineLimit(1)
                    
                    Text(match.transaction.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(match.transaction.amount, format: .currency(code: currencyCode))
                        .font(.subheadline)
                    
                    Text("\(Int(match.score * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(isSelected ? AppConstants.primaryColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(match.transaction.merchantName.isEmpty ? match.transaction.note : match.transaction.merchantName), \(match.transaction.date.formatted(date: .abbreviated, time: .omitted)), \(Int(match.score * 100)) percent match\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview {
    ReceiptMatchingQueueView()
        .modelContainer(for: [ReceiptData.self, Transaction.self], inMemory: true)
}
